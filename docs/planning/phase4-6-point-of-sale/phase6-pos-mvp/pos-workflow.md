# Phase 6 Slice 6.7 — POS operator workflow

**Status:** Implemented. Implementation authority for cashier interaction: POS Home, preferred Register, X Report, keyboard contract, merchandise pickers, `/` search, open-price Standard, return entry, and tender selection.

**Authority:** How the cashier operates MVP capabilities that 6.1–6.6 already made commercially true. Completion, inventory posting, settlement math, controlled-action *policy*, linked/unlinked return *engines*, and post-void *facts* remain those contracts. Receipt *print layout* is 6.8 ([receipt-presentation.md](receipt-presentation.md) / [mvp-closeout.md](mvp-closeout.md)).

Companions: [phase6-plan.md](phase6-plan.md), [register-workspace.md](../phase5-cash-register/register-workspace.md), [merchandise-breadth.md](merchandise-breadth.md), [tender-breadth.md](tender-breadth.md), [controlled-actions.md](controlled-actions.md), [returns.md](returns.md), [transaction-history.md](transaction-history.md), [post-void.md](post-void.md).

Draft POS specifications are vocabulary. This document is implementation authority for the MVP subset. No new ADR.

**6.7 supersedes** Phase 5 / 6.2 / 6.4 **keyboard bindings and entry chrome** in [register-workspace.md](../phase5-cash-register/register-workspace.md) §7, [tender-breadth.md](tender-breadth.md) §7 (F2 cycling), [controlled-actions.md](controlled-actions.md) §18 (F5/F6/F7), [merchandise-breadth.md](merchandise-breadth.md) (POS still rejects `open_price` until this slice), and [returns.md](returns.md) (Unlinked button-only; keyboard map deferred). Domain engines in those documents stay authoritative.

### Actually locked

```text
6.7 = operator workflow; 6.8 = presentation/closeout
GET /pos = POS_HOME (no selling scan field)
GET /pos/register remains the sparse selling workspace
preferred Register = signed 1-year per-Store cookie; convenience only
X Report = live open-Session totals; does not close
own X: pos.transact; other Registers: pos.sessions.view via Active Sessions
open-price: quantity-tracked and non-inventory Standard only
open-price Used/individual: explicit POS refusal
entered open price = selling = reference; not a price_override
F6 Price: override on ordinary sale lines; edit open price on open-price lines
$0-only basket may complete with no tender
scan unique sellable → add immediately
/ search always shows a list
- opens Linked/Unlinked chooser (keyboard)
post-void remains history-only
F10 opens history; working basket untouched
F5 stored-value tenders (Phase 10.4; Keyboard Lock includes F5)
+ = Cash with remaining prefilled (not a generic “any tender”)
Enter in scanner-sensitive fields resolves; never confirms cancel
```

---

## 1. Objective

Make all MVP capabilities practical to operate from one coherent cashier workflow.

```text
POS Home
  → Open or Resume Register
  → scan / search / pick / open-price
  → quantity, Price, discount, Tax Class
  → linked or unlinked return
  → F1–F4 / + settle
  → complete
```

6.7 does not invent new commercial models. It does add cashier-facing behavior that 6.1–6.6 deferred (open-price selling, pickers, POS Home, keymap).

---

## 2. Scope

### In 6.7

POS Home and Register chrome. Preferred Register cookie. Session-free POS Home / history / Session and Z **screens** (Open Register still required to sell). Read-only X Report. Breaking keyboard remap. Variant/unit pickers. `/` search. Open-price Standard. `-` return chooser and linked lookup from the selling surface. F1–F4 tenders. One dialog/error contract.

### Explicitly out

```text
Ctrl/Cmd/Alt maps
suspend / recall
open ring
open-price Used / individual
author catalog field / full catalog browser
post-void from the selling surface or POS Home
Store Close, paid-in, drop, drawer
integrated Card
customer print layout (6.8)
ESC/POS / printer discovery (out of MVP)
reprint audit
```

