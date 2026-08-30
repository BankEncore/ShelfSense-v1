# Slice 6B — Till and session detail

Status: **Packet locked** (not started). Depends on Slice 6A shell context and eligibility law.

Authority: [plan.md](plan.md), [implementation-plan.md](implementation-plan.md), [routing-and-authority.md](routing-and-authority.md), [slice6a-customer-service-plan.md](slice6a-customer-service-plan.md) (shared `RegisterShellContext`, eligibility matrix, expected-cash), [textual-wireframes.md](textual-wireframes.md) S17–S19 / S21–S23, [user-stories.md](user-stories.md).

Issue: [#91](https://github.com/BankEncore/ShelfSense-v1/issues/91). Branch: `91-till-session-detail`. PR target: `register-workspace-consolidation`.

## Outcome

Compose Till Activity, Session Details, Active Sessions enhancements, and cash operation detail into the Register shell. Shell-wrap existing paid-in/out, drop, replenish, and gift-card cash-out forms (S21/S22). Enable reverse-from-original on cash activity detail; delete the generic reverse launcher in the same PR.

## Boundary statement

> Slice 6B wraps till and session inquiry and existing cash forms in the shared shell. It does not invent new cash types or duplicate reverse services. Reverse is only from an eligible original; confirmation uses a distinct overlay ID assigned before markup (not O10).

## Scope

| In | Out |
|---|---|
| S17 Till Activity | Reporting / X / Z / P13 (6C) |
| S18 Session Details | Assisted Close |
| S19 Active Sessions enhancements | New cash types |
| S21/S22 shell wrap of existing cash forms | Redesigning cash mutation services |
| S23 cash activity detail + reverse-from-original | Generic reverse launcher (delete) |
| Expected-cash gating on these surfaces | Slice 7 |
| Distinct reverse confirmation overlay ID | Using O10 for reverse confirm |

## Reverse-from-original (packet law)

- Only an eligible original exposes Reverse
- Cannot reverse a reversal; cannot reverse twice
- Revalidate authorization and session/register custody at commit
- Revalidate cash availability when reversal removes session cash
- Confirmation shows original operation, amount, direction, performer, time, resulting effect
- Existing reverse service; idempotent
- Detail page reflects reversal relationship immediately
- Generic launcher + obsolete tests deleted in the **same PR**
- Distinct confirmation overlay ID assigned **before** markup (not O10)

## Eligibility (from Slice 6 matrix)

| Surface | Closed | Between sessions | Own session | Occupied | Selector / no Register |
|---|---|---|---|---|---|
| Till Activity | No current till | Historical | Current session | Permission-controlled view | No |
| Session Details | Historical only | Historical | Current | `pos.sessions.view` | No |
| Active Sessions | Permission | Permission | Permission | Permission | Permission |

GET must not create a period, session, transaction, or cash record.

## Default for S21/S22

Shell wrap of existing cash forms (no new cash types; layout refresh only if required for shell fit).

## Shared context

Reuse `Pos::RegisterShellContext` surfaces `:till_activity`, `:session_detail`, `:active_sessions`, `:cash_operation`. Menu surface `:inquiry` (or cash-specific if needed) — no open/finalize/close proxies.

## Manual verification

Add `slice6b-manual-verification.md` when implementation starts.
