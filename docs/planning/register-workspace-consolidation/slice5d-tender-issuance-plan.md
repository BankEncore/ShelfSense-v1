# Slice 5D — Tender selection and issuance host migration

Status: **Complete** on `register-workspace-consolidation` ([#89](https://github.com/BankEncore/ShelfSense-v1/issues/89) / PR [#102](https://github.com/BankEncore/ShelfSense-v1/pull/102); remediation PR [#103](https://github.com/BankEncore/ShelfSense-v1/pull/103)). O10 reload requires a card field; Amount → Program → Type → Card order; Enter submits from Amount/card only; Scan-or-enter is the real O10 scan path; O11 rows are visually numbered (not digit shortcuts).

Authority: [plan.md](plan.md), [routing-and-authority.md](routing-and-authority.md), [textual-wireframes.md](textual-wireframes.md) O10 / O11 / P8 / P12, [user-stories.md](user-stories.md), [slice5a-lookup-overlays-plan.md](slice5a-lookup-overlays-plan.md) (lifecycle), Phase 6.7 [pos-workflow.md](../phase4-6-point-of-sale/phase6-pos-mvp/pos-workflow.md) (keyboard — with intentional `+` supersession below).

Issue: [#89](https://github.com/BankEncore/ShelfSense-v1/issues/89). Branch: `89-tender-issuance-overlays`. PR target: `register-workspace-consolidation`.

**ID note:** Wireframe **O11** is tender selection. Manager authorization is **O18** (Slice 5C). **O12–O14** amount-entry overlays are deferred.

## Outcome

Host-migrate gift-card issuance **Add** (O10) and tender **selection** (O11) onto the shared 5A lifecycle. Intentionally supersede only the Phase 6.7 `+` destination so empty-field `+` opens O11 after existing tenderability checks. F1–F5 and command-field amount / reference / gift-card number entry remain. O12–O14 and Slice 7 stay out.

## Boundary statement

> Slice 5D changes tender-type **selection**, not tender **application**. O11 chooses an eligible type; the existing command-field tender mode captures and submits the amount, reference, or stored-value number. O10 moves issuance Add into the shared overlay lifecycle without changing issuance persistence. Slice 5D intentionally supersedes `+` to open O11; F1–F5 and all financial mutation contracts remain otherwise unchanged.

## Scope

| In | Out |
|---|---|
| O10 gift-card issuance **Add** on 5A lifecycle | O10 Edit / Replace Issuance (7B) |
| O11 tender selection (eligible payment/refund types) | O12 / O13 / O14 **amount** overlays |
| Expand/replace `#pos_other_overlay` into O11 | Changing F1–F5 category behavior |
| Keep command-field amount / reference / GC number chrome | O15–O17 tender edit/remove/return-to-sale redesign |
| Keep P8 issuance **list** + Remove | Merging issuances into merchandise lines |
| Eligible issuance scan routing per locked precedence table | Reordering payment / cash-out gift-card scan paths |
| Delete visible basket Add form; keep hidden Turbo mutation form | New tender/issuance mutation services |
| Endpoints stay | Prefix+last-four find as possession |
| Document `+` supersession in 6.7 authority | Full SALE/TENDER keyboard redesign (7C) |

## Locked decisions

| Decision | Choice |
|---|---|
| Overlay inventory | **B — Host migration:** O10 + O11 |
| Amount entry | Command field |
| F1–F5 | Direct into command-field tender chrome |
| `+` | Intentional supersession → O11 (after tenderability checks) |
| O12–O14 | Out |
| Slice 7 | No F1–F5 remap or completed SALE/TENDER keyboard redesign. The `+` → O11 change is owned and tested by Slice 5D |

### Keyboard authority exception

```text
Slice 5D supersedes only the Phase 6.7 + destination:
  + now opens O11 before tender entry (subject to enterTender preconditions).
F1–F5 retain their existing category behavior.
All other keyboard contracts remain locked until Slice 7C.
```

### Launch map

```text
F1 / F2 / F3 → command-field tender chrome
F4 / F5: 0 → feedback; 1 → direct; many → O11 (filtered; invocation other_key | stored_value_key)
Empty-field + / Tender → tenderability checks → O11 (full eligible; source plus)
O11 Choose Tender → entry chrome only; no applied-tender mutation
O11 Escape / secondary → invocation-aware restore; never remove applied tenders
```

### `+` preconditions

```text
nonempty command field → ordinary field input
no commercial content → existing merchandise feedback; no O11
Even Exchange / settlement none → existing completion; no empty O11
payment or refund remaining → O11 with eligible types
no eligible types → local feedback; no empty chooser
```

### O11 invocation

```js
{
  source: "plus" | "other_key" | "stored_value_key",
  priorMode: "sale_entry" | "tender",
  priorTenderTypeId,
  priorCommandValue,
  priorReferenceValue,
  priorGiftCardNumber,
  opener
}
```

| Invocation | Secondary | Restore |
|---|---|---|
| Sale via `+` or F4/F5 | Back to Sale | Sale command |
| Existing tender entry | Back to Tender | Prior type + amount / reference / card |

### O10 transport

- Visible fields in overlay; hidden Turbo form remains mutation transport.
- Delete visible basket Add form only.
- Failures → `pos-issuance-feedback` (persist overlay); success clears O10.
- Program selection drives whether a card number is required (not cashier “number authority” jargon).

### Gift-card scan precedence

```text
O10 open → populate O10 card field
Existing card + payment due → existing gift-card tender path
Cash-out eligible → existing cash-out path
Unknown manual/external in sale-entry issuance context → open O10 + populate card
System-generated program → no card entry
```

Never silently assign an arbitrary program when multiple manual programs exist.

## Implementation sequence

1. Packet (this document + manual stub); README / implementation-plan status; 6.7 `+` note.
2. O11 selection + invocation restore + `+` preconditions.
3. O10 Add overlay + failure transport + scan precedence; remove visible basket Add form.
4. Tests, docs, PR; close #89 after merge.

## Tests

See plan matrix: O11 precondition / restore / eligibility / split-tender survival; O10 activation / reload / program switch / scan precedence / validation persist / double-submit / Remove.

## Explicit non-goals

O12–O14; F1–F5 remap; Slice 7 review/replacement/capping; O10 Replace; cancel-tendering redesign; new financial mutation model; reordering payment/cash-out scans.
