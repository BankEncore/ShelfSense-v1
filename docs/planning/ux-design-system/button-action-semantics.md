# ShelfSense Button and Action Semantics

**Status:** Accepted for UDS-1 implementation (`ActionButtonHelper` shipped in UDS-1b; broad view adoption is UDS-2)  
**Packet:** [UX design system](README.md)  
**Applies to:** Administrative screens, operational workspaces, the Register, dialogs, and other interactive ShelfSense interfaces

Visual brand colors come from [warm-parchment.md](warm-parchment.md) (or the currently implemented Phase 2.2 palette until UDS-1 ships). This document is independent of specific hex values: it defines wording, intent, style, size, and review behavior.

## Purpose

This document defines how ShelfSense names, presents, sizes, and implements buttons and actions. Its purpose is to make actions easy to scan, distinguish routine work from consequential changes, and keep similar controls consistent across administrative, purchasing, inventory, and point-of-sale workflows.

Button wording, visual treatment, and size communicate different things:

- **Wording** identifies what the action does in the current context.
- **Style and color** communicate emphasis, intent, and severity.
- **Size** reflects the interaction environment and frequency of use.
- **Placement and review behavior** communicate workflow order and consequence.

No single characteristic should carry the entire meaning of an action.

## Core principles

### Use concise, context-aware labels

Labels should be as short as the surrounding context safely permits. Page headings, selected records, dialog titles, and explanatory copy should carry context that does not need to be repeated in every button.

Prefer:

- `Save Changes`
- `Cancel Request`
- `Cancel Transaction`
- `Post Receipt`
- `Send PO`
- `Remove Line`
- `Post-Void`

Avoid generic commitment labels:

- `OK`
- `Yes`
- `Confirm`
- `Submit`
- `Process`

Avoid putting a complete consequence statement into an ordinary page button. Consequences belong in supporting text and, when required, a review dialog.

### Interpret labels in context

The same word may represent different interface concepts when context and presentation make the distinction clear.

For example:

- `Cancel` beside `Save Changes` abandons a form.
- `Cancel Request` changes a customer request's lifecycle state.
- `Cancel Transaction` abandons an active POS transaction.
- `Post-Void` corrects a completed POS transaction through a compensating fact.

ShelfSense does not infer severity from the verb alone. The view or domain-specific component must assign the action's semantic intent explicitly.

### Preserve domain distinctions

Use verbs that reflect the underlying business behavior:

| Verb | Meaning |
|---|---|
| `Back` or `Return` | Navigate to another screen without changing a business record. |
| `Close` | Dismiss an interface surface, or complete a domain workflow specifically defined as closing. |
| `Cancel` | Abandon editing in an obvious form context, or stop an active business process while preserving its history. |
| `Discard` | Throw away unsaved input or an explicitly disposable draft. |
| `Remove` | Take an uncommitted item out of a collection, basket, or draft. |
| `Deactivate` | Make configuration unavailable for future use without deleting it. |
| `Discontinue` | End future sellability or use under the applicable lifecycle contract. |
| `Reverse` | Compensate for a posted fact without rewriting history. |
| `Post-Void` | Reverse a completed POS transaction through the defined controlled correction workflow. |
| `Post` | Commit an operational document or fact through its authoritative posting boundary. |
| `Complete` | Finish the current business workflow when completion is the accepted domain term. |

Do not use `Delete` when ShelfSense actually deactivates, cancels, discontinues, removes an uncommitted line, or posts a compensating fact.

### Do not communicate meaning through color alone

Every important distinction must be supported by more than color. Use an appropriate combination of:

- Action wording
- Button style
- Placement
- Grouping
- Dialog title and explanatory copy
- Status or warning text
- Icons only when they add useful recognition

All styles require visible hover, active, disabled, and keyboard-focus states.

## Action intents

ShelfSense supports the following presentation intents. Intent is independent from wording and must be selected explicitly.

### Primary commit

The expected commitment for the current decision context.

Examples:

- `Create Supplier`
- `Save Changes`
- `Complete Sale`
- `Post Receipt`
- `Send Purchase Order`

