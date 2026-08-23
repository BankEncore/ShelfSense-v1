# Administrative navigation grouping proposal

Status: **Proposed** inventory; **UDS-4.0** implements the disposable prototype and gate evidence. Production flat nav remains until **UDS-4.1** after the gate passes.

## Purpose and boundaries

The signed-in application header currently presents every authorized destination as one flat list. This proposal gives those existing links a canonical task/domain grouping and defines a server-rendered, progressively enhanced presentation pattern. It changes information architecture only; it does not add routes, permissions, or domain behavior.

This pattern applies to the **administrative shell** and to links from that shell into purchasing operations or POS. It does not change the dedicated purchasing-ops or Register shells. In particular, it:

- keeps ordinary Rails links and server-side permission checks as the baseline;
- does **not** require Turbo, Stimulus, or other Hotwire behavior in admin chrome;
- does **not** imply a permanent/collapsible sidebar, dark global chrome, a global search command, or universal drawers;
- does not put general administration around the Register scan workspace; and
- does not make hidden navigation an authorization boundary. Controllers and services remain authoritative.

The names below follow the project domain map and accepted vocabulary in ADR-011 and ADR-021: **supplier**, **Register**, **inventory balance**, and **audit** retain their established meanings. “POS operations” describes work performed through or in support of a Register; it does not introduce the deferred **Terminal** identity.

## Current-link inventory and canonical groups

This is an inventory of the signed-in, permission-gated destinations in `app/views/layouts/application.html.erb`. “Store” means the link also requires an authoritative `current_store`. Multiple links intentionally share one gate where that is the current behavior.

| Canonical group | Current label → destination | Visibility gate | Rationale |
|---|---|---|---|
| **Merchandise** | Departments → `admin_departments_path` | `departments.view` | Merchandise/financial classification used by the catalog |
| | Merchandise classes → `admin_merchandise_classes_path` | `merchandise_classes.view` | Merchandise classification |
| | Categories → `admin_merchandise_categories_path` | `merchandise_categories.view` | Merchandise classification |
| | Conditions → `admin_merchandise_conditions_path` | `merchandise_conditions.view` | Merchandise condition reference data |
| | Products → `admin_products_path` | `products.view` | Catalog master data |
| | Lookup → `new_admin_merchandise_lookup_path` | `merchandise.lookup` | Identifier-based merchandise task |
| | Import → `new_admin_merchandise_import_path` | `merchandise.import` | Merchandise import task |
| **Inventory** | Inventory → `admin_inventory_balances_path` | `inventory.view` | Inventory balances and history |
| | Adjustment reasons → `admin_adjustment_reasons_path` | `inventory.manage_adjustment_reasons` | Inventory configuration |
| | Inventory reconcile → `admin_inventory_reconciliation_path` | `inventory.reconcile` | Inventory reconciliation task |
| **Purchasing** | Purchasing → `admin_purchasing_path` | Hub-eligible via `Purchasing::HubAccess` / `purchasing_hub_accessible?` | Phase 7.1 purchasing work hub (primary Purchasing entry) |
| | Orders → `admin_orders_path` | `orders.view` | Supplier-order workflow |
| | Purchase orders → `admin_purchase_orders_path` | `orders.view` | Purchase-order history and administration |
| | Purchase receipts → `admin_purchase_receipts_path` | `purchase_receipts.view` | Receiving history |
| | Receiving ops → `ops_receiving_index_path` | `purchase_receipts.manage` + Store | Store receiving workspace |
| | Suppliers → `admin_suppliers_path` | `suppliers.view` | Supplier master data |
| | Draft PO ops → `ops_draft_pos_path` | `orders.manage` + Store | Store purchasing workspace |
| **Customers** | Customers → `admin_customers_path` | `customers.view` | Customer records |
| | Customer requests → `admin_customer_requests_path` | `customers.view` | Customer request history and administration |
| | Location ops → `ops_location_path` | `customer_requests.locate` + Store | Store location/reservation workspace |
| **POS operations** | POS → `pos_path` | `pos.transact` + Store | Enter the Register workspace |
| | Transactions → `pos_transactions_path` | `pos.transact` + Store | POS transaction history |
| | Tender types → `admin_tender_types_path` | `pos.manage_tender_types` | POS configuration |
| **Organization configuration** | Settings → `admin_system_settings_path` | `system_settings.view` | Organization-wide settings |
| | Stores → `admin_stores_path` | `stores.view` **or** `stores.create` | Store configuration |
| | GL Accounts → `admin_gl_accounts_path` | `gl_accounts.view` | Organization financial classification |
| | Tax Classes → `admin_tax_classes_path` | `tax_classes.view` | Organization tax classification |
| | Store taxes → `admin_store_taxes_path` | `store_taxes.view` | Store-scoped tax configuration |
| | Registers → `admin_registers_path` | `registers.view` | Durable logical checkout configuration |
| **Security** | Users → `admin_users_path` | `users.view` | User administration |
| | Roles → `admin_roles_path` | `roles.view` | Role and permission administration |
| | Role assignments → `admin_role_assignments_path` | `users.assign_roles` | Scoped authority administration |
| **Audit** | Audit → `admin_audit_events_path` | `audit_events.view` | Sensitive audit-event access |

