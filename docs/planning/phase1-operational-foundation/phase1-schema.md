# Phase 1 Database Schema

* `registers` (renamed from Phase 1 `workstations`; ADR-021)  
* `user_roles` → `role_assignments`  
* Organization administration requires globally scoped role assignments  
* Administrators use the ordinary permission engine  
* All primary business identifiers use UUIDv7  
* Lifecycle records are deactivated or revoked rather than deleted  
* Timestamps are `timestamptz`  
* Mutable configuration records use optimistic-concurrency `lock_version`
* Authorization contract: [phase1-authorization.md](phase1-authorization.md)

## 1\. `system_settings`

One row representing installation-wide configuration.

| Field | Type | Constraints | Notes |
| :---- | :---- | :---- | :---- |
| `id` | uuid | PK; UUIDv7 |  |
| `singleton_key` | boolean | null: false; default `true`; unique; check `singleton_key = true` | Database enforcement of one row |
| `organization_name` | varchar | null: false | Customer-facing organization name |
| `legal_name` | varchar |  | Legal entity name if different |
| `base_currency_code` | char(3) | null: false | ISO 4217 |
| `default_timezone` | varchar | null: false | IANA timezone |
| `default_country_code` | char(2) | null: false | ISO 3166-1 alpha-2 |
| `default_region_code` | varchar |  | State, province, or equivalent |
| `fiscal_year_start_month` | smallint | null: false; default `1`; check 1–12 |  |
| `default_supplier_cancellation_days` | smallint | null: false; default `20`; check `>= 0` | Default used when supplier-specific policy is absent |
| `default_customer_reservation_expiration_days` | smallint | null: false; default `7`; check `>= 0` | Default for customer reservations |
| `default_receipt_header` | text | max 500 after trim | Organization default; inherit target |
| `default_receipt_footer` | text | max 500 after trim | Organization default; inherit target |
| `gift_card_voucher_footer` | text | max 500 after trim | Organization gift-card voucher terms; blank omits the footer ([phase10-schema.md](../phase10-stored-value/phase10-schema.md) §13) |
| `stored_value_adjust_credit_approval_threshold_cents` | bigint | null: false; default `5000`; check `>= 0` | Credits at or above this amount require second-user approval; all debits require second-user approval ([phase10-schema.md](../phase10-stored-value/phase10-schema.md) §13) |
| `initialized_at` | timestamptz |  | Set only as the final successful bootstrap step; null means install incomplete / retryable |
| `lock_version` | integer | null: false; default `0` | Optimistic concurrency |
| `created_at` | timestamptz | null: false |  |
| `updated_at` | timestamptz | null: false |  |

`singleton_key` gives PostgreSQL a simple way to prevent a second settings row without relying on a magic integer ID.

There should be no normal create or delete operation after bootstrap. Bootstrap uses a transactional service with an advisory lock (and/or locking the singleton row). Concurrent bootstrap attempts must fail cleanly. A rolled-back failure leaves `initialized_at` null so installation remains retryable. Phase 1 does not provide an ordinary administrative reopen of bootstrap.

---

## 2\. `stores`

Defines an operational store and reporting boundary.

