# Phase 5 Slice 2 — Register workspace wireframes

**Status:** Draft. Low-fidelity interaction proposal. Not implemented. Does not change the HTTP/domain contract in [register-workspace.md](register-workspace.md).

**Purpose:** Validate where the cashier's eyes are, where keyboard focus is, and what the next keystroke does — before Hotwire. Bindings, layout, error placement, and completion-pending presentation are **wireframe-validatable**; changing them here is not an architectural reversal.

HTTP, GET-does-not-mutate, one working transaction, tender/complete split, Rails-issued `completion_operation_id`, and the Slice 2 vs Slice 3 receipt split stay in [register-workspace.md](register-workspace.md).

Do not reuse admin chrome ([ux-conventions.md](../../../ux-conventions.md)). This is a dedicated POS layout. Money display uses `format_money_cents`; money entry uses decimal strings parsed by `Money::ParseCents`.

---

## How to read these frames

Each frame annotates:

| Annotation | Meaning |
|---|---|
| Focused element | Where the caret is. `[FOCUS]` in the drawing |
| Selected line | Which basket row QUANTITY / F8 apply to. `>` in the drawing |
| Next Enter | What Enter submits |
| Escape | What Escape does |
| Shortcuts | Keys that do something **on this frame** |
| Visible equivalents | Focusable controls for those shortcuts (keyboard-first, not keyboard-only) |
| Error location | Where the cashier sees failure without hunting |
| Turbo region(s) | What a successful response replaces. Full-page visits are named as such |

`[FOCUS]` is the only focused control. Visible action buttons are in tab order **after** the primary field. After every successful action and recoverable error, focus returns to the primary field unless the cancel overlay is open.

In-flight (any mutating POST waiting): primary field disabled; a second Enter must not queue another mutation.

Hidden fields (not drawn): `lock_version`; on completion-pending, `completion_operation_id`, `expected_total_cents`, `amount_presented_cents`. Stimulus does not recompute those.

---

## Shared selling chrome

Frames 3–7 share this skeleton. Open gate (1–2) and the completed receipt (8) do **not** include the scan field.

```text
+------------------------------------------------------------------+
|  pos_header                                                      |
|  Store  Downtown            Register  2            Alex Rivera   |
|  Business date  2026-08-17                                       |
+--------------------------------------+---------------------------+
|  pos_basket  (scrolls)               |  pos_totals  (fixed)      |
|  lines                               |  subtotal / tax / total   |
|                                      |  (amount due is largest)  |
+--------------------------------------+---------------------------+
|  pos_feedback   fixed height — errors must not move the field    |
|  pos_command    mode name + label + one primary field  [FOCUS]   |
|  pos_actions    Quantity (*)  Tender (+)  Remove (F8) Cancel (F9)|
+------------------------------------------------------------------+
|  pos_overlay   cancel confirmation only; absent unless open      |
+------------------------------------------------------------------+
```

**Header hierarchy (proposed):** store and register first, cashier on the right, **business date on its own line** and visually heavier than the names. If the period date is not today, `pos_header` adds a full-width banner (see 1c) so a leftover period cannot be missed.

**Stationary command area.** `pos_command` occupies a fixed location. `pos_feedback` reserves a stable height (empty when there is no message). Errors and status must not cause the primary input to jump. System-testable.

**Visible mode indicator.** The same physical field means identifier, quantity, or money. Show the mode name in the command area, not only a changed label:

```text
SALE ENTRY
Scan or identifier
[________________________]

QUANTITY
Blue gel pen · Current quantity 2
[ 2______________________]

CASH TENDER
Amount due $18.36
Cash presented
[________________________]
```

**Primary field stays in the same place** in `SALE_ENTRY`, `QUANTITY`, and `TENDER`. Completion-pending keeps that field visible but disabled.

