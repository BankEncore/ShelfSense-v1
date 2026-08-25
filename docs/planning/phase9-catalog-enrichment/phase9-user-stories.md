# Phase 9 — User stories

GitHub-issue-ready stories for catalog enrichment.

## 9.1 — Bibliographic facts

### US-9.1.1 — Optional bibliographic fields

**As** staff with `products.update`  
**I want** optional publisher, imprint, edition, binding, language, pages, series, cover URL, and publication year on a product  
**So that** books can carry bookstore metadata without requiring those fields on sidelines.

**Acceptance:**

- Fields are optional on create and update
- Non-book products remain valid with them blank
- Optimistic locking continues to work

### US-9.1.2 — Contributors and roles

**As** staff  
**I want** to attach contributors with roles (author, illustrator, editor, translator, other)  
**So that** I can record who made the work.

**Acceptance:**

- Find-or-create contributor by normalized name
- Unique `(product, contributor, role)`
- ISBNdb authors map to role `author`

## 9.2 — Match-before-create

### US-9.2.1 — Existing ISBN opens the product

**As** staff with `products.create`  
**I want** an existing industry identifier to open the current product  
**So that** I do not create a duplicate ISBN.

### US-9.2.2 — Unknown book from candidate

**As** staff  
**I want** to create a product from an ISBNdb candidate  
**So that** I do not retype title, ISBN, and list price.

**Acceptance:**

- Generated `222` primary identifier
- Reserved `product_industry` ISBN-13
- Prefill including MSRP as list price
- Staff can edit before save
- Skip lookup and create a blank draft

## 9.3 — Provider

### US-9.3.1 — Stubbed lookup

**As** a developer  
**I want** the ISBNdb client injectable  
**So that** CI never calls the network.

### US-9.3.2 — Unavailable provider

**As** staff  
**I want** a clear message when the API key is missing or ISBNdb fails  
**So that** I can still create a blank product.

## 9.4 — Refresh

### US-9.4.1 — Curated fields are protected

**As** staff  
**I want** refresh to fill blanks only unless I confirm overwrite  
**So that** curated titles and list prices are not clobbered.

## 9.5 — Search

### US-9.5.1 — Find by ISBN or contributor

**As** staff with `products.view`  
**I want** the product index to match industry identifier, subtitle, and contributor name  
**So that** I can find a book without knowing the generated `222`.
