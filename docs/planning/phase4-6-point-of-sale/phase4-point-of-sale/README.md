# Phase 4 — Point of sale foundation

**Status:** Implemented (headless Cash sale, completion kernel, receipt identity, inventory posting).

Phase 5 cash accountability and register UI: [../phase5-cash-register/](../phase5-cash-register/).

| Document | Purpose |
|---|---|
| [phase4-plan.md](phase4-plan.md) | Scope, locked decisions, requirements, build order, acceptance |
| [phase4-schema.md](phase4-schema.md) | Table and column outline for migrations |
| [completed-pos-operation-v1.md](completed-pos-operation-v1.md) | Canonical completed-operation contract and examples |
| [pos-tax-contract.md](pos-tax-contract.md) | Store Tax / rules / calculator and completed tax facts ([ADR-019](../../../adr/ADR-019-pos-sales-tax-model.md)) |
| [receipt-identity.md](receipt-identity.md) | Human-facing `S…-R…-T…` transaction reference ([ADR-006](../../../adr/ADR-006-receipt-numbering.md)) |
| [register-identity.md](register-identity.md) | Register vs Terminal; pre-Phase-4 rename ([ADR-021](../../../adr/ADR-021-register-and-terminal-identity.md)) |
| [operation-and-core-facts.md](operation-and-core-facts.md) | Envelope vs normalized Core dual authority ([ADR-020](../../../adr/ADR-020-pos-operation-envelope-and-core-facts.md)) |

Parent multi-phase sequencing: [../spec.md](../spec.md).

`preliminary-specs-1.md` and `preliminary-specs-2.md` are historical design discussion notes (bannered). Prefer the documents above and ADR-021 for implementation.