**Totals stay on the right** and do not scroll. Amount due is the largest figure on the selling surface. After a successful `TenderCash`, that slot becomes **CHANGE**. Label presented cash as **Cash presented**, never bare “Cash” ($20 presented vs $18.36 applied).

**Basket is the scrolling region.** Header, totals, command, feedback, and actions stay put. New/rescanned line becomes selected and is scrolled into view. ArrowUp/ArrowDown keep the selected row visible.

**Line table columns (proposed):** qty, description (name + identifier), unit price, extended. Selected row uses a leading `>` plus a semantic selected state; do not rely on color alone.

**Minimum viewport for system tests:** `1280×720`. Do not discover later that the fixed chrome only fits a developer monitor.

**Accessibility:** [register-workspace.md](register-workspace.md) §9 (`alert` / `aria-live`, selected row, dialog, `disabled`).

**Turbo mapping**

| Region | Updates when |
|---|---|
| `pos_header` | Rarely (enter/resume). Not on scan |
| `pos_basket` | Add / quantity / remove / rescan merge |
| `pos_totals` | Same as basket; also after tender (change) |
| `pos_command` | Mode label, enabled/disabled, in-flight |
| `pos_feedback` | Every error and recoverable status |
| `pos_actions` | Enable/disable by mode (Tender when merchandise exists; Quantity/Remove when a line is selected; Cancel disabled when the basket is empty or complete is in flight) |
| `pos_overlay` | Cancel open/close (client-side until confirm POST) |

Merchandise / quantity / remove / tender responses are Turbo Streams that replace `pos_basket`, `pos_totals`, `pos_feedback`, `pos_actions`, and refresh `lock_version` in `pos_command`. Focus restoration is Stimulus, not a full-page visit.

`POST complete` success is a **full-page** visit to `GET /pos/transactions/:id/completed`. `POST continue` / `POST cancel` / `POST abandon_tender` return to `SALE_ENTRY` (cancel and continue via `ResumeOrStartTransaction`; abandon tender stays on the same working transaction).

---

## 1. Open gate — no Session

`GET enter` (read-only). `POST enter` creates period (if needed) and Session, then `ResumeOrStartTransaction`, then redirects to the workspace.

### 1a. No open period (confirm today's date + opening float)

```text
+------------------------------------------------------------------+
|  Open register                                                   |
|  Store  Downtown                                                 |
+------------------------------------------------------------------+
|                                                                  |
|  Register                                                        |
|  [ 2 — Front  v ]                                                |
|                                                                  |
|  Business date                                                   |
|  2026-08-17            (calculated; not editable)                |
|                                                                  |
|  Opening float                                                   |
|  $[ 100.00          ]  [FOCUS]                                   |
|                                                                  |
|  [ Open register ]                                               |
|                                                                  |
+------------------------------------------------------------------+
```

| Annotation | |
|---|---|
| Focused element | Opening float (if only one register). Register select if more than one register and none chosen yet |
| Selected line | n/a |
| Next Enter | `POST enter` (confirm date by submitting; collect float; open period + Session) |
| Escape | no-op on this page (or leave to store selection if that control is present — not a POS overlay) |
| Shortcuts | Enter submits. No `*` / `+` / F9 |
| Visible equivalents | **Open register** button |
| Error location | `form_errors` summary at top of this form, plus field error on float / register. Invalid money stays in the field |
| Turbo region(s) | Full page. Success: redirect `GET workspace`. Failure: re-render this page |

Opening float is required, integer cents ≥ 0, zero allowed. Shown only because this POST will **create** a Session.

If the store has one active register, the select is omitted (or read-only); focus starts on float.

### 1b. Open period exists, no Session (do not re-confirm a new date)

Same form as 1a, except business date is the **period's** date (read-only) and the submit label stays **Open register**. Opening float still required (new Session).

### 1c. Period date is not today

Same as 1b, plus a banner in the page header:

```text
|  This register's reporting period is 2026-08-16 — not today.     |
|  Slice 2 resumes it. Close / Z is Slice 3.                       |
```

