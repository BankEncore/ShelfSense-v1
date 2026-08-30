# Slice 6A — Customer-service surfaces

Status: **Implemented on branch** `90-customer-service-surfaces` ([#90](https://github.com/BankEncore/ShelfSense-v1/issues/90)). Delivery: one packet; three commits/PRs (**6A.1** / **6A.2** / **6A.3**). Close #90 after all three merge to `register-workspace-consolidation`.

Authority: [plan.md](plan.md), [implementation-plan.md](implementation-plan.md), [routing-and-authority.md](routing-and-authority.md), [user-stories.md](user-stories.md), [textual-wireframes.md](textual-wireframes.md) S12–S16 / P1–P5, [closeout-plan.md](closeout-plan.md), ADR-026 / ADR-027.

Issue: [#90](https://github.com/BankEncore/ShelfSense-v1/issues/90). Branch: `90-customer-service-surfaces`. PR target: `register-workspace-consolidation` (not `main`).

## Outcome

Compose read-only customer-service inquiry into the shared Register shell: Transactions & Receipts (S12/S13), Stored Value Inquiry (S14), Customer Summary (S15), and Pickup Queue (S16 view-only). Establish shared `Pos::RegisterShellContext` for header, menu policy input, return navigation, ownership, and expected-cash visibility. Do not duplicate transaction, stored-value, pickup, cash, or finalization mutations.

## Boundary statement

> Slice 6A consolidates customer-service inquiry into the Register shell. It may bridge back to existing workspace or cash-out workflows when operational context makes continuations legal, but it does not duplicate those mutation services. Every surface has explicit Register-state eligibility, direct-URL authorization, read-only GET behavior, and expected-cash protection. S16 Add to Transaction and Assisted Close stay out.

## Scope

| In | Out |
|---|---|
| `Pos::RegisterShellContext` (6A.1) | Till / session detail (6B) |
| S12 Transactions & Receipts + S13 detail in shell | Reporting / X / Z / P13 (6C) |
| Post-void / linked-return **entry chrome** only | Assisted Close |
| S14 three labeled SV find paths | S16 Add to Transaction bridge |
| S15 Customer Summary (read-only) | Customer create / merge / edit; attach from S15 |
| S16 Pickup Queue (view-only) | Prefix+last-four as possession |
| F10-only Keyboard Lock on inquiry | F1–F9 claims; SALE/TENDER remaps (7C) |
| Expected-cash gating on these surfaces | New cash types; duplicating mutation services |
| Menu items + `register_id` preservation | Slice 7 |

## Locked decisions

| Decision | Choice |
|---|---|
| Sequencing within Slice 6 | **6A → 6B → 6C** |
| 6A delivery | **One packet; three PRs** (6A.1 / 6A.2 / 6A.3) |
| Composition | Inside Register shell (P1–P5). Working basket preserved across F10 inquiry |
| Shell context | Shared read-only `Pos::RegisterShellContext` in **6A.1** |
| Keyboard | Inquiry pages: **F10-only** Keyboard Lock. No F1–F9 |
| S16 bridge | **Out of 6A** — view-only Pickup Queue |
| Assisted Close | Out of 6A–6C |
| S14 packaging | One `Pos::StoredValueInquiriesController` with **separate actions** per path — not three controllers, not one `mode=` |

## Surface / state eligibility matrix (packet law)

Hiding a menu item is not authorization. Every destination enforces the same rules on **direct URL**.

| Surface | Closed | Between sessions | Own session | Occupied | Selector / no Register |
|---|---|---|---|---|---|
| Transactions & Receipts | View | View | View / return entry | View if permitted | View |
| Stored Value Inquiry | View | View | View; contextual actions only per S14 table | View | View |
| Customer Summary | View | View | View | View | View |
| Pickup Queue | View | View | View only (6A) | View | View |

GET must not create a period, session, transaction, or cash record.

## Shared `Pos::RegisterShellContext` (6A.1)

```ruby
Pos::RegisterShellContext.call(
  store:,
  actor:,
  register:,
  session:,
  surface:,
  state: # RegisterStateResolver result (or equivalent facts)
)
```

Surfaces include at least: `:transaction_history`, `:stored_value_inquiry`, `:customer_summary`, `:pickup_queue` (and later `:till_activity`, `:session_detail`, `:active_sessions`, `:x_report`, `:z_period`, `:cash_operation`).

**Supplies:** header facts, status copy, F10 / menu policy input (`menu_surface: :inquiry`), return destination, `surface:`, Register/session ownership, expected-cash visibility.

**Must not:** read cookies/Rails session directly; create durable records; reimplement mutation services or RegisterMenu groups.

### Return navigation (exact)

```text
Own session        → existing workspace for that owned session/Register
Closed / between   → /pos?register_id=...
Occupied           → occupied Register state (never the other cashier’s workspace)
Selector / none    → /pos selector
```

Preserve `register_id` through inquiry links and forms. If the actor owns multiple sessions, do not silently choose one for return when the resolver already surfaced selector/custody warnings.

### Menu surface `:inquiry`

Suppress state-landing proxies (`open_register`, `open_session`, `finalize_z`) and workspace-only `close_session`. Customer-service items remain. Till / X / Z / active-sessions / switch / leave follow existing RegisterMenu permission and kind rules unless a later packet narrows them.

## Expected-cash protection (Slice 6 law; applied on 6A surfaces)

Without `cash.view_expected_before_count`, expected till totals are absent from shell chrome, inquiry pages, Turbo fragments, and direct URLs that these surfaces render. 6A surfaces do not introduce new expected-cash displays; they must not leak totals through reused partials.

## S12 / S13 — Transactions & Receipts (6A.1)

- Wrap index and show in `pos/shell/frame`.
- Replace orphan `_chrome` / history mini-nav with shell Close / Return using `RegisterShellContext#return_path`.
- Keep existing search and detail behavior; preserve filter `register_id` separately from shell register resolution when both are present (shell context uses resolver register; search filter remains a query param).
- Post-void and Begin Linked Return remain **entry chrome** to existing routes — no workflow redesign.
- Print receipt output must not include F10 / Return / shell status strips (existing print templates / `pos-no-print`; verify).

## S14 — Stored Value Inquiry (6A.2)

Inquiry first; continuation only when legal.

| Action | Required context |
|---|---|
| View balance/activity | Any authorized Register state |
| Tender with card | Own active session, working transaction, payment due |
| Reload | Own active session and explicit issuance flow |
| Cash-out | Own active session, eligible card/account, existing cash-out rules |
| Store-credit use | Correct customer/account context and payment due |

Inquiry never mutates merely because an exact card was found. Continuations **return to / invoke** existing workspace or cash-out workflows — no duplicated tender/issuance/cash-out services inside S14.

**Prefix/last-four:** masked inquiry only; never exposes continuation actions; never populates O10, tender fields, cash-out forms, or scan routing.

### Card-number protection

- No full numbers in GET query strings; **POST** for exact-number and prefix/last-four
- Filter card parameters from logs
- Never render full numbers after lookup
- Do not persist searched numbers in presenters longer than necessary
- Exact-number possession does **not** grant `gift_cards.view`
- Audit administrative prefix/last-four inquiry (existing `GiftCards::AdminInquiry` audits)
- Test browser history, redirect URLs, and rendered HTML for number leakage
- **Separate actions/commands** per path (no shared `mode=` that can cross possession/admin)

### Controller shape

```text
GET  /pos/stored_value_inquiry          → show (blank form; three labeled paths)
POST /pos/stored_value_inquiry/exact    → exact_number (GiftCards::Lookup)
POST /pos/stored_value_inquiry/store_credit → store_credit (customer → account)
POST /pos/stored_value_inquiry/admin    → admin_prefix_last_four (GiftCards::AdminInquiry; gift_cards.view)
```

## S15 — Customer Summary (6A.3)

Read-only: identity/contact; recent transactions; open requests/pickups; store-credit balance/activity; link to full Customer workspace when authorized. **No** edit, merge, or attach from S15.

## S16 — Pickup Queue (6A.3)

View-only: ready/eligible pickups; customer/request identity; location/status/expiration; fulfillment blockers. **Add to Transaction deferred** (explicit Out).

## Delivery split

| PR | Scope |
|---|---|
| **6A.1** | `RegisterShellContext` + return-nav + Transactions & Receipts / detail (+ post-void/return entry chrome) in shell; replace orphan history chrome for those pages |
| **6A.2** | S14 three-path SV inquiry + menu item + card-number protection + audits/tests |
| **6A.3** | S15 + S16 view-only + menu items; close #90 after merge |

## Primary touch points

- `app/services/pos/register_menu.rb`, `app/helpers/pos_register_shell_helper.rb`, `app/views/pos/shell/`
- New: `Pos::RegisterShellContext` (+ tests)
- `app/controllers/pos/transactions_controller.rb`, `app/views/pos/transactions/*`
- New: `Pos::StoredValueInquiriesController` + presenters; `GiftCards::Lookup` / `GiftCards::AdminInquiry`
- New: customer summary + pickup queue controllers/views/presenters
- Replace `app/views/pos/transactions/_chrome.html.erb` usage as history migrates

## Tests (minimum)

- `RegisterShellContext` return paths for own / closed / between / occupied / selector
- Menu `:inquiry` suppresses open/finalize/close proxies
- Transactions index/show render inside shell; GET creates no session/period
- Direct URL eligibility matches matrix (all View for 6A surfaces)
- S14: separate POSTs; no card number in GET/redirect/HTML; Lookup vs AdminInquiry isolation; prefix path has no continuation actions
- S15/S16: read-only; no attach / no Add to Transaction
- Expected-cash helper still gates any reused cash fragments
- Update [test-matrix.md](test-matrix.md) with 6A rows

## Manual verification

[slice6a-manual-verification.md](slice6a-manual-verification.md)
