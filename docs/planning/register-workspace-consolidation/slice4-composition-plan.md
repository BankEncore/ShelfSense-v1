# Slice 4 — Transaction composition

Status: **Implementation-ready.** Slice 3 is on `register-workspace-consolidation` ([#84](https://github.com/BankEncore/ShelfSense-v1/issues/84) / PR #97).

Authority: [plan.md](plan.md), [routing-and-authority.md](routing-and-authority.md), [textual-wireframes.md](textual-wireframes.md) §S4 / P7–P11, [user-stories.md](user-stories.md), Phase 6.7 keys except F10.

Issue: [#85](https://github.com/BankEncore/ShelfSense-v1/issues/85). Branch: `85-transaction-composition`. PR target: `register-workspace-consolidation`.

## Outcome

Split workspace `_surface`. Extract a query-free `Pos::WorkspacePresenter` that assembles authoritative display values and groups tax components (not a second pricing engine). Keep Phase 6.7 keys except F10. Commercial summary, applied tenders, and settlement footer become distinct layers.

## Locked contracts

### Presenter

`Pos::WorkspacePresenter` receives fully loaded arrays and scalars from the controller. It must not call association scopes as fallbacks, look up tender types, evaluate permissions, or generate routes.

```ruby
Pos::WorkspacePresenter.call(
  transaction:,
  lines:,
  tenders:,
  issuances:,
  selected_line:,
  selected_tender_type:,
  ui_mode:,
  settlement_direction:,
  remaining_payment_cents:,
  remaining_refund_cents:,
  command_value:,
  feedback:,
  action_capabilities:
)
```

`action_capabilities` holds controller-established booleans only (for example `pickup_available`, `close_session_available`, `gift_card_programs_available`).

| Owner | Responsibility |
|---|---|
| Presenter | Display DTOs, labels, signed summary and tax groups, tender display facts |
| Views / helpers | Routes, forms, CSRF, mutation params, shared money formatting |
| Controllers / services | Authorization, preloads, `Pos::Support` settlement scalars |

### Summary formula

Never use the label `Sales` or `sale_total_cents` as a summary row (`sale_total_cents` already includes tax).

| Label | Signed contribution |
|---|---|
| Merchandise | `+ transaction.subtotal_cents` |
| Discount | `− transaction.discount_cents` |
| Returns | `− transaction.return_subtotal_cents` |
| Return discount reversal | `+ transaction.return_discount_cents` |
| Gift cards issued | `+ transaction.stored_value_issuance_cents` |
| named tax groups | sum to `+ tax_cents − return_tax_cents` |
| Net | `transaction.signed_net_cents` |

Invariant: `summary_rows.sum(&:signed_cents) == transaction.signed_net_cents`.

Omit zero rows only when the formula remains understandable. Omit zero-net tax groups unless needed to explain a nonzero formula.

**Forbidden:** label `Sales`; using `sale_total_cents` as a summary row (it already includes tax).

### Tax grouping

Working sale/return lines persist provisional `pos_line_tax_components` through `Pos::Support.apply_provisional_tax!` so the presenter stays query-free and can group tax without calling `Pos::Tax::Calculate`.

`PosLineTaxComponent#tax_cents` is nonnegative; direction lives on the line:

```ruby
signed_component_tax = line.sale? ? component.tax_cents : -component.tax_cents
```

Group by snapshotted identity: `store_tax_id`, `store_tax_code_snapshot`, `store_tax_name_snapshot`, `rate_percent`, `calculation_order`. Sort by `calculation_order`, name, then code.

Invariant: `tax_groups.sum(&:signed_cents) == transaction.tax_cents - transaction.return_tax_cents`.

On mismatch: fail hard in tests; in production log (`Rails.logger.warn`) and fall back to a single authoritative **Net tax** row. Do not invent “Other tax.” Do not write audit/outbox records for a presentation fallback.

### Three financial layers

1. **Summary** (`#pos_totals`) — commercial calculation only.
2. **Applied tenders** (`#pos_tenders`) — positive applied amounts with explicit `direction`; cash presented/change as supporting detail only.
3. **Settlement footer** — in the summary rail, not inside `#pos_totals`; formats controller-supplied `Pos::Support` remainings (Balance due, Refund remaining, Settled, Even exchange, Change).

Settlement checks: payment `signed_net − applied payments == remaining_payment`; refund `−signed_net − applied refunds == remaining_refund`.

### DOM composition

```erb
<div class="pos-main">
  <section class="pos-basket-region">
    <%= render "basket" %>
    <%= render "issuances" %>
    <%= render "customer" %>
  </section>

  <aside class="pos-summary-rail">
    <%= render "totals" %>
    <%= render "tenders" %>
  </aside>
</div>
```

Stable IDs: `#pos_workspace`, `#pos_feedback`, `#pos_basket`, `#pos_totals`, `#pos_tenders`, `#pos_actions`. `#pos_tenders` is a sibling of `#pos_totals`, not a descendant. Use `aria-labelledby` for totals and tenders titles.

### Partials

`_command`, `_basket`, `_issuances`, `_customer`, `_totals`, `_tenders` (includes settlement footer), `_actions`, `_forms`, `_overlays`.

Overlays move to `_overlays.html.erb` mechanically in a distinct commit (indentation only). No Stimulus target/ID/behavior changes (5A–5D).

### Behavior preservation

- Issuance **Remove** remains where currently valid; no issuance Edit.
- Customer attach / change / clear unchanged.
- Close Session remains authoritative in `_actions`; F10 discovers it via live proxy.
- Separated tender rows imply no new Edit/Remove controls.
- Workspace keeps F1–F9 and overlay ownership; F10 stays shell-owned.
- Turbo continues to replace the whole `#pos_workspace` tree.

## Exclusions

Overlay-family migration (5A–5D); inquiry presenters (6A–6C); tender edit/replace and selection model (7A); stored-value capping (7B); keyboard supersession (7C); merging issuances into merchandise; JS unit-test framework; runtime feature flags.

## Tests

Presenter matrix: sale only; return only; mixed; gift-card issuance; multiple tax groups; tax mismatch fallback; split payment; cash overpayment; refund tender; even exchange; completion failure. Request/system: `#pos_tenders` sibling of `#pos_totals`. No large HTML snapshot suite. Do not characterize current Sales/tax-inclusive totals as golden.

## Implementation sequence

1. This locked packet (+ manual verification stub).
2. Characterization tests for non-summary chrome.
3. Query-free presenter while `_surface` intact; wire controller.
4. Tax grouping and formula tests; switch summary rendering.
5. Split non-overlay partials; summary rail.
6. Mechanical overlay move commit.
7. Financial/domain + workspace system suites.
8. Manual zoom and keyboard verification.

## Done when

- [ ] Presenter is query-free and action-neutral
- [ ] Summary formula reconciles to `signed_net_cents`
- [ ] Tax groups reconcile or fall back to Net tax
- [ ] `#pos_totals` / `#pos_tenders` / settlement footer are distinct
- [ ] `_surface` split into the locked partials
- [ ] Overlay move is mechanical only
- [ ] 6.7 keys except F10 remain; Close Session proxy and issuance Remove preserved
- [ ] Focused presenter tests green; affected system suites green