Use one primary commit per decision context. A page may contain more than one primary button only when the buttons belong to clearly separate tasks or regions.

### Secondary action

An important alternative or supporting operation that should remain readily discoverable but should not compete with the expected commit.

Examples:

- `Edit`
- `Reprint`
- `Return Items`
- `Add Line`
- `Export`

### Navigation or escape

A low-emphasis action that leaves, dismisses, or resets the current interface state.

Examples:

- `Cancel` in a form footer
- `Close`
- `Back to Orders`
- `Clear Filters`
- `Continue Editing`

### Lifecycle or warning action

An action that changes future availability or stops an unfinished business process without correcting a completed fact.

Examples:

- `Cancel Request` (page-level trigger)
- `Cancel Quantity`
- `Deactivate Supplier`
- `Discontinue Variant`

### Destructive or corrective action

An action with immediate operational consequences, or one that compensates for a completed fact.

Examples:

- `Cancel Transaction`
- `Post-Void`
- `Reverse Receipt Line`

### Path-dependent severity (by stage)

Some labels appear at more than one stage. Assign intent by **stage**, not by scanning the verb:

| Stage | `Cancel Request` treatment |
|---|---|
| Page-level trigger | Warning **outline** (lifecycle). Opens review; does not dominate the page. |
| Review final action (release allocation and/or cancel unsent draft order) | Solid **danger** after the dialog explains consequences. |
| Review noncommitting action | Ghost (`Keep Request`). |

A review dialog may escalate the final action beyond the severity of its page-level trigger. Do not list the same bare label under two intent buckets without stating the stage.

## Visual styles

### Solid

Use a solid button for the expected commit within the current decision context.

Typical combinations:

- **Solid brand:** routine primary commit
- **Solid danger:** final destructive or corrective commitment inside a review dialog
- **Solid warning:** uncommon; use only when the warning-level action is genuinely the expected next step

Do not make a rare correction such as `Post-Void` a solid page-header action merely because it is available. Solid danger treatment is normally reserved for the final action after review.

### Outline

Use an outline button for meaningful secondary actions and page-level triggers for consequential workflows.

Typical combinations:

- **Neutral outline:** ordinary secondary action
- **Warning outline:** lifecycle-changing trigger
- **Danger outline:** destructive or corrective trigger

An outline danger button makes an action discoverable without giving it the same prominence as the screen's normal next step.

### Ghost

Use a ghost button for low-emphasis actions that still require a button-sized target and belong within an action group.

Examples:

- Form `Cancel`
- Dialog `Close`
- `Clear Filters`
- `Continue Editing`
- `Keep Request` in a cancellation review

Ghost buttons must remain recognizable as interactive controls without requiring hover. Do not remove their focus indicator or reduce their target size.

### Link style

Use link styling primarily for navigation and lightweight disclosure.

Examples:

- `Back to Purchase Orders`
- `View Supplier`
- `View Original Receipt`
- `Show Technical Details`

Use semantic HTML:

- Navigation should normally use an `<a>` element.
- A state-changing action should use a `<button>` or form submission, even if its appearance is intentionally understated.

Do not use link styling for destructive actions, primary commits, consequential operational commands, or actions that open a required review.

## Recommended style progression

Consequential actions should become more visually prominent only as the user approaches commitment.

For example:

```text
Customer request page:
[Edit]  [Cancel Request]
outline   warning outline

Cancellation review:
[Keep Request]  [Cancel Request]
    ghost          solid danger
```

The page-level trigger signals consequence without dominating the page. The review dialog explains the effect. The final action receives the strongest treatment.

## Button sizing

ShelfSense supports three standard sizes: **small**, **standard**, and **large**. Extra-small is not a general-purpose size.

Size reflects interaction environment, density, and frequency. It does not communicate severity or business importance.

| Size | Typical visual height | Use |
|---|---:|---|
| Small | 32–36px | Dense tables, compact toolbars, pagination, and repeated row actions |
| Standard | 40–44px | Forms, page headers, show pages, dialogs, and ordinary operational actions |
| Large | 48–56px | Register commands, tender actions, touch-oriented controls, and high-frequency operational actions |

