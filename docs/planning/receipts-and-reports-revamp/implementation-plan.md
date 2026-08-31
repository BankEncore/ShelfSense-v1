# Receipts and reports revamp — Implementation plan

Status: **In progress**

Authority: [plan.md](plan.md), [content-contract.md](content-contract.md), [visual-system.md](visual-system.md).

## Merge policy

- Slice branches from `main`: `<issue-number>-receipt-r<n>-<short-description>` or focused PR per slice.
- Each slice PR targets `main` directly (no long-lived integration branch required).
- Delete superseded print markup in the owning slice. No runtime compatibility flags.

## Slice status

| Slice | Status | Scope |
|---|---|---|
| R1 Packet + ADR | **Complete** | Docs, ADR-022 amendment, roadmap pointer |
| R2 Thermal primitives | **Complete** | CSS, fonts, print behavior |
| R3 Customer receipt | **Complete** | Projection, partials, tests |
| R4 Voucher closeout | **Complete** | Voucher chrome, recovery designation, protection tests |

## Testing stack

- **Service/unit:** `Pos::CustomerReceipt` section projections, tax reconciliation, `balance_after_cents` selection, total verification.
- **Request/integration:** print partial rendering, voucher masking, first-print delivery, `Cache-Control: no-store`.
- **System (manual):** 80 mm print preview, barcode scannability, receipt-only vs voucher-only modes, keyboard Print/Reprint.

Run during development:

```sh
./dev/rails-docker bin/rails test test/services/pos/customer_receipt_test.rb
./dev/rails-docker bin/rails test test/integration/pos_gift_card_voucher_test.rb
```

Full CI before handoff: `./dev/rails-docker bin/ci`

## Components touched

| Area | Files |
|---|---|
| Projection | `app/services/pos/customer_receipt.rb` |
| Print partials | `app/views/pos/receipts/_print*.html.erb`, `app/views/pos/receipts/thermal/*` |
| Voucher | `app/views/pos/receipts/_gift_card_voucher.html.erb` |
| Styles | `app/assets/stylesheets/application.css` (thermal scope only) |
| Fonts / layout | `app/views/layouts/pos.html.erb`, admin credential/recovery views |
| Print controller | `app/javascript/controllers/pos_receipt_controller.js` |
| First print | `app/services/pos/first_print.rb` (recovery designation on `Credential`) |

Do **not** restyle `.pos-report-print` or `.pos-shift-end-tape` in this program.