Do not offer a date override. Do not open a second period.

### 1d. Resume the actor's own open Session

No opening float (must not change `opening_float_cents`).

```text
+------------------------------------------------------------------+
|  Open register                                                   |
|  Store  Downtown                                                 |
+------------------------------------------------------------------+
|                                                                  |
|  Register                                                        |
|  2 — Front                         (this is your open Session)   |
|                                                                  |
|  Business date                                                   |
|  2026-08-17                                                      |
|                                                                  |
|  [ Continue ]                      [FOCUS]                       |
|                                                                  |
+------------------------------------------------------------------+
```

| Annotation | |
|---|---|
| Focused element | **Continue** |
| Next Enter | `POST enter` → resume Session → `ResumeOrStartTransaction` → workspace |
| Escape | no-op |
| Visible equivalents | **Continue** |
| Error location | Top of this form (occupied race after reload: switch to frame 2) |
| Turbo region(s) | Full page → workspace |

---

## 2. Open gate — occupied Register

`GET enter` deny. Not a workspace overlay. `POST enter` for this register also denies.

```text
+------------------------------------------------------------------+
|  Open register                                                   |
|  Store  Downtown                                                 |
+------------------------------------------------------------------+
|                                                                  |
|  Register                                                        |
|  [ 2 — Front  v ]                  [FOCUS]                       |
|                                                                  |
|  Register 2 is open for Jordan Blake.                            |
|  You cannot enter this Session.                                  |
|                                                                  |
|  Choose a different register, or wait until that Session closes. |
|                                                                  |
|  [ Open register ]                 (disabled while 2 is selected)|
|                                                                  |
+------------------------------------------------------------------+
```

| Annotation | |
|---|---|
| Focused element | Register select (cashier can pick another) |
| Selected line | n/a |
| Next Enter | If another register is selected and available, `POST enter` for that register. If the occupied one is still selected, Enter does not submit |
| Escape | no-op |
| Shortcuts | none of the selling-surface keys |
| Visible equivalents | Register select; **Open register** enabled only when the selected register is enterable |
| Error location | Body of this page (the deny sentence). Not a flash on the selling surface |
| Turbo region(s) | Full page. Changing the select may be a GET (`?register_id=`) so the deny/float/continue state stays read-only until POST |

No manager takeover in Slice 2. If the store has only this occupied register, the cashier cannot enter POS; keep the deny visible.

---

## 3. SALE_ENTRY

`GET workspace` with a working transaction and no Cash tender. Ordinary selling surface.

### 3a. Empty basket (after enter / continue / cancel+resume)

```text
+------------------------------------------------------------------+
|  Downtown            Register  2                    Alex Rivera  |
|  Business date  2026-08-17                                       |
+--------------------------------------+---------------------------+
|                                      |  Subtotal         $0.00   |
|  Scan to add a line.                 |  Tax              $0.00   |
|                                      |                           |
|                                      |  Amount due       $0.00   |
+--------------------------------------+---------------------------+
|  pos_feedback  (fixed height; empty)                             |
|  SALE ENTRY                                                      |
|  Scan or identifier                                              |
|  [                                    ] [FOCUS]                  |
|                                                                  |
|  Quantity (*)          Tender (+)     (disabled)                 |
|  Remove (F8)           Cancel (F9)    (disabled)                 |
+------------------------------------------------------------------+
```

Quantity / Remove idle (no selected line). Tender idle (no merchandise). **Cancel disabled** — cancel+resume of an empty ticket has no useful effect and still blocks `CloseSession`. Slice 3 can dispose of leftover empty working transactions on leave/close.

### 3b. With lines (selected line = last added / last changed)

