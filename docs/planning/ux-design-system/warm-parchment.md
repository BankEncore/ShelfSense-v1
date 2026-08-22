# Warm Parchment visual system

Status: **Proposed candidate, contrast-complete for ADR-022 review**

Authority for visual tokens and density. Action wording/style/size: [button-action-semantics.md](button-action-semantics.md). Shell boundaries: [README.md](README.md). Palette supersession: [ADR-022](../../adr/ADR-022-warm-parchment-visual-tokens.md).

Inspirational mockups: [`docs/drafts/phase-7.1-ux-refactor/`](../../drafts/phase-7.1-ux-refactor/) (not binding). Contrast-complete palette demo: [warm-parchment-palette-mockup.html](warm-parchment-palette-mockup.html).

## Intent and acceptance baseline

Balance bookstore literary warmth with back-office data density. Restrict pure white (`#FFFFFF`) to elevated surfaces (cards, inputs, table bodies, and dialogs) so the canvas stays low-glare linen. Prefer hairline warm borders over heavy drop shadows.

The candidate below replaces every brand and hover placeholder with an exact value. It targets WCAG 2.2 AA: 4.5:1 for ordinary text, 3:1 for large text, and 3:1 for meaningful control boundaries and focus indicators against adjacent colors. Disabled controls are exempt from WCAG contrast requirements, but these candidates still meet 4.5:1 text and 3:1 boundary contrast. State changes also use shape, border, underline, text, or position; color is never the only cue.

Ratios are rounded to two decimal places from unrounded sRGB relative-luminance calculations. Recalculate them if either member of a pair changes. Do **not** claim blanket AAA for the palette.

## Foundation and brand tokens

| Token | Hex | Role |
|---|---|---|
| `--color-bg-canvas` | `#FBF9F5` | Main application canvas (warm linen) |
| `--color-bg-surface` | `#FFFFFF` | Cards, inputs, table bodies, dialog containers |
| `--color-bg-surface-elevated` | `#F4F0EA` | Layered containers and dialog headers/footers |
| `--color-bg-subtle` | `#EFECE6` | Table headers, sticky bars, subtle dividers |
| `--color-bg-drawer` | `#F0EAE1` | Expanded line details; not a global shell mandate |
| `--color-text-primary` | `#2C2523` | Body text and primary table data |
| `--color-text-secondary` | `#6E6763` | Timestamps, ISBNs, secondary labels |
| `--color-text-inverse` | `#FFFFFF` | Labels on the solid fills specified below |
| `--color-border-subtle` | `#E6DFD5` | Decorative gridlines and card separation; not sufficient alone as a control boundary |
| `--color-border-strong` | `#8B8178` | Input, button, dialog, and panel boundaries |
| `--color-brand-default` | `#A84320` | Primary commit fill, unvisited link, selected-row accent |
| `--color-brand-hover` | `#8F3518` | Hovered primary commit fill |
| `--color-brand-active` | `#752A13` | Pressed primary commit fill |
| `--color-brand-soft` | `#F9ECE7` | Selected navigation and soft brand emphasis |
| `--color-brand-soft-hover` | `#F3DDD4` | Hover layered over soft brand treatment |
| `--color-focus-ring` | `#7C3218` | Universal keyboard focus ring; 2px minimum plus 2px offset |

`#C85A32` is not a solid-action candidate: white text on it is only about 4.23:1. The exact default is `#A84320`, which gives 6.02:1.

## Semantic token families

Every family has a foreground for text/icons, a 3:1-capable boundary, quiet fills and hover fills, plus solid button default/hover/active states. Use solid warning only when warning is the expected next step; use solid danger principally for the final commitment after review. Badges and flashes retain a visible label or icon in addition to color.

