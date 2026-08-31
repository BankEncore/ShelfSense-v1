# Register surface polish — Visual system

Status: **Accepted**

Typography authority: [ADR-022](../../adr/ADR-022-warm-parchment-visual-tokens.md). Color/token authority: [warm-parchment.md](../ux-design-system/warm-parchment.md).

Reference mockup: [active_transaction.html](../../drafts/register-surface-revamp/active_transaction.html).

## Scope

Applies to Register **screen** chrome on the POS layout:

- Shell header, feedback, enter/closed/selector frames (as touched by allowlist)
- Active workspace: command, basket, issuances, customer, totals, tenders, actions
- F10 menu panel chrome
- Workspace overlay panel chrome
- Optional: Transactions & Receipts filter/table skin

Does **not** apply to:

- Thermal print content grammar (D1/D2) — fonts only via shared local packaging
- `.pos-report-print` / `.pos-shift-end-tape`
- Admin / ops shells

## Region mapping

| Draft region | Live composition |
|---|---|
| Header bar | `shell/_header.html.erb` → `.pos-header--register` |
| Scanner command card | `workspaces/_command.html.erb` → `.pos-command*` |
| Basket card + table | `workspaces/_basket.html.erb` → `#pos_basket`, `.pos-lines`, `.pos-line__*` |
| Aux gift/customer | `workspaces/_issuances.html.erb`, `_basket_aux.html.erb`, `_customer.html.erb` |
| Summary sidebar | `workspaces/_totals.html.erb`, `_tenders.html.erb` → `.pos-summary-rail` |
| Keypad bar | `workspaces/_actions.html.erb` → `.pos-actions*` |
| F10 menu panel | `shell/_menu.html.erb` → `#register-menu`, `.pos-register-menu*` |
| Dialog overlay panel | `workspaces/_overlays.html.erb` → `.pos-overlay*` |

## Typography roles (after S2 packaging)

| Role | Face | Notes |
|---|---|---|
| Register UI body / controls | Plus Jakarta Sans **or** Source Sans 3 | S3 chooses; packet-gated |
| Identifiers / money emphasis (optional) | Noto Sans Mono | Prefer for SKU, amounts if contrast holds |
| Thermal body | Noto Sans Mono | `--font-thermal-body` |
| Thermal display | Plus Jakarta Sans | `--font-thermal-display` |
| Reports / tapes | Inconsolata | Unchanged |

Weights to package (minimum):

- Noto Sans Mono: 400, 700 (add 500/600 only if thermal/screen uses them)
- Plus Jakarta Sans: 700, 800 (add 400/500/600 if Register body adopts Jakarta)

Commit OFL (or equivalent) license text beside the `.woff2` files under `app/assets/fonts/`.

## Visual principles

1. **One composition:** Header, command, main grid, and keypad read as related Warm Parchment cards—not a dashboard of unrelated widgets.
2. **Preserve hierarchy:** Basket title + metadata (UDS-3) stays; selection accent (brand border / wash) remains obvious at arm’s length.
3. **Balance due emphasis:** Summary rail highlights remaining settlement without inventing new totals math.
4. **Grouped shortcuts:** Visual groups already match Slice 7 / UDS-3; polish spacing and brand on primary tender affordances only.
5. **Overlay separation:** Elevated panel + boundary; no workspace blur/disable that breaks scan or focus restore.
6. **ActionButtonHelper:** Intent/style/size vocabulary unchanged.

## CSS variables (expected additions)

Prefer extending existing Warm Parchment tokens. If new Register-only variables are needed, name them under `--pos-*` or reuse `--color-*` / `--space-*` / `--radius-*`. Document any new selector in the PR and in [change-allowlist.md](change-allowlist.md).

Suggested stacks after S3 (illustrative):

```text
--font-pos-ui: "Plus Jakarta Sans", "Source Sans 3", system-ui, sans-serif
--font-pos-mono: "Noto Sans Mono", "Cascadia Code", "Consolas", "SF Mono", "Segoe UI Mono", monospace
```

Admin/ops `:root` `--font-sans` remains Source Sans 3 unless a separate packet says otherwise.