`Home` is a primary utility destination rather than a domain group. `Switch store` (only when `accessible_stores.many?`) and `Sign out` are session/context utilities and stay visually separate from domain destinations. The current-store label remains persistent context, not a link group.

The grouping deliberately keeps Departments with Merchandise because it is used as catalog classification, while GL Accounts, Tax Classes, and Store taxes are organization configuration. Suppliers, Orders, Purchase orders, receipts, and their operational workspaces remain Purchasing. Registers are configured as organization/store infrastructure; entering a Register and reviewing its transactions are POS operations.

## Proposed baseline pattern

### Server-rendered structure

Build a navigation view model/helper from a fixed, code-defined group order and destination list. Each destination carries its label, path, permission predicate, optional current-store requirement, and route-matching rule. Render only destinations the current request is allowed to advertise; discard empty groups before rendering.

Use semantic HTML in this order:

1. brand and current-store context;
2. `<nav aria-label="Primary">` containing Home, followed by group sections;
3. each group as a labelled section containing a plain `<ul>` of ordinary `<a href>` links; and
4. a separate utility list for Switch store and the Sign out form.

The no-JavaScript baseline exposes the same authorized destinations as the current header. A small vanilla enhancement may add a disclosure treatment to long group lists, but it must operate on the server-rendered links and must not fetch, synthesize, or authorize destinations. If enhancement fails, the complete grouped list remains usable.

### Authorization and store context

- Preserve every predicate in the inventory above, including the `stores.view || stores.create` rule and gates shared by two links.
- Evaluate link visibility against effective permissions for the request's current context. Never render a store-required destination when `current_store` is absent.
- Do not replace controller/service authorization with navigation filtering. A copied or typed URL receives the existing authorization and current-store checks.
- Do not silently disable a store-required link. Omit it when there is no current store; retain the existing current-store display and store-selection flow.
- Do not create group-level permissions. A group exists when at least one child destination survives filtering.

### Current destination and group

The server determines one current destination using explicit route matching, not label text or URL-prefix guessing. Its link receives `aria-current="page"` and a persistent text/shape treatment with sufficient contrast. The containing group receives a visible “Current area” treatment and exposes that state to assistive technology in its heading (for example, visually hidden text “Current area”). An active descendant must be visible whenever a disclosure enhancement is applied; the current group starts expanded and enhancement must not collapse it on load.

On record/new/edit pages, the resource's index destination remains current (for example, a Supplier show page activates **Suppliers** and **Purchasing**). Routes not represented by a destination keep Home available but do not invent a false active group.

### Responsive and accessible behavior

