# Slice 6C — Reporting-period surfaces

Status: **Fully locked.** Report-content inventory complete ([report-content-inventory.md](report-content-inventory.md)); snapshot-envelope extensions for 6C: **none.** Implementation may proceed as 6C.1 → 6C.2 → 6C.3 on branch `92-reporting-period-surfaces`. Depends on Slice 6A shell context and Slice 6B till/session patterns.

Authority: [plan.md](plan.md), [implementation-plan.md](implementation-plan.md), [routing-and-authority.md](routing-and-authority.md), [slice6a-customer-service-plan.md](slice6a-customer-service-plan.md), [slice6b-till-session-plan.md](slice6b-till-session-plan.md), [report-content-contract.md](report-content-contract.md), [report-content-inventory.md](report-content-inventory.md), [textual-wireframes.md](textual-wireframes.md) S8–S11 / S20 / P13, [user-stories.md](user-stories.md).

Issue: [#92](https://github.com/BankEncore/ShelfSense-v1/issues/92). Branch: `92-reporting-period-surfaces`. PR target: `register-workspace-consolidation`.

## Outcome

Compose current X, closed-session reporting, reporting-period status, finalized Z, and Z finalization inside the Register shell. Define P13 as a shared presentation contract over authoritative live report results and immutable finalized snapshots. Before implementing P13, inventory every proposed report row against current models, services, and snapshots. Deliver a full screen report and a compact shift-end tape using supported P13 facts. Ensure report and artifact printing excludes interactive Register-shell chrome.

## Boundary statement

> Slice 6C composes current X, historical session reporting, reporting-period status, finalized Z, and Z finalization inside the Register shell. P13 formats authoritative live report results or immutable finalized snapshots according to explicit source precedence; it does not independently query, reprice, or persist commercial totals. Each proposed report row must be classified as currently supported, safely projectable, unavailable in historical snapshots, or future-domain work before implementation. Finalization targets one explicit reporting period and atomically revalidates authorization, blockers, and stale state before producing exactly one immutable result.

## Scope

| In | Out |
|---|---|
| Code-backed report-content inventory | Inventing unavailable report facts |
| S9–S11 reporting-period destinations | Assisted Close |
| Session Details enhancement for closed-session P13 (not a second closed-session surface) | A second closed-session controller/destination |
| P13 semantic report contract | New financial ledgers |
| Screen Session/Z reports | Independent view-level calculations |
| Compact shift-end tape from supported P13 facts | Used Buyback and Trade Credit before those domains exist |
| Reporting-period/session resolution | Silent fallback from inaccessible explicit IDs |
| Finalize GET blockers and atomic POST | Bypassing POST revalidation |
| Immutable snapshot source precedence | Recalculating finalized reports from live data |
| Expected-cash gating on screen and print | Query parameters controlling sensitive visibility |
| Print-contract verification | Receipt/voucher redesign |
| Minimal snapshot-envelope extension **only if** explicitly approved after inventory | Fabricating missing historical values |

## Wireframe surface map (terminology lock)

| Wireframe | 6C meaning |
|---|---|
| **S20** | Live **X Report** for an open session (unchanged ID) |
| **S8** / Session closed result | Closeout result; may link into Session Details |
| **Session Details** (Slice 6B route) | Hosts **closed-session** P13 + print; enhance in place |
| **S9** | Z-period status (open period cumulative + readiness) |
| **S10** | Finalize Z confirmation (GET) |
| **S11** | Finalized Z report (immutable snapshot) |
| **P13** | Shared report totals presentation contract |

Do **not** redefine S20 as closed-session detail. Do **not** keep a competing `closed_sessions` navigation destination after 6C; redirect/retire it into Session Details.

Once a session is closed, its report is a **Closed Session Report**, not an “X Report.” X is live and non-closing for an open session only.

## Report-content gate

**Complete (2026-08-30).** Every proposed row in [report-content-inventory.md](report-content-inventory.md) has a disposition. Snapshot extensions approved for 6C: **none** (omit fine/unsupported rows on finalized Z rather than migrate). [report-content-contract.md](report-content-contract.md) remains the semantic target; P13 renders only inventory-permitted rows per surface.

Gate checklist (done):

1. ~~Complete inventory — every proposed row has a disposition.~~
2. ~~Keep contract as semantic target (no implementability claims).~~
3. ~~Mark this packet fully locked for 6C.1–6C.3 implementation.~~

### Disposition taxonomy

| Disposition | Meaning |
|---|---|
| Required now — existing authority | Live and/or snapshot already authoritative |
| Required now — presenter grouping | Existing facts; P13 only regroups/labels |
| Prospective snapshot extension | Live fact exists; freeze on finalize only after explicit approval |
| Omit when unavailable | Hide row; never show `$0.00` as “not captured” |
| Deferred | Known gap; not in 6C UI |
| Future domain | e.g. trade credit, used buyback — semantic contract only |

If a desired fact exists live but is not preserved at finalization, choose exactly one: extend the immutable snapshot prospectively; omit from finalized reports; or defer. **Never** reconstruct a finalized value from current configuration or live recompute.

**“Not captured”** appears only for operationally important facts missing from an **old** snapshot. Future/deferred/unsupported rows are omitted entirely.

## P13 / financial authority

P13 is a **shared presentation contract** over existing domain results — not a second report calculator. Evolve/replace `Pos::OperatorReport` into the P13 presenter over `SessionTotals` / `PeriodTotals`. Do not keep two parallel calculators.

- X = open-session live scope
- Closed-session report = one session (Session Details)
- Current Z = open reporting-period cumulative (live)
- Finalized Z = immutable period snapshot

P13 may only show a component when the inventory identifies an authoritative source. Gift-card **issuance** must never be combined with gift-card **tender** use. Operational cash does not change revenue or tender settlement.

Two presenters select from the same P13 facts:

| Section | Screen report | Shift-end tape |
|---|---|---|
| Identity | Full | Compact |
| Commercial activity | Full | Essential rows |
| Tender settlement | Full | Nonzero tenders |
| Stored-value activity | Full when supported | Nonzero summary |
| Operational cash | Full | Nonzero operations |
| Cash reconciliation | Full | Required |
| Transaction metrics | Full | Essential counts |
| Controls/exceptions | Full | Nonzero summary |
| Detailed explanatory text | Yes | No |
| Averages | Optional | Generally no |

Shift-end tape: canonical **42-character** monospaced width (fits current ~80mm print path). Defer 32-character / 58mm unless that printer class is adopted. Do not create a separate financial calculator for the tape.

## Source precedence

```text
Finalized immutable snapshot
  → authority for finalized Z and finalized closed-session facts (where snapshotted)

Existing live report/domain result
  → authority for current X and current Z

Completed transactions, tenders, and cash records
  → inputs to existing domain projections only

P13 presenter
  → labels, groups, and formats those results
```

Rules:

- No live fallback for missing finalized snapshot facts
- No current tax/tender/reason names when snapshots preserve historic names
- Reprints use original snapshot values
- P13 does not query raw transaction lines merely because a preferred row is missing

## Report resolution

Introduce `Pos::ReportingSurfaceResolver` or extend Slice 6B inquiry resolution without duplicating ownership/`pos.sessions.view` law.

| State | Default |
|---|---|
| Own session | Current session X; current-period status |
| Occupied | Occupying session / current period when authorized |
| Between sessions | Current open reporting period; closed-session selection within it |
| Closed | Recent finalized-period chooser |
| Selector | Require Register selection |
| Explicit `session_id` | Exact authorized session |
| Explicit `reporting_period_id` | Exact authorized period |

Validation: IDs ∈ `current_store`; Register/session/period agree; inaccessible explicit IDs do not fall back or leak facts; historical session access follows 6B ownership / `pos.sessions.view`; GET never creates period, session, transaction, cash, or configuration records.

## Eligibility

| Surface | Closed | Between sessions | Own session | Occupied | Selector |
|---|---|---|---|---|---|
| Current X | No | No | Own current session | `pos.sessions.view` | No |
| Closed Session Report | Authorized historical chooser | Authorized sessions | Yes (own historical) | `pos.sessions.view` | No |
| Current Z status | No open period; historical chooser | Current open period | View only | Permission-controlled view | No |
| Finalized Z | Historical chooser | Prior finalized periods | Historical | Permission-controlled | No |
| Finalize Z | No | Eligible current period only | No | No | No |

## Expected cash and variance

| Fact | Visibility |
|---|---|
| Opening float | Existing policy |
| Counted closing cash | Existing closing-count policy |
| Expected cash | `cash.view_expected_before_count` |
| Variance | Same gate when it reveals expected cash |
| Operation signed effects | Visible with authorized report access |
| Running / resulting till balance | Expected-cash permission |

Print endpoints **re-evaluate** permission. They must not trust screen presenter state, hidden fields, `show_expected_cash` parameters, or CSS alone. If blind-count policy prevents derivation, pre-count reports also hide inputs that would reconstruct expected cash.

## Finalize

```text
GET
  → resolve one explicit reporting period
  → display current read-only blockers and warnings (structured separately)
  → include lock_version / stale-state token

POST
  → authorize again
  → lock explicit reporting period and closing facts
  → verify stale state
  → recompute blockers
  → finalize once
  → create or return one immutable snapshot
```

Guarantees: no implicit “currently open period” substitution; no open session; no working transaction; complete required closing snapshots; deterministic lock order; concurrent submissions produce one finalization; replay redirects to existing finalized result; failure leaves period open; no partial snapshot; actor/time/result audited.

## Print

Screen reports render in the Register shell. Printable report regions or dedicated templates contain **only** report content. Existing receipt and voucher renderers get regression coverage for shell contamination but are not redesigned. Tests verify markup boundaries, print CSS, permission-sensitive contents, and rendered print behavior; `.pos-no-print` alone is insufficient.

Required exclusions: F10 launcher/menu; Return to Register; status and custody strips; notices and interactive feedback; filters, pagination, mutation controls; hidden dialogs; authorization-only content when the print request lacks permission.

## GET immutability

Cover: report index; current X; closed-session report; current Z status; historical/finalized Z; finalize confirmation; print endpoints.

Assert no change to: reporting periods; sessions; transactions; cash operations and entries; closing snapshots; finalized snapshots; reason/configuration records.

Prohibit `seed!` or equivalent configuration repair in GET report controllers.

## Shared context

Reuse `Pos::RegisterShellContext` surfaces `:x_report`, `:z_period`, and session detail as applicable. Inquiry menu surface suppresses Open/Finalize/Close proxies per 6A/6B.

## Delivery (one issue, three PRs)

```text
6C.1 → 6C.2 → 6C.3
```

| PR | Scope |
|---|---|
| **6C.1** | Reporting resolver; P13 presenter (evolve/replace OperatorReport) + reconciliation tests; shell-wrap live X (S20); Session Details closed-session P13 enhancement — honor inventory dispositions |
| **6C.2** | S9/S11; period/session chooser; current Z status; finalized snapshot rendering; full screen reports |
| **6C.3** | S10 GET + atomic/idempotent POST; shift-end tape; formal report print; receipt/voucher chrome regressions; high-zoom and print verification |

Full-lock criterion: met — every inventory row has a disposition; snapshot-envelope extensions for 6C: none.

## Manual verification

[slice6c-manual-verification.md](slice6c-manual-verification.md) — expand when implementation starts; include inventory sign-off and print/chrome cases.
