# ADR-003: Server and terminal data authority

- **Status:** Accepted
- **Date:** 2026-08-09
- **Interpretation (ADR-021):** “Workstation” holding cached reference data or owning open local work is a **Terminal**. Commercial checkout origin remains the **Register**.

## Context

## Decision

Assign one authoritative writer by data category:

- The central server owns organization and store master data, configuration, catalog, prices, taxes, users, permissions, suppliers, purchasing data, customer master data, reusable exemptions, and consolidated projections.
- A workstation holds read-only cached projections of server-owned reference data.
- The originating workstation owns open local work and locally completed but unacknowledged operations.
- Once accepted, the server owns consolidated processing and projections while preserving the terminal-originated fact unchanged.

Terminals do not directly edit cached master data. Exceptional checkout needs use explicitly modeled operations, such as open-ring lines, rather than silently creating master records. Future terminal-originated proposals may be added as separate reviewable workflows.

## Consequences

- Most synchronization conflicts are prevented through ownership.
- Back-office administration requires access to the server application.
- Split-ownership workflows such as sessions require explicit state and acknowledgment boundaries.
- A server rejection cannot erase a completed local historical fact; it can change acceptance or reconciliation state.