| Family | Foreground | Border | Fill | Quiet hover | Solid | Solid hover | Solid active |
|---|---|---|---|---|---|---|---|
| Neutral | `--color-neutral-fg` `#2C2523` | `--color-neutral-border` `#8B8178` | `--color-neutral-fill` `#F4F0EA` | `--color-neutral-fill-hover` `#E8E1D8` | `--color-neutral-solid` `#514944` | `--color-neutral-solid-hover` `#403936` | `--color-neutral-solid-active` `#332D2B` |
| Warning | `--color-warning-fg` `#6E4D00` | `--color-warning-border` `#9A6C00` | `--color-warning-fill` `#FAF3E5` | `--color-warning-fill-hover` `#F3E5C6` | `--color-warning-solid` `#765300` | `--color-warning-solid-hover` `#624500` | `--color-warning-solid-active` `#503800` |
| Danger | `--color-danger-fg` `#7A2018` | `--color-danger-border` `#A53A2E` | `--color-danger-fill` `#F9EBEA` | `--color-danger-fill-hover` `#F1D5D1` | `--color-danger-solid` `#9B2C23` | `--color-danger-solid-hover` `#812219` | `--color-danger-solid-active` `#681A13` |
| Information | `--color-info-fg` `#1D435E` | `--color-info-border` `#39708F` | `--color-info-fill` `#EBF1F5` | `--color-info-fill-hover` `#D8E7F0` | `--color-info-solid` `#245B78` | `--color-info-solid-hover` `#1B4A65` | `--color-info-solid-active` `#153B51` |
| Success | `--color-success-fg` `#2D4731` | `--color-success-border` `#527A58` | `--color-success-fill` `#EAF0EB` | `--color-success-fill-hover` `#D8E6DA` | `--color-success-solid` `#37603D` | `--color-success-solid-hover` `#2C5032` | `--color-success-solid-active` `#234128` |

### Disabled and validation tokens

| Token | Hex | Use |
|---|---|---|
| `--color-disabled-text` | `#6E6763` | Disabled label/value; retain normal font weight |
| `--color-disabled-border` | `#8F8882` | Disabled control boundary |
| `--color-disabled-surface` | `#F1EEEA` | Disabled input/button surface; pair with `disabled` semantics and `not-allowed` cursor where applicable |
| `--color-field-invalid-text` | `#7A2018` | Field error and validation-summary text |
| `--color-field-invalid-border` | `#A53A2E` | Invalid input boundary; use with error text/icon and `aria-invalid` |
| `--color-field-invalid-fill` | `#F9EBEA` | Optional error-summary/invalid-field tint |
| `--color-field-invalid-ring` | `#7C3218` | Focus ring on an invalid field; ring remains visible outside the invalid border |

Placeholder text is not a substitute for a label. When used, it uses `--color-text-secondary`, not a low-contrast tertiary token.

### Dialog, link, and collection-state tokens

| Token | Value | Use |
|---|---|---|
| `--color-overlay-scrim` | `rgb(23 19 17 / 60%)` | Common dialog/POS backdrop; contains no foreground content |
| `--color-dialog-surface` | `#FFFFFF` | Opaque elevated dialog body |
| `--color-dialog-elevated-boundary` | `#8B8178` | 2px dialog boundary against white and linen |
| `--color-link` / `--color-link-hover` / `--color-link-active` | `#A84320` / `#8F3518` / `#752A13` | Underlined navigation states; hover also thickens underline |
| `--color-link-visited` | `#6D3A63` | Visited content/history links where knowing visitation is useful; do not apply to command/navigation chrome |
| `--color-table-row-hover` | `#F0EAE1` | Pointer hover; cursor/action affordance also changes where actionable |
| `--color-table-row-selected` | `#EBE3D5` | Selected row plus 3px `--color-brand-default` leading accent and selection semantics |
| `--color-table-row-focus` | `#F7F1E8` | Keyboard-focused row plus inset 2px `--color-focus-ring` outline |

Do not render controls directly on the scrim. Dialogs and POS overlays always use the opaque dialog surface and elevated boundary. Sidebar/topbar espresso candidates (`#231F1D`, `#36302E`) remain deferred with global shell chrome in [deferred-patterns.md](deferred-patterns.md).

## Contrast ledger

This ledger enumerates every foreground/background pairing intended by these tokens. A token is not permission to create an unlisted pair. Decorative subtle borders and the scrim are not foreground content; meaningful boundaries use the strong or semantic borders audited below.

### Foundation, brand, links, fields, and rows

| Foreground / boundary | Background | Ratio | Intended use and result |
|---|---|---:|---|
| Primary `#2C2523` | canvas `#FBF9F5` / white `#FFFFFF` / subtle `#EFECE6` | 14.31 / 15.04 / 12.76 | Body/table/header text: AA |
| Secondary `#6E6763` | canvas / white / elevated `#F4F0EA` / subtle | 5.28 / 5.55 / 4.89 / 4.71 | Secondary and placeholder text: AA |
| Brand/link `#A84320` | canvas / white / brand soft / soft hover | 5.72 / 6.02 / 5.21 / 4.62 | Links and soft-brand text: AA |
| Inverse `#FFFFFF` | brand default / hover / active | 6.02 / 7.81 / 10.01 | Solid primary labels: AA |
| Visited `#6D3A63` | canvas / white | 8.20 / 8.62 | Visited link text: AA |
| Strong boundary `#8B8178` | canvas / white / elevated | 3.63 / 3.81 / 3.36 | Controls/dialog boundaries: non-text AA |
| Disabled text `#6E6763` | disabled surface `#F1EEEA` | 4.80 | Disabled label: AA despite exemption |
| Disabled border `#8F8882` | disabled surface | 3.02 | Disabled boundary: non-text AA despite exemption |
| Invalid text `#7A2018` | white / invalid fill | 10.26 / 8.84 | Validation message and field value: AA |
| Invalid border `#A53A2E` | white / invalid fill | 6.47 / 5.58 | Invalid boundary: non-text AA |
| Primary `#2C2523` | row hover / selected / focus | 12.58 / 11.81 / 13.40 | Row contents: AA |
| Focus ring `#7C3218` | white / canvas / row hover / selected | 9.03 / 8.58 / 7.55 / 7.08 | Focus indicator: exceeds 3:1 |

