# POS Domain Specification: Customer Display

**Design status:** Core non-authoritative customer-display model decided **Implementation status:** Deferred; not required for initial operational POS **Initial delivery:** Optional Phase 6B — POS Productization **Related specifications:** Transactions, Transaction Lines, Pricing, Discounts, Tax, Tenders, Receipts, Local Persistence **Related workflows:** Add Merchandise, Complete Transaction, Customer Display Presentation

---

## 1\. Purpose

This specification defines the optional customer-facing display used alongside a ShelfSense POS workstation.

It establishes:

* the role and authority of the customer display;  
* which transaction information may be presented;  
* working versus completed transaction presentation;  
* communication with the authoritative POS process;  
* failure and recovery behavior;  
* privacy expectations;  
* boundaries with receipt rendering and transaction processing.

This specification does **not** define:

* a specific display technology;  
* operating-system monitor configuration;  
* hardware selection;  
* advertising/signage systems;  
* customer touch interaction;  
* payment-terminal UI;  
* receipt delivery;  
* exact visual design.

Those may be defined later if concrete requirements emerge.

---

## 2\. Governing principle

The customer display is a presentation surface, not a POS authority.

> **The authoritative POS application determines transaction state and calculations. The customer display only presents information supplied by that application.**

Conceptually:

```
Authoritative POS
    │
    ├── working transaction
    ├── prices / discounts
    ├── tax
    ├── totals
    └── completion result
          │
          ↓
    Customer Display
```

The display must not independently calculate, persist, approve, or complete business operations.

---

## 3\. Optional capability

ShelfSense must operate fully without a customer display.

A missing, disconnected, or failed customer display must not prevent ordinary POS functions such as:

* scanning merchandise;  
* pricing;  
* tendering;  
* completing a transaction;  
* printing a receipt;  
* offline operation.

The customer display is an enhancement to the cashier/customer experience, not part of the transaction-completion boundary.

---

## 4\. No business authority

The customer display must not become authoritative for:

* transaction lines;  
* quantity;  
* selling price;  
* discounts;  
* tax;  
* tender amounts;  
* receipt identity;  
* transaction completion;  
* inventory effects.

It displays values already determined by the authoritative POS application.

Incorrect:

```
POS sends items
    ↓
Customer display calculates total
    ↓
POS trusts display total
```

Correct:

```
POS calculates total
    ↓
Customer display presents total
```

---

## 5\. No independent persistence requirement

The customer display does not require its own durable copy of POS business history.

If it maintains temporary presentation state, that state is disposable.

After restart or reconnection, the authoritative POS application supplies the current display state again.

Completed transaction history remains owned by the POS/local database and organization server.

---

## 6\. Working transaction presentation

While a transaction is open, the display may show customer-relevant working state such as:

* merchandise descriptions;  
* quantity;  
* selling price;  
* line discounts;  
* transaction discounts;  
* subtotal;  
* tax;  
* running total.

Example:

```
The Left Hand of Darkness      $18.00
The Hobbit          2 × $12    24.00

Discount                       -4.00
Subtotal                       38.00
Tax                             2.28

TOTAL                          $40.28
```

The exact visual format is deferred.

---

## 7\. Working state is provisional

Information displayed before completion is not an immutable financial fact.

A cashier may still:

* change quantity;  
* void a line;  
* apply an authorized price override;  
* apply a discount;  
* cancel the transaction.

The customer display therefore reflects the current authoritative working transaction rather than preserving each intermediate display state as business history.

---

## 8\. Sale and return direction

The display should clearly distinguish sale and return lines when mixed transactions are supported.

For example:

```
RETURN
Book A                         -$20.00

PURCHASE
Book B                          $30.00

BALANCE DUE                     $10.00
```

The display consumes line direction from Transaction Lines.

It does not infer returns from negative quantities.

---

## 9\. Pricing and discounts

Displayed pricing comes from the POS Pricing and Discount domains.