---

## 3. Modes

Browser state only. Transaction status remains `working` / `completed` / `cancelled`.

```text
POS_HOME
SALE_ENTRY
QUANTITY
MERCHANDISE_SEARCH
VARIANT_PICKER
UNIT_PICKER
OPEN_PRICE
RETURN
RETURN_LOOKUP
UNLINKED_RETURN
TENDER
OTHER_TENDER_PICKER
CONTROLLED_ACTION
```

Selling stays on the dedicated POS layout. GET still does not mutate.

---

## 4. POS Home and Register chrome

### 4.1 `GET /pos` — `POS_HOME`

POS layout, no selling scan field. Independent of Session.

Show: current Store, preferred Register (if any), current cashier, current Session if any.

Actions:

```text
Resume Register / Open Register
Transactions
X Report                    # this cashier’s open Session only
Active Sessions             # only with pos.sessions.view
Session / Z Reports
Switch Register
Return to ShelfSense
```

Do **not** use a **Management** label. Do not send cashiers into undifferentiated admin chrome from this list.

- **Resume Register** if this cashier has an open Session at this Store; else **Open Register**.
- Resume targets that **open Session’s Register**, not a newly preferred Register (§5).
- **X Report** never changes meaning by permission. Managers who need another Register’s X use **Active Sessions**.
- **Active Sessions:** list of open Sessions at this Store → that Session’s X Report.
- **Session / Z Reports:** existing closed-Session and Z screens; no open Session required to *view* (same idea as 6.3 history). Finalize Z and Open Register remain their existing commands.

### 4.2 `GET /pos/register`

Sparse selling chrome:

```text
POS Home
Transactions
X Report          # this Session
Close Register
```

Header still shows store, register, business date, cashier. No Switch Register, Return to ShelfSense, or general admin navigation around the scan field.

### 4.3 Switch Register while a Session remains open

Copy:

> **Register 02 is still open under your Session. Changing your preferred Register will not close it.**

Actions: **Change Preferred Register** / **Cancel**.

Preference change does not transfer, close, or open a Session. Occupied-register deny and Session-cashier rules in [register-workspace.md](../phase5-cash-register/register-workspace.md) §3 still decide whether the cashier may **enter** another Register.

---

## 5. Preferred Register

Signed persistent Rails cookie, not `localStorage`. Server-rendered `/pos` can read it.

```text
cookie name: pos_preferred_registers
payload: { store_id => register_id, ... }
signed
persistent
1-year TTL
refresh TTL when the preference changes
```

Use the remembered Register only when all of:

```text
Store matches current Store
Register still exists
Register is active
```

If the user changes Store, use that Store’s remembered Register if present; otherwise no preference.

If the preferred Register has an open Session for **another** cashier: keep it selected and say who is using it. **Do not** silently pick another Register.

The cookie confers neither authorization nor Session ownership.

---

## 6. Keyboard map

6.7 is the lock. Phase 5 “wireframe-validatable” bindings are superseded.

| Key | Action |
|---|---|
| Enter | per §7 |
| Esc | cancel current dialog / mode; restore scanner focus |
| `/` | `MERCHANDISE_SEARCH` (empty scan field only) |
| `*` | `QUANTITY` on selected quantity-tracked sale line |
| `-` | `RETURN` chooser (empty scan field only) |
| `+` | Cash settlement with remaining prefilled (§12); even-exchange complete (§12.4) |
| F1 | Cash |
| F2 | Card |
| F3 | Check |
| F4 | Other |
| F5 | stored-value tenders |
| F6 | **Price** on selected sale line (§9.3) |
| F7 | line discount on selected sale line |
| F8 | remove selected line or selected tender |
| F9 | cancel confirmation; second F9 confirms cancel |
| F10 | Transactions (§14) |
| ↑ / ↓ | move highlight in lists / selected line in `SALE_ENTRY` |