| Field | Type | Constraints | Notes |
| :---- | :---- | :---- | :---- |
| `id` | uuid | PK; UUIDv7 |  |
| `store_number` | integer | null: false; unique; CHECK `> 0` | Business-facing identifier; leading zeroes are display-only |
| `code` | varchar | null: false; unique | Short, stable operational code |
| `name` | varchar | null: false | Display name |
| `legal_name` | varchar | required while `active`; not copied from `name` | Customer receipt identity |
| `street_address_1` | varchar |  |  |
| `street_address_2` | varchar |  |  |
| `city` | varchar |  |  |
| `region_code` | varchar |  | State, province, or equivalent |
| `postal_code` | varchar |  |  |
| `country_code` | char(2) | null: false | ISO 3166-1 alpha-2 |
| `phone` | varchar |  | Store contact number |
| `san` | varchar |  | Standard Address Number, where applicable |
| `timezone` | varchar | null: false | IANA timezone |
| `receipt_header` | text |  | Custom header text when `receipt_header_mode = custom`; dormant otherwise |
| `receipt_footer` | text |  | Custom footer text when `receipt_footer_mode = custom`; dormant otherwise |
| `receipt_header_mode` | varchar | null: false; default `inherit`; CHECK `inherit \| custom \| none` | Independent of footer |
| `receipt_footer_mode` | varchar | null: false; default `inherit`; CHECK `inherit \| custom \| none` | Independent of header |
| `active` | boolean | null: false; default `true` | Inactive stores cannot be selected operationally |
| `deactivated_at` | timestamptz |  |  |
| `deactivated_by_id` | uuid | FK: `users`; nullable |  |
| `lock_version` | integer | null: false; default `0` | Optimistic concurrency |
| `created_at` | timestamptz | null: false |  |
| `updated_at` | timestamptz | null: false |  |

Recommended rules:

* Normalize `code` before enforcing uniqueness. Store numbers are positive integers (`"01"` and `"1"` are the same identity).  
* Do not allow `store_number` to change after a completed POS transaction exists for the Store or any Register in the Store has `receipt_sequence > 0`; treat Register `register_number` as immutable once that Register has issued a receipt.  
* Do not allow the final active store to be deactivated normally.  
* Do not hard-delete a store after another record references it.

---

## 3\. `users`

A durable human or system actor identity.

| Field | Type | Constraints | Notes |
| :---- | :---- | :---- | :---- |
| `id` | uuid | PK; UUIDv7 |  |
| `username` | varchar | null: false | Case-insensitive unique |
| `email` | varchar |  | Case-insensitive unique when present |
| `display_name` | varchar | null: false | Historical audit records also snapshot this |
| `actor_type` | varchar | null: false; default `human` | `human`, `system`, `integration`, `scheduled_job` |
| `password_digest` | varchar |  | Required for interactive human users; omitted for the protected system actor |
| `active` | boolean | null: false; default `true` |  |
| `password_changed_at` | timestamptz |  |  |
| `password_reset_required` | boolean | null: false; default `false` | Useful for administrator-initiated resets |
| `last_signed_in_at` | timestamptz |  |  |
| `failed_sign_in_count` | integer | null: false; default `0`; check `>= 0` |  |
| `locked_at` | timestamptz |  |  |
| `deactivated_at` | timestamptz |  |  |
| `deactivated_by_id` | uuid | FK: `users`; nullable |  |
| `lock_version` | integer | null: false; default `0` | Optimistic concurrency |
| `created_at` | timestamptz | null: false |  |
| `updated_at` | timestamptz | null: false |  |

Recommended indexes:

```
unique(lower(username))
unique(lower(email)) where email is not null
```

Recommended invariants:

* Interactive `actor_type = 'human'` accounts require `password_digest` (`has_secure_password` + `bcrypt`).  
* The protected system actor (`actor_type = 'system'`) cannot authenticate, cannot receive interactive sessions or role assignments, and is exempt from password-presence validation. Authentication must reject system actors even if a digest exists.  
* Non-human actors cannot sign in interactively.  
* The protected system actor cannot be deactivated or deleted.  
* Deactivation revokes all active `user_sessions`.  
* ShelfSense must retain at least one active human with a current global `system_administrator` role assignment (enforced with transactional locking; see authorization contract).

Administrator status comes entirely from roles and permissions. There is no separate administrator user type.

---

## 4\. `roles`

Reusable permission bundles.