The customer display may show:

* selling price;  
* discount;  
* promotional savings;  
* resulting line amount.

Whether reference/list price or price-override information is customer-visible is a presentation-policy decision.

Internal authorization details should not be exposed merely because they exist in the transaction.

---

## 10\. Tax

The display may show:

* subtotal;  
* tax total;  
* component tax where useful or required;  
* transaction total.

It consumes the POS tax result.

It does not independently resolve tax classes, select tax rules, or calculate tax.

---

## 11\. Tendering

During tender, the display may show customer-relevant settlement information such as:

```
Total                 $40.28
Cash                  $50.00
Change                 $9.72
```

or mixed-tender information where supported.

Tender semantics and calculations remain owned by `tenders.md`.

---

## 12\. Sensitive information

The customer display should receive only information required for customer-facing presentation.

It should not expose operational or sensitive data such as:

* cashier permissions;  
* manager approval details;  
* inventory cost;  
* inventory valuation;  
* internal reconciliation conditions;  
* synchronization status;  
* installation credentials;  
* customer information unrelated to the transaction.

Future Card integrations must not expose prohibited payment-card data through the customer display.

---

## 13\. Customer identity and privacy

If future customer functionality presents information such as:

* customer name;  
* loyalty status;  
* reservation information;  
* account credit;

the display must deliberately limit what is visible to nearby customers.

Customer-specific presentation should be added only when a concrete workflow requires it.

The initial customer display does not require customer identity presentation.

---

## 14\. Completion presentation

After successful transaction completion, the POS may instruct the customer display to present a final state such as:

```
TOTAL                    $40.28
CASH                     $50.00
CHANGE                    $9.72

Thank you
```

This state reflects the already-completed transaction.

The display does not determine whether completion succeeded.

---

## 15\. Completion occurs before final display

The customer display is outside the transaction commit boundary.

Conceptually:

```
commit completed transaction
        ↓
transaction is final
        ↓
update customer display
        ↓
print receipt / peripheral actions
```

If the display cannot show the final state, the completed transaction remains completed.

---

## 16\. Display failure

A customer-display failure must not:

* roll back a transaction;  
* prevent receipt identity assignment;  
* change tender state;  
* change inventory effects;  
* reopen a completed transaction.

Example:

```
sale committed
customer display disconnects
```

Result:

```
sale = completed
display = unavailable
```

The cashier POS may indicate the display problem operationally.

---

## 17\. Reconnection

After a temporary display failure or restart, the POS should be able to resend the current presentation state.

If an open transaction still exists:

```
display reconnects
    ↓
POS sends current working transaction
```

The display does not need to reconstruct missing intermediate events.

This favors **state synchronization** over a requirement to replay every UI event.

---

## 18\. State-oriented presentation

The customer-display interface should primarily communicate:

> **What should the display show now?**

rather than requiring the display to reproduce the POS business state by interpreting a long event stream.

Conceptually:

```
CustomerDisplayState
├── mode
├── lines
├── subtotal
├── discounts
├── tax
├── total
├── tender/change
└── customer message
```

This is a presentation contract, not a business-operation contract.

---

## 19\. Display modes

A minimal conceptual set may include:

```
idle
transaction
tender
completed
```

Additional modes should only be introduced for concrete presentation needs.

### Idle

No active customer transaction.

May show:

* store branding;  
* simple welcome message.

### Transaction

Displays current working sale/return information.

### Tender

Emphasizes amount due and customer settlement information.

### Completed

Shows final total/change/thank-you information briefly before returning to idle.

Exact state names are not required to become persisted domain enums.

---

## 20\. Advertising and promotional signage

Idle-screen branding or promotional material may eventually be supported.

This is secondary presentation content.

It must not:

* interfere with transaction information;  
* become required for POS operation;  
* turn Customer Display into a general content-management domain prematurely.

A full digital-signage system is out of scope unless separately justified.

---

## 21\. Customer interaction