```text
+------------------------------------------------------------------+
|  Downtown            Register  2                    Alex Rivera  |
|  Business date  2026-08-17                                       |
+--------------------------------------+---------------------------+
|  Qty  Description              Unit      Ext                     |
|    1  Graphite notebook        $12.00    $12.00                  |
|  > 2  Blue gel pen   012345    $2.50     $5.00                   |
|                                      |  Subtotal        $17.00   |
|                                      |  Tax              $1.36   |
|                                      |                           |
|                                      |  Amount due      $18.36   |
+--------------------------------------+---------------------------+
|  pos_feedback  (fixed height; empty)                             |
|  SALE ENTRY                                                      |
|  Scan or identifier                                              |
|  [                                    ] [FOCUS]                  |
|                                                                  |
|  Quantity (*)          Tender (+)                                |
|  Remove (F8)           Cancel (F9)                               |
+------------------------------------------------------------------+
```

| Annotation | |
|---|---|
| Focused element | Scan or identifier (cleared after each successful add) |
| Selected line | Line returned by last `AddMerchandise` (here the pen). ArrowUp / ArrowDown move selection without leaving the field |
| Next Enter | Non-empty identifier → `POST merchandise` (`AddMerchandise`). Empty Enter is a no-op. Digits alone are an identifier, not quantity |
| Escape | Clear the field; stay `SALE_ENTRY` |
| Shortcuts | `*` quantity (if a line is selected); `+` tender (if merchandise exists); F8 remove selected; F9 cancel overlay; arrows move selection |
| Visible equivalents | **Quantity (\*)**, **Tender (+)**, **Remove (F8)**, **Cancel (F9)** |
| Error location | `pos_feedback` in the reserved strip above the field (unknown identifier, unsupported merchandise, stale `lock_version`). Basket unchanged. Field coordinates do not change |
| Turbo region(s) | Streams: `pos_basket`, `pos_totals`, `pos_feedback`, `pos_actions`; `lock_version` in `pos_command`. Focus stays in the field |

Rescan of a compatible SKU increments that line in `AddMerchandise`; the response selects **that** line. Same SKU with a different price/tax context is a new line.

`*` with no selected line is a no-op. `+` with no merchandise is a no-op. F8 with no selected line is a no-op. Delete is native text editing in the command field. Hyphens are identifier text.

### 3c. Unknown identifier (error)

Same as 3b, with `pos_feedback`:

```text
|  pos_feedback                                                    |
|  No sellable item for “XYZ999”.                                  |
|  SALE ENTRY                                                      |
|  Scan or identifier                                              |
|  [ XYZ999                             ] [FOCUS]                  |
```

Preserve the submitted string. Do not clear the basket. The primary field stays at the same coordinates as 3b.

---

## 4. QUANTITY

Same chrome. Primary field label becomes **Quantity**. Browser state only; transaction stays `working`.

```text
+------------------------------------------------------------------+
|  Downtown            Register  2                    Alex Rivera  |
|  Business date  2026-08-17                                       |
+--------------------------------------+---------------------------+
|  Qty  Description              Unit      Ext                     |
|    1  Graphite notebook        $12.00    $12.00                  |
|  > 2  Blue gel pen   012345    $2.50     $5.00                   |
|                                      |  Amount due      $18.36   |
+--------------------------------------+---------------------------+
|  pos_feedback  (fixed height; empty)                             |
|  QUANTITY                                                        |
|  Blue gel pen · Current quantity 2                               |
|  [ 2                                  ] [FOCUS]                  |
|                                                                  |
|  Quantity (*)          Tender (+)     (idle while in QUANTITY)   |
|  Remove (F8)           Cancel (F9)                               |
+------------------------------------------------------------------+
```

Pre-fill the selected line's current quantity so Enter without typing is a no-op-or-confirm of the same value (implementation may confirm the same quantity; it must not blank the field).

