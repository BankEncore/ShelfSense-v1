# ShelfSense Button and Action Semantics

**Status:** Superseded as authority.

Canonical copy: [docs/planning/ux-design-system/button-action-semantics.md](../../planning/ux-design-system/button-action-semantics.md)

The text below is retained for history only.

---

# ShelfSense Button and Action Semantics (draft archive)

**Former status:** Proposed  
**Applies to:** Administrative screens, operational workspaces, the Register, dialogs, and other interactive ShelfSense interfaces

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

- `Cancel Request`
- `Cancel Quantity`
- `Deactivate Supplier`
- `Discontinue Variant`

### Destructive or corrective action

An action with immediate operational consequences, or one that compensates for a completed fact.

Examples:

- `Cancel Transaction`
- `Post-Void`
- `Reverse Receipt Line`
- `Cancel Request` when the selected path also cancels its unsent draft order

The exact severity can depend on the path selected. A review dialog may escalate the final action beyond the severity of its page-level trigger.

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
[Edit]  [Cancel Order]  [Send Purchase Order]
outline  danger outline     solid brand
standard standard           standard
```

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

Register commands may use equal width for scanning and muscle memory. Existing keyboard commands and focus behavior remain authoritative.

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

Visual variants should express intent rather than encode domain behavior. Suggested component classes are:

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

Examples:

```erb
<%= link_to "Cancel", product_path(@product),
      class: "btn btn--ghost btn--neutral btn--standard" %>

<button type="button"
        class="btn btn--outline btn--warning btn--standard">
  Cancel Request
</button>

<%= button_to "Post-Void", post_void_path(@transaction),
      class: "btn btn--solid btn--danger btn--standard" %>
```

The exact helper or partial API may consolidate these classes, but it must keep the following concepts independent:

- Label
- HTML behavior
- Visual style
- Semantic intent
- Size
- Review requirement

Do not infer warning or danger intent by scanning label text for words such as `Cancel`, `Remove`, or `Reverse`.

## Accessibility requirements

- Use semantic links for navigation and semantic buttons/forms for actions.
- Maintain visible keyboard focus for every style and color combination.
- Ensure text, border, hover, focus, and disabled states meet the adopted contrast requirements.
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