### Standard

Standard is the application default. Use it for:

- Form action groups
- Page-header actions
- Show-page actions
- Review-dialog footers
- Empty-state actions
- Ordinary purchasing and inventory workflows

Buttons in the same decision group should normally share the same height.

### Small

Use small buttons only where controls repeat or space is structurally constrained.

Appropriate uses include:

- Table-row actions
- Compact data-grid toolbars
- Pagination
- Inline uncommitted-line actions
- Expanded line-detail utilities

Prefer a record's name as its primary row link rather than adding a dedicated `View` button to every row. Do not crowd many small actions into a row; move rare actions to the record page or an appropriate action menu.

A small page-level trigger may open a review dialog whose final actions use standard sizing.

### Large

Reserve large buttons for speed, distance, touch use, or high-frequency operation.

Appropriate uses include:

- Register command clusters
- Tender selection
- High-frequency cashier actions
- Touch-oriented receiving or location workflows
- Starting a Register session

Large does not mean more severe or more authoritative. An administrative `Save Supplier` button remains standard size even though it is the primary action.

### Extra-small

Do not define a general extra-small button. When space is constrained, prefer:

- A navigation link
- An explicit disclosure control
- An icon button with an accessible name and adequate hit target
- A noninteractive badge
- A small button with concise content

Visually compact controls must retain a usable interactive target.

## Placement and grouping

### Decision groups

Group actions that resolve the same decision. Actions in one group should normally share height and spacing.

Place the expected commit at the commit end of the group, normally the right side in ShelfSense's left-to-right layout:

```text
[Cancel]  [Save Changes]
 ghost       solid brand
```

Preserve logical DOM and tab order even when CSS controls visual alignment or wrapping.

### Separate rare or consequential actions

Do not place rare lifecycle or corrective actions so close to routine commits that accidental activation becomes likely. Use spacing, grouping, and style to separate them.

Example:

```text
[Edit]  [Reprint]        [Post-Void]
outline  outline          danger outline
```

A page does not require a solid brand button when it has no expected commit. Transaction detail may legitimately contain only secondary and consequential actions.

### Width

- Use content-width buttons for ordinary administrative actions.
- Use a reasonable shared minimum width in dialog footers when it improves balance.
- Use equal widths within Register command clusters.
- Use full-width buttons only in narrow layouts or intentionally constrained panels.
- Do not force unrelated administrative labels into equal widths.

## Review dialogs

Use a review dialog when an action is consequential, difficult to reverse, affects related records or inventory, or corrects a posted fact.

The dialog should provide:

1. A specific title identifying the action and record.
2. The material consequences in domain language.
3. Any relevant record identifiers, quantities, or linked workflows.
4. A clear noncommitting action.
5. A concise final action with severity-appropriate styling.

Example:

| Element | Wording |
|---|---|
| Trigger | `Cancel Request` |
| Dialog title | `Cancel customer request CR-000142?` |
| Explanation | The reserved copy will be released and become available for sale. |
| Noncommitting action | `Keep Request` |
| Final action | `Cancel Request` |

The final button does not need to repeat every consequence described in the dialog. Use longer final labels only when the user must choose between materially different effects, such as:

- `Keep as Stock Order`
- `Cancel Draft Order`

Never use `Yes`, `No`, or generic `Confirm` for consequential reviews.

## Common ShelfSense patterns

### Administrative form

```text
[Cancel]  [Save Changes]
 ghost       solid brand
 standard    standard
```

Bare `Cancel` is acceptable because the form context and pairing with `Save Changes` make its meaning clear.

### Show page with lifecycle action

```text
[Edit]  [Cancel Request]
outline   warning outline
standard  standard
```

### Purchase order ready to send

```text
[Edit]  [Cancel Draft Order]  [Send Purchase Order]
outline  danger outline           solid brand
standard standard                 standard
```

Use domain-accurate labels (`Cancel Draft Order`, cancel quantity / re-source on sent POs). Do not use a vague `Cancel Order` when the command is draft-line cancellation.