The initial customer display is **view-only**.

It does not collect:

* customer confirmations;  
* signatures;  
* tips;  
* donations;  
* loyalty enrollment;  
* receipt-delivery choices;  
* payment input.

If interactive customer workflows are added later, they require explicit contracts describing:

```
customer request
→ authoritative POS validation
→ accepted business action
```

The display itself must still not directly mutate transaction authority.

---

## 22\. Payment terminal distinction

A processor-controlled Card terminal is not the ShelfSense customer display.

A payment terminal may have:

* its own secure UI;  
* processor-controlled workflow;  
* Card-specific interaction.

ShelfSense may coordinate with it, but `customer-display.md` should not attempt to define payment-terminal security or behavior.

---

## 23\. Receipt distinction

The customer display and receipt may present similar transaction information, but they serve different purposes.

### Customer display

* temporary;  
* live;  
* may show mutable working state;  
* not durable customer evidence.

### Receipt

* represents a completed transaction;  
* permanent receipt identity;  
* historically reproducible.

The customer display must not be treated as a substitute for receipt history.

---

## 24\. Offline behavior

Customer-display operation must not require access to the organization server.

If the POS can perform the transaction offline, the customer display can present the locally available transaction state.

Conceptually:

```
Local POS
    ↓ local presentation channel
Customer Display
```

Central connectivity is unnecessary.

---

## 25\. Communication boundary

The exact communication mechanism is intentionally not part of the domain model.

Possible implementations might include:

* second local window;  
* second monitor;  
* local IPC;  
* loopback/local-network web view;  
* separate lightweight process.

The important requirements are:

* POS remains authoritative;  
* display failure is isolated;  
* business completion does not depend on display acknowledgment.

---

## 26\. Trust boundary

The POS must treat data received from an optional customer-display process as untrusted unless a future interactive workflow explicitly validates it.

For the initial view-only design, the simplest model is one-way conceptual authority:

```
POS
  ↓
Customer Display
```

No customer-display response is needed for ordinary transaction completion.

---

## 27\. Version compatibility

If the customer display is implemented as a separately versioned component, the POS and display must agree on a supported presentation contract.

An incompatible display should become unavailable rather than affecting transaction processing.

Exact version-negotiation behavior belongs to implementation/productization.

---

## 28\. Logging and diagnostics

Customer-display availability and communication errors may be logged for support.

Such diagnostics are operational data, not POS financial history.

Detailed telemetry requirements belong to productization.

---

## 29\. Domain ownership

### Customer Display owns

* customer-facing live presentation;  
* display modes;  
* presentation-state contract;  
* failure isolation;  
* display-specific privacy constraints.

### Transactions owns

* transaction lifecycle and current/completed facts.

### Transaction Lines owns

* sale/return line semantics.

### Pricing and Discounts own

* displayed price/discount source facts.

### Tax owns

* displayed tax facts.

### Tenders owns

* amount due, tender, and change facts.

### Receipts owns

* durable completed customer receipt representation.

### Local Persistence owns

* durable POS state.

### Platform/Productization owns

* physical monitor/process setup;  
* IPC;  
* diagnostics;  
* supported hardware configurations.

---

## 30\. Phase delivery

Customer Display is not required to prove the peer/offline architecture in Phase 4 and is not required for the first operational Cash sale in Phase 5\.

It may be added during Phase 6B productization when:

* primary POS workflows are stable;  
* final visual design is clearer;  
* supported hardware configurations are being defined.

Adding it later must not require changes to transaction authority or completion semantics.

---

## 31\. Pending decisions

### 31.1 Physical architecture

Determine whether the first implementation uses:

* second Terminal.Gui/window surface;  
* browser/web view;  
* separate process;  
* another lightweight renderer.

### 31.2 Supported platforms

Determine customer-display support across:

* Windows;  
* macOS;  
* Linux.

It need not be available on every supported cashier-POS environment if the hardware configuration does not support it.

