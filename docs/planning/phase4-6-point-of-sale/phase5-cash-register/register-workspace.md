# Phase 5 Slice 2 — Register workspace contract

**Status:** HTTP/domain contract locked. Register workspace implemented (Importmap + Turbo + Stimulus).

**Authority:** Cashier-facing online Register workspace: open gate, ephemeral UI modes, HTTP commands, focus/retry rules, and the Slice 2 vs Slice 3 receipt split. Domain completion, tax, inventory posting, and receipt identity remain in the [Phase 4 packet](../phase4-point-of-sale/). Cash/Z snapshots remain in [phase5-schema.md](phase5-schema.md).

Companions: [phase5-plan.md](phase5-plan.md), [register-workspace-ux.md](register-workspace-ux.md), [receipt-identity.md](../phase4-point-of-sale/receipt-identity.md). Low-fidelity wireframes in `register-workspace-ux.md` (review before Hotwire). Changing a key binding or layout in that pass is not an architectural reversal.

Where this document and [spec.md](../spec.md) §5.4–5.11 disagree, **prefer this document**.

**Governing UX principle:** where are the cashier's eyes, where is keyboard focus, and what will the next keystroke do?

### Actually locked

```text
Hotwire + system/browser tests
dedicated POS layout
one working transaction
GET does not mutate
ResumeOrStartTransaction
rescan merge in AddMerchandise
basket mutation clears tender
AbandonTender (return to sale)
CancelTransaction clears working tenders
TenderCash / CompleteTransaction split
completion retry semantics (no re-tender)
Rails-issued completion operation_id (restore matching in_flight/failed)
lost-complete recovery by explicit transaction id (not latest-in-session)
cancel disabled when the basket is empty (UI only)
Slice 2 vs Slice 3 boundary
```

### Wireframe-validatable

```text
* / + / Delete / F9 bindings
header hierarchy
line-table layout and selected-line styling
where errors appear
how completion-pending looks
visible button arrangement
receipt confirmation layout
completed-receipt New sale shortcut (not Enter)
```

---

## 1. Locked stack and testing

| Topic | Decision |
|---|---|
| Client | Rails-native online POS. No Terminal table (ADR-021). No scanner API; scanners are keyboard input ending in Enter |
| UI stack | Importmap + Turbo + Stimulus. Gems are installed for the Register workspace |
| Layout | Dedicated POS layout. Do not reuse admin chrome for the selling surface (it would steal scan focus) |
| Permission | `pos.transact` at the current store. Session cashier for session/transaction commands (`require_session_cashier!` / `require_transaction_cashier!`) |
| Controllers | Orchestrate Phase 4/5 services only. No receipt allocation, inventory posting, tax calculation, or commercial total mutation in controllers or Stimulus |
| Browser tests | Meaningful client-side POS behavior **requires** system/browser tests. Request tests cannot prove focus, scanner Enter, Escape, or duplicate-submit prevention |
| Keyboard-first | Ordinary sale path requires no mouse. Every shortcut has a visible, focusable control |
| Money entry | Decimal strings via `Money::ParseCents`. Never binary floats |

Do not install Importmap / Turbo / Stimulus in a docs-only change.

---

## 2. Slice 2 vs Slice 3

| Slice 2 | Slice 3 |
|---|---|
| Open gate, selling workspace, on-screen **completion receipt/confirmation** | Receipt **print** path, blind session close, Z finalize screens |
| Render completion confirmation from **immutable completed transaction facts** | Print representation of those same facts |
| No print controls | One supported print path; printer failure does not undo completion |

Slice 2 completion receipt minimum:

```text
transaction_reference
completed total
Cash presented
change
completed lines / tax (concise)
prominent continue / new sale
```

Never render the confirmation from leftover working browser state.

---

## 3. Open gate

Requires `current_store` and `pos.transact`. If no current store, redirect to existing store selection. Cashier picks an **active register** in that store (auto-select if only one).

| Request | Mutates? | Role |
|---|---|---|
| `GET enter` | no | Open-gate form: register pick, date, float when needed, occupied-register deny |
| `POST enter` | yes | Resolve period/session and `ResumeOrStartTransaction`; redirect to workspace |
| `GET workspace` | no | Selling surface: `SALE_ENTRY` or completion-pending (never creates; never infers a receipt) |

Authoritative resolve (also after a uniqueness race: **reload state and apply these rules**; do not surface a raw unique-index exception):

