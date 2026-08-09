# ADR-017: Business-day closure with unreported workstations

- **Status:** Proposed
- **Date:** 2026-08-09

## Context

A workstation may be offline, damaged, or unavailable when the store needs to close its business day. Immediate final closure risks omitting later-synchronized activity; indefinite blocking can prevent operational completion.

## Proposed direction

Allow a workstation to close its own session offline. A central business day normally moves to `closing` or `pending_terminal_sync` while known sessions or workstation activity remain unreported. Final closure normally waits for all sessions.

Permit an authorized administrator to force closure when a workstation cannot report. Late activity retains its originally recorded business date and creates an explicit post-close adjustment or amended report; it is never silently reassigned to another business day. Forced closure and later amendment are audited.

## Decision required

ShelfSense must determine:

1. Who may force closure and what reason/evidence is required.
2. Whether a waiting period or escalation is required.
3. Which reports are provisional, final, or amended.
4. How late tenders, cash movements, inventory effects, and financial postings appear.
5. Whether a reopened day is ever allowed or amendment is the only correction mechanism.

## Consequences if adopted

- A lost workstation cannot block operations indefinitely.
- “Final” reporting must support explicit amendments or post-close adjustments.
- Late activity preserves its true business date.
- Close-state UI and accounting exports must distinguish pending, forced, and amended results.
