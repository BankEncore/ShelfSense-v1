# ShelfSense

ShelfSense is an inventory, purchasing, customer-service, and point-of-sale system for independent bookstores. It is designed for one organization operating one or more stores, with a central organization server and store workstations that can continue ordinary checkout during temporary connectivity loss.

The project is in the planning and foundation stage. Phase 0 established the governing architecture decisions. A Ruby on Rails application foundation is now in place; Phase 1 business implementation has not yet begun. Phase 1 will deliver the minimum operable foundation needed to initialize and administer a store, authenticate users, authorize store access, configure workstations, and record audit events.

## Goals

ShelfSense is intended to provide a coherent operational system for:

- Books, music, video, games, periodicals, sidelines, café items, services, and other bookstore merchandise
- New, used, remainder, promotional, and consignment inventory
- Purchasing, receiving, supplier returns, customer orders, and reservations
- Fast, keyboard-friendly point of sale with offline continuity
- Sales, returns, tenders, stored value, buybacks, and cash accountability
- Store-level inventory authority with organization-wide reporting
- Exact financial calculations and reconstructable operational history

ShelfSense is a single-tenant application: each installation serves one organization, while retaining explicit store scope wherever operationally meaningful.

## Technology foundation

The accepted application scaffold currently uses:

- Ruby 3.4.9
- Rails 8.1
- PostgreSQL
- Puma
- Propshaft
- Rails' database-backed Solid Cache, Solid Queue, and Solid Cable adapters
- Minitest, RuboCop, Brakeman, and Bundler Audit
- GitHub Actions for continuous integration

The frontend dependency strategy is not yet settled. Importmap, Turbo, and Stimulus gems are present in the scaffold, but Importmap has not been installed or configured. Browser-based system testing is also intentionally deferred. See [Testing and CI](docs/testing.md).

## Quick start

Local development is Docker-only. Install Docker Desktop and VS Code; Ruby, Rails, Bundler, PostgreSQL, gems, and command-line utilities run inside containers.

```sh
docker compose build
docker compose run --rm web bin/setup --skip-server
docker compose up
```

Open <http://localhost:3000>. The Rails health endpoint is available at <http://localhost:3000/up>.

Use the project helper for application commands. It executes in the running `web` container when available and otherwise starts a temporary container:

```sh
./dev/rails-docker bin/rails console
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails test
```

See the [development guide](docs/development.md) for the complete Docker workflow, database behavior, validation commands, volume management, and troubleshooting.

## Validation

Run the same categories of checks enforced by CI:

```sh
./dev/rails-docker bin/rails test
./dev/rails-docker bin/rubocop
./dev/rails-docker bin/brakeman --no-pager
./dev/rails-docker bin/bundler-audit
```

CI prepares its PostgreSQL test database before running the Rails suite. See [Testing and CI](docs/testing.md) for the active checks and the conditions for restoring system tests and JavaScript dependency auditing.

## Architecture at a glance

ShelfSense uses a central-server/store-workstation topology:

- The central server owns master data, configuration, users, permissions, purchasing, customer records, and consolidated projections.
- Workstations cache the reference data required for checkout and originate local POS operations.
- Ordinary sales may complete locally while disconnected and synchronize later.
- Completed business facts remain immutable; corrections use reversals, compensating records, or explicit reconciliation.
- UUIDv7 identifiers allow durable records to originate without a central sequence allocator.
- Human-facing document numbers are separate from technical identifiers.
- Transactional outboxes and idempotent consumers provide at-least-once delivery across asynchronous boundaries.

Detailed architectural policy is recorded in the [Architecture Decision Records](docs/adr/README.md). Accepted ADRs govern implementation. Proposed ADRs identify unresolved policy and must not be treated as settled.

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

### Phase 0: Architecture and planning

Status: complete.

Phase 0 established deployment topology, data authority, offline behavior, identifiers, receipt numbering, value types, auditing, concurrency, idempotency, asynchronous delivery, naming, record lifecycle, immutability, and reconciliation policy.

Two policies remain proposed and require later business decisions:

- Offline returns
- Business-day closure when a workstation has not reported

### Phase 1: Operable foundation

Status: operable foundation implemented (bootstrap, authentication, authorization, administration, audit).

Phase 1 uses server-rendered Rails HTML. Turbo and Stimulus may be installed when a specific interaction requires them; no client-side application framework or JavaScript package-management strategy is required for early Phase 1 slices. Durable domain identifiers use Rails-generated UUIDv7 (`SecureRandom.uuid_v7`) while the project remains on PostgreSQL 17.

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

