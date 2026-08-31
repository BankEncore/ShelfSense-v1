# Slice 7A — Tender Review (ordinary tender correction)

Status: **Complete** on `register-workspace-consolidation` ([#93](https://github.com/BankEncore/ShelfSense-v1/issues/93) / PRs [#115](https://github.com/BankEncore/ShelfSense-v1/pull/115), remediation [#116](https://github.com/BankEncore/ShelfSense-v1/pull/116)). Inventory gate was met ([slice7-tender-lifecycle-inventory.md](slice7-tender-lifecycle-inventory.md)). Evidence: [slice7a-manual-verification.md](slice7a-manual-verification.md).

Authority: [plan.md](plan.md), [implementation-plan.md](implementation-plan.md), [slice7-overview.md](slice7-overview.md), [slice7-tender-lifecycle-inventory.md](slice7-tender-lifecycle-inventory.md), [slice7-keyboard-contract.md](slice7-keyboard-contract.md), [slice5a-lookup-overlays-plan.md](slice5a-lookup-overlays-plan.md) (overlay lifecycle), [slice5d-tender-issuance-plan.md](slice5d-tender-issuance-plan.md) (O11 add path unchanged), [textual-wireframes.md](textual-wireframes.md) P10 / **O15–O17**, [user-stories.md](user-stories.md), [routing-and-authority.md](routing-and-authority.md).

Issue: [#93](https://github.com/BankEncore/ShelfSense-v1/issues/93). Packet-lock branch: `93-slice7a-tender-review-plan` (docs only; does not complete implementation of #93).

## Outcome

Add Tender Review over the existing working transaction: semantic selection of applied tenders, ordinary-family remove and atomic replace, and Return to Sale that clears ordinary tenders only. Preserve add paths (O11 / F1–F5 / command field). Do not mutate stored-value or issuance rows. Do not remap live keys (7C).

## Boundary statement

> Slice 7A adds Tender Review over the working transaction: semantic tender selection, ordinary tender remove/replace, and Return to Sale for ordinary tenders only. Stored-value and issuance mutation stay out. No temporary global shortcuts; runtime keys remain Phase 6.7 (plus Slice 5D `+` → O11) until 7C. Working correction is audited destroy plus add under one transaction lock with OperationLease replay — not a stored-value ledger reversal and not a supersession schema on `pos_tenders`.

## Scope

| In | Out |
|---|---|
| Tender Review mode when ≥1 working tender applied | SV / issuance Edit / Remove (7B) |
| Semantic selection (`aria-selected`; survive Turbo) | Auto-cap / SV completion revalidation (7B) |
| Select / inspect SV rows; mutate unavailable + concise reason | Quick Customer / nested customer lookup (7B) |
| O15 / O16 for **ordinary** families; O17 Return to Sale | Temporary document-level `-` / `+` handlers; 7C dispatcher |
| `Pos::ReplaceTender` + `Pos::OperationLease` command types | Supersession schema on `pos_tenders` |
| Cash presented / applied / change on replace | Card processor integration or auth-reversal service |
| Selected-tender remove (pointer / Tab / Enter in 7A; F8 key binding in 7C) | Issuance edit; merging issuances into merchandise |
| Replace F8 “last tender only” UX for Tender Review | Weakening completion / custody / auth tests |

## Locked decisions

| Decision | Choice |
|---|---|
| Delivery | **Three PRs** (7A.1 / 7A.2 / 7A.3) under [#93](https://github.com/BankEncore/ShelfSense-v1/issues/93) |
| Enter Tender Review | When ≥1 working tender is applied |
| Settlement labels | Balance Due / Refund Remaining / Settled / Even Exchange (plus Completing / Completion Failed when completion is in flight or failed) |
| Selection | At most one selected tender; `aria-selected` (or equivalent); selection survives whole-workspace Turbo replacement when the tender still exists; after remove, select nearest remaining row; clear when empty; **focus ≠ selection**; not color-only |
| Ordinary families | Cash, check, configured manual-reference other, card (see card rule) |
| Card correction | Remove working row → any required **external** reauthorization outside/currently supported by ShelfSense → record replacement authorization/reference. No field-edit of an external auth; ShelfSense has no integrated card auth-reversal for working tenders |
| Persistence | Audited **destroy + add** in one DB transaction under txn lock; cash upsert allowed inside orchestration where equivalent; no supersession columns |
| Idempotency | `Pos::OperationLease` / `PosOperation` with distinct `command_type`s — **not** audit-only keys |
| Return to Sale | Ordinary tenders only: atomic clear or change nothing. **Any SV tender present → refuse** with explanation until 7B. Not Cancel Transaction |
| Confirmations | O16 remove and O17 Return to Sale yes; ordinary field edits no |
| Keyboard (7A) | Buttons, accessible controls, controller actions, semantic events only. **No** temporary global shortcuts or independent document-level key handlers |
| Overlays | O15 / O16 / O17 on shared 5A blocking-overlay lifecycle |
| Wireframe O16 SV copy | Working remove does **not** restore ledger value; SV-specific restore consequence text is **7B**. Ordinary O16 copy must not claim ledger restore |

### PR split

| PR | Scope |
|---|---|
| **7A.1** | Tender Review chrome + selection model + SV inspect-only affordances (no mutate) |
| **7A.2** | Idempotent ordinary remove + O16; `command_type` e.g. `pos.remove_working_tender` |
| **7A.3** | `Pos::ReplaceTender` + O15; Return to Sale O17 (ordinary-only clear; refuse if any SV tender); `command_type`s e.g. `pos.replace_working_tender`, `pos.return_to_sale_clear_tenders` |

## Tender Review state

Workspace enters Tender Review when at least one working tender is applied.

State includes: transaction; settlement direction; applied tenders; selected tender id; remaining due/refund; available actions for selection; completion eligibility; pending mutation / lease status.

Do **not** describe applied working tenders as pending authorizations.

| Settlement | Label |
|---|---|
| Positive remainder | Balance Due |
| Negative remainder | Refund Remaining |
| Exactly settled | Settled |
| Zero commercial total with mixed activity | Even Exchange |
| Completion running | Completing |
| Completion failed | Completion Failed |

## Selection contract

- One selected tender at most.
- Selected record id survives whole-workspace Turbo replacement when still present.
- After removal, selection falls to the nearest remaining row; clears when the list is empty.
- Focus and selection are distinct.
- Selected state uses `aria-selected` or an appropriate equivalent; not color or chevron alone.
- 7A provides pointer, Tab, and Enter access. Do not invent temporary POS shortcuts that 7C will replace.

## Actions for selected tender

| Action | Ordinary (7A) | Stored value / issuance |
|---|---|---|
| View / inspect | Yes | Yes |
| Edit / Replace (O15) | Yes when family supported | Unavailable — concise reason until 7B |
| Remove (O16) | Yes when supported | Unavailable — concise reason until 7B |
| Add another tender | Opens O11 / existing add path | Same |
| Return to Sale | O17 when only ordinary tenders (or empty after clear) | Refuse O17 clear while any SV tender remains |
| Complete | When exactly settled | Unchanged |

Unavailable actions are omitted or show a short reason, for example: stored-value tender correction becomes available after Slice 7B. Remove that staging message once 7B lands.

## Ordinary remove (7A.2)

- Confirm with **O16** when destructive confirmation is required (inventory: confirm destructive/reversal actions).
- Service path: authorize → OperationLease begin → lock working transaction → verify tender membership and ordinary family → destroy → audit in same DB txn → complete lease.
- Replay of the same key returns the original successful outcome; payload mismatch is an error.
- Must **not** call `StoredValue::Reverse` (nothing posted yet).
- Must **not** remove SV tenders through this path in 7A (UI and service gate).

## Atomic replace — `Pos::ReplaceTender` (7A.3)

```text
authorize → OperationLease begin → lock transaction
  → verify working membership + ordinary family supported
  → validate full replacement
  → destroy original → add replacement (cash upsert OK if equivalent)
  → audit in same DB transaction → recalc settlement → commit lease
```

On any failure after lock: original tender unchanged; audit for the failed attempt must not commit as a successful mutation record.

### Cash

```text
Cash presented = Cash applied + Change
```

Replacement inputs: amount intended to settle; cash presented. Persist applied, presented, and change. Validate presented sufficient for payment; refund direction and availability rules; no illegitimate over-settle except legitimate change behavior; change is not another tender row.

### Card / check / other

- Check and configured manual-reference other: replace amount/reference via orchestration.
- Card: remove working row; cashier performs any required external reauthorization; record new reference/amount as replacement — no integrated ShelfSense card reverse.

## Return to Sale (7A.3 / O17)

```text
No applied tenders → return to Sale directly (no O17)
Ordinary tenders only → O17 confirm → atomic clear via lease or change nothing
Any stored-value tender present → refuse with explanation (7B owns SV clear)
```

Consequence copy must match inventory: commercial lines cannot change while tenders remain; clearing requires re-tendering. Do not treat Return to Sale as Cancel Transaction (F9).

Underlying `clear_working_tenders!` capability must **not** be exposed for SV rows through this UI before 7B.

## Overlays (O15–O17)

| Overlay | Role |
|---|---|
| O15 | Ordinary tender edit / atomic replacement |
| O16 | Remove confirmation (ordinary; no false ledger-restore copy) |
| O17 | Return to Sale with applied ordinary tenders |

Lifecycle: 5A stack, inertness, focus restore, Escape closes child then parent. F10 suppressed while blocking overlay open (existing shell law).

**Wireframe correction:** [textual-wireframes.md](textual-wireframes.md) O15/O16 prose that implies working SV ledger reverse/restore is **not** 7A authority. Inventory governs; update wireframe notes in the owning implementation PR or a small docs follow-up if needed.

## Idempotency command types

| Mutation | Example `command_type` |
|---|---|
| Remove working tender | `pos.remove_working_tender` |
| Replace working tender | `pos.replace_working_tender` |
| Return to Sale clear | `pos.return_to_sale_clear_tenders` |

Register-scoped `source_id`, canonical payload hash, in-flight / completed / failed replay per `Pos::OperationLease`. Optimistic `lock_version` remains required and is not a substitute for lost-response replay.

## Authorization

Existing POS transact / cashier / active-context rules. No new permission keys in 7A. Server must enforce ordinary-only mutate and SV refuse even if the client is crafted.

## Testing (implementation)

- Select each supported ordinary tender; inspect SV without mutate controls.
- Remove first / middle / last ordinary tender; selection nearest / clear.
- Edit cash / check / other; card remove + re-record reference.
- Replace failure preserves original; stale transaction/tender; concurrent remove/replace.
- Idempotent lease retry; payload mismatch.
- Cash presented / change correction; settlement after correction; exact settlement enables completion; over/under; payment and refund; even exchange.
- SV tender remains untouched by remove/replace; Return to Sale refuses when SV present; succeeds for ordinary-only.
- Basket survives F10 inquiry round-trip; pointer and Tab/Enter accessibility; O15–O17 Escape / focus.

## Assert no change to

Reporting periods; sessions; completed transactions; posted tenders; stored-value ledger (except unchanged); cash operations; receipt numbering; Phase 6.7 runtime keys beyond existing 5D `+` exception.

## Full-lock criterion

Met when this packet is on `register-workspace-consolidation` with inventory already complete. Implementation landed as [#115](https://github.com/BankEncore/ShelfSense-v1/pull/115) (7A.1–7A.3 together) with remediation [#116](https://github.com/BankEncore/ShelfSense-v1/pull/116).