| Annotation | |
|---|---|
| Focused element | Quantity field (same DOM node as scan, new label). Select-all on entry so a scanner-or-type replacement is easy |
| Selected line | Unchanged (the line QUANTITY applies to). Arrows do not change selection in this mode |
| Next Enter | `POST quantity` (`ChangeQuantity`, absolute). Success → `SALE_ENTRY`, field cleared, that line still selected |
| Escape | Abandon; no POST; `SALE_ENTRY`; restore scan label; keep selection |
| Shortcuts | Enter, Escape, F9 (cancel overlay). `*` / `+` / F8 / arrows ignored while in QUANTITY |
| Visible equivalents | Field itself is the confirm target; **Cancel (F9)** still visible. No separate “OK” required; a visible **Update quantity** next to the field is allowed |
| Error location | `pos_feedback` in the reserved strip. Quantity `0` is invalid (do not remove from here — Escape, then F8 in `SALE_ENTRY`). Non-numeric: field error, stay QUANTITY. Field does not jump |
| Turbo region(s) | Success streams: `pos_basket`, `pos_totals`, `pos_feedback`, `pos_actions`, `pos_command` (back to scan label). Failure: `pos_feedback` only |

Basket mutation clears any working tender (none expected in this mode).

---

## 5. TENDER

Before `TenderCash` succeeds. Same chrome. Primary field label becomes **Cash presented**.

```text
+------------------------------------------------------------------+
|  Downtown            Register  2                    Alex Rivera  |
|  Business date  2026-08-17                                       |
+--------------------------------------+---------------------------+
|  Qty  Description              Unit      Ext                     |
|    1  Graphite notebook        $12.00    $12.00                  |
|    2  Blue gel pen   012345    $2.50     $5.00                   |
|                                      |  Subtotal        $17.00   |
|                                      |  Tax              $1.36   |
|                                      |                           |
|                                      |  Amount due      $18.36   |
+--------------------------------------+---------------------------+
|  pos_feedback  (fixed height; empty)                             |
|  CASH TENDER                                                     |
|  Amount due $18.36                                               |
|  Cash presented                                                  |
|  [                                    ] [FOCUS]                  |
|                                                                  |
|  Quantity (*)          Tender (+)     (idle)                     |
|  Remove (F8)           Cancel (F9)                               |
+------------------------------------------------------------------+
```

| Annotation | |
|---|---|
| Focused element | Cash presented |
| Selected line | Last selected line remains visually selected but is inactive (no F8 / QUANTITY until Escape back to `SALE_ENTRY`) |
| Next Enter | `POST tender` only (`TenderCash`). Does **not** complete. On success → frame 6 (Stimulus then `POST complete`) |
| Escape | Return to `SALE_ENTRY` without tendering; keep basket |
| Shortcuts | Enter, Escape, F9. `*` / `+` / F8 / arrows ignored |
| Visible equivalents | **Charge cash** / **Tender** next to the field; **Cancel (F9)** |
| Error location | `pos_feedback` in the reserved strip |
| Turbo region(s) | Success: streams (or morph) into frame 6 — `pos_totals` (change), `pos_command` (disabled), `pos_feedback`, hidden `completion_operation_id`. Failure: `pos_feedback`; field keeps the submitted string |

### 5b. Insufficient Cash

Stay in `TENDER`. Example `pos_feedback`:

```text
|  pos_feedback                                                    |
|  Cash presented must cover $18.36.                               |
|  CASH TENDER                                                     |
|  Amount due $18.36                                               |
|  Cash presented                                                  |
|  [ 10.00                              ] [FOCUS]                  |
```

No split tender. Cashier edits the amount and Enter retries `POST tender` only.

---

## 6. Completion-pending / recoverable completion error

Not a fourth named mode. Working transaction **plus** Cash tender. Input locked. Retry is `POST complete` only.

### 6a. In flight (ordinary path after successful `TenderCash`)