### Phase 2: Financial classification and merchandise foundation

Status: implemented (GL/tax/departments, merchandise reference data, products with mandatory primary identifiers, variants with immutable `221` SKUs, identifier registry tombstones, lookup, and CSV import).

Phase 2 extends Phase 1 patterns for organization-wide catalog master data:

- Financial classifications: `gl_accounts`, `tax_classes`, `departments`
- Merchandise reference: `merchandise_classes`, `merchandise_categories`, `merchandise_conditions`
- Catalog: `products` (mandatory `primary_identifier`, enter-external or generate-`222` at create), `product_variants` (immutable generated `221` SKU), `identifier_registry`
- Unified identifier lookup (`merchandise.lookup`) and minimal CSV import (`merchandise.import`)

The Phase 2 deliverable is:

> An authorized user can configure financial classifications, create a product with one or more sellable standard or used variants (each with an immutable `221` SKU), assign department/tax/class/price (and condition for used variants), and retrieve by product identifier, variant SKU, or variant industry identifier.

Phase 2 does not include inventory, journal posting, tax calculation, suppliers/purchasing, POS, buyback, promotions, or bibliographic enrichment.

### Phase 2.1: Merchandise correctness and operability

Status: implemented (reference-data reactivation, immutable normalized codes, GL category↔type and buyback invariants, `default_supplier_returnable`, pricing-method-aware variant defaults, product category/list-price UX, CSV import template).

Phase 2.1 is a focused patch between the Phase 2 merchandise foundation and Phase 3 inventory. It hardens merchandise contracts inventory will depend on without introducing inventory, purchasing, buyback, or POS workflows.

The Phase 2.1 deliverable is:

> An authorized administrator can reactivate core financial and merchandise reference data, create products and variants with complete fields and pricing-method-aware defaults, and use a documented CSV import template, with database-enforced merchandise and GL-account invariants.

Authoritative plan: [phase-2.1-platform-and-merchandise-refinements.md](docs/planning/phase2.1-platform-merchandise-refinement/phase-2.1-platform-and-merchandise-refinements.md).

### Phase 2.2: Administrative UX foundation

Status: implemented (Propshaft design tokens and shell, shared admin partials/helpers, product reference flow with search/filter/pagination, currency form UX via `Money::ParseCents`, Stores and Merchandise Classes adoption).

Phase 2.2 is an HTML/CSS-first presentation pass between merchandise foundation work and Phase 3 inventory. It does not install Hotwire and does not add inventory behavior.

The Phase 2.2 deliverable is:

> An authorized administrator can navigate a consistent administrative shell, manage products with searchable/filterable indexes and dollar-oriented price fields, and use the same presentation patterns on Stores and Merchandise Classes.

Authoritative plan: [phase-2.2-ux-foundation.md](docs/planning/phase2.2-ux-foundation/phase-2.2-ux-foundation.md). Conventions: [UX conventions](docs/ux-conventions.md).

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

## Documentation

Start with the [documentation index](docs/README.md). Key references include:

- [Architecture Decision Records](docs/adr/README.md)
- [Phase 1 plan](docs/planning/phase1-operational-foundation/phase1-plan.md), [schema](docs/planning/phase1-operational-foundation/phase1-schema.md), and [authorization contract](docs/planning/phase1-operational-foundation/phase1-authorization.md)
- [Phase 2 plan](docs/planning/phase2-financial-classification-and-merchandise-foundation/phase2-plan.md), [schema](docs/planning/phase2-financial-classification-and-merchandise-foundation/phase-2-database-schema.md), and [authorization contract](docs/planning/phase2-financial-classification-and-merchandise-foundation/phase2-authorization.md)
- [Phase 2.2 UX foundation](docs/planning/phase2.2-ux-foundation/phase-2.2-ux-foundation.md) and [UX conventions](docs/ux-conventions.md)
- [Development guide](docs/development.md)
- [Testing and CI](docs/testing.md)
- [GitHub work management](docs/github-workflow.md)
- [Contributor and coding-agent rules](AGENTS.md)

When implementation reveals a conflict with an accepted ADR, propose a new ADR that supersedes the old decision. Do not silently diverge in code.

## Contributing

Keep changes narrowly scoped, preserve established domain language, and update tests and documentation with behavior changes. Read [AGENTS.md](AGENTS.md) before modifying the project.
