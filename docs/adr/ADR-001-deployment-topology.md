# ADR-001: Single-tenant, multi-store deployment

- **Status:** Accepted
- **Date:** 2026-08-09

## Context

ShelfSense must support multiple stores while avoiding the complexity of a shared SaaS database serving unrelated organizations. Store-specific operation must continue during temporary loss of connectivity.

## Decision

Each ShelfSense installation is authoritative for one organization and may contain multiple stores. A central organization server owns consolidated and master data. Store workstations maintain local POS data and cached reference projections required for offline operation.

Tenant identifiers are not required on every business table merely to simulate multi-tenancy. `store_id` is retained wherever store scope is meaningful.

## Consequences

- Organization-wide constraints can be enforced within one installation.
- Store reporting, sessions, inventory, and receipt identities remain explicitly scoped.
- Hosting multiple unrelated organizations requires separate installations or a future, deliberate multi-tenant redesign.
- Offline capability still creates distributed-systems concerns inside one organization.