- At wide widths, groups may wrap across rows; they must not rely on hover menus.
- At narrow widths and at 200%–400% zoom, render a single-column group flow within the document. Horizontal clipping must not remove destinations, and the navigation must not become an icon-only hamburger or pointer-only flyout.
- If a vanilla-JavaScript or native disclosure is later prototyped, its trigger is a real `<button>` (or semantic `<summary>`), exposes expanded state, works with Enter and Space, has a visible focus indicator, and leaves links in logical DOM/tab order. Escape behavior and focus return must be specified if any overlay is proposed; this proposal does not require an overlay.
- Group headings are not focusable unless they control a disclosure. Link text stays visible; icons, if added, are supplemental and `aria-hidden`.
- Focus order follows visual order: Home, canonical groups and their destinations, Switch store, Sign out. There is no roving tabindex or custom arrow-key model.
- CSS wrapping/reflow is the default narrow-width solution. JavaScript is optional enhancement, never the only way to reveal a destination.

### One-destination groups

Do not flatten a lone authorized link into another group and do not show an empty or disabled group. Render the canonical heading plus its one ordinary link. This keeps the user's location predictable across roles and makes “Audit → Audit” acceptable; presentation may avoid visual repetition by labelling the destination “Audit events” after a separate copy review, without changing the canonical **Audit** group.

## Required prototype gate

This proposal is an **UDS-0 inventory**, not permission to ship navigation in UDS-1 or UDS-2. Before either slice adopts it, build a disposable server-rendered prototype using the real destination/filter rules and test both profiles below. Do not promote the prototype by copying the inspirational permanent sidebar in the HTML mockups.

### Profile A — fully privileged administrator

Prototype with a global system administrator, an active current store, and multiple accessible stores. Expected result:

- all eight canonical groups and all **33** permission-gated destinations above are present (including the Purchasing hub);
- all four Store-gated operational links (Receiving ops, Location ops, Draft PO ops, POS) plus store-gated Transactions are present;
- Switch store and Sign out remain separate utilities; and
- a route in each group marks exactly one destination and its containing group current.

Repeat without `current_store`: the five Store-gated links are absent, other globally authorized links remain, and the presentation does not imply that store selection grants new permissions.

### Profile B — narrowly scoped store user

Prototype a store-scoped receiving user with only `purchase_receipts.manage` in one active store and that store selected. Expected result (after Phase 7.1 hub eligibility includes `purchase_receipts.manage`):

```text
Home
Purchasing (Current area when on the workspace)
├── Purchasing (hub)
└── Receiving ops
Sign out
```

No empty groups, Purchase receipts history, Suppliers, Switch store, security/configuration links, or POS links appear. Direct access to an unauthorized admin route remains denied by the server. Repeat with no current store: **Receiving ops** is omitted (store-gated); the **Purchasing hub** remains if hub-eligible without store-scoped counts (hub access is organization/any-store), while Home and Sign out remain operable.

This narrow profile exercises the minimal receiving permission. If fixtures or policy couple `purchase_receipts.manage` to another permission, use the narrowest real store role and record the additional links rather than weakening authorization to fit the mockup.

### Prototype checks and evidence

Record viewport/zoom, input method, profile, route, expected/observed destinations, active state, and defects. The gate requires:

1. automated view/helper coverage for all visibility predicates, empty-group removal, route matching, and `aria-current`;
2. direct-request authorization tests for at least one omitted link in each profile;
3. keyboard-only traversal at desktop and narrow width, with every destination and utility reachable and focus visible;
4. a screen-reader smoke test that announces the Primary landmark, group name, current page, current area, and disclosure state if used;
5. reflow checks at 320 CSS px and at 200% and 400% zoom, with no destination lost or requiring two-dimensional page scrolling; and
6. JavaScript-disabled verification proving that all authorized links remain available.

Attach results and screenshots for both profiles to the implementation change. Only after the gate passes may the program plan move navigation into UDS-1 (shared semantic primitive and responsive CSS) or UDS-2 (representative-screen validation). Update the migration matrix from **proposal / not implemented** only when the application shell actually ships.

## Non-goals and open implementation choices

This proposal does not select a permanent desktop geometry, create group landing pages, rename routes, alter the home page, persist expanded state, or define global search. A wrapping group strip, an in-flow “All areas” region, and optional accessible disclosures may be compared in the prototype, provided each honors the baseline and narrow-width rules above. Choosing a persistent sidebar or global search remains a separate architectural decision under [deferred-patterns.md](deferred-patterns.md).
