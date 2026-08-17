# Phase 1 \- Operational Foundation

**Authority:** Field-level schema is defined in [phase1-schema.md](phase1-schema.md). Permission catalog, role grants, and evaluation rules are defined in [phase1-authorization.md](phase1-authorization.md). Where this plan’s earlier draft tables conflict (for example historical `user_roles` / `registers` / conceptual `version` wording), prefer the schema, authorization contract, and the settled decisions at the end of this document. Mutable aggregate concurrency uses Rails `lock_version`.

Phase 1 is appropriately scoped, but I would make three structural adjustments before implementation:

1. Treat `user_roles` as scoped role assignments, with an optional `store_id`.  
2. Use `workstations` rather than `registers`, consistent with the terminology we already selected.  
3. Include authentication/session infrastructure even if framework-managed, because “a user can sign in” cannot be delivered by the `users` table alone.

The phase should produce a usable administration shell, not merely migrations and CRUD screens.

## 1\. Phase 1 boundary

Phase 1 should answer these operational questions:

* How is the ShelfSense installation initialized?  
* How does a user authenticate?  
* Which stores may that user access?  
* What may the user do in the selected store?  
* How are users, roles, stores, workstations, and essential settings administered?  
* Which security and configuration actions are permanently audited?

It should not yet implement:

* Business days or register sessions  
* Cash drawers  
* POS transactions  
* Offline workstation operation or synchronization  
* Product, inventory, customer, or supplier administration  
* Approval workflows  
* Detailed store operating policies  
* Configurable permission creation through the UI

The central application should be usable at the end of Phase 1, but the workstation is only being defined and administered—not yet used as a POS.

---

## 2\. Recommended Phase 1 tables

| Table | Responsibility |
| :---- | :---- |
| `system_settings` | Singleton organization-wide configuration |
| `stores` | Store identity, address, timezone, and lifecycle |
| `users` | Human and system actors capable of authentication or attribution |
| `roles` | Reusable permission bundles |
| `permissions` | System-defined authorization capabilities |
| `role_permissions` | Permissions included in each role |
| `role_assignments` | Global or store-scoped role assignments |
| `workstations` | Durable store-assigned POS workstation identities |
| `audit_events` | Append-only record of material actions |
| Authentication/session storage | Credential recovery, sessions, and related authentication state |

The authorization relationship would be:

```
erDiagram
    USERS ||--o{ USER_ROLES : receives
    ROLES ||--o{ USER_ROLES : assigned_as
    STORES o|--o{ USER_ROLES : scopes
    ROLES ||--o{ ROLE_PERMISSIONS : includes
    PERMISSIONS ||--o{ ROLE_PERMISSIONS : grants
    STORES ||--o{ WORKSTATIONS : contains
```

A null `role_assignments.store_id` means the assignment is organization-wide. A populated `store_id` means it applies only while operating in that store.

This gives us explicit store access without a separate `user_stores` table: a user can access a store only if they have at least one active role assignment applicable to it.

---

# 3\. `system_settings`

This should be a true singleton representing the organization using this ShelfSense installation.

### Recommended fields

| Field | Type | Constraints / notes |
| :---- | :---- | :---- |
| `id` | UUID | PK; UUIDv7 |
| `organization_name` | string | null: false |
| `legal_name` | string |  |
| `base_currency_code` | string | null: false; ISO 4217; length 3 |
| `default_timezone` | string | null: false; IANA timezone |
| `default_country_code` | string | null: false; ISO 3166-1 alpha-2 |
| `default_region_code` | string |  |
| `fiscal_year_start_month` | smallint | null: false; default 1; range 1–12 |
| `default_supplier_cancellation_days` | smallint | null: false; default 20 |
| `default_customer_reservation_expiration_days` | smallint | null: false; default 7 |
| `default_receipt_header` | text |  |
| `default_receipt_footer` | text |  |
| `lock_version` | integer | null: false; default 1 |
| `created_at` | timestamp | null: false |
| `updated_at` | timestamp | null: false |

### Singleton enforcement

The application should expose:

```
SystemSettings.current
```

It should not expose create/delete operations after installation.

There are several ways to enforce one row, but the simplest application-level model is:

* Bootstrap creates the single record.  
* No ordinary route exists for creating another.  
* No delete operation exists.  
* Startup validation fails clearly if zero or multiple rows exist.

A database constraint can strengthen this, but the settings row should not depend on a magic `id = 1`, especially after adopting UUIDv7.

### Settings behavior

Store-level values should override organization defaults where appropriate:

```
effective receipt header =
    store.receipt_header if present
    otherwise system_settings.default_receipt_header
```

Defaults are copied or inherited according to the setting’s semantics. We should not use one generic JSON settings column in Phase 1\. Typed columns provide validation, discoverability, and safer changes.

---

# 4\. `stores`

A store is an operational and reporting boundary. Even though Phase 1 initially administers one store, the schema should preserve the accepted multi-store design.

### Recommended fields

| Field | Type | Constraints / notes |
| :---- | :---- | :---- |
| `id` | UUID | PK; UUIDv7 |
| `store_number` | integer | null: false; unique; CHECK `> 0` |
| `code` | string | null: false; unique; stable short code |
| `name` | string | null: false |
| `legal_name` | string | optional store-specific legal name |
| `street_address_1` | string |  |
| `street_address_2` | string |  |
| `city` | string |  |
| `region_code` | string |  |
| `postal_code` | string |  |
| `country_code` | string | ISO alpha-2 |
| `phone` | string |  |
| `san` | string | Standard Address Number, if applicable |
| `timezone` | string | null: false; IANA timezone |
| `receipt_header` | text | optional override |
| `receipt_footer` | text | optional override |
| `active` | boolean | null: false; default true |
| `lock_version` | integer | null: false; default 1 |
| `created_at` | timestamp | null: false |
| `updated_at` | timestamp | null: false |

`store_number` is a positive integer. Leading zeroes are presentation only (`1` displays as `S001`); `"1"` and `"01"` are the same identity. Letters are not part of the store number.

`code` should be a short, immutable operational identifier suitable for receipt numbers and UI contexts:

```
DT
NORTH
002
```

The display name can change; the code should not be casually changed once used.

### Lifecycle

Stores should be deactivated, not deleted, once referenced. Phase 1 may permit deletion only if the store has never been used and has no assignments or workstations.

The final active store must not be deactivated through the normal UI.

---

# 5\. `users`

A user is a durable actor identity. Shared cashier accounts should not be permitted.

### Recommended fields

| Field | Type | Constraints / notes |
| :---- | :---- | :---- |
| `id` | UUID | PK; UUIDv7 |
| `username` | string | null: false; case-insensitive unique |
| `email` | string | optional initially; case-insensitive unique when present |
| `display_name` | string | null: false |
| `password_digest` | string | null for non-interactive system actors |
| `user_type` | string | `system`, `administrator`, `user` |
| `active` | boolean | null: false; default true |
| `password_changed_at` | timestamp |  |
| `last_signed_in_at` | timestamp |  |
| `failed_sign_in_count` | integer | null: false; default 0 |
| `locked_at` | timestamp |  |
| `lock_version` | integer | null: false; default 1 |
| `created_at` | timestamp | null: false |
| `updated_at` | timestamp | null: false |

### User type versus authorization

`user_type` should describe identity behavior, not replace permissions:

* `system`: non-interactive actor used for system-attributed activity.  
* `administrator`: interactive bootstrap/administrative identity.  
* `user`: ordinary interactive identity.

Application code should still check permission keys, not:

```
if user.user_type == "administrator"
```

If `administrator` is intended to bypass ordinary permission calculation, that is a special security rule and should be kept very narrow. My preference is to seed the administrator with a global `system_administrator` role and let the normal authorization engine grant access.

### Protected system user

Seed a non-interactive `system` user:

* Cannot sign in  
* Cannot receive a password  
* Cannot be deactivated  
* Cannot be deleted  
* Cannot be assigned ordinary operational roles  
* Used where an audit event requires a durable system actor

### User deactivation

Deactivation should:

* Prevent new sign-ins.  
* Revoke active server sessions.  
* Preserve the user and all historical references.  
* Preserve past role assignments and audit events.  
* Prevent new role assignments until reactivated.

The application must prevent an administrator from removing the final usable global system administrator.

---

# 6\. Roles and permissions

## `roles`

| Field | Type | Constraints / notes |
| :---- | :---- | :---- |
| `id` | UUID | PK; UUIDv7 |
| `key` | string | null: false; unique; immutable machine identity |
| `name` | string | null: false; unique display name |
| `description` | text |  |
| `system_role` | boolean | null: false; default false |
| `active` | boolean | null: false; default true |
| `lock_version` | integer | null: false; default 1 |
| `created_at` | timestamp | null: false |
| `updated_at` | timestamp | null: false |

Adding `key` avoids using a mutable display name as identity.

System roles may be protected from deletion but should not receive hard-coded behavior. Their permissions still come through `role_permissions`.

