# Deferred UX patterns

Status: **Proposed** (explicitly out of the UDS foundation program)

These ideas appear in inspirational drafts. They are worthwhile only after specification. Do not implement them as side effects of Warm Parchment tokens or button-class migration.

| Pattern | Why deferred | Prerequisite |
|---|---|---|
| Universal master-detail / slide-in drawers as default navigation | Admin remains conventional server-rendered Rails; Hotwire is not global | Ops-only Stimulus pattern spec; must not replace admin show pages by default |
| Permanent global search (Cmd/Ctrl+K) | Existing searches are resource-specific with bounded semantics | Product scope, permissions, result types, barcode behavior |
| Persisted density preference | Density is CSS-based and deliberate today | Preference storage, applicability per shell, defaults |
| Collapsible global sidebar + dark espresso chrome | Conflicts with distinct admin / ops / Register shells | ADR revisiting shell architecture; parked as UDS-7. Compact **header** presentation of the existing grouped catalog is UDS-5.0/5.2, not this row |
| Inline editing in dense data grids | High interaction and validation risk | Per-workspace contract |
| Generic keyboard-driven data-grid (arrow keys + Enter expand) | Conflicts with Register and ops Enter/activate semantics | Explicit grid mode and focus model |
| Enter anywhere on a table row to expand Line details | Appropriates Enter without navigation contract | Explicit disclosure control first ([surface-contracts.md](surface-contracts.md)) |
| Replacing ordinary admin show pages with drawers | Breaks breadcrumbs, deep links, and Hotwire policy | Accepted IA change |
| Fetching `audit_events` for every transaction line | Different authz and volume; conflates with Line details | Separate sensitive-access design |
| Broad conversion of all existing screens in one PR | Unbounded risk | [migration-matrix.md](migration-matrix.md) + phase adoption targets |
| Runtime font dependency on an external CDN | Offline / Docker / CSP continuity | Self-hosted or system fonts only ([warm-parchment.md](warm-parchment.md)) |

## Conflict resolutions (accepted for foundation)

| Draft proposal | Existing decision | Foundation resolution |
|---|---|---|
| Replace slate/teal/plum palette | Phase 2.2 tokens in conventions | Supersede via [ADR-022](../../adr/ADR-022-warm-parchment-visual-tokens.md) when UDS-1 ships; do not silently rename meanings |
| Google Fonts links | Local/offline continuity | Package fonts or use system stacks |
| Post-Void as solid terracotta primary | Post-void is controlled correction | Danger outline on page; solid danger only after review ([button-action-semantics.md](button-action-semantics.md)) |
| One primary action always | Some pages have no routine commit | Transaction detail may have no solid brand button |
| Click/Enter row to expand | Established keyboard behavior | Explicit disclosure control |

When a deferred pattern is ready, add a dedicated proposed doc (or ADR) and a program-plan slice—do not expand UDS-1 scope silently.
