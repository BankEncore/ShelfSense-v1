# Phase 5 Slice 2 — Register workspace contract

**Status:** Locked (interaction and HTTP/domain contract). Not yet implemented.

**Authority:** Cashier-facing online Register workspace: open gate, ephemeral UI modes, HTTP commands, focus/retry rules, and the Slice 2 vs Slice 3 receipt split. Domain completion, tax, inventory posting, and receipt identity remain in the [Phase 4 packet](../phase4-point-of-sale/). Cash/Z snapshots remain in [phase5-schema.md](phase5-schema.md).

Companions: [phase5-plan.md](phase5-plan.md), [receipt-identity.md](../phase4-point-of-sale/receipt-identity.md). Low-fidelity wireframes belong in `register-workspace-ux.md` (not in this change; write before Hotwire).

Where this document and [spec.md](../spec.md) §5.4–5.11 disagree, **prefer this document**.

**Governing UX principle:** where are the cashier's eyes, where is keyboard focus, and what will the next keystroke do?

---

## 1. Locked stack and testing

| Topic | Decision |
|---|---|
| Client | Rails-native online POS. No Terminal table (ADR-021). No scanner API; scanners are keyboard input ending in Enter |
| UI stack | Importmap + Turbo + Stimulus. Gems are in the Gemfile; they are **not installed** until the workspace implementation PR |
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
| `GET workspace` | no | Selling surface for an existing working transaction |

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

`StartTransaction` rejects if a working row exists while it holds the session lock.

Controllers must not `find || StartTransaction`. Use `Pos::ResumeOrStartTransaction`:

```text
lock Session
authorize actor
require actor == Session cashier
require Session and period open

if working transaction exists
  return it
else
  create through the same StartTransaction rules
end
```

**GET never creates transactions.** Refresh, prefetch, crawlers, and the back button must not mutate commercial state.

```text
GET workspace
  → render the existing working transaction
  → if it already has a Cash tender: restore completion-pending (do not create)
  → if none (including back from completion receipt): redirect to GET enter
  → do not create

POST enter / POST continue
  → ResumeOrStartTransaction
  → redirect to workspace
```

Two browser tabs: last writer wins via `lock_version`. The stale tab shows an error and reloads. Slice 2 does not sync tabs.

Empty working transactions created on enter/continue **block** `CloseSession` (existing Slice 1 gate). Do not auto-cancel on GET. Cashiers cancel in the workspace; Slice 3 may later auto-cancel empty leftovers.

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
  → read only
  → if the working transaction already has a Cash tender: restore completion-pending
    (show change; retry is POST complete only; do not treat as empty SALE_ENTRY)
  → if none (including back from completion receipt): redirect to GET enter
  → do not create

POST merchandise     → AddMerchandise; clear working tenders
POST quantity        → ChangeQuantity; clear working tenders
POST remove          → RemoveWorkingLine; clear working tenders
POST cancel          → CancelTransaction (after explicit confirmation)

POST tender
  → TenderCash
  → return change + new lock_version
  → do not complete

POST complete
  → CompleteTransaction
  → caller supplies a UUIDv7 operation_id generated at this completion attempt
  → stable operation_id and post-tender expected_lock_version
  → retries hit only this endpoint with the same payload
  → redirect to completion receipt

GET completed receipt
  → immutable completed facts only
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
POST complete (
    operation_id = A,
    expected_lock_version = v6,
    expected_total_cents from the tender response,
    amount_presented_cents from the tender response
  )
  → GET completion receipt
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

- The workspace generates a UUIDv7 at the **first** `POST complete` after a successful `TenderCash` (identifier at origin). Put it in the complete request; do not let the server silently mint a different id on retry.
- Reuse that id only for retries of that same post-tender payload (`expected_lock_version`, expected total, amount presented).
- Refresh after `TenderCash` but before a successful complete: restore completion-pending from the persisted tender. If Stimulus lost the in-memory id and no complete has succeeded, mint a **new** UUIDv7 for the next `POST complete` (a new attempt). Do not reuse an id whose payload would no longer match.
- Any new `TenderCash` (changed presented amount, or re-tender after returning to sale entry) mints a **new** `operation_id`.
- After `TenderCash` succeeds, do not `POST tender` again unless the cashier is changing the presented amount. That requires leaving completion-pending (explicit return to `SALE_ENTRY` after a recoverable complete failure, or Escape **before** `TenderCash` succeeded). Then a new `TenderCash` and a new `operation_id`.
- Stimulus sends `expected_total_cents` and `amount_presented_cents` from the **last tender response**, not a client-side recompute.
- Abandoned `in_flight` leases expire in 2 minutes (`PosOperation::LEASE_DURATION`). Do not reuse an old id after a new tender.