### Transaction detail

```text
[Reprint]  [Return Items]  [Post-Void]
 outline      outline       danger outline
 standard     standard      standard
```

No action is rendered as a solid brand button when none is the routine expected commit.

### Destructive review

```text
[Keep Transaction]  [Post-Void]
       ghost          solid danger
       standard       standard
```

### Dense table row

Prefer:

```text
PO-000142                         [Receive]
primary row link                 small outline
```

Avoid repeating `View`, `Edit`, `Cancel`, and `Receive` buttons on every row when the same actions can be presented more safely on the record page.

### Register command cluster

```text
[Cash F1]  [Card F2]  [Other Tender]
large       large      large
```

Register commands may use equal width for scanning and muscle memory. Existing keyboard commands, tab order relative to the documented cashier flow, and focus behavior remain authoritative. Visual regrouping of shortcut clusters must not change bindings unless a Register UX ADR says otherwise.

## Disabled and unavailable actions

Use a disabled button when showing the unavailable action helps the user understand the workflow or anticipate what becomes available next. Provide nearby explanatory text when the reason is not apparent.

Omit the action when:

- The user lacks permission and revealing it would be inappropriate.
- The action is irrelevant to the current record or state.
- Its presence would create misleading clutter.

Do not rely on a disabled button's tooltip as the only explanation. Disabled controls must remain visually distinguishable, and the interface must not communicate status solely through reduced opacity.

## Icons

Icons may reinforce recognition but should not replace text for domain actions unless space is genuinely constrained and the meaning is well established.

Icon-only buttons require:

- An accessible name
- A visible focus state
- A tooltip or other visible explanation when meaning may be unfamiliar
- A usable hit target independent of the icon's visual size

Do not use an icon to soften or obscure a destructive action.

## Implementation semantics

Visual variants express presentation intent; they do not encode domain behavior. UDS-1 should introduce `ActionButtonHelper` with four deliberately separate entry points:

```ruby
action_link_to(label, url, style:, intent:, size: :standard, disabled: false, **html_options)
action_button_to(label, url, style:, intent:, size: :standard, method:, form: {}, **html_options)
action_submit(form_builder, label, style:, intent:, size: :standard, **html_options)
action_button(label, style:, intent:, size: :standard, type: :button, **html_options)
```

The helper owns only validation of the presentation arguments and construction of the controlled class list. Each entry point delegates to the named Rails primitive rather than constructing HTML strings:

| Entry point | Rendering path | Required result |
|---|---|---|
| `action_link_to` | Rails `link_to` | An `<a href="…">` for navigation. It must not accept `method:` or turn a link into a state-changing request. |
| `action_button_to` | Rails `button_to` | A standalone form containing a submit `<button>`. `method:` is required and passed to `button_to`; Rails' authenticity-token and method-override behavior must be preserved. |
| `action_submit` | The supplied form builder's `button` | A submit button in an existing `form_with`/`form_for` form. It must not create a nested form or accept a URL or HTTP method. |
| `action_button` | Rails `button_tag` | A non-submitting `<button type="button">` by default, suitable for a dialog trigger, disclosure, printing, or another client-side interface action. |

`action_button(type: :submit)` is not a substitute for `action_submit`; reject it. The only accepted `type:` for `action_button` is `:button`. This makes an accidental submit inside a form impossible. A future reset-button need requires an explicit contract extension rather than a free-form type.

The four methods share these keyword values (symbols or their equivalent strings may be normalized):

| Keyword | Allowed values | Default |
|---|---|---|
| `style` | `solid`, `outline`, `ghost`, `link` | None; required |
| `intent` | `brand`, `neutral`, `warning`, `danger` | None; required |
| `size` | `small`, `standard`, `large` | `standard` |

Not every pair is valid. UDS-1 must encode this allowlist and raise `ArgumentError` for everything else:

| Style | Allowed intents |
|---|---|
| `solid` | `brand`, `warning`, `danger` |
| `outline` | `brand`, `neutral`, `warning`, `danger` |
| `ghost` | `neutral` |
| `link` | `neutral` |

