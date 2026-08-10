Your domain list is a solid starting point, but the schema worksheet is not yet ready to become migrations. The best next step is to turn it into a development model organized around domain ownership, dependencies, and vertical workflows—not simply build its 42 current tables from top to bottom.

## 1\. Refine domain ownership

The largest structural issue is that `administration` currently owns many tables that actually belong to other business domains. Administration is better treated as an application interface for managing configuration, not as the owner of everything configurable.

| Domain | Tables/capabilities it should own |
| :---- | :---- |
| Platform | users, authentication, roles, permissions, stores, system settings, audit events, integrations, synchronization |
| Administration | Administrative workflows and screens; preferably few or no uniquely owned business tables |
| Financial | GL accounts, departments/accounting mappings, tax classes, tax rates, tax rules, journal entries |
| Customers | Customers, contact information, exemptions, customer requests/reservations |
| Merchandise | Products, variants, creators, relationships, categories, classes, conditions, pricing, inventory |
| Purchasing | Suppliers, replenishment demand, purchase orders, shipments, receipts, supplier returns |
| POS | Business days, register sessions, transactions, lines, discounts, taxes, tenders, cash movements, stored value |
| Buyback | Buyback transactions, offers, acquired units, seller identification, payout |
| Reports | Read models, exports, and reporting queries; generally not a source-of-truth transactional domain |

For example, `gl_accounts` should be owned by Financial even though administrators configure them. Likewise, merchandise classes and conditions belong to Merchandise.

This avoids a “miscellaneous administration domain” that every other module must depend on.

## 2\. Use a dependency-oriented structure

A reasonable high-level dependency map is:

```
flowchart TD
    P["Platform"]
    F["Financial configuration"]
    M["Merchandise"]
    I["Inventory"]
    C["Customers"]
    B["Buyback"]
    U["Purchasing"]
    S["POS"]
    R["Reports"]

    P --> F
    P --> M
    F --> M
    M --> I
    M --> U
    C --> U
    I --> S
    C --> S
    U --> I
    B --> I
    S --> F
    U --> F
    B --> F
    S --> R
    I --> R
```

Inventory is worth treating as an internal subdomain within Merchandise, even if it remains in the same code module initially. It has distinct invariants, transactions, and integration requirements.

## 3\. Organize development by vertical slices

Do not attempt to complete an entire domain before testing a real workflow. Build thin end-to-end slices that prove the architecture.

### Phase 0 — Architecture and contracts

Decide and document:

* Single-tenant assumptions  
* UUID versus bigint identity policy  
* Server and POS-terminal application boundaries  
* Offline ownership and synchronization rules  
* Money, percentages, dates, and timestamps  
* Audit-event policy  
* Optimistic concurrency and idempotency  
* Domain-event/outbox strategy  
* Naming conventions  
* Which records may be edited versus superseded or reversed

For offline POS, explicitly distinguish:

* Authoritative organization/store data  
* Terminal-cached reference data  
* Terminal-originated operations  
* Server-assigned values such as final receipt numbers  
* Conflict-free append-only records  
* Records that require conflict resolution

### Phase 1 — Operable foundation

Authoritative Phase 1 documents:

* [phase1-plan.md](phase1-operational-foundation/phase1-plan.md) — scope, slices, acceptance criteria  
* [phase1-schema.md](phase1-operational-foundation/phase1-schema.md) — tables, fields, constraints  
* [phase1-authorization.md](phase1-operational-foundation/phase1-authorization.md) — permission catalog, role grants, evaluation rules  

Implement only what is necessary to run and administer one store:

* `system_settings`  
* `stores`  
* `users`  
* `roles`  
* `permissions`  
* `role_permissions`  
* `role_assignments`  
* `workstations`  
* `user_sessions`  
* `audit_events`  
* authentication and authorization  
* audit-event recording  

Deliverable: a user can sign in, access an authorized store, and manage essential system configuration according to globally or store-scoped permissions, with material actions recorded in the audit log.

### Phase 2 — Financial classification and merchandise foundation

Status: implemented.

Authoritative Phase 2 documents:

* [phase2-plan.md](phase2-financial-classification-and-merchandise-foundation/phase2-plan.md) — scope, slices, completion criteria  
* [phase-2-database-schema.md](phase2-financial-classification-and-merchandise-foundation/phase-2-database-schema.md) — tables, fields, constraints  
* [phase2-authorization.md](phase2-financial-classification-and-merchandise-foundation/phase2-authorization.md) — permissions and role grants  

Implement:

* `gl_accounts`, `tax_classes`, `departments`  
* `merchandise_classes`, `merchandise_categories`, `merchandise_conditions`  
* `products` (mandatory primary identifier), `product_variants`, `identifier_registry`  
* unified identifier lookup and minimal CSV import  

Deliverable: an authorized user can configure financial classifications, create a product with one or more sellable variants (each with an immutable `221` SKU), assign department/tax/class/condition/price, and retrieve by product identifier, variant SKU, or variant industry identifier.

Avoid inventory, tax calculation, journal posting, and bibliographic enrichment in this phase.

### Phase 3 — Inventory foundation

Implement:

* `inventory_ledger_entries`  
* `inventory_balances`  
* inventory adjustments and adjustment lines  
* adjustment reasons  
* individually tracked `inventory_units`  
* stock availability calculations

Deliverable: establish opening inventory, adjust it, and view an auditable balance.

I would retain the earlier invariant:

```
available = on_hand - reserved - unavailable
```

The ledger is authoritative; the balance is a maintained projection.

