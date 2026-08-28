# Register workspace consolidation — Routing and authority

Status: **Accepted** with Slice 1.

## Staged supersession of Phase 6.7

[pos-workflow.md](../phase4-6-point-of-sale/phase6-pos-mvp/pos-workflow.md) remains implementation authority until the owning slice merges.

| Slice | Supersedes |
|---|---|
| 2 | Phase 6.7 **§4** POS Home and Register-entry chrome |
| 3 | Phase 6.7 **§6 F10 binding** and **§14 F10 transaction-history entry** |
| 7C | The remainder of Phase 6.7 **§6** and any affected Enter/Escape/modal sections, after acceptance of the replacement keyboard contract |

Slice 3 supersedes **F10 as the direct entry to Transactions**. It does **not** supersede transaction-history behavior, search, linked-return workflow, or working-basket preservation.

Until Slice 7C, all other 6.7 keys (`F1`–`F9`, `/`, `-`, `.`, `*`, `+`, Enter, Escape) remain lock.

## GET versus POST

GET `/pos` and GET workspace may resolve a Register, evaluate `OpenGate`, select a state body, and display an existing working transaction. They must not:

- open a reporting period
- open a session
- transfer opening float or other cash
- create a working transaction

Mutating entry remains `POST` enter / `EnterRegister` / `ResumeOrStartTransaction`. Workspace GET that finds no working transaction uses the existing redirect-to-enter recovery path.

GET immutability tests must compare **counts and relevant record state** (for example `lock_version`, `expected_balance_cents`, `initialized_at`). Counts alone miss in-place updates.

## `Pos::RegisterStateResolver`

The controller gathers request-specific inputs. The resolver must not read cookies, Rails session, `current_user`, or `current_store` implicitly.

```ruby
Pos::RegisterStateResolver.call(
  store: current_store,
  actor: current_user,
  requested_register: requested_register,
  preferred_register: preferred_register,
  bound_register_id: session[:pos_register_id],
  owned_open_sessions: cashier_open_sessions
)
```

Return a presentation-neutral result:

```text
kind: selector | closed | between_sessions | own_session | occupied
register
gate          # OpenGate for the selected register, if any
owned_sessions
reason
```

Helpers/presenters own user-facing language (including **Your session — Resume**).

### Routing table (Slice 2)

| Case | Expected `kind` |
|---|---|
| No selected/preferred/bound Register | `selector` |
| Valid preferred or bound closed Register | `closed` |
| Open period, no session | `between_sessions` |
| Prior-date period, no session | `between_sessions` (prior-date qualifier) |
| Own session (working transaction or not) | `own_session` — GET creates nothing |
| Other cashier’s session | `occupied` |
| One owned session without binding | that session (`own_session`) |
| Multiple owned sessions without binding | `selector` with every owned session |
| Multiple owned sessions with valid binding | bound owned session |
| Stale or inactive preferred Register | ignore preference; fall through |
| Register from another store | ignore/reject |
| Missing `pos.transact` | existing POS authorization denial |

## Temporary destination cluster (Slice 2 only)

One partial, one eligibility policy, **deleted in Slice 3**. Not a literal copy of POS Home buttons on every state.

Preserve every **currently eligible** destination:

| Destination | Closed | Between sessions | Own session | Occupied |
|---|---|---|---|---|
| Transactions | Yes | Yes | Yes | Yes |
| Session/Z Reports | Yes | Yes | Yes | `pos.sessions.view` |
| X Report | No | No | Own X | `pos.sessions.view` |
| Till operations | No | No | Yes | No |
| Active Sessions | Permission-controlled | Permission-controlled | Permission-controlled | Permission-controlled |
| Switch Register | Yes | Yes | Yes | Yes |

**X Report exists only for an open session.** Between sessions has no current X. Historical totals stay under Session/Z Reports, never labeled X.

Reverse Cash is **not** in the cluster (overexposure). Keep the reverse **route and service** until Slice 6B.

## Expected cash

Hide **before-count** expected till/session totals unless `Authorization::PermissionEvaluator.allowed?(user:, permission_key: "cash.view_expected_before_count", store:)`.

`can_view_expected_cash?` is a POS controller `helper_method`. Open-session X omits Expected Cash without that permission. Closed-session and finalized Z reconciliation snapshots stay visible after count. Known operation effects (drop −$300 / safe +$300) may still show. Availability errors may say the amount exceeds available session cash without revealing expected totals.

## Stored-value inquiry (Slice 6A)

Three labeled find paths — not one field that might accept a complete number or prefix + last four.

1. **Exact number** — `GiftCards::Lookup` / digest possession. May lead to eligible reload, tender, cash-out.
2. **Customer store credit** — customer identity → account relationship. Not a card possession test.
3. **Prefix + last four** — `GiftCards::AdminInquiry` (or equivalent), `gift_cards.view`, masked candidates. Must not call the possession path, feed scan routing, or start redeem/reload/cash-out/completion ([ADR-026](../../adr/ADR-026-gift-card-number-protection.md), [ADR-027](../../adr/ADR-027-admin-gift-card-prefix-last-four-inquiry.md)).

## Current route disposition

`GET /pos` → `pos/homes#show` (`pos_path`). Helper name may remain; user-visible semantics become state-aware entry in Slice 2. Delete generic `pos/homes/show` markup in Slice 2.

| Route / helper | Disposition |
|---|---|
| `pos_path` | Slice 2: state resolver. Stop treating as POS Home. |
| `pos_register_enter_path` GET/POST | Keep; POST remains mutating entry. GET may be absorbed into closed/between bodies. |
| `pos_register_workspace_path` | Keep; wrap in shell (Slice 2); recompose `_surface` (Slice 4). |
| `pos_transactions_path` / show | Keep; F10 destination (Slice 3); compose as Transactions & Receipts (Slice 6A). |
| `pos_x_report_path`, session X | Keep; cluster then F10; shell integration Slice 6C. |
| `pos_reports_path`, closed session, Z | Keep; cluster then F10; Slice 6C. |
| `pos_active_sessions_path` | Keep; permission-filtered; Slice 6B enhancements. |
| `pos_switch_register_path` | Keep; selector. |
| Cash paid-in/out, drop, replenish, cash-out | Keep services; cluster (own session) then F10 Till; frames later. |
| `pos_cash_reversals_path` | Remove **nav** Slice 3; remove generic launcher Slice 6B if no other caller. Keep service. |
| Workspace merchandise/tender/return posts | Keep endpoints; migrate overlay markup in 5A–5D. |
| Session close, period finalize | Keep full surfaces; F10 launches them. |

Safe recon and deposit remain **outside** Register (admin cash).
