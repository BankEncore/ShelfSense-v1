# Receipts and reports revamp — Test matrix

Status: **Accepted** for slices R3–R4.

## Automated — customer receipt (D1)

| # | Scenario | Assertions |
|---|---|---|
| 1 | Ordinary single-tender sale | Subtotal + tax = signed_net; named tax when shown |
| 2 | Complex mixed sale | Merchandise + issuance sections separate; multiple tax groups |
| 3 | Linked return | Original reference on line |
| 4 | Return-only Cash refund | `REFUND TOTAL`; refund tender label |
| 5 | Even exchange | `NET TOTAL` $0; no tender section |
| 6 | Post-voided original | POST-VOIDED banner |
| 7 | Post-void reversal | POST-VOID + original reference |
| 8 | Gift-card activation only | Issuance section; no empty merchandise |
| 9 | Gift-card reload | Reload section label |
| 10 | Gift-card redemption + Cash | Remaining Balance from entry |
| 11 | Used unit | Condition on meta line |
| 12 | Open-price | No override provenance |
| 13 | Multiple Store Taxes | Named rows; Total Tax |
| 14 | No tax / exempt | No tax rows when none apply |
| 15 | Customerless | No Customer row |
| 16 | Missing description | `Description unavailable` |
| 17 | Legal name blank | Fail closed |
| 18 | Reprint after balance change | Balance note uses historical `balance_after_cents` |

## Automated — voucher (D2)

| # | Scenario | Assertions |
|---|---|---|
| 1 | First-print activation | Full number on voucher only; masked receipt |
| 2 | Barcode | SVG aria-label = normalized number |
| 3 | Footer | System settings footer present |
| 4 | After delivery | No full number on completed view |
| 5 | Recovery print | REPLACEMENT PRINT COPY designation |

## Reconciliation (all D1 fixtures)

- Tax group sum = persisted transaction tax direction
- Tender rows reconcile to settlement
- Cash: presented = applied + change
- Print/reprint creates no commercial rows

## Manual verification

For priority fixtures:

- 80 mm screen preview and browser print preview
- Long-name wrapping without column overlap
- Barcode scannability
- Receipt-only vs voucher-only print
- Keyboard Print / Print gift card
- Black-and-white legibility

## Existing test files

| File | Role |
|---|---|
| `test/services/pos/customer_receipt_test.rb` | Projection unit tests |
| `test/integration/pos_gift_card_voucher_test.rb` | Voucher protection integration |
| `test/services/pos/receipt_identity_test.rb` | Identity strings unchanged |

## Out of scope (deferred packet)

X Report, Z Report, session tape, cash slips, gift-card cash-out receipt fixtures.
