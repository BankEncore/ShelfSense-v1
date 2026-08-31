# Register surface polish — Test matrix

Status: **Proposed** for slices S2–S4.

## Frozen automated suites (do not relax)

| Suite | Role |
|---|---|
| `test/system/pos_register_workspace_test.rb` | Sale entry, shortcuts, overlays, focus |
| `test/system/pos_register_shell_test.rb` | Shell, F10, zoom reachability |
| `test/system/pos_linked_return_test.rb` | Linked return path |
| `test/system/pos_unlinked_return_test.rb` | Unlinked return path |
| `test/system/pos_mixed_return_test.rb` | Mixed return |
| `test/system/pos_close_z_test.rb` | Close / Z path touchpoints |
| `test/integration/pos_close_z_test.rb` | Completed receipt chrome / fonts (S2) |
| `test/integration/pos_gift_card_voucher_test.rb` | Voucher still renders (S2) |
| `test/integration/admin_product_composition_test.rb` | No CDN fonts in admin CSS (S2) |

UDS-style rule: polish may **add** visual or font assertions; it must not delete, rename, or weaken existing workflow assertions to pass.

## S2 — Font packaging assertions

| # | Scenario | Assertions |
|---|---|---|
| 1 | POS completed receipt layout | Thermal CSS variables present; no `fonts.googleapis.com` link |
| 2 | Stylesheet | `@font-face` for Noto Sans Mono and Plus Jakarta Sans; Inconsolata retained |
| 3 | Admin composition | Still refutes Google Fonts CDN in CSS |
| 4 | Voucher | Barcode/credential assertions unchanged |

## S3 — Layout smoke (manual + system)

| # | Viewport | Checks |
|---|---|---|
| 1 | 1280×720 @ 100% | Header, command, basket, summary, actions visible; selection obvious |
| 2 | 1280×720 @ 200% | Shell body scrollable; primary actions reachable (no stale-element flakiness) |
| 3 | Sale + line select | Quantity/Price/Discount enablement unchanged |
| 4 | Tender mode | Tender review controls remain usable |

## S4 — Menu / overlay smoke

| # | Scenario | Checks |
|---|---|---|
| 1 | F10 open/close | Dialog modal; Escape closes; focus returns |
| 2 | Menu navigation | Proxy items and leave-confirm still work |
| 3 | Controlled overlay | Panel readable; Esc / Cancel; command field restore after close |
| 4 | Optional history | Filters submit; receipt links work |

## Explicit non-coverage (deferred)

- Pixel-diff against HTML drafts
- Transaction Complete / Review redesign
- Timed cashier PERF-HUMAN / full a11y **conforming** study (may remain open)

## Reconciliation with receipts packet

S2 must not regress D1/D2 scannable SVG barcodes or voucher masking. If thermal font-loader changes, re-run gift-card voucher + close-Z font assertions.
