# ADR-008: Append-only audit events

- **Status:** Accepted
- **Date:** 2026-08-09

## Context

Operational history must explain who performed a material action, where, when, and why. Domain events alone do not contain sufficient accountability context, and generic database triggers cannot reliably express business intent.

## Decision

Record material security, configuration, pricing, tax, POS, return, inventory, cash, purchasing, financial, synchronization, and sensitive-access actions as append-only audit events.

An audit event records, as applicable: occurrence and recording times; actor; store, workstation, and session; action; subject and source; reason; correlation and causation identifiers; selective before and after values; metadata; and application version.

Audit records are not edited or deleted by ordinary workflows. Corrections create additional events. Sensitive secrets and complete indiscriminate row dumps are prohibited. Generate the audit event in the same database transaction as the audited server-side change when possible. Offline actions retain both workstation occurrence context and server recording context.

## Consequences

- Audit history remains reconstructable and explains business intent.
- Payload design and redaction require deliberate policy.
- Audit events and domain events remain separate concepts even when produced by the same command.
- Retention, access control, and reporting must be designed for potentially large append-only data.