```text
Register has open Session for actor
  → resume it
  → show that Session's period business_date read-only
  → do not collect opening float

Register has open Session for a different cashier
  → GET enter shows deny (not a workspace overlay)
  → POST enter denies

Register has no open Session:
  use the existing open period if one exists
    (do not re-confirm a date; use the period's business_date)
  otherwise open a period for BusinessDate.for_store(...) (confirm; no override)
  then open Session (opening float required, integer cents >= 0, zero allowed)
```

Opening float is collected **only when this POST will create a Session**. Resuming the actor's open Session must not change `opening_float_cents`. Float is not a paid-in and not a Cash tender.

**Yesterday’s open period:** one open period per register. If it is still open, resume it and show **that** `business_date`. Do not open a second period because the calendar rolled. Make a non-today date unmissable in the header. Slice 3 is how a leftover period is Z’d. Slice 2 has no “please Z first” wizard.

---

## 4. One working transaction

```sql
UNIQUE (pos_session_id) WHERE status = 'working'
```

`StartTransaction` rejects if a working row exists while it holds the session lock. **Start means start** — do not give it resume semantics.

Controllers must not `find || StartTransaction`. Use `Pos::ResumeOrStartTransaction` (UI-safe boundary). Both services share an internal create kernel after the Session is already locked and validated; Resume must not call Start (duplicated orchestration / second lock acquisition).

```text
StartTransaction
  → lock + authorize + validate
  → reject if a working transaction exists
  → create

ResumeOrStartTransaction
  → lock + authorize + validate
  → return existing working transaction or create
```

**GET never creates transactions.** Refresh, prefetch, crawlers, and the back button must not mutate commercial state.

```text
GET workspace (never create)
  → find the Session's existing working transaction for this cashier

  if working transaction exists
    if it has a Cash tender
      → render completion-pending
        (restore matching completion_operation_id from persisted settlement — see §6)
    otherwise
      → render SALE_ENTRY
  else
    → redirect GET enter
    (do not infer a receipt from the Session's completed sales)

POST enter / POST continue
  → ResumeOrStartTransaction
  → redirect to workspace
```

Completed receipts are reached only with an **explicit** transaction identity: redirect after successful or replayed `CompleteTransaction`, or `GET /pos/transactions/:id/completed`. `GET workspace` never guesses “latest completed.”

Two browser tabs: last writer wins via `lock_version`. The stale tab shows an error and reloads. Slice 2 does not sync tabs.

Empty working transactions created on enter/continue **block** `CloseSession` (existing Slice 1 gate). Do not auto-cancel on GET. Slice 2 **disables the Cancel control** while the working transaction has no lines (cancel+resume of an empty ticket is a no-op that still blocks close). `CancelTransaction` itself **may** cancel an empty working transaction — Slice 3 may need that to dispose of leftovers before close. After `CancelTransaction` of a sale that had lines, immediately `ResumeOrStartTransaction` (same as `POST continue`) so the cashier returns to empty `SALE_ENTRY`.

---

## 5. HTTP contract

Stimulus may make `POST tender` then `POST complete` feel like one Enter. They are **not** one controller action.

```text
GET enter
  → read only (open-gate form)

POST enter
  → resolve/open period
  → resolve/open Session
  → ResumeOrStartTransaction
  → redirect workspace

GET workspace
  → read only; never create
  → find the Session's existing working transaction for this cashier
  → if working + Cash tender: render completion-pending
       (restore matching completion_operation_id from persisted settlement — see §6)
  → if working, no tender: render SALE_ENTRY
  → if no working transaction: redirect GET enter
       (never infer a completed receipt)

POST merchandise     → AddMerchandise; clear working tenders
POST quantity        → ChangeQuantity; clear working tenders
POST remove          → RemoveWorkingLine; clear working tenders
POST abandon_tender
  → Pos::AbandonTender (lock working transaction; require transaction cashier;
    destroy working tender; advance lock_version only if a tender was removed)
  → render SALE_ENTRY
POST cancel
  → workspace UI: only when the working transaction has at least one line
    (CancelTransaction may still cancel an empty working transaction)
  → CancelTransaction (after explicit confirmation):
       lock working transaction
       clear working tenders (shared helper; no extra aggregate save)
       status = cancelled, cancelled_at = Time.current
       (keep cancelled lines)
  → ResumeOrStartTransaction
  → redirect workspace (SALE_ENTRY)

POST tender
  → TenderCash
  → return change_cents, lock_version, expected_total_cents, amount_presented_cents,
    completion_operation_id (SecureRandom.uuid_v7)
  → do not complete

POST complete
  → CompleteTransaction using the Rails-issued completion_operation_id as operation_id
  → retries hit only this endpoint with the same payload and same operation_id
  → if the transaction is already completed: redirect to GET /pos/transactions/:id/completed
    (lost-response / replay; do not create a second completion)
  → otherwise redirect to GET /pos/transactions/:id/completed

GET /pos/transactions/:id/completed
  → that transaction's immutable completed facts only
  → session/transaction cashier only
  → if the transaction is not completed: not found (do not complete on GET)

POST continue
  → ResumeOrStartTransaction
  → redirect workspace
```

