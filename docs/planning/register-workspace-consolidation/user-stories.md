# Register workspace consolidation — User stories

GitHub issues should usually be one focused PR. Slice 1 is this packet (no separate implementation issue required after merge).

Tracker: [milestone Register workspace consolidation](https://github.com/BankEncore/ShelfSense-v1/milestone/7) — [#83](https://github.com/BankEncore/ShelfSense-v1/issues/83) Slice 2, [#84](https://github.com/BankEncore/ShelfSense-v1/issues/84) Slice 3, [#85](https://github.com/BankEncore/ShelfSense-v1/issues/85) Slice 4, [#86](https://github.com/BankEncore/ShelfSense-v1/issues/86) 5A, [#87](https://github.com/BankEncore/ShelfSense-v1/issues/87) 5B, [#88](https://github.com/BankEncore/ShelfSense-v1/issues/88) 5C, [#89](https://github.com/BankEncore/ShelfSense-v1/issues/89) 5D, [#90](https://github.com/BankEncore/ShelfSense-v1/issues/90) 6A, [#91](https://github.com/BankEncore/ShelfSense-v1/issues/91) 6B, [#92](https://github.com/BankEncore/ShelfSense-v1/issues/92) 6C, [#93](https://github.com/BankEncore/ShelfSense-v1/issues/93) 7A (gated), [#94](https://github.com/BankEncore/ShelfSense-v1/issues/94) 7B (gated), [#95](https://github.com/BankEncore/ShelfSense-v1/issues/95) 7C (gated).

## Slice 2 — Shell and state routing

**Outcome:** `/pos` is state-aware Register entry. Generic POS Home is gone. Existing workspace is wrapped in the shared shell. Temporary destination cluster preserves eligible destinations. Shell containment keeps state bodies and the scan field reachable at workstation zoom.

**Acceptance:**

- [ ] `RegisterStateResolver` is pure (explicit inputs; presentation-neutral result)
- [ ] Routing table in [routing-and-authority.md](routing-and-authority.md) is covered by unit + request tests
- [ ] GET immutability: counts **and** record state
- [ ] Multiple unbound owned sessions → selector, never a false empty session
- [ ] Expected cash hidden without `cash.view_expected_before_count`
- [ ] Destination cluster matches the state/permission matrix; Reverse Cash not listed
- [ ] POST enter / occupied denial / leftover period unchanged
- [ ] Generic `pos/homes/show` removed
- [ ] Domain tests remain green
- [ ] Header business-date language is state-aware (no calculated date presented as established)
- [ ] Selector / enter / Switch Register content scrolls inside the shell at high zoom; last actions remain reachable
- [ ] Same-tab **Return to ShelfSense** with custody confirmation when a session is owned
- [ ] Authorized shell-containment interaction: command above basket, selected-row visibility, printable scan redirection, shell-wide Keyboard Lock reacquisition (no key remap)
- [ ] Automated system coverage for focused controls, dialog text entry, scanner punctuation, completion modes, shell-to-scan recovery, and lock API unavailability
- [ ] Manual verification evidence for screen-reader/form-control behavior, real browser navigation, high zoom, and workstation Keyboard Lock

**Exclusions:** F10, overlay family migration, new inquiry surfaces, key remapping (7C). Shell-containment composition above is in scope; Slice 4 still owns splitting `_surface`.

## Slice 3 — F10 and navigation

**Outcome:** F10 is Register Menu on every Register state. Destination cluster and duplicate nav are gone.

**Planning:** [slice3-f10-plan.md](slice3-f10-plan.md) (implementation-ready contract).

**Acceptance:**

- [ ] Explicit supersession of 6.7 §6 F10 row and §14 F10 history entry (docs updated in the same PR)
- [ ] Transactions remains reachable via menu; working basket preserved
- [ ] F10 suppressed while a blocking overlay is open
- [ ] Menu filtered by state and permission; wireframe items without routes deferred to 6A–6C
- [ ] Reverse Cash nav removed; reverse route/service remain
- [ ] Other 6.7 keys unchanged
- [ ] Destination cluster and duplicate Register nav deleted
- [ ] System tests retarget cluster clicks → menu; F10 opens menu not history
- [ ] Keyboard Lock: F1–F10 on workspace, F10 only on other Register surfaces

## Slice 4 — Transaction composition

**Outcome:** Workspace `_surface` split; presenter assembles authoritative values; 6.7 keys except F10.

**Exclusions:** Tender edit/replace, new selection model, stored-value capping, keyboard remap.

## Slice 5A — Lookup overlays

Product/variant/unit/customer/pickup. Shared lookup frame only as needed. Delete old targets in the same PR.

## Slice 5B — Return overlays

Chooser, linked, unlinked.

## Slice 5C — Controlled actions and confirmation

Price/discount/tax; confirmation frame.

## Slice 5D — Tender and issuance overlays

Do not design Slice 7 replacement into this frame.

## Slice 6A — Customer-service surfaces

Transactions & Receipts, detail, Stored Value Inquiry (three paths), Customer Summary, Pickup Queue.

## Slice 6B — Till and session detail

Till Activity, cash activity detail, Session Details, Active Sessions, reversal from original. Remove generic reversal UI if no other caller.

## Slice 6C — Reporting-period surfaces

**Complete** ([#92](https://github.com/BankEncore/ShelfSense-v1/issues/92) / PR [#109](https://github.com/BankEncore/ShelfSense-v1/pull/109)). Z status, blockers, live X, Session Details closed-session report, finalized Z, finalization confirmation, print chrome, and shift-end tape in shell — only inventory-permitted P13 rows.

## Slice 7.0 — Keyboard contract amendment

**Docs-only** ([#95](https://github.com/BankEncore/ShelfSense-v1/issues/95) / PR [#112](https://github.com/BankEncore/ShelfSense-v1/pull/112)). Accept SALE / TENDER / overlay / Escape / scanner / Lock tables and semantic vocabulary ([slice7-keyboard-contract.md](slice7-keyboard-contract.md)). Does not implement the dispatcher and **does not close [#93](https://github.com/BankEncore/ShelfSense-v1/issues/93)**. Clarifies plan.md decision 13 “first merge.” See [slice7-overview.md](slice7-overview.md).

## Slice 7A — Tender-review framework (gated)

Gated on 7.0 + tender lifecycle inventory. Tender Review mode, semantic selection, ordinary tender remove/replace, Return to Sale. No temporary global shortcuts. SV mutate deferred to 7B.

## Slice 7B — Stored-value, issuance, and Quick Customer

Gated on 7A. Nested customer-required SV lookup (7B.1), Quick Customer (7B.2), capping / working correction / completion revalidation / issuance edit (7B.3).

## Slice 7C — Keyboard dispatcher

Gated on 7A–7B. Implement [slice7-keyboard-contract.md](slice7-keyboard-contract.md): one dispatcher, scanner/overlay hardening, delete obsolete handlers, update pos-workflow.md §6 supersession.
