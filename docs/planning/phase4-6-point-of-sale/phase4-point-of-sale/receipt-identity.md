# Receipt identity contract

**Status:** Accepted (implements amended [ADR-006](../../../adr/ADR-006-receipt-numbering.md))

**Authority:** Human-facing POS transaction/receipt identity, display forms, snapshots, and lookup semantics. Sequence allocation rules remain in ADR-006.

Companions: [phase4-plan.md](phase4-plan.md), [phase4-schema.md](phase4-schema.md), [completed-pos-operation-v1.md](completed-pos-operation-v1.md).

---

## 1. One identity, two presentations

Every completed POS transaction has one permanent human-facing identity:

```text
Compact (transaction reference):
S{store_number}-R{workstation_number}-T{receipt_sequence}

Receipt header:
Store: {store_number}   Reg: {workstation_number}   Trans: {receipt_sequence}
```

They represent exactly the same identity. The compact form is the standard ShelfSense **transaction reference** for typing, support, search parsing, and eventual barcode/QR encoding.

Example:

```text
S003-R02-T0018427

Store: 003   Reg: 02   Trans: 0018427
```

---

## 2. Component meanings

| Piece | Source | Notes |
|---|---|---|
| Store number | `stores.store_number` | Stable human store identifier; not the editable store name; not `stores.code` for this reference |
| Workstation number | `workstations.workstation_number` | Stable within store; cashier UI may label it Register / `Reg` |
| Receipt sequence | Allocated at completion | Workstation-scoped; field name `receipt_sequence`, never `transaction_id` |

Internal technical identity remains:

```text
pos_transactions.id   # UUIDv7
```

Customer/cashier header label `Trans:` means the padded receipt sequence, not the UUID.

---

## 3. Padding

Minimum zero-padded display widths (not structural maxima):

| Component | Minimum digits |
|---|---|
| Store number | 3 |
| Workstation number | 2 |
| Receipt sequence | 7 |

```text
store 3, workstation 2, sequence 18427
→ S003-R02-T0018427
```

```text
store 1002, workstation 2, sequence 18427
→ S1002-R02-T0018427
```

Parsers must not assume fixed widths; they recognize `S` / `R` / `T` segments separated by `-`.

---

## 4. Durability and snapshots

Store numbers and workstation numbers must remain historically stable once used on a completed transaction.

Completed transactions should persist at least:

```text
store_id
workstation_id
receipt_sequence
store_number_snapshot
workstation_number_snapshot
```

The compact reference is derived:

```text
format(store_number_snapshot, workstation_number_snapshot, receipt_sequence)
```

Storing a denormalized `transaction_reference` / `receipt_number` string is optional if always regenerable from snapshots.

---

## 5. Uniqueness

```text
UNIQUE(store_id, workstation_id, receipt_sequence)
```

These are both valid and distinct:

```text
S003-R01-T0000123
S003-R02-T0000123
```

Sequences are never reused. Gaps are acceptable.

---

## 6. Display guidance

### Printed receipt (Phase 5+)

Prefer the separated header for readability:

```text
Store: 003   Reg: 02   Trans: 0018427
```

Optionally include the compact reference elsewhere (footer or barcode payload). Both need not be equally prominent on a small receipt.

### Lookup / support

Prefer the compact reference as the primary typed/scanned value.

---

## 7. Search behavior

The general search box should recognize:

```text
S003-R02-T0018427
→ store_number=3, workstation_number=2, receipt_sequence=18427
→ exact transaction
```

Advanced search may expose components separately and allow progressive narrowing:

| Input | Result |
|---|---|
| Full compact reference | Exact match |
| Store + Reg + Trans | Exact match |
| Store + Trans only | Candidates across workstations |
| Trans only | Candidates across stores/workstations |

Show candidates when the supplied components are not globally unique.

Phase 4 need only allocate identity and prove reconstruction; rich search UI may wait for later POS phases.

---

## 8. Scanning

Barcode/QR may encode the compact reference so printed and typed values match. Prefer that over encoding a raw UUID for ordinary POS use. Richer payloads that also carry the UUID remain optional later.

---

## 9. `CompletedPosOperation` receipt block

```text
receipt:
  sequence                      # integer receipt_sequence
  store_number                  # snapshot string as displayed without requiring fixed width
  workstation_number            # snapshot
  reference                     # optional derived compact form S…-R…-T…
```

Phase 4 completion must populate sequence and number snapshots (and may include `reference`).

---

## 10. Schema prerequisite

`workstations` must expose a durable per-store `workstation_number` suitable for the `R` component (unique within `store_id`, normalized consistently with `store_number` practice).

Do not use editable `workstations.name` in the reference. Do not use free-form alphanumeric `workstations.code` as the `R` value unless it is constrained to be that durable number—prefer an explicit `workstation_number` column parallel to `stores.store_number`.

---

## 11. Governing statement

> Each completed POS transaction receives a permanent workstation-scoped receipt sequence. The human-facing transaction reference combines the originating store number, workstation number, and receipt sequence as `S{store}-R{workstation}-T{sequence}`, with minimum display padding of three, two, and seven digits respectively.
>
> Receipts may present the same identity as separate fields (`Store` / `Reg` / `Trans`) for readability. Both presentations refer to the same completed transaction identity.
>
> The composite reference is intended for human entry, scanning, support, and transaction lookup. ShelfSense also permits searches using individual components. The POS transaction UUID remains the global technical identity and is distinct from the workstation-assigned receipt sequence.
>
> Display padding is a minimum, not a numeric limit. Store numbers, workstation numbers, and receipt sequences are stable historical identifiers and are not reused.
