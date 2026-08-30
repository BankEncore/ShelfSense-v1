# Slice 7.0 — Keyboard contract amendment

Status: **Accepted as documentation** (implementation deferred to Slice 7C). Branch `93-slice7-keyboard-contract`. Parent: [slice7-overview.md](slice7-overview.md).

This document is the replacement keyboard **authority** for Register workspace consolidation. It satisfies [plan.md](plan.md) locked decision 13’s “first merge” requirement without remapping live keys.

**Runtime until 7C:** Phase 6.7 [pos-workflow.md](../phase4-6-point-of-sale/phase6-pos-mvp/pos-workflow.md) §6 remains live, as staged in [routing-and-authority.md](routing-and-authority.md) (Slice 3 F10; Slice 5D `+` → O11).

**Implementation:** One mode-aware dispatcher and deletion of obsolete handlers occur only in **7C**, after 7A/7B expose final semantic actions.

---

## Implementation deferral (normative)

| Allowed in 7.0 | Forbidden until 7C |
|---|---|
| Accept the tables and vocabulary in this document | Remap live SALE/TENDER keys to this contract |
| Update routing / overview / tracker docs | Add a central keyboard dispatcher |
| Refine tables in later docs-only PRs if 7A/7B discover gaps | Add temporary global shortcuts or document-level handlers in 7A/7B |
| | Delete obsolete Phase 6.7 handlers before the dispatcher lands |

7A/7B may emit **semantic events** and provide pointer / standard Tab / Enter controls that 7C will later bind to keys.

---

## SALE

Applies when the workspace is in commercial Sale entry (basket / command field; not Tender Review; no blocking overlay owns input).

| Key | Semantic action | Meaning |
|---|---|---|
| Printable scan / typed characters | `command-input` | Route into the sale command field when input protection allows |
| `Enter` | `submit-command` | Submit current command / resolve scan (context per overlay Enter table below when an overlay owns focus) |
| `*` | `set-quantity` | Quantity on selected quantity-tracked sale line |
| `/` | `open-product-lookup` | Merchandise search (empty command field only; identifier punctuation is not Search) |
| `.` | `open-pickup-lookup` | Pickup lookup (composition MVP; empty field pattern) |
| `-` | `open-return-chooser` | Return chooser (empty command field only) |
| `+` | `open-tender-selection` | Open O11 tender selection after tenderability checks (**preserves Slice 5D**; does not restore Cash-with-remaining as the `+` destination) |
| `F1` | `tender-cash` | Cash tender entry |
| `F2` | `tender-card` | Card tender entry |
| `F3` | `tender-check` | Check tender entry |
| `F4` | `tender-other` | Other tender (picker when multiple configured) |
| `F5` | `tender-stored-value` | Stored-value tender family |
| `F6` | `edit-price` | Price on selected sale line |
| `F7` | `edit-discount` | Line discount on selected sale line |
| `F8` | `remove-selected-record` | Remove selected commercial line (or selected working issuance when that is the selected record) |
| `F9` | `cancel-transaction` | Cancel confirmation; second confirm per existing cancel contract — **never** silent cancel |
| `F10` | `open-register-menu` | Register Menu (shell-owned) |
| `↑` / `↓` | `move-basket-selection` | Move selected basket line |
| `Esc` | (see Escape precedence) | Innermost reversible layer only |

**Omitted:** `+1`–`+9` tender category sequences.

Unavailable actions must expose a visible, focusable control that explains why (no silent no-op when the cashier has reason to expect the action).

---

## TENDER (Tender Review)

Applies when at least one working tender is applied and the workspace is in Tender Review (Slice 7A). Until 7A lands, this table is **accepted target authority** only.

| Key | Semantic action | Meaning |
|---|---|---|
| `+` | `open-tender-selection` | Add another tender (O11) |
| `-` | `remove-selected-tender` | Remove selected tender when supported; confirm when required |
| `↑` / `↓` | `move-tender-selection` | Change selected applied tender |
| `Enter` | `open-selected-tender-actions` | Open actions / editor for the selected tender (O15 when replace supported) |
| `Esc` | `return-to-sale` or leave child overlay | Per Escape precedence; may open O17 when tenders must clear |
| `F1`–`F5` | same tender-family actions as SALE | Add that tender family without requiring O11 when legal |
| `F8` | `remove-selected-tender` | Same as `-` when a tender is selected |
| `F9` | `cancel-transaction` | Same cancel contract as SALE |
| `F10` | `open-register-menu` | Register Menu |
| Printable / scan | `command-input` only when a tender amount/reference field owns focus under input protection | Do not treat scanned `+` / `-` as Add/Remove |

**Omitted:** `+1`–`+9`.

Stored-value Edit/Remove remain unavailable until 7B; selection and inspect are allowed in 7A.

---

## Overlay precedence