All three sizes are valid for each allowed style/intent pair. Although a large link is valid for a deliberately touch-oriented navigation surface, it is not the ordinary admin choice. The helper must also reject unknown keywords where Ruby would not already do so, caller-supplied `class`, and attempts to smuggle any `btn` or `btn--*` token through another class-related option. It emits exactly `btn btn--STYLE btn--INTENT btn--SIZE`, while unrelated component classes should be placed on a wrapper. Views must not use the helper as an arbitrary class-composition escape hatch.

### What the API does not decide

Choosing one of these rendering paths is a decision made by the calling view; it is not inferred from a label, URL, route name, record state, or permission. Specifically, the helper does **not** decide or enforce:

- Authorization or whether the current actor may see or invoke the action
- Domain eligibility or whether the record's current lifecycle permits the action
- Whether review or confirmation is required
- The HTTP method, route, command/service, or business behavior
- Audit, optimistic-locking, idempotency, or transaction behavior

The controller and domain boundary remain authoritative even when a view omits or disables a control. The caller must supply an explicit `method:` to `action_button_to`; the helper does not guess `POST`, `PATCH`, or `DELETE`. It also must not inspect label text to infer warning or danger intent.

### Rails and HTML constraints

#### Forms, methods, and CSRF

- Use `action_button_to` for a state change that is not already inside a form. Do not replace `button_to` with a styled link: the generated form, authenticity token, and Rails method override must survive unchanged.
- Because `button_to` generates a form, never call `action_button_to` inside another form. Use `action_submit(form_builder, ...)` for the existing form's action. If one screen genuinely needs independent commands, place each command form outside the enclosing form and associate its submit button with that form's `id` using the HTML `form` attribute, or restructure the markup; do not emit invalid nested forms.
- `action_submit` passes `name`, `value`, `disabled`, `form`, `formaction`, `formmethod`, and other valid button attributes through to the builder unchanged. `formaction` or `formmethod` must be explicit in the view and must not bypass the route's authorization or review contract.
- `action_button_to` passes its `form:` hash to Rails unchanged, including form-level `data`, `class`, and authenticity-token options. The button's `data` belongs in `html_options`, not in `form:`. The helper must not manually create, suppress, copy, or cache CSRF tokens.

#### Disabled and unavailable controls

- Native buttons may use `disabled: true`; retain the real `disabled` attribute and, when supplied, `aria-describedby` pointing to visible explanatory copy.
- HTML has no disabled anchor. `action_link_to(disabled: true)` must render a non-focusable `<span>` with the controlled button classes, `aria-disabled="true"`, no `href`, and no click/keyboard binding. It may retain safe accessibility attributes such as `aria-describedby`, but must discard navigation-only `target`, `rel`, and `download` attributes. It must never render a live anchor with only `aria-disabled` or CSS/pointer-event suppression.
- Prefer omitting unavailable navigation when the destination is irrelevant or unauthorized. Use the disabled-span representation only when seeing a temporarily unavailable destination teaches the user the workflow. `aria-disabled` communicates state but does not enforce authorization and does not itself prevent activation.

#### Pass-through attributes and accessible names

- Preserve ordinary HTML attributes and nested Rails `data:` and `aria:` hashes without renaming, filtering, serializing, or merging their values, except for the controlled `class` rule and the disabled-link restrictions above. Rails remains responsible for converting keys such as `data: { action: "review-dialog#open" }` to attributes.
- A visible text `label` is the default accessible name. Icon-only content requires the caller to provide a nonblank `aria: { label: "…" }`; the helper must raise `ArgumentError` when it can identify icon-only/blank content without one. The helper does not invent an accessible name from a route or icon title.
- `action_button` must preserve Stimulus and Register bindings exactly, including `data-controller`, `data-action`, target, value, keyboard-command metadata, `id`, `name`, `value`, `aria-controls`, and `aria-expanded`. It must not parse, reorder, prefix, or replace binding strings. Adopting the helper must not change Register command dispatch, shortcut behavior, tab order, or focus restoration.
- Form association is caller-owned. Preserve an explicit button `form="form-id"` attribute unchanged; do not confuse it with `action_button_to`'s `form:` options hash.

