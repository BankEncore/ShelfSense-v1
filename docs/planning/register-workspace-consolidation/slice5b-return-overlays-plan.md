# Slice 5B — Return overlays

Status: **Accepted** on `register-workspace-consolidation` ([#87](https://github.com/BankEncore/ShelfSense-v1/issues/87) / PR [#100](https://github.com/BankEncore/ShelfSense-v1/pull/100)).

Authority: [plan.md](plan.md), [routing-and-authority.md](routing-and-authority.md), [textual-wireframes.md](textual-wireframes.md) O6–O8 / Part IV, [user-stories.md](user-stories.md), [slice5a-lookup-overlays-plan.md](slice5a-lookup-overlays-plan.md) (lifecycle), Phase 6.7 launch key (`−`) until 7C.

Issue: [#87](https://github.com/BankEncore/ShelfSense-v1/issues/87). Branch: `87-return-overlays`. PR target: `register-workspace-consolidation`.

## Outcome

Migrate **O6–O8 return overlays** onto the shared 5A blocking-overlay lifecycle: stack, inertness, focus restore, async invalidation, local status, and keyboard/pointer parity. Introduce an explicit linked stage machine with stage-aware Escape/Back, commit-open-during-submit failure contracts, full resolution-chain invocation generations, and eligibility/enablement parity. Keep 5C confirmation / O11 and 5D tender content out of scope.

## Scope

| In | Out |
|---|---|
| O6 chooser, O7 linked, O8 unlinked **content** on 5A lifecycle | 5C controlled-action / O9–O11 confirmation redesign |
| Chooser as **parent** of linked/unlinked (stack restore) | Nesting a new O11 approval overlay (keep inline approver fields) |
| Explicit `linkedStage`; stage-aware Escape/Back | 5D tender/issuance content |
| Pointer select + explicit confirm; eligibility/enablement | New return domain services / endpoints |
| Full async generation for linked + unlinked resolve chains | Slice 7 key remaps |
| Commit open-during-submit + failure preserve / password clear | History “Return items” chrome unless it already uses these overlays |
| Delete obsolete return-only targets/handlers in the same PR | Relocating overlays to a shell-level host |

Launch key remains Phase 6.7 (`−` / Return (−)). Endpoints stay.

## Locked contracts

### 1. Overlay stack transitions

```text
command → chooser → Escape → command
chooser → linked → Escape from lookup / Back to Return Options → chooser
chooser → unlinked → Escape / Back to Return Options → chooser
unlinked → product/variant/unit → Escape/Back → unlinked
```

Child close never skips an open parent. Closing chooser invalidates/closes linked/unlinked children and their resolve generations.

Reuse 5A APIs: `showOverlay` / `hideOverlay` / `topOverlay` / `restoreOverlayFocus`. Do not replace-open linked/unlinked after closing the chooser.

### 2. Linked stage machine (explicit)

```js
this.linkedStage = "lookup" // lookup | receipts | lines
```

Do **not** infer stage from list `data-*` contents.

| Stage | Primary | Secondary / Back |
|---|---|---|
| `lookup` | Find Receipt | Back to Return Options (→ chooser) |
| `receipts` | View Returnable Items | Back to lookup |
| `lines` | Add Return | Back to Receipts |

**Add Return** is shown/enabled only when a returnable line is selected and required return details are ready.

**Escape ladder** (same function as Back where they mean the same transition):

```text
linked lines    → Escape → receipt results
receipt results → Escape → receipt lookup
receipt lookup  → Escape → chooser
chooser         → Escape → command
```

Stage-aware Escape operates *inside* the linked overlay node. Overlay-stack LIFO still applies to real children (chooser → linked/unlinked → product/variant/unit).

### 3. Visual frames and control naming

| Surface | Title | Secondary | Primary |
|---|---|---|---|
| Chooser | Start return | Keep Sale Mode / Close Return | Continue |
| Linked `lookup` | Return from original receipt | Back to Return Options | Find Receipt |
| Linked `receipts` | Return from original receipt | Back (to lookup) | View Returnable Items |
| Linked `lines` | Return from original receipt | Back to Receipts | Add Return |
| Unlinked | Unlinked return | Keep Transaction Unchanged / Back to Return Options | Look Up Item → then Add Unlinked Return when ready |

Chooser options use explanatory copy (Find Original Receipt / Unlinked Return). **Keep Transaction Unchanged** is for final entry forms; intermediate stages use destination-explicit Back labels.

### 4. Commit and failure lifecycle

Return overlays **remain open** during submission:

- Do not close or pop the child before `requestSubmit()`
- Disable mutation controls while in flight; prevent double submission
- Successful Turbo workspace replacement clears the entire stack naturally
- Rejected validation restores the **same child and stage**
- Preserve identifier, receipt/line selection, quantity, reason, note, and price
- Always clear approver passwords after a failed attempt

### 5. Async invalidation — full resolution chains

One **invocation generation** per root return child:

```text
unlinked invocation
  ├── identifier resolve
  ├── product choice resolve
  ├── variant choice resolve
  └── unit choice resolve

linked invocation
  ├── receipt lookup
  └── receipt → lines request
```

A response may apply only when: controller connected; invocation generation matches; overlay remains in active stack ancestry; response matches current identifier/selection.

Closing unlinked (or its chooser parent) invalidates the entire unlinked chain. Same for linked. Query changes immediately invalidate prior results and selections (and for linked: clear receipt, lines stage, and entered line details).

### 6. Eligibility and action enablement

- Navigation skips disabled/ineligible rows
- Pointer clicks cannot select disabled rows
- Primary buttons stay **disabled** until an eligible selection / ready state exists
- Ineligible reasons remain readable but cannot become the active option
- **Add Unlinked Return** enabled only when: merchandise resolved, valid quantity/price, reason present, required note present, and required approval credentials present

### 7. Focus / inert / F10

Reuse 5A stack APIs. Workspace background inert with root return overlay; parent inert while child open; shell header/status inert; F10 suppressed. Nested picker Back calls `abortUnlinkedPicker` (same as Esc). O11 nesting is out — keep inline unlinked approver wrap.

## Implementation sequence

1. Packet — this document + manual stub; README / implementation-plan status.
2. Chooser-as-parent stack + O6 chrome.
3. Linked staged workflow (`linkedStage`, Escape ladder, async generations).
4. Unlinked workflow (full resolve-chain invalidation, nested-picker cleanup, enablement).
5. Submission failure/success lifecycle and sensitive-field clearing.
6. Pointer / disabled / action-enablement parity.
7. Tests + docs + PR; close #87 after merge.

## Tests (required)

- Full linked Escape ladder: lines → receipts → lookup → chooser → command
- Chooser Escape → command; child Escape from lookup → chooser
- Workspace/parent inert while return overlays open
- Pointer-only: Continue, Add Return, Add Unlinked Return
- Query edit invalidates; Enter re-searches; disabled rows not selectable
- Escape during fetch → reopen → late response ignored
- Nested picker Back clears `unlinkedPickerActive`
- Submission failure while nested: unlinked visible, chooser inert, non-secrets preserved, password cleared
- Success clears ancestry: no return overlay; new return line selected

No JS unit-test framework.

## Explicit non-goals

- O11 / 5C confirmation redesign
- Remapping `−` or other 6.7 keys
- New return financial/domain model
- Shell-level overlay host relocation
- Controlled price/discount/tax overlays (5C)