| Field | Type | Constraints | Notes |
| :---- | :---- | :---- | :---- |
| `id` | uuid | PK; UUIDv7 |  |
| `key` | varchar | null: false; unique | Stable machine identifier |
| `name` | varchar | null: false | Human-facing name |
| `description` | text |  |  |
| `system_role` | boolean | null: false; default `false` | Seeded/protected role |
| `assignment_scope` | varchar | null: false | `global`, `store`, or `either` — where the role may be assigned |
| `active` | boolean | null: false; default `true` |  |
| `deactivated_at` | timestamptz |  |  |
| `deactivated_by_id` | uuid | FK: `users`; nullable |  |
| `lock_version` | integer | null: false; default `0` | Increment when role or permission membership changes |
| `created_at` | timestamptz | null: false |  |
| `updated_at` | timestamptz | null: false |  |

Recommended indexes:

```
unique(lower(name))
unique(key)
```

Recommended rules:

* `key` becomes immutable once created.  
* System roles cannot be deleted.  
* Deactivated roles grant no permissions.  
* The `system_administrator` role does not bypass authorization; it receives its capabilities through `role_permissions`.  
* Any change to `role_permissions` increments `roles.lock_version`.  
* Seeded assignment scopes: `system_administrator` → `global`; `store_manager` / `associate` → `store`. See [phase1-authorization.md](phase1-authorization.md).

Initial roles:

```
system_administrator
store_manager
associate
```

---

## 5\. `permissions`

System-defined authorization capabilities.

| Field | Type | Constraints | Notes |
| :---- | :---- | :---- | :---- |
| `id` | uuid | PK; UUIDv7 | Seeded identifier |
| `key` | varchar | null: false; unique | Machine-readable capability |
| `group_key` | varchar | null: false | Used to group permissions in the UI |
| `name` | varchar | null: false | Human-readable label |
| `description` | text |  |  |
| `scope_type` | varchar | null: false | `global`, `store`, or `either` |
| `active` | boolean | null: false; default `true` | Retains obsolete permissions without reuse |
| `created_at` | timestamptz | null: false |  |
| `updated_at` | timestamptz | null: false |  |

`scope_type` helps prevent inappropriate assignments:

* `global`: meaningful only through a global role assignment  
* `store`: evaluated in a store context  
* `either`: may be assigned globally or for one store

For example:

| Permission | Scope |
| :---- | :---- |
| `system_settings.view` | `global` |
| `system_settings.manage` | `global` |
| `users.manage` | `global` |
| `users.assign_roles` | `global` |
| `stores.create` | `global` |
| `stores.view` | `either` |
| `registers.manage` | `either` |
| `audit_events.view` | `either` |

Permissions are seeded by application code. The administration interface should not permit arbitrary permission creation or deletion.

---

## 6\. `role_permissions`

Associates permissions with roles.

| Field | Type | Constraints | Notes |
| :---- | :---- | :---- | :---- |
| `id` | uuid | PK; UUIDv7 | Gives the association its own audit identity |
| `role_id` | uuid | FK: `roles`; null: false |  |
| `permission_id` | uuid | FK: `permissions`; null: false |  |
| `granted_by_id` | uuid | FK: `users`; null: false | Actor making the change |
| `created_at` | timestamptz | null: false |  |

Constraint:

```
unique(role_id, permission_id)
```

The current permission set may be represented by rows being added or removed. The permanent history of those changes belongs in `audit_events`.

No explicit denial rows are included in Phase 1\. Permissions are additive.

---

## 7\. `role_assignments`

Assigns a role to a user globally or within one store.

| Field | Type | Constraints | Notes |
| :---- | :---- | :---- | :---- |
| `id` | uuid | PK; UUIDv7 |  |
| `user_id` | uuid | FK: `users`; null: false |  |
| `role_id` | uuid | FK: `roles`; null: false |  |
| `store_id` | uuid | FK: `stores`; nullable | Null means global |
| `effective_at` | timestamptz | null: false; default current time |  |
| `expires_at` | timestamptz |  | Must be later than `effective_at` |
| `assigned_by_id` | uuid | FK: `users`; null: false |  |
| `revoked_at` | timestamptz |  | Null means not revoked |
| `revoked_by_id` | uuid | FK: `users`; nullable | Required when revoked |
| `revocation_reason` | text |  |  |
| `created_at` | timestamptz | null: false |  |
| `updated_at` | timestamptz | null: false |  |

