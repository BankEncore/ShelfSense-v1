# Phase 2.2 — Administrative UX Foundation

## Status

Implemented

## Purpose

Phase 2.2 improves the readability, consistency, and usability of the existing ShelfSense administrative interface before Phase 3 introduces inventory workflows and denser operational data.

This is a focused presentation and interaction pass, not a full-scale UX redesign. The phase should transform the current barebones Rails forms and record views into a coherent administrative interface with reusable patterns that future phases can extend.

The primary objective is to help users quickly answer four questions on every screen:

1. What record or task am I viewing?
2. What is its current state?
3. What information matters most right now?
4. What actions can I take?

## Position in the roadmap

Phase 2.2 sits after Phase 2.1 (merchandise correctness and operability) and before Phase 3 inventory foundation.

It does not reopen Phase 2 or Phase 2.1 domain decisions, and it does not add Phase 3 inventory behavior. Instead, it establishes the presentation patterns needed to display merchandise, configuration, authorization, audit, and future inventory information clearly.

Roadmap and documentation indexes updated with this implementation:

- [README.md](../../../README.md) roadmap
- [docs/README.md](../../README.md) documentation index
- [docs/planning/README.md](../README.md) planning index
- [UX conventions](../../ux-conventions.md)

## Goals

Phase 2.2 will:

- Establish a consistent visual hierarchy and page structure across the administrative application.
- Make index, show, and form pages easier to scan and understand.
- Present domain values in user-friendly formats rather than exposing raw database values.
- Create reusable view partials and helpers for common interface patterns.
- Improve form organization, guidance, validation, and error recovery.
- Make relationships between records visible through human-readable labels and contextual links.
- Separate operationally important information from secondary and technical metadata.
- Establish a product index, show page, and form flow as the reference implementation.
- Provide patterns that Phase 3 can extend for balances, adjustments, units, and ledger history.
- Preserve the existing server-rendered Rails architecture using Propshaft-served CSS.

## Non-goals

Phase 2.2 will not:

- Conduct a complete application-wide UX or product-design exercise.
- Redesign business workflows or change domain rules merely to improve presentation.
- Build dashboards, analytics, reporting, or new operational capabilities.
- Design the final POS interface or its keyboard-driven interaction model.
- Introduce a client-side application framework, SPA, ViewComponent library, Node toolchain, or Tailwind.
- Install or configure Importmap, Turbo, or Stimulus.
- Implement Phase 3 inventory tables, adjustments, balance calculations, or ledger behavior.
- Add responsive mobile workflows beyond ensuring that administrative pages remain usable at reasonable viewport sizes.
- Replace every existing view if doing so does not contribute to the shared UX foundation.
- Add store schema fields such as `internal_name` or `shopping_center`, or redefine receipt blank/inherit semantics.
- Introduce fuzzy or full-text product search.
- Add browser-based system tests or restore the deferred system-test CI job.

## UX principles

### 1. Design for recognition and scanning

Pages should emphasize identity, state, key values, and available actions. Fields should not receive equal visual weight merely because they are adjacent columns in a table.

### 2. Present domain language, not storage details

The interface should display human-readable names, formatted values, and meaningful relationships. Raw enum values, integer cents, UUIDs, and foreign keys should not be the default user experience.

Examples:

- `1250` cents becomes a currency amount such as `$12.50` (respecting organization currency conventions when available).
- `physical_book` / `list_price` become humanized labels such as `Physical book` / `List price`.
- A department is shown by code and name rather than by ID.
- A merchandise category uses its path label (`Parent > Child`) when nested.
- A missing optional value becomes a consistent muted value such as `Not provided`.

### 3. Use progressive disclosure

Information should be organized into three levels:

- **Primary:** record identity, status, key values, and primary actions.
- **Secondary:** classification, pricing, relationships, and supporting details.
- **Technical:** UUIDs, timestamps, concurrency metadata, and other system details.

Technical information must remain accessible (for example via a native `<details>` section), but it should not dominate routine workflows.

### 4. Make relationships visible

ShelfSense records are relational. Related records should appear as named, contextual links. Breadcrumbs, summary sections, and related-record panels should reinforce where the current record fits within the domain.

### 5. Use color semantically and accessibly