Intercept `/`, `*`, `-`, `+` only when the primary field is **empty** (same pattern as today’s `*` / `+`). A hyphen or slash inside a typed/scanned identifier is not Return or Search.

Extend Keyboard Lock to F1–F10. Phase 10.4 binds F5 to stored-value tenders (6.7 left it unbound). Postpone Ctrl/Cmd/Alt.

Every shortcut has a visible, focusable control. Unavailable keys explain why (§12.2) — no silent no-op for F1–F5 / F6 / F7 / F8 / `*` / `+` when the cashier has reason to think they should work.

F6/F7 remain disabled on **return** lines ([returns.md](returns.md)). Tax Class stays a **visible control** only (no F-key).

---

## 7. Enter contract

In scanner-sensitive identifier/search fields, Enter **resolves** the entered value. It does not implicitly confirm the next destructive or commercial step.

| Context | Enter |
|---|---|
| Sale-entry scan field | Resolve/add scanned identifier |
| `/` search query | Search / show results |
| Search result picker | Select highlighted result (then §8.3 resolver) |
| Variant picker | Select highlighted variant (then §8.3) |
| Unit picker | Select highlighted unit (add) |
| Open-price prompt | Apply entered price |
| Quantity | Apply quantity |
| Price control (ordinary override) | Apply when direct; continue to approval when required |
| Price control (open-price edit) | Apply new open price (no `price_override`) |
| Discount | Apply when direct; continue to approval when required |
| Tax Class picker | Apply when direct; continue to approval when required |
| Return chooser | Choose highlighted Linked / Unlinked |
| Linked-return lookup field | **Resolve/search only** |
| Linked-return result picker | Add selected return line |
| Unlinked identifier field | **Resolve only** |
| Resolved unlinked-return form | Apply when direct; continue to approval when required |
| Tender amount | If a required reference is still blank, focus the reference field; otherwise apply tender when all required fields are satisfied |
| Required tender reference (complete) | Apply tender |
| Manager username | Focus password; do not approve |
| Manager password | Approve/apply |
| Cancel confirmation | **Never confirms** |

Cancel dialog:

```text
Esc  → don’t cancel / close dialog
F9   → confirm cancellation
Enter → ignored
```

A scanner suffix Enter must never cancel the transaction.

---

## 8. Merchandise resolution

Distinguish **scanning/resolution** from explicit **search**. Lookup stays identifier-authoritative. Pickers only choose among `Identifiers::Lookup` results or store-available units. Do not add retired/unsellable rows.

### 8.1 Main sale-entry field (scan)

```text
unique directly sellable target     → add immediately
multiple eligible variants          → VARIANT_PICKER
individually tracked variant SKU    → UNIT_PICKER
unit barcode                        → add that unit (bypass pickers)
open-price Standard (unique)        → OPEN_PRICE prompt
open-price Used / individual        → error (§9.1)
```

This preserves the scanner fast path.

### 8.2 `/` Search

`/` opens `MERCHANDISE_SEARCH`. Fields: **SKU** and **Product name**. No author. Not a catalog browser. Cap ~20.

**Always show a result list**, even when only one text-search result exists. Highlight the first/best row. Workflow is `/` → type → Enter (search) → highlight → Enter (select). The cashier chose Search rather than Scan, so confirmation is required.

Ranking:

1. exact SKU match
2. remaining matches by Product name
3. SKU as deterministic tie-breaker

Unsellable / retired / open-price Used rows: **show disabled with a reason**, so catalog mistakes are visible. Enter on a disabled row does not add.

### 8.3 After a search or picker selection

Apply the **same resolver as scan** to the chosen variant/unit:

```text
Used / individual variant  → UNIT_PICKER (not a variant line)
open-price Standard        → OPEN_PRICE prompt
open-price Used            → same explicit error as scan
unique sellable Standard   → add
```