A role assignment is effective when:

```
revoked_at is null
and effective_at <= current time
and (expires_at is null or expires_at > current time)
and user.active = true
and role.active = true
and (store_id is null or store.active = true)
```

Global and store-specific assignments require separate partial unique indexes because SQL treats nulls specially:

```
unique(user_id, role_id)
where store_id is null and revoked_at is null

unique(user_id, role_id, store_id)
where store_id is not null and revoked_at is null
```

Authorization behavior:

* `store_id IS NULL` grants the role globally.  
* A global assignment contributes permissions in every active store.  
* A populated `store_id` contributes permissions only in that store.  
* Store-scoped assignments never grant organization-wide administration.  
* Organization-wide user, role, permission, or settings administration requires the relevant permission from a global assignment.  
* Revocation preserves the assignment history rather than deleting it.

A user may access a store when at least one effective assignment applies either globally or to that store.

---

## 8\. `registers` (ADR-021)

**Implemented:** table `registers` (renamed from Phase 1 `workstations`). A Register is the durable logical checkout position. A Terminal (deferred) is the concrete POS client. See [ADR-021](../../adr/ADR-021-register-and-terminal-identity.md) and [register-identity.md](../phase4-6-point-of-sale/phase4-point-of-sale/register-identity.md).

| Field | Type | Constraints | Notes |
| :---- | :---- | :---- | :---- |
| `id` | uuid | PK; UUIDv7 |  |
| `store_id` | uuid | FK: `stores`; null: false |  |
| `register_number` | integer | null: false; unique per store; CHECK `> 0` | Durable number parallel to `stores.store_number`; immutable once a receipt has been issued |
| `name` | varchar | null: false | Editable label; not used in receipt reference |
| `description` | text |  |  |
| `active` | boolean | null: false; default `true` |  |
| `receipt_sequence` | bigint | null: false; default `0`; check `>= 0` | Last sequence permanently consumed; must not decrease |
| `deactivated_at` | timestamptz |  | Register removed from normal operation |
| `deactivated_by_id` | uuid | FK: `users`; nullable |  |
| `lock_version` | integer | null: false; default `0` | Optimistic concurrency |
| `created_at` | timestamptz | null: false |  |
| `updated_at` | timestamptz | null: false |  |

Constraints:

```
unique(store_id, register_number)
```

Device/client columns (`code`, `activated_at`, `revoked_at`, `last_seen_at`) were dropped with the rename. Permission `workstations.revoke` is retained inactive (deprecated) so custom-role grants remain in authorization history; it is removed from current system-role grants. Terminal lifecycle belongs to a later phase.

Important distinctions:

* A Register is not a cash drawer.  
* A Register is not an employee session.  
* POS Sessions are operational use of a Register.  
* Hardware/Terminal may be replaced while preserving the Register identity.  
* Human-facing receipt / transaction reference (ADR-006):

```
S{store_number}-R{register_number}-T{receipt_sequence}
```

For example: `S003-R02-T0018427`. See [receipt-identity.md](../phase4-6-point-of-sale/phase4-point-of-sale/receipt-identity.md).

---

## 9\. `user_sessions`

Server-side authentication sessions. These are not future POS workstation sessions.

| Field | Type | Constraints | Notes |
| :---- | :---- | :---- | :---- |
| `id` | uuid | PK; UUIDv7 | Internal session identity |
| `user_id` | uuid | FK: `users`; null: false |  |
| `token_digest` | varchar | null: false; unique | Never store the usable bearer token |
| `created_at` | timestamptz | null: false |  |
| `last_seen_at` | timestamptz | null: false | Used for idle expiration |
| `expires_at` | timestamptz | null: false | Absolute expiration |
| `revoked_at` | timestamptz |  |  |
| `revoked_by_id` | uuid | FK: `users`; nullable | Null for automatic revocation |
| `revocation_reason` | varchar |  | `sign_out`, `user_deactivated`, `password_changed`, `administrator_revoked`, etc. |
| `ip_address` | inet |  |  |
| `user_agent` | text |  |  |
| `created_audit_event_id` | uuid | FK: `audit_events`; nullable | Optional traceability |

