# Register surface polish — Implementation plan

Status: **Accepted** — in progress on `register-surface-polish`.

Authority: [plan.md](plan.md), [visual-system.md](visual-system.md), [change-allowlist.md](change-allowlist.md).

## Merge policy

- Development branch `register-surface-polish` from `main`; sequential commits S1→S4; one PR to `main`.
- Do not combine S3 workspace polish with completed-transaction redesign.
- Font packaging (S2) lands before thermal CDN loaders are removed.

## Slice status

| Slice | Status | Scope |
|---|---|---|
| S1 Packet | **Complete** | Docs, roadmap pointer, allowlist |
| S2 Local fonts | Pending | Package faces; remove CDN; thermal font-ready |
| S3 Workspace polish | Pending | Header/command/basket/summary/actions |
| S4 Menu/overlay (+ optional history) | Pending | Panel chrome; closeout |

## Testing stack

Frozen suites (must stay green; do not rewrite workflow assertions to pass polish):

```sh
./dev/rails-docker bin/rails test \
  test/system/pos_register_workspace_test.rb \
  test/system/pos_register_shell_test.rb \
  test/system/pos_linked_return_test.rb \
  test/system/pos_unlinked_return_test.rb \
  test/system/pos_mixed_return_test.rb \
  test/system/pos_close_z_test.rb
```

S2 additionally:

```sh
./dev/rails-docker bin/rails test \
  test/integration/pos_close_z_test.rb \
  test/integration/pos_gift_card_voucher_test.rb \
  test/integration/admin_product_composition_test.rb
```

Full CI before handoff: `./dev/rails-docker bin/ci`

## Components touched (expected)

| Area | Files |
|---|---|
| Fonts | `app/assets/fonts/*noto*`, `*plus-jakarta*`, OFL texts |
| CSS | `app/assets/stylesheets/application.css` (POS + `@font-face`) |
| Thermal font loader | `app/views/pos/receipts/_thermal_fonts.html.erb` |
| Print JS | `app/javascript/controllers/pos_receipt_controller.js` |
| Shell | `app/views/pos/shell/_header.html.erb`, `_menu.html.erb`, frame/feedback as needed |
| Workspace | `app/views/pos/workspaces/_surface.html.erb`, `_command.html.erb`, `_basket.html.erb`, `_totals.html.erb`, `_tenders.html.erb`, `_actions.html.erb`, `_customer.html.erb`, `_issuances.html.erb`, `_overlays.html.erb` |
| Optional history | `app/views/pos/transactions/index.html.erb` |

## Manual verification (cashier)

At Chromium 1280×720 and 200% zoom:

1. Open register → sale entry → scan/add line → select line → quantity/price overlays
2. Return chooser + linked/unlinked path smoke
3. Tender path → complete → print receipt (local fonts)
4. F10 menu open/close; leave confirm still works
5. No unreachable primary actions; basket selection visible; balance due readable

## Exit

Packet complete when S1–S4 merged (S4 history skin may be skipped with an explicit deferral note), CDN fonts gone, frozen suites green, and README status updated to **Accepted / implemented**.
