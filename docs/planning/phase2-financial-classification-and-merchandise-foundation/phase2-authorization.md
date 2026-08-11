# Phase 2 Authorization Contract

This document is the authoritative Phase 2 permission catalog and role grants. Phase 1 keys remain documented in [phase1-authorization.md](../phase1-operational-foundation/phase1-authorization.md). Both sets are seeded from `Authorization::PermissionCatalog`.

Phase 2 merchandise and financial reference data are organization-wide master data. Create, update, and lifecycle permissions use `scope_type: global` and require a global role assignment. View and catalog-lookup permissions use `scope_type: either` so store-scoped roles can read the catalog in an active store without granting organization-wide administration.

## Permission verbs

| Verb | Meaning |
|---|---|
| `view` | Read and list |
| `create` | Create new records |
| `update` | Non-lifecycle edits (does not include deactivate/discontinue) |
| `deactivate` | Soft-deactivate or reactivate reference/configuration records (same permission family) |
| `discontinue` | Move products/variants to discontinued (lifecycle) |

`products.create` authorizes product creation whether the user enters an external primary identifier or chooses Generate ShelfSense identifier (`222`). There is no separate `products.generate_identifier` permission.

## Permission catalog

| Permission | scope_type | group_key |
|---|---|---|
| `gl_accounts.view` | either | gl_accounts |
| `gl_accounts.create` | global | gl_accounts |
| `gl_accounts.update` | global | gl_accounts |
| `gl_accounts.deactivate` | global | gl_accounts |
| `tax_classes.view` | either | tax_classes |
| `tax_classes.create` | global | tax_classes |
| `tax_classes.update` | global | tax_classes |
| `tax_classes.deactivate` | global | tax_classes |
| `departments.view` | either | departments |
| `departments.create` | global | departments |
| `departments.update` | global | departments |
| `departments.deactivate` | global | departments |
| `merchandise_classes.view` | either | merchandise_classes |
| `merchandise_classes.create` | global | merchandise_classes |
| `merchandise_classes.update` | global | merchandise_classes |
| `merchandise_classes.deactivate` | global | merchandise_classes |
| `merchandise_categories.view` | either | merchandise_categories |
| `merchandise_categories.create` | global | merchandise_categories |
| `merchandise_categories.update` | global | merchandise_categories |
| `merchandise_categories.deactivate` | global | merchandise_categories |
| `merchandise_conditions.view` | either | merchandise_conditions |
| `merchandise_conditions.create` | global | merchandise_conditions |
| `merchandise_conditions.update` | global | merchandise_conditions |
| `merchandise_conditions.deactivate` | global | merchandise_conditions |
| `products.view` | either | products |
| `products.create` | global | products |
| `products.update` | global | products |
| `products.discontinue` | global | products |
| `product_variants.view` | either | product_variants |
| `product_variants.create` | global | product_variants |
| `product_variants.update` | global | product_variants |
| `product_variants.discontinue` | global | product_variants |
| `merchandise.lookup` | either | merchandise |
| `merchandise.import` | global | merchandise |

## Role grants

| Role | Phase 2 permissions |
|---|---|
| `system_administrator` | Entire Phase 2 catalog |
| `store_manager` | All `*.view` keys above, plus `merchandise.lookup` |
| `associate` | `merchandise.lookup`, `products.view`, `product_variants.view` |

## Seed ownership

| Kind | Contents |
|---|---|
| Production baseline | Permissions, system roles, and only reference codes with application-level semantics |
| Bootstrap / demo | Example GL accounts, tax classes, departments, merchandise classes/categories (organization-specific; not universal production records) |
| Test fixtures | Records required only by automated tests |

Merchandise conditions are production-seeded only if application code hard-depends on particular codes. Prefer organization setup to create used-variant condition tiers (`like_new`, `good`, and so on) as ordinary reference data.
