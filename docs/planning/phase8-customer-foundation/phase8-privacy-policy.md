# Phase 8 — Customer privacy and retention (policy only)

Status: **Policy documentation** (August 2026). No automated retention, anonymization, export, or erasure workflows ship in Phase 8.

## Operational collection

ShelfSense collects customer identity and contact data needed to fulfill customer requests and related store operations: display name, optional given/family name, email, phone, preferred contact method, and free-text notes.

Staff should collect only what is needed for contact and fulfillment. Marketing consent and loyalty programs are out of scope.

## Lifecycle and historical records

- **Active** customers may begin new requests.
- **Inactive** customers remain visible in history and cannot begin new requests; reactivation is allowed when not merged.
- **Merged** alias rows retain former contact fields for search and audit. They are not reactivated and do not accept new operational ownership.

Deactivation and merge do **not** erase historical commercial records (requests, orders, receipts, audit events). Completed and cancelled requests may continue to cite the originally recorded customer UUID after a merge ([ADR-023](../../adr/ADR-023-customer-merge.md)).

## Deferred until financial and legal retention is defined

- Customer data export for subject-access requests
- Automated anonymization or hard deletion of customer PII
- Retention schedules tied to stored-value, tax, or buyback records (Phases 10+)

Until those workflows exist, treat customer rows and related commercial facts as durable operational records subject to manual administrative process and future policy ADRs.
