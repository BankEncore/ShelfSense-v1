# Receipts and reports revamp — User stories

GitHub issues should usually be one focused PR per slice.

## Slice R1 — Content and authority lock

**Outcome:** Accepted planning packet, ADR-022 amendment, supersession documented, label locks recorded.

**Acceptance:**

- [ ] `docs/planning/receipts-and-reports-revamp/` README and companions exist
- [ ] ADR-022 amended for thermal Google Fonts exception
- [ ] Roadmap cross-phase section references this program
- [ ] Draft spec D3–D7 marked deferred in README

## Slice R2 — Shared thermal primitives

**Outcome:** Thermal CSS tokens, Google Fonts in print layouts, font-ready print, wrapping without ellipsis clamp on print descriptions.

**Acceptance:**

- [ ] `--font-thermal-body` and `--font-thermal-display` defined
- [ ] `pos.html.erb` loads Google Fonts with preconnect
- [ ] `pos_receipt_controller.js` preloads new faces
- [ ] Print partials use thermal primitive classes
- [ ] Report/tape print CSS unchanged (Inconsolata)

## Slice R3 — Customer receipt projection and template

**Outcome:** Sectioned `Pos::CustomerReceipt`, description-first print template, Store Tax names, payment hierarchy, `balance_after_cents`, scenario tests.

**Acceptance:**

- [ ] Merchandise and stored-value issuance in separate sections
- [ ] Description-first layout matches content contract
- [ ] Tax rows use `store_tax_name_snapshot`
- [ ] Cash Tendered / Applied / Change hierarchy
- [ ] Historical balance notes use persisted `balance_after_cents`
- [ ] Post-void, reprint, refund, even-exchange variants render correctly
- [ ] `test/services/pos/customer_receipt_test.rb` covers priority fixtures
- [ ] Receipt totals reconcile to `signed_net_cents`

## Slice R4 — Voucher presentation closeout

**Outcome:** Voucher chrome aligned to thermal system; replacement designation; ADR-026 protection preserved.

**Acceptance:**

- [ ] Voucher shares store header, dividers, fonts with receipt
- [ ] Recovery voucher shows `*** REPLACEMENT PRINT COPY ***`
- [ ] Full number only on voucher, never ordinary receipt
- [ ] Receipt-only and voucher-only print modes unchanged
- [ ] `test/integration/pos_gift_card_voucher_test.rb` passes

**Exclusions:** Transaction Complete screen redesign, X/Z restyle, cash-out receipt.
