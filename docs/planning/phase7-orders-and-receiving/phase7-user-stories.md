# Phase 7 — User stories

Status: **accepted** backlog for [phase7-plan.md](phase7-plan.md). Concise stories for slices 7.1–7.7; acceptance bullets are the review bar, not exhaustive novels.

---

## Slice 7.1 — Suppliers and sources

### 7.1.1 Maintain suppliers

**As a** purchasing administrator, **I want** to create and deactivate suppliers **so that** buyers can place orders against known sources.

Acceptance:

- Supplier requires code and name; code is unique and immutable after create.
- Supplier can be deactivated without deleting history.
- Changes are authorized and audited.

### 7.1.2 Maintain Standard variant sources

**As a** buyer, **I want** optional supplier item numbers and expected cost defaults on Standard variants **so that** draft PO lines start with usable economics.

Acceptance:

- Used and non-inventory variants cannot have sources.
- Preferred resolution is store override → organization preferred → none.
- Missing source does not block a manually priced order later.
- Source create/edit/deactivate is audited.

---

## Slice 7.2 — Customers, locate, universal hard-stop

### 7.2.1 Create in-stock customer request

**As a** associate, **I want** to create a quantity-one request for an apparently available Standard or Used variant **so that** staff can locate it without reserving stock yet.

Acceptance:

- Request receives a store-scoped number at create (immutable, never reused).
- In-stock Standard/Used enter `pending_location` without allocation.
- Out-of-stock Used is rejected; OOS Standard create is feature-gated until 7.3.

### 7.2.2 Locate and reserve

**As a** floor associate, **I want** to confirm a located Standard copy or exact Used unit **so that** it is reserved for the customer.

Acceptance:

- Standard locate creates aggregate allocation; Used locate requires the exact unit.
- Competing pending-location requests: first successful locate wins.
- Active allocation is excluded from general availability without reducing on-hand.

### 7.2.3 Universal hard-stop

**As a** store, **I want** every stock-depleting path to refuse reserved stock **so that** ordinary sales and adjustments cannot steal allocated merchandise.

Acceptance:

- `Inventory::PostSale`, negative `Inventory::PostAdjustment`, depleting post-void, and Register add validation hard-stop against reserved Standard availability and allocated Used units.
- No pickup exception exists yet (pickup cannot succeed until 7.6).
- Concurrency tests cover locate vs sale races under [phase7-lock-order.md](phase7-lock-order.md).

### 7.2.4 Unlocated Used cancel

**As a** associate, **I want** to cancel an unlocated Used request **so that** the queue stays clean.

Acceptance:

- Used not-located forces cancellation; supplier conversion is prohibited.
- Standard not-located→convert remains feature-gated until 7.3.

---

## Slice 7.3 — Orders and draft PO

### 7.3.1 Create stock order into draft PO

**As a** buyer, **I want** a stock order to land on the open supplier/store draft PO as its own line **so that** I can build a PO without consolidating lines.

Acceptance:

- Order receives store-scoped number at create.
- Scan/search from fixed draft atomically creates order + dedicated PO line (never a bare line).
- Used variants rejected at every purchasing boundary.

### 7.3.2 Enable special-order paths

**As a** associate/buyer, **I want** OOS Standard requests and unlocated Standard converts to create order + draft PO line atomically **so that** special orders are purchasing-ready.

Acceptance:

- OOS Standard create and Standard convert are enabled (gates from 7.2 removed).
- UI never leaves a `special_order_pending` request without order+PO line.
- Customer cancel with unsent special order requires explicit buyer keep/cancel decision.

---

## Slice 7.4 — Send, cancel, re-source

### 7.4.1 Generate and send PO

**As a** buyer, **I want** to generate a numbered PO and record sending it **so that** the supplier document is immutable after send.

Acceptance:

- PO number assigned at generate; never reused; retained if returned to draft before send.
- Sent snapshots reject business-content edits.
- Linked customer requests move to `ordered` when applicable.

### 7.4.2 Cancel and re-source

**As a** buyer, **I want** to cancel open quantity and optionally create a replacement order **so that** I can change suppliers without rewriting history.

Acceptance:

- Cancellation reduces open quantity immediately.
- Re-source creates linked replacement order + draft line atomically.
- PO auto-closes when all lines reach zero open quantity.

---

## Slice 7.5 — Receiving

### 7.5.1 Post physical receipt

**As a** receiver, **I want** to post a delivery against one or more same-supplier/store POs **so that** inventory and open quantities update correctly.

Acceptance:

- Receipt number assigned **at posting**; abandoned drafts do not consume numbers.
- Matched vs unplanned quantities frozen under lock; over-shipment becomes unplanned stock.
- Ancillary charges recorded but excluded from inventory valuation.
- Active special-order receipt creates Standard allocation for the request.
- `Inventory::PostReceipt` is implemented and marked in the inventory posting contract.

---

## Slice 7.6 — Allocation-linked pickup

### 7.6.1 Complete pickup on Register

**As a** cashier, **I want** to sell an available customer allocation on the Register **so that** the request completes only after a successful sale.

Acceptance:

- Ordinary line capacity = `available`; pickup capacity = `available` + allocation on that line.
- Used pickup must use the allocated unit.
- Failed/cancelled transaction leaves allocation available.
- No admin “mark completed” path.
- Concurrent pickup cannot fulfill the same allocation twice.

---

## Slice 7.7 — Corrections

### 7.7.1 Reverse or cost-correct a receipt line

**As a** authorized receiver, **I want** to reverse eligible receipt lines or post cost-only corrections **so that** posted facts stay immutable while errors are fixable.

Acceptance:

- Exact reversal up to remaining posted quantity; whole-receipt convenience is atomic.
- Cost-only correction changes valuation without quantity change.
- Unsafe reversal blocked; requires separately authorized compensation.
- Downstream pickup/sale prevents silent undo of fulfilled allocations.
