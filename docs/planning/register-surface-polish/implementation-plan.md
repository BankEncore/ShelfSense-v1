# Register surface polish — Implementation plan

Status: **Accepted / implemented** (S1–S4 on `main`). Hierarchy follow-on in progress on `register-workspace-hierarchy`.

Authority: [plan.md](plan.md), [visual-system.md](visual-system.md), [change-allowlist.md](change-allowlist.md).

## Merge policy

- S1–S4 landed via `register-surface-polish` → `main` (PR #131).
- Hierarchy follow-on: branch `register-workspace-hierarchy`; one PR to `main`; **do not merge until manual review is complete**.
- Do not combine hierarchy polish with completed-transaction redesign or Turbo boundary refactors.

## Slice status

| Slice | Status | Scope |
|---|---|---|
| S1 Packet | **Complete** | Docs, roadmap pointer, allowlist |
| S2 Local fonts | **Complete** | Package faces; remove CDN; thermal font-ready |
| S3 Workspace polish | **Complete** | Header/command/basket/summary/actions |
| S4 Menu/overlay (+ optional history) | **Complete** | Panel chrome; history skin; closeout |
| Hierarchy follow-on | **In progress** | Basket header, feedback collapse, card rhythm, Cash/Remove emphasis, F10 Close Session, hint removal; Turbo deferred |

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
| Workspace | `app/views/pos/workspaces/_surface.html.erb`, `_command.html.erb`, `_basket.html.erb`, `_totals.html.erb`, `_tenders.html.erb`, `_actions.html.erb`, `_basket_aux.html.erb`, `_customer.html.erb`, `_issuances.html.erb`, `_overlays.html.erb` → `overlays/*`, `_forms.html.erb` → `forms/*` |
| Optional history | `app/views/pos/transactions/index.html.erb` |

## Manual verification (cashier)

At Chromium 1280×720 and 200% zoom:

1. Open register → sale entry → scan/add line → select line → quantity/price overlays
2. Return chooser + linked/unlinked path smoke
3. Tender path → complete → print receipt (local fonts)
4. F10 menu open/close; leave confirm still works
5. No unreachable primary actions; basket selection visible; balance due readable

## Exit

Packet S1–S4 complete on `main`. Hierarchy follow-on complete when suites green, manual review signed off, and PR merged.