## `permissions`

| Field | Type | Constraints / notes |
| :---- | :---- | :---- |
| `id` | bigint or UUID | PK |
| `key` | string | null: false; unique |
| `group` | string | null: false |
| `name` | string | null: false |
| `description` | text |  |
| `active` | boolean | null: false; default true |

Permissions are system-defined capabilities shipped with code. Because they are static lookup records, bigint IDs remain acceptable under ADR-002. UUIDs are also fine if consistency is preferred.

Examples:

```
system_settings.view
system_settings.manage

stores.view
stores.manage

users.view
users.manage
users.assign_roles

roles.view
roles.manage

workstations.view
workstations.manage

audit_events.view
```

I would not allow administrators to create arbitrary permission keys in the UI. The code must know what a permission means. Administrators may configure roles using the available permission catalog.

## `role_permissions`

| Field | Type | Constraints / notes |
| :---- | :---- | :---- |
| `role_id` | UUID | FK; null: false |
| `permission_id` | bigint/UUID | FK; null: false |
| `created_at` | timestamp | null: false |

Primary or unique constraint:

```
unique(role_id, permission_id)
```

Changes to the set should increment `roles.lock_version`.

---

# 7\. `user_roles` as role assignments

This table is more than a simple join table. I would call it `role_assignments`, which matches the business concept more accurately, but retaining `user_roles` is workable.

### Recommended fields

| Field | Type | Constraints / notes |
| :---- | :---- | :---- |
| `id` | UUID | PK; UUIDv7 |
| `user_id` | UUID | FK; null: false |
| `role_id` | UUID | FK; null: false |
| `store_id` | UUID | FK; nullable |
| `effective_on` | date | optional |
| `expires_on` | date | optional |
| `active` | boolean | null: false; default true |
| `assigned_by_id` | UUID | FK users; null: false |
| `created_at` | timestamp | null: false |
| `updated_at` | timestamp | null: false |

Interpretation:

* `store_id IS NULL`: organization-wide assignment.  
* `store_id IS NOT NULL`: assignment applies only to that store.

Effective permissions for store `S` are the union of permissions from active assignments where:

```
store_id IS NULL OR store_id = S
```

An ordinary user may enter store `S` only if at least one effective assignment applies to `S`.

### Important behavior

* A home/default store should affect navigation convenience only.  
* It must not grant access.  
* It must not restrict access otherwise granted by role assignments.  
* Global assignments grant access to all active stores.  
* Store assignments permit different roles at different stores.  
* Deactivated roles and expired assignments contribute no permissions.

For Phase 1, permissions should be additive. Explicit denials make the model much harder to explain and troubleshoot and should be deferred unless a real requirement emerges.

---

# 8\. `workstations`, not `registers`

We previously settled on **Workstation** as the durable configured identity. A future register session represents operational use of that workstation; a cash drawer is another concept.

### Recommended fields

| Field | Type | Constraints / notes |
| :---- | :---- | :---- |
| `id` | UUID | PK; UUIDv7 |
| `store_id` | UUID | FK; null: false |
| `code` | string | null: false |
| `name` | string | null: false |
| `description` | text |  |
| `active` | boolean | null: false; default true |
| `receipt_sequence` | bigint | null: false; default 0 |
| `activated_at` | timestamp | future provisioning support |
| `revoked_at` | timestamp |  |
| `last_seen_at` | timestamp | later synchronization use |
| `lock_version` | integer | null: false; default 1 |
| `created_at` | timestamp | null: false |
| `updated_at` | timestamp | null: false |

Constraint:

```
unique(store_id, code)
```

The workstation’s `code` becomes part of the permanent receipt identity, so it should not be freely editable once receipts exist.

However, I would consider deferring `receipt_sequence` until the POS persistence layer is implemented. Phase 1 only needs to establish the durable workstation identity and its store assignment.

Likewise, activation credentials and synchronization status belong to a future workstation-provisioning slice unless Phase 1 must actually launch a connected workstation client.

---

# 9\. Authentication

Phase 1 should implement central-server authentication only. Offline workstation authentication belongs with the POS/workstation implementation because it requires cached credentials and workstation synchronization policy.

### Minimum flows

* Initial administrator creation during installation  
* Sign in  
* Sign out  
* Session expiration  
* Password change  
* Administrator-initiated password reset  
* Account lock or throttling after repeated failures  
* Session revocation after user deactivation  
* Safe redirect when authorization is denied

