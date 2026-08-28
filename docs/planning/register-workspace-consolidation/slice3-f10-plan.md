# Slice 3 — F10 Register Menu (planning)

Status: **Planning draft.** Implementation starts only after Slice 2 ([#83](https://github.com/BankEncore/ShelfSense-v1/issues/83) / PR #96) is on `register-workspace-consolidation`.

Authority: [plan.md](plan.md), [routing-and-authority.md](routing-and-authority.md), [textual-wireframes.md](textual-wireframes.md) §O1, [user-stories.md](user-stories.md), Phase 6.7 until this slice merges.

Issue: [#84](https://github.com/BankEncore/ShelfSense-v1/issues/84). Branch: `84-f10-and-navigation`. PR target: `register-workspace-consolidation`.

## Outcome

F10 opens the **Register Menu** on every Register shell state. The Slice 2 temporary destination cluster and duplicate Register navigation are deleted. Transactions remains reachable from the menu; a working basket is never discarded by F10.

## Packet amendment (supersession)

When Slice 3 merges, it **explicitly supersedes**:

| Source | What changes |
|---|---|
| Phase 6.7 §6 F10 row | F10 opens Register Menu (not Transactions) |
| Phase 6.7 §14 F10 history entry | Visible/F10 entry to Transactions moves under Register Menu → **Transactions & Receipts**; history behavior itself is unchanged |
| Slice 2 destination cluster | Deleted; menu is the sole Register navigation surface for those destinations |

**Does not supersede:** transaction-history search/behavior, linked-return workflow, working-basket preservation, other 6.7 keys (`F1`–`F9`, `/`, `-`, `.`, `*`, `+`, Enter, Escape), Keyboard Lock key set (already F1–F10), overlay families, Slice 7 remap.

Update [routing-and-authority.md](routing-and-authority.md) staged-supersession table and [pos-workflow.md](../phase4-6-point-of-sale/phase6-pos-mvp/pos-workflow.md) F10 rows in the **same** Slice 3 PR.

## Menu contract

Wireframe: [textual-wireframes.md](textual-wireframes.md) §O1.

### Behavior

1. F10 toggles/opens Register Menu from every shell state that has Register chrome (selector, closed, between sessions, own session, occupied, Switch Register when wrapped).
2. Focus moves into the menu; Escape / Close returns focus to the launcher (command field, primary state action, or prior focus).
3. While a **blocking** overlay or approval dialog is open, F10 does **not** open the menu (finish or leave the layer first).
4. F10 never cancels, suspends, clears, or completes the working transaction.
5. Keyboard Lock remains requested for F1–F10 on Register surfaces (extend to non-workspace states if not already covered after Slice 2).
6. Reverse Cash is **not** listed; reverse route/service remain until Slice 6B.
7. Same-tab **Return to ShelfSense** with custody confirmation when a session is owned (align with Slice 2 header).

### Eligibility (initial Slice 3 surface)

Destinations that already exist today (Slice 2 cluster + enter/close entry points). Labels may match wireframes where the route already exists; do **not** invent Slice 6 inquiry/detail presenters.

| Group | Item | Closed | Between | Own session | Occupied | Notes |
|---|---|---|---|---|---|---|
| Customer service | Transactions & Receipts | Yes | Yes | Yes | Yes | Existing `pos_transactions_path` |
| Customer service | Stored Value Inquiry | No* | No* | No* | No* | *Defer UI until 6A; omit from menu until route exists |
| Customer service | Customer Summary / Pickup Queue | No* | No* | No* | No* | *Defer until 6A |
| Till | Paid-in / Paid-out / Drop / Replenish / Gift-card cash-out | No | No | Permission-filtered | No | Existing cash routes |
| Till | Till Activity | No* | No* | No* | No* | *Defer until 6B |
| Session & Register | X Report | No | No | Own X | `pos.sessions.view` | Same rules as Slice 2 cluster |
| Session & Register | Session / Z Reports | Yes | Yes | Yes | `pos.sessions.view` | Existing reports index |
| Session & Register | Active Sessions | Permission | Permission | Permission | Permission | Existing |
| Session & Register | Switch Register | Yes | Yes | Yes | Yes | Existing |
| Session & Register | Open Register / Open Session / Finalize Z / Close Session | State body actions | State body actions | Close Session | Assisted close deferred | Prefer deep-link to existing enter/close surfaces; do not duplicate mutating POST in the menu |
| Session & Register | Return to ShelfSense | Yes | Yes | Yes | Yes | Same-tab; custody confirm |

**MVP rule for Slice 3:** Ship the menu shell + every destination that already has a route in Slice 2. Wireframe items without routes appear only after their owning slice (6A–6C), not as dead buttons.

## Implementation breakdown (issue #84)

Suggested PR shape: **one PR** for Slice 3 unless review wants menu chrome first.

| Task | Work | Tests |
|---|---|---|
| 3.1 Menu presenter / helper | Pure eligibility from `kind`, permissions, gate; presentation-neutral item list | Unit/helper |
| 3.2 Menu markup + Stimulus | Overlay/dialog pattern consistent with workspace overlays; focus trap; Escape; inert selling chrome when open from workspace | System |
| 3.3 F10 binding | Capture F10 on all Register shell states; suppress when blocking overlay open; restore focus | System |
| 3.4 Delete cluster | Remove `pos/shell/_cluster`, cluster helper matrix, Home-era leftover nav, workspace duplicate Transactions/X/Switch chrome if any remain | Request + system retarget |
| 3.5 Delete duplicate nav | `_report_nav` / `_chrome` / remaining POS Home links that the menu replaces | Request |
| 3.6 Docs supersession | routing-and-authority, pos-workflow §6/§14, user-stories checkboxes, test-matrix rows, migration-matrix | Doc + CI links |
| 3.7 Manual evidence | High zoom menu, screen reader menu, overlay-open F10 suppression, basket preservation after Transactions round-trip | Checklist |

### Retarget tests (from test-matrix)

- System: F10 → menu (not history); Transactions via menu preserves basket (existing basket-preservation coverage retargeted).
- Request: menu contents by state/permission; Reverse Cash absent; X Report rules unchanged.
- Remove assertions that click destination-cluster links as the primary nav path.

## Non-goals

- Redesigning transaction history, receipt detail, or post-void
- Building Stored Value Inquiry / Customer Summary / Pickup Queue / Till Activity presenters (6A–6B)
- Assisted Close for occupied Registers (later)
- Changing any 6.7 key other than F10’s destination
- JavaScript unit test framework

## Exit criteria

- [ ] F10 Register Menu on every Register shell state
- [ ] Destination cluster gone; no duplicate Register nav
- [ ] 6.7 §6 F10 and §14 F10 entry superseded in docs + tests
- [ ] Working basket preserved across Transactions round-trip
- [ ] Blocking overlay suppresses F10
- [ ] Reverse Cash nav absent; service remains
- [ ] CI green on integration branch

## Sequencing note

Do not start `84-f10-and-navigation` implementation commits until PR #96 is merged to `register-workspace-consolidation`. This planning file may land ahead of that merge.
