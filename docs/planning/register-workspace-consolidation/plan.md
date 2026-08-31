# Register workspace consolidation — Plan

Status: **Accepted** (Slice 1). Slice 2 implementation on `register-workspace-consolidation`.

Companions: [routing-and-authority.md](routing-and-authority.md), [implementation-plan.md](implementation-plan.md), [pos-workflow.md](../phase4-6-point-of-sale/phase6-pos-mvp/pos-workflow.md) (6.7 remains lock until the owning slice supersedes it).

## Goal

Cashiers enter Register and land on the surface that matches operational state: closed, between sessions, own session (transaction workspace), or occupied. A shared shell keeps Store, Register, business date, cashier, and custody visible. Frequent ticket work stays on the workspace; less frequent customer-service, till, and session work moves under F10 after Slice 3.

This is presentation replacement. It must not introduce a second transaction, cash, stored-value, or reporting model.

## Non-goals

- Parallel old/new POS Home
- Markup or Stimulus adapters for deleted presentation
- Safe reconciliation, deposit preparation, or configuration in Register
- Merging gift-card issuances into merchandise lines
- Silent remap of 6.7 keys before Slice 7C
- Prefix + last-four gift-card find as possession or as input to redeem, reload, cash-out, or completion

## Locked decisions

1. Four user-facing states; a leftover prior-date reporting period is a qualifier, not a fifth state.
2. GET `/pos` may resolve and render; it must not open a period, session, transfer cash, or create a working transaction.
3. Preferred Register (cookie), bound `session[:pos_register_id]`, and owned session custody are distinct. Preference changes never close or transfer custody.
4. Multiple owned sessions with no valid binding → selector listing every owned session. Never present that cashier as having no session (Slice 2; current Home does the opposite — see [test-matrix.md](test-matrix.md)).
5. `Pos::RegisterStateResolver` is pure: the controller passes store, actor, registers, and owned sessions explicitly. Helpers own labels.
6. Expected cash is hidden unless `cash.view_expected_before_count`. No session-owner exception. Home’s always-on expected cash is a defect to remove in Slice 2.
7. Stored-value inquiry (Slice 6A) is three labeled paths: exact-number possession, customer store credit, permission-controlled masked prefix/last-four history.
8. Slice 2 keeps a **temporary, state- and permission-filtered destination cluster**. Slice 3 deletes it when F10 exists.
9. Delete replaced presentation in the same slice. Replace obsolete tests in the same PR. Never weaken financial, custody, stored-value, cash, auth, concurrency, receipt, or cross-store tests.
10. Keyboard and overlay interaction tests are **system tests**. Do not add a JavaScript unit runner for this program.
11. Wrap the **existing** workspace in the shell in Slice 2. Slice 4 only splits `_surface`.
12. **Slice 2 shell-containment interaction (authorized):** Once the Register shell is a fixed workstation viewport, Slice 2 may also change selling-chrome composition and scan input routing as required for containment—not as silent scope into Slice 4/7:
    - Place feedback and the command area above the basket; give the basket an internal scroll region.
    - Keep the selected basket line scrolled into view on add/rescan and ArrowUp/ArrowDown.
    - Redirect printable scan/typed input into the command field when no overlay/dialog field owns the keystroke.
    - Reacquire Keyboard Lock from shell-wide pointer/focus (header, status, cluster, workspace), and tolerate `navigator.keyboard.lock` absence or rejection.
    - This does **not** authorize key remapping, new F-key bindings, or overlay family migration (Slices 3–5 / 7C).
13. Slice 7 does not start until slices 2–6 are on the integration branch and green. Slice 7’s first merge is a packet amendment (SALE / TENDER / overlay tables), then 7A → 7B → 7C. Clarified in [slice7-overview.md](slice7-overview.md): “first merge” accepts the keyboard **contract** ([slice7-keyboard-contract.md](slice7-keyboard-contract.md)); dispatcher **implementation** is 7C only.

## States

| Internal condition | `kind` | Primary surface |
|---|---|---|
| No usable Register selected | `selector` | Register selector |
| No open reporting period | `closed` | Open Register |
| Open period, no session | `between_sessions` | Open Session / Z |
| Open session owned by current user | `own_session` | Existing workspace in shell |
| Open session owned by another user | `occupied` | Occupied Register |

## Slices

| Slice | Lands | Work |
|---|---|---|
| 1 | `main` | This packet, test matrix, gap characterization, tracker |
| 2 | integration | Shell, resolver, `/pos` state routing, delete generic Home, destination cluster |
| 3 | integration | F10 Register Menu; delete cluster and duplicate nav |
| 4 | integration | Transaction composition MVP; 6.7 keys except F10 |
| 5A–5D | integration | Overlay families: lookup → returns → controlled actions → tender/issuance |
| 6A–6C | integration | Inquiry/detail presenters |
| 7A–7C | integration | Tender framework, stored-value correction, keyboard supersession (gated) |

## UX adoption targets

- **Screens created or materially changed:** Slice 2 (`/pos` state entry, Register shell partials, wrapped workspace, selector/closed/between/occupied bodies, destination cluster). Later slices: F10 destinations and workspace composition.
- **Current migration-matrix state:** Register workspace remains verified-automated for basket/overlays; POS Home markup deleted; entry is state-aware shell.
- **Accepted primitives:** Warm Parchment, `ActionButtonHelper`, Register layout contracts.
- **Applicable automated evidence:** `test/services/pos/register_state_resolver_test.rb`, retargeted `pos_home` / enter request tests, existing `test/system/pos_*`.
- **Matrix rows:** `pos/homes/**` replaced; `pos/workspaces/**` shell wrap; `layouts/pos.html.erb` shared shell chrome.

## Deliverable

> Authorized cashiers enter Register and immediately work from the correct operational state, with consistent custody context, without a generic POS Home, and without a second financial model.