```text
Top blocking overlay
  → owns Escape, Enter, arrows, and printable input

Register Menu (F10)
  → owns F10 and its focus trap; not a competing Keyboard Lock owner

Workspace submode (Sale / Tender Review)
  → owns mode-specific commands when no overlay owns input

Sale command field
  → receives scanner/command input only when input protection allows
```

Blocking overlays do not create a competing `navigator.keyboard.lock` owner. Shell remains sole Lock owner.

---

## Escape precedence

1. Close the top child overlay (return to its parent overlay if any).
2. Leave the active workspace submode when that leave action is defined (Tender Review → Return to Sale contract, which may require O17).
3. Clear the current command field when it has content and no overlay/submode consumes Escape.
4. Otherwise do nothing.

**Escape must never** cancel the transaction or close the session without an explicit confirmation action (`cancel-transaction` / F9 path).

---

## Scanner punctuation and input protection

Do **not** redirect printable characters into workspace commands when focus is in:

- `text` / `password` / `search` / `tel` / `email` / `number` fields
- textareas
- selects
- contenteditable controls
- blocking overlays
- authorization fields
- tender / issuance entry controls

Intercept mode keys such as `/`, `*`, `-`, `+` only when the owning command field is **empty** (existing empty-field pattern). A hyphen or slash inside a typed or scanned identifier is not Return or Search.

Cover scanner strings containing `/`, `-`, `+`, `*`, leading zeroes, rapid input, and Enter terminator. A scanned `+` must not be mistaken for Tender; a typed `-` in an applicable field must not be Remove.

---

## Keyboard Lock ownership

| Surface | Lock request |
|---|---|
| Selling workspace (Sale / Tender Review) | F1–F10 |
| Non-workspace Register shell surfaces | F10 only |
| Blocking overlays | Do not call lock/unlock; inherit shell ownership |

- Acquisition failure must not break typed or scanned input.
- Unlock on navigation / visibility loss; re-acquire per existing shell rules (Slice 2 / 3).
- Postpone Ctrl / Cmd / Alt chords.

---

## Semantic action vocabulary

Controllers and (later) the dispatcher consume these actions. Keys are bindings; actions are the contract.

| Action | Typical producers |
|---|---|
| `command-input` | Scanner / printable routing |
| `submit-command` | Enter on command field |
| `open-product-lookup` | `/`, Product Search control |
| `open-pickup-lookup` | `.`, Pickup control |
| `open-return-chooser` | `-` (Sale), Return control |
| `open-tender-selection` | `+`, Tender control → O11 |
| `set-quantity` | `*` |
| `edit-price` | `F6` |
| `edit-discount` | `F7` |
| `tender-cash` / `tender-card` / `tender-check` / `tender-other` / `tender-stored-value` | `F1`–`F5` |
| `remove-selected-record` | `F8` (Sale) |
| `remove-selected-tender` | `-` / `F8` (Tender) |
| `move-basket-selection` | Arrows (Sale) |
| `move-tender-selection` | Arrows (Tender) |
| `open-selected-tender-actions` | Enter (Tender) |
| `return-to-sale` | Escape / Return to Sale control |
| `cancel-transaction` | `F9` |
| `open-register-menu` | `F10` |
| `complete-transaction` | Complete control when exactly settled (pointer / announced control; key binding if added later must be packet-amended) |

7A/7B may add narrowly scoped actions (for example `attach-customer`, `open-quick-customer`) in their packets; 7C folds them into the dispatcher.

---

## Phase 6.7 supersession map

| 6.7 / staged rule | Slice 7 contract |
|---|---|
| §6 full keyboard map (except already staged) | Superseded at **7C runtime** by this document |
| Slice 3: F10 → Register Menu | **Retained** |
| Slice 5D: empty-field `+` → O11 | **Retained** as `open-tender-selection` |
| Historical 6.7: `+` = Cash-with-remaining | Remains superseded by 5D; not restored |
| F1–F5 tender families | **Retained** meanings |
| F6 Price / F7 Discount / F8 Remove / F9 Cancel | **Retained**; F8 becomes explicitly mode-scoped (line vs tender) |
| `/` merchandise search, `*` quantity, `-` return (Sale) | **Retained** on SALE (speculative P12 remap rejected) |
| F8 removes last tender only (current UI) | Superseded in **7A** by selected-tender remove; key binding in **7C** |
| Document-scattered key handlers | Superseded by one dispatcher in **7C** |
| pos-workflow.md §6 as live authority | Remains live until **7C** updates it to point here |

---

## Relationship to overlays O11–O17

Wireframe destinations remain composition authority for frames:

- O11 Tender selection — opened by `open-tender-selection`
- O12–O14 amount / reference / SV entry — opened from tender-family actions
- O15 Replace — 7A ordinary / 7B stored-value
- O16 Remove confirmation — when required
- O17 Return to Sale with tenders — `return-to-sale` when tenders must clear

Overlay lifecycle remains [slice5a-lookup-overlays-plan.md](slice5a-lookup-overlays-plan.md).