### 8.4 Picker display

Variant / product picker:

| Field | Show |
|---|---|
| SKU | Yes |
| Product name | Yes |
| Variant name / condition | Yes |
| Price | Yes — or `Open price` |
| Availability | Yes (`available`; Phase 3 `available = on_hand`) |
| Department | No |
| Tax Class | No |

Unit picker:

```text
Unit ID         Condition        Price
```

Omit units not on hand at this Store, and units already on **another** working ticket ([merchandise-breadth.md](merchandise-breadth.md) §4.4).

---

## 9. Open-price

### 9.1 Tracking forms

```text
quantity-tracked Standard     YES
non-inventory Standard        YES
individually tracked Used     NO
```

Catalog may still allow Used + `open_price`. POS resolution fails explicitly:

> Open-price individually tracked merchandise is not supported by this POS version.

Do not persist estimated cost from `departments.default_target_margin_bps`. Inventory-tracked open-price uses existing `Inventory::PostSale` (moving average / unit carrying value). Non-inventory continues to skip inventory posting.

### 9.2 Line facts

```text
entered amount >= 0
entered amount = selling_unit_price_cents
entered amount = reference_unit_price_cents
no price_override controlled action
```

Zero selling price is allowed and is not an override. If zero-price sales later need approval, that is controlled-action policy, not open-price.

Tax: current line Tax Class applied to the entered price (`Tax::Calculate` as usual).

Line discount: allowed under existing 6.4 policy.

Tax Class override: allowed under existing 6.4 policy.

Price override: **not applicable**.

Do **not** merge open-price lines on rescan (`AddMerchandise` compatible-line increment). Each confirmation is its own line. Quantity `n` on a confirmed open-price line is `n ×` that entered price (`ChangeQuantity` / `*`).

### 9.3 F6 Price (dual behavior)

Visible control label: **Price**.

```text
fixed / list-price / cost-based sale line
  F6 Price → controlled price override (6.4)
  reference unchanged; selling changes; reason + policy

open-price sale line
  F6 Price → edit entered open price
  no price_override row
  both reference and selling become the new cents
```

If a percentage discount already exists on the open-price line, **block the price edit**. Do not recalculate discount cents in place. The approved discount fingerprints selling basis, quantity, and basis points; changing the base after approval must not silently rebase.

```text
open-price, no discount
  F6 → edit reference and selling to the new cents
     → clear working tenders
     → recalc tax from the line’s current Tax Class
     → no price_override row

open-price, discount present
  F6 → "Remove the line discount before changing the price."
```

Any existing discount blocks the open-price edit (including a `$0.00` rounded discount). Reapply the discount through the normal controlled-action path after the price edit. Spell this in tests so an open-price correction never inserts `price_override`.

F6 on return lines stays disabled. Unlinked return price remains the `unlinked_return` action, not F6.

### 9.4 `$0`-only basket

Allowed.

```text
one or more valid lines
signed_net_cents = 0
→ no tender
→ complete normally
→ allocate receipt
→ post inventory where applicable
```

Sale-only or return-only zero-net remains 6.4/6.5 completion-pending / auto-complete. Mixed even exchange stays [returns.md](returns.md) §20: remain in `SALE_ENTRY`; `+` confirms complete — **not** a Cash `$0.00` tender.

---

## 10. Returns entry

`-` from empty `SALE_ENTRY` → `RETURN` chooser:

```text
RETURN

> Linked return
  Unlinked return

↑/↓ Select
Enter Choose
Esc Cancel
```

Linked is initially highlighted. Unlinked is **not** button-only.

### 10.1 Linked return lookup

Lookup field accepts: compact `transaction_reference`, merchandise identifier, unit identifier.

Receipt barcode encodes the compact reference ([receipt-identity.md](../phase4-point-of-sale/receipt-identity.md)):

