# Slice 6C — Reporting-period surfaces

Status: **Packet locked** (not started). Depends on Slice 6A shell context and Slice 6B till/session patterns where shared.

Authority: [plan.md](plan.md), [implementation-plan.md](implementation-plan.md), [routing-and-authority.md](routing-and-authority.md), [slice6a-customer-service-plan.md](slice6a-customer-service-plan.md), [textual-wireframes.md](textual-wireframes.md) S9–S11 / S20 / P13, [user-stories.md](user-stories.md).

Issue: [#92](https://github.com/BankEncore/ShelfSense-v1/issues/92). Branch: `92-reporting-period-surfaces`. PR target: `register-workspace-consolidation`.

## Outcome

Compose X Report, Session / Z Reports, closed-session detail, and Z status/finalize into the Register shell. Introduce **P13** as a shared projection over existing facts (not a second report calculator). Ensure print/X/Z/receipt/voucher output omits interactive shell chrome.

## Boundary statement

> Slice 6C consolidates reporting-period inquiry and finalize into the Register shell. P13 projects existing session and period facts; presenters do not persist totals. Finalize revalidates blockers on POST. Print views must not include F10, Return to Register, status strips, or interactive navigation.

## Scope

| In | Out |
|---|---|
| S9–S11 reporting destinations in shell | Assisted Close |
| S20 closed-session detail | New financial ledgers |
| P13 shared totals projection | Recalculating sales outside existing facts |
| Finalize Z GET blockers / POST once | Bypassing blockers via earlier GET |
| Print chrome absence tests | Slice 7 |
| Expected-cash gating on X/Z/session/print | Changing finalized snapshot authority |

## P13 / financial authority

P13 is a **shared projection over existing facts**, not another report calculation.

- X = session-scoped; closed-session = one session snapshot; Z = reporting-period cumulative
- Sale/return signs and tender totals reconcile to completed transactions
- Cash operations separate from sales/tenders
- Stored-value issuance and redemption not conflated
- Presenters do not persist totals; finalized reports use immutable snapshots where available

## Finalize

```text
GET  → read-only blockers / confirmation
POST → revalidate blockers, lock, finalize once
```

No open session, working transaction, incomplete closing snapshot, or stale eligibility bypass via an earlier confirmation GET.

## Print

Screen reports use Register shell. Print-specific X/Z, receipts, vouchers **must not** print F10, Return to Register, shell status strips, or interactive navigation. Print CSS or dedicated print templates; test chrome absence.

## Eligibility (from Slice 6 matrix)

| Surface | Closed | Between sessions | Own session | Occupied | Selector / no Register |
|---|---|---|---|---|---|
| X Report | No current X | Prior/closed reports | Current X | `pos.sessions.view` | No |
| Z status | Historical | Current period | View only | Permission-controlled | No |
| Finalize Z | No | When eligible | No | No | No |

GET must not create a period, session, transaction, or cash record.

## Shared context

Reuse `Pos::RegisterShellContext` surfaces `:x_report`, `:z_period`, and session detail as applicable.

## Manual verification

Add `slice6c-manual-verification.md` when implementation starts.
