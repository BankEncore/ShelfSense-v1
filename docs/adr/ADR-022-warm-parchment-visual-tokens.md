# ADR-022: Warm Parchment visual tokens

- **Status:** Accepted
- **Date:** 2026-08-22
- **Related:** [Phase 2.2 UX foundation](../planning/phase2.2-ux-foundation/phase-2.2-ux-foundation.md), [UX conventions](../ux-conventions.md), [UX design system](../planning/ux-design-system/README.md), [UDS-1 implementation plan](../planning/ux-design-system/uds-1-plan.md), [Warm Parchment](../planning/ux-design-system/warm-parchment.md), [Button and action semantics](../planning/ux-design-system/button-action-semantics.md)

## Context

Phase 2.2 adopted a cool slate/teal/plum token set (`#F8FAFC`, `#0D6E6E`, `#7A2E5A`, and related borders/text) as the administrative visual baseline. That foundation successfully established Propshaft CSS variables, shared partials, money UX, and accessibility expectations.

Exploratory design work now proposes **Warm Parchment**: warm linen canvases, espresso text, hairline warm borders, and a terracotta brand accent suited to bookstore operations. Applying that direction requires an explicit supersession of the Phase 2.2 **palette**, not a silent reinterpretation of existing token names, and must not collapse admin, purchasing ops, and Register into one layout shell.

## Decision

The UX design-system foundation (UDS-1) is accepted for implementation:

1. **Supersede the Phase 2.2 color palette** with the Warm Parchment token vocabulary documented in [warm-parchment.md](../planning/ux-design-system/warm-parchment.md), including a controlled migration or aliases from existing `--color-*` names.
2. **Preserve Phase 2.2 architecture:** Propshaft and component classes; shared partials/helpers; money display/parse boundaries; accessibility rules (visible focus; meaning not by color alone); admin / purchasing-ops / Register runtime boundaries; no business logic in presentation code.
3. **Contrast:** Enforce WCAG **AA** for ordinary interface text and solid button label combinations. Do not claim blanket AAA. Darken solid brand fills as needed so inverse text meets AA (inspirational `#C85A32` on white is insufficient).
4. **Fonts:** Package webfonts locally or use system stacks. Do not depend on Google Fonts or other CDNs at runtime.
5. **Shells remain distinct:** Warm Parchment is one design system expressed through different shells—not a universal sidebar/drawer IA. Deferred chrome patterns stay in [deferred-patterns.md](../planning/ux-design-system/deferred-patterns.md).
6. **Actions:** Visual brand tokens supply colors; [button-action-semantics.md](../planning/ux-design-system/button-action-semantics.md) remains authoritative for wording, intent, style, size, and review escalation (including Post-Void as danger, not routine primary).

UDS-1a lands tokens and temporary legacy aliases in `application.css`. Mark this ADR **Implemented** when UDS-1 (through UDS-1d) merges. See [uds-1-plan.md](../planning/ux-design-system/uds-1-plan.md).

## Consequences

- New screens and migrated screens use Warm Parchment tokens after acceptance.
- Documentation indexes and conventions update when status moves from Accepted to Implemented (UDS-1d).
- Inspirational drafts under `docs/drafts/phase-7.1-ux-refactor/` stay non-authoritative.
- Reject runtime CDN fonts and silent token-meaning changes without migration notes.