```text
scan S003-R02-T0018427
→ same exact-receipt semantics as history
→ show that receipt’s returnable sale lines
```

Do **not** automatically return every line. Even a single original shows eligible lines so the cashier chooses what the customer is returning.

Merchandise identifier, many originals: current Store, remaining returnable `> 0`, not post-voided; order `completed_at` desc; cap 20; if truncated, require a receipt reference or history. Then the cashier picks a receipt, then lines.

Unit barcode still adds that unit when eligible.

History **Return items** remains and feeds the **same** `AddLinkedReturnLine` engine. Multi-origin lines in one basket are already 6.5.

After adding a linked return line, return to `SALE_ENTRY`. `-` again can locate another receipt.

Enter in the lookup field **resolves/searches only**. Enter on a highlighted returnable line adds it.

### 10.2 Unlinked

Chooser → existing `ExecuteUnlinkedReturn` overlay. Identifier field: Enter resolves only. Resolved form: apply when direct, or continue to approval when required.

---

## 11. X Report

Read-only live `Pos::SessionTotals` for an **open** Session.

Banner: `X REPORT` / `INTERIM — SESSION REMAINS OPEN`.

Must not close, count Cash, snapshot close, or finalize Z.

```text
this cashier’s open Session     → pos.transact
another cashier’s open Session  → pos.sessions.view
```

Seed `pos.sessions.view` (`either` scope): associate **no**; store manager and system administrator **yes**. `pos.transact` alone must not browse other live Registers. Existing databases need `./dev/rails-docker bin/rails shelfsense:seed_permissions`.

Closed Sessions use the existing Session report, not X.

---

## 12. Tender selection

Stop F2 cycling.

```text
F1  Cash
F2  Card
F3  Check
F4  Other
+   Cash with remaining prefilled
```

Amount defaults to remaining due (payment) or remaining refund (refund). Cash still distinguishes presented vs applied. Check/Other `external_reference_policy` unchanged. Card confirmation policy unchanged (6.2/6.5/6.6).

F1–F4 bypass the Cash default of `+` and select that tender.

### 12.1 F4 Other

Other identities sort by `code` (`TenderType.cashier_selectable`). No new `display_order`.

```text
no active Other     → F4 visually disabled; press → "No Other tender types are configured."
exactly one         → F4 selects that Other
more than one       → F4 opens Other picker; highlight first; do not auto-select
```

### 12.2 Refunds and unavailability

Same keys; filter `allows_refund` / active. Examples:

> Card refunds are not enabled.

> Card tender is not available.

No silent no-op.

### 12.3 `+` (payment)

```text
Due $26.72
+
→ Cash
  Amount: [26.72]
```

Exact Cash: `+` then Enter. Customer gives $40: `+` then `40` then Enter.

Refund-direction: `+` is **Cash refund** with remaining refund prefilled.

### 12.4 Even exchange

Mixed sale+return `signed_net = 0`: `+` confirms complete with no tender ([returns.md](returns.md)). Do not open a $0.00 Cash tender.

`+` with no merchandise: explain why (not a silent no-op).

---

## 13. Modals and errors

One dialog contract: dim workspace, focus first field, Tab trap, Enter per §7, Esc cancel, restore scanner focus. Visible `[Esc Cancel]` / `[Enter Apply]` where Enter applies.

Every blocking POS overlay must render its contents on an opaque, visually distinct dialog surface above the dimmed workspace. Fields and actions must never appear directly over the backdrop.

**Replace** 6.4 “Enter does not submit” except where a scan could confirm (lookup/identifier fields, cancel overlay).

Picker overlays (Other tender, variant, unit, return chooser) focus the highlighted option. Options are keyboard-focusable (`tabindex`, `role="option"`). Arrow keys move the highlight; Tab cycles only within the open dialog.

Errors: transient above scan (next input replaces); blocking inside the current dialog.

