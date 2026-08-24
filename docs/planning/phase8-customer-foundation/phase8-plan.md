# Phase 8 — Customer foundation plan

Status: **Complete** on `main` (PR #42, merge `b5ed590`).

## Goal

Make customer identity reliable enough for **stored value** (Phase 10) and **buyback** (Phase 12) without building CRM, marketing, or multi-contact management.

## Exit outcome

> Staff can quickly find or create the correct customer using name, phone, or email; the system warns about likely duplicates; authorized staff can safely merge duplicates without losing request history; and later customer-owned financial relationships can rely on one durable canonical identity.

## Scope boundary

| In scope | Out of scope (defer) |
|---|---|
| Identity, lookup, normalization | Multiple phones/emails |
| Single email + phone + preference | Postal addresses |
| Duplicate detection + staff choice | Receipt-delivery preferences |
| Transactional merge + tombstone | Marketing consent / subscriptions |
| `active` / `inactive` / `merged` lifecycle | Note categories / fine-grained visibility |
| Audit for contact, lifecycle, merge | Automated retention / anonymization / privacy requests |
| Stored-value **identity** contract (doc only) | Tax exemption (separate POS policy slice) |
| | Customer purchase history workspace (Phase 13) |
| | Loyalty, segmentation, CRM |

## Slices

### 8.1 — Customer identity and lookup

**Build on:** `display_name`, `active`, `lock_version`, admin CRUD, request lookup (`ILIKE` today).

**Add:**

- Optional `given_name`, `family_name` (never required; `display_name` remains authoritative operational label).
- When `display_name` is blank at save, derive it as `Family, Given` (or the single non-blank part). Manual `display_name` is never overwritten.
- Admin customer index search aligned with request lookup patterns.
- Normalized search:
  - partial match on display name (and optional structured names);
  - exact match on normalized email and phone.
- Preserve optimistic locking and existing audit actions.

**Tests:** model normalization; integration search matrix; authorization unchanged.

### 8.2 — Essential contact methods

**Keep:** single `email`, single `phone`.

**Add:**

- Persisted normalized email/phone for lookup and duplicate comparison (see [phase8-schema.md](phase8-schema.md)).
- `preferred_contact_method`: `phone`, `email`, or `none`.
- Validation: selected preference requires a corresponding populated value.
- Enforce Phase 7 policy where contact is operationally required: at least one of email or phone when creating a customer request (application layer; not necessarily on bare customer create).

**Defer:** multiple contacts, labels (home/work/mobile), address fields.

### 8.3 — Duplicate prevention and safe merge

**Highest priority slice.** Policy authority: [ADR-023](../../adr/ADR-023-customer-merge.md).

**Add:**

- `Customers::SuggestDuplicates` — strong match on normalized phone/email; weaker match on normalized display name. Merged aliases are excluded as independent candidates.
- Create/edit UI: show suggestions; staff chooses **use existing**, **create anyway**, or **cancel**.
- Merge review + confirmation: source vs survivor profile diffs, active relationship counts, proposed reassignment counts, required reason, stale-state revalidation. No ordinary unmerge.
- `Customers::MergeCustomers` — transactional merge under `customers.manage`:
  - survivor + source; reason; actor; idempotency key.
  - Lock source, survivor, and direct aliases of the source in deterministic UUID order; flatten aliases onto survivor; then tombstone source.
  - Explicit call to `Customers::ReassignActiveRequests` — reassign only `CustomerRequest::ACTIVE_STATUSES`; preserve `customer_id` on completed/cancelled requests.
  - Survivor profile remains authoritative; merge does not copy or concatenate profile fields.
  - `Customer#canonical` is a single hop to an active-or-inactive survivor (chains forbidden after flatten).
  - Append-only merge audit with reassignment counts and alias-repoint counts.
- Operational search matching former alias contact data returns the **canonical survivor** with a “matched former record” indication.
- Source record retained as tombstone/alias (no physical delete).

**Explicit non-goals:** generic FK rewriter; callback/plugin reassignment registry; automatic profile field reconciliation.

**Tests:** duplicate suggestions; merge happy path; alias flattening; cycle/self-merge rejection; active vs completed/cancelled request policy; concurrent request create vs merge; concurrent merges; alias search returns survivor once; profile fields not combined; stale review rejection; merged-alias operational guards; idempotent retry and payload mismatch; audit redaction.

### 8.4 — Minimal lifecycle and governance

**Lifecycle:**

| State | Rule |
|---|---|
| `active` | Default; may begin new requests |
| `inactive` | Visible in history; cannot begin new requests (existing guard) |
| `merged` | `merged_into_customer_id` set; resolves to survivor; not reactivatable |

**Add:**

- Block reactivation of merged customers.
- Block new requests against merged aliases (resolve to survivor or reject).
- Document privacy/retention **policy only** (no automation): operational collection, historical commercial records not erased by deactivation, export/deletion deferred until financial/legal retention is defined.

**UX adoption:** include [ux-adoption-template.md](../ux-design-system/ux-adoption-template.md) section when customer admin screens change materially.

## UX adoption targets

- **Screens created or materially changed:** `admin/customers/index`, `admin/customers/_form`, `admin/customers/show`, `admin/customers/merge_review`
- **Current migration-matrix state:** `partial` (search, merge review, lifecycle badges)
- **Accepted primitives and interaction contracts:** `page_header`, breadcrumbs, `data_table`, `definition_list`, `ActionButtonHelper`, filters form pattern from inventory index
- **Applicable automated evidence:** deferred until customer admin surfaces stabilize post-merge to `main` (optional UDS reference suite follow-up)
- **Matrix rows to update after validation:** `admin/customers/**` in [migration-matrix.md](../ux-design-system/migration-matrix.md)

### Rules

- New screens begin with accepted UDS primitives.
- A materially changed legacy screen becomes that phase's migration responsibility.
- Unrelated neighboring screens do not enter scope automatically.
- New interaction patterns require their own specification.
- Evidence and matrix updates ship in the same PR as the feature.
- Inherited Warm Parchment colors never establish verification or conformance.

## Stored-value boundary

Phase 8 does **not** create stored-value accounts. See [phase8-stored-value-boundary.md](phase8-stored-value-boundary.md).

## ADR and documentation triggers

- **Accepted ADR:** [ADR-023](../../adr/ADR-023-customer-merge.md) customer merge policy (tombstone, alias flattening, active-only request reassignment, profile non-combination, alias search, irreversibility, financial-domain exceptions).
- Update data dictionary / schema reference with new columns and merge audit actions.
- Amend roadmap Phase 8 (done in same planning pass).
- Phase 7 spec §7.4 duplicate note: superseded by Phase 8 implementation, not silent behavior change.

## Sequencing

```text
8.1 identity + lookup
  → 8.2 contact normalization + preference
  → 8.3 duplicates + merge
  → 8.4 lifecycle guards + governance doc
```

8.3 may start normalization work from 8.2; do not ship merge without duplicate UX and request reassignment tests.

## Parallel work

Phase 8 has shipped. [Phase 9](../roadmap.md#phase-9--catalog-and-bibliographic-enrichment) is the next domain phase and must not reopen customer admin contracts except where a later phase explicitly extends merge consumers.

## Acceptance

1. Staff can find customers by partial name and exact normalized phone/email on admin index and request lookup.
2. Duplicate warnings appear on create/edit with explicit staff resolution.
3. Authorized merge flattens existing aliases, reassigns **active** `customer_requests` only, preserves completed/cancelled FKs, tombstones source, audits counts, and leaves no chains.
4. Inactive and merged customers cannot start new requests; operational lookup by former alias contact returns the survivor.
5. Phase 10 identity contract documented and testable via `Customer#canonical` and active guards.
6. No stored-value ledger tables introduced.
