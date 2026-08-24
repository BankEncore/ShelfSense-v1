# Phase 8 — User stories

GitHub-issue-ready stories for the customer foundation MVP.

## 8.1 — Identity and lookup

### US-8.1.1 — Structured optional names

**As** staff with `customers.manage`  
**I want** optional given and family name fields on a customer  
**So that** I can record name parts without changing the operational `display_name`.

**Acceptance:**

- `given_name` and `family_name` are optional
- `display_name` remains required and is the primary label
- Optimistic locking and existing create/update audit continue to work

### US-8.1.2 — Admin customer index search

**As** staff with `customers.view`  
**I want** to search the customer index by name  
**So that** I can find a customer without scrolling the full list.

**Acceptance:**

- Query param `q` filters by partial match on `display_name`, `given_name`, and `family_name`
- Empty query lists all customers (existing order)
- Unauthorized users cannot access the index

### US-8.1.3 — Shared customer search

**As** a developer  
**I want** one `Customers::Search` service for admin index and request lookup  
**So that** search behavior stays consistent as Phase 8 adds normalization and alias resolution.

**Acceptance:**

- Request customer lookup and customer index use the shared service
- Existing request lookup tests remain green

---

## 8.2 — Essential contact methods

### US-8.2.1 — Normalized email and phone

**As** staff  
**I want** email and phone stored in normalized form for matching  
**So that** duplicate detection and exact search ignore formatting noise.

**Acceptance:**

- `email_normalized` is lowercased/trimmed
- `phone_normalized` is E.164 when parseable; otherwise blank while display `phone` may remain
- Existing rows are backfilled on migrate

### US-8.2.2 — Preferred contact method

**As** staff  
**I want** to set preferred contact method to phone, email, or none  
**So that** later workflows know how to reach the customer.

**Acceptance:**

- Preference `phone` requires a populated phone
- Preference `email` requires a populated email
- Default is `none`

### US-8.2.3 — Contact required for requests

**As** staff creating a customer request  
**I want** the system to require at least one of email or phone on the customer  
**So that** we can contact them about location and pickup.

**Acceptance:**

- `Customers::CreateRequest` rejects customers with neither email nor phone
- Customer row is locked and revalidated immediately before request persistence

---

## 8.3 — Duplicates and merge

### US-8.3.1 — Duplicate suggestions

**As** staff creating or editing a customer  
**I want** warnings when phone, email, or name looks like an existing customer  
**So that** I can use the existing record instead of creating a duplicate.

**Acceptance:**

- Strong match on normalized phone or email
- Weaker match on normalized display-name token overlap (≥2 tokens)
- Staff choose: use existing, create/save anyway, or cancel
- Merged aliases are not independent suggestions

### US-8.3.2 — Safe customer merge

**As** staff with `customers.manage`  
**I want** to merge a duplicate into a survivor with review and confirmation  
**So that** active requests move to one identity without rewriting completed history.

**Acceptance:**

- Review shows profile diffs, active relationship counts, alias counts, required reason
- Merge flattens existing aliases onto the survivor (no chains)
- Only active requests are reassigned; completed/cancelled FKs preserved
- Source is tombstoned (`merged_into_customer_id`, inactive)
- Idempotent; no ordinary unmerge
- Audit `customers.merge` with counts

### US-8.3.3 — Alias operational search

**As** staff looking up a customer by an old phone number  
**I want** to land on the canonical survivor  
**So that** I do not select a dead duplicate account.

**Acceptance:**

- Operational search matching alias contact returns the survivor once with former-match indication
- Merged aliases cannot be selected as operational targets

---

## 8.4 — Lifecycle and governance

### US-8.4.1 — Merged lifecycle guards

**As** staff  
**I want** merged customers blocked from reactivation and new requests  
**So that** operational work always uses the canonical survivor.

**Acceptance:**

- Merged customers cannot be reactivated
- New requests resolve to or require a canonical active customer
- Show page displays Active / Inactive / Merged badge

### US-8.4.2 — Privacy policy documentation

**As** an operator  
**I want** documented privacy/retention policy for customer data  
**So that** expectations are clear before automation exists.

**Acceptance:**

- Policy doc only (no automated erasure/export in Phase 8)
- Phase 7 §7.4 notes Phase 8 supersedes duplicate-warn intent