Password-reset email can be deferred if ShelfSense does not yet have outbound-email infrastructure. An administrator can issue a temporary reset flow instead—but passwords should never be visible or transmitted back to the administrator.

### Session records

If sessions are stored server-side, use a technical table such as `user_sessions`:

| Field | Purpose |
| :---- | :---- |
| `id` | Opaque session identity or digest |
| `user_id` | Authenticated user |
| `created_at` | Session creation |
| `last_seen_at` | Idle timeout |
| `expires_at` | Absolute expiration |
| `ip_address` | Security context |
| `user_agent` | Security context |
| `revoked_at` | Explicit invalidation |

Store only a digest of the browser session token, not the usable bearer token.

These are authentication sessions, distinct from future POS `register_sessions`.

---

# 10\. Authorization request context

Every authenticated request should establish:

```
current_user
current_store
effective_permissions
```

The store selection flow should be:

1. User signs in.  
2. ShelfSense calculates accessible active stores.  
3. If there is exactly one, select it automatically.  
4. If there are several, show the store selector.  
5. If there are none, deny application access with a clear administrative message.  
6. Switching stores recalculates effective permissions.

Organization-wide administration pages may not require an active store, but they still require appropriate global authority.

A store-scoped role should not grant organization-wide management merely because the user navigates to a route without a store context. For example:

```
store-scoped users.view
```

may permit viewing users relevant to the current store, but not managing global identities across the installation. For Phase 1, the simpler policy is to require a globally assigned administration permission for organization-wide user and role management.

Authorization must be enforced in service/application logic, not only by hiding navigation links.

---

# 11\. Seeded roles and permissions

I would seed these initial roles:

| Role | Intended use |
| :---- | :---- |
| `system_administrator` | Complete organization-wide administration |
| `store_manager` | Store configuration, users assigned to that store, and workstations |
| `associate` | Basic store access; limited until later domains add capabilities |

The `associate` role may initially contain only:

```
stores.view
```

That is acceptable. It establishes store access even before POS permissions exist.

The exact Phase 1 permission catalog could be:

```
system_settings.view
system_settings.manage

stores.view
stores.create
stores.manage
stores.deactivate

users.view
users.create
users.manage
users.deactivate
users.assign_roles

roles.view
roles.create
roles.manage
roles.deactivate

workstations.view
workstations.create
workstations.manage
workstations.deactivate

audit_events.view
```

I prefer separate lifecycle permissions over a single broad `manage`, especially for users, stores, and workstations. Deactivation has more serious operational consequences than editing a name.

---

# 12\. Audit coverage

Phase 1 should audit both successful material actions and security-relevant failures.

### Always audit

* Successful sign-in  
* Failed sign-in where a known account or security threshold is involved  
* Sign-out and administrative session revocation  
* User creation, activation, deactivation, and password reset initiation  
* Role creation, change, activation, and deactivation  
* Permission additions/removals from roles  
* Role assignments and revocations  
* Store creation, material change, activation, and deactivation  
* Workstation creation, reassignment, activation, revocation, and deactivation  
* System-setting changes  
* Authorization denials for sensitive administrative actions

Ordinary page views do not need audit events. Viewing the audit log itself may be audited if you consider that operationally sensitive.

### Revised `audit_events`

The current pro forma needs updating for UUIDv7 and the accepted ADR:

| Field | Type | Notes |
| :---- | :---- | :---- |
| `id` | UUID | UUIDv7 |
| `occurred_at` | timestamp | When action occurred |
| `recorded_at` | timestamp | When audit event was persisted |
| `actor_type` | string | `user`, `system`, `integration`, `scheduled_job` |
| `actor_user_id` | UUID | nullable FK users |
| `actor_label` | string | historical snapshot |
| `store_id` | UUID | nullable |
| `workstation_id` | UUID | nullable |
| `user_session_id` | UUID/string | nullable |
| `action` | string | stable machine key |
| `outcome` | string | `succeeded`, `failed`, `denied` |
| `subject_type` | string |  |
| `subject_id` | UUID | nullable polymorphic identity |
| `subject_label` | string | snapshot |
| `reason_code` | string | nullable |
| `reason_text` | text | nullable |
| `correlation_id` | UUID |  |
| `before_values` | JSONB | selective |
| `after_values` | JSONB | selective |
| `metadata` | JSONB | redacted contextual data |
| `ip_address` | inet | nullable |
| `user_agent` | text | nullable |
| `application_version` | string |  |

I would use `before_values` and `after_values`, rather than the less expressive single `changes` object.

Audit creation should occur in the same database transaction as the successful configuration change. Failed authentication and authorization attempts are recorded independently because there is no successful business transaction.

