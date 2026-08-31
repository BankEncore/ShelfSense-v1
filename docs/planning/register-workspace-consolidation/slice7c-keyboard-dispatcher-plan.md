# Slice 7C — Keyboard dispatcher and Phase 6.7 supersession

Status: **Accepted packet** (docs lock). Implementation under [#95](https://github.com/BankEncore/ShelfSense-v1/issues/95). Parent: [slice7-overview.md](slice7-overview.md). Authority: [slice7-keyboard-contract.md](slice7-keyboard-contract.md), [plan.md](plan.md), [routing-and-authority.md](routing-and-authority.md), [implementation-plan.md](implementation-plan.md), [user-stories.md](user-stories.md). Evidence template: [slice7c-manual-verification.md](slice7c-manual-verification.md).

Issue: [#95](https://github.com/BankEncore/ShelfSense-v1/issues/95). Packet-lock branch: `95-slice7c-keyboard-dispatcher-plan` (docs only; does not complete implementation of #95).

7B remediation ([#123](https://github.com/BankEncore/ShelfSense-v1/pull/123) — issuance Edit/replace, Quick Customer duplicate-ack) is already on `register-workspace-consolidation` and is **not** a 7C blocker.

## Outcome

Replace accumulated workspace keyboard conditionals with one mode-aware dispatcher that:

- implements the accepted SALE and TENDER tables without reopening the key map;
- protects typed and scanned input (focus-based punctuation; delete empty-field interception);
- delegates blocking-overlay keys to the top overlay (do not rewrite overlay list navigation);
- preserves shell ownership of F10 and Keyboard Lock;
- dispatches **semantic actions** rather than encoding workflows in the keyboard layer;
- removes obsolete Phase 6.7 interception and last-tender F8 behavior;
- updates visible shortcut labels/help and documentation to match runtime truth.

**Discipline:** centralize key→action routing, not business behavior. No financial, tender, stored-value, issuance, customer, or authorization rules move into the keyboard layer.

## Boundary statement

> Slice 7C implements the accepted Slice 7.0 keyboard contract at runtime via one mode-aware dispatcher, replaces empty-field punctuation interception with the focus-based rule, binds Tender Review remove keys to the selected tender, deletes obsolete Phase 6.7 handlers, and documents supersession of remaining pos-workflow §6 authority. Shell remains sole Keyboard Lock and F10 owner. Workspace continues to claim F1–F9 via `preventDefault` (Lock ≠ event claiming). No Customer Lookup key; F2 remains Card. No command-field-focused punctuation shortcuts without amending the 7.0 contract.

## Scope

| In | Out |
|---|---|
| One dispatcher: normalize → classify → resolve → execute | Reopening SALE/TENDER key map |
| Focus-based punctuation; delete empty-field interception | Command-field punctuation shortcuts (needs 7.0 amendment) |
| Tender F8/`-` → selected tender remove; delete `removeLastTender` | Customer Lookup / Quick Customer / Tax Class hotkeys |
| Repeat-key ignore for mutation / overlay-open actions | `+1`–`+9` sequences |
| Unavailable-action announce from existing control reasons | Speculative P12 `/`/`-` remap |
| Overlay owns first; delegate to existing overlay handlers | Rewriting overlay list navigation |
| Shell Lock + F10 ownership retained | Moving F1–F9 Lock ownership to workspace |
| Workspace F1–F9 `preventDefault` claiming retained | Runtime feature flags / compatibility adapters |
| System tests + manual verification; docs supersession | Second JS test framework; domain/service rule changes |

## Locked decisions

| Decision | Choice |
|---|---|
| Delivery | **Three merges** under [#95](https://github.com/BankEncore/ShelfSense-v1/issues/95): packet → 7C.1 foundation → 7C.2 cutover |
| Authority | Implement [slice7-keyboard-contract.md](slice7-keyboard-contract.md) exactly; do not implement from the superseded Slice 7 draft |
| Architecture | Context classifier → binding resolver → semantic action executor |
| Module layout | Importmap-pinned helpers under `app/javascript/`; executor on `register_workspace_controller.js` |
| Event bus | No CustomEvent bus; no second window keydown owner besides shell F10 |
| F-key claiming | Workspace claims F1–F9; shell owns Lock + F10 only |
| Focus zones | `overlay` \| `command_input` \| `other_editable` \| `workspace_control` \| `basket_row` \| `tender_row` \| `workspace_background` \| `shell_chrome` |
| Punctuation shortcuts | Only from `basket_row` \| `tender_row` \| `workspace_background` (or explicit visible controls) |
| `shell_chrome` | Printables redirect as literal command input (Slice 2); never mode shortcuts |
| Repeat keys | Allow for arrows and text; ignore `event.repeat` for mutation / overlay-opening actions |
| Unavailable actions | Do not invoke; do not silent no-op; announce existing reason via workspace feedback live region |
| Overlay | Top overlay owns event; delegate to existing handlers; do not rewrite overlay nav in 7C |
| 7C.1 | Foundation only — **preserve current runtime bindings** (no user-facing remap) |
| 7C.2 | Atomic `onKeydown` cutover to 7.0 tables; delete obsolete handlers/tests in the same PR |
| Tests | Rails system tests only |

### PR split

| Branch / PR | Scope |
|---|---|
| `95-slice7c-keyboard-dispatcher-plan` | This packet + verification template + tracker pointers (docs only) |
| `95-slice7c1-semantic-foundation` | Classifier, key normalization, semantic action executor; route visible controls through shared executors; **preserve current key bindings** |
| `95-slice7c2-dispatcher-cutover` | Atomic cutover; delete empty-field / `removeLastTender` / obsolete tests; labels/help; pos-workflow + routing supersession; fill verification; close #95 |

Each branches from the updated integration branch after its predecessor merges. PR target: `register-workspace-consolidation` (not `main`).

---

## Architecture

```text
Keyboard event
  → Key normalization
  → Context classifier (facts only)
  → Binding resolver (context + key → semantic action | literal | none)
  → Action executor (existing controller methods)
```

### Key normalization

| Physical input | Normalized |
|---|---|
| Main or numpad `+` / `-` | `+` / `-` |
| Numpad multiply / divide / decimal | `*` / `/` / `.` |
| F-key via `key` or `code` | `F1`–`F10` |

Ignore Ctrl/Cmd/Alt chords. Allow Shift where needed for `+`/`*`. Ignore IME composition (`event.isComposing`). No scanner timing heuristics. No `+1`–`+9`.

### Context classifier

Produces facts; does not perform an action.

- **mode:** `sale` | `tender` | `completion_pending` | `completion_failed`
- **focusZone:** as locked above
- **state:** selected line / issuance / tender; in flight; top overlay; composing; `event.repeat`

### Binding resolver

Must not call Rails endpoints, inspect permissions, calculate settlement, or mutate controller state.

### Action executor

| Semantic action | Existing behavior |
|---|---|
| `open-product-lookup` | `openSearchOverlay` |
| `open-pickup-lookup` | `openPickupOverlay` |
| `open-return-chooser` | `openReturnChooser` |
| `open-customer-lookup` | `openCustomerOverlay` (no key) |
| `open-quick-customer` | `openQuickCustomerOverlay` (no key) |
| `open-tender-selection` | `enterTender` / O11 |
| `set-quantity` | `enterQuantity` |
| `tender-cash` … `tender-stored-value` | `chooseCash` … `chooseStoredValue` |
| `edit-price` / `edit-discount` | `openPriceOverride` / `openLineDiscount` |
| `remove-selected-record` | selected sale/issuance removal |
| `remove-selected-tender` | selected tender remove path (**not** last) |
| `open-selected-tender-actions` | tender review/detail (+ reason when edit unavailable) |
| `return-to-sale` | existing O17 path |
| `cancel-transaction` | F9 confirmation |
| `submit-command` | mode submission |
| `open-register-menu` | shell-owned F10 |
| `move-basket-selection` / `move-tender-selection` | existing arrow movers |

Visible controls and keyboard bindings converge on these executors where practical. Eligibility stays in existing control/enablement logic.

---

## Event precedence

1. Shell handles F10 / open Register Menu
2. Open Register Menu owns its keys
3. Top blocking overlay owns Tab, Escape, Enter, arrows, and input
4. Composition and protected editables retain literal input
5. In-flight / completion modes suppress illegal workspace actions
6. Focused native controls retain Enter and Space activation
7. SALE or TENDER binding resolves
8. Unbound printable input redirects to the command field (literal)
9. Otherwise do nothing

Workspace returns immediately for F10. Blocking overlay open → menu does not open (existing shell announcement).

---

## Input protection

Replace narrow `isCommandSurfaceInput` with a general editable classifier covering: text/search/tel/email/password/number (and similar); textarea; select; contenteditable; command, reference, stored-value, authorization, issuance, and Quick Customer fields; any field inside the active blocking overlay.

Printable characters including `/` `.` `-` `+` `*` remain literal there. **Delete** empty-field exception and `reservedCommandGlyph` shortcut gating.

Punctuation **shortcuts** only from eligible non-input workspace focus zones (or explicit visible controls).

---

## Repeat-key policy

(Packet amendment; 7.0 contract is silent.)

- Permit `event.repeat` for arrows and ordinary text input.
- Ignore `event.repeat` for mutation and overlay-opening actions: remove, cancel, return-to-sale, tender selection, price/discount, tender-family actions.

---

## Unavailable-action behavior

When an expected bound action is unavailable per live control state:

- do not invoke;
- do not silent no-op;
- announce a concise **existing** reason via the workspace feedback live region;
- keep focus/selection stable.

Prefer presenter/service-provided reasons already used by controls.

---

## SALE / TENDER at cutover (7C.2)

Implement accepted tables as written. Notable deltas from Phase 6.7 runtime:

- Tender F8 / `-` → `remove-selected-tender` for **selected** tender; delete `removeLastTender`
- SALE F8 → `remove-selected-record` (line or selected issuance)
- Enter on selected tender → `open-selected-tender-actions` (expose detail + reason when edit unavailable)
- F2 remains Card; Customer Lookup / Quick Customer / Tax Class stay visible controls with **no** new shortcuts
- Add concise help so labels like `Tender (+)` / `Return (-)` are not read as applying from the focused command field

---

## Code disposition

**Revise:** `register_workspace_controller.js`; workspace partials (shortcut labels/help); `register_shell_controller.js` only if a tiny integration hook is required.

**Delete at cutover:** empty-command punctuation interception; `reservedCommandGlyph` shortcut use; `removeLastTender` keyboard routing; superseded tests; any temporary 7A/7B keyboard bridge found during inventory.

**Preserve:** overlay stack/lifecycle; F10 shell controller; Lock acquisition/release; services/endpoints; Turbo whole-workspace replacement; visible non-keyboard controls; workspace F1–F9 event claiming.

---

## Tests

Rails system tests only (no Jest).

- **Binding matrix:** SALE F1–F9; TENDER F1–F5, F8, F9; arrows; selected-line vs selected-tender removal; Enter on command / native control / tender row / overlay; Escape precedence; F10 regression.
- **Input/scanner matrix:** literal preservation across command, reference, SV, issuance, Quick Customer, authorization, lookup, controlled-action fields. Representative scans with reserved glyphs + Enter must not open mode overlays.
- **Focus zones for `+`:** command field / tender fields → literal; selected basket/tender row → O11; shell header → redirected literal; overlay → overlay-owned.
- **Safety:** repeated F8 removes one; Escape never cancels; F9 opens confirmation; Turbo does not double-bind; Lock failure does not break typed/scanned entry.
- **Accessibility:** pointer equivalents; focus visible; `aria-selected`; unavailable reasons announced; overlay focus trap intact.

---

## Documentation closeout (7C.2)

- Mark [slice7-keyboard-contract.md](slice7-keyboard-contract.md) implemented at runtime
- Supersede Phase 6.7 §6; point [pos-workflow.md](../phase4-6-point-of-sale/phase6-pos-mvp/pos-workflow.md) at the Slice 7 contract
- Update routing-and-authority, implementation-plan, user-stories, test-matrix, overview, README
- Document rejected `+1`–`+9` and contextual punctuation rule
- Fill and sign [slice7c-manual-verification.md](slice7c-manual-verification.md)
- Close #95 only after cutover is on the integration branch

## Explicit non-goals

Command-field punctuation shortcuts; Customer Lookup key; `+1`–`+9`; speculative P12 remap; runtime flags; domain/service rule changes; full overlay keyboard rewrite; stripping workspace F1–F9 claiming.

## Tracker updates (this packet)

- [implementation-plan.md](implementation-plan.md) — 7C packet accepted; implementation next
- [slice7-overview.md](slice7-overview.md) — point at this packet
- [user-stories.md](user-stories.md) — 7C acceptance checklist
- [README.md](README.md) — index this packet + verification template