```text
+------------------------------------------------------------------+
|  Downtown            Register  2                    Alex Rivera  |
|  Business date  2026-08-17                                       |
+--------------------------------------+---------------------------+
|  Qty  Description              Unit      Ext                     |
|    1  Graphite notebook        $12.00    $12.00                  |
|    2  Blue gel pen   012345    $2.50     $5.00                   |
|                                      |  Subtotal        $17.00   |
|                                      |  Tax              $1.36   |
|                                      |  Total           $18.36   |
|                                      |  Cash presented  $20.00   |
|                                      |                           |
|                                      |  CHANGE           $1.64   |
+--------------------------------------+---------------------------+
|  pos_feedback  Completing sale…                                  |
|  CASH TENDER                                                     |
|  Cash presented (locked)                                         |
|  [                                    ] (disabled)               |
|                                                                  |
|  Quantity (*)  Tender (+)  Remove (F8) (disabled)                |
|  Cancel (F9)                           (disabled while in flight)|
+------------------------------------------------------------------+
```

| Annotation | |
|---|---|
| Focused element | None that can type. Caret must not sit in a field a scanner can fill. Optional: focus a non-editable **Completing** status so Enter is swallowed |
| Selected line | Inactive |
| Next Enter | Ignored while `POST complete` is in flight |
| Escape | Does **not** return to `SALE_ENTRY` |
| Shortcuts | None while in flight. F9 disabled |
| Visible equivalents | None active until a response. Unexpired `in_flight` on refresh: “Completion is still processing”; no Retry, no Return to sale, Cancel disabled |
| Error location | n/a until failure |
| Turbo region(s) | Success: **full-page** redirect to `GET /pos/transactions/:id/completed`. GET workspace refresh while still working+tender re-renders this frame and **restores** a matching `in_flight`/`failed` `completion_operation_id` if one exists; mints only if complete was never started. If that transaction is already completed: redirect to **that** id's receipt |

Eyes: **CHANGE** is the largest figure (give the customer cash). Stimulus issues `POST complete` automatically after tender success, reusing the Rails token.

### 6b. Recoverable complete failure (inventory, network, unresolved tax, stale lock after showing this frame)

Same layout as 6a, with `pos_feedback` and controls re-enabled for retry / return / cancel:

```text
|                                      |  CHANGE           $1.64   |
+--------------------------------------+---------------------------+
|  pos_feedback                                                    |
|  Could not complete — inventory short for Blue gel pen.          |
|  Tender is kept. Retry does not take Cash again.                 |
|                                                                  |
|  [ Retry complete ] [FOCUS]     [ Return to sale ]               |
|  Cancel (F9)                     (enabled)                       |
```

| Annotation | |
|---|---|
| Focused element | **Retry complete** |
| Next Enter | `POST complete` with the **same** `completion_operation_id`, `expected_lock_version`, totals, and presented amount |
| Escape | Does not silently dump to `SALE_ENTRY`. Use **Return to sale** (`POST abandon_tender`) |
| Shortcuts | Enter = retry; F9 = cancel overlay. `*` / `+` / F8 ignored |
| Visible equivalents | **Retry complete**, **Return to sale**, **Cancel (F9)** |
| Error location | `pos_feedback` in the reserved strip (inventory, tax, network, stale `lock_version`) |
| Turbo region(s) | Retry success: full-page that transaction's receipt. Retry failure: `pos_feedback`. Return to sale: `POST abandon_tender` → `SALE_ENTRY` with no working tender. Cancel: overlay → `POST cancel` (`CancelTransaction` discards the tender, then `ResumeOrStartTransaction`) → empty `SALE_ENTRY` |

Do not `POST tender` again from this frame. Changing Cash presented: **Return to sale** (clears tender) then `+` / Tender (new `TenderCash`, new token). Refresh after Return to sale stays `SALE_ENTRY`.

If `POST complete` hits an already-completed transaction (lost response): **full-page** `GET /pos/transactions/:id/completed` for **that** id.

---

## 7. Cancel confirmation