If completion fails recoverably: keep the working transaction **and** the tender; show a completion error; offer retry complete. Explicit return to `SALE_ENTRY` is allowed; the next merchandise mutation clears the tender. Changing Cash presented after a failed complete requires a new `TenderCash` and a new `operation_id`.

F9 / cancel is disabled while a `POST complete` is in flight. After a recoverable complete failure, cancel is allowed (`CancelTransaction`).

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
| completion pending (`TenderCash` succeeded, including GET workspace restore) | not a fourth named mode; input locked until complete response | do not silently return to `SALE_ENTRY` | retry is `POST complete` only; explicit return-to-sale control is allowed after a recoverable complete failure |

Keyboard map (shortcuts; each has a visible control):

| Key | Action |
|---|---|
| Enter | confirm current mode; **ignored** on the cancel overlay |
| Escape | back out where the table allows; on cancel overlay, abort confirm |
| `*` | `QUANTITY` (no-op if no selected line) |
| `+` | `TENDER` (no-op if no merchandise) |
| Delete | `RemoveWorkingLine` on the selected line in `SALE_ENTRY` |
| ArrowUp / ArrowDown | move selected line (in `SALE_ENTRY`) |
| F9 | open cancel confirmation (disabled while `POST complete` is in flight) |
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

**Basket mutation invalidates working tenders.** `AddMerchandise`, `ChangeQuantity`, and `RemoveWorkingLine` clear existing working tenders in the same database transaction. The cashier must re-enter `TENDER` after changing the basket.

Inventory shortage is a **completion** error (Phase 4 posts on complete, not on add-line). The scan path will not catch oversell.

Cancel: explicit confirmation overlay (see keyboard map). Escape / Don't cancel returns to the prior mode and focus. Scanner Enter must not confirm.

---

## 9. Slice 2 acceptance (contract)

A cashier can:

1. Enter the Register workspace only with an open reporting period and open Session belonging to them (open gate creates or resumes).
2. See the period's business date; cannot edit it.
3. Scan/type a sellable identifier and press Enter to add merchandise.
4. Continue scanning without manually restoring focus.
5. Scan the same compatible SKU again and increment the existing line.
6. Change quantity and remove a working line using keyboard-only interaction (visible controls also exist).
7. Cancel with explicit confirmation that scanner Enter cannot submit (second F9 confirms; Enter ignored).
8. Enter Cash presented; insufficient Cash stays in `TENDER`; valid settlement calls `TenderCash` then `CompleteTransaction` as two HTTP requests.
9. Retry completion without calling `TenderCash` again; one receipt and one inventory posting.
10. Refresh the workspace and resume the same working transaction (GET does not create another). If a Cash tender is already on the working transaction, restore completion-pending rather than empty `SALE_ENTRY`.
11. See a completion receipt/confirmation from completed facts, then continue to a fresh `SALE_ENTRY`.
12. Receive inline feedback for unknown identifier, unsupported merchandise, stale `lock_version`, unresolved tax, insufficient Cash, inventory failure on complete, and recoverable completion/network errors, with the working transaction preserved.
13. Be denied when a second cashier attempts to operate another cashier's Session.
14. Never mutate receipt, inventory, tax, or totals in controller or Stimulus code.

System tests (when the workspace is implemented) must cover at least: scan → focus restored → rescan increment; quantity mode; tender then complete; Escape; double Enter; insufficient Cash; refresh/re-entry; refresh with an existing tender restores completion-pending; completion retry without re-tender; cancel overlay ignores Enter and confirms on second F9.

---

## 10. Out of this contract

Close session UI, blind count, Z screens, receipt print, split tender, discounts, returns, suspend/recall, drawers, Terminal, new permissions, close/Z outbox, polished visual design, mobile POS, customer display.
