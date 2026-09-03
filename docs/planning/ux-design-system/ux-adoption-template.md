# UX adoption targets (template)

Copy this section into feature-phase plans that create or materially change screens.

## UX adoption targets

- **Screens created or materially changed:** _(list paths)_
- **Current migration-matrix state:** _(legacy / partial / verified-automated / conforming / locked)_
- **Accepted primitives and interaction contracts:** _(ActionButtonHelper intents, shared partials, ops/register contracts as applicable)_
- **Applicable automated evidence:** _(Layer A axe / Layer B workflow / Layer C layout; cite test files)_
- **Matrix rows to update after validation:** _(link migration-matrix rows)_

### Rules

- **Feature-led adoption:** new screens use the current accepted UDS primitives. Existing screens adopt those primitives when the feature that owns them is next in scope. Do not sweep unrelated templates in the same PR. **Accepted exception:** the [Admin Page Frame Program](../admin-page-frame/README.md) established a shared page-frame API and migrated Adjustment Reasons, Customer core, and Product show/new/edit. It does not authorize a general restyle. Slice 1 and Customer core are **Implemented on `main`**. Product show is [product-show.md](../admin-page-frame/product-show.md).
- New screens begin with accepted UDS primitives (tokens, ActionButtonHelper, shared partials, type roles, composition utilities, compact grouped admin nav as applicable).
- A materially changed legacy screen becomes that phase's migration responsibility.
- Unrelated neighboring screens do not enter scope automatically.
- New interaction patterns require their own specification.
- Evidence and matrix updates ship in the same PR as the feature.
- Inherited Warm Parchment colors never establish verification or conformance.
- Printed receipt and Register completion stay locked unless the phase explicitly owns that surface.