### 31.3 Customer-display visual design

Define typography, line density, totals emphasis, and idle appearance during UI/productization work.

### 31.4 Idle content

Determine whether the idle state supports only store branding or also limited promotional content.

### 31.5 Future customer interaction

Treat signatures, tipping, loyalty, donations, and receipt-delivery selection as separate future requirements rather than designing a generic interaction framework now.

---

## 32\. Core invariants

1. **The customer display is optional and non-authoritative.**  
2. **POS operation must remain fully functional without it.**  
3. **The authoritative POS application performs all financial and business calculations.**  
4. **The display never independently calculates transaction totals, tax, discounts, or tender settlement.**  
5. **Working display state is provisional until the transaction completes.**  
6. **The display receives only customer-relevant information.**  
7. **Sensitive internal and authorization information is not exposed merely because it exists locally.**  
8. **Transaction completion does not depend on customer-display acknowledgment.**  
9. **Customer-display failure never rolls back or reopens a completed transaction.**  
10. **After reconnection, the POS may resend current presentation state rather than replaying every missed display event.**  
11. **Initial customer-display behavior is view-only.**  
12. **A Card payment terminal is a separate system from the ShelfSense customer display.**  
13. **The customer display is not a substitute for the durable receipt.**  
14. **The display must work from local POS state without central connectivity.**  
15. **Implementation technology must not become part of POS business authority.**

---

## 33\. Acceptance examples

### Example A — ordinary sale

Given an active transaction contains:

```
Book A      $15.00
Book B      $20.00
Tax          $2.10
Total       $37.10
```

then the customer display may show those values.

The display does not calculate `$37.10`; it receives the result from the POS.

---

### Example B — line void

Given the customer display currently shows Book B,

when the cashier voids Book B,

then the POS updates its authoritative working transaction and sends the resulting current presentation state.

The customer display does not decide whether the void is permitted.

---

### Example C — price override

Given an authorized price override changes an item's selling price from `$20` to `$18`,

then the customer display shows the resulting customer-facing `$18` price according to presentation policy.

It does not receive or display manager credential details.

---

### Example D — Cash tender

Given:

```
Total          $37.10
Cash presented $40.00
Change          $2.90
```

then the customer display may present those completed/working tender values as provided by Tenders.

---

### Example E — display disconnects before completion

Given the customer display disconnects while a transaction is open,

then the cashier may continue the transaction normally.

Display availability does not control transaction state.

---

### Example F — display fails after commit

Given the transaction commits successfully,

when the customer display fails before showing the thank-you screen,

then:

* transaction remains completed;  
* receipt identity remains valid;  
* inventory/tender effects remain completed.

No rollback occurs.

---

### Example G — reconnection

Given a display disconnects and later reconnects while the transaction is still open,

then the POS sends the current authoritative presentation state.

The display does not need the full history of every scan and void that occurred while disconnected.

---

### Example H — offline sale

Given the organization server is unreachable,

when the POS continues an ordinary supported offline sale,

then the customer display may continue presenting transaction state from the local POS.

No central connection is required.

---

### Example I — historical receipt

Given a customer later requests a copy of a completed transaction,

then Receipt rendering produces the historical receipt.

The customer display's previous live state is not used as the historical source.

---

## 34\. Related contract

If Customer Display is implemented as a separate component, define a lightweight presentation contract such as:

```
CustomerDisplayState
├── contract_version
├── mode
├── transaction_id when applicable
├── line presentations
├── subtotal
├── discounts
├── tax
├── total
├── tender/change presentation
└── message
```

This contract should contain **presentation-ready authoritative values**, not enough independent business rules for the display to reconstruct or recalculate the transaction.

---

The Customer Display domain is intentionally small:

> **ShelfSense POS knows what is happening; the customer display shows the customer the relevant parts.**

Keeping it this narrow lets us add anything from a simple second monitor to a separate display process later without making customer-display hardware part of transaction correctness.
