# Register surface polish

Status: **Proposed packet** — awaiting acceptance before implementation.

**Program type:** Register follow-on / UDS-adjacent visual program (not a numbered domain phase). Runs after [Register workspace consolidation](../register-workspace-consolidation/README.md) and alongside or after [Receipts and reports revamp](../receipts-and-reports-revamp/README.md). Does not reopen transaction, tender, stored-value, cash, session, keyboard, or reporting-period domain semantics.

This program **restyles** the live Register shell and active workspace to approach the approved HTML drafts under [`docs/drafts/register-surface-revamp/`](../../drafts/register-surface-revamp/), while freezing Scan/Turbo/Stimulus/keyboard contracts. It also completes **local packaging** of Noto Sans Mono and Plus Jakarta Sans per [ADR-022](../../adr/ADR-022-warm-parchment-visual-tokens.md).

| Document | Purpose |
|---|---|
| [plan.md](plan.md) | Goal, locked decisions, scope, slices S1–S4 |
| [visual-system.md](visual-system.md) | Screen chrome tokens, typography roles, draft mapping |
| [change-allowlist.md](change-allowlist.md) | Files and selectors in / out of scope |
| [implementation-plan.md](implementation-plan.md) | Slice status, merge policy, testing stack |
| [user-stories.md](user-stories.md) | GitHub-issue-ready slice stories |
| [test-matrix.md](test-matrix.md) | Frozen suites and manual layout gates |

## Visual references (inspirational, not domain authority)

| Draft | Maps to |
|---|---|
| [active_transaction.html](../../drafts/register-surface-revamp/active_transaction.html) | Active workspace (primary target) |
| [menu_overlay_corrected.html](../../drafts/register-surface-revamp/menu_overlay_corrected.html) | F10 Register Menu chrome |
| [dialog_overlay.html](../../drafts/register-surface-revamp/dialog_overlay.html) | Controlled-action / overlay panel chrome |
| [transactions_and_receipts.html](../../drafts/register-surface-revamp/transactions_and_receipts.html) | History filter/table skin (optional late slice) |
| [transaction_review.html](../../drafts/register-surface-revamp/transaction_review.html) | **Deferred** — completed / review screens |

## Prior art

- [UDS-3 — Register visual refinement](../ux-design-system/uds-3-plan.md) — basket hierarchy, shortcut groups, overlay separation (implemented)
- [register-workspace.md](../phase4-6-point-of-sale/phase5-cash-register/register-workspace.md) — Importmap + Turbo + Stimulus Register stack
- [slice7-keyboard-contract.md](../register-workspace-consolidation/slice7-keyboard-contract.md) — keyboard authority (frozen)

## Does not reopen

- Slice 7 keyboard semantics, shell F10 ownership, or `navigator.keyboard.lock`
- Tender / return / controlled-action domain services
- Thermal print content contracts (D1/D2) — only font packaging may touch print CSS/font loaders
- Admin / purchasing-ops face stacks (remain Source Sans 3 / Source Serif 4)
- Report/tape print (Inconsolata)

## Deferred (later packet)

- Transaction Complete / Transaction Review redesign (`transaction_review.html`)
- Structural Transactions & Receipts IA changes beyond filter/table skin
- Blurred workspace + `pointer-events: none` overlay patterns from drafts
- Moving Gift Card / Attach Customer into a new aux bar that changes ownership or enablement rules
- ESC/POS or raw printer drivers
- Full a11y matrix **conforming** cashier timed study (may remain open as for UDS-3)
