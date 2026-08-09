# ADR-016: Offline return policy

- **Status:** Proposed
- **Date:** 2026-08-09

## Context

Physical possession proves that merchandise was presented for return, but it does not prove eligibility, remaining returnable quantity, original tender, or whether another disconnected workstation already returned the item. The project has not yet selected the acceptable balance between continuity and refund risk.

## Proposed direction

Classify return scenarios independently rather than adopting one blanket offline rule:

- Linked return when the original transaction and local return history are available
- Linked return requiring central retrieval
- No-receipt or otherwise unlinked return
- Return of an individually tracked unit
- Refund to cash, external card, or store credit
- Manager-authorized exception and monetary limits

A plausible baseline is to allow a linked offline return only when the original sale and sufficient return history are locally available. Uncertain, excessive, no-receipt, or high-risk refunds would require connectivity or explicit manager authorization. Central detection of a duplicate or excessive return would quarantine it rather than erase the locally completed fact.

## Decision required

ShelfSense must determine:

1. Which linked returns are allowed offline.
2. Whether no-receipt returns may occur offline.
3. Which refund tenders are allowed offline.
4. Whether offline limits vary by amount, item class, cashier role, or manager approval.
5. How duplicate-return conflicts are financially and operationally corrected.

## Consequences if adopted

- Ordinary verifiable returns can continue during outages.
- Workstations need selected original-sale and return-history data.
- Offline authorization and reconciliation workload increase.
- Card refunds may still depend on external terminal capability even when ShelfSense itself is offline.
