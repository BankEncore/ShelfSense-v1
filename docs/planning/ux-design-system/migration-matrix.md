# UX design system — migration matrix

Status: **Working tracker** (update as UDS slices ship)

Values:

- **legacy** — pre–Warm Parchment / pre–action-semantics presentation
- **partial** — tokens or some primitives applied; patterns incomplete
- **conforming** — matches accepted packet + conventions for that surface

| Area | Status | Notes |
|---|---|---|
| Shared CSS tokens (`application.css` `:root`) | legacy | Phase 2.2 teal/plum palette implemented |
| Shared admin partials (`shared/*`) | legacy | Structure sound; visual tokens pending UDS-1 |
| Button classes (`btn`, `btn--secondary`, `btn--danger`, `btn--ghost`) | legacy | Map in UDS-1 per [button-action-semantics.md](button-action-semantics.md) |
| Review dialogs (Phase 7 consequence modals) | partial | Behavior accepted; opaque Warm Parchment surfaces pending |
| Admin — Suppliers (reference CRUD) | legacy | UDS-2 target |
| Admin — other CRUD (products, stores, …) | legacy | Incremental after UDS-2 |
| Ops — Location queue | legacy | Candidate UDS-2 ops reference |
| Ops — Draft PO | legacy | Candidate UDS-2 ops reference |
| Ops — Receiving | legacy | Preferred dense-grid UDS-2 ops reference |
| POS — Register workspace | legacy | UDS-3 visual only; bindings unchanged |
| POS — Transaction history / completed show | legacy | UDS-2 target; [surface-contracts.md](surface-contracts.md) |
| POS — Printed receipt | conforming* | *Print contract remains authoritative; not a Warm Parchment target |
| Status badges | legacy | Retheme with semantic tokens in UDS-1 |

\* Printed receipt is “conforming” to its own locked print contract, not to Warm Parchment screen chrome.
