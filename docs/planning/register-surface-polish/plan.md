# Register surface polish — Plan

Status: **Proposed**

Companions: [visual-system.md](visual-system.md), [change-allowlist.md](change-allowlist.md), [ADR-022](../../adr/ADR-022-warm-parchment-visual-tokens.md), [UDS-3](../ux-design-system/uds-3-plan.md).

## Goal

Make the active Register workspace and shell chrome read as one Warm Parchment composition aligned to the approved register-surface drafts—carded header/command/basket/summary/keypad regions, clearer selection and balance-due emphasis, stronger menu/overlay panel chrome—without changing cashier bindings, scan focus, Turbo contracts, or domain posting.

Secondarily: package **Noto Sans Mono** and **Plus Jakarta Sans** locally, remove the transitional Google Fonts CDN loaders from thermal layouts, and optionally adopt those faces on Register **screen** chrome when S3 opts in.

## Non-goals

- Remap Register keyboard shortcuts or Slice 7 dispatcher semantics
- Redesign transaction, tender, stored-value, cash, session, or Z domain semantics
- Redesign Transaction Complete / Transaction Review screens
- Change print receipt/voucher **content** (labels, sections, barcode encoding)
- Replace admin/ops typography
- Restyle `.pos-report-print` / session tapes
- Introduce Hotwire on admin chrome
- Invent new Register destinations or menu membership

## Locked decisions

1. **First packet scope:** active Register shell + workspace visual polish; local font packaging; optional history table/filter skin. Completed-transaction redesign is deferred.
2. **Visual authority:** [active_transaction.html](../../drafts/register-surface-revamp/active_transaction.html) for density, card regions, selection accent, summary rail, and keypad grouping. Menu/dialog drafts authorize **panel chrome only**, not interaction model changes.
3. **Drafts are inspirational:** pixel identity is not required. Prefer existing DOM composition over inventing parallel markup.
4. **Contracts frozen:** `#pos_workspace`, `#pos_basket`, `#pos-command-field`, `#register-menu`, Stimulus `data-controller` / `data-*-target` / `data-action`, form methods, Turbo stream targets, shell F10 ownership, leave-confirm, overlay open/close semantics.
5. **Typography:** Local packaging of Noto Sans Mono + Plus Jakarta Sans per ADR-022. No runtime font CDN after S2. Register screen may switch `--font-*` / component classes to those faces in S3; admin/ops stay on Source Sans 3 / Source Serif 4.
6. **Thermal print:** After S2, D1/D2 continue to use `--font-thermal-*` from local `@font-face`. Content and barcode contracts unchanged.
7. **Action semantics:** Continue `ActionButtonHelper`; do not invent a parallel button system. Size `:large` remains for the command/action cluster unless a named exception is documented in the PR.
8. **Allowlist discipline:** Only files and selectors in [change-allowlist.md](change-allowlist.md). Expanding the allowlist requires a same-PR or preceding docs change.
9. **Overlay caution:** Do not apply draft `filter: blur` or `pointer-events: none` on the workspace background. Panel elevation, border, radius, and header treatment are in scope.
10. **Aux bar:** Do not relocate Gift Card / Attach Customer into a new ownership model. Visual grouping within existing `_issuances` / `_customer` regions is allowed.

## Slices

| Slice | Deliverable |
|---|---|
| **S1** | Planning packet accepted; roadmap pointer; allowlist locked |
| **S2** | Local Noto Sans Mono + Plus Jakarta Sans packaging; remove CDN loaders; thermal print still font-ready |
| **S3** | Active workspace + shell header/command/basket/summary/actions visual polish (primary draft alignment) |
| **S4** | F10 menu + overlay **panel** chrome polish; optional history filter/table skin; closeout evidence |

## Success criteria

1. Cashier can complete sale → tender → print without new keyboard or focus regressions.
2. Frozen Register system suites green (see [test-matrix.md](test-matrix.md)).
3. Active workspace visually approaches `active_transaction.html` at 1280×720 and 200% zoom without unreachable controls.
4. Thermal print uses local faces; `fonts.googleapis.com` absent from POS/admin print layouts.
5. No domain service or Slice 7 contract changes in the diff.
