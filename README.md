# ShelfSense

ShelfSense is an inventory, purchasing, customer-service, and point-of-sale system for independent bookstores. It is designed for one organization operating one or more stores, with a central organization server and store workstations that can continue ordinary checkout during temporary connectivity loss.

The project is currently in the planning and foundation stage. Phase 0 established the governing architecture decisions. Phase 1 will deliver the minimum operable foundation needed to initialize and administer a store, authenticate users, authorize store access, configure workstations, and record audit events.

## Goals

ShelfSense is intended to provide a coherent operational system for:

- Books, music, video, games, periodicals, sidelines, cafÃ© items, services, and other bookstore merchandise
- New, used, remainder, promotional, and consignment inventory
- Purchasing, receiving, supplier returns, customer orders, and reservations
- Fast, keyboard-friendly point of sale with offline continuity
- Sales, returns, tenders, stored value, buybacks, and cash accountability
- Store-level inventory authority with organization-wide reporting
- Exact financial calculations and reconstructable operational history

ShelfSense is a single-tenant application: each installation serves one organization, while retaining explicit store scope wherever operationally meaningful.

## Architecture at a glance

ShelfSense uses a central-server/store-workstation topology:

- The central server owns master data, configuration, users, permissions, purchasing, customer records, and consolidated projections.
- Workstations cache the reference data required for checkout and originate local POS operations.
- Ordinary sales may complete locally while disconnected and synchronize later.
- Completed business facts remain immutable; corrections use reversals, compensating records, or explicit reconciliation.
- UUIDv7 identifiers allow durable records to originate without a central sequence allocator.
- Human-facing document numbers are separate from technical identifiers.
- Transactional outboxes and idempotent consumers provide at-least-once delivery across asynchronous boundaries.

Detailed architectural policy is recorded in [`shelfsense-adrs/`](shelfsense-adrs/README.md). Accepted ADRs govern implementation. Proposed ADRs identify unresolved policy and must not be treated as settled.

## Domain map

| Domain | Responsibility |
|---|---|
| `platform` | Core technical infrastructure and cross-domain system concerns |
| `administration` | System configuration, stores, users, permissions, and operational setup |
| `financial` | Financial classification, tax, accounting configuration, and financial records |
| `customers` | Customer identities, relationships, exemptions, requests, and reservations |
| `merchandise` | Products, variants, inventory units, classification, pricing, and inventory concepts |
| `purchasing` | Suppliers, purchase orders, receiving, shipments, and returns to suppliers |
| `pos` | Sales, returns, tenders, business days, sessions, and point-of-sale operation |
| `buyback` | Acquisition of used merchandise from customers |
| `reports` | Operational, financial, and analytical reporting |

## Roadmap

### Phase 0 Architecture and planning

Status: complete.

Phase 0 established deployment topology, data authority, offline behavior, identifiers, receipt numbering, value types, auditing, concurrency, idempotency, asynchronous delivery, naming, record lifecycle, immutability, and reconciliation policy.

Two policies remain proposed and require later business decisions:

- Offline returns
- Business-day closure when a workstation has not reported

### Phase 1 Operable foundation

Phase 1 implements only what is required to initialize, operate, and administer the application foundation:

- `system_settings`
- `stores`
- `users`
- `roles`
- `permissions`
- `role_permissions`
- `role_assignments`
- `workstations`
- `user_sessions`
- `audit_events`
- Authentication and authorization
- Bootstrap of the organization, first store, protected system actor, and first administrator
- Administration of essential configuration

The Phase 1 deliverable is:

> A user can sign in, access an authorized store, and manage essential system configuration according to globally or store-scoped permissions, with material actions recorded in the audit log.

Phase 1 does not include business days, POS sessions, cash drawers, transactions, inventory, merchandise, customers, suppliers, offline workstation synchronization, or purchasing workflows.

## Phase 1 authorization model

Permissions are additive and supplied by roles:

- A role assignment with no `store_id` is global.
- A role assignment with a `store_id` applies only in that store.
- A global assignment contributes authority in every active store.
- Store-scoped authority never becomes organization-wide authority implicitly.
- Organization-wide user, role, permission, store, and system-setting administration requires the applicable permission through a global assignment.
- Administrators use the ordinary role-and-permission engine; there is no authorization bypass.
- ShelfSense must always retain at least one active, sign-in-capable user with an effective global `system_administrator` assignment.

Initial roles are expected to include `system_administrator`, `store_manager`, and `associate`. Permission keys are defined by application code; administrators compose roles from the available catalog rather than inventing new permission semantics in the UI.

## Governing data conventions

- Durable distributed business records use UUIDv7 primary keys.
- Tables use plural `snake_case`; foreign keys use singular `_id` names.
- Authoritative monetary values use signed integer minor units, normally `_cents`.
- Conventional percentages use integer `_basis_points` when that precision is sufficient.
- Calendar concepts use `date`; event instants use timezone-aware timestamps stored as UTC.
- Store operational records also retain the applicable business date where required.
- Mutable aggregate roots use an integer version for optimistic concurrency.
- Retryable commands use scoped idempotency keys and payload hashes.
- Effective configuration is superseded; completed facts are reversed or compensated, not edited.
- Lifecycle-specific states such as inactive, revoked, expired, discontinued, or cancelled are preferred to generic soft deletion.

## Project status and setup

The implementation language, frameworks, build commands, and deployment tooling have not yet been formally selected for this project. Add reproducible setup, migration, test, and run instructions here as soon as the initial scaffold is accepted. Until then, architecture and schema work should remain technology-neutral and should not imply that an exploratory stack choice is settled.

## Documentation

- [`shelfsense-adrs/README.md`](shelfsense-adrs/README.md) Architecture Decision Record index
- [`AGENTS.md`](AGENTS.md) Rules for contributors and coding agents
- `docs/` Domain models, workflows, schema reference, glossary, security guidance, and roadmap documentation as they are added

When implementation reveals a conflict with an accepted ADR, propose a new ADR that supersedes the old decision. Do not silently diverge in code.

## Contributing

Keep changes narrowly scoped, preserve established domain language, and update tests and documentation with behavior changes. Read [`AGENTS.md`](AGENTS.md) before modifying the project.
