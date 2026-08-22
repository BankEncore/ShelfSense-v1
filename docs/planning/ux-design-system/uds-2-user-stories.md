# UDS-2 user stories

Status: **In progress** (backlog for [uds-2-plan.md](uds-2-plan.md))

---

## UDS-2a — Suppliers

### US-UDS-2a-1 — Converge Suppliers admin onto shared primitives

As an implementer, I need Suppliers index/show/form to use shared partials and `ActionButtonHelper` so UDS-2 has an admin CRUD reference.

**Acceptance**

- [x] Index uses page header, data table (or empty state), and solid-brand “New supplier”.
- [x] Show uses breadcrumbs, page header, definition list, status badge, outline Edit, warning-outline Deactivate / solid Reactivate.
- [x] Form uses `.form`, form errors, solid Save/Create, ghost Cancel; Cancel does not change records.
- [x] No `data-turbo-confirm` / `confirm()` on supplier actions.
- [x] Integration tests assert element types, methods, and controlled classes.

---

## UDS-2b — Receiving

### US-UDS-2b-1 — Converge Receiving workspace chrome and actions

As an implementer, I need Receiving views to use explicit action intents without changing scanner/shortcut/Turbo contracts.

**Acceptance**

- [x] Allowlisted Receiving templates use helper or explicit `btn--*` triples for new/changed controls.
- [x] Review triggers vs finals follow button-action-semantics by stage.
- [x] Frozen receiving integration/system tests remain green.

---

## UDS-2c — Transaction history

### US-UDS-2c-1 — History show action group and Line details

As an implementer, I need completed-transaction show to present Reprint / Return / Post-Void with correct prominence and Line details (not audit logs).

**Acceptance**

- [x] Post-Void is danger outline trigger; solid danger only inside review if present.
- [x] Line details disclosure wording (not “audit”).
- [x] Printed receipt markup unchanged; history uses snapshots only.
- [x] History integration tests remain green with markup assertions as needed.

---

## UDS-2d — Dialogs and exit

### US-UDS-2d-1 — Representative review dialogs and matrix evidence

As a reviewer, I need dialog actions on reference surfaces classified by stage and matrix rows updated honestly.

**Acceptance**

- [x] Reference review dialogs: ghost/keep vs solid final via helper.
- [x] Matrix rows partial/conforming with evidence; a11y matrix attached before conforming.
- [x] Packet indexes note UDS-2 progress.
