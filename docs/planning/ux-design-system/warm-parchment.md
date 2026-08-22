# Warm Parchment visual system

Status: **Proposed**

Authority for visual tokens and density. Action wording/style/size: [button-action-semantics.md](button-action-semantics.md). Shell boundaries: [README.md](README.md). Palette supersession: [ADR-022](../../adr/ADR-022-warm-parchment-visual-tokens.md).

Inspirational mockups: [`docs/drafts/phase-7.1-ux-refactor/`](../../drafts/phase-7.1-ux-refactor/) (not binding).

## Intent

Balance bookstore literary warmth with back-office data density. Restrict pure white (`#FFFFFF`) to elevated surfaces (cards, inputs, table bodies, modals) so the canvas stays low-glare linen. Prefer hairline warm borders over heavy drop shadows.

## Contrast baseline

Enforce **WCAG AA** for ordinary interface text and controls. Do **not** claim blanket AAA for the full palette.

Known issue with the inspirational terracotta `#C85A32` on white text (~4.23:1): it fails AA for normal-size text. Implementation must:

- Darken the solid brand / commit fill toward `#A84320` (or darker) so white label text meets AA; and/or
- Use a darker text treatment on light brand tints where appropriate.

Secondary text `#6E6763` on white (~5.55:1) meets AA for normal text; treat AAA as aspirational where practical (e.g. primary body `#2C2523`).

## Color tokens (proposed)

Proposed CSS custom properties. Exact names may alias to existing `--color-*` during migration ([program-plan.md](program-plan.md) UDS-1).

| Token | Hex | Role |
|---|---|---|
| `--color-bg-canvas` | `#FBF9F5` | Main application background (warm linen) |
| `--color-bg-surface` | `#FFFFFF` | Cards, inputs, table rows, modal containers |
| `--color-bg-surface-elevated` | `#F4F0EA` | Layered containers, modal headers |
| `--color-bg-subtle` | `#EFECE6` | Table headers, sticky bars, subtle dividers |
| `--color-bg-drawer` | `#F0EAE1` | Expanded line-detail backgrounds (when used); not a global shell mandate |
| `--color-text-primary` | `#2C2523` | Body text, primary table data |
| `--color-text-secondary` | `#6E6763` | Timestamps, ISBNs, secondary labels |
| `--color-text-tertiary` | `#A29B96` | Placeholders, disabled hints |
| `--color-text-inverse` | `#FFFFFF` | Text on solid brand/danger fills (only when fill meets AA) |
| `--color-border-subtle` | `#E6DFD5` | Hairline gridlines, card borders |
| `--color-border-strong` | `#C8BFB5` | Form field borders, panel dividers |
| `--color-brand-primary` | TBD at implementation (start from `#A84320` for AA) | Solid primary commit fill |
| `--color-brand-hover` | Darker than primary | Hover for primary actions |
| `--color-brand-soft` | `#F9ECE7` | Soft brand tint for selection/active nav |
| `--color-table-row-hover` | `#F0EAE1` | Row hover |
| `--color-table-row-selected` | `#EBE3D5` | Selected row (+ left accent bar when applicable) |
| `--color-status-success-bg` / `-text` | `#EAF0EB` / `#2D4731` | In stock / OK / success |
| `--color-status-warning-bg` / `-text` | `#FAF3E5` / `#6E4D00` | Low stock / pending |
| `--color-status-danger-bg` / `-text` | `#F9EBEA` / `#7A2018` | Error / out of stock / alert |
| `--color-status-info-bg` / `-text` | `#EBF1F5` / `#1D435E` | Draft / on order / info |

Sidebar/topbar espresso tokens (`#231F1D`, `#36302E`) are **deferred** with global shell chrome ([deferred-patterns.md](deferred-patterns.md)). Do not introduce a permanent global dark sidebar in UDS-1.

### Phase 2.2 mapping (until migration completes)

| Phase 2.2 token | Role today | Warm Parchment direction |
|---|---|---|
| `--color-background` | `#F8FAFC` | → canvas linen |
| `--color-surface` | `#FFFFFF` | → surface (unchanged role) |
| `--color-text` / `--color-text-muted` | Slate | → primary / secondary espresso-taupe |
| `--color-action` | `#0D6E6E` teal | → brand primary (darkened terracotta) |
| `--color-accent` | `#7A2E5A` plum | Revisit; soft brand or secondary accent as needed |
| `--color-warning` / `--color-danger` / `--color-border` | Existing | → warm semantic / border tokens |

## Typography

| Role | Guidance |
|---|---|
| Primary sans | Data grids, forms, navigation, tabular UI. Prefer a packaged webfont **or** system UI stack. Candidates: Plus Jakarta Sans (self-hosted) or keep/extend Source Sans 3. |
| Serif (optional) | Brand wordmark and top-level page titles only—not table cells. |
| Mono | ISBN-13, transaction references, barcodes. Prefer packaged mono or existing receipt mono (`Inconsolata` / `--font-receipt`). |

**Do not** load fonts from Google Fonts (or other CDNs) at runtime. Package assets under the app or use system fallbacks so offline/local Docker continuity holds.

Use `font-variant-numeric: tabular-nums` for money, quantities, and aligned numeric columns.

## Density

| Mode | Approx. row height | Use |
|---|---|---|
| Standard | ~52px | Register, touch-oriented ops |
| Compact | ~36px | Dense back-office tables (inventory, PO lines) |

Select density with **contextual CSS classes** by screen type. Persisted user toggles are deferred ([deferred-patterns.md](deferred-patterns.md)).

## Table interaction

| State | Treatment |
|---|---|
| Hover | Soft tan row background |
| Selected | Stronger cream + optional 3px brand left accent |
| Keyboard focus | Visible 2px brand (or action) ring with offset; never remove focus indicators |

Pair status badges with text labels; never color alone ([ux-conventions.md](../../ux-conventions.md)).

## Modals and review dialogs

Use opaque surface backgrounds for dialogs so they separate clearly from the linen canvas (addresses washout against translucent or tinted-only panels). Consequence styling remains intent-based (warning / danger / information) per Phase 7 review-dialog conventions and [button-action-semantics.md](button-action-semantics.md).