### Phase 4 — First POS vertical slice

Initially support:

* one active business day  
* one register session  
* product sale lines  
* cash tender  
* tax calculation  
* transaction completion  
* inventory posting  
* receipt assignment  
* basic offline operation and synchronization

Deliverable: scan an item, tender cash, complete a sale, reduce inventory, and reproduce the transaction after synchronization.

This is the most important architectural proof. It exercises Platform, Merchandise, Inventory, Financial configuration, and POS together.

### Phase 5 — Full POS operations

Add:

* suspended transactions and reservations  
* card/check/other tenders  
* mixed tenders  
* returns and refunds  
* discounts and price overrides  
* cash movements  
* session and business-day closing  
* stored value  
* post-void/reversal support  
* offline recovery and conflict handling

### Phase 6 — Customers and requests

Add:

* customer records  
* reservations  
* special-order requests  
* expiration and cancellation  
* tax exemptions  
* customer history

### Phase 7 — Purchasing and receiving

Add:

* supplier sources for products/variants  
* replenishment demand or order requests  
* purchase orders and lines  
* shipments  
* receipts and receipt lines  
* partial receiving  
* backorders and cancellations  
* supplier returns  
* inventory and financial posting

### Phase 8 — Buyback

Add:

* buyback transaction  
* customer/seller details  
* offer lines  
* cash/store-credit payout  
* accepted merchandise units  
* condition and pricing decisions  
* inventory and financial posting

### Phase 9 — Financial posting and reporting

Build journal posting throughout the earlier phases, but defer a full accounting/reporting interface until the operational sources are stable.

Reports should primarily consume projections of operational data rather than introduce duplicate source-of-truth tables.

## 4\. Immediate schema problems to resolve

The worksheet contains several issues that would prevent direct implementation.

### Referenced but undefined tables

* `users`  
* `role_permissions`  
* `user_roles`  
* `purchase_orders`  
* `stock_units`  
* `stored_value_accounts`

`stock_units` appears to mean `inventory_units`; choose one canonical name.

### Apparent typos or malformed fields

* `producsts` → `products`  
* `related_prodict_id` → `related_product_id`  
* `occured_on` → `occurred_at` or `occurred_on`  
* `registers.store_id` is marked `auto_increment`; it should be an FK to `stores`  
* `customers.customer_requests.created_by_id` and `updated_by_id` are typed `datetime`; they should be the user PK type  
* Several `orders` quantity fields have no type  
* `transactions.status` combines type and default in the type column  
* `tender_types` says `non` in enums but defaults to `none`  
* `reference2_label` appears to be missing  
* `cancelled_by_id` and `voided_by_id` have no type or FK

### Incomplete major areas

* Domains list includes Buyback and Reports, but neither has tables.  
* Purchasing currently has only `suppliers` and `orders`; it does not yet model purchase orders, lines, shipments, receipts, or supplier returns.  
* POS does not yet model reservations, cash movements, stored value, transaction totals, or offline synchronization.  
* Platform has roles and permissions but no users or join tables.  
* Product supplier sourcing is too limited for multiple suppliers and supplier-specific costs/terms.  
* Inventory adjustments are currently one row per affected variant; a header-plus-lines model will be easier to authorize, post, and audit.

### Constraints that need to be explicit

Add database-level constraints for:

* unique inventory balance per `(store_id, product_variant_id)`  
* unique tax rule per relevant store/class/rate combination  
* unique receipt number per store  
* at most one active business day per store  
* appropriate uniqueness on register names/numbers within a store  
* nonzero ledger quantities  
* valid basis-point ranges  
* nonnegative requested/ordered/received quantities  
* debit/credit journal invariants  
* valid polymorphic source/subject references where feasible

## 5\. Recommended project layout

Regardless of framework, I would structure ShelfSense as a modular monolith plus a separately deployable POS client:

```
ShelfSense
├── applications
│   ├── back_office
│   ├── pos_terminal
│   └── synchronization_worker
├── domains
│   ├── platform
│   ├── financial
│   ├── customers
│   ├── merchandise
│   ├── purchasing
│   ├── pos
│   ├── buyback
│   └── reporting
├── shared
│   ├── money
│   ├── identifiers
│   ├── time
│   └── persistence
├── database
│   ├── migrations
│   ├── seeds
│   └── projections
└── docs
    ├── architecture
    ├── decisions
    ├── domains
    ├── workflows
    ├── schema
    └── roadmap
```

Each domain should contain its own:

* entities and value objects  
* use cases/application services  
* validation and policies  
* persistence mappings  
* events and event handlers  
* tests  
* domain documentation

Avoid a global `models` directory containing all tables. Even in Rails, domain-scoped modules will make ownership and dependencies much clearer.

## 6\. What I would do next

Before choosing every remaining field, I would produce these four working documents:

1. **Domain catalog** — purpose, responsibilities, owned records, dependencies, and excluded responsibilities.  
2. **Workflow catalog** — catalog setup, inventory adjustment, sale, return, customer request, purchasing/receiving, and buyback.  
3. **Schema backlog** — every proposed table marked `planned`, `needed for slice`, `implemented`, or `deferred`.  
4. **Architecture decision records** — identity, offline storage, synchronization, financial posting, audit, and inventory authority.

The immediate target should then be one executable vertical slice:

> Configure a store → create a product and variant → establish inventory → scan it at POS → accept cash → complete and synchronize the sale → verify inventory and financial results.

That slice is small enough to build deliberately but broad enough to expose incorrect architectural assumptions before hundreds of migrations and screens make them expensive to change.