The only overlay. No text field. Opens over frames 3b–5 and 6b (not 3a — Cancel disabled; not 6a; not 8; not the open gate). Real dialog; background inert.

```text
+------------------------------------------------------------------+
|  Downtown            Register  2                    Alex Rivera  |
|  … selling surface dimmed; not focusable …                       |
|                                                                  |
|           +----------------------------------------+             |
|           |  Cancel this sale?                     |             |
|           |                                        |             |
|           |  Lines will not be sold.               |             |
|           |  No receipt. No inventory movement.    |             |
|           |                                        |             |
|           |  [ Don't cancel  Esc ]                 |             |
|           |  [ Cancel sale   F9  ]                 |             |
|           +----------------------------------------+             |
+------------------------------------------------------------------+
```

No caret in an input. Do not put `[FOCUS]` on a text field. Proposed: focus **Don't cancel** so a stray Enter does nothing useful if it were honored — and **Enter is ignored** regardless.

| Annotation | |
|---|---|
| Focused element | **Don't cancel** (no input). Scanner keystrokes must not land anywhere typed |
| Selected line | Unchanged underneath; inactive |
| Next Enter | **Ignored** (barcodes end in Enter) |
| Escape | Abort overlay; restore prior mode and focus (scan / quantity / cash / retry) |
| Shortcuts | F9 confirms cancel (`POST cancel`). Alphanumeric keys ignored. `*` / `+` / F8 ignored |
| Visible equivalents | **Don't cancel (Esc)**, **Cancel sale (F9)** |
| Error location | If `POST cancel` fails, close overlay, `pos_feedback` on the underlying frame, restore focus to primary |
| Turbo region(s) | Overlay is Stimulus until confirm. Success: `CancelTransaction` discards working tenders, then full-page `SALE_ENTRY` after `ResumeOrStartTransaction`. Do not land on a prior receipt |

First F9 opens this overlay. Second F9 confirms. There is no `Y` confirm.

---

## 8. Completed receipt / confirmation

Immutable completed facts only. No print in Slice 2. No scan field.

Reached only with an **explicit** completed transaction identity:

```text
successful CompleteTransaction
  → redirect GET /pos/transactions/:id/completed
replayed CompleteTransaction
  → redirect to that same id
explicit completed receipt URL
  → render that transaction
GET workspace with no working transaction
  → GET enter
  (does not infer a receipt from the Session's completed sales)
```

The browser may retain the transaction id it was completing so a lost redirect can still request that receipt. The server does not guess “latest completed.”

```text
+------------------------------------------------------------------+
|  Downtown            Register  2                    Alex Rivera  |
|  Business date  2026-08-17                                       |
+------------------------------------------------------------------+
|                                                                  |
|  Sale complete                                                   |
|                                                                  |
|  S003-R02-T0018427                                               |
|                                                                  |
|  Total                         $18.36                            |
|  Cash presented                $20.00                            |
|  Change                         $1.64                            |
|                                                                  |
|  1 × Graphite notebook         $12.00                            |
|  2 × Blue gel pen               $5.00                            |
|  Tax                            $1.36                            |
|                                                                  |
|  [ New sale ]                                                    |
|                                                                  |
+------------------------------------------------------------------+
```

Do **not** default-focus **New sale**. Slice 2: **Enter does nothing** on this page (no identifier buffer). **New sale** is an explicit control (click, or a dedicated non-Enter shortcut — which key is wireframe-validatable). A later slice may add “scan on receipt → start new sale and add that identifier”; do not implement that orchestration now.