A session is valid only when:

```
revoked_at is null
and expires_at > current time
and user.active = true
and user.locked_at is null
```

Recommended indexes:

```
unique(token_digest)
index(user_id, revoked_at)
index(expires_at)
```

Password changes and user deactivation should revoke all currently active sessions.

---

## 10\. `audit_events`

Append-only record of security, authorization, and material configuration activity.

| Field | Type | Constraints | Notes |
| :---- | :---- | :---- | :---- |
| `id` | uuid | PK; UUIDv7 |  |
| `occurred_at` | timestamptz | null: false | When the action occurred |
| `recorded_at` | timestamptz | null: false | When the event was persisted |
| `actor_type` | varchar | null: false | `user`, `system`, `integration`, `scheduled_job`, `anonymous` |
| `actor_user_id` | uuid | FK: `users`; nullable | Nullable for anonymous or external actors |
| `actor_label` | varchar | null: false | Historical display snapshot |
| `store_id` | uuid | FK: `stores`; nullable | Store context, if applicable |
| `register_id` | uuid | FK: `registers`; nullable |  |
| `user_session_id` | uuid | FK: `user_sessions`; nullable |  |
| `action` | varchar | null: false | Stable event key |
| `outcome` | varchar | null: false | `succeeded`, `failed`, `denied` |
| `subject_type` | varchar |  | Stable subject type |
| `subject_id` | uuid |  | Deliberately not a strict polymorphic FK |
| `subject_label` | varchar |  | Historical display snapshot |
| `reason_code` | varchar |  | Machine-readable reason |
| `reason_text` | text |  | Human explanation |
| `correlation_id` | uuid | null: false | Groups related events |
| `before_values` | jsonb |  | Selected, redacted prior values |
| `after_values` | jsonb |  | Selected, redacted resulting values |
| `metadata` | jsonb | null: false; default `{}` | Additional redacted context |
| `ip_address` | inet |  |  |
| `user_agent` | text |  |  |
| `application_version` | varchar |  |  |
| `created_at` | timestamptz | null: false | Normally equal or close to `recorded_at` |

Recommended indexes:

```
index(occurred_at)
index(actor_user_id, occurred_at)
index(store_id, occurred_at)
index(action, occurred_at)
index(subject_type, subject_id)
index(correlation_id)
index(outcome, occurred_at)
```

Important rules:

* Audit events are append-only.  
* There are no update or delete operations.  
* Successful configuration changes and their audit events are written in the same transaction.  
* Passwords, password hashes, session tokens, reset tokens, and sensitive credentials must never appear in JSON values or metadata.  
* `actor_label` and `subject_label` preserve meaningful history if names later change.  
* `subject_id` is not a database foreign key because it can reference multiple table types and must survive subject deactivation or archival.

## Relationship summary

```
erDiagram
    USERS ||--o{ USER_SESSIONS : authenticates
    USERS ||--o{ ROLE_ASSIGNMENTS : receives
    ROLES ||--o{ ROLE_ASSIGNMENTS : assigned_as
    STORES o|--o{ ROLE_ASSIGNMENTS : scopes
    ROLES ||--o{ ROLE_PERMISSIONS : contains
    PERMISSIONS ||--o{ ROLE_PERMISSIONS : grants
    STORES ||--o{ WORKSTATIONS : contains
    USERS o|--o{ AUDIT_EVENTS : performs
    STORES o|--o{ AUDIT_EVENTS : contextualizes
    WORKSTATIONS o|--o{ AUDIT_EVENTS : originates
```

## Phase 1 permission catalog and role matrix

The authoritative permission catalog, role grants, assignment scopes, evaluation sequence, and last-administrator rules are defined in [phase1-authorization.md](phase1-authorization.md).  