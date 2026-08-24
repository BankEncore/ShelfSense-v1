# UX design system — accessibility and ergonomic test matrix

Status: **Proposed acceptance gate for UDS-2 and UDS-3**; foundation closeout uses the automated layer mapping below.

This matrix turns the foundation program's accessibility and timed cashier requirements into a repeatable gate. It applies to the five reference surfaces: **Supplier administration**, **Receiving** (the selected purchasing workspace), **transaction history and completed-transaction detail**, **consequential-action review dialogs**, and the **Register**. It supplements automated tests; it does not replace authorization, request, service, or system tests.

PR change allowlists, Chromium visual baselines, frozen suites, and token rollback live in the [implementation rollout contract](program-plan.md#implementation-rollout-contract)—complete those on every UDS PR; use this matrix for reference-surface **conforming** evidence and foundation criterion 10.

## Automated layer mapping (foundation closeout)

Foundation criterion 10 closes at **`verified-automated`**, not full manual conformance. See [uds-foundation-closeout-plan.md](uds-foundation-closeout-plan.md).

| Evidence ID | Closeout substitute | Deferred for `conforming` |
|---|---|---|
| `K` | Layer B — `assert_focus_sequence` / workflow suites | — |
| `SR` | Layer A axe (partial) | **SR-MANUAL** — screen reader |
| `D` | Layer B — `assert_dialog_contract` | — |
| `R` | Layer C — viewport/zoom smoke | Full screenshot review |
| `S` | Layer C — layout overflow smoke | Stress-fixture screenshots |
| `C` | Layer C — `assert_forced_colors_smoke` (one per surface) | Full forced-colors matrix |
| `T` | Layer C — target-size smoke | Full measurement audit |
| `I` | Layer B — keyboard/scanner paths in frozen suites | Touch emulation |
| `M` | Layer C — `assert_reduced_motion_smoke` | Full motion catalogue |
| `E` | Layer B — resilient-state in domain suites | Full state catalogue |
| Timed cashier | Layer B — PERF **correctness** only in CI | **PERF-HUMAN** — median timing |
| Independent review | — | **UX-INDEPENDENT** |
| Firefox | — | **Deferred** |
| Lighthouse | — | **Deferred** |

Unavailable evidence is recorded as **deferred**, not passed.

## Test setup, evidence, and ownership

Run the matrix in the project's supported headless-Chrome baseline and manually in current Chrome and Firefox. Use the browser/platform accessibility tree or a screen reader (NVDA with Firefox or VoiceOver with Safari/Chrome), keyboard only, a mouse, touch emulation or a touch device, and Windows forced-colors mode or browser emulation. Record browser, version, operating system, assistive technology, viewport, zoom, input device, test data, date, and commit SHA.

The defined narrow viewport is **320 × 568 CSS pixels**. Reflow checks use 200% and 400% browser zoom from the normal desktop viewport, plus an explicit 320 × 568 run at 100%. Content must remain available without two-dimensional page scrolling; a data table or other genuinely two-dimensional region may scroll horizontally inside its labelled container. The Register's supported workstation layout remains **1280 × 720** for its timed gate, but the Register must still expose every operation and message without clipping or loss at the zoom/reflow sizes.

Interactive targets are at least **24 × 24 CSS pixels**. Primary touch actions and standalone icon controls should be at least **44 × 44 CSS pixels**. A dense inline control may be smaller than 24 × 24 only when it is part of a text line or dense table, an equivalent control meeting the minimum exists on the same surface, or spacing prevents a 24 CSS-pixel-diameter circle centred on the target from intersecting another target. Each exception must be identified in the test record with its rationale; visual density alone is not an exception.

| Evidence ID | Expected evidence | Pass/fail owner |
|---|---|---|
| `K` | Short keyboard recording or ordered focus log showing all operations, visible focus, no trap, and the final restored-focus target | Implementing engineer; UX reviewer signs off |
| `SR` | Accessibility-tree capture plus screen-reader notes for names, headings, landmarks, tables, status announcements, errors, and dialogs | Accessibility reviewer |
| `D` | Dialog recording covering open, initial focus, Tab/Shift+Tab containment, safe Escape, submit, validation error, success, and restoration | Implementing engineer; accessibility reviewer signs off |
| `R` | Screenshots at 200%, 400%, and 320 × 568, including any locally scrolling table region | UX reviewer |
| `S` | Screenshots with 200% text-only resizing and stress fixtures (labels about 80 characters, identifiers about 64 characters, and signed monetary values through `$9,999,999,999.99`) | UX reviewer |
| `C` | Forced-colors/high-contrast screenshots and notes identifying how every selected, warning, error, disabled, success, and required state is recognized without color | Accessibility reviewer |
| `T` | Browser measurement of target bounding boxes and a list of every documented dense-inline exception | UX reviewer |
| `I` | Pointer/touch/keyboard/scanner equivalence checklist; mark an input method `N/A` only with a reason | Product owner for workflow equivalence; implementing engineer executes |
| `M` | Reduced-motion recording or computed-style capture showing transitions removed or reduced without hiding state changes | UX reviewer |
| `E` | State catalogue screenshots/recordings and, where applicable, request/system-test references for validation, empty, busy, denied, stale, and failure paths | QA owner; domain owner confirms semantics |

A surface passes only when all applicable evidence IDs are attached, there are no critical or serious accessibility defects, and every lesser defect has an owner and an agreed follow-up. The implementing engineer owns remediation. The accessibility reviewer owns accessibility pass/fail; the UX reviewer owns reflow, visual-state, target-size, and motion pass/fail; the relevant domain/product owner owns workflow correctness. The UDS program owner records the aggregate gate result.

## Supplier administration

1. **Keyboard and focus (`K`):** traverse index filters, pagination, New supplier, form fields, validation summary, show/edit actions, and activation controls in visual/DOM order. No hover-only action is allowed; focus remains visible against every surface.
2. **Screen reader (`SR`):** verify a unique page heading, navigation/main landmarks, names and descriptions for filters and controls, scoped supplier-table column headers, announced result counts/status changes, errors associated with fields and summarized, and meaningful active/inactive text that does not rely on its badge color.
3. **Dialogs (`D`):** for any deactivate/reactivate review, focus the dialog heading or least-destructive control on open, contain focus, let Escape close only before submission, preserve entered non-secret values on validation error, prevent duplicate submit while busy, and restore focus to the visible trigger or the updated row action.
4. **Zoom/reflow (`R`):** test index, no-results, show, and form at 200%, 400%, and 320 × 568. Filters and actions wrap without covering content; the supplier table may scroll only inside a labelled region.
5. **Text/data stress (`S`):** at 200% text size, use long translated-style field/action labels, an 80-character supplier name, 64-character supplier code/reference, long address/contact values, and the maximum displayed monetary amount. Text wraps or is disclosed accessibly; it never overlaps or silently truncates required meaning.
6. **Contrast/state (`C`):** in forced colors, identify focus, required fields, validation errors, active/inactive state, disabled actions, and selected filters through text, borders, native controls, or icons in addition to color.
7. **Targets (`T`):** measure pagination, row actions, checkboxes, disclosure controls, and form buttons against the 24 CSS-pixel minimum and 44 CSS-pixel preference; record any dense table exception and its equivalent action.
8. **Input equivalence (`I`):** create, find, inspect, edit, deactivate, and reactivate with pointer and keyboard; repeat primary actions with touch. Scanner is `N/A` unless a supplier-code capture field explicitly supports it.
9. **Motion (`M`):** with `prefers-reduced-motion: reduce`, remove or shorten any introduced flash, disclosure, or dialog transition while keeping completion and focus changes perceivable.
10. **States (`E`):** capture invalid form, empty/no-results, loading/busy submit, permission denied by direct access, stale `lock_version`, and server failure. Preserve user input where safe, announce the error, prevent duplicate effect, and offer a recovery path.

## Receiving workspace (selected purchasing reference)

1. **Keyboard and focus (`K`):** operate order/shipment selection, line navigation, quantity entry, exception resolution, save/receive actions, and any disclosures without a pointer. Focus order follows the visible work sequence and remains visible within a scrolled dense grid.
2. **Screen reader (`SR`):** verify workspace and section headings, main/navigation landmarks, an accessible name for the receiving grid, row and column headers for each editable cell, names including line context, announced recalculated totals and receive status, linked error text, and dialog context.
3. **Dialogs (`D`):** review/consequence dialogs focus their heading or safest first control, trap Tab, close safely with Escape only before commit, retain valid quantities/notes after errors, expose busy submission, and restore focus to the originating line or action. A scan suffix Enter must not confirm a consequential dialog.
4. **Zoom/reflow (`R`):** test populated, empty, and exception-heavy workspace states at 200%, 400%, and 320 × 568. Controls remain operable; the dense grid may use a labelled local horizontal scroller, with frozen/sticky content not obscuring focused cells.
5. **Text/data stress (`S`):** at 200% text size, use long supplier/product/location labels, 64-character ISBN/SKU/shipment identifiers, large quantities, and `$9,999,999,999.99` totals. Headers, inline errors, and totals remain attributable to their rows.
6. **Contrast/state (`C`):** forced colors must distinguish selected row/cell, matched/unmatched/over-received lines, warnings, errors, disabled actions, and completion using text or symbols as well as color.
7. **Targets (`T`):** measure quantity steppers, row disclosures, exception actions, checkboxes, and submit controls. Document dense-cell exceptions and provide a same-surface 24 CSS-pixel equivalent; touch-critical receive/review actions target 44 × 44.
8. **Input equivalence (`I`):** select a shipment, scan/type an identifier, correct quantity, resolve an exception, review, and submit using keyboard/scanner; verify pointer and touch equivalents. Scanner input must use the same validation and must never bypass review or authorization.
9. **Motion (`M`):** row insertion, highlight, status, and dialog transitions respect reduced motion; a stable text/status indication replaces motion as the only completion cue.
10. **States (`E`):** capture invalid/over-limit quantity, empty shipment, lookup/loading and submit-busy, permission denial, stale purchase order or receipt, and server failure. Announce the affected line and recovery action, retain safe draft input, and prevent duplicate receipt effects.

## Transaction history and completed-transaction detail

1. **Keyboard and focus (`K`):** navigate filters, pagination, transaction links, disclosures, reprint, return/post-void eligibility actions, and back-to-Register without row-click dependence. Focus order follows the visual reading order and focus returns after closed reviews.
2. **Screen reader (`SR`):** verify unique headings, navigation/main landmarks, named filters, transaction-table headers, line-detail headings/definition terms, historical status and totals read with their labels, result/status announcements, linked errors, and review-dialog context.
3. **Dialogs (`D`):** reprint or consequential reviews use safe initial focus and modal containment; Escape never dismisses after a committed request; validation/server errors remain in context; successful close returns focus to the initiating transaction action or a logical fallback if it disappeared.
4. **Zoom/reflow (`R`):** test history, no-results, completed sale, return, mixed basket, and post-void detail at 200%, 400%, and 320 × 568. Tables may scroll locally; receipt totals and action eligibility must not be clipped.
5. **Text/data stress (`S`):** at 200% text size, use long cashier/register/snapshot descriptions, 64-character technical and receipt identifiers, many line details, and large signed Sales/Returns/Net/Tender values. Preserve the association between amounts and labels.
6. **Contrast/state (`C`):** forced colors must expose selected filters, transaction direction, completed/cancelled/post-voided status, eligibility, warnings, links, and focus without color-only badges or sign styling.
7. **Targets (`T`):** measure filter clears, pagination, line-detail disclosures, transaction links, reprint, return, and post-void actions; document any inline-link exception and ensure an equivalent target when required.
8. **Input equivalence (`I`):** find and open a transaction, disclose lines, reprint, and enter an eligible controlled flow with pointer, touch, and keyboard. Verify receipt-barcode scanner lookup where supported; scanning and typed lookup produce the same exact-transaction result.
9. **Motion (`M`):** disclosure, filter-result, and dialog transitions respect reduced motion and do not move focus or scroll unexpectedly.
10. **States (`E`):** capture invalid filters/reference, empty results, loading/busy reprint or action, direct permission denial, eligibility changed/stale transaction, and server failure. Historical snapshots remain readable and errors identify whether retry is safe.

## Consequential-action review dialogs

1. **Keyboard and focus (`K`):** reach the trigger and every dialog field/action by keyboard, in a visible order that puts review content before commitment; destructive confirmation is never the accidental first tab stop.
2. **Screen reader (`SR`):** verify the dialog role, accessible name from its visible heading, description of subject/consequence, labelled reason/credential fields, error association and announcement, busy/status announcement, and background exclusion from the accessibility tree while modal.
3. **Dialogs (`D`):** record every review type opening, cycling in both directions, safe Escape, submit, error, and success. Initial focus goes to the heading, first required field, or least-destructive action as specified; focus cannot leave the modal; Escape is disabled once submission cannot safely be abandoned; errors keep context and clear secrets; close restores the visible trigger or documented fallback.
4. **Zoom/reflow (`R`):** at 200%, 400%, and 320 × 568, heading, consequence, errors, fields, and actions remain reachable. The dialog body may scroll vertically while heading/action context remains understandable; there is no page-level two-dimensional scroll.
5. **Text/data stress (`S`):** at 200% text size, use long translated-style buttons, consequence copy, actor/subject labels, 64-character identifiers, and large monetary impacts. Buttons wrap rather than clip and similarly named actions remain distinguishable.
6. **Contrast/state (`C`):** forced colors must distinguish modal boundary, backdrop separation, focus, destructive/least-destructive actions, required/error state, disabled/busy state, and outcome without color alone.
7. **Targets (`T`):** all dialog controls meet 24 × 24 CSS pixels; primary touch actions and close/icon buttons should meet 44 × 44. Dense-inline exceptions are normally inappropriate in a modal and require explicit UX and accessibility approval.
8. **Input equivalence (`I`):** open, review, correct, submit, and safely cancel using pointer, touch, and keyboard. Scanner keystrokes must not activate cancellation or approval; where a dialog intentionally accepts scanned identifiers, typed and scanned input follow identical resolution and confirmation rules.
9. **Motion (`M`):** opening, closing, backdrop, and error transitions respect reduced motion; focus placement and textual status, not animation, convey the state change.
10. **States (`E`):** capture missing/invalid reason, empty review data where possible, loading/busy, permission/approval denial, stale subject, and server failure. Prevent double submit, state whether retry is safe, preserve non-secret values, clear credentials, and never leave an apparently active modal over invalid background state.

## Register

1. **Keyboard and focus (`K`):** complete the scenarios below without a pointer. Verify the visible focus sequence through scan, basket/actions, modes, pickers, tenders, receipt/history, and overlays; ordinary success and recoverable error restore scan focus, while completion failure focuses Retry complete as specified.
2. **Screen reader (`SR`):** verify workspace/mode headings and main landmark, labelled scan and mode-specific fields, basket table headers and selected-line state, totals with direction, named shortcut controls, polite scan/status announcements, assertive blocking errors without duplicate speech, field-error links, and complete picker/review dialog context.
3. **Dialogs (`D`):** search/picker/action dialogs focus their field or highlighted option, cancel confirmation focuses the safest non-activating target, Tab is contained, and Escape returns to the prior mode and scan focus where safe. Scanner Enter resolves only in scanner-sensitive fields and never confirms cancellation; submit errors preserve safe values, clear secrets, and restore the contractually correct target.
4. **Zoom/reflow (`R`):** test sale entry, populated basket, tender, completion failure, receipt, history, and every overlay at 200%, 400%, and 320 × 568. All commands, totals, messages, and recovery actions remain available without overlap; locally scroll the basket when necessary. Separately run timed tests at 1280 × 720 and 100% zoom.
5. **Text/data stress (`S`):** at 200% text size, use long translated shortcut/action labels, long product/tender/register names, 64-character identifiers, a large basket, and large positive/negative monetary totals. The selected line, amount direction, shortcut, and next action remain unambiguous.
6. **Contrast/state (`C`):** forced colors must distinguish focus, selected basket/picker row, sale versus return, enabled/disabled shortcuts, warning/error/success, completion pending, and modal boundaries through text, borders, symbols, or native state—not color alone.
7. **Targets (`T`):** measure all visible shortcut equivalents, basket selection/actions, tender buttons, picker rows, and overlay controls. Standalone cashier/touch actions should be 44 × 44 CSS pixels; any dense basket control below 24 × 24 needs a documented same-surface equivalent.
8. **Input equivalence (`I`):** compare pointer, touch, keyboard, and keyboard-wedge scanner paths for lookup/add, selection, correction, tender, cancel, and recovery. Shortcuts always have visible focusable controls; scanning cannot bypass a picker, review, authorization, or error state and cannot leak into a closed/obsolete overlay field.
9. **Motion (`M`):** basket updates, selection, feedback, overlay, and completion transitions respect reduced motion. No animation delays the next scan, steals focus, or acts as the only indication of success/failure.
10. **States (`E`):** capture invalid/unknown scan, empty basket/search/picker/history, lookup and completion busy, permission/manager denial, stale `lock_version`, recoverable completion failure, lost-response recovery, and non-retryable server failure. Announcements, focus, retained tender/basket state, idempotent retry, and safe exit must match the Register contracts.

## Timed cashier workflow gate

Use a seeded Register at **1280 × 720**, 100% zoom, with a warmed browser, known test identifiers, and no network throttling. Run once with keyboard plus keyboard-wedge scanner and once with keyboard only; pointer/touch equivalence is checked in `I` but is not timed. Timing begins on the ready sale-entry scan field and ends when the stated stable state is visible and announced. Record raw time, retries, unexpected focus changes, errors, and the resulting transaction/reference. Each scenario gets one untimed familiarization run followed by three measured runs; the **median** must meet the limit, all three runs must preserve correctness, and no run may require a pointer, reload, or focus repair.

| Scenario | Representative steps | Success criteria |
|---|---|---|
| Scan | Scan three unique directly sellable identifiers, including a repeat of one identifier | **≤ 12 seconds** median; three scan suffixes add/merge the correct lines and quantities; each result is visibly and audibly acknowledged; focus is ready for the next scan; no duplicate request/effect |
| Correction | Scan two items, select the first line, change its quantity, remove the other line, then return to sale entry | **≤ 20 seconds** median; correction applies only to the selected line; totals update and are announced; no tender survives a basket mutation; scan focus is restored |
| Tender | From a seeded two-line basket, open Cash with the remaining amount prefilled, enter presented Cash, complete, and reach the immutable receipt | **≤ 20 seconds** median; exactly one completion and receipt result; applied/change totals are correct and announced; double Enter cannot duplicate tender/completion; receipt actions are keyboard reachable |
| Cancellation | From a populated working basket, open cancel review, prove scanner text plus Enter cannot confirm it, Escape back to the unchanged sale, reopen, and confirm with the defined cancellation command | **≤ 25 seconds** median; first review leaves the basket unchanged and restores scan focus; only the explicit confirmation cancels; a fresh empty working sale is ready; no scanned characters leak into a field |
| Overlay recovery | Open merchandise search, move through results, Escape and verify scan focus; then trigger a validation error in a consequential overlay, correct it, submit, and return to the appropriate Register mode | **≤ 30 seconds** median; focus is contained while each overlay is open; Escape is safe; error is visible and announced in context; safe values persist; secrets clear if present; success closes the overlay and restores the documented focus target |

Any wrong commercial effect, duplicate effect, unsafe cancellation, lost basket/tender, keyboard trap, unannounced blocking error, or scanner input reaching an obsolete target is an automatic failure regardless of elapsed time. Timing thresholds are regression gates for the seeded reference tasks, not productivity quotas for employees; changes to the fixtures or thresholds require the UDS program owner and POS product owner to document the reason.
