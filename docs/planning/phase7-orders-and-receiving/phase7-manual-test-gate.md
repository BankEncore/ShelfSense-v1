# Phase 7 — Expanded manual test gate

Status: **required before** the final integration branch → `main` merge. Application slices 7.1–7.7 may be complete on `phase-7-orders-and-receiving` while this gate is still open.

Do not mark Phase 7 implemented on `main` until every item below has been exercised and the integration PR has been reviewed.

## Checklist

### Reservations and ordinary POS

- [ ] Competing in-stock requests: first locate wins
- [ ] Ordinary POS blocked by Standard reservation
- [ ] Ordinary POS blocked for allocated Used unit

### Pickup (Slice 7.6)

- [ ] Allocation-linked pickup succeeds
- [ ] Failed/cancelled POS leaves allocation available

### Requests and purchasing

- [ ] OOS Standard → special order; unlocated Standard converts; unlocated Used cancels
- [ ] Partial receipt; over-shipment; customer cancel before receipt
- [ ] Cancel and re-source; duplicate receipt-post idempotency
- [ ] Customer cancel with `cancel_draft_order: true` after re-source (replacement draft cancelled; sent predecessor and its cancellation history unchanged)
- [ ] Customer cancel does not leave an orphaned reservation when locate or receipt is in flight
- [ ] Location-queue special-order convert accepts dollar expected unit cost (consistent with draft PO and receiving)
- [ ] Automatic PO closure

### Corrections (Slice 7.7)

- [ ] Cost correction changes valuation without physical quantity
- [ ] Eligible reversal restores qty/value and releases a receipt-created allocation
- [ ] Reversal blocked by downstream pickup/sale (fulfilled allocation or insufficient on-hand)
- [ ] Unsafe exact reversal directs to authorized compensating adjustment (`purchase_receipts.compensate`); completed pickup is never undone
- [ ] Whole-receipt reversal creates per-line corrections atomically or fails with no partial effect

## Sign-off

| Role | Name | Date | Notes |
|---|---|---|---|
| Operator / QA | | | |
| Reviewer | | | |

After sign-off: merge `phase-7-orders-and-receiving` → `main`, then update root README / docs index to mark Phase 7 implemented.