---

# 13\. Bootstrap workflow

A fresh installation needs a deliberate bootstrap path:

1. Verify that the installation is uninitialized.  
2. Create `system_settings`.  
3. Create the first store.  
4. Create the protected `system` user.  
5. Seed the permission catalog.  
6. Seed protected system roles.  
7. Create the initial administrator.  
8. Assign `system_administrator` globally.  
9. Optionally create the first workstation.  
10. Record bootstrap audit events.  
11. Permanently disable the initialization route.

Bootstrap must be transactionally safe. A partial installation should either roll back or resume deterministically; it must not leave ShelfSense accessible without an administrator.

Bootstrap credentials should come from an explicit installation workflow or deployment secret—not hard-coded seed credentials.

---

# 14\. Suggested implementation sequence

## Slice 1: Installation and persistence

* UUIDv7 support  
* Core migrations  
* Singleton settings  
* Seed permissions and system roles  
* Protected system user  
* Bootstrap administrator and first store

## Slice 2: Authentication

* Sign-in/sign-out  
* Session storage and expiration  
* Password change/reset  
* Account deactivation and session revocation  
* Authentication audit events

## Slice 3: Store context and authorization

* Scoped role assignments  
* Effective-permission evaluator  
* Accessible-store calculation  
* Store selector  
* Route and service authorization  
* Authorization denial handling

## Slice 4: Administration

* System settings editor  
* Store administration  
* User administration  
* Role/permission administration  
* Role-assignment management  
* Workstation administration

## Slice 5: Audit visibility and hardening

* Audit-event browser  
* Filters by actor, store, action, subject, outcome, and date  
* Concurrency checks using `lock_version`  
* Protected-record invariants  
* Security and authorization tests

---

# 15\. Phase 1 acceptance criteria

Phase 1 is complete when all of the following are demonstrated:

* A fresh installation can be initialized without manual database editing.  
* The initial administrator can sign in and sign out.  
* A user cannot authenticate with an invalid password or when inactive.  
* Each interactive person has an individual account.  
* An administrator can create a store, user, role, role assignment, and workstation.  
* A user sees only stores reached through an effective role assignment.  
* A user can have different effective permissions in different stores.  
* A global assignment applies to every active store.  
* Store switching recalculates permissions.  
* Unauthorized requests fail even if their URL is entered directly.  
* Deactivating a user prevents further access and revokes sessions.  
* The final global system administrator cannot be removed accidentally.  
* The protected system actor cannot be deleted or deactivated.  
* Permission keys are seeded by the application, not freely invented in the UI.  
* Material configuration and security actions create append-only audit events.  
* Audit records contain actor, action, outcome, subject, time, and applicable store context.  
* Concurrent settings or role edits do not silently overwrite one another.  
* Historical users, stores, roles, and workstations are deactivated rather than erased once referenced.

## Decisions I recommend settling before schema design

There are four details worth resolving next:

1. Rename `registers` to `workstations`.  
2. Rename `user_roles` to `role_assignments`, or retain the existing name with assignment fields.  
3. Decide whether administrators may manage users only through a global permission in Phase 1, which I recommend.  
4. Decide whether the initial administrator account uses the normal authorization engine exclusively, which I also recommend, with protection against removing the last global system administrator.

Once those are settled, we can define the exact Phase 1 tables in your preferred field/type/constraints/notes format.

---

All four Phase 1 decisions are settled:

1. Rename `registers` to `workstations`.  
2. Rename `user_roles` to `role_assignments`.  
3. Require globally scoped permissions for organization-wide user administration.  
4. Use the normal role-and-permission engine for administrators, while preventing removal of the final active global `system_administrator`.

The resulting authorization model is:

* `role_assignments.store_id IS NULL` → organization-wide authority.  
* `role_assignments.store_id = <store>` → authority only within that store.  
* Organization-wide administration requires the relevant permission through a global role assignment.  
* Store-scoped permissions never implicitly become global.  
* The initial administrator has a global `system_administrator` assignment.  
* `system_administrator` remains a normal role whose capabilities come from `role_permissions`; it is not an authorization bypass.  
* ShelfSense must always retain at least one active, sign-in-capable user with an effective global `system_administrator` assignment.

The finalized Phase 1 core tables are therefore:

```
system_settings
stores
users
roles
permissions
role_permissions
role_assignments
workstations
user_sessions
audit_events
```

This gives us a stable basis for defining the exact schema, constraints, indexes, protected-record rules, and lifecycle behavior for each table.