#### Review and confirmation routing

The helper never adds `data-turbo-confirm`, browser `confirm()`, or a review dialog. A consequential page-level trigger must follow the interaction contract selected by its shell:

1. For a server-rendered review page, render the route to review with `action_link_to`; the final state change on that page uses `action_button_to` or `action_submit`.
2. For an already-established native dialog/Stimulus review, render its opener with `action_button` and pass the dialog's `data`/ARIA bindings unchanged; the final action is the dialog's existing form submit.

The trigger must not submit the state change directly when review is required. The final form must route to the existing authorized command/service and retain its required lock version, idempotency key, reason, or other domain fields.

### Controlled CSS output

The component classes are:

```text
btn
btn--solid
btn--outline
btn--ghost
btn--link

btn--brand
btn--neutral
btn--warning
btn--danger

btn--small
btn--standard
btn--large
```

Concepts that remain independent are:

- Label
- HTML behavior (`<a>` vs `<button>` / form)
- Visual style (solid / outline / ghost / link)
- Semantic intent (brand / neutral / warning / danger)
- Size
- Review requirement

### Legacy alias and deprecation sequence (UDS-1)

| Legacy shorthand | Compatibility meaning during migration | Final direction |
|---|---|---|
| `btn` alone | `btn--solid btn--brand btn--standard` | Migrate to the helper; a bare `btn` is no longer a complete variant. |
| `btn--secondary` | `btn--outline btn--neutral btn--standard` | Remove. It is not part of the new vocabulary. |
| `btn--danger` without a style class | Legacy solid-danger, standard-size appearance | Migrate each use by stage. The `btn--danger` token remains, but only as the canonical **intent** class and never as a complete variant. |
| `btn--ghost` without an intent or size | `btn--ghost btn--neutral btn--standard` | The token remains as the canonical **style** class, but shorthand use is removed. |

Use this sequence rather than changing every screen in one cutover:

1. **Alias release:** add the new matrix and narrowly scoped compatibility selectors for the shorthand forms above. Add the helper and its unit tests first. Do not change the meaning of existing templates in this release.
2. **Representative adoption release:** migrate one administrative form/show flow, one server-rendered or native-dialog review flow, and one Register command cluster. Classify every legacy danger use as outline trigger or solid final action; do not mechanically translate it. Add the selected view/integration tests below.
3. **Broad adoption releases:** migrate by bounded surface, keeping aliases while repository scans and visual review identify remaining shorthand. New or materially changed views use only the helper contract.
4. **Deprecation enforcement:** make CI fail on new `btn--secondary`, bare `btn`, style-less `btn--danger`, and incomplete `btn--ghost` usage outside the compatibility stylesheet and an explicit temporary allowlist.
5. **Alias removal:** after the scan and representative tests prove there are no callers, remove `btn--secondary` and the bare/default, danger-shorthand, and ghost-shorthand compatibility selectors. Retain `btn--danger` as an intent and `btn--ghost` as a style, always paired with an allowed counterpart and size.

Examples:

```erb
<%= action_link_to "Cancel", product_path(@product),
      style: :ghost, intent: :neutral %>

<%= action_button "Cancel Request",
      style: :outline, intent: :warning,
      data: { action: "review-dialog#open" },
      aria: { controls: "cancel-request-review", expanded: false } %>

<%# Page-level Post-Void is a danger outline trigger (see surface-contracts.md), not a solid final. %>
<%= action_button "Post-Void",
      style: :outline, intent: :danger,
      data: { action: "review-dialog#open" },
      aria: { controls: "post-void-review", expanded: false } %>

<%# Solid danger is the review dialog's final commit, via the existing form. %>
<%= action_submit f, "Post-Void",
      style: :solid, intent: :danger %>
```

Do not infer warning or danger intent by scanning label text for words such as `Cancel`, `Remove`, or `Reverse`.

### Tests required before broad adoption

