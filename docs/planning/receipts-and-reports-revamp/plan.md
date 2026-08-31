# Receipts and reports revamp — Plan

Status: **Accepted**

Companions: [content-contract.md](content-contract.md), [visual-system.md](visual-system.md), [receipt-presentation.md](../phase4-6-point-of-sale/phase6-pos-mvp/receipt-presentation.md) (superseded sections), [ADR-022](../../adr/ADR-022-warm-parchment-visual-tokens.md) (amended for thermal fonts).

## Goal

Make customer receipts and gift-card vouchers easier to read on 80 mm thermal output, using a coherent ShelfSense visual system aligned with the approved HTML mockup. Render from persisted completed facts without repricing or reconstructing historical activity.

## Non-goals

- Remap Register keyboard shortcuts
- Redesign transaction, tender, stored-value, cash, session, or Z domain semantics
- Store raw printer bytes or image snapshots for reprint
- Require pixel-identical historical reprints
- Expose full gift-card numbers on ordinary customer receipts
- Print expected drawer cash where authorization prohibits it
- Rewrite Transaction Complete / Transaction Review screen density
- ESC/POS or raw printer drivers

## Locked decisions

1. **First packet scope:** document families D1 (customer transaction receipts) and D2 (gift-card vouchers) only.
2. **Visual authority:** [receipt.html](../../drafts/receipts_and_reports_revamp/receipt.html) for density, hierarchy, dividers, description-first lines, section titles, total banner, savings box, and barcode chrome.
3. **Data authority:** completed transaction facts, receipt identity snapshots, Store Tax components, tender snapshots, stored-value entries (`balance_after_cents`), first-print/recovery services — unchanged.
4. **Description-first merchandise:** product description on the primary line; SKU or unit identifier on indented meta; tax indicators on the amount line.
5. **Separate stored-value issuance:** gift-card activation/reload in a distinct section, not mixed into merchandise lines.
6. **Store Tax names:** persisted `store_tax_name_snapshot` on customer receipt tax rows; Tax Class names are not customer labels.
7. **No universal taxable subtotal:** omit `TAXABLE SUBTOTAL` unless a row is semantically valid for all applicable Store Taxes.
8. **Historical stored-value balances:** balance notes use the applicable persisted `stored_value_entries.balance_after_cents` for the operation, not live account balance.
9. **Typography:** Noto Sans Mono + Plus Jakarta Sans packaged locally for thermal customer documents ([ADR-022](../../adr/ADR-022-warm-parchment-visual-tokens.md)). Register screen chrome may adopt the same faces via an accepted presentation packet. Reports/tapes keep Inconsolata until a later packet. No runtime font CDN.
10. **Receipt-only / voucher-only print modes** preserved via `pos_receipt_controller.js` body classes.
11. **Operator screen vs thermal print** remain distinct projections; this packet changes hidden print markup and voucher print, not Transaction Complete screen layout.

## Slices

| Slice | Deliverable |
|---|---|
| **R1** | Planning packet, ADR-022 amendment, label locks, roadmap pointer |
| **R2** | Shared thermal CSS primitives, Google Fonts load, font-ready print, wrapping |
| **R3** | Sectioned `Pos::CustomerReceipt`, decomposed print partials, scenario tests |
| **R4** | Voucher chrome aligned to thermal system, recovery designation, protection tests |

## Label locks (customer receipt)

| Element | Label |
|---|---|
| Merchandise subtotal | `Merchandise Subtotal` |
| Discounts | `Item Discounts` |
| Returns | `Returns Subtotal` |
| Issuance | `Gift Cards Activated` / `Gift Cards Reloaded` |
| Sale total | `TOTAL DUE` |
| Refund total | `REFUND TOTAL` |
| Zero net | `NET TOTAL` |
| Payments section | `PAYMENTS APPLIED` |
| Cash presented | `Cash Tendered` |
| Cash settlement | `Cash Applied` |
| Change | `Change` |
| Issuance balance note | `New Balance` |
| Redemption balance note | `Remaining Balance` |
| Issued balances section | `ISSUED GIFT CARD BALANCES` (when multiple activations) |
| Item counts | `Items Sold:` or `Items Returned` when one direction only; `Items Sold / Returned:` when both |
| Savings | `YOU SAVED:` |
| Date/time | Store timezone, four-digit year (e.g. `30 Aug 2026 12:09 AM`) |

Identity header: restyle `Pos::ReceiptIdentity.header` as label/value rows (`Store/Reg/Trans:`) without changing canonical strings.

## Voucher recovery designation

Customer voucher for authorized recovery/replacement carries `*** REPLACEMENT PRINT COPY ***`. Manager identity, internal reason, and audit reference stay off the customer copy.