Recoverable field/action errors (invalid price, missing reason/note, approver credentials, policy denial until approval is supplied) keep the current dialog open: same non-secret values, error inside the overlay, password fields cleared and never echoed. Stale lock, completed transaction, or other invalidated commercial basis close the dialog and refresh the workspace.

Disable F10 while a blocking modal is open:

> Finish or cancel the current dialog before opening Transactions.

---

## 14. Post-void and F10

**Post-void remains history-only in 6.7.** No selling-workspace hotkey and no POS Home shortcut to initiate post-void.

**F10** (and visible Transactions): completed transaction history; current working basket remains untouched. Does not cancel, suspend, clear, or complete. Returning to the Register resumes the same persisted working transaction.

---

## 15. Authorization

```text
pos.transact + current Store     → POS Home, sell, own X, history, Session/Z view per existing rules
pos.sessions.view                → Active Sessions / other open Session X
Open Register / Close / Finalize → existing Session cashier / pos.transact rules
```

No new permission except seeding `pos.sessions.view` as specified.

---

## 16. Delivery

Letter so each PR stays reviewable:

- **6.7A** — this contract + [phase6-plan.md](phase6-plan.md) / companions (docs-only).
- **6.7B** — `/pos` home, preferred Register cookie, Session-free reporting nav, X Report + `pos.sessions.view`.
- **6.7C** — keyboard remap, F1–F4 (including Other picker and remaining prefill), modal/error contract, Keyboard Lock set (selling workspace still sparse). Do **not** intercept `/` or `-`.
- **6.7D** — variant/unit pickers, `/` search, open-price Standard (no derived cost). F6 on an open-price line with a discount is refused.
- **6.7E** — `-` return lookup (multi-origin). Tender keys remain 6.7C.

Merge gate each letter: Phase 5 all-Cash Standard path still green; GET still does not mutate; scanners still Enter-terminated keyboard input.

---

## 17. Acceptance

1. `/pos` is POS Home without a selling scan field; `/pos/register` remains the selling workspace.
2. Preferred Register is a signed per-Store cookie and never grants Session ownership.
3. Resume opens this cashier’s open Session Register even if preference points elsewhere.
4. X Report is interim live totals for an open Session and does not close it.
5. `pos.transact` cannot open another cashier’s live X; `pos.sessions.view` can via Active Sessions.
6. Unique scan still adds immediately; `/` search always presents a list.
7. Search/picker selection uses the same resolver as scan (Used → unit picker; open-price Standard → price prompt).
8. Open-price Used is refused with the locked message; quantity and non-inventory Standard open-price complete.
9. Open-price confirmation sets reference = selling; no `price_override`; rescan does not merge those lines.
10. F6 on an open-price line edits price without a controlled override; F6 on an ordinary line remains override; F6 on a return line stays disabled.
11. F6 on an open-price line with any existing discount is refused until the discount is removed; F6 never inserts `price_override` on an open-price line.
12. `$0` sale-only baskets complete with no tender; mixed even exchange still uses `+` to confirm.
13. `-` is a keyboard Linked/Unlinked chooser; Unlinked is not button-only.
14. Receipt barcode lookup is exact `transaction_reference`; lines are chosen, not auto-returned.
15. F1–F4 select tenders; unavailable keys explain why; `+` is Cash (or Cash refund) with remaining prefilled.
16. Cancel confirmation ignores Enter.
17. F10 leaves the working basket intact; F10 is disabled while a blocking modal is open.
18. Post-void is not offered from Home or the selling keymap.
19. Phase 5 all-Cash Standard path remains green.

---

## 18. Out of 6.7

```text
customer receipt redesign (6.8)
Session/Z label polish (6.8)
condition_name snapshot (6.8)
Store legal_name enforcement (6.8)
open-price Used
Ctrl/Cmd/Alt
suspend / recall / open ring
post-void hotkey
Z numbering
ESC/POS
```
