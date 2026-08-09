# ADR-015: Offline sale of individually tracked units

- **Status:** Accepted
- **Date:** 2026-08-09

## Context

An individually tracked unit is unique, so stale data could theoretically allow duplicate sale. In ShelfSense's bookstore context, however, the physical unit must be presented to the cashier, which provides a strong operational control.

## Decision

Permit individually tracked merchandise to be sold offline. The cashier must scan or explicitly select the exact `inventory_unit`. The workstation verifies its cached sellable state, reserves it while the transaction is open, records its identifier on the line, and marks it sold locally at completion.

Physical possession is the primary operational control. If a duplicate unit sale nevertheless synchronizes, preserve both transaction histories, quarantine the conflicting inventory effect, never substitute a different unit silently, and resolve the error through an authorized compensating workflow.

## Consequences

- Unique merchandise does not become unavailable merely because the network is down.
- Duplicate-sale risk is accepted as low but nonzero.
- Manual unit entry and override paths require stronger authorization and audit than scanning.
- Synchronization must detect duplicate completed effects for the same unit.