Direct unauthorized requests must fail, including a second cashier operating another cashier's Session.

---

## 6. Tender vs complete (blocker)

`TenderCash` destroys/recreates the Cash tender and advances `lock_version`. `CompleteTransaction` includes that post-tender `expected_lock_version` in its idempotency command hash. Re-running `TenderCash` on a completion retry changes the hash and raises `PayloadMismatch`.

Ordinary cashier Enter in `TENDER`:

```text
disable input
POST tender (expected_lock_version = v5)
  → change + lock_version = v6
  → completion_operation_id = A   (Rails: SecureRandom.uuid_v7)
POST complete (
    operation_id = A,
    expected_lock_version = v6,
    expected_total_cents from the tender response,
    amount_presented_cents from the tender response
  )
  → GET /pos/transactions/:id/completed
```

Completion retry:

```text
POST complete again
operation_id = A
expected_lock_version = v6
same command payload
```

Do **not** re-tender.

### `operation_id` lifetime

Rails issues the UUIDv7. Stimulus treats `completion_operation_id` as an opaque token. Do not add a JavaScript UUIDv7 implementation for this.

```text
POST tender succeeds
  → response includes completion_operation_id = SecureRandom.uuid_v7
     (mint only; CompleteTransaction has not run yet)
POST complete
  → operation_id = that token, unchanged on retries
GET workspace while working + tender (refresh)
  → FindCompletionOperation against persisted settlement
       (transaction.lock_version, transaction.total_cents,
        Cash tender amount_presented_cents — not browser-supplied values)
  → matching in_flight or failed pos.complete_transaction
       (recompute CanonicalJson.hash with that row’s id as operation_id)
       → restore that operation_id; Retry complete uses the same command
  → no matching completion operation
       → mint a new completion_operation_id
  → transaction already completed
       → redirect GET /pos/transactions/:id/completed for that id
```

Do **not** unconditionally mint a new id on refresh. Minting B while A is `in_flight` is a second completion attempt for the same sale.

- Reuse the token only for retries of that same post-tender payload (`expected_lock_version`, expected total, amount presented).
- A new `TenderCash` (changed presented amount, or re-tender after `AbandonTender`) returns a **new** `completion_operation_id`.
- After `TenderCash` succeeds, do not `POST tender` again unless the cashier is changing the presented amount. That requires `POST abandon_tender` (Return to sale) or Escape **before** `TenderCash` succeeded. Then a new `TenderCash` and a new token.
- Stimulus sends `expected_total_cents` and `amount_presented_cents` from the **last tender / completion-pending render**, not a client-side recompute. Recovery on GET workspace uses **persisted** transaction + tender, not those browser fields.
- Abandoned `in_flight` leases expire in 2 minutes (`PosOperation::LEASE_DURATION`). Do not reuse an old token after a new tender.

If completion fails recoverably: keep the working transaction **and** the tender; show a completion error; offer retry complete with the **same** token. **Return to sale** is `POST abandon_tender`, then `SALE_ENTRY` with no working tender (`lock_version` advances only if a tender was removed). Changing Cash presented after a failed complete: Return to sale, then `+` / Tender (new `TenderCash`, new token).

### Lost complete response

Phase 4 already prevents a second commercial effect. Recovery must reference **that** transaction, not “latest completed in this Session”:

```text
working transaction + Cash tender  → completion-pending (restore operation_id per above)
POST complete / retry for an already-completed transaction
  → GET /pos/transactions/:id/completed for that id
GET /pos/transactions/:id/completed
  → that transaction's receipt
GET workspace, no working transaction
  → GET enter
```

The browser may retain the transaction id it was completing (so a lost redirect can still request that receipt). The server must not infer a receipt from other completed sales in the Session.

F9 / cancel is disabled while a `POST complete` is in flight. After a recoverable complete failure, the workspace allows cancel if the basket has lines. `CancelTransaction` may still cancel an empty working transaction (Slice 3).

Working-command in-flight guard: a second Enter must not fire `AddMerchandise` (or another mutation) before the first response refreshes `lock_version`.

