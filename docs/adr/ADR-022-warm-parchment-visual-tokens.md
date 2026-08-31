# ADR-022: Warm Parchment visual tokens

- **Status:** Implemented
- **Date:** 2026-08-22
- **Amended:** 2026-08-31 (thermal customer-document fonts); 2026-08-31 (local packaging of thermal faces; Register chrome optional adoption)
- **Related:** [Phase 2.2 UX foundation](../planning/phase2.2-ux-foundation/phase-2.2-ux-foundation.md), [UX conventions](../ux-conventions.md), [UX design system](../planning/ux-design-system/README.md), [UDS-1 implementation plan](../planning/ux-design-system/uds-1-plan.md), [Warm Parchment](../planning/ux-design-system/warm-parchment.md), [Button and action semantics](../planning/ux-design-system/button-action-semantics.md), [Receipts and reports revamp](../planning/receipts-and-reports-revamp/README.md), [Register surface polish](../planning/register-surface-polish/README.md)

## Context

Phase 2.2 adopted a cool slate/teal/plum token set (`#F8FAFC`, `#0D6E6E`, `#7A2E5A`, and related borders/text) as the administrative visual baseline. That foundation successfully established Propshaft CSS variables, shared partials, money UX, and accessibility expectations.

Exploratory design work proposed **Warm Parchment**: warm linen canvases, espresso text, hairline warm borders, and a terracotta brand accent suited to bookstore operations. Applying that direction required an explicit supersession of the Phase 2.2 **palette**, not a silent reinterpretation of existing token names, and must not collapse admin, purchasing ops, and Register into one layout shell.

The 2026-08-31 thermal amendment permitted **Noto Sans Mono** and **Plus Jakarta Sans** for D1/D2 customer documents via Google Fonts CDN. That satisfied browser-print readability quickly, but left print dependent on network access, required CSP carve-outs, and did not satisfy future offline Terminal print ([ADR-018](ADR-018-pos-runtime-and-deployment.md)). ShelfSense already packages Source Sans 3, Source Serif 4, and Inconsolata under `app/assets/fonts/`; the same pattern is the durable home for the thermal faces.

## Decision

The UX design-system foundation (UDS-1) ships Warm Parchment for screen chrome:

1. **Supersede the Phase 2.2 color palette** with the Warm Parchment token vocabulary documented in [warm-parchment.md](../planning/ux-design-system/warm-parchment.md), including controlled temporary aliases from existing `--color-*` names.
2. **Preserve Phase 2.2 architecture:** Propshaft and component classes; shared partials/helpers; money display/parse boundaries; accessibility rules (visible focus; meaning not by color alone); admin / purchasing-ops / Register runtime boundaries; no business logic in presentation code.
3. **Contrast:** Enforce WCAG **AA** for ordinary interface text and solid button label combinations. Do not claim blanket AAA. Solid brand default is `#A84320`.
4. **Fonts (screen and print packaging):** Package webfonts locally or use system stacks. Do **not** depend on Google Fonts or other runtime font CDNs for any ShelfSense UI or print surface. Faces live under `app/assets/fonts/` with Propshaft-served `@font-face` rules and committed license texts (OFL or equivalent). Prefer latin subsets and only the weights a surface actually uses.
5. **Authorized faces and surfaces (amended 2026-08-31 — local packaging):**
   - **Admin and purchasing-ops screen chrome** remain on locally packaged **Source Sans 3** (and **Source Serif 4** where Warm Parchment display roles already use it). Do not silently replace those faces on admin/ops without a presentation packet.
   - **Thermal customer documents** — `.pos-receipt__print` (D1) and `.pos-gift-card-voucher` (D2) — use locally packaged **Noto Sans Mono** (body, money, meta) and **Plus Jakarta Sans** (store name, totals, section emphasis). CSS variables `--font-thermal-body` and `--font-thermal-display` remain authoritative. Print must wait for `document.fonts.ready` when supported. Fallback stacks (`Cascadia Code`, `Consolas`, `SF Mono`, `Segoe UI Mono`, `Source Sans 3`, system UI) must remain so a missing face still produces legible output.
   - **Register screen chrome** may adopt the same locally packaged **Plus Jakarta Sans** and/or **Noto Sans Mono** when an accepted presentation packet (for example Register surface polish) explicitly switches token stacks or component classes. Adoption is optional and packet-gated; it does not require a further ADR if packaging and role mapping stay within this decision. Keyboard, Turbo, Stimulus, and scan-focus contracts remain frozen unless that packet separately amends them.
   - **X/Z reports, session tapes, and other `.pos-report-print` surfaces** keep locally packaged **Inconsolata** (`--font-receipt`) until a later presentation packet supersedes them.
6. **Shells remain distinct:** Warm Parchment is one design system expressed through different shells—not a universal sidebar/drawer IA. Deferred chrome patterns stay in [deferred-patterns.md](../planning/ux-design-system/deferred-patterns.md).
7. **Actions:** Visual brand tokens supply colors; [button-action-semantics.md](../planning/ux-design-system/button-action-semantics.md) and `ActionButtonHelper` are authoritative for wording, intent, style, size, and review escalation (including Post-Void as danger, not routine primary). Broad view adoption is UDS-2.

Delivery record: [uds-1-plan.md](../planning/ux-design-system/uds-1-plan.md) (UDS-1a–1d). Thermal typography delivery: [receipts-and-reports-revamp/](../planning/receipts-and-reports-revamp/README.md).

### Amendment note — supersedes CDN thermal exception

The prior decision that D1/D2 may load Noto Sans Mono and Plus Jakarta Sans from `fonts.googleapis.com` / `fonts.gstatic.com` is **superseded**. Those faces must be packaged locally like Source Sans 3 and Inconsolata. Runtime CDN font links, preconnects, and CSP allowances for Google Fonts hosts are removed when packaging lands. Until packaging is merged, the temporary CDN loaders may remain only as a transitional implementation detail; they are no longer accepted policy.

## Consequences

- New screens and migrated screens use Warm Parchment tokens.
- [ux-conventions.md](../ux-conventions.md) palette section points at Warm Parchment; Phase 2.2 architecture conventions remain.
- Temporary legacy `--color-*` aliases and button shorthand remain until retirement conditions in the migration matrix are met.
- Inspirational drafts under `docs/drafts/phase-7.1-ux-refactor/` and `docs/drafts/register-surface-revamp/` stay non-authoritative until an accepted packet adopts their presentation.
- Reject runtime CDN fonts for all surfaces. Thermal and optional Register use of Noto Sans Mono / Plus Jakarta Sans requires local packaging, license files, `@font-face` weights actually used, and fallback stacks.
- Offline Terminal print may reuse the same packaged faces without a second font-hosting decision; channel and embedding details remain under [ADR-018](ADR-018-pos-runtime-and-deployment.md) when that runtime is accepted.
- Content-Security-Policy need not allow Google Fonts hosts for Register print once local packaging is live.
