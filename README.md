# ShelfSense

ShelfSense is an inventory, purchasing, customer-service, and point-of-sale system for independent bookstores. Each installation serves one organization operating one or more stores. The current application is a central, online Rails system; standalone/offline Terminal operation is a future program governed by [ADR-018](docs/adr/ADR-018-pos-runtime-and-deployment.md) and [ADR-021](docs/adr/ADR-021-register-and-terminal-identity.md).

## Project status

The operational foundation through **Phase 9** is implemented on `main`, including:

- Organization, stores, users, scoped authorization, and audit
- Merchandise, identifiers, classification, pricing, and inventory valuation
- Register sales, tenders, returns, post-void, session close, and receipt history
- Suppliers, customer requests, reservations, purchase orders, receiving, and corrections
- Customer identity, contact lookup, duplicate suggestions, and merge
- Catalog and bibliographic enrichment with reviewed external-data apply
- The Warm Parchment UX foundation, grouped administrative navigation, and ActionButtonHelper adoption on reference and non-purchasing screens

UDS-5 (administrative composition) is Proposed in [uds-5-plan.md](docs/planning/ux-design-system/uds-5-plan.md) and is not yet on `main`.

Forward domain work is sequenced in the [canonical roadmap](docs/planning/roadmap.md). Phase 10 (stored value and its financial event contract) is proposed but is not identified as the primary stream; later phases cover cash accountability, used buyback, customer-service expansion, and financial/reporting closeout.

## Technology

- Ruby 3.4.9 and Rails 8.1
- PostgreSQL 17
- Puma and Propshaft
- Importmap, Turbo, and Stimulus where interactive workflows require them
- Solid Cache, Solid Queue, and Solid Cable
- Minitest, Capybara/Selenium, axe-core, RuboCop, Brakeman, Bundler Audit, and Importmap Audit
- GitHub Actions continuous integration

ShelfSense favors server-rendered Rails. The Register workspace uses Hotwire; administrative surfaces use it only where an established interaction requires it.

## Quick start

Local development is Docker-only. Install Docker Desktop and Git; Ruby, Rails, Bundler, PostgreSQL, gems, and browser-test dependencies run in containers.

```sh
docker compose build
docker compose run --rm web bin/setup --skip-server
docker compose up
```

Open <http://localhost:3000>. The health endpoint is <http://localhost:3000/up>.

Use the project helper for application commands. It uses the running `web` container when available and otherwise starts a temporary one:

```sh
./dev/rails-docker bin/rails console
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails test
```

For bootstrap, database, environment, and troubleshooting instructions, see the [development guide](docs/development.md).

## Validation

Run the complete local CI entry point:

```sh
./dev/rails-docker bin/ci
```

During development, run the smallest relevant test set first. The individual CI categories are:

```sh
./dev/rails-docker bin/rails test
./dev/rails-docker bin/rails test:system
./dev/rails-docker bin/rubocop
./dev/rails-docker bin/brakeman --no-pager
./dev/rails-docker bin/bundler-audit
./dev/rails-docker bin/importmap audit
```

See [Testing and CI](docs/testing.md) for browser-test behavior and the active GitHub Actions jobs.

## Architecture at a glance

- ShelfSense is single-tenant and multi-store. Store scope remains explicit wherever operationally meaningful.
- The central server owns master data, configuration, customer records, purchasing, and consolidated projections.
- A **Register** is the durable logical checkout identity; a future **Terminal** is a concrete POS client or device.
- Completed business facts are immutable. Corrections use reversals, compensating records, or explicit reconciliation.
- Durable domain records use application-assigned UUIDv7 identifiers; human-facing document numbers remain separate.
- Money is stored as integer minor units. Operational timestamps are UTC instants with explicit store business dates where required.
- Retryable commands use idempotency keys and payload hashes. Asynchronous delivery uses a transactional outbox and idempotent consumers.
- Authorization is additive and may be global or store-scoped; there is no administrator bypass around the ordinary permission engine.

Accepted [Architecture Decision Records](docs/adr/README.md) govern implementation. Proposed ADRs describe unresolved policy and are not settled decisions.

## Domain map

Named domains for ownership. `buyback` and `reports` are reserved for later phases; they are not implemented on `main`.

| Domain | Responsibility |
|---|---|
| `platform` | Cross-domain infrastructure, identity, audit, concurrency, and delivery |
| `administration` | Organization configuration, stores, users, permissions, and operational setup |
| `financial` | Financial classification, tax, accounting configuration, and financial records |
| `customers` | Customer identity, contact, requests, reservations, and customer-owned relationships |
| `merchandise` | Catalog, variants, classification, pricing, inventory units, and inventory |
| `purchasing` | Suppliers, orders, purchase orders, receiving, and supplier-facing workflows |
| `pos` | Sales, returns, tenders, sessions, business dates, and Register operation |
| `buyback` | Acquisition and valuation of used merchandise from customers (Phase 12) |
| `reports` | Operational, financial, and analytical reporting (Phase 14 closeout) |

## Documentation

Start with the [documentation index](docs/README.md). The primary entry points are:

- [Canonical roadmap](docs/planning/roadmap.md) — implemented milestones, current sequencing, and explicit deferrals
- [Architecture Decision Records](docs/adr/README.md) — accepted and proposed cross-cutting policy
- [Development guide](docs/development.md) — Docker workflow, bootstrap, database operations, and troubleshooting
- [Testing and CI](docs/testing.md) — active validation and system-test requirements
- [UX design system](docs/planning/ux-design-system/README.md) and [UX conventions](docs/ux-conventions.md)
- [GitHub work management](docs/github-workflow.md) — branch, PR, issue, milestone, and release conventions
- [Contributor and coding-agent rules](AGENTS.md) — required implementation and review practices

Phase planning packets remain the authority for their implemented workflows and contracts; the roadmap links the canonical packet for each milestone.

## Contributing

Read [AGENTS.md](AGENTS.md) before changing the project. Keep changes narrowly scoped, preserve canonical domain language, and update tests and documentation whenever behavior, schema, permissions, or workflows change.
