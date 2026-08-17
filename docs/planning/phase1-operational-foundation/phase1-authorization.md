# Phase 1 Authorization Contract

This document is the authoritative Phase 1 permission catalog, role grants, assignment-scope rules, and evaluation sequence. Schema field details live in [phase1-schema.md](phase1-schema.md). Phase scope and acceptance criteria live in [phase1-plan.md](phase1-plan.md).

## Concepts

| Concept | Meaning |
|---|---|
| `permissions.scope_type` | Where a permission may take effect: `global`, `store`, or `either`. |
| `roles.assignment_scope` | Where a role may be assigned: `global`, `store`, or `either`. |
| Global role assignment | `role_assignments.store_id IS NULL` — organization-wide authority. |
| Store-scoped role assignment | `role_assignments.store_id` populated — authority only in that store. |

Permission `scope_type` alone cannot prevent an inappropriate global role assignment. Role `assignment_scope` must also be enforced when creating assignments.

## Permission catalog

| Permission | scope_type | group_key |
|---|---|---|
| `system_settings.view` | global | system_settings |
| `system_settings.manage` | global | system_settings |
| `stores.view` | either | stores |
| `stores.create` | global | stores |
| `stores.manage` | either | stores |
| `stores.deactivate` | global | stores |
| `users.view` | global | users |
| `users.create` | global | users |
| `users.manage` | global | users |
| `users.deactivate` | global | users |
| `users.assign_roles` | global | users |
| `users.revoke_sessions` | global | users |
| `roles.view` | global | roles |
| `roles.create` | global | roles |
| `roles.manage` | global | roles |
| `roles.deactivate` | global | roles |
| `registers.view` | either | registers |
| `registers.create` | either | registers |
| `registers.manage` | either | registers |
| `registers.deactivate` | either | registers |
| `audit_events.view` | either | audit_events |

Permission keys are seeded by application code. The UI must not invent new permission semantics.

## Meaning of `scope_type`

### `global`

Meaningful only through a global role assignment. Example: `users.manage`, `system_settings.manage`.

### `store`

Evaluated only in a store context through a store-scoped assignment (or a global assignment that contributes store-context authority when the contract allows). Phase 1 seeded catalog does not currently use pure `store` keys; reserved for later domains.

### `either`

- A **global** grant permits the action organization-wide (any store, or org-wide subjects).
- A **store-scoped** grant permits the action only for the current assigned store.

Examples:

- Global `stores.manage` → manage any store.
- Store-scoped `stores.manage` → manage only the current store.
- Global `audit_events.view` → organization-wide audit visibility, including events with `store_id IS NULL`.
- Store-scoped `audit_events.view` → only events for that store. Events with `store_id IS NULL` must not leak to store-scoped viewers.

## Seeded roles

| Role | assignment_scope | Permissions |
|---|---|---|
| `system_administrator` | global | Entire catalog |
| `store_manager` | store | `stores.view`, `stores.manage`, `registers.view`, `registers.create`, `registers.manage`, `registers.deactivate`, `audit_events.view` |
| `associate` | store | `stores.view` |

`system_administrator` is a normal role populated through `role_permissions`. It is not an authorization bypass.

Future custom roles may set `assignment_scope` to `global`, `store`, or `either`. Seeded system roles keep the scopes above.

## Role-assignment authority

- Granting or revoking any role requires effective `users.assign_roles` from a **global** assignment.
- `system_administrator` may only be assigned with `store_id IS NULL`.
- `store_manager` and `associate` may only be assigned with a populated `store_id`.
- System roles cannot be deleted. Their permission membership is code-seeded.

## Store selection and permission evaluation

Do not use `stores.view` to discover accessible stores. That creates a circular dependency.

Required sequence:

1. Derive accessible active stores from effective **role assignments**:
   - A global assignment contributes every active store.
   - A store-scoped assignment contributes that store when active.
2. Select or validate `current_store` (auto-select when exactly one; selector when several; deny when none).
3. Compute `effective_permissions` as the union of permissions from:
   - effective global assignments, and
   - effective assignments for `current_store`,
   respecting each permission’s `scope_type` and each role’s `assignment_scope`.
4. Authorize the requested action against `effective_permissions` (and subject-store rules for `either` permissions).

Organization-wide administration pages may not require an active store, but they still require the relevant permission through a global assignment.

## Last global administrator

ShelfSense must always retain at least one active, sign-in-capable human user with an effective global `system_administrator` assignment.

Granting, revoking, or otherwise removing protected assignments (including deactivating the user or role) must occur through a transactional service that locks the relevant global `system_administrator` assignments before checking the invariant. Model validations may provide friendly feedback but are not sufficient under concurrency.

## System actor

The protected system user (`actor_type = system`) cannot authenticate, cannot receive interactive sessions or role assignments, and is exempt from password-presence validation. Authentication must reject system actors even if a password digest exists.