Implement the following representative tests in the alias and representative-adoption releases; do not defer them until the repository-wide migration:

| Test | Representative assertions |
|---|---|
| `test/helpers/action_button_helper_test.rb` | Each entry point generates the expected `a`, standalone `form > button`, existing-form submit button, or `button[type=button]`; exact controlled classes appear once; every allowed style/intent/size value works; invalid values, invalid pairs, caller classes, missing `method:`, and submitting `action_button` raise `ArgumentError`. |
| `test/helpers/action_button_helper_test.rb` — Rails attributes | `action_button_to` retains the requested method override and authenticity-token behavior; button and form `data` land on the correct elements; a disabled navigation renders a `span[aria-disabled=true]` without `href`; native disabled buttons retain `disabled`; `aria-label`, `aria-describedby`, `form`, `name`, and `value` pass through unchanged. |
| `test/integration/tender_types_admin_test.rb` | Use Tender Type edit/show as the administrative reference: Cancel is an anchor with no non-GET method; Save is the existing form's submit; Deactivate/Reactivate are standalone CSRF-preserving forms with their explicit route methods; unavailable or unauthorized actions are omitted. |
| `test/integration/customer_requests_admin_test.rb` | Use customer-request cancellation as the review reference: the page-level `Review cancellation` button only opens the native dialog; the final cancellation is the state-changing form submit with solid-danger classes, explicit HTTP semantics, and required domain fields. No generated confirmation attribute bypasses review. |
| `test/integration/pos_register_test.rb` | Use the `Cash (F1)` command as the Register reference: it remains `button[type=button]`; its exact `data-action="register-workspace#chooseCash"`, `data-register-workspace-target="cashButton"`, disabled state, accessible name, and relative DOM order remain unchanged after helper adoption. |

Use parsed-element assertions (`assert_select` plus attribute assertions), not class-string-only snapshots. For `button_to`, assert the outer form action/method, hidden method override where applicable, authenticity-token presence under the test environment's configured behavior, and the inner button separately. Controller/service authorization and business-effect tests remain required and are not replaced by these rendering tests.

## Accessibility requirements

- Use semantic links for navigation and semantic buttons/forms for actions.
- Maintain visible keyboard focus for every style and color combination.
- Ensure text, border, hover, focus, and disabled states meet the adopted contrast requirements ([warm-parchment.md](warm-parchment.md): WCAG **AA** for ordinary interface text).
- Do not rely on color, fill, or position alone to communicate meaning.
- Preserve logical focus and DOM order.
- Ensure dialogs receive initial focus, contain focus while modal, support Escape where safe, and restore focus to the visible trigger.
- Maintain adequate interactive targets, including visually compact controls.
- Keep action labels understandable when read by assistive technology without relying solely on neighboring icons.

## Review checklist

When adding or changing an action, verify:

1. Does the label identify the action clearly in its current context?
2. Does the verb match the domain behavior—navigate, remove, cancel, deactivate, reverse, post, or complete?
3. Is the control semantically a link or a button?
4. Is its intent primary, secondary, navigation, warning, or danger?
5. Is its visual style appropriate for that intent and stage of commitment?
6. Is its size appropriate for the interaction environment rather than its severity?
7. Does it belong in this action group and position?
8. Does it require a review dialog?
9. Are the consequences explained outside the button label?
10. Is the action still understandable without color?
11. Are focus, target size, authorization, and disabled-state behavior correct?
12. Does the action preserve the authoritative domain service, audit, idempotency, and append-only contracts?

## Summary convention

> ShelfSense uses concise, context-aware action labels. Solid buttons commit the current decision; outline buttons expose meaningful alternatives and consequential triggers; ghost buttons provide escape or low-emphasis utilities; and links navigate or disclose. Brand, warning, and danger intent is assigned independently from wording. Standard is the default size, small is reserved for dense repeated controls, and large is reserved for Register, touch-oriented, and high-frequency operational actions. Consequential triggers escalate to a strong final treatment only after an explicit review. Meaning is never communicated through color, fill, size, or position alone.