Presented amount less than amount due: `TenderCash` rejects; remain in `TENDER`; preserve/edit the amount; focus the primary amount input. No split tender in Phase 5.

---

## 7. Ephemeral UI modes

UI mode is **browser state**. Authoritative transaction status remains `working` / `completed` / `cancelled`.

One primary POS input. Autofocus on load. After every successful action and recoverable error, focus returns there unless a confirmation overlay is open. Overlays must restore focus to the primary input.

Quantity and tender **reuse that same primary field** with a changed label. The only overlay is **cancel confirmation**. Occupied-register deny lives on `GET enter`, not on the selling surface.

Intercept `*` and `+` on keydown so they never become identifier text. Do not intercept letter keys such as `T`.

`*` with no selected line is a no-op (stay `SALE_ENTRY`). `+` with no merchandise is a no-op. QUANTITY with no selected line is not entered.

| Mode | Enter | Escape | Other |
|---|---|---|---|
| `SALE_ENTRY` | identifier → `AddMerchandise`. Empty Enter is a no-op. Digits alone are an identifier, not quantity | clear input; stay `SALE_ENTRY` | `*` → `QUANTITY` if a line is selected; `+` → `TENDER` if merchandise exists; Delete removes selected line |
| `QUANTITY` | `ChangeQuantity` on selected line → `SALE_ENTRY` | abandon → `SALE_ENTRY` | quantity `0` is invalid (service requires positive); Delete is not used here — Escape then Delete in `SALE_ENTRY` |
| `TENDER` (before `TenderCash` succeeds) | `POST tender` only | → `SALE_ENTRY` | insufficient Cash: remain `TENDER` |
| completion pending (`TenderCash` succeeded, including GET workspace restore) | not a fourth named mode; input locked until complete response | do not silently return to `SALE_ENTRY` | retry is `POST complete` only; **Return to sale** is `POST abandon_tender` |

Keyboard map (shortcuts; each has a visible control). Bindings are **wireframe-validatable**; F9 is the current proposal, not an architectural lock.

| Key | Action |
|---|---|
| Enter | confirm current mode; **ignored** on the cancel overlay |
| Escape | back out where the table allows; on cancel overlay, abort confirm |
| `*` | `QUANTITY` (no-op if no selected line) |
| `+` | `TENDER` (no-op if no merchandise) |
| Delete | `RemoveWorkingLine` on the selected line in `SALE_ENTRY` |
| ArrowUp / ArrowDown | move selected line (in `SALE_ENTRY`) |
| F9 | open cancel confirmation (disabled while `POST complete` is in flight, and while the basket has no lines) |
| F9 again | confirm cancel (**not** Enter, **not** `Y` — barcodes may contain letters) |

Cancel overlay: no text field (so a scan cannot type into it). Ignore Enter and alphanumeric keys. Visible Confirm (activates on second F9) and Don't cancel (Escape). Abort restores the prior mode and focus.

Selected line defaults to the line **returned** by the last `AddMerchandise`, or the last changed line. After `RemoveWorkingLine`, select the previous remaining line, or none if the basket is empty. Arrow keys move selection. QUANTITY and Delete apply to the selected line.

---

## 8. Merchandise commands

Phase 5 UI sells only standard quantity-tracked merchandise (existing `AddMerchandise` validations).

**Rescan merge** happens in `AddMerchandise` after the working-transaction lock, not in Stimulus. Compatible line:

```text
same product_variant_id
same direction
same selling_unit_price_cents
same tax_class_id
same relevant pricing basis
```

Phase 5 has no discounts or price overrides, so unit price + tax class is the pricing basis. Increment quantity by the scanned amount (default 1). QUANTITY mode sets **absolute** quantity via `ChangeQuantity`.

`AddMerchandise` returns the **resulting line** in both cases (new line or incremented line) so the UI always selects that line.

Same variant with a different price/tax context becomes a separate line.

**Basket mutation, Return to sale, and Cancel invalidate working tenders.** Share one helper (`clear_working_tenders!`): destroy working tenders only — do **not** `save!` the aggregate (basket commands persist via `refresh_totals!`). `AddMerchandise`, `ChangeQuantity`, and `RemoveWorkingLine` clear then mutate in the same database transaction. **Return to sale** is `Pos::AbandonTender` (`POST abandon_tender`): lock the working transaction, require the transaction cashier, destroy the working tender, advance `lock_version` **only if a tender was removed**, render `SALE_ENTRY`. After that, GET workspace is `SALE_ENTRY` (no hidden tender). The cashier must re-enter `TENDER` to settle.