Color reinforces meaning but must never be the only way meaning is communicated. Statuses and warnings require text labels.

Use the administrative palette in [Color and surface tokens](#color-and-surface-tokens). Map semantic status to that palette with text labels:

- Success / active configuration: Deep Teal with text.
- Informational: Deep Teal or Slate Muted with text.
- Warning / attention: Warm Amber with text.
- Destructive / failed / invalid: a high-contrast danger treatment with text (not the primary brand colors alone).
- Inactive / secondary: Soft Gray borders and Slate Muted text.

### 6. Prefer server-rendered HTML and CSS

Pages remain conventional server-rendered Rails HTML. Phase 2.2 is HTML/CSS-first. Importmap, Turbo, and Stimulus remain deferred. Any later installation must be a separately accepted, narrowly scoped change.

Forms and navigation remain ordinary Rails form posts and links. Native `<details>` covers technical disclosure accessibly. Destructive confirmations use conventional Rails confirmation behavior until Hotwire is formally adopted.

## Shared page anatomy

Administrative pages should use a consistent structure where applicable:

1. Breadcrumbs or contextual navigation.
2. Page header with title and identifying subtitle.
3. Current status and primary actions.
4. Key summary information.
5. Related operational or domain details.
6. Secondary metadata.
7. Optional cheap recent-activity snippet only when no new query infrastructure is required.
8. Collapsible or visually subordinate system details (`<details>`).

The structure may be simplified for small records, but pages should use the same underlying patterns rather than inventing a new layout for each resource.

## Shared presentation primitives

Create reusable partials and helpers for at least the following patterns:

### Application structure

- Application shell and primary navigation.
- Content container with readable maximum widths.
- Breadcrumbs.
- Page header.
- Primary and secondary action groups.
- Section heading and optional explanatory text.

### Record presentation

- Status badge.
- Definition or detail list.
- Money value (display helper).
- Identifier display (plain text; copy-to-clipboard is not required while Hotwire is deferred).
- Date and timestamp display.
- Empty or missing value display.
- Related-record link.
- Empty state.
- Technical-details section (`<details>`).

### Data collections

- Responsive data table.
- Sortable-column treatment only where sorting is already supported or explicitly added for the product index.
- Filter and search controls (required for product index; optional elsewhere in this phase).
- Pagination controls when pagination is needed.
- Collection empty state.
- Row-level action treatment for genuine list actions.

### Forms and feedback

- Form section or field group.
- Consistent labels, required indicators, help text, and input spacing.
- Field-level validation error.
- Validation-error summary linked to affected fields.
- Flash message and alert banner.
- Confirmation treatment for consequential actions.
- Primary submit and secondary cancel action group.
- Currency amount fields that convert to/from integer cents at the form boundary.

Partials and helpers should encode presentation rules so those rules do not have to be recreated in each template. Do not introduce ViewComponent or a separate frontend component framework in this phase.

## Typography, spacing, and layout

Serve styles through Propshaft from hand-authored CSS. Define application-wide custom properties and small component classes for:

- Page, section, and field spacing.
- Content and form maximum widths.
- Heading levels and supporting text.
- Body, muted, and technical text.
- Borders, surfaces, and light elevation where needed.
- Links, buttons, focus indicators, and disabled states.
- Semantic status and alert colors derived from the palette below.
- Table density and alignment.

Do not add Node, Tailwind, cssbundling, or a CSS framework. A later CSS toolchain, if ever needed, requires a separate decision.

Operational and comparison-oriented screens may use denser layouts than narrative or configuration pages, but density must be deliberate and consistent.

Keyboard focus indicators must remain clearly visible. Text and interactive controls should meet reasonable accessibility contrast expectations against the chosen surfaces.

## Color and surface tokens

Adopt this restrained administrative palette. It is coherent with ShelfSense identity and appropriate for back-office work rather than marketing UI.

| Role | Color name | HEX | Usage |
|---|---|---|---|
| Background | Slate Light | `#F8FAFC` | App canvas, background behind cards |
| Surface | Pure White | `#FFFFFF` | Cards, panels, sidebars, tables |
| Primary text | Dark Slate | `#0F172A` | Headings, body text (matches logo text) |
| Secondary text | Slate Muted | `#64748B` | Subtitles, disabled states, placeholders, muted empty values |
| Primary action | Deep Teal | `#0D6E6E` | Main buttons, active nav items, key links |
| Secondary accent | Muted Plum | `#7A2E5A` | Secondary buttons, feature highlights, tags |
| Warm accent | Warm Amber | `#E09214` | Alerts, warnings, attention banners |
| Borders | Soft Gray | `#E2E8F0` | Card borders, table row dividers |

Encode these as CSS custom properties (for example `--color-background`, `--color-surface`, `--color-text`, `--color-text-muted`, `--color-action`, `--color-accent`, `--color-warning`, `--color-border`) and consume them from component classes. Do not hard-code one-off hex values across templates.

Destructive actions and validation errors need a clearly labeled danger treatment that remains distinguishable from Warm Amber warnings and Deep Teal primary actions. Prefer a dedicated danger token if contrast requires it; do not rely on color alone.

## Index-page standard

Index pages should function as working lists rather than database dumps.

Each index should include, when relevant:

- A clear page title and creation action.
- Human-readable, task-relevant columns.
- Consistent numeric, monetary, and status alignment.
- A clear primary link for each row (usually the record name or title).
- Meaningful collection empty states.
- Distinct empty states when search or filters return no rows, on screens that support search or filters.

**Bounded new index behavior in Phase 2.2:** only the product index must gain search, filters, and pagination. Other indexes may adopt shared table, empty-state, and formatting primitives without adding search in this phase.

Columns should be selected because they help a user identify, compare, or act on records—not merely because the attributes exist.

Dedicated `Show` buttons should generally be avoided when the record name or title can serve as the primary link. Row menus should be added only where users need to perform those actions directly from the list.

## Show-page standard

Show pages should establish the record's identity and state before presenting detailed attributes.

A show page should normally include:

- Record title and identifying subtitle.
- Status badge where the record has a lifecycle state.
- Primary action, usually `Edit`.
- Summary of the most important values.
- Grouped detail sections.
- Named links to related records.
- Subordinate system details such as UUID and timestamps inside `<details>`.

A short recent-audit snippet on product show is optional and permitted only if it can reuse existing audit queries/indexes without new audit-query infrastructure. Otherwise omit it; the Audit Events index remains the full history surface.

Destructive, rare, or lifecycle-changing actions should be visually separated from routine actions and should explain their consequences when confirmation is required.

## Form standard

Forms should be organized around the user's mental model and task rather than database column order.

Requirements:

- Group fields into named sections with short guidance where needed.
- Make required fields recognizable before submission.
- Use appropriate controls and input modes for the value being collected.
- Preserve entered values after validation failures.
- Display an error summary near the start of the form.
- Display the relevant message beside each invalid field.
- Move or guide focus to the error summary after an invalid submission when practical without JavaScript frameworks (for example via server-rendered `autofocus` or an in-page anchor).
- Explain domain behavior before it causes an error.
- Keep the primary submit action clear and stable.
- Provide a predictable cancel or return action.
- Present money as currency amounts on ordinary admin forms; convert to/from integer `_cents` at the form/controller boundary. CSV and import contracts continue to use integer cents.

For example, the product identifier field must explain that the user may enter a manufacturer-assigned identifier or request a system-generated identifier. The interface should not reveal that policy only through a validation failure.

## Empty states

Empty states should communicate:

1. What is absent.
2. What that absence means in the current domain context.
3. What the user can do next, if an action is available.

Generic messages such as `No records found` should be replaced where domain context matters.

The design should distinguish between:

- A collection that has never had records.
- A collection with no results for the current search or filters.
- A legitimately absent optional relationship.
- A future operational state, such as a variant with no inventory activity yet.

## Product reference implementation

Products are the reference flow for Phase 2.2 because they exercise identifiers, category classification, list pricing, lifecycle state, related variants, index presentation, and forms.

Field ownership must follow the implemented Phase 2 / 2.1 schema. Phase 2.2 must not introduce new product attributes solely to fill a layout.

### Product index

The product index must include:

- Search by product `name` and normalized `primary_identifier` using **normalized exact or prefix matching** only (no fuzzy matching and no broad full-text search).
- Filters for `status` (`draft`, `active`, `discontinued`) and `merchandise_category_id`.
- Pagination with default page size **50**.
- Product name as the primary row link.
- Primary identifier.
- Merchandise category path label when present.
- Variant count.
- Formatted list price.
- Lifecycle status badge.
- Distinct empty collection vs empty search/filter result states.

Do not show product-level department or tax class; those belong to variants.

### Product show page

The product show page must include:

- Product name as the primary identity.
- Primary identifier as supporting identity.
- Lifecycle status (`draft`, `active`, or `discontinued`).
- Formatted list price and other key summary information.
- Merchandise category as a named link using path label when present.
- Publication and descriptive details grouped by meaning from existing fields: `subtitle`, `description`, `brand_name`, `product_model`, `release_date`, variant option names.
- Related variants as a readable collection with links, each showing enough sellability context (status, class, department, tax, condition when used, formatted regular price).
- UUID and timestamps in subordinate system details.
- Optional short audit snippet only under the cheap-query rule above.

### Product form

Group fields into sections that match real attributes:

#### Identity

- Identifier mode and external identifier on create; immutable primary identifier display on edit.
- Name.
- Subtitle.
- Description.
- Brand name.
- Model (`product_model`).
- Release date.
- Variant option name 1 / 2.

#### Classification

- Merchandise category (path-label options).

#### Pricing

- List price as a currency amount (not raw cents).

#### Lifecycle

- Status (`draft`, `active`; discontinue remains the dedicated lifecycle action where already established).

Help text must continue to explain that category and list price supply creation-time defaults for variants and do not rewrite existing variants.

### Product variant show and form

Variant screens are part of the reference/adoption set because sellability fields live here:

- Merchandise class, department, tax class, and condition (used variants).
- Regular price as a currency amount on ordinary admin forms (CSV remains `regular_price_cents`).
- Status and type.
- Human-readable related-record links.
- No implication that blank edit fields dynamically re-inherit defaults.

## Adoption across existing screens

After the product reference flow establishes the patterns, apply the shared primitives to these named screens:

- Application navigation and flash messages.
- Product index, show, new, and edit.
- Product variant show and form.
- **Stores** (Phase 1 representative): adopt shared page/form patterns and expose existing schema fields already permitted by the controller—`legal_name`, address lines, city, region, postal code, phone, and `san`—without adding deferred store columns or receipt blank/inherit semantics.
- **Merchandise classes** (Phase 2 classification representative): adopt shared show/index/form patterns for an existing classification resource.

Remaining existing screens may be migrated incrementally if they can already use the established partials without blocking Phase 3. The phase must not become an unbounded rewrite of every generated view.

## Phase 3 extension points

The UX foundation should be capable of supporting, without implementing, these Phase 3 patterns:

- Quantity summary cards or compact metrics for on-hand, reserved, unavailable, and available inventory.
- Store-by-store inventory comparison tables.
- Readable ledger or activity history.
- Inventory adjustment forms with reason and quantity guidance.
- Individually tracked unit status and history.
- Warnings for unavailable or exceptional stock states.

For future inventory summaries, `available` is the operationally emphasized value while preserving the invariant:

```text
available = on_hand - reserved - unavailable
```

Ledger history should eventually be presented in domain language rather than as raw polymorphic source fields and UUIDs. That behavior belongs to Phase 3; Phase 2.2 establishes only the reusable presentation structure.

## Frontend runtime policy

Phase 2.2 is HTML/CSS-first.

- Propshaft serves hand-authored CSS custom properties and component classes.
- Importmap, Turbo, and Stimulus remain deferred.
- Any later Hotwire installation must be a separately accepted, narrowly scoped change.
- Forms and navigation remain conventional server-rendered Rails behavior.
- Use native `<details>` for technical disclosure.
- Keep destructive confirmations as conventional Rails confirmation behavior until Hotwire is formally adopted.

## Implementation sequence

### Slice 1 — Visual foundation and application shell

- Define CSS custom properties for the palette, typography, spacing, layout, focus, and controls.
- Refine the application shell and navigation with the new surfaces and action colors.
- Implement page headers, breadcrumbs, action groups, alerts, and content sections.
- No JavaScript runtime installation in this slice.

### Slice 2 — Shared records, tables, and forms

- Implement status badges and formatted value helpers (money, dates, missing values, category path labels).
- Implement detail lists, technical details (`<details>`), and empty states.
- Implement the shared table pattern.
- Implement form sections, help text, error summaries, field errors, and currency field helpers.

### Slice 3 — Product reference flow

- Redesign the product index with search, status/category filters, and pagination (page size 50).
- Redesign the product show page and related variants list.
- Redesign product new/edit forms around real field ownership.
- Apply currency UX to variant regular price on variant show/form.

### Slice 4 — Representative adoption and hardening

- Apply the patterns to Stores (including existing address fields) and Merchandise Classes.
- Verify keyboard focus, contrast, validation flows, and authorization-preserving actions.
- Document how future screens should use the shared partials and helpers.
- Confirm that Phase 3 can extend the patterns without redesigning the foundation.

## Testing expectations

Phase 2.2 should add or update tests for behavior rather than brittle visual markup details.

Use request/integration tests and helper/unit tests. Browser system tests remain deferred per [docs/testing.md](../../testing.md).

Tests should cover, as applicable:

- Authorized users can reach the redesigned screens and perform existing actions.
- Product index search (name; normalized identifier exact/prefix) and filters return the expected records.
- Pagination defaults to 50 and pages correctly.
- Human-readable formatting is correct for money, identifiers, statuses, dates, category paths, and missing values.
- Invalid forms show both a summary and field-level errors.
- Entered form values survive validation failures, including currency fields.
- Record relationships link to the correct routes.
- Empty states differ appropriately from empty search/filter results on the product index.
- Consequential actions preserve existing authorization and lifecycle rules.
- Existing audit behavior remains intact.
- Variant admin forms accept and display currency amounts while persisting integer cents.

## Documentation deliverables

Phase 2.2 should produce concise internal documentation covering:

- Page anatomy and layout conventions.
- Available shared partials/helpers and when to use them.
- Form and validation conventions, including currency boundaries.
- Palette tokens and semantic color usage.
- Table and empty-state conventions.
- Explicit note that Hotwire remains deferred.
- Guidance for extending the system in Phase 3 and later phases.

The documentation should describe intended usage rather than duplicating implementation details that are obvious from helper and partial APIs.

Roadmap and index documents listed under [Position in the roadmap](#position-in-the-roadmap) are updated with this Implemented status.

## Acceptance criteria

Phase 2.2 is complete when:

1. Administrative screens in scope use a consistent application shell, content width, typography, spacing, navigation, focus treatment, and the adopted color tokens.
2. Shared partials/helpers exist for page headers, actions, status badges, formatted values, detail lists, tables, form sections, alerts, validation errors, empty states, currency fields, and technical details.
3. Product index, show, new, and edit screens serve as the documented reference implementation and use only real product attributes.
4. Product index supports name and normalized-identifier exact/prefix search, status and merchandise-category filters, and pagination at 50 rows.
5. Product and variant ordinary admin forms use currency amounts for list price and regular price; CSV/import contracts remain in cents.
6. Stores and Merchandise Classes adopt the shared patterns; Stores expose existing address/legal/phone/SAN fields without new deferred store schema.
7. Primary, secondary, lifecycle-changing, and destructive actions are visually distinguishable and retain existing authorization behavior.
8. Empty collections and empty product search/filter results provide distinct, meaningful guidance.
9. Technical values remain accessible via subordinate disclosure without dominating routine pages.
10. Keyboard focus is visible, controls are labeled, and meaning is not communicated by color alone.
11. No Importmap/Turbo/Stimulus installation is introduced by this phase.
12. Existing domain behavior, authorization, and audit behavior continue to pass their tests under the current non-system-test CI policy.
13. The new patterns are documented well enough for Phase 3 screens to adopt them without inventing a separate design system.

## Deliverable

ShelfSense has a readable, consistent administrative interface and a reusable HTML/CSS UX foundation. Users can navigate merchandise and configuration records, understand their state and relationships, complete forms with useful guidance, and recover from validation errors without interpreting the underlying database schema.

Phase 3 can then introduce inventory balances, adjustments, units, and ledger history using established presentation patterns rather than adding another layer of barebones CRUD views.