| Annotation | |
|---|---|
| Focused element | A non-activating target (heading or status). **New sale** is prominent and in tab order |
| Selected line | n/a (completed lines are a summary, not a working selection) |
| Next Enter | **No-op.** Does not `POST continue`. Scanner Enter cannot start a sale or drop a barcode |
| Escape | no-op (do not cancel a completed sale) |
| Shortcuts | No `*` / `+` / F8 / F9. New sale uses the visible control (optional dedicated non-Enter key) |
| Visible equivalents | **New sale** (prominent). No print control |
| Error location | If continue fails (session closed, occupancy): message on this page; do not create a working transaction on GET |
| Turbo region(s) | Full page. Not a Turbo Frame inside the selling surface — a scan must not be interpretable as `AddMerchandise` |

Render from completed transaction facts (`transaction_reference`, total, Cash presented, change, concise lines/tax). Never from leftover working browser state. Technical UUID stays out of the cashier's primary view. **Cash presented** is the physical amount ($20), not the applied payment ($18.36).

---

## Keyboard map (proposed; wireframe-validatable)

| Key | Where it applies | Action |
|---|---|---|
| Enter | Open gate | Submit enter / continue |
| Enter | `SALE_ENTRY` | Add merchandise |
| Enter | `QUANTITY` | Set absolute quantity |
| Enter | `TENDER` | `POST tender` only |
| Enter | Completion-pending in flight | Ignored |
| Enter | Completion error | Retry complete |
| Enter | Cancel overlay | **Ignored** |
| Enter | Completed receipt | **Ignored** (New sale is the explicit control) |
| Escape | `SALE_ENTRY` | Clear field |
| Escape | `QUANTITY` / `TENDER` | Back to `SALE_ENTRY` |
| Escape | Completion-pending | No silent return |
| Escape | Cancel overlay | Abort |
| `*` | `SALE_ENTRY` only | Quantity (no-op if no selected line) |
| `+` | `SALE_ENTRY` only | Tender (no-op if no merchandise) |
| F8 | `SALE_ENTRY` only | Remove selected line |
| ArrowUp / ArrowDown | `SALE_ENTRY` only | Move selected line |
| F9 | Selling surface, not in-flight complete, basket has lines | Open cancel overlay |
| F9 | Cancel overlay | Confirm cancel |

Intercept `*` and `+` on keydown in `SALE_ENTRY` so they never become identifier text. Do not intercept letter keys or hyphen. Delete is native text editing. F8 removes the selected line.

---

## Out of these wireframes

Print prompt, blind close, Z screens (Slice 3). Split tender, discounts, returns, suspend/recall, drawers, customer display, mobile layout, polished visual design. Admin shell.

---

## What to validate in review

These are the interaction questions this pass is for:

1. Primary field at the **bottom** (same place in every selling mode) vs top.
2. Totals on the **right**, with amount due / change as the largest figure.
3. **F9** as cancel (open, then confirm) vs another non-letter key.
4. Leftover period: banner copy and weight enough to be unmissable?
5. Completion-pending: huge **CHANGE**, locked field, auto-`POST complete` — or should the cashier press Enter once more to complete?
6. Recoverable complete error: focus on **Retry complete**; Escape does not return to sale.
7. Cancel-overlay scanner safety (Enter ignored; second F9 confirms).
8. Occupied register: stay on `GET enter` with register select, not a workspace modal.
9. Feedback placement in the reserved strip, not a top-of-page admin flash.
10. Does feedback appear without moving the command field?
11. Does a long basket scroll independently while command/totals remain fixed?
12. Return to sale discards the persisted tender (`POST abandon_tender`). Cancel from 6b also discards the tender (`CancelTransaction`).
13. Completed receipt: Enter is a no-op; New sale is explicit. (Later: scan-on-receipt → new sale + add SKU.) Dedicated non-Enter New sale shortcut?
14. Is the current mode unmistakable at a glance?

HTTP/domain locks (not open UX questions): no latest-receipt inference; restore matching `operation_id`; `AbandonTender`; empty-basket Cancel disabled; `CancelTransaction` clears working tenders.

Accepting this document (with any of items 1–5, 7, 13–14 adjusted) is what makes Slice 2 interaction locked enough to implement domain invariants, then Hotwire.