**`CancelTransaction` clears working tenders** in the same database transaction, under the working-transaction lock, before marking the transaction cancelled. Keep cancelled lines (minimal cancellation activity). Do not leave a cancelled row with a provisional Cash tender. Completed tenders are never touched (`lock_working_transaction!` already forbids that). The service **may** cancel an empty working transaction.

Exit paths:

```text
basket edit     → tender invalidated
Return to sale  → tender abandoned
Cancel          → tender discarded
Complete        → tender becomes completed immutable fact
```

Inventory shortage is a **completion** error (Phase 4 posts on complete, not on add-line). The scan path will not catch oversell.

Cancel: explicit confirmation overlay (see keyboard map). Slice 2 **disables the control** when the working transaction has no lines; that is operator UX, not a `CancelTransaction` invariant. Escape / Don't cancel returns to the prior mode and focus. Scanner Enter must not confirm. Cancel from the recoverable completion-error screen (working + tender) uses this same `CancelTransaction` rule.

---

## 9. Accessibility (locked)

Not a visual redesign. Lock these before Stimulus is written:

```text
pos_feedback errors     → role="alert" (or equivalent assertive live region)
ordinary status         → aria-live="polite"
selected basket row     → semantic selected state, not color alone
cancel overlay          → real dialog; background inert / non-focusable;
                          focus restored to the primary field when closed
disabled actions        → actual disabled state (empty-basket Cancel, in-flight complete)
```

Custom key handling must not undermine these semantics.

---

## 10. Slice 2 acceptance (contract)

A cashier can:

1. Enter the Register workspace only with an open reporting period and open Session belonging to them (open gate creates or resumes).
2. See the period's business date; cannot edit it.
3. Scan/type a sellable identifier and press Enter to add merchandise.
4. Continue scanning without manually restoring focus.
5. Scan the same compatible SKU again and increment the existing line.
6. Change quantity and remove a working line using keyboard-only interaction (visible controls also exist).
7. Cancel a sale that has lines with explicit confirmation that scanner Enter cannot submit (second F9 confirms; Enter ignored). Slice 2 disables Cancel on an empty basket; `CancelTransaction` may still cancel an empty working transaction. The service discards any working tender before marking the sale cancelled.
8. Enter Cash presented; insufficient Cash stays in `TENDER`; valid settlement calls `TenderCash` then `CompleteTransaction` as two HTTP requests.
9. Retry completion without calling `TenderCash` again; one receipt and one inventory posting. Refresh while working+tender restores a matching `in_flight`/`failed` `operation_id` from **persisted** settlement rather than minting a second attempt.
10. Refresh the workspace and resume the same working transaction (GET does not create another). Working + Cash tender restores completion-pending. No working transaction redirects to the enter gate — never to an inferred “latest” receipt.
11. See a completion receipt/confirmation from completed facts at `GET /pos/transactions/:id/completed`, then continue to a fresh `SALE_ENTRY` via the **New sale** control. Enter on the receipt is a no-op (scanner-safe). A lost complete response or complete retry against an already-completed transaction routes to **that** id's receipt.
12. Return to sale after a recoverable complete failure via `AbandonTender` (persisted tender is gone; GET workspace stays `SALE_ENTRY`).
13. Receive inline feedback for unknown identifier, unsupported merchandise, stale `lock_version`, unresolved tax, insufficient Cash, inventory failure on complete, and recoverable completion/network errors, with the working transaction preserved.
14. Be denied when a second cashier attempts to operate another cashier's Session.
15. Never mutate receipt, inventory, tax, or totals in controller or Stimulus code.

System tests (when the workspace is implemented) must cover at least: scan → focus restored → rescan increment; quantity mode; tender then complete; Escape; double Enter; insufficient Cash; refresh/re-entry; refresh with an existing tender restores completion-pending and the matching `operation_id`; completion retry without re-tender; complete succeeds / response lost / retry of that transaction's complete shows that receipt; GET workspace with no working transaction goes to enter; Return to sale clears the tender; cancel of a working sale with a Cash tender leaves no tenders on the cancelled row; empty-basket Cancel is disabled; cancel overlay ignores Enter and confirms on second F9; completed-receipt Enter does not start New sale; `pos_feedback` does not move the primary field.

---

## 11. Out of this contract

Close session UI, blind count, Z screens, receipt print, split tender, discounts, returns, suspend/recall, drawers, Terminal, new permissions, close/Z outbox, polished visual design, mobile POS, customer display.
