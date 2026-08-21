# Merchandise classification and identifier drafts — superseded

These files are **not** implementation authority.

The earlier drafts described a production-style expand/contract refactor, including class-level GL mappings and staged column drops with backfill reports.

ShelfSense will instead implement **Phase 6.1**, which assumes disposable data and no backward compatibility. Live tax inheritance, product-level industry GTIN, lookup codes, shared-code product selection, and POS/inventory identifier targeting **are** in Phase 6.1. Class-level GL posting is deferred with a documented trigger before journal posting.

Canonical packet:

- [Phase 6.1 README](../../planning/phase6.1-merchandise-classification-and-identifiers/README.md)
- [Plan](../../planning/phase6.1-merchandise-classification-and-identifiers/phase6.1-plan.md)
- [Schema](../../planning/phase6.1-merchandise-classification-and-identifiers/phase6.1-schema.md)
- [User stories](../../planning/phase6.1-merchandise-classification-and-identifiers/phase6.1-user-stories.md)
