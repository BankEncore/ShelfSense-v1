# Slice 5C — Controlled actions and confirmation

Status: **Implementation-ready.** Slice 5B is on `register-workspace-consolidation` ([#87](https://github.com/BankEncore/ShelfSense-v1/issues/87) / PR [#100](https://github.com/BankEncore/ShelfSense-v1/pull/100)).

Authority: [plan.md](plan.md), [routing-and-authority.md](routing-and-authority.md), [textual-wireframes.md](textual-wireframes.md) O9 / O18 / P14, [user-stories.md](user-stories.md), [slice5a-lookup-overlays-plan.md](slice5a-lookup-overlays-plan.md) (lifecycle), [slice5b-return-overlays-plan.md](slice5b-return-overlays-plan.md) (deferred O18 nesting).

Issue: [#88](https://github.com/BankEncore/ShelfSense-v1/issues/88). Branch: `88-controlled-action-overlays`. PR target: `register-workspace-consolidation`.

**ID note:** Wireframe **O11** is tender selection (5D). Manager authorization is **O18**.

## Outcome

Migrate O9 price / discount / tax onto action-specific chrome on the shared 5A lifecycle. Introduce one confirmation-frame primitive with **authorization** (O18) and **destructive** variants. Nest O18 for controlled actions and unlinked returns without a separate approval side effect. Migrate Cancel Transaction onto the destructive frame with presenter-authored consequences. Only named consumers. Typed `OverlayFailure` routing at the workspace response boundary.

## Scope

| In | Out |
|---|---|
| O9 price / discount / tax content on 5A lifecycle | Quantity editor (command-field mode) |
| Shared confirmation frame (authorization + destructive) | Open-ended P14 migration |
| Nested O18 for controlled-action **and** unlinked-return approval | Separate “manager approved” client side effect |
| Cancel transaction destructive frame (presenter consequences) | Second confirmation for remove-adjustment |
| Direct O9 remove with explicit labels; O18 only if removal needs auth | Cancel tendering / remove tender (Slice 7) |
| Typed `OverlayFailure` vocabulary | Close session, cash-op, post-void, abandon-completion |
| Delete inline `controlApproverWrap` / `unlinkedApproverWrap` | Gift-card issuance (O10) / tender selection (O11) — 5D |
| Invocation isolation + credential lifecycle | New controlled-action domain mutation services |

Endpoints stay. Preserve `#pos_overlay`, Stimulus cancel targets, F9, and cancel service unless this packet explicitly supersedes them. Launch keys remain Phase 6.7 until 7C.

## Named confirmation consumers (closed list)

No additional P14 consumer may enter the PR unless added here by name:

| Consumer | Behavior |
|---|---|
| Price override authorization | O9 → O18 → atomic apply |
| Discount authorization | O9 → O18 → atomic apply |
| Tax-class authorization | O9 → O18 → atomic apply |
| Unlinked-return authorization | Unlinked → O18 → atomic add |
| Cancel transaction | Destructive frame; existing cancel service |
| Remove existing adjustment | **Direct** explicit O9 action |
| Removal requiring authorization | O9 → O18 → atomic remove |
| Additional destructive confirmation for remove | **Out of scope** |
| Cancel tendering / remove tender / close session / abandon completion / cash ops / post-void | **No** |

## One frame, two semantics

```text
Confirmation frame (shared lifecycle chrome)
├── authorization (O18)
│   ├── context summary
│   ├── username / password
│   └── Back to parent · Authorize and Apply / Authorize and Add Return
└── destructive
    ├── presenter-authored consequence
    ├── Keep / safe alternative
    └── destructive commit
```

## Locked contracts

### 1. Invocation record (no secrets)

```js
{
  consumer: "price_override", // line_discount | tax_class_override | unlinked_return | cancel_transaction
  operation: "apply",         // remove | cancel
  parentOverlay,
  formTarget,
  context                     // non-secret display strings only
}
```

Never store password, username/password pair, arbitrary callbacks, markup selectors, or prebuilt HTML.

### 2. Credential lifecycle

```text
Password exists only in O18 fields and the command form during active submission.
It is never retained in the invocation object or restored with parent values.
```

1. Read O18 fields at Authorize.
2. Copy into existing command form immediately before `requestSubmit()`.
3. Submit once (auth + mutation one server operation).
4. Clear hidden password once the request payload is captured.
5. Clear visible + hidden passwords on failure, close, Escape, parent close, disconnect, Turbo replace, or aborted submission.

Username may remain after authentication failure; password never does.

### 3. Auth is not a side effect

O18 does not authorize independently. Credentials ride with the existing command. No durable client “approved” flag. Wireframe “approve then return to form” is superseded.

### 4. O9 parent chrome

| Action | Title | Secondary | Remove label |
|---|---|---|---|
| Price | Change Selling Price | Keep Current Price | Remove Price Override |
| Discount | Apply Line Discount | Keep Current Discount | Remove Line Discount |
| Tax | Change Tax Class | Keep Current Tax Class | Restore Original Tax Class |

- Direct policy: Apply / Remove submit immediately.
- Approval required: Apply / Remove opens O18.
- Prohibited: cannot open O9 or O18.

### 5. O18 context

Tax-class **names** and formatted money—never internal IDs. Escape/Back closes O18 only; parent non-secret values intact; credentials cleared.

### 6. Cancel transaction

Presenter-authored consequences using **quantities**, not DOM row counts. Include gift-card issuances when present; omit absent components. Do not invent tender reversal; honor existing cancel gates.

### 7. Typed failure classification

Closed vocabulary (no message-prefix UI routing):

```text
authorization_failed
authorization_prohibited
parent_validation_failed
stale_transaction
transport_uncertain
```

Turbo / dialog error exposes `data-overlay-error-kind` and `data-overlay-error-field`. Adapter at workspace response boundary maps domain exceptions.

| Kind | Visible layer | Focus |
|---|---|---|
| `authorization_failed` | O18 | Password |
| `authorization_prohibited` | O18 | Username or safe dismiss |
| `parent_validation_failed` | Parent (pop O18) | Invalid field |
| `stale_transaction` | Parent (pop O18) | Local error |
| `transport_uncertain` | Existing recovery | Retry |
| Success | Refreshed workspace | Command / selected line |

### 8. Stack transitions

```text
command → O9 → Escape → command
O9 (approval required) → O18 → Escape/Back → O9
unlinked → O18 → Escape/Back → unlinked
command → cancel destructive → Escape/Keep → command
Closing parent closes O18 and clears invocation + credentials
```

## Implementation sequence

1. Packet (this document + manual stub).
2. Shared frame lifecycle + whitelisted invocation.
3. Cancel Transaction with presenter consequences.
4. O9 action-specific content and direct-policy submission.
5. Controlled-action O18.
6. Unlinked-return O18.
7. Typed failure routing, isolation, credential clearing.
8. Tests, docs, PR; close #88 after merge.

## Tests (required)

Flows plus invocation isolation (direct-policy without O18; prohibited cannot open; cross-parent context/credential isolation; exact form submit; parent close clears invocation; Turbo/disconnect clears credentials; remove direct or O18 per policy; tax-class names in O18; pointer-only; double-submit prevention).

## Explicit non-goals

- Quantity overlay; tender/issuance (5D); Slice 7 confirmations
- Cash / post-void / session leave confirmations
- Destructive second step for remove-adjustment
- New financial/domain mutation model
- Remapping F6/F7; message-prefix failure routing; open-ended P14 migration