### Semantic families

Each row reports: foreground on quiet fill / quiet-hover fill; border on quiet fill; white inverse text on solid / solid-hover / solid-active.

| Family | Foreground ratios | Boundary ratio | Solid-label ratios | Result |
|---|---:|---:|---:|---|
| Neutral | 13.25 / 11.60 (15.04 on white) | 3.36 (3.81 on white) | 8.80 / 11.31 / 13.54 | Text and non-text AA |
| Warning | 6.98 / 6.18 (7.71 on white) | 4.21 (4.65 on white) | 6.98 / 8.86 / 11.01 | Text and non-text AA |
| Danger | 8.84 / 7.41 (10.26 on white) | 5.58 (6.47 on white) | 7.56 / 9.65 / 12.03 | Text and non-text AA |
| Information | 9.14 / 8.24 (10.41 on white) | 4.74 (5.40 on white) | 7.39 / 9.48 / 11.82 | Text and non-text AA |
| Success | 8.83 / 7.90 (10.21 on white) | 4.24 (4.90 on white) | 7.23 / 9.13 / 11.30 | Text and non-text AA |

## Component-state matrix

`focus-visible` is additive: it does not replace hover, selected, invalid, or semantic treatment. Native disabled semantics, `aria-invalid`, `aria-current`, `aria-selected`, status text, and dialog roles carry programmatic meaning.

| Component | Default | Hover / active | Keyboard focus | Disabled / invalid / selected | Checks |
|---|---|---|---|---|---|
| Solid buttons | White label on family solid; one primary commit per context | Exact family solid-hover/solid-active fills; pressed position may shift 1px | 2px focus ring, 2px offset outside button | Disabled text/border/surface and native `disabled`; no opacity multiplication | All label pairs ≥6.02; focus ≥3:1; fill and motion distinguish hover/active |
| Outline/ghost buttons | Family foreground and 2px family border on surface; ghost still has a visible strong boundary | Quiet-hover fill; active uses quiet fill plus inset boundary | Common focus ring outside existing boundary | Disabled triplet plus native semantics | Foreground ≥4.62; meaningful boundaries ≥3.02; border/fill/position distinguish states |
| Links | Underlined link color; visited color only for visitation-useful content | Hover darkens and thickens underline; active darkens again | Common ring with offset; underline remains | `aria-current` plus font weight/soft fill for current navigation | All text ≥4.62; underline and color distinguish states |
| Inputs/selects/textareas | Primary text on white, 2px strong boundary; secondary placeholder | Hover may use elevated surface while retaining boundary | Common ring outside boundary | Disabled triplet; invalid border + message/icon + `aria-invalid`; invalid focus keeps border and ring | Text ≥4.80; boundaries ≥3.02; invalid is not color-only |
| Badges | Semantic foreground on quiet fill with 1px semantic border and explicit text/icon | If interactive, quiet-hover plus underline/cursor; otherwise no invented hover | Interactive badge gets common ring | Status label remains visible; disabled only when badge is a control | Semantic text ≥6.18; boundaries ≥3.36; labels prevent color-only meaning |
| Flashes/validation summaries | Semantic foreground/fill, 2px border, heading/icon, live-region behavior as applicable | Close/action control uses its own button states | Focused summary/action uses common ring | Errors link to invalid fields; success/warning/info names remain in copy | Semantic text/boundary pass; icon/heading/copy distinguish intent |
| Tables/list rows | Primary/secondary text on white; decorative gridlines only | Hover fill plus pointer/action affordance when actionable | Focus fill plus inset 2px focus outline | Selected fill + 3px brand accent + `aria-selected`; focused-selected keeps both accent and ring | Text ≥11.81 primary; focus ≥7.08; hover/selected/focus are visibly distinct without color alone |
| Dialogs | Opaque white surface, 2px elevated boundary, primary text; semantic header/callout as needed | Buttons/links use their own states | Initial focus visible; native modal containment and trigger restoration | Consequential final action uses appropriate solid family; validation stays in dialog | Boundary 3.81 on white and 3.63 vs canvas; opaque surface separates content from scrim |
| Overlays/scrims | 60% espresso-black scrim behind opaque dialog panel | No actionable content on scrim; optional pointer dismissal must duplicate visible close action | Focus remains in panel; scrim never receives focus | Underlying workspace is inert while blocking overlay is open | State is distinguished by occlusion + opaque bordered panel, not merely tint |

