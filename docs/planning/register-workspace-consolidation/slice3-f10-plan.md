# Slice 3 — F10 Register Menu

Status: **Implementation-ready.** Slice 2 is on `register-workspace-consolidation` ([#83](https://github.com/BankEncore/ShelfSense-v1/issues/83) / PR #96).

Authority: [plan.md](plan.md), [routing-and-authority.md](routing-and-authority.md), [textual-wireframes.md](textual-wireframes.md) §O1, [user-stories.md](user-stories.md), Phase 6.7 until this slice merges.

Issue: [#84](https://github.com/BankEncore/ShelfSense-v1/issues/84). Branch: `84-f10-and-navigation`. PR target: `register-workspace-consolidation`.

## Outcome

F10 opens the **Register Menu** on every Register shell surface. The Slice 2 temporary destination cluster is deleted. Transactions remains reachable from the menu; a working basket is never discarded by F10.

## Packet amendment (supersession)

When Slice 3 merges, it **explicitly supersedes**:

| Source | What changes |
|---|---|
| Phase 6.7 §6 F10 row | F10 opens Register Menu (not Transactions) |
| Phase 6.7 §14 F10 history entry | Visible/F10 entry to Transactions moves under Register Menu → **Transactions & Receipts**; history behavior itself is unchanged |
| Slice 2 destination cluster | Deleted; menu is the sole Register navigation surface for those destinations |

**Does not supersede:** transaction-history search/behavior, linked-return workflow, working-basket preservation, other 6.7 keys (`F1`–`F9`, `/`, `-`, `.`, `*`, `+`, Enter, Escape), overlay families, Slice 7 remap.

Keyboard Lock key *set* is owned by the Register shell and is **surface-derived** (below), not a copy of the former workspace F1–F10 lock on every Register page.

Update [routing-and-authority.md](routing-and-authority.md) and [pos-workflow.md](../phase4-6-point-of-sale/phase6-pos-mvp/pos-workflow.md) F10 rows in the **same** Slice 3 PR.

## Locked interaction contract

### F10 order

1. If the Register Menu is already open → close it and restore invoking focus.
2. Else if another **blocking** overlay is open → keep that layer; announce finish or leave. The Register Menu is never a blocking overlay.
3. Else sync live proxies, save `document.activeElement`, inert the shell background, show the menu, set `aria-expanded`, focus the first menu item.

Blocking overlays are tagged `data-register-blocking-overlay`. Do not query generic `.pos-overlay`.

### Inert boundary

Every Register shell composition uses one background wrapper. The menu overlay (and the F10-blocked live region) are **siblings** of that wrapper, never descendants.

```text
.pos-register-shell
├── .pos-register-shell__background
│   ├── header
│   ├── status
│   ├── feedback where applicable
│   └── primary content (state body, workspace, or Switch Register)
├── Register Menu overlay
└── live region (F10-blocked announcements)
```

Open: `background.inert = true`. Close: `inert = false`.

### Keyboard Lock

The Register shell is the **sole** owner of `navigator.keyboard.lock` / `unlock`. The workspace controller must not call them.

Lock set derives from the **rendered surface**, not `@state.kind`:

- `#pos_workspace` present / `surface: :workspace` → F1–F10
- every other Register surface → F10 only

Graceful no-op when `navigator.keyboard` is absent, `lock` is absent, or `lock()` rejects. Unlock on disconnect and when the document is hidden; re-request on visible / pointer / focus / keydown. Ordinary keydown handling continues without Lock.

### Workspace F10

Workspace `onKeydown` returns on F10 **before** overlay dispatch and does not claim F10. Shell prevents default and owns the key. Delete `openTransactions` and `transactionsUrl`.

### Focus restore

On open, save `document.activeElement`. On close, focus it if still connected and not inert; otherwise the visible **F10 Menu** launcher. Navigation away lets the destination own focus.

| Invocation | Close returns to |
|---|---|
| Click visible F10 Menu | F10 Menu button |
| F10 from scan / quantity / tender field | That field |
| Invoking element removed | F10 Menu fallback |
| Navigation selected | Destination owns focus |

### Close Session and in-page mutations

`Pos::RegisterMenu` may emit `:close_session` for `surface: :workspace`. It does **not** inspect basket state.

The live proxy owns Close Session **visibility**. Re-evaluate when the menu **opens**. Authoritative control stays in `#pos_workspace` (`data-register-shell-proxy="close-session"`). Activating the menu item closes the menu and invokes that control. No second POST.

The same proxy pattern applies to in-page Open Register, Open Session, and Finalize Z.

If `#pos_workspace` can be replaced while the menu is open, **close the menu on `turbo:before-render`** (or the workspace-frame render event). Restore invoking focus if still connected. Recompute proxy availability on the **next** opening. Do not mutate an open menu while its invoking target may disappear.

### Surfaces

```ruby
Pos::RegisterMenu.call(kind:, surface:, permissions:, gate:)
# surface: :state_landing | :workspace | :switch_register
```

The PORO returns grouped **capability keys** only. The helper/view owns labels, routes, ARIA, and proxy declarations.

`surface: :switch_register` suppresses Switch Register, Till, X Report, Close Session, and all in-page Open/Finalize actions. Switch Register retains Transactions & Receipts, eligible Session/Z Reports, permissioned Active Sessions, and Return to ShelfSense.

### ARIA

Launcher: `type="button"`, `aria-haspopup="dialog"`, `aria-controls="register-menu"`, `aria-expanded` toggled.

Menu: `id="register-menu"`, `role="dialog"`, `aria-modal="true"`, `aria-labelledby`, Close, focus trap, Escape, group headings, scrollable body. No focusable hidden or unauthorized items.

F10-blocked announcements use a shell live region **outside** the inert background (or the already-open overlay’s status).

### Tests

- All six shell compositions (selector, closed, between sessions, own session, occupied, Switch Register) receive compact F10 lifecycle coverage: launcher present, F10 opens, Escape closes, first item focused, invoking focus restored, background inert.
- High-zoom reachability is tested **once** against the shared menu implementation.
- Overlay suppression, quantity/tender F10, and basket preservation stay on the workspace suite.

## Eligibility (Slice 3 destinations)

Destinations that already exist (Slice 2 cluster + enter/close entry points). Do **not** invent Slice 6 inquiry/detail presenters.

| Group | Item | Closed | Between | Own session | Occupied | Notes |
|---|---|---|---|---|---|---|
| Customer service | Transactions & Receipts | Yes | Yes | Yes | Yes | Existing `pos_transactions_path` |
| Customer service | Stored Value Inquiry | No* | No* | No* | No* | *Defer until 6A |
| Customer service | Customer Summary / Pickup Queue | No* | No* | No* | No* | *Defer until 6A |
| Till | Paid-in / Paid-out / Drop / Replenish / Gift-card cash-out | No | No | Permission-filtered | No | Existing cash routes |
| Till | Till Activity | No* | No* | No* | No* | *Defer until 6B |
| Session & Register | X Report | No | No | Own X | `pos.sessions.view` | Same rules as Slice 2 cluster |
| Session & Register | Session / Z Reports | Yes | Yes | Yes | `pos.sessions.view` | Existing reports index |
| Session & Register | Active Sessions | Permission | Permission | Permission | Permission | Existing |
| Session & Register | Switch Register | Yes | Yes | Yes | Yes | Omit on `surface: :switch_register` |
| Session & Register | Open Register / Open Session / Finalize Z / Close Session | Live proxy | Live proxy | Close Session proxy | Assisted close deferred | Authoritative forms stay on the page |
| Session & Register | Return to ShelfSense | Yes | Yes | Yes | Yes | Same-tab; custody confirm |

**MVP rule:** Ship the menu shell + every destination that already has a route. Wireframe items without routes appear only after their owning slice.

Reverse Cash is **not** listed; reverse route/service remain until Slice 6B.

`_report_nav` and history `_chrome` stay as return-to-Register on supporting pages until 6A/6C wrap those surfaces.

## Ownership

| Component | Owns |
|---|---|
| Register shell controller | F10, Keyboard Lock, menu lifecycle, focus, inert state, live-proxy resolution, close-on-Turbo-before-render |
| Workspace controller | F1–F9 and transaction interactions; explicitly ignores F10 |
| `Pos::RegisterMenu` | Stable capability keys by state, surface, and permission |
| Menu helper/view | Labels, URLs, groups, ARIA markup, proxy declarations |
| Existing workspace/state forms | Authoritative mutation controls and eligibility |
| System tests | Browser-level keyboard, focus, inertness, Turbo, and basket preservation |

## Non-goals

- Redesigning transaction history, receipt detail, or post-void
- Building Stored Value Inquiry / Customer Summary / Pickup Queue / Till Activity presenters (6A–6B)
- Assisted Close for occupied Registers
- Changing any 6.7 key other than F10’s destination
- JavaScript unit test framework
- Wrapping history / cash / reports in the Register shell

## Exit criteria

- [ ] F10 Register Menu on every Register shell composition
- [ ] Destination cluster gone
- [ ] 6.7 §6 F10 and §14 F10 entry superseded in docs + tests
- [ ] Working basket preserved across Transactions round-trip
- [ ] Blocking overlay suppresses F10 (menu-open check first)
- [ ] Reverse Cash nav absent; service remains
- [ ] CI green on the integration-branch PR