## Existing hard-coded CSS migration map

UDS-1 must replace these literals in `app/assets/stylesheets/application.css`; until ADR-022 is accepted this table is a migration instruction, not a claim that CSS is already changed.

| Existing selector/value | Warm Parchment token mapping | Note |
|---|---|---|
| `.pos-overlay` `color-mix(in srgb, #000 45%, transparent)` | `background: var(--color-overlay-scrim)` | One common scrim replaces the POS-only black mix. |
| `.pos-overlay__panel` `--color-surface`, `--color-text`, `--color-border` | dialog surface, primary text, elevated boundary | Raise border to 2px so the panel has a meaningful 3:1 boundary. |
| `.pos-overlay__panel` `rgb(0 0 0 / 0.25)` shadow | Keep as optional elevation shadow; never count it as the boundary | The explicit border supplies contrast. |
| `.review-dialog` fallback `#334155` | `--color-dialog-elevated-boundary` | Removes the cool-slate fallback and aligns dialog/POS panels. |
| `.review-dialog::backdrop` `rgb(15 23 42 / 68%)` | `--color-overlay-scrim` | Replaces the separate cool-slate backdrop. |
| `.review-dialog--warning` `#FFF7D6` / `#A16207` | `--color-warning-fill` / `--color-warning-border`; text `--color-warning-fg` | Opaque semantic surface and audited pairing. |
| `.review-dialog--danger` `#FFF0F0` / `#B91C1C` | `--color-danger-fill` / `--color-danger-border`; text `--color-danger-fg` | Opaque semantic surface and audited pairing. |
| `.review-dialog--information` `#EAF6FF` / `#0369A1` | `--color-info-fill` / `--color-info-border`; text `--color-info-fg` | Opaque semantic surface and audited pairing. |
| `.review-dialog__consequences` `rgb(255 255 255 / 65%)` | `--color-dialog-surface` with family foreground and border | Remove translucent washout; use an opaque nested surface. |
| Review/POS dialog shadows `rgb(15 23 42 / 45%)` and `rgb(0 0 0 / 0.25)` | Optional future `--shadow-dialog`; no contrast dependency | Shadow standardization is cosmetic and may follow token migration. |

## Typography and density

| Role | Guidance |
|---|---|
| Primary sans | Data grids, forms, navigation, tabular UI. Prefer a packaged webfont or system UI stack. Candidates: Plus Jakarta Sans (self-hosted) or keep/extend Source Sans 3. |
| Serif (optional) | Brand wordmark and top-level page titles only—not table cells. |
| Mono | ISBN-13, transaction references, barcodes. Prefer packaged mono or existing receipt mono (`Inconsolata` / `--font-receipt`). |

Do not load fonts from a CDN at runtime. Use `font-variant-numeric: tabular-nums` for money, quantities, and aligned numeric columns.

| Mode | Approx. row height | Use |
|---|---:|---|
| Standard | ~52px | Register, touch-oriented operations |
| Compact | ~36px | Dense back-office tables |

Select density with contextual CSS classes by screen type. Persisted user toggles remain deferred.

## Phase 2.2 migration aliases

| Phase 2.2 token | Warm Parchment destination |
|---|---|
| `--color-background` | `--color-bg-canvas` |
| `--color-surface` | `--color-bg-surface` |
| `--color-text` / `--color-text-muted` | `--color-text-primary` / `--color-text-secondary` |
| `--color-action` | `--color-brand-default` |
| `--color-accent` | No automatic alias; select brand soft or an explicit semantic family by meaning |
| `--color-warning` | `--color-warning-solid` for solid controls; otherwise use the warning family member required by the component |
| `--color-danger` | `--color-danger-solid` for solid controls; otherwise use the danger family member required by the component |
| `--color-border` | `--color-border-subtle` for decoration or `--color-border-strong` for controls |

Do not alias one legacy token into every member of a new family. Migration must select the token that matches foreground, boundary, fill, or interaction state.

