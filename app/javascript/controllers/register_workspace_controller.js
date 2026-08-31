import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "field",
    "fieldLabel",
    "modeLabel",
    "background",
    "overlay",
    "controlOverlay",
    "unlinkedOverlay",
    "unlinkedForm",
    "completeForm",
    "tenderForm",
    "removeTenderForm",
    "replaceTenderForm",
    "returnToSaleForm",
    "merchandiseForm",
    "quantityForm",
    "removeForm",
    "cancelForm",
    "controlForm",
    "identifierInput",
    "quantityInput",
    "presentedInput",
    "tenderTypeInput",
    "referenceInput",
    "referenceField",
    "referenceWrap",
    "giftCardNumberWrap",
    "giftCardNumberField",
    "cardNumberInput",
    "issuanceCardNumber",
    "issuanceOverlay",
    "issuanceTypeField",
    "issuanceProgramField",
    "issuanceAmountField",
    "issuanceCardWrap",
    "issuanceResultLabel",
    "issuanceTitle",
    "issuanceCancel",
    "issuanceApply",
    "issuanceForm",
    "issuanceTypeInput",
    "issuanceProgramInput",
    "issuanceAmountInput",
    "issuanceCardInput",
    "issuanceOperationInput",
    "issuanceConfirmClearInput",
    "removeIssuanceForm",
    "removeIssuanceIdInput",
    "removeIssuanceOperationInput",
    "removeIssuanceConfirmClearInput",
    "replaceIssuanceForm",
    "replaceIssuanceIdInput",
    "replaceIssuanceTypeInput",
    "replaceIssuanceProgramInput",
    "replaceIssuanceAmountInput",
    "replaceIssuanceCardInput",
    "replaceIssuanceOperationInput",
    "replaceIssuanceConfirmClearInput",
    "clearTendersOverlay",
    "clearTendersConsequence",
    "tenderOperationInput",
    "editTenderStoredValueNote",
    "cashOutForm",
    "cashOutCardInput",
    "destinationModeInput",
    "referenceLabel",
    "removeTenderInput",
    "removeTenderOperationInput",
    "selectedTenderInput",
    "replaceTenderInput",
    "replaceTenderOperationInput",
    "replaceTenderAmountInput",
    "replaceTenderPresentedInput",
    "replaceTenderReferenceInput",
    "returnToSaleOperationInput",
    "editTenderOverlay",
    "editTenderDetail",
    "editTenderAmount",
    "editTenderPresentedWrap",
    "editTenderPresented",
    "editTenderReferenceWrap",
    "editTenderReference",
    "removeTenderOverlay",
    "removeTenderDetail",
    "returnToSaleOverlay",
    "tenderReviewDetail",
    "tenderEditAction",
    "tenderRemoveAction",
    "tenderUnavailableReason",
    "quantityLineInput",
    "removeLineInput",
    "controlLineInput",
    "controlActionInput",
    "controlOperationInput",
    "controlReasonInput",
    "controlNoteInput",
    "controlPriceInput",
    "controlDiscountInput",
    "controlTaxInput",
    "controlApproverUserInput",
    "controlApproverPasswordInput",
    "controlTitle",
    "controlLineLabel",
    "controlCurrentLabel",
    "controlPriceWrap",
    "controlDiscountWrap",
    "controlTaxWrap",
    "controlPriceField",
    "controlDiscountField",
    "controlTaxField",
    "controlReasonField",
    "controlNoteWrap",
    "controlNoteField",
    "controlCancel",
    "controlApply",
    "controlRemove",
    "approvalOverlay",
    "approvalActionLabel",
    "approvalItemLabel",
    "approvalCurrentWrap",
    "approvalCurrentHeading",
    "approvalCurrentLabel",
    "approvalProposedWrap",
    "approvalProposedHeading",
    "approvalProposedLabel",
    "approvalQtyWrap",
    "approvalQtyLabel",
    "approvalReasonLabel",
    "approvalBack",
    "approvalAuthorize",
    "approverUsername",
    "approverPassword",
    "overlayFailureMeta",
    "cancelConsequence",
    "unlinkedIdentifierField",
    "unlinkedIdentifierInput",
    "unlinkedProductIdInput",
    "unlinkedVariantIdInput",
    "unlinkedUnitIdInput",
    "unlinkedQuantityInput",
    "unlinkedReasonInput",
    "unlinkedNoteInput",
    "unlinkedPriceInput",
    "unlinkedExpectedVariantInput",
    "unlinkedExpectedUnitInput",
    "unlinkedExpectedReferenceInput",
    "unlinkedExpectedTaxInput",
    "unlinkedApproverUserInput",
    "unlinkedApproverPasswordInput",
    "unlinkedFeedback",
    "unlinkedQueryLabel",
    "unlinkedPreview",
    "unlinkedDescription",
    "unlinkedReferenceLabel",
    "unlinkedQuantityWrap",
    "unlinkedQuantityField",
    "unlinkedReasonField",
    "unlinkedNoteWrap",
    "unlinkedNoteField",
    "unlinkedPriceField",
    "unlinkedCancel",
    "unlinkedLookup",
    "unlinkedApply",
    "dontCancel",
    "confirmCancel",
    "retry",
    "abandonButton",
    "quantityButton",
    "overrideButton",
    "discountButton",
    "taxClassButton",
    "tenderButton",
    "removeButton",
    "cancelButton",
    "cashButton",
    "cardButton",
    "checkButton",
    "otherButton",
    "storedValueButton",
    "otherOverlay",
    "otherList",
    "otherTitle",
    "otherSettlementLabel",
    "otherCancel",
    "otherChoose",
    "searchOverlay",
    "searchList",
    "searchSkuField",
    "searchNameField",
    "searchQueryLabel",
    "pickupButton",
    "pickupOverlay",
    "pickupList",
    "pickupQueryField",
    "pickupQueryLabel",
    "pickupForm",
    "pickupRequestInput",
    "attachCustomerButton",
    "attachCustomerForm",
    "attachCustomerIdInput",
    "customerOverlay",
    "customerList",
    "customerQueryField",
    "customerQueryLabel",
    "quickCustomerButton",
    "quickCustomerOverlay",
    "quickCustomerContextLabel",
    "quickCustomerDisplayNameField",
    "quickCustomerEmailField",
    "quickCustomerPhoneField",
    "quickCustomerDuplicateWrap",
    "quickCustomerDuplicateList",
    "quickCustomerAcknowledgeField",
    "quickCustomerBack",
    "quickCustomerSubmit",
    "productOverlay",
    "productList",
    "variantOverlay",
    "variantList",
    "variantBack",
    "unitOverlay",
    "unitList",
    "unitBack",
    "openPriceOverlay",
    "openPriceTitle",
    "openPricePrompt",
    "openPriceField",
    "openPriceForm",
    "openPriceLineInput",
    "openPriceEditInput",
    "variantInput",
    "unitInput",
    "openPriceInput",
    "returnButton",
    "returnChooserOverlay",
    "returnChooserList",
    "returnChooserCancel",
    "returnChooserContinue",
    "linkedOverlay",
    "linkedInstruction",
    "linkedLookupWrap",
    "linkedLookupField",
    "linkedFeedback",
    "linkedQueryLabel",
    "linkedList",
    "linkedDetailsWrap",
    "linkedQuantityField",
    "linkedReasonField",
    "linkedNoteWrap",
    "linkedNoteField",
    "linkedSecondary",
    "linkedPrimary",
    "linkedReturnForm",
    "linkedOriginalInput",
    "linkedQuantityInput",
    "linkedReasonInput",
    "linkedNoteInput",
    "feedback",
    "clientRecovery"
  ]

  static values = {
    mode: String,
    autoComplete: Boolean,
    workspaceUrl: String,
    tenderTypes: Array,
    policies: Object,
    reasons: Object,
    returnReasons: Array,
    unlinkedLookupUrl: String,
    linkedLookupUrl: String,
    resolveUrl: String,
    searchUrl: String,
    pickupSearchUrl: String,
    customerSearchUrl: String,
    quickCustomerUrl: String,
    quickCustomerAllowed: Boolean,
    customerAttached: Boolean,
    pickupAllowed: Boolean,
    openPriceUrl: String,
    settlement: String,
    refundRemaining: Number,
    paymentRemaining: Number,
    cashOutAllowed: Boolean
  }

  connect() {
    this.inFlight = false
    this.overlayStack = []
    this.confirmationInvocation = null
    this.tenderPickerInvocation = null
    this.searchRequestToken = 0
    this.pickupRequestToken = 0
    this.customerRequestToken = 0
    this.linkedInvocation = 0
    this.unlinkedInvocation = 0
    this.searchAbort = null
    this.pickupAbort = null
    this.customerAbort = null
    this.linkedAbort = null
    this.unlinkedAbort = null
    this.customerLookupContext = null
    this.quickCustomerIdempotencyKey = null
    this.linkedStage = "lookup"
    this.bindFunctionKeyCapture()
    if (this.hasControlReasonFieldTarget) {
      this.controlReasonFieldTarget.addEventListener("change", () => {
        this.toggleHidden(this.hasControlNoteWrapTarget && this.controlNoteWrapTarget, this.controlReasonFieldTarget.value !== "other")
      })
    }
    if (this.hasUnlinkedReasonFieldTarget) {
      this.unlinkedReasonFieldTarget.addEventListener("change", () => {
        this.toggleHidden(this.hasUnlinkedNoteWrapTarget && this.unlinkedNoteWrapTarget, this.unlinkedReasonFieldTarget.value !== "other")
        this.syncUnlinkedPrimaryEnabled()
      })
    }
    if (this.hasLinkedReasonFieldTarget) {
      this.linkedReasonFieldTarget.addEventListener("change", () => {
        this.onLinkedReasonChange()
      })
    }
    if (this.autoCompleteValue) {
      this.submitComplete()
      return
    }
    this.enableReadyActions()
    this.restoreFocus()
    this.scrollSelectedRowIntoView()
    if (this.hasFeedbackTarget && /customer is required/i.test(this.feedbackTarget.textContent || "")) {
      this.openCustomerOverlay()
    }
  }

  disconnect() {
    this.unbindFunctionKeyCapture()
    this.abortPendingLookups()
    this.clearConfirmationCredentials()
    this.confirmationInvocation = null
    this.clearOverlayStack({ restoreCommand: false })
    if (this.hasBackgroundTarget) this.backgroundTarget.inert = false
  }

  onKeydown(event) {
    const functionKey = this.functionKey(event)
    const key = functionKey || event.key
    if (key === "F10") return
    if (this.claimedFunctionKey(functionKey)) this.claimFunctionKey(event)

    const overlay = this.activeOverlayElement()
    if (overlay && key === "Tab") {
      this.trapTabInOverlay(overlay, event)
      return
    }

    if (overlay) {
      this.dispatchOverlayKeydown(overlay, event, key)
      return
    }

    if (this.modeValue === "tender" && (key === "ArrowUp" || key === "ArrowDown") && this.tenderListKeyTarget(event.target)) {
      event.preventDefault()
      this.moveTenderSelection(key === "ArrowUp" ? -1 : 1, { focus: true })
      return
    }
    if (this.modeValue === "tender" && key === "Enter" && event.target?.matches?.(".pos-tenders__item")) {
      event.preventDefault()
      this.selectTender({ currentTarget: event.target })
      if (event.target.dataset.editAvailable === "true") this.openEditTenderOverlay()
      return
    }

    this.redirectPrintableToCommandField(event)

    if (this.inFlight || this.modeValue === "completion_pending") {
      if (key === "Enter" && this.isActionableControl(event.target)) return
      if (key === "Enter" || key === "F9") event.preventDefault()
      return
    }

    if (this.modeValue === "completion_failed") {
      if (key === "Enter") {
        if (this.isActionableControl(event.target)) return
        event.preventDefault()
        this.submitComplete()
      }
      if (key === "F9") {
        event.preventDefault()
        this.openOverlay()
      }
      if (key === "Escape") event.preventDefault()
      return
    }

    if (key === "Enter") {
      if (this.isActionableControl(event.target)) return
      event.preventDefault()
      this.submitMode()
      return
    }
    if (key === "Escape") {
      event.preventDefault()
      this.escape()
      return
    }
    if (key === "F9") {
      event.preventDefault()
      this.openOverlay()
      return
    }
    if (this.modeValue !== "sale_entry" && this.modeValue !== "tender") return

    if (key === "F1") {
      event.preventDefault()
      this.chooseCash()
      return
    }
    if (key === "F2") {
      event.preventDefault()
      this.chooseCard()
      return
    }
    if (key === "F3") {
      event.preventDefault()
      this.chooseCheck()
      return
    }
    if (key === "F4") {
      event.preventDefault()
      this.chooseOther()
      return
    }
    if (key === "F5") {
      event.preventDefault()
      this.chooseStoredValue()
      return
    }

    if (this.modeValue === "tender") {
      if (key === "F8") {
        event.preventDefault()
        this.removeLastTender()
      }
      return
    }

    const fieldEmpty = this.commandFieldEmpty()
    if (key === "*" && fieldEmpty) {
      event.preventDefault()
      this.enterQuantity()
    } else if (key === "+" && fieldEmpty) {
      event.preventDefault()
      this.enterTender()
    } else if (key === "/" && fieldEmpty) {
      event.preventDefault()
      this.openSearchOverlay()
    } else if (key === "." && fieldEmpty && this.pickupAllowedValue) {
      event.preventDefault()
      this.openPickupOverlay()
    } else if ((key === "-" || event.code === "Minus") && fieldEmpty) {
      event.preventDefault()
      this.openReturnChooser()
    } else if (key === "F6") {
      event.preventDefault()
      this.openPriceOverride()
    } else if (key === "F7") {
      event.preventDefault()
      this.openLineDiscount()
    } else if (key === "F8") {
      event.preventDefault()
      this.removeSelected()
    } else if (key === "ArrowUp" || key === "ArrowDown") {
      event.preventDefault()
      this.moveSelection(key === "ArrowUp" ? -1 : 1)
    }
  }

  suppressBrowserFunctionKeys(event) {
    if (this.claimedFunctionKey(this.functionKey(event))) this.claimFunctionKey(event)
  }

  onControlOverlayKeydown(event, key = this.functionKey(event) || event.key) {
    if (key === "Escape") {
      event.preventDefault()
      this.closeControlOverlay()
      return
    }
    if (key === "F9" || key === "F10") {
      event.preventDefault()
      return
    }
    if (key !== "Enter") return

    const target = event.target
    if (this.isActionableControl(target)) return
    event.preventDefault()
    this.advanceOrApplyControlOverlay()
  }

  advanceOrApplyControlOverlay() {
    if (this.controlReasonNeedsNote()) {
      this.controlNoteFieldTarget.focus()
      return
    }
    this.submitControlApply()
  }

  controlReasonNeedsNote() {
    return this.hasControlReasonFieldTarget &&
      this.controlReasonFieldTarget.value === "other" &&
      this.hasControlNoteFieldTarget &&
      this.controlNoteFieldTarget.value.trim() === "" &&
      this.hasControlNoteWrapTarget &&
      !this.controlNoteWrapTarget.hidden
  }

  onApprovalOverlayKeydown(event, key = this.functionKey(event) || event.key) {
    if (key === "Escape") {
      event.preventDefault()
      this.backFromApprovalOverlay()
      return
    }
    if (key === "F9" || key === "F10") {
      event.preventDefault()
      return
    }
    if (key !== "Enter") return

    const target = event.target
    if (this.hasApproverUsernameTarget && target === this.approverUsernameTarget) {
      event.preventDefault()
      if (this.hasApproverPasswordTarget) this.approverPasswordTarget.focus()
      return
    }
    if (this.hasApproverPasswordTarget && target === this.approverPasswordTarget) {
      event.preventDefault()
      if (this.approverPasswordTarget.value.trim() !== "") this.authorizeAndSubmit()
      return
    }
    if (this.isActionableControl(target)) return
    event.preventDefault()
    this.authorizeAndSubmit()
  }

  onUnlinkedOverlayKeydown(event, key = this.functionKey(event) || event.key) {
    if (key === "Escape") {
      event.preventDefault()
      this.backFromUnlinkedOverlay()
      return
    }
    if (key === "F9" || key === "F10") {
      event.preventDefault()
      return
    }
    if (key !== "Enter") return

    const target = event.target
    if (this.hasUnlinkedIdentifierFieldTarget && target === this.unlinkedIdentifierFieldTarget) {
      event.preventDefault()
      this.lookUpUnlinkedItem()
      return
    }
    if (this.isActionableControl(target)) return
    event.preventDefault()
    this.advanceOrApplyUnlinkedOverlay()
  }

  advanceOrApplyUnlinkedOverlay() {
    if (!this.unlinkedPreviewPayload) {
      this.lookUpUnlinkedItem()
      return
    }
    if (!this.unlinkedAddReady()) return
    this.submitUnlinkedReturn()
  }

  onSubmitEnd(event) {
    if (event.detail?.success) return
    if (!this.inFlight) return
    if (this.overlayOpen()) {
      this.recoverDialogRejection()
      return
    }
    this.recoverFromTransportFailure(event.target)
  }

  submitMode() {
    if (this.inFlight) return
    if (this.modeValue === "sale_entry") this.submitMerchandise()
    else if (this.modeValue === "quantity") this.submitQuantity()
    else if (this.modeValue === "tender") this.submitTender()
  }

  async submitMerchandise() {
    const value = this.fieldTarget.value.trim()
    if (!value) return
    await this.resolveAndHandle({ identifier: value })
  }

  submitQuantity() {
    const value = this.fieldTarget.value.trim()
    if (!value) return
    this.quantityInputTarget.value = value
    this.syncSelectedLine()
    this.beginFlight()
    this.quantityFormTarget.requestSubmit()
  }

  submitTender() {
    const value = this.fieldTarget.value.trim()
    if (!value) return
    if (this.referenceRequired() && this.hasReferenceFieldTarget && this.referenceFieldTarget.value.trim() === "") {
      this.referenceFieldTarget.focus()
      return
    }
    this.presentedInputTarget.value = value
    if (this.hasReferenceInputTarget) {
      const capture = this.hasReferenceWrapTarget && !this.referenceWrapTarget.hidden && this.hasReferenceFieldTarget
      this.referenceInputTarget.value = capture ? this.referenceFieldTarget.value.trim() : ""
    }
    if (this.hasCardNumberInputTarget) {
      const captureCard = this.hasGiftCardNumberWrapTarget && !this.giftCardNumberWrapTarget.hidden && this.hasGiftCardNumberFieldTarget
      this.cardNumberInputTarget.value = captureCard ? this.giftCardNumberFieldTarget.value.trim() : ""
    }
    if (this.hasDestinationModeInputTarget) {
      const type = this.selectedTenderType()
      if (this.settlementValue === "refund" && type?.stored_value_account_type === "gift_card" && !(this.cardNumberInputTarget?.value)) {
        this.destinationModeInputTarget.value = "new_gift_card"
      } else if (this.settlementValue === "refund" && type?.stored_value_account_type === "store_credit") {
        this.destinationModeInputTarget.value = "customer_store_credit"
        if (!this.customerAttachedValue) {
          this.showFeedback("A customer is required. Find and attach a customer to continue.")
          this.openCustomerOverlay({ context: "customer_store_credit" })
        }
      } else {
        this.destinationModeInputTarget.value = type?.category === "stored_value" ? "existing_account" : ""
      }
    }
    if (this.hasTenderOperationInputTarget) this.tenderOperationInputTarget.value = this.uuidV7()
    this.beginFlight()
    this.tenderFormTarget.requestSubmit()
  }

  submitComplete() {
    if (this.inFlight) return
    this.beginFlight()
    this.completeFormTarget.requestSubmit()
  }

  enterQuantity() {
    if (this.inFlight) return
    if (this.modeValue !== "sale_entry" || !this.selectedRow()) return
    if (this.selectedUnitLine() || this.selectedQuantityBlocked()) return
    const row = this.selectedRow()
    this.setMode("quantity", "QUANTITY")
    const description = row.dataset.description || "Selected line"
    const quantity = row.dataset.quantity || ""
    this.setFieldLabel(`${description} · Current quantity ${quantity}`)
    this.fieldTarget.disabled = false
    this.fieldTarget.inputMode = "numeric"
    this.fieldTarget.value = quantity
    this.setActionEnabled("quantityButton", false)
    this.setActionEnabled("overrideButton", false)
    this.setActionEnabled("discountButton", false)
    this.setActionEnabled("taxClassButton", false)
    this.setActionEnabled("tenderButton", false)
    this.setActionEnabled("removeButton", false)
    this.fieldTarget.focus()
    this.fieldTarget.select()
  }

  enterTender() {
    if (this.inFlight) return
    if (this.modeValue !== "sale_entry") return
    if (!this.hasCommercialContent()) {
      this.showFeedback("Add merchandise before taking a tender.")
      return
    }
    if (this.settlementValue === "none") {
      this.submitComplete()
      return
    }
    const types = this.cashierTenderTypes()
    if (types.length === 0) {
      this.showFeedback(this.settlementValue === "refund" ? "No refund tender types are available." : "No tender types are available.")
      return
    }
    this.openTenderPicker(types, { source: "plus" })
  }

  chooseCash() {
    this.chooseTenderCategory("cash")
  }

  chooseCard() {
    this.chooseTenderCategory("card")
  }

  chooseCheck() {
    this.chooseTenderCategory("check")
  }

  chooseOther() {
    if (this.inFlight) return
    if (this.modeValue !== "sale_entry" && this.modeValue !== "tender") return
    if (!this.ensureTenderable()) return
    const types = this.otherTypes()
    if (types.length === 0) {
      this.showFeedback("No Other tender types are configured.")
      return
    }
    if (types.length === 1) {
      this.beginTenderMode()
      this.applyTenderType(types[0])
      this.prefillRemaining()
      return
    }
    this.openTenderPicker(types, { source: "other_key" })
  }

  chooseStoredValue() {
    if (this.inFlight) return
    if (this.modeValue !== "sale_entry" && this.modeValue !== "tender") return
    if (!this.ensureTenderable()) return
    const types = this.typesForCategory("stored_value")
    if (types.length === 0) {
      this.showFeedback("Stored-value tender is not available.")
      return
    }
    if (types.length === 1) {
      this.beginTenderMode()
      this.applyTenderType(types[0])
      this.prefillRemaining()
      return
    }
    this.openTenderPicker(types, { source: "stored_value_key" })
  }

  chooseTenderCategory(category) {
    if (this.inFlight) return
    if (this.modeValue !== "sale_entry" && this.modeValue !== "tender") return
    if (!this.ensureTenderable()) return
    const types = this.typesForCategory(category)
    const label = this.categoryLabel(category)
    if (types.length === 0) {
      if (this.settlementValue === "refund") {
        this.showFeedback(`${label} refunds are not enabled.`)
      } else {
        this.showFeedback(`${label} tender is not available.`)
      }
      return
    }
    this.beginTenderMode()
    this.applyTenderType(types[0])
    this.prefillRemaining()
  }

  ensureTenderable() {
    if (this.modeValue === "tender") return true
    if (!this.hasCommercialContent()) {
      this.showFeedback("Add merchandise before taking a tender.")
      return false
    }
    if (this.settlementValue === "none") {
      this.submitComplete()
      return false
    }
    return true
  }

  beginTenderMode() {
    if (this.modeValue === "tender") return
    const refund = this.settlementValue === "refund"
    this.setMode("tender", refund ? "REFUND" : "CASH TENDER")
    this.fieldTarget.disabled = false
    this.fieldTarget.inputMode = "decimal"
    this.setActionEnabled("quantityButton", false)
    this.setActionEnabled("overrideButton", false)
    this.setActionEnabled("discountButton", false)
    this.setActionEnabled("taxClassButton", false)
    this.setActionEnabled("tenderButton", false)
    this.setActionEnabled("removeButton", false)
    this.enableTenderIdentityButtons()
  }

  applyTenderType(type) {
    if (!type) return
    const types = this.cashierTenderTypes()
    const index = types.findIndex((item) => item.id === type.id)
    this.selectTenderType(index >= 0 ? index : 0)
  }

  prefillRemaining() {
    this.fieldTarget.value = this.formatCents(this.remainingCents())
    this.fieldTarget.focus()
    this.fieldTarget.select()
  }

  remainingCents() {
    return this.settlementValue === "refund" ? this.refundRemainingValue : this.paymentRemainingValue
  }

  typesForCategory(category) {
    return this.cashierTenderTypes().filter((type) => type.category === category)
  }

  otherTypes() {
    return this.typesForCategory("other").slice().sort((left, right) => (left.code || "").localeCompare(right.code || ""))
  }

  categoryLabel(category) {
    if (category === "cash") return "Cash"
    if (category === "card") return "Card"
    if (category === "check") return "Check"
    if (category === "stored_value") return "Stored value"
    return "Other"
  }

  commandFieldEmpty() {
    return this.hasFieldTarget && this.fieldTarget.value.trim() === ""
  }

  referenceRequired() {
    const type = this.selectedTenderType()
    return Boolean(type && type.reference_policy === "required")
  }

  selectedTenderType() {
    const types = this.cashierTenderTypes()
    const id = this.hasTenderTypeInputTarget ? this.tenderTypeInputTarget.value : null
    return types.find((type) => type.id === id) || types[0]
  }

  showFeedback(message) {
    if (!this.hasFeedbackTarget) return
    this.feedbackTarget.textContent = message
    this.feedbackTarget.setAttribute("role", "alert")
  }

  openTenderPicker(types, { source }) {
    if (!this.hasOtherOverlayTarget || !this.hasOtherListTarget) return
    this.tenderPickerInvocation = {
      source,
      priorMode: this.modeValue === "tender" ? "tender" : "sale_entry",
      priorTenderTypeId: this.hasTenderTypeInputTarget ? this.tenderTypeInputTarget.value : null,
      priorCommandValue: this.hasFieldTarget ? this.fieldTarget.value : "",
      priorReferenceValue: this.hasReferenceFieldTarget ? this.referenceFieldTarget.value : "",
      priorGiftCardNumber: this.hasGiftCardNumberFieldTarget ? this.giftCardNumberFieldTarget.value : "",
      opener: document.activeElement
    }
    if (this.hasOtherSettlementLabelTarget) {
      const remaining = this.formatCents(this.remainingCents())
      this.otherSettlementLabelTarget.textContent = this.settlementValue === "refund"
        ? `Refund remaining $${remaining}`
        : `Balance due $${remaining}`
    }
    if (this.hasOtherCancelTarget) {
      const restoreTender = this.tenderPickerInvocation.priorMode === "tender"
      this.otherCancelTarget.textContent = restoreTender ? "Back to Tender" : "Back to Sale"
    }
    this.otherListTarget.replaceChildren()
    types.forEach((type, index) => {
      const item = document.createElement("li")
      item.dataset.tenderTypeId = type.id
      item.dataset.tenderIndex = String(index + 1)
      item.textContent = `${index + 1}  ${type.name}`
      this.decoratePickerItem(item, { selected: index === 0 })
      item.addEventListener("click", () => this.onPickerItemClick(this.otherListTarget, item))
      this.otherListTarget.append(item)
    })
    this.showOverlay(this.otherOverlayTarget, this.otherListTarget.querySelector("li.is-selected"))
  }

  openOtherPicker(types) {
    this.openTenderPicker(types, { source: "other_key" })
  }

  closeOtherOverlay() {
    this.tenderPickerInvocation = null
    this.hideOverlay(this.hasOtherOverlayTarget && this.otherOverlayTarget)
  }

  dismissTenderPicker() {
    if (!this.otherOverlayOpen()) return
    const invocation = this.tenderPickerInvocation
    this.tenderPickerInvocation = null
    this.hideOverlay(this.otherOverlayTarget)
    if (!invocation) {
      this.restoreFocus()
      return
    }
    this.restoreTenderPickerInvocation(invocation)
  }

  restoreTenderPickerInvocation(invocation) {
    if (invocation.priorMode === "tender") {
      this.beginTenderMode()
      const type = this.cashierTenderTypes().find((item) => item.id === invocation.priorTenderTypeId)
      if (type) this.applyTenderType(type)
      if (this.hasFieldTarget) this.fieldTarget.value = invocation.priorCommandValue || ""
      if (this.hasReferenceFieldTarget) this.referenceFieldTarget.value = invocation.priorReferenceValue || ""
      if (this.hasGiftCardNumberFieldTarget) this.giftCardNumberFieldTarget.value = invocation.priorGiftCardNumber || ""
      this.fieldTarget.focus()
      this.fieldTarget.select()
      return
    }
    if (this.modeValue === "tender") {
      this.setMode("sale_entry", "SALE ENTRY")
      this.setFieldLabel("Scan or identifier")
      this.fieldTarget.inputMode = "text"
      this.toggleReferenceField("omitted")
      this.toggleGiftCardNumberField(null)
      this.enableReadyActions()
    }
    if (this.hasFieldTarget) {
      this.fieldTarget.value = invocation.priorCommandValue || ""
      this.fieldTarget.focus()
    }
  }

  onOtherOverlayKeydown(event, key) {
    if (key === "Escape") {
      event.preventDefault()
      this.dismissTenderPicker()
      return
    }
    if (key === "ArrowUp" || key === "ArrowDown") {
      event.preventDefault()
      this.movePickerList(this.otherListTarget, key === "ArrowUp" ? -1 : 1)
      return
    }
    if (key === "Enter") {
      event.preventDefault()
      this.selectHighlightedOther()
    }
  }

  selectHighlightedOther() {
    if (!this.hasOtherListTarget) return
    const selected = this.otherListTarget.querySelector("li.is-selected")
    if (!selected) return
    const type = this.cashierTenderTypes().find((item) => item.id === selected.dataset.tenderTypeId)
    this.tenderPickerInvocation = null
    this.hideOverlay(this.otherOverlayTarget)
    if (!type) return
    this.beginTenderMode()
    this.applyTenderType(type)
    this.prefillRemaining()
  }

  async resolveAndHandle(params) {
    if (this.inFlight) return
    this.inFlight = true
    try {
      const result = await this.fetchResolve(params)
      this.inFlight = false
      this.handleResolution(result)
    } catch (error) {
      this.inFlight = false
      this.showFeedback(error?.message || "merchandise not found")
      this.enableReadyActions()
      this.restoreFocus()
    }
  }

  async fetchResolve(params) {
    const url = new URL(this.resolveUrlValue, window.location.origin)
    if (params.identifier) url.searchParams.set("identifier", params.identifier)
    if (params.product_id) url.searchParams.set("product_id", params.product_id)
    if (params.product_variant_id) url.searchParams.set("product_variant_id", params.product_variant_id)
    if (params.inventory_unit_id) url.searchParams.set("inventory_unit_id", params.inventory_unit_id)
    const response = await fetch(url, { headers: { Accept: "application/json" }, credentials: "same-origin" })
    const payload = await response.json()
    if (!response.ok) throw new Error(payload.message || "merchandise not found")
    return payload
  }

  handleResolution(result) {
    switch (result.outcome) {
      case "addable_variant":
        this.clearOverlayStack({ restoreCommand: false })
        this.postAddMerchandise({ variantId: result.variant.id })
        return
      case "addable_unit":
        this.clearOverlayStack({ restoreCommand: false })
        this.postAddMerchandise({ unitId: result.unit.id })
        return
      case "product_choice_required":
        this.openProductPicker(result.products || [])
        return
      case "variant_choice_required":
        this.openVariantPicker(result.variants || [])
        return
      case "unit_choice_required":
        this.openUnitPicker(result.units || [])
        return
      case "open_price_required":
        this.openOpenPriceOverlay({
          kind: "add",
          variantId: result.variant?.id,
          prompt: this.variantLabel(result.variant)
        })
        return
      case "gift_card":
        this.handleGiftCardScan(result)
        return
      default:
        this.showFeedback(result.message || "merchandise not found")
        this.enableReadyActions()
        this.restoreFocus()
    }
  }

  postAddMerchandise({ variantId, unitId, sellingPrice } = {}) {
    if (this.hasIdentifierInputTarget) this.identifierInputTarget.value = ""
    if (this.hasVariantInputTarget) this.variantInputTarget.value = variantId || ""
    if (this.hasUnitInputTarget) this.unitInputTarget.value = unitId || ""
    if (this.hasOpenPriceInputTarget) this.openPriceInputTarget.value = sellingPrice || ""
    this.beginFlight()
    this.merchandiseFormTarget.requestSubmit()
  }

  variantLabel(variant) {
    if (!variant) return "Open price"
    const parts = [variant.sku, variant.name, variant.condition].filter(Boolean)
    return parts.join(" · ") || "Open price"
  }

  openSearchOverlay() {
    if (this.inFlight || this.modeValue !== "sale_entry") return
    if (!this.hasSearchOverlayTarget) return
    this.invalidateSearchLookup()
    if (this.hasSearchSkuFieldTarget) this.searchSkuFieldTarget.value = ""
    if (this.hasSearchNameFieldTarget) this.searchNameFieldTarget.value = ""
    if (this.hasSearchListTarget) this.searchListTarget.replaceChildren()
    if (this.hasSearchQueryLabelTarget) this.searchQueryLabelTarget.textContent = ""
    this.showOverlay(this.searchOverlayTarget, this.hasSearchSkuFieldTarget && this.searchSkuFieldTarget)
  }

  closeSearchOverlay() {
    this.invalidateSearchLookup()
    this.hideOverlay(this.hasSearchOverlayTarget && this.searchOverlayTarget)
  }

  invalidateSearchLookup() {
    if (this.searchAbort) this.searchAbort.abort()
    this.searchAbort = null
    this.searchRequestToken += 1
    this.searchResultsReady = false
  }

  invalidateSearchResultsOnInput() {
    if (!this.searchResultsReady && !(this.hasSearchListTarget && this.searchListTarget.children.length > 0)) return
    if (this.hasSearchListTarget) this.searchListTarget.replaceChildren()
    this.searchResultsReady = false
    if (this.hasSearchQueryLabelTarget) this.searchQueryLabelTarget.textContent = ""
  }

  onSearchOverlayKeydown(event, key) {
    if (key === "Escape") {
      event.preventDefault()
      this.closeSearchOverlay()
      return
    }
    if (key === "ArrowUp" || key === "ArrowDown") {
      event.preventDefault()
      this.movePickerList(this.searchListTarget, key === "ArrowUp" ? -1 : 1)
      return
    }
    if (key !== "Enter") return
    event.preventDefault()
    const inField = event.target === this.searchSkuFieldTarget || event.target === this.searchNameFieldTarget
    const selected = this.hasSearchListTarget && this.searchListTarget.querySelector("li.is-selected:not(.is-disabled)")
    if (inField && (!this.searchResultsReady || !selected)) {
      this.runMerchandiseSearch()
      return
    }
    this.selectHighlightedSearch()
  }

  async runMerchandiseSearch() {
    const sku = this.hasSearchSkuFieldTarget ? this.searchSkuFieldTarget.value.trim() : ""
    const name = this.hasSearchNameFieldTarget ? this.searchNameFieldTarget.value.trim() : ""
    if (!sku && !name) return
    if (this.searchAbort) this.searchAbort.abort()
    this.searchAbort = new AbortController()
    const token = ++this.searchRequestToken
    if (this.hasSearchQueryLabelTarget) this.searchQueryLabelTarget.textContent = "Searching…"
    const url = new URL(this.searchUrlValue, window.location.origin)
    if (sku) url.searchParams.set("sku", sku)
    if (name) url.searchParams.set("name", name)
    try {
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
        signal: this.searchAbort.signal
      })
      const payload = await response.json()
      if (!this.lookupResponseCurrent("search", token)) return
      this.renderSearchResults(payload.results || [])
    } catch (error) {
      if (error?.name === "AbortError") return
      if (!this.lookupResponseCurrent("search", token)) return
      this.renderSearchResults([])
      if (this.hasSearchQueryLabelTarget) this.searchQueryLabelTarget.textContent = "Search failed."
      this.focusOverlayEntry(this.searchSkuFieldTarget || this.searchNameFieldTarget)
    }
  }

  lookupResponseCurrent(family, token) {
    if (!this.element.isConnected) return false
    if (family === "search") {
      return token === this.searchRequestToken && this.searchOverlayOpen()
    }
    if (family === "pickup") {
      return token === this.pickupRequestToken && this.pickupOverlayOpen()
    }
    if (family === "customer") {
      return token === this.customerRequestToken && this.customerOverlayOpen()
    }
    return false
  }

  renderSearchResults(rows) {
    if (!this.hasSearchListTarget) return
    this.searchListTarget.replaceChildren()
    this.searchResultsReady = true
    const enabledRows = rows.filter((row) => !row.disabled)
    if (this.hasSearchQueryLabelTarget) {
      this.searchQueryLabelTarget.textContent = rows.length === 0 ? "No matching merchandise." : ""
    }
    let firstEnabled = null
    rows.forEach((row) => {
      const item = document.createElement("li")
      item.dataset.variantId = row.id
      item.dataset.disabled = row.disabled ? "true" : "false"
      item.dataset.reason = row.reason || ""
      const availability = row.available == null ? "" : ` · ${row.available}`
      const reason = row.disabled && row.reason ? ` — ${row.reason}` : ""
      item.textContent = [row.sku, row.name, row.condition, row.price_label].filter(Boolean).join(" · ") + availability + reason
      const selected = !row.disabled && firstEnabled == null
      if (selected) firstEnabled = item
      this.decoratePickerItem(item, { selected, disabled: Boolean(row.disabled) })
      item.addEventListener("click", () => this.onPickerItemClick(this.searchListTarget, item))
      this.searchListTarget.append(item)
    })
    if (firstEnabled) {
      this.focusOverlayEntry(firstEnabled)
    } else {
      const query = this.searchSkuFieldTarget || this.searchNameFieldTarget
      this.focusOverlayEntry(query)
    }
  }

  selectHighlightedSearch() {
    const selected = this.hasSearchListTarget && this.searchListTarget.querySelector("li.is-selected")
    if (!selected) return
    if (selected.dataset.disabled === "true") {
      this.showFeedback(selected.dataset.reason || "merchandise is not sellable")
      return
    }
    const variantId = selected.dataset.variantId
    // Keep search open so resolve children (variant / unit / open-price) stack on top.
    this.resolveAndHandle({ product_variant_id: variantId })
  }

  keepSearching() {
    if (this.hasSearchListTarget) this.searchListTarget.replaceChildren()
    this.searchResultsReady = false
    if (this.hasSearchQueryLabelTarget) this.searchQueryLabelTarget.textContent = ""
    this.focusOverlayEntry(this.searchSkuFieldTarget || this.searchNameFieldTarget)
  }

  confirmSearchSelection(event) {
    if (event) event.preventDefault()
    this.selectHighlightedSearch()
  }

  onPickerItemClick(list, item) {
    if (!list || !item || item.classList.contains("is-disabled")) return
    Array.from(list.querySelectorAll("li")).forEach((row) => {
      const selected = row === item
      row.classList.toggle("is-selected", selected)
      row.setAttribute("aria-selected", selected ? "true" : "false")
      row.tabIndex = selected ? 0 : -1
    })
    this.focusOverlayEntry(item)
  }

  openPickupOverlay() {
    if (!this.pickupAllowedValue) return
    if (!this.hasPickupOverlayTarget) return
    this.invalidatePickupLookup()
    if (this.hasPickupQueryFieldTarget) this.pickupQueryFieldTarget.value = ""
    if (this.hasPickupListTarget) this.pickupListTarget.replaceChildren()
    if (this.hasPickupQueryLabelTarget) this.pickupQueryLabelTarget.textContent = ""
    this.showOverlay(this.pickupOverlayTarget, this.hasPickupQueryFieldTarget && this.pickupQueryFieldTarget)
  }

  closePickupOverlay() {
    this.invalidatePickupLookup()
    this.hideOverlay(this.hasPickupOverlayTarget && this.pickupOverlayTarget)
  }

  invalidatePickupLookup() {
    if (this.pickupAbort) this.pickupAbort.abort()
    this.pickupAbort = null
    this.pickupRequestToken += 1
    this.pickupResultsReady = false
  }

  invalidatePickupResultsOnInput() {
    if (!this.pickupResultsReady && !(this.hasPickupListTarget && this.pickupListTarget.children.length > 0)) return
    if (this.hasPickupListTarget) this.pickupListTarget.replaceChildren()
    this.pickupResultsReady = false
    if (this.hasPickupQueryLabelTarget) this.pickupQueryLabelTarget.textContent = ""
  }

  onPickupOverlayKeydown(event, key) {
    if (key === "Escape") {
      event.preventDefault()
      this.closePickupOverlay()
      return
    }
    if (key === "ArrowUp" || key === "ArrowDown") {
      event.preventDefault()
      this.movePickerList(this.pickupListTarget, key === "ArrowUp" ? -1 : 1)
      return
    }
    if (key !== "Enter") return
    event.preventDefault()
    const inField = event.target === this.pickupQueryFieldTarget
    const selected = this.hasPickupListTarget && this.pickupListTarget.querySelector("li.is-selected:not(.is-disabled)")
    if (inField && (!this.pickupResultsReady || !selected)) {
      this.runPickupSearch()
      return
    }
    this.selectHighlightedPickup()
  }

  async runPickupSearch() {
    const query = this.hasPickupQueryFieldTarget ? this.pickupQueryFieldTarget.value.trim() : ""
    if (!query) {
      this.renderPickupResults([])
      if (this.hasPickupQueryLabelTarget) this.pickupQueryLabelTarget.textContent = "Enter a search."
      this.focusOverlayEntry(this.pickupQueryFieldTarget)
      return
    }
    if (this.pickupAbort) this.pickupAbort.abort()
    this.pickupAbort = new AbortController()
    const token = ++this.pickupRequestToken
    if (this.hasPickupQueryLabelTarget) this.pickupQueryLabelTarget.textContent = "Searching…"
    const url = new URL(this.pickupSearchUrlValue, window.location.origin)
    url.searchParams.set("q", query)
    try {
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        signal: this.pickupAbort.signal
      })
      const payload = await response.json()
      if (!this.lookupResponseCurrent("pickup", token)) return
      if (!response.ok) throw new Error(payload.error || "pickup search failed")
      this.renderPickupResults(payload.results || [])
    } catch (error) {
      if (error?.name === "AbortError") return
      if (!this.lookupResponseCurrent("pickup", token)) return
      this.renderPickupResults([])
      if (this.hasPickupQueryLabelTarget) this.pickupQueryLabelTarget.textContent = "Search failed."
      this.focusOverlayEntry(this.pickupQueryFieldTarget)
    }
  }

  renderPickupResults(rows) {
    if (!this.hasPickupListTarget) return
    this.pickupListTarget.replaceChildren()
    this.pickupResultsReady = true
    if (this.hasPickupQueryLabelTarget) {
      this.pickupQueryLabelTarget.textContent = rows.length === 0 ? "No available customer requests." : ""
    }
    let firstEnabled = null
    rows.forEach((row) => {
      const item = document.createElement("li")
      item.dataset.requestId = row.customer_request_id
      item.dataset.allocationType = row.allocation_type || ""
      const detail = row.allocation_type === "used_unit"
        ? `Used unit ${row.unit_identifier || ""}`.trim()
        : "Standard reserved copy"
      item.textContent = `${row.label} · ${detail}`
      const selected = firstEnabled == null
      if (selected) firstEnabled = item
      this.decoratePickerItem(item, { selected, disabled: false })
      item.addEventListener("click", () => this.onPickerItemClick(this.pickupListTarget, item))
      this.pickupListTarget.append(item)
    })
    if (firstEnabled) this.focusOverlayEntry(firstEnabled)
    else this.focusOverlayEntry(this.pickupQueryFieldTarget)
  }

  selectHighlightedPickup() {
    const selected = this.hasPickupListTarget && this.pickupListTarget.querySelector("li.is-selected")
    if (!selected || selected.classList.contains("is-disabled")) return
    if (!this.hasPickupFormTarget || !this.hasPickupRequestInputTarget) return
    this.pickupRequestInputTarget.value = selected.dataset.requestId
    this.closePickupOverlay()
    this.pickupFormTarget.requestSubmit()
  }

  confirmPickupSelection(event) {
    if (event) event.preventDefault()
    this.selectHighlightedPickup()
  }

  keepTransactionUnchanged(event) {
    if (event) event.preventDefault()
    this.closePickupOverlay()
  }

  openCustomerOverlay(options = {}) {
    if (!this.hasCustomerOverlayTarget) return
    this.customerLookupContext = options.context || null
    this.invalidateCustomerLookup()
    if (this.hasCustomerQueryFieldTarget) this.customerQueryFieldTarget.value = ""
    if (this.hasCustomerListTarget) this.customerListTarget.replaceChildren()
    if (this.hasCustomerQueryLabelTarget) this.customerQueryLabelTarget.textContent = ""
    this.showOverlay(this.customerOverlayTarget, this.hasCustomerQueryFieldTarget && this.customerQueryFieldTarget)
  }

  closeCustomerOverlay() {
    this.invalidateCustomerLookup()
    this.hideOverlay(this.hasCustomerOverlayTarget && this.customerOverlayTarget)
  }

  invalidateCustomerLookup() {
    if (this.customerAbort) this.customerAbort.abort()
    this.customerAbort = null
    this.customerRequestToken += 1
    this.customerResultsReady = false
  }

  invalidateCustomerResultsOnInput() {
    if (!this.customerResultsReady && !(this.hasCustomerListTarget && this.customerListTarget.children.length > 0)) return
    if (this.hasCustomerListTarget) this.customerListTarget.replaceChildren()
    this.customerResultsReady = false
    if (this.hasCustomerQueryLabelTarget) this.customerQueryLabelTarget.textContent = ""
  }

  onCustomerOverlayKeydown(event, key) {
    if (key === "Escape") {
      event.preventDefault()
      this.closeCustomerOverlay()
      return
    }
    if (key === "ArrowUp" || key === "ArrowDown") {
      event.preventDefault()
      this.movePickerList(this.customerListTarget, key === "ArrowUp" ? -1 : 1)
      return
    }
    if (key !== "Enter") return
    event.preventDefault()
    const inField = event.target === this.customerQueryFieldTarget
    const selected = this.hasCustomerListTarget && this.customerListTarget.querySelector("li.is-selected:not(.is-disabled)")
    if (inField && (!this.customerResultsReady || !selected)) {
      this.runCustomerSearch()
      return
    }
    this.selectHighlightedCustomer()
  }

  onQuickCustomerOverlayKeydown(event, key) {
    if (key === "Escape") {
      event.preventDefault()
      this.closeQuickCustomerOverlay()
      return
    }
    if (key === "Enter" && !event.target.matches("textarea")) {
      event.preventDefault()
      this.submitQuickCustomer()
    }
  }

  async runCustomerSearch() {
    const query = this.hasCustomerQueryFieldTarget ? this.customerQueryFieldTarget.value.trim() : ""
    if (!query) {
      this.renderCustomerResults([])
      if (this.hasCustomerQueryLabelTarget) this.customerQueryLabelTarget.textContent = "Enter a search."
      this.focusOverlayEntry(this.customerQueryFieldTarget)
      return
    }
    if (this.customerAbort) this.customerAbort.abort()
    this.customerAbort = new AbortController()
    const token = ++this.customerRequestToken
    if (this.hasCustomerQueryLabelTarget) this.customerQueryLabelTarget.textContent = "Searching…"
    const url = new URL(this.customerSearchUrlValue, window.location.origin)
    url.searchParams.set("q", query)
    try {
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        signal: this.customerAbort.signal
      })
      const payload = await response.json()
      if (!this.lookupResponseCurrent("customer", token)) return
      if (!response.ok) throw new Error(payload.error || "customer search failed")
      this.renderCustomerResults(payload.results || [])
    } catch (error) {
      if (error?.name === "AbortError") return
      if (!this.lookupResponseCurrent("customer", token)) return
      this.renderCustomerResults([])
      if (this.hasCustomerQueryLabelTarget) this.customerQueryLabelTarget.textContent = "Search failed."
      this.focusOverlayEntry(this.customerQueryFieldTarget)
    }
  }

  renderCustomerResults(rows) {
    if (!this.hasCustomerListTarget) return
    this.customerListTarget.replaceChildren()
    this.customerResultsReady = true
    if (this.hasCustomerQueryLabelTarget) {
      this.customerQueryLabelTarget.textContent = rows.length === 0 ? "No matching customers." : ""
    }
    let firstEnabled = null
    rows.forEach((row) => {
      const item = document.createElement("li")
      item.dataset.customerId = row.id
      item.textContent = row.label
      const selected = firstEnabled == null
      if (selected) firstEnabled = item
      this.decoratePickerItem(item, { selected, disabled: false })
      item.addEventListener("click", () => this.onPickerItemClick(this.customerListTarget, item))
      this.customerListTarget.append(item)
    })
    if (firstEnabled) this.focusOverlayEntry(firstEnabled)
    else this.focusOverlayEntry(this.customerQueryFieldTarget)
  }

  selectHighlightedCustomer() {
    const selected = this.hasCustomerListTarget && this.customerListTarget.querySelector("li.is-selected")
    if (!selected) return
    this.closeCustomerOverlay()
    if (!this.hasAttachCustomerFormTarget || !this.hasAttachCustomerIdInputTarget) return
    this.attachCustomerIdInputTarget.value = selected.dataset.customerId
    this.attachCustomerFormTarget.requestSubmit()
  }

  confirmCustomerSelection(event) {
    if (event) event.preventDefault()
    this.selectHighlightedCustomer()
  }

  keepCurrentCustomer(event) {
    if (event) event.preventDefault()
    this.closeCustomerOverlay()
  }

  openQuickCustomerOverlay(event) {
    if (event) event.preventDefault()
    if (!this.quickCustomerAllowedValue || !this.hasQuickCustomerOverlayTarget) return
    this.resetQuickCustomerOverlay()
    this.syncQuickCustomerContextLabel()
    this.showOverlay(
      this.quickCustomerOverlayTarget,
      {
        parent: this.hasCustomerOverlayTarget ? this.customerOverlayTarget : null,
        initialFocus: this.hasQuickCustomerDisplayNameFieldTarget && this.quickCustomerDisplayNameFieldTarget
      }
    )
  }

  closeQuickCustomerOverlay(event) {
    if (event) event.preventDefault()
    this.hideOverlay(this.hasQuickCustomerOverlayTarget && this.quickCustomerOverlayTarget)
  }

  resetQuickCustomerOverlay() {
    this.quickCustomerIdempotencyKey = this.uuidV7()
    if (this.hasQuickCustomerDisplayNameFieldTarget) this.quickCustomerDisplayNameFieldTarget.value = ""
    if (this.hasQuickCustomerEmailFieldTarget) this.quickCustomerEmailFieldTarget.value = ""
    if (this.hasQuickCustomerPhoneFieldTarget) this.quickCustomerPhoneFieldTarget.value = ""
    if (this.hasQuickCustomerAcknowledgeFieldTarget) this.quickCustomerAcknowledgeFieldTarget.checked = false
    this.clearQuickCustomerDuplicates()
    if (this.hasQuickCustomerOverlayTarget) this.clearOverlayError(this.quickCustomerOverlayTarget)
  }

  clearQuickCustomerDuplicates() {
    if (this.hasQuickCustomerDuplicateWrapTarget) this.quickCustomerDuplicateWrapTarget.hidden = true
    if (this.hasQuickCustomerDuplicateListTarget) this.quickCustomerDuplicateListTarget.replaceChildren()
  }

  syncQuickCustomerContextLabel() {
    if (!this.hasQuickCustomerContextLabelTarget) return
    const context = this.customerLookupContext
    if (context === "store_credit" || context === "trade_credit") {
      this.quickCustomerContextLabelTarget.textContent = "Email or phone is required for store-credit and trade-credit flows."
    } else if (context === "customer_store_credit") {
      this.quickCustomerContextLabelTarget.textContent = "Email or phone is required for customer store-credit refunds."
    } else {
      this.quickCustomerContextLabelTarget.textContent = "Create a customer identity and attach it to this transaction."
    }
  }

  quickCustomerRequiresContact() {
    return this.customerLookupContext === "store_credit" ||
      this.customerLookupContext === "trade_credit" ||
      this.customerLookupContext === "customer_store_credit"
  }

  renderQuickCustomerDuplicates(rows) {
    if (!this.hasQuickCustomerDuplicateWrapTarget || !this.hasQuickCustomerDuplicateListTarget) return
    this.quickCustomerDuplicateWrapTarget.hidden = false
    this.quickCustomerDuplicateListTarget.replaceChildren()
    rows.forEach((row, index) => {
      const item = document.createElement("li")
      item.textContent = row.label || [row.display_name, row.email, row.phone].filter(Boolean).join(" · ")
      this.decoratePickerItem(item, { selected: index === 0, disabled: true })
      this.quickCustomerDuplicateListTarget.append(item)
    })
  }

  async submitQuickCustomer(event) {
    if (event) event.preventDefault()
    if (this.inFlight || !this.hasQuickCustomerOverlayTarget) return
    const displayName = this.hasQuickCustomerDisplayNameFieldTarget ? this.quickCustomerDisplayNameFieldTarget.value.trim() : ""
    const email = this.hasQuickCustomerEmailFieldTarget ? this.quickCustomerEmailFieldTarget.value.trim() : ""
    const phone = this.hasQuickCustomerPhoneFieldTarget ? this.quickCustomerPhoneFieldTarget.value.trim() : ""
    if (!displayName) {
      this.setQuickCustomerFeedback("Display name is required.")
      if (this.hasQuickCustomerDisplayNameFieldTarget) this.focusOverlayEntry(this.quickCustomerDisplayNameFieldTarget)
      return
    }
    if (this.quickCustomerRequiresContact() && !email && !phone) {
      this.setQuickCustomerFeedback("Email or phone is required for this flow.")
      const focusTarget = this.hasQuickCustomerEmailFieldTarget ? this.quickCustomerEmailFieldTarget : this.quickCustomerPhoneFieldTarget
      if (focusTarget) this.focusOverlayEntry(focusTarget)
      return
    }

    if (!this.quickCustomerIdempotencyKey) this.quickCustomerIdempotencyKey = this.uuidV7()
    const acknowledge = this.hasQuickCustomerAcknowledgeFieldTarget && this.quickCustomerAcknowledgeFieldTarget.checked

    this.beginFlight()
    try {
      const body = new FormData()
      body.set("display_name", displayName)
      if (email) body.set("email", email)
      if (phone) body.set("phone", phone)
      body.set("idempotency_key", this.quickCustomerIdempotencyKey)
      if (this.customerLookupContext) {
        body.set("customer_context", this.customerLookupContext)
      }
      if (acknowledge) body.set("acknowledge_duplicates", "1")

      const response = await fetch(this.quickCustomerUrlValue, {
        method: "POST",
        headers: {
          Accept: "text/vnd.turbo-stream.html, text/html, application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body,
        credentials: "same-origin"
      })

      const contentType = response.headers.get("content-type") || ""
      if (contentType.includes("application/json")) {
        const payload = await response.json()
        if (response.ok) {
          window.location.assign(this.workspaceUrlValue)
          return
        }
        if (payload.error === "duplicates") {
          // Acknowledged create is a new deliberate command — rotate the key so the
          // acknowledge_duplicates change cannot collide with the failed probe payload.
          this.quickCustomerIdempotencyKey = this.uuidV7()
          this.setQuickCustomerFeedback(payload.message || "Possible duplicate customers found.")
          this.renderQuickCustomerDuplicates(payload.suggestions || [])
          if (this.hasQuickCustomerAcknowledgeFieldTarget) this.focusOverlayEntry(this.quickCustomerAcknowledgeFieldTarget)
          return
        }
        this.setQuickCustomerFeedback(payload.message || "Quick Customer could not be completed.")
        return
      }

      const html = await response.text()
      if (response.ok) {
        Turbo.renderStreamMessage(html)
        this.clearOverlayStack({ restoreCommand: false })
        return
      }

      Turbo.renderStreamMessage(html)
    } catch (_error) {
      this.setQuickCustomerFeedback("Quick Customer could not be completed.")
    } finally {
      this.inFlight = false
      this.enableReadyActions()
    }
  }

  setQuickCustomerFeedback(message) {
    if (!this.hasQuickCustomerOverlayTarget) return
    const node = this.quickCustomerOverlayTarget.querySelector("[data-overlay-error]")
    if (node) node.textContent = message || ""
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }


  openProductPicker(products) {
    if (!this.hasProductOverlayTarget || !this.hasProductListTarget) return
    this.productListTarget.replaceChildren()
    products.forEach((product, index) => {
      const item = document.createElement("li")
      item.dataset.productId = product.id
      const identity = [product.primary_identifier, product.industry_identifier, product.lookup_code].filter(Boolean).join(" · ")
      const descriptor = [product.name, product.subtitle, product.brand_name].filter(Boolean).join(" — ")
      item.textContent = [descriptor, identity].filter(Boolean).join(" · ")
      this.decoratePickerItem(item, { selected: index === 0 })
      item.addEventListener("click", () => this.onPickerItemClick(this.productListTarget, item))
      this.productListTarget.append(item)
    })
    this.showOverlay(this.productOverlayTarget, this.productListTarget.querySelector("li.is-selected"))
  }

  closeProductOverlay() {
    this.hideOverlay(this.hasProductOverlayTarget && this.productOverlayTarget)
  }

  onProductOverlayKeydown(event, key) {
    if (key === "Escape") {
      event.preventDefault()
      this.closeProductOverlay()
      this.abortUnlinkedPicker()
      return
    }
    if (key === "ArrowUp" || key === "ArrowDown") {
      event.preventDefault()
      this.movePickerList(this.productListTarget, key === "ArrowUp" ? -1 : 1)
      return
    }
    if (key === "Enter") {
      event.preventDefault()
      this.selectHighlightedProduct()
    }
  }

  selectHighlightedProduct() {
    const selected = this.hasProductListTarget && this.productListTarget.querySelector("li.is-selected")
    if (!selected || !selected.dataset.productId || selected.classList.contains("is-disabled")) return
    const productId = selected.dataset.productId
    if (this.unlinkedPickerActive) {
      this.unlinkedPickerActive = false
      this.closeProductOverlay()
      this.fetchUnlinkedResolution({ product_id: productId })
      return
    }
    this.resolveAndHandle({ product_id: productId })
  }

  confirmProductSelection(event) {
    if (event) event.preventDefault()
    this.selectHighlightedProduct()
  }

  backFromProductOverlay(event) {
    if (event) event.preventDefault()
    this.closeProductOverlay()
    this.abortUnlinkedPicker()
  }

  openVariantPicker(variants) {
    if (!this.hasVariantOverlayTarget || !this.hasVariantListTarget) return
    this.syncNestedPickerBackLabels()
    this.variantListTarget.replaceChildren()
    variants.forEach((variant, index) => {
      const item = document.createElement("li")
      item.dataset.variantId = variant.id
      const price = variant.price_label || this.formatCents(variant.price_cents)
      const availability = variant.available == null ? "" : ` · ${variant.available}`
      item.textContent = [variant.sku, variant.name, variant.condition, price].filter(Boolean).join(" · ") + availability
      this.decoratePickerItem(item, { selected: index === 0 })
      item.addEventListener("click", () => this.onPickerItemClick(this.variantListTarget, item))
      this.variantListTarget.append(item)
    })
    this.showOverlay(this.variantOverlayTarget, this.variantListTarget.querySelector("li.is-selected"))
  }

  closeVariantOverlay() {
    this.hideOverlay(this.hasVariantOverlayTarget && this.variantOverlayTarget)
  }

  onVariantOverlayKeydown(event, key) {
    if (key === "Escape") {
      event.preventDefault()
      this.closeVariantOverlay()
      this.abortUnlinkedPicker()
      return
    }
    if (key === "ArrowUp" || key === "ArrowDown") {
      event.preventDefault()
      this.movePickerList(this.variantListTarget, key === "ArrowUp" ? -1 : 1)
      return
    }
    if (key === "Enter") {
      event.preventDefault()
      this.selectHighlightedVariant()
    }
  }

  selectHighlightedVariant() {
    const selected = this.hasVariantListTarget && this.variantListTarget.querySelector("li.is-selected")
    if (!selected || selected.classList.contains("is-disabled")) return
    const variantId = selected.dataset.variantId
    if (this.unlinkedPickerActive) {
      this.unlinkedPickerActive = false
      this.closeVariantOverlay()
      this.fetchUnlinkedResolution({ product_variant_id: variantId })
      return
    }
    this.resolveAndHandle({ product_variant_id: variantId })
  }

  confirmVariantSelection(event) {
    if (event) event.preventDefault()
    this.selectHighlightedVariant()
  }

  backToProducts(event) {
    if (event) event.preventDefault()
    this.closeVariantOverlay()
    this.abortUnlinkedPicker()
  }

  syncNestedPickerBackLabels() {
    const unlinked = Boolean(this.unlinkedPickerActive)
    if (this.hasVariantBackTarget) {
      this.variantBackTarget.textContent = unlinked ? "Back to Item Lookup" : "Back to Products"
    }
    if (this.hasUnitBackTarget) {
      this.unitBackTarget.textContent = unlinked ? "Back to Item Lookup" : "Back to Variants"
    }
  }

  openUnitPicker(units) {
    if (!this.hasUnitOverlayTarget || !this.hasUnitListTarget) return
    this.syncNestedPickerBackLabels()
    this.unitListTarget.replaceChildren()
    if (units.length === 0) {
      const item = document.createElement("li")
      item.textContent = "No units available."
      this.decoratePickerItem(item, { disabled: true })
      this.unitListTarget.append(item)
    }
    units.forEach((unit, index) => {
      const item = document.createElement("li")
      item.dataset.unitId = unit.id
      item.textContent = [unit.unit_identifier, unit.condition, this.formatCents(unit.price_cents)].filter(Boolean).join(" · ")
      this.decoratePickerItem(item, { selected: index === 0 })
      item.addEventListener("click", () => this.onPickerItemClick(this.unitListTarget, item))
      this.unitListTarget.append(item)
    })
    this.showOverlay(this.unitOverlayTarget, this.unitListTarget.querySelector("li.is-selected"))
  }

  closeUnitOverlay() {
    this.hideOverlay(this.hasUnitOverlayTarget && this.unitOverlayTarget)
  }

  onUnitOverlayKeydown(event, key) {
    if (key === "Escape") {
      event.preventDefault()
      this.closeUnitOverlay()
      this.abortUnlinkedPicker()
      return
    }
    if (key === "ArrowUp" || key === "ArrowDown") {
      event.preventDefault()
      this.movePickerList(this.unitListTarget, key === "ArrowUp" ? -1 : 1)
      return
    }
    if (key === "Enter") {
      event.preventDefault()
      this.selectHighlightedUnit()
    }
  }

  selectHighlightedUnit() {
    const selected = this.hasUnitListTarget && this.unitListTarget.querySelector("li.is-selected")
    if (!selected || !selected.dataset.unitId || selected.classList.contains("is-disabled")) return
    const unitId = selected.dataset.unitId
    if (this.unlinkedPickerActive) {
      this.unlinkedPickerActive = false
      this.closeUnitOverlay()
      this.fetchUnlinkedResolution({ inventory_unit_id: unitId })
      return
    }
    this.resolveAndHandle({ inventory_unit_id: unitId })
  }

  confirmUnitSelection(event) {
    if (event) event.preventDefault()
    this.selectHighlightedUnit()
  }

  backToVariants(event) {
    if (event) event.preventDefault()
    this.closeUnitOverlay()
    this.abortUnlinkedPicker()
  }

  movePickerList(list, delta) {
    if (!list) return
    const all = Array.from(list.querySelectorAll("li"))
    const items = all.filter((item) => !item.classList.contains("is-disabled"))
    if (items.length === 0) return
    const current = items.findIndex((item) => item.classList.contains("is-selected"))
    const nextIndex = Math.min(items.length - 1, Math.max(0, (current < 0 ? 0 : current) + delta))
    all.forEach((item) => {
      const selected = item === items[nextIndex]
      item.classList.toggle("is-selected", selected)
      item.setAttribute("aria-selected", selected ? "true" : "false")
      item.tabIndex = selected ? 0 : -1
    })
    items[nextIndex].focus()
  }

  openOpenPriceOverlay({ kind, variantId, lineId, prompt, currentCents }) {
    if (!this.hasOpenPriceOverlayTarget) return
    this.pendingOpenPrice = { kind, variantId, lineId }
    if (this.hasOpenPricePromptTarget) this.openPricePromptTarget.textContent = prompt || "Enter the selling price."
    if (this.hasOpenPriceFieldTarget) {
      this.openPriceFieldTarget.value = currentCents != null ? this.formatCents(currentCents) : ""
    }
    if (this.hasOpenPriceTitleTarget) {
      this.openPriceTitleTarget.textContent = kind === "edit" ? "Edit open price" : "Open price"
    }
    this.showOverlay(this.openPriceOverlayTarget, this.hasOpenPriceFieldTarget && this.openPriceFieldTarget)
  }

  closeOpenPriceOverlay() {
    if (!this.hasOpenPriceOverlayTarget) return
    this.pendingOpenPrice = null
    this.hideOverlay(this.openPriceOverlayTarget)
  }

  onOpenPriceOverlayKeydown(event, key) {
    if (key === "Escape") {
      event.preventDefault()
      this.closeOpenPriceOverlay()
      return
    }
    if (key === "Enter") {
      event.preventDefault()
      this.submitOpenPricePrompt()
    }
  }

  submitOpenPricePrompt() {
    if (this.inFlight || !this.pendingOpenPrice) return
    const value = this.hasOpenPriceFieldTarget ? this.openPriceFieldTarget.value.trim() : ""
    if (value === "") return
    const pending = this.pendingOpenPrice
    this.pendingOpenPrice = null
    this.clearOverlayError(this.openPriceOverlayTarget)
    if (pending.kind === "edit") {
      this.clearOverlayStack({ restoreCommand: false })
      if (this.hasOpenPriceLineInputTarget) this.openPriceLineInputTarget.value = pending.lineId
      if (this.hasOpenPriceEditInputTarget) this.openPriceEditInputTarget.value = value
      this.beginFlight()
      this.openPriceFormTarget.requestSubmit()
      return
    }
    this.clearOverlayStack({ restoreCommand: false })
    this.postAddMerchandise({ variantId: pending.variantId, sellingPrice: value })
  }

  priceActionEnabled() {
    const row = this.selectedRow()
    if (!row) return false
    if (row.dataset.pricingMethodSnapshot === "open_price") return true
    return this.policyFor("price_override") !== "prohibited"
  }

  openReturnChooser() {
    if (this.inFlight || this.modeValue !== "sale_entry") return
    if (!this.hasReturnChooserOverlayTarget) return
    const items = Array.from(this.returnChooserListTarget.querySelectorAll("li"))
    const unlinkedProhibited = this.policyFor("unlinked_return") === "prohibited"
    let firstEnabled = null
    items.forEach((item) => {
      const disabled = item.dataset.choice === "unlinked" && unlinkedProhibited
      const muted = item.querySelector(".muted")
      if (item.dataset.choice === "unlinked" && muted) {
        muted.textContent = disabled
          ? "Not available for your role."
          : "Requires a reason and may require authorization."
      }
      const selected = !disabled && firstEnabled == null
      if (selected) firstEnabled = item
      this.decoratePickerItem(item, { selected, disabled })
      item.onclick = () => {
        this.onPickerItemClick(this.returnChooserListTarget, item)
        this.syncReturnChooserContinue()
      }
    })
    this.showOverlay(this.returnChooserOverlayTarget, firstEnabled || items[0])
    this.syncReturnChooserContinue()
  }

  closeReturnChooser() {
    this.invalidateLinkedLookup()
    this.invalidateUnlinkedLookup()
    this.hideOverlay(this.hasReturnChooserOverlayTarget && this.returnChooserOverlayTarget)
  }

  keepSaleMode(event) {
    if (event) event.preventDefault()
    this.closeReturnChooser()
  }

  onReturnChooserKeydown(event, key) {
    if (key === "Escape") {
      event.preventDefault()
      this.closeReturnChooser()
      return
    }
    if (key === "ArrowUp" || key === "ArrowDown") {
      event.preventDefault()
      this.movePickerList(this.returnChooserListTarget, key === "ArrowUp" ? -1 : 1)
      this.syncReturnChooserContinue()
      return
    }
    if (key === "Enter") {
      event.preventDefault()
      this.confirmReturnChooser()
    }
  }

  syncReturnChooserContinue() {
    if (!this.hasReturnChooserContinueTarget) return
    const selected = this.hasReturnChooserListTarget && this.returnChooserListTarget.querySelector("li.is-selected:not(.is-disabled)")
    this.returnChooserContinueTarget.disabled = !selected
  }

  confirmReturnChooser(event) {
    if (event) event.preventDefault()
    this.selectReturnChooser()
  }

  selectReturnChooser() {
    const selected = this.hasReturnChooserListTarget && this.returnChooserListTarget.querySelector("li.is-selected:not(.is-disabled)")
    if (!selected) return
    const choice = selected.dataset.choice
    // Keep chooser on the stack as parent of linked/unlinked.
    if (choice === "unlinked") {
      if (this.policyFor("unlinked_return") === "prohibited") return
      this.openUnlinkedOverlay()
      return
    }
    this.openLinkedOverlay()
  }

  openLinkedOverlay() {
    if (this.inFlight || this.modeValue !== "sale_entry") return
    if (!this.hasLinkedOverlayTarget) return
    this.invalidateLinkedLookup()
    this.linkedStage = "lookup"
    if (this.hasLinkedLookupFieldTarget) this.linkedLookupFieldTarget.value = ""
    if (this.hasLinkedFeedbackTarget) this.linkedFeedbackTarget.textContent = ""
    if (this.hasLinkedQueryLabelTarget) this.linkedQueryLabelTarget.textContent = ""
    if (this.hasLinkedListTarget) this.linkedListTarget.replaceChildren()
    if (this.hasLinkedQuantityFieldTarget) this.linkedQuantityFieldTarget.value = "1"
    this.populateLinkedReasons()
    this.toggleHidden(this.hasLinkedNoteWrapTarget && this.linkedNoteWrapTarget, true)
    this.syncLinkedStageChrome()
    this.showOverlay(this.linkedOverlayTarget, this.hasLinkedLookupFieldTarget && this.linkedLookupFieldTarget)
  }

  closeLinkedOverlay() {
    this.invalidateLinkedLookup()
    this.hideOverlay(this.hasLinkedOverlayTarget && this.linkedOverlayTarget)
  }

  invalidateLinkedLookup() {
    if (this.linkedAbort) this.linkedAbort.abort()
    this.linkedAbort = null
    this.linkedInvocation += 1
  }

  invalidateLinkedResultsOnInput() {
    this.syncLinkedPrimaryEnabled()
    const hasResults = this.hasLinkedListTarget && this.linkedListTarget.children.length > 0
    const searching = this.hasLinkedQueryLabelTarget && this.linkedQueryLabelTarget.textContent
    if (this.linkedStage === "lookup" && !hasResults && !searching) return
    this.invalidateLinkedLookup()
    if (this.hasLinkedListTarget) this.linkedListTarget.replaceChildren()
    if (this.hasLinkedFeedbackTarget) this.linkedFeedbackTarget.textContent = ""
    if (this.hasLinkedQueryLabelTarget) this.linkedQueryLabelTarget.textContent = ""
    this.linkedReceiptCacheHtml = null
    this.linkedStage = "lookup"
    this.syncLinkedStageChrome()
  }

  populateLinkedReasons() {
    if (!this.hasLinkedReasonFieldTarget) return
    const entries = this.returnReasonsValue || []
    this.linkedReasonFieldTarget.replaceChildren()
    const blank = document.createElement("option")
    blank.value = ""
    blank.textContent = "Select…"
    this.linkedReasonFieldTarget.append(blank)
    entries.forEach((entry) => {
      const option = document.createElement("option")
      option.value = entry.code
      option.textContent = entry.name
      this.linkedReasonFieldTarget.append(option)
    })
  }

  onLinkedReasonChange() {
    const reason = this.hasLinkedReasonFieldTarget ? this.linkedReasonFieldTarget.value : ""
    this.toggleHidden(this.hasLinkedNoteWrapTarget && this.linkedNoteWrapTarget, reason !== "other")
    this.syncLinkedPrimaryEnabled()
  }

  syncLinkedStageChrome() {
    const stage = this.linkedStage || "lookup"
    if (this.hasLinkedLookupWrapTarget) this.linkedLookupWrapTarget.hidden = stage !== "lookup"
    if (this.hasLinkedDetailsWrapTarget) this.linkedDetailsWrapTarget.hidden = stage !== "lines"
    if (this.hasLinkedInstructionTarget) {
      if (stage === "lookup") this.linkedInstructionTarget.textContent = "Find a receipt, then choose returnable items."
      else if (stage === "receipts") this.linkedInstructionTarget.textContent = "Select a receipt to view returnable items."
      else this.linkedInstructionTarget.textContent = "Select a returnable line and enter return details."
    }
    if (this.hasLinkedSecondaryTarget) {
      if (stage === "lookup") this.linkedSecondaryTarget.textContent = "Back to Return Options"
      else if (stage === "receipts") this.linkedSecondaryTarget.textContent = "Back"
      else this.linkedSecondaryTarget.textContent = "Back to Receipts"
    }
    if (this.hasLinkedPrimaryTarget) {
      if (stage === "lookup") this.linkedPrimaryTarget.textContent = "Find Receipt"
      else if (stage === "receipts") this.linkedPrimaryTarget.textContent = "View Returnable Items"
      else this.linkedPrimaryTarget.textContent = "Add Return"
    }
    this.syncLinkedPrimaryEnabled()
  }

  syncLinkedPrimaryEnabled() {
    if (this.hasLinkedSecondaryTarget) this.linkedSecondaryTarget.disabled = this.inFlight
    if (!this.hasLinkedPrimaryTarget) return
    const stage = this.linkedStage || "lookup"
    if (stage === "lookup") {
      const query = this.hasLinkedLookupFieldTarget ? this.linkedLookupFieldTarget.value.trim() : ""
      this.linkedPrimaryTarget.disabled = !query || this.inFlight
      return
    }
    const selected = this.hasLinkedListTarget && this.linkedListTarget.querySelector("li.is-selected:not(.is-disabled)")
    if (stage === "receipts") {
      this.linkedPrimaryTarget.disabled = !selected || this.inFlight
      return
    }
    this.linkedPrimaryTarget.disabled = !this.linkedLineReady(selected) || this.inFlight
  }

  linkedLineReady(selected) {
    if (!selected || selected.classList.contains("is-disabled")) return false
    const reason = this.hasLinkedReasonFieldTarget ? this.linkedReasonFieldTarget.value : ""
    if (!reason) return false
    if (reason === "other" && this.hasLinkedNoteFieldTarget && this.linkedNoteFieldTarget.value.trim() === "") return false
    if (selected.dataset.quantityFixed !== "true") {
      const qty = this.hasLinkedQuantityFieldTarget ? this.linkedQuantityFieldTarget.value.trim() : ""
      if (!qty || Number(qty) <= 0) return false
    }
    return true
  }

  onLinkedOverlayKeydown(event, key) {
    if (key === "Escape") {
      event.preventDefault()
      this.linkedEscapeOrBack()
      return
    }
    if (key === "ArrowUp" || key === "ArrowDown") {
      event.preventDefault()
      if (this.linkedStage === "lookup") return
      this.movePickerList(this.linkedListTarget, key === "ArrowUp" ? -1 : 1)
      this.syncLinkedPrimaryEnabled()
      return
    }
    if (key !== "Enter") return
    event.preventDefault()
    if (event.target === this.linkedLookupFieldTarget || this.linkedStage === "lookup") {
      this.runLinkedLookup()
      return
    }
    this.linkedPrimaryAction()
  }

  linkedSecondaryAction(event) {
    if (event) event.preventDefault()
    this.linkedEscapeOrBack()
  }

  linkedPrimaryAction(event) {
    if (event) event.preventDefault()
    if (this.inFlight) return
    const stage = this.linkedStage || "lookup"
    if (stage === "lookup") {
      this.runLinkedLookup()
      return
    }
    if (stage === "receipts") {
      this.selectHighlightedLinked()
      return
    }
    this.selectHighlightedLinked()
  }

  linkedEscapeOrBack() {
    if (this.inFlight) return
    const stage = this.linkedStage || "lookup"
    if (stage === "lines") {
      // Abandon any in-flight lookup/lines request before reversing stage.
      this.invalidateLinkedLookup()
      if (this.hasLinkedQueryLabelTarget) this.linkedQueryLabelTarget.textContent = ""
      if (this.linkedReceiptCacheHtml) {
        this.linkedStage = "receipts"
        if (this.hasLinkedListTarget) this.linkedListTarget.innerHTML = this.linkedReceiptCacheHtml
        this.linkedListTarget.querySelectorAll("li").forEach((item) => {
          item.addEventListener("click", () => {
            this.onPickerItemClick(this.linkedListTarget, item)
            this.syncLinkedPrimaryEnabled()
          })
        })
        this.syncLinkedStageChrome()
        const first = this.linkedListTarget.querySelector("li.is-selected:not(.is-disabled)") ||
          this.linkedListTarget.querySelector("li:not(.is-disabled)")
        this.focusOverlayEntry(first)
        return
      }
      this.linkedStage = "lookup"
      if (this.hasLinkedListTarget) this.linkedListTarget.replaceChildren()
      this.syncLinkedStageChrome()
      this.focusOverlayEntry(this.hasLinkedLookupFieldTarget && this.linkedLookupFieldTarget)
      return
    }
    if (stage === "receipts") {
      this.invalidateLinkedLookup()
      if (this.hasLinkedQueryLabelTarget) this.linkedQueryLabelTarget.textContent = ""
      this.linkedStage = "lookup"
      this.linkedReceiptCacheHtml = null
      if (this.hasLinkedListTarget) this.linkedListTarget.replaceChildren()
      if (this.hasLinkedFeedbackTarget) this.linkedFeedbackTarget.textContent = ""
      this.syncLinkedStageChrome()
      this.focusOverlayEntry(this.hasLinkedLookupFieldTarget && this.linkedLookupFieldTarget)
      return
    }
    this.closeLinkedOverlay()
  }

  async runLinkedLookup(params = {}) {
    const query = this.hasLinkedLookupFieldTarget ? this.linkedLookupFieldTarget.value.trim() : ""
    if (!params.transaction_id && !query) return
    if (this.linkedAbort) this.linkedAbort.abort()
    this.linkedAbort = new AbortController()
    const token = ++this.linkedInvocation
    if (this.hasLinkedQueryLabelTarget) this.linkedQueryLabelTarget.textContent = "Searching…"
    const url = new URL(this.linkedLookupUrlValue, window.location.origin)
    if (params.transaction_id) url.searchParams.set("transaction_id", params.transaction_id)
    else url.searchParams.set("q", query)
    try {
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
        signal: this.linkedAbort.signal
      })
      const payload = await response.json()
      if (!this.linkedResponseCurrent(token)) return
      this.renderLinkedLookup(payload)
    } catch (error) {
      if (error?.name === "AbortError") return
      if (!this.linkedResponseCurrent(token)) return
      if (this.hasLinkedFeedbackTarget) this.linkedFeedbackTarget.textContent = "no returnable original found"
      if (this.hasLinkedQueryLabelTarget) this.linkedQueryLabelTarget.textContent = ""
      this.focusOverlayEntry(this.hasLinkedLookupFieldTarget && this.linkedLookupFieldTarget)
    }
  }

  linkedResponseCurrent(token) {
    if (!this.element.isConnected) return false
    if (token !== this.linkedInvocation) return false
    return this.linkedOverlayOpen()
  }

  renderLinkedLookup(payload) {
    if (this.hasLinkedFeedbackTarget) this.linkedFeedbackTarget.textContent = payload.message || ""
    if (this.hasLinkedQueryLabelTarget) this.linkedQueryLabelTarget.textContent = ""
    if (!this.hasLinkedListTarget) return
    this.linkedListTarget.replaceChildren()
    if (payload.outcome === "receipts") {
      this.linkedStage = "receipts"
      this.linkedReceiptCacheHtml = null
      ;(payload.receipts || []).forEach((receipt, index) => {
        const item = document.createElement("li")
        item.dataset.transactionId = receipt.id
        item.textContent = receipt.transaction_reference
        const selected = index === 0
        this.decoratePickerItem(item, { selected, disabled: false })
        item.addEventListener("click", () => {
          this.onPickerItemClick(this.linkedListTarget, item)
          this.syncLinkedPrimaryEnabled()
        })
        this.linkedListTarget.append(item)
      })
      this.linkedReceiptCacheHtml = this.linkedListTarget.innerHTML
    } else if (payload.outcome === "lines") {
      this.linkedStage = "lines"
      let firstEnabled = null
      ;(payload.lines || []).forEach((line) => {
        const item = document.createElement("li")
        item.dataset.lineId = line.id
        item.dataset.remaining = String(line.remaining)
        item.dataset.quantityFixed = line.quantity_fixed ? "true" : "false"
        const ineligible = line.remaining <= 0 || Boolean(line.ineligible)
        const unit = line.unit_identifier ? ` · ${line.unit_identifier}` : ""
        const reason = line.ineligible_reason ? ` — ${line.ineligible_reason}` : ""
        item.textContent = `${line.description} · remaining ${line.remaining}${unit}${reason}`
        const selected = !ineligible && firstEnabled == null
        if (selected) firstEnabled = item
        this.decoratePickerItem(item, { selected, disabled: ineligible })
        item.addEventListener("click", () => {
          this.onPickerItemClick(this.linkedListTarget, item)
          this.syncLinkedPrimaryEnabled()
        })
        this.linkedListTarget.append(item)
      })
    } else if (this.hasLinkedQueryLabelTarget) {
      this.linkedQueryLabelTarget.textContent = payload.message || "No matching receipts."
      this.linkedStage = "lookup"
    }
    this.syncLinkedStageChrome()
    const first = this.linkedListTarget.querySelector("li.is-selected:not(.is-disabled)")
    if (first) this.focusOverlayEntry(first)
    else this.focusOverlayEntry(this.hasLinkedLookupFieldTarget && this.linkedLookupFieldTarget)
  }

  selectHighlightedLinked() {
    if (this.inFlight) return
    const selected = this.hasLinkedListTarget && this.linkedListTarget.querySelector("li.is-selected:not(.is-disabled)")
    if (!selected) return
    if (this.linkedStage === "receipts") {
      this.linkedReceiptCacheHtml = this.linkedListTarget.innerHTML
      this.runLinkedLookup({ transaction_id: selected.dataset.transactionId })
      return
    }
    if (this.linkedStage !== "lines") return
    if (!this.linkedLineReady(selected)) {
      if (this.hasLinkedFeedbackTarget) this.linkedFeedbackTarget.textContent = "Complete quantity, reason, and note."
      return
    }
    const reason = this.hasLinkedReasonFieldTarget ? this.linkedReasonFieldTarget.value : ""
    const quantity = selected.dataset.quantityFixed === "true"
      ? "1"
      : (this.hasLinkedQuantityFieldTarget ? this.linkedQuantityFieldTarget.value.trim() : "1")
    if (this.hasLinkedOriginalInputTarget) this.linkedOriginalInputTarget.value = selected.dataset.lineId
    if (this.hasLinkedQuantityInputTarget) this.linkedQuantityInputTarget.value = quantity
    if (this.hasLinkedReasonInputTarget) this.linkedReasonInputTarget.value = reason
    if (this.hasLinkedNoteInputTarget) {
      this.linkedNoteInputTarget.value = this.hasLinkedNoteFieldTarget ? this.linkedNoteFieldTarget.value.trim() : ""
    }
    this.clearOverlayError(this.linkedOverlayTarget)
    this.beginFlight()
    this.syncLinkedPrimaryEnabled()
    this.linkedReturnFormTarget.requestSubmit()
  }

  removeSelected() {
    if (this.inFlight) return
    if (this.modeValue !== "sale_entry" || !this.selectedRow()) return
    this.syncSelectedLine()
    this.beginFlight()
    this.removeFormTarget.requestSubmit()
  }

  selectTenderType(index) {
    const types = this.cashierTenderTypes()
    if (types.length === 0) return
    const safeIndex = ((index % types.length) + types.length) % types.length
    const type = types[safeIndex]
    if (this.hasTenderTypeInputTarget) this.tenderTypeInputTarget.value = type.id
    const cash = type.category === "cash"
    const refund = this.settlementValue === "refund"
    const name = type.name || (cash ? "Cash" : "Tender")
    this.setMode("tender", refund ? "REFUND" : (cash ? "CASH TENDER" : "TENDER"))
    const due = this.element.querySelector(".pos-totals__due")
    const dueText = due ? due.textContent.trim() : (refund ? "Refund remaining" : "Balance due")
    if (refund) {
      this.setFieldLabel(cash ? `${dueText}. Refund amount` : `${dueText}. ${name} amount`)
    } else {
      this.setFieldLabel(cash ? `${dueText}. Cash presented` : `${dueText}. ${name} amount`)
    }
    this.toggleReferenceField(type.reference_policy)
    this.toggleGiftCardNumberField(type)
    this.promptCustomerLookupIfRequired(type)
  }

  customerRequiredTenderType(type) {
    if (!type || type.category !== "stored_value") return false
    const accountType = type.stored_value_account_type
    if (accountType === "store_credit" || accountType === "trade_credit") return true
    return false
  }

  promptCustomerLookupIfRequired(type) {
    if (!this.customerRequiredTenderType(type)) return
    if (this.customerAttachedValue) return
    this.showFeedback("A customer is required. Find and attach a customer to continue.")
    this.openCustomerOverlay({ context: type.stored_value_account_type })
  }

  toggleGiftCardNumberField(type) {
    if (!this.hasGiftCardNumberWrapTarget) return
    const show = this.modeValue === "tender" && type?.stored_value_account_type === "gift_card"
    this.giftCardNumberWrapTarget.hidden = !show
    if (!show && this.hasGiftCardNumberFieldTarget) this.giftCardNumberFieldTarget.value = ""
  }

  hasCommercialContent() {
    return Boolean(this.element.querySelector(".pos-lines tbody tr") || this.element.querySelector(".pos-issuance"))
  }

  handleGiftCardScan(result) {
    const scanned = this.hasFieldTarget ? this.fieldTarget.value.trim() : ""
    if (this.hasIdentifierInputTarget) this.identifierInputTarget.value = ""
    if (this.hasFieldTarget) this.fieldTarget.value = ""

    if (this.issuanceOverlayOpen()) {
      if (this.hasIssuanceCardNumberTarget) this.issuanceCardNumberTarget.value = scanned
      this.syncIssuanceCardVisibility({ preserveCard: true })
      this.clearOverlayError(this.issuanceOverlayTarget)
      this.enableReadyActions()
      if (this.hasIssuanceCardNumberTarget && !this.issuanceCardWrapTarget?.hidden) {
        this.issuanceCardNumberTarget.focus()
      }
      return
    }

    if (result.found) {
      if (this.settlementValue === "payment" && this.remainingCents() > 0) {
        const gift = this.typesForCategory("stored_value").find((type) => type.stored_value_account_type === "gift_card")
        if (!gift) {
          this.showFeedback("Gift card tender is not available.")
          this.enableReadyActions()
          this.restoreFocus()
          return
        }
        this.beginTenderMode()
        this.applyTenderType(gift)
        if (this.hasGiftCardNumberFieldTarget) this.giftCardNumberFieldTarget.value = scanned
        this.prefillRemaining()
        this.enableReadyActions()
        return
      }
      if (this.cashOutAllowedValue && !this.hasCommercialContent() && this.remainingCents() === 0) {
        if (this.hasCashOutFormTarget && this.hasCashOutCardInputTarget) {
          this.cashOutCardInputTarget.value = scanned
          this.cashOutFormTarget.requestSubmit()
          return
        }
      }
      this.showFeedback(result.masked_number ? `Gift card ${result.masked_number}` : "Gift card on file")
      this.enableReadyActions()
      this.restoreFocus()
      return
    }

    if (result.number_authority === "manual_external" && this.modeValue === "sale_entry") {
      this.openIssuanceOverlay({ cardNumber: scanned, preferManual: true })
      this.showFeedback("Gift card not on file. Enter an activation amount.")
      this.enableReadyActions()
      return
    }

    this.showFeedback(result.message || "gift card not on file")
    this.enableReadyActions()
    this.restoreFocus()
  }

  openIssuanceOverlay({ cardNumber = "", preferManual = false, editIssuanceId = null } = {}) {
    if (!this.hasIssuanceOverlayTarget) return
    const programs = this.hasIssuanceProgramFieldTarget
      ? Array.from(this.issuanceProgramFieldTarget.options).filter((option) => option.value)
      : []
    if (programs.length === 0) {
      this.showFeedback("No gift-card programs are available.")
      return
    }
    this.editingIssuanceId = editIssuanceId
    if (this.hasIssuanceTitleTarget) {
      this.issuanceTitleTarget.textContent = editIssuanceId ? "Edit gift card" : "Add gift card"
    }
    if (this.hasIssuanceApplyTarget) {
      this.issuanceApplyTarget.textContent = editIssuanceId ? "Replace Gift Card" : "Add Gift Card"
    }
    if (this.hasIssuanceTypeFieldTarget) this.issuanceTypeFieldTarget.value = "activation"
    if (this.hasIssuanceAmountFieldTarget) this.issuanceAmountFieldTarget.value = ""
    if (this.hasIssuanceCardNumberTarget) this.issuanceCardNumberTarget.value = cardNumber || ""
    if (this.hasIssuanceResultLabelTarget) this.issuanceResultLabelTarget.textContent = ""
    this.selectIssuanceProgram({ preferManual, cardNumber })
    this.syncIssuanceCardVisibility({ preserveCard: Boolean(cardNumber) })
    this.showOverlay(this.issuanceOverlayTarget, this.hasIssuanceAmountFieldTarget && this.issuanceAmountFieldTarget)
    if (cardNumber && this.issuanceNeedsCard() && this.hasIssuanceCardNumberTarget) {
      this.issuanceAmountFieldTarget?.focus()
      this.issuanceAmountFieldTarget?.select()
    }
  }

  requestEditIssuance(event) {
    if (event) event.preventDefault()
    if (this.inFlight) return
    const button = event?.currentTarget
    const issuanceId = button?.dataset?.issuanceId
    if (!issuanceId) return
    const row = button.closest(".pos-issuance")
    this.openIssuanceOverlay({ editIssuanceId: issuanceId })
    if (row && this.hasIssuanceTypeFieldTarget) this.issuanceTypeFieldTarget.value = row.dataset.issuanceType || "activation"
    if (row && this.hasIssuanceProgramFieldTarget && row.dataset.issuanceProgramId) {
      this.issuanceProgramFieldTarget.value = row.dataset.issuanceProgramId
    }
    if (row && this.hasIssuanceAmountFieldTarget && row.dataset.issuanceAmountCents) {
      const cents = Number(row.dataset.issuanceAmountCents)
      this.issuanceAmountFieldTarget.value = Number.isFinite(cents) ? (cents / 100).toFixed(2) : ""
    }
    if (this.hasIssuanceResultLabelTarget && row?.dataset?.issuanceMasked) {
      this.issuanceResultLabelTarget.textContent = `Current card ${row.dataset.issuanceMasked}. Enter a new amount or card as needed.`
    }
    this.syncIssuanceCardVisibility({ preserveCard: true })
    this.issuanceAmountFieldTarget?.focus()
    this.issuanceAmountFieldTarget?.select()
  }

  selectIssuanceProgram({ preferManual = false } = {}) {
    if (!this.hasIssuanceProgramFieldTarget) return
    const options = Array.from(this.issuanceProgramFieldTarget.options).filter((option) => option.value)
    if (options.length === 0) return

    if (preferManual) {
      const manuals = options.filter((option) => option.dataset.numberAuthority === "manual_external")
      if (manuals.length === 1) {
        this.issuanceProgramFieldTarget.value = manuals[0].value
        return
      }
      if (manuals.length > 1) {
        this.issuanceProgramFieldTarget.value = ""
        if (this.hasIssuanceResultLabelTarget) {
          this.issuanceResultLabelTarget.textContent = "Select the program for this card number."
        }
        return
      }
    }

    this.issuanceProgramFieldTarget.value = options[0].value
  }

  issuanceNeedsCard() {
    if (!this.hasIssuanceProgramFieldTarget) return true
    const option = this.issuanceProgramFieldTarget.selectedOptions[0]
    const reload = this.hasIssuanceTypeFieldTarget && this.issuanceTypeFieldTarget.value === "reload"
    return reload || !option || !option.value || option.dataset.numberAuthority !== "system_generated"
  }

  onIssuanceFieldChange(event) {
    const fromType = this.hasIssuanceTypeFieldTarget && event?.target === this.issuanceTypeFieldTarget
    this.syncIssuanceCardVisibility({ focusCardWhenShown: fromType })
  }

  syncIssuanceCardVisibility({ preserveCard = false, focusCardWhenShown = false } = {}) {
    if (!this.hasIssuanceProgramFieldTarget || !this.hasIssuanceCardWrapTarget) return
    const option = this.issuanceProgramFieldTarget.selectedOptions[0]
    if (this.hasIssuanceTypeFieldTarget && option && option.dataset.reloadAllowed === "false" && this.issuanceTypeFieldTarget.value === "reload") {
      this.issuanceTypeFieldTarget.value = "activation"
    }
    const needsCard = this.issuanceNeedsCard()
    const wasHidden = this.issuanceCardWrapTarget.hidden
    this.issuanceCardWrapTarget.hidden = !needsCard
    if (!needsCard && this.hasIssuanceCardNumberTarget && !preserveCard) {
      this.issuanceCardNumberTarget.value = ""
    }
    if (needsCard && focusCardWhenShown && wasHidden && this.hasIssuanceCardNumberTarget) {
      this.issuanceCardNumberTarget.focus()
      this.issuanceCardNumberTarget.select()
    }
  }

  onIssuanceOverlayKeydown(event, key) {
    if (key === "Escape") {
      event.preventDefault()
      this.closeIssuanceOverlay()
      return
    }
    if (key === "F9" || key === "F10") {
      event.preventDefault()
      return
    }
    if (key !== "Enter") return
    if (this.isActionableControl(event.target)) return
    const submitField =
      (this.hasIssuanceAmountFieldTarget && event.target === this.issuanceAmountFieldTarget) ||
      (this.hasIssuanceCardNumberTarget && event.target === this.issuanceCardNumberTarget)
    if (!submitField) return
    event.preventDefault()
    this.submitIssuance()
  }

  closeIssuanceOverlay() {
    if (!this.hasIssuanceOverlayTarget) return
    this.editingIssuanceId = null
    if (this.hasIssuanceAmountFieldTarget) this.issuanceAmountFieldTarget.value = ""
    if (this.hasIssuanceCardNumberTarget) this.issuanceCardNumberTarget.value = ""
    if (this.hasIssuanceResultLabelTarget) this.issuanceResultLabelTarget.textContent = ""
    if (this.hasIssuanceTitleTarget) this.issuanceTitleTarget.textContent = "Add gift card"
    if (this.hasIssuanceApplyTarget) this.issuanceApplyTarget.textContent = "Add Gift Card"
    this.hideOverlay(this.issuanceOverlayTarget)
  }

  submitIssuance() {
    if (this.inFlight) return
    const amount = this.hasIssuanceAmountFieldTarget ? this.issuanceAmountFieldTarget.value.trim() : ""
    const programId = this.hasIssuanceProgramFieldTarget ? this.issuanceProgramFieldTarget.value : ""
    if (!amount) {
      this.showOverlayLocalError(this.issuanceOverlayTarget, "issuance amount is required")
      this.issuanceAmountFieldTarget?.focus()
      return
    }
    if (!programId) {
      this.showOverlayLocalError(this.issuanceOverlayTarget, "Select a gift-card program.")
      this.issuanceProgramFieldTarget?.focus()
      return
    }
    const needsCard = this.issuanceNeedsCard()
    const cardNumber = this.hasIssuanceCardNumberTarget ? this.issuanceCardNumberTarget.value.trim() : ""
    if (needsCard && !cardNumber && !this.editingIssuanceId) {
      this.showOverlayLocalError(this.issuanceOverlayTarget, "Card number is required for this program.")
      this.issuanceCardNumberTarget?.focus()
      return
    }
    this.clearOverlayError(this.issuanceOverlayTarget)

    if (this.editingIssuanceId) {
      if (!this.hasReplaceIssuanceFormTarget) return
      if (this.hasReplaceIssuanceIdInputTarget) this.replaceIssuanceIdInputTarget.value = this.editingIssuanceId
      if (this.hasReplaceIssuanceTypeInputTarget) this.replaceIssuanceTypeInputTarget.value = this.issuanceTypeFieldTarget.value
      if (this.hasReplaceIssuanceProgramInputTarget) this.replaceIssuanceProgramInputTarget.value = programId
      if (this.hasReplaceIssuanceAmountInputTarget) this.replaceIssuanceAmountInputTarget.value = amount
      if (this.hasReplaceIssuanceCardInputTarget) this.replaceIssuanceCardInputTarget.value = needsCard ? cardNumber : ""
      if (this.hasReplaceIssuanceOperationInputTarget) this.replaceIssuanceOperationInputTarget.value = this.uuidV7()
      if (this.hasReplaceIssuanceConfirmClearInputTarget) this.replaceIssuanceConfirmClearInputTarget.value = ""
      if (this.tendersApplied()) {
        this.requestClearTendersConfirmation("replace")
        return
      }
      this.beginFlight()
      this.replaceIssuanceFormTarget.requestSubmit()
      return
    }

    if (!this.hasIssuanceFormTarget) return
    if (this.hasIssuanceTypeInputTarget) this.issuanceTypeInputTarget.value = this.issuanceTypeFieldTarget.value
    if (this.hasIssuanceProgramInputTarget) this.issuanceProgramInputTarget.value = programId
    if (this.hasIssuanceAmountInputTarget) this.issuanceAmountInputTarget.value = amount
    if (this.hasIssuanceCardInputTarget) this.issuanceCardInputTarget.value = needsCard ? cardNumber : ""
    if (this.hasIssuanceOperationInputTarget) this.issuanceOperationInputTarget.value = this.uuidV7()
    if (this.hasIssuanceConfirmClearInputTarget) this.issuanceConfirmClearInputTarget.value = ""
    if (this.tendersApplied()) {
      this.requestClearTendersConfirmation("add")
      return
    }
    this.beginFlight()
    this.issuanceFormTarget.requestSubmit()
  }

  requestRemoveIssuance(event) {
    if (event) event.preventDefault()
    if (this.inFlight || !this.hasRemoveIssuanceFormTarget) return
    const issuanceId = event?.currentTarget?.dataset?.issuanceId
    if (!issuanceId) return
    if (this.hasRemoveIssuanceIdInputTarget) this.removeIssuanceIdInputTarget.value = issuanceId
    if (this.hasRemoveIssuanceOperationInputTarget) this.removeIssuanceOperationInputTarget.value = this.uuidV7()
    if (this.hasRemoveIssuanceConfirmClearInputTarget) this.removeIssuanceConfirmClearInputTarget.value = ""
    if (this.tendersApplied()) {
      this.requestClearTendersConfirmation("remove")
      return
    }
    this.beginFlight()
    this.removeIssuanceFormTarget.requestSubmit()
  }

  tendersApplied() {
    return Boolean(this.element.querySelector(".pos-tenders__item"))
  }

  requestClearTendersConfirmation(pendingIssuanceAction) {
    this.pendingIssuanceAction = pendingIssuanceAction
    if (!this.hasClearTendersOverlayTarget) return
    if (this.hasClearTendersConsequenceTarget) {
      const verb = pendingIssuanceAction === "remove"
        ? "Removing"
        : (pendingIssuanceAction === "replace" ? "Replacing" : "Adding")
      this.clearTendersConsequenceTarget.textContent =
        `${verb} this gift card changes the amount due, so every applied tender must be cleared and the transaction tendered again.`
    }
    const confirm = this.clearTendersOverlayTarget.querySelector("[data-action*='confirmClearTenders']")
    this.showOverlay(this.clearTendersOverlayTarget, confirm)
  }

  closeClearTendersOverlay(event) {
    if (event) event.preventDefault()
    this.pendingIssuanceAction = null
    this.hideOverlay(this.hasClearTendersOverlayTarget && this.clearTendersOverlayTarget)
  }

  confirmClearTenders(event) {
    if (event) event.preventDefault()
    if (this.inFlight) return
    const pending = this.pendingIssuanceAction
    this.pendingIssuanceAction = null
    if (pending === "remove" && this.hasRemoveIssuanceFormTarget) {
      if (this.hasRemoveIssuanceConfirmClearInputTarget) this.removeIssuanceConfirmClearInputTarget.value = "true"
      this.beginFlight()
      this.removeIssuanceFormTarget.requestSubmit()
      return
    }
    if (pending === "replace" && this.hasReplaceIssuanceFormTarget) {
      if (this.hasReplaceIssuanceConfirmClearInputTarget) this.replaceIssuanceConfirmClearInputTarget.value = "true"
      this.beginFlight()
      this.replaceIssuanceFormTarget.requestSubmit()
      return
    }
    if (pending === "add" && this.hasIssuanceFormTarget) {
      if (this.hasIssuanceConfirmClearInputTarget) this.issuanceConfirmClearInputTarget.value = "true"
      this.beginFlight()
      this.issuanceFormTarget.requestSubmit()
    }
  }

  onClearTendersOverlayKeydown(event, key) {
    if (key === "Escape") {
      event.preventDefault()
      this.closeClearTendersOverlay()
      return
    }
    if (key === "F9" || key === "F10") {
      event.preventDefault()
      return
    }
    if (key !== "Enter") return
    if (this.isActionableControl(event.target)) return
    event.preventDefault()
    this.confirmClearTenders()
  }

  showOverlayLocalError(overlay, message) {
    if (!overlay) return
    const node = overlay.querySelector("[data-overlay-error]")
    if (!node) {
      this.showFeedback(message)
      return
    }
    node.textContent = message
    node.setAttribute("role", "alert")
  }

  cashTenderIndex() {
    const index = this.cashierTenderTypes().findIndex((type) => type.category === "cash")
    return index >= 0 ? index : 0
  }

  cashierTenderTypes() {
    const types = Array.isArray(this.tenderTypesValue) ? this.tenderTypesValue : []
    if (this.settlementValue === "refund") {
      return types.filter((type) => type.allows_refund)
    }
    return types
  }

  toggleReferenceField(policy) {
    if (!this.hasReferenceWrapTarget) return
    const show = this.modeValue === "tender" && policy !== "omitted"
    this.referenceWrapTarget.hidden = !show
    if (show && this.hasReferenceLabelTarget) {
      this.referenceLabelTarget.textContent = policy === "required" ? "Reference (required)" : "Reference (optional)"
    }
    if (!show && this.hasReferenceFieldTarget) this.referenceFieldTarget.value = ""
  }

  removeLastTender() {
    if (this.inFlight) return
    if (!this.hasRemoveTenderFormTarget || !this.hasRemoveTenderInputTarget) return
    const last = this.tenderRows().at(-1)
    if (last?.dataset?.tenderId) this.removeTenderInputTarget.value = last.dataset.tenderId
    if (!this.removeTenderInputTarget.value) return
    if (this.hasRemoveTenderOperationInputTarget) this.removeTenderOperationInputTarget.value = this.uuidV7()
    this.beginFlight()
    this.removeTenderFormTarget.requestSubmit()
  }

  tenderRows() {
    return Array.from(this.element.querySelectorAll(".pos-tenders__item[data-tender-id]"))
  }

  selectedTenderRow() {
    return this.element.querySelector(".pos-tenders__item.is-selected[data-tender-id]")
  }

  selectTender(event) {
    const row = event?.currentTarget
    if (!row?.dataset?.tenderId) return
    this.tenderRows().forEach((item) => {
      const selected = item === row
      item.classList.toggle("is-selected", selected)
      item.setAttribute("aria-selected", String(selected))
      item.tabIndex = selected ? 0 : -1
    })
    this.syncSelectedTender(row.dataset.tenderId)
    if (this.hasTenderReviewDetailTarget) this.tenderReviewDetailTarget.textContent = row.dataset.inspectDetail || ""
    const editAvailable = row.dataset.editAvailable === "true"
    const removeAvailable = row.dataset.removeAvailable === "true"
    if (this.hasTenderEditActionTarget) this.tenderEditActionTarget.hidden = !editAvailable
    if (this.hasTenderRemoveActionTarget) this.tenderRemoveActionTarget.hidden = !removeAvailable
    if (this.hasTenderUnavailableReasonTarget) {
      const reason = row.dataset.editUnavailableReason || row.dataset.removeUnavailableReason || ""
      this.tenderUnavailableReasonTarget.hidden = !reason
      this.tenderUnavailableReasonTarget.textContent = reason
    }
  }

  tenderListKeyTarget(target) {
    return Boolean(target?.closest?.(".pos-tenders__list, .pos-tenders__item"))
  }

  moveTenderSelection(delta, { focus = false } = {}) {
    const rows = this.tenderRows()
    if (rows.length === 0) return
    const current = this.selectedTenderRow()
    const index = Math.max(0, rows.indexOf(current))
    const next = rows[Math.max(0, Math.min(rows.length - 1, index + delta))]
    this.selectTender({ currentTarget: next })
    if (focus) next.focus()
  }

  syncSelectedTender(id = this.selectedTenderRow()?.dataset?.tenderId) {
    this.selectedTenderInputTargets.forEach((input) => { input.value = id || "" })
    if (this.hasRemoveTenderInputTarget) this.removeTenderInputTarget.value = id || this.removeTenderInputTarget.value
    if (this.hasReplaceTenderInputTarget) this.replaceTenderInputTarget.value = id || ""
  }

  openRemoveTenderOverlay(event) {
    if (event) event.preventDefault()
    const row = this.selectedTenderRow()
    if (!row || row.dataset.removeAvailable !== "true" || !this.hasRemoveTenderOverlayTarget) return
    this.syncSelectedTender(row.dataset.tenderId)
    if (this.hasRemoveTenderDetailTarget) this.removeTenderDetailTarget.textContent = row.dataset.inspectDetail || ""
    const confirm = this.removeTenderOverlayTarget.querySelector("[data-action*='confirmRemoveTender']")
    this.showOverlay(this.removeTenderOverlayTarget, confirm)
  }

  closeRemoveTenderOverlay(event) {
    if (event) event.preventDefault()
    this.hideOverlay(this.hasRemoveTenderOverlayTarget && this.removeTenderOverlayTarget)
  }

  confirmRemoveTender(event) {
    if (event) event.preventDefault()
    if (this.inFlight || !this.hasRemoveTenderFormTarget) return
    if (this.hasRemoveTenderOperationInputTarget) this.removeTenderOperationInputTarget.value = this.uuidV7()
    this.beginFlight()
    this.removeTenderFormTarget.requestSubmit()
  }

  openEditTenderOverlay(event) {
    if (event) event.preventDefault()
    const row = this.selectedTenderRow()
    if (!row || row.dataset.editAvailable !== "true" || !this.hasEditTenderOverlayTarget) return
    this.syncSelectedTender(row.dataset.tenderId)
    if (this.hasEditTenderDetailTarget) this.editTenderDetailTarget.textContent = row.dataset.inspectDetail || ""
    if (this.hasEditTenderAmountTarget) this.editTenderAmountTarget.value = this.formatCents(row.dataset.amountCents)
    const storedValue = row.dataset.storedValue === "true"
    const cashPayment = row.dataset.behavioralCategory === "cash" && row.dataset.direction === "payment"
    if (this.hasEditTenderPresentedWrapTarget) this.editTenderPresentedWrapTarget.hidden = !cashPayment
    if (this.hasEditTenderPresentedTarget) {
      this.editTenderPresentedTarget.value = cashPayment ? this.formatCents(row.dataset.presentedCents || row.dataset.amountCents) : ""
    }
    if (this.hasEditTenderStoredValueNoteTarget) this.editTenderStoredValueNoteTarget.hidden = !storedValue
    const capturesReference = !storedValue && row.dataset.behavioralCategory !== "cash"
    if (this.hasEditTenderReferenceWrapTarget) this.editTenderReferenceWrapTarget.hidden = !capturesReference
    if (this.hasEditTenderReferenceTarget) this.editTenderReferenceTarget.value = row.dataset.externalReference || ""
    this.showOverlay(this.editTenderOverlayTarget, this.editTenderAmountTarget)
  }

  closeEditTenderOverlay(event) {
    if (event) event.preventDefault()
    this.hideOverlay(this.hasEditTenderOverlayTarget && this.editTenderOverlayTarget)
  }

  confirmReplaceTender(event) {
    if (event) event.preventDefault()
    if (this.inFlight || !this.hasReplaceTenderFormTarget) return
    this.replaceTenderAmountInputTarget.value = this.editTenderAmountTarget.value
    this.replaceTenderPresentedInputTarget.value = this.hasEditTenderPresentedWrapTarget && !this.editTenderPresentedWrapTarget.hidden
      ? this.editTenderPresentedTarget.value : ""
    this.replaceTenderReferenceInputTarget.value = this.hasEditTenderReferenceWrapTarget && !this.editTenderReferenceWrapTarget.hidden
      ? this.editTenderReferenceTarget.value.trim() : ""
    this.replaceTenderOperationInputTarget.value = this.uuidV7()
    this.beginFlight()
    this.replaceTenderFormTarget.requestSubmit()
  }

  openReturnToSaleOverlay(event) {
    if (event) event.preventDefault()
    if (this.inFlight || !this.hasReturnToSaleOverlayTarget) return
    const confirm = this.returnToSaleOverlayTarget.querySelector("[data-action*='confirmReturnToSale']:not([disabled])")
    this.showOverlay(this.returnToSaleOverlayTarget, confirm || this.returnToSaleOverlayTarget.querySelector("button"))
  }

  closeReturnToSaleOverlay(event) {
    if (event) event.preventDefault()
    this.hideOverlay(this.hasReturnToSaleOverlayTarget && this.returnToSaleOverlayTarget)
  }

  confirmReturnToSale(event) {
    if (event) event.preventDefault()
    if (this.inFlight || !this.hasReturnToSaleFormTarget) return
    this.returnToSaleOperationInputTarget.value = this.uuidV7()
    this.beginFlight()
    this.returnToSaleFormTarget.requestSubmit()
  }

  onEditTenderOverlayKeydown(event, key) {
    if (key === "Escape") {
      event.preventDefault()
      this.closeEditTenderOverlay()
      return
    }
    if (key === "F9" || key === "F10") {
      event.preventDefault()
      return
    }
    if (key !== "Enter") return
    if (this.isActionableControl(event.target)) return
    event.preventDefault()
    if (this.advanceEditTenderField(event.target)) return
    this.confirmReplaceTender()
  }

  advanceEditTenderField(target) {
    if (!this.hasEditTenderAmountTarget || target !== this.editTenderAmountTarget) return false
    if (this.hasEditTenderPresentedWrapTarget && !this.editTenderPresentedWrapTarget.hidden && this.hasEditTenderPresentedTarget) {
      this.editTenderPresentedTarget.focus()
      return true
    }
    if (this.hasEditTenderReferenceWrapTarget && !this.editTenderReferenceWrapTarget.hidden && this.hasEditTenderReferenceTarget) {
      this.editTenderReferenceTarget.focus()
      return true
    }
    return false
  }

  onRemoveTenderOverlayKeydown(event, key) {
    if (key === "Escape") {
      event.preventDefault()
      this.closeRemoveTenderOverlay()
      return
    }
    if (key === "F9" || key === "F10") {
      event.preventDefault()
      return
    }
    if (key !== "Enter") return
    if (this.isActionableControl(event.target)) return
    event.preventDefault()
    this.confirmRemoveTender()
  }

  onReturnToSaleOverlayKeydown(event, key) {
    if (key === "Escape") {
      event.preventDefault()
      this.closeReturnToSaleOverlay()
      return
    }
    if (key === "F9" || key === "F10") {
      event.preventDefault()
      return
    }
    if (key !== "Enter") return
    if (this.isActionableControl(event.target)) return
    event.preventDefault()
    this.confirmReturnToSale()
  }

  uuidV7() {
    const bytes = crypto.getRandomValues(new Uint8Array(16))
    let timestamp = Date.now()
    for (let index = 5; index >= 0; index -= 1) {
      bytes[index] = timestamp & 0xff
      timestamp = Math.floor(timestamp / 256)
    }
    bytes[6] = (bytes[6] & 0x0f) | 0x70
    bytes[8] = (bytes[8] & 0x3f) | 0x80
    const hex = Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("")
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
  }

  escape() {
    if (this.inFlight) return
    if (this.modeValue === "quantity") {
      this.setMode("sale_entry", "SALE ENTRY")
      this.setFieldLabel("Scan or identifier")
      this.fieldTarget.inputMode = "text"
      this.fieldTarget.value = ""
      this.toggleReferenceField("omitted")
      this.enableReadyActions()
      this.fieldTarget.focus()
      return
    }
    if (this.modeValue === "tender") {
      if (this.tenderRows().length > 0) {
        this.openReturnToSaleOverlay()
        return
      }
      this.setMode("sale_entry", "SALE ENTRY")
      this.setFieldLabel("Scan or identifier")
      this.fieldTarget.inputMode = "text"
      this.fieldTarget.value = ""
      this.toggleReferenceField("omitted")
      this.enableReadyActions()
      this.fieldTarget.focus()
    }
  }

  openOverlay() {
    if (this.inFlight || this.controlOverlayOpen()) return
    const cancel = this.hasCancelButtonTarget ? this.cancelButtonTarget : this.element.querySelector(".pos-actions .btn--danger")
    if (!cancel || cancel.disabled) return
    this.showOverlay(this.overlayTarget, this.dontCancelTarget)
  }

  closeOverlay() {
    this.hideOverlay(this.hasOverlayTarget && this.overlayTarget)
  }

  openPriceOverride() {
    const row = this.selectedRow()
    if (!row) {
      this.showFeedback("Select a sale line first.")
      return
    }
    if (this.selectedReturnLine()) {
      this.showFeedback("Price is not available on a return line.")
      return
    }
    if (row.dataset.pricingMethodSnapshot === "open_price") {
      if (row.dataset.discounted === "true") {
        this.showFeedback("Remove the line discount before changing the price.")
        return
      }
      this.openOpenPriceOverlay({
        kind: "edit",
        lineId: row.dataset.lineId,
        prompt: row.dataset.description || "Selected line",
        currentCents: row.dataset.sellingCents
      })
      return
    }
    this.openControlOverlay("price_override")
  }

  openLineDiscount() {
    this.openControlOverlay("line_discount")
  }

  openTaxClassOverride() {
    this.openControlOverlay("tax_class_override")
  }

  controlChromeFor(actionType) {
    if (actionType === "price_override") {
      return {
        title: "Change Selling Price",
        keepLabel: "Keep Current Price",
        removeLabel: "Remove Price Override",
        currentPrefix: "Current price",
        backLabel: "Back to Price Change",
        authorizeLabel: "Authorize and Apply",
        actionLabel: "Price change"
      }
    }
    if (actionType === "line_discount") {
      return {
        title: "Apply Line Discount",
        keepLabel: "Keep Current Discount",
        removeLabel: "Remove Line Discount",
        currentPrefix: "Current discount",
        backLabel: "Back to Discount",
        authorizeLabel: "Authorize and Apply",
        actionLabel: "Line discount"
      }
    }
    return {
      title: "Change Tax Class",
      keepLabel: "Keep Current Tax Class",
      removeLabel: "Restore Original Tax Class",
      currentPrefix: "Current tax class",
      backLabel: "Back to Tax Class",
      authorizeLabel: "Authorize and Apply",
      actionLabel: "Tax class change"
    }
  }

  openControlOverlay(actionType) {
    if (this.inFlight) return
    if (this.modeValue !== "sale_entry") return
    const chrome = this.controlChromeFor(actionType)
    if (this.policyFor(actionType) === "prohibited") {
      this.showFeedback(`${chrome.title} is not available.`)
      return
    }
    if (this.selectedReturnLine()) {
      this.showFeedback(`${chrome.title} is not available on a return line.`)
      return
    }
    const row = this.selectedRow()
    if (!row || !this.hasControlOverlayTarget) {
      this.showFeedback("Select a sale line first.")
      return
    }

    this.currentControlAction = actionType
    if (this.hasControlTitleTarget) this.controlTitleTarget.textContent = chrome.title
    if (this.hasControlCancelTarget) this.controlCancelTarget.textContent = chrome.keepLabel
    if (this.hasControlRemoveTarget) this.controlRemoveTarget.textContent = chrome.removeLabel
    if (this.hasControlLineLabelTarget) this.controlLineLabelTarget.textContent = row.dataset.description || "Selected line"
    if (this.hasControlCurrentLabelTarget) {
      this.controlCurrentLabelTarget.textContent = this.controlCurrentSummary(row, actionType, chrome)
    }
    this.toggleHidden(this.hasControlPriceWrapTarget && this.controlPriceWrapTarget, actionType !== "price_override")
    this.toggleHidden(this.hasControlDiscountWrapTarget && this.controlDiscountWrapTarget, actionType !== "line_discount")
    this.toggleHidden(this.hasControlTaxWrapTarget && this.controlTaxWrapTarget, actionType !== "tax_class_override")
    if (this.hasControlPriceFieldTarget) this.controlPriceFieldTarget.value = ""
    if (this.hasControlDiscountFieldTarget) this.controlDiscountFieldTarget.value = ""
    if (actionType === "price_override" && this.hasControlPriceFieldTarget) {
      this.controlPriceFieldTarget.value = this.formatCents(row.dataset.sellingCents)
    }
    if (actionType === "line_discount" && this.hasControlDiscountFieldTarget) {
      this.controlDiscountFieldTarget.value = row.dataset.discountBp ? this.formatBasisPoints(row.dataset.discountBp) : ""
    }
    if (actionType === "tax_class_override" && this.hasControlTaxFieldTarget && row.dataset.taxClassId) {
      this.controlTaxFieldTarget.value = row.dataset.taxClassId
    }
    this.populateReasons(actionType)
    this.toggleHidden(this.hasControlNoteWrapTarget && this.controlNoteWrapTarget, true)
    if (this.hasControlNoteFieldTarget) this.controlNoteFieldTarget.value = ""
    const hasExisting = this.lineHasAction(row, actionType)
    if (this.hasControlRemoveTarget) this.controlRemoveTarget.hidden = !hasExisting

    this.showOverlay(this.controlOverlayTarget)
  }

  controlCurrentSummary(row, actionType, chrome) {
    if (actionType === "price_override") {
      return `${chrome.currentPrefix} $${this.formatCents(row.dataset.sellingCents)}`
    }
    if (actionType === "line_discount") {
      const bp = row.dataset.discountBp
      return bp ? `${chrome.currentPrefix} ${this.formatBasisPoints(bp)}%` : `${chrome.currentPrefix} none`
    }
    const name = this.taxClassOptionLabel(row.dataset.taxClassId) || row.dataset.taxClassName || "—"
    return `${chrome.currentPrefix} ${name}`
  }

  taxClassOptionLabel(id) {
    if (!this.hasControlTaxFieldTarget || !id) return null
    const option = Array.from(this.controlTaxFieldTarget.options).find((entry) => entry.value === String(id))
    return option ? option.textContent : null
  }

  formatBasisPoints(bp) {
    const value = Number(bp || 0)
    return (value / 100).toFixed(value % 100 === 0 ? 0 : 2)
  }

  closeControlOverlay() {
    if (this.approvalOverlayOpen()) this.closeApprovalOverlay({ clearInvocation: true })
    this.hideOverlay(this.hasControlOverlayTarget && this.controlOverlayTarget)
  }

  openUnlinkedOverlay() {
    if (this.inFlight) return
    if (this.modeValue !== "sale_entry") return
    if (this.policyFor("unlinked_return") === "prohibited") return
    if (!this.hasUnlinkedOverlayTarget) return

    this.invalidateUnlinkedLookup()
    this.resetUnlinkedOverlay()
    this.populateUnlinkedReasons()
    this.syncUnlinkedPrimaryEnabled()
    this.showOverlay(this.unlinkedOverlayTarget, this.hasUnlinkedIdentifierFieldTarget && this.unlinkedIdentifierFieldTarget)
  }

  closeUnlinkedOverlay() {
    if (this.approvalOverlayOpen()) this.closeApprovalOverlay({ clearInvocation: true })
    this.invalidateUnlinkedLookup()
    this.unlinkedPickerActive = false
    this.hideOverlay(this.hasUnlinkedOverlayTarget && this.unlinkedOverlayTarget)
  }

  backFromUnlinkedOverlay(event) {
    if (event) event.preventDefault()
    if (this.inFlight) return
    this.closeUnlinkedOverlay()
  }

  invalidateUnlinkedLookup() {
    if (this.unlinkedAbort) this.unlinkedAbort.abort()
    this.unlinkedAbort = null
    this.unlinkedInvocation += 1
  }

  invalidateUnlinkedResultsOnInput() {
    this.syncUnlinkedPrimaryEnabled()
    if (!this.unlinkedPreviewPayload && !(this.hasUnlinkedQueryLabelTarget && this.unlinkedQueryLabelTarget.textContent)) return
    this.invalidateUnlinkedLookup()
    this.clearUnlinkedPreviewState()
    this.unlinkedSelection = null
    this.unlinkedPickerActive = false
    if (this.hasUnlinkedFeedbackTarget) this.unlinkedFeedbackTarget.textContent = ""
    if (this.hasUnlinkedQueryLabelTarget) this.unlinkedQueryLabelTarget.textContent = ""
    this.syncUnlinkedPrimaryEnabled()
  }

  resetUnlinkedOverlay() {
    this.unlinkedPreviewPayload = null
    this.unlinkedSelection = null
    this.unlinkedPickerActive = false
    if (this.hasUnlinkedFeedbackTarget) this.unlinkedFeedbackTarget.textContent = ""
    if (this.hasUnlinkedQueryLabelTarget) this.unlinkedQueryLabelTarget.textContent = ""
    if (this.hasUnlinkedIdentifierFieldTarget) this.unlinkedIdentifierFieldTarget.value = ""
    this.toggleHidden(this.hasUnlinkedPreviewTarget && this.unlinkedPreviewTarget, true)
    if (this.hasUnlinkedNoteFieldTarget) this.unlinkedNoteFieldTarget.value = ""
    this.toggleHidden(this.hasUnlinkedNoteWrapTarget && this.unlinkedNoteWrapTarget, true)
    this.syncUnlinkedPrimaryEnabled()
  }

  populateUnlinkedReasons() {
    if (!this.hasUnlinkedReasonFieldTarget) return
    const entries = this.returnReasonsValue || []
    this.unlinkedReasonFieldTarget.innerHTML = ""
    const blank = document.createElement("option")
    blank.value = ""
    blank.textContent = "Select…"
    this.unlinkedReasonFieldTarget.append(blank)
    entries.forEach((entry) => {
      const option = document.createElement("option")
      option.value = entry.code
      option.textContent = entry.name
      this.unlinkedReasonFieldTarget.appendChild(option)
    })
  }

  onUnlinkedReasonChange() {
    const reason = this.hasUnlinkedReasonFieldTarget ? this.unlinkedReasonFieldTarget.value : ""
    this.toggleHidden(this.hasUnlinkedNoteWrapTarget && this.unlinkedNoteWrapTarget, reason !== "other")
    this.syncUnlinkedPrimaryEnabled()
  }

  lookUpUnlinkedItem(event) {
    if (event) event.preventDefault()
    this.resolveUnlinkedIdentifier()
  }

  async resolveUnlinkedIdentifier() {
    if (this.inFlight || !this.hasUnlinkedIdentifierFieldTarget) return
    const identifier = this.unlinkedIdentifierFieldTarget.value.trim()
    if (identifier === "") return
    this.unlinkedSelection = { identifier }
    await this.fetchUnlinkedResolution({ identifier })
  }

  async fetchUnlinkedResolution(params = {}) {
    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
    const body = new URLSearchParams()
    const identifier = params.identifier || this.unlinkedSelection?.identifier ||
      (this.hasUnlinkedIdentifierFieldTarget ? this.unlinkedIdentifierFieldTarget.value.trim() : "")
    if (identifier) body.set("identifier", identifier)
    if (params.product_id) body.set("product_id", params.product_id)
    if (params.product_variant_id) body.set("product_variant_id", params.product_variant_id)
    if (params.inventory_unit_id) body.set("inventory_unit_id", params.inventory_unit_id)
    if (this.unlinkedAbort) this.unlinkedAbort.abort()
    this.unlinkedAbort = new AbortController()
    const invocation = ++this.unlinkedInvocation
    if (this.hasUnlinkedQueryLabelTarget) this.unlinkedQueryLabelTarget.textContent = "Looking up…"
    try {
      const response = await fetch(this.unlinkedLookupUrlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
          "X-CSRF-Token": token || ""
        },
        body: body.toString(),
        signal: this.unlinkedAbort.signal
      })
      const payload = await response.json()
      if (!this.unlinkedResponseCurrent(invocation)) return
      this.handleUnlinkedResolution(payload, response.ok)
    } catch (error) {
      if (error?.name === "AbortError") return
      if (!this.unlinkedResponseCurrent(invocation)) return
      this.showUnlinkedFeedback("merchandise not found")
      this.clearUnlinkedPreviewState()
      this.unlinkedSelection = null
    }
  }

  unlinkedResponseCurrent(invocation) {
    if (!this.element.isConnected) return false
    if (invocation !== this.unlinkedInvocation) return false
    if (!this.unlinkedOverlayOpen()) return false
    // Must remain in stack ancestry (chooser may be parent).
    return this.overlayStack.some((entry) => entry.overlay === this.unlinkedOverlayTarget && !entry.overlay.hidden)
  }

  handleUnlinkedResolution(payload, ok) {
    if (this.hasUnlinkedQueryLabelTarget) this.unlinkedQueryLabelTarget.textContent = ""
    const outcome = payload.outcome || (ok ? "resolved" : "unavailable")
    switch (outcome) {
      case "resolved":
        this.applyUnlinkedPreview(payload)
        return
      case "product_choice_required":
        this.unlinkedPickerActive = true
        this.openProductPicker(payload.products || [])
        return
      case "variant_choice_required":
        this.unlinkedPickerActive = true
        this.openVariantPicker(payload.variants || [])
        return
      case "unit_choice_required":
        this.unlinkedPickerActive = true
        this.openUnitPicker(payload.units || [])
        return
      default:
        this.showUnlinkedFeedback(payload.error || payload.message || "merchandise not found")
        this.clearUnlinkedPreviewState()
        this.unlinkedSelection = null
        this.unlinkedPickerActive = false
    }
  }

  clearUnlinkedPreviewState() {
    this.unlinkedPreviewPayload = null
    this.toggleHidden(this.hasUnlinkedPreviewTarget && this.unlinkedPreviewTarget, true)
    this.syncUnlinkedPrimaryEnabled()
  }

  applyUnlinkedPreview(payload) {
    this.unlinkedPreviewPayload = payload
    this.unlinkedPickerActive = false
    if (this.hasUnlinkedFeedbackTarget) this.unlinkedFeedbackTarget.textContent = ""
    this.toggleHidden(this.hasUnlinkedPreviewTarget && this.unlinkedPreviewTarget, false)
    if (this.hasUnlinkedDescriptionTarget) this.unlinkedDescriptionTarget.textContent = payload.description || ""
    if (this.hasUnlinkedReferenceLabelTarget) {
      this.unlinkedReferenceLabelTarget.textContent = this.formatCents(payload.reference_unit_price_cents)
    }
    if (this.hasUnlinkedPriceFieldTarget) {
      this.unlinkedPriceFieldTarget.value = this.formatCents(payload.reference_unit_price_cents)
    }
    const fixed = Boolean(payload.quantity_fixed)
    this.toggleHidden(this.hasUnlinkedQuantityWrapTarget && this.unlinkedQuantityWrapTarget, fixed)
    if (this.hasUnlinkedQuantityFieldTarget) {
      this.unlinkedQuantityFieldTarget.value = "1"
      this.unlinkedQuantityFieldTarget.disabled = fixed
    }
    this.syncUnlinkedPrimaryEnabled()

    const focusTarget = (this.hasUnlinkedQuantityFieldTarget && !fixed)
      ? this.unlinkedQuantityFieldTarget
      : (this.hasUnlinkedReasonFieldTarget && this.unlinkedReasonFieldTarget)
    // Restore unlinked as top if nested pickers closed.
    if (this.topOverlay() !== this.unlinkedOverlayTarget) {
      this.showOverlay(this.unlinkedOverlayTarget, focusTarget)
    } else {
      this.focusOverlayEntry(focusTarget)
    }
  }

  unlinkedAddReady() {
    if (!this.unlinkedPreviewPayload || this.inFlight) return false
    const reason = this.hasUnlinkedReasonFieldTarget ? this.unlinkedReasonFieldTarget.value : ""
    if (!reason) return false
    if (reason === "other" && this.hasUnlinkedNoteFieldTarget && this.unlinkedNoteFieldTarget.value.trim() === "") return false
    const price = this.hasUnlinkedPriceFieldTarget ? this.unlinkedPriceFieldTarget.value.trim() : ""
    if (price === "") return false
    if (!this.unlinkedPreviewPayload.quantity_fixed) {
      const qty = this.hasUnlinkedQuantityFieldTarget ? this.unlinkedQuantityFieldTarget.value.trim() : ""
      if (!qty || Number(qty) <= 0) return false
    }
    return true
  }

  syncUnlinkedPrimaryEnabled() {
    if (this.hasUnlinkedCancelTarget) this.unlinkedCancelTarget.disabled = this.inFlight
    if (this.hasUnlinkedLookupTarget) {
      const query = this.hasUnlinkedIdentifierFieldTarget ? this.unlinkedIdentifierFieldTarget.value.trim() : ""
      this.unlinkedLookupTarget.disabled = this.inFlight || !query
    }
    if (!this.hasUnlinkedApplyTarget) return
    this.unlinkedApplyTarget.disabled = !this.unlinkedAddReady()
  }

  // Abandon a stacked merchandise picker opened from unlinked return.
  abortUnlinkedPicker() {
    if (!this.unlinkedPickerActive) return
    this.unlinkedPickerActive = false
    if (this.unlinkedOverlayOpen() && this.hasUnlinkedIdentifierFieldTarget) {
      this.unlinkedIdentifierFieldTarget.focus()
    }
  }

  showUnlinkedFeedback(message) {
    if (this.hasUnlinkedFeedbackTarget) this.unlinkedFeedbackTarget.textContent = message
  }

  submitUnlinkedReturn(event) {
    if (event) event.preventDefault()
    if (this.inFlight || !this.hasUnlinkedFormTarget) return
    if (!this.unlinkedAddReady()) return
    if (this.policyFor("unlinked_return") === "approval_required") {
      this.openUnlinkedAuthorization()
      return
    }
    this.commitUnlinkedReturn()
  }

  openUnlinkedAuthorization() {
    const reasonCode = this.hasUnlinkedReasonFieldTarget ? this.unlinkedReasonFieldTarget.value : ""
    const reasonName = this.reasonDisplayName(this.returnReasonsValue, reasonCode)
    const qty = this.unlinkedPreviewPayload.quantity_fixed
      ? "1"
      : (this.hasUnlinkedQuantityFieldTarget ? this.unlinkedQuantityFieldTarget.value.trim() : "1")
    const price = this.hasUnlinkedPriceFieldTarget ? this.unlinkedPriceFieldTarget.value.trim() : ""
    this.openAuthorizationOverlay({
      consumer: "unlinked_return",
      operation: "apply",
      parentOverlay: this.unlinkedOverlayTarget,
      formTarget: "unlinkedForm",
      context: {
        actionLabel: "Unlinked return",
        itemLabel: this.hasUnlinkedDescriptionTarget ? this.unlinkedDescriptionTarget.textContent : "",
        currentLabel: "",
        proposedLabel: `$${price}`,
        qtyLabel: qty,
        reasonLabel: reasonName,
        backLabel: "Back to Unlinked Return",
        authorizeLabel: "Authorize and Add Return",
        showQty: true,
        showCurrent: false,
        proposedHeading: "Return amount"
      }
    })
  }

  commitUnlinkedReturn({ credentials = null } = {}) {
    if (this.inFlight || !this.hasUnlinkedFormTarget) return
    this.fillUnlinkedForm(credentials)
    this.clearOverlayError(this.unlinkedOverlayTarget)
    if (this.approvalOverlayOpen()) this.clearOverlayError(this.approvalOverlayTarget)
    this.beginFlight()
    this.syncUnlinkedPrimaryEnabled()
    this.unlinkedFormTarget.requestSubmit()
    this.clearHiddenApproverPasswords()
  }

  fillUnlinkedForm(credentials = null) {
    if (this.hasUnlinkedIdentifierInputTarget) {
      this.unlinkedIdentifierInputTarget.value = this.hasUnlinkedIdentifierFieldTarget
        ? this.unlinkedIdentifierFieldTarget.value.trim()
        : ""
    }
    if (this.hasUnlinkedProductIdInputTarget) {
      this.unlinkedProductIdInputTarget.value = this.unlinkedPreviewPayload.product_id || ""
    }
    if (this.hasUnlinkedVariantIdInputTarget) {
      this.unlinkedVariantIdInputTarget.value = this.unlinkedPreviewPayload.product_variant_id || ""
    }
    if (this.hasUnlinkedUnitIdInputTarget) {
      this.unlinkedUnitIdInputTarget.value = this.unlinkedPreviewPayload.inventory_unit_id || ""
    }
    if (this.hasUnlinkedQuantityInputTarget) {
      this.unlinkedQuantityInputTarget.value = this.unlinkedPreviewPayload.quantity_fixed
        ? "1"
        : (this.hasUnlinkedQuantityFieldTarget ? this.unlinkedQuantityFieldTarget.value.trim() : "1")
    }
    if (this.hasUnlinkedReasonInputTarget) {
      this.unlinkedReasonInputTarget.value = this.hasUnlinkedReasonFieldTarget ? this.unlinkedReasonFieldTarget.value : ""
    }
    if (this.hasUnlinkedNoteInputTarget) {
      this.unlinkedNoteInputTarget.value = this.hasUnlinkedNoteFieldTarget ? this.unlinkedNoteFieldTarget.value.trim() : ""
    }
    if (this.hasUnlinkedPriceInputTarget) {
      this.unlinkedPriceInputTarget.value = this.hasUnlinkedPriceFieldTarget ? this.unlinkedPriceFieldTarget.value.trim() : ""
    }
    if (this.hasUnlinkedExpectedVariantInputTarget) {
      this.unlinkedExpectedVariantInputTarget.value = this.unlinkedPreviewPayload.product_variant_id || ""
    }
    if (this.hasUnlinkedExpectedUnitInputTarget) {
      this.unlinkedExpectedUnitInputTarget.value = this.unlinkedPreviewPayload.inventory_unit_id || ""
    }
    if (this.hasUnlinkedExpectedReferenceInputTarget) {
      this.unlinkedExpectedReferenceInputTarget.value = this.unlinkedPreviewPayload.reference_unit_price_cents ?? ""
    }
    if (this.hasUnlinkedExpectedTaxInputTarget) {
      this.unlinkedExpectedTaxInputTarget.value = this.unlinkedPreviewPayload.tax_class_id || ""
    }
    const username = credentials?.username || ""
    const password = credentials?.password || ""
    if (this.hasUnlinkedApproverUserInputTarget) this.unlinkedApproverUserInputTarget.value = username
    if (this.hasUnlinkedApproverPasswordInputTarget) this.unlinkedApproverPasswordInputTarget.value = password
  }

  submitControlApply(event) {
    if (event) event.preventDefault()
    if (this.inFlight || !this.hasControlFormTarget) return
    if (!this.ensureControlReady("apply")) return
    if (this.policyFor(this.currentControlAction) === "approval_required") {
      this.openControlAuthorization("apply")
      return
    }
    this.commitControlOperation("apply")
  }

  submitControlRemove(event) {
    if (event) event.preventDefault()
    if (this.inFlight || !this.hasControlFormTarget) return
    if (!this.ensureControlReady("remove")) return
    if (this.policyFor(this.currentControlAction) === "approval_required") {
      this.openControlAuthorization("remove")
      return
    }
    this.commitControlOperation("remove")
  }

  ensureControlReady(operation) {
    const action = this.currentControlAction
    const row = this.selectedRow()
    if (operation === "remove") {
      if (!row || !this.lineHasAction(row, action)) {
        this.showControlFeedback("There is no adjustment to remove.")
        if (this.hasControlCancelTarget) this.controlCancelTarget.focus()
        return false
      }
      return true
    }

    if (action === "price_override") {
      const value = this.hasControlPriceFieldTarget ? this.controlPriceFieldTarget.value.trim() : ""
      if (!value) {
        this.showControlFeedback("Enter a selling price.")
        if (this.hasControlPriceFieldTarget) this.controlPriceFieldTarget.focus()
        return false
      }
    } else if (action === "line_discount") {
      const value = this.hasControlDiscountFieldTarget ? this.controlDiscountFieldTarget.value.trim() : ""
      if (!value) {
        this.showControlFeedback("Enter a discount percent.")
        if (this.hasControlDiscountFieldTarget) this.controlDiscountFieldTarget.focus()
        return false
      }
    } else if (action === "tax_class_override") {
      const value = this.hasControlTaxFieldTarget ? this.controlTaxFieldTarget.value : ""
      if (!value) {
        this.showControlFeedback("Choose a Tax Class.")
        if (this.hasControlTaxFieldTarget) this.controlTaxFieldTarget.focus()
        return false
      }
    }

    const reason = this.hasControlReasonFieldTarget ? this.controlReasonFieldTarget.value : ""
    if (!reason) {
      this.showControlFeedback("Choose a reason.")
      if (this.hasControlReasonFieldTarget) this.controlReasonFieldTarget.focus()
      return false
    }
    if (reason === "other") {
      const note = this.hasControlNoteFieldTarget ? this.controlNoteFieldTarget.value.trim() : ""
      if (!note) {
        this.showControlFeedback("Enter a note for Other.")
        this.toggleHidden(this.hasControlNoteWrapTarget && this.controlNoteWrapTarget, false)
        if (this.hasControlNoteFieldTarget) this.controlNoteFieldTarget.focus()
        return false
      }
    }
    return true
  }

  showControlFeedback(message) {
    const node = this.controlOverlayTarget?.querySelector("[data-overlay-error]")
    if (node) node.textContent = message
  }

  openControlAuthorization(operation) {
    const action = this.currentControlAction
    const chrome = this.controlChromeFor(action)
    const row = this.selectedRow()
    const reasonCode = this.hasControlReasonFieldTarget ? this.controlReasonFieldTarget.value : ""
    const reasonName = operation === "remove"
      ? "Remove existing adjustment"
      : this.reasonDisplayName(this.reasonsValue?.[action], reasonCode)
    const proposed = operation === "remove"
      ? "Restore original"
      : this.controlProposedLabel(action)
    this.openAuthorizationOverlay({
      consumer: action,
      operation,
      parentOverlay: this.controlOverlayTarget,
      formTarget: "controlForm",
      context: {
        actionLabel: operation === "remove" ? `${chrome.actionLabel} removal` : chrome.actionLabel,
        itemLabel: this.hasControlLineLabelTarget ? this.controlLineLabelTarget.textContent : "",
        currentLabel: this.controlCurrentValueLabel(row, action),
        proposedLabel: proposed,
        reasonLabel: reasonName,
        backLabel: chrome.backLabel,
        authorizeLabel: chrome.authorizeLabel,
        showQty: false,
        showCurrent: true,
        proposedHeading: "Proposed"
      }
    })
  }

  controlCurrentValueLabel(row, actionType) {
    if (!row) return ""
    if (actionType === "price_override") return `$${this.formatCents(row.dataset.sellingCents)}`
    if (actionType === "line_discount") {
      const bp = row.dataset.discountBp
      return bp ? `${this.formatBasisPoints(bp)}%` : "none"
    }
    return this.taxClassOptionLabel(row.dataset.taxClassId) || row.dataset.taxClassName || "—"
  }

  controlProposedLabel(actionType) {
    if (actionType === "price_override") {
      const value = this.hasControlPriceFieldTarget ? this.controlPriceFieldTarget.value.trim() : ""
      return value ? `$${value}` : ""
    }
    if (actionType === "line_discount") {
      const value = this.hasControlDiscountFieldTarget ? this.controlDiscountFieldTarget.value.trim() : ""
      return value ? `${value}%` : ""
    }
    if (!this.hasControlTaxFieldTarget) return ""
    const option = this.controlTaxFieldTarget.selectedOptions?.[0]
    return option ? option.textContent : ""
  }

  reasonDisplayName(entries, code) {
    if (!code) return ""
    if (Array.isArray(entries)) {
      const match = entries.find((entry) => entry.code === code)
      return match?.name || code
    }
    if (entries && typeof entries === "object") {
      return entries[code] || code
    }
    return code
  }

  commitControlOperation(operation, { credentials = null } = {}) {
    if (this.inFlight || !this.hasControlFormTarget) return
    this.fillControlForm(operation, credentials)
    this.clearOverlayError(this.controlOverlayTarget)
    if (this.approvalOverlayOpen()) this.clearOverlayError(this.approvalOverlayTarget)
    this.beginFlight()
    this.controlFormTarget.requestSubmit()
    this.clearHiddenApproverPasswords()
  }

  fillControlForm(operation, credentials = null) {
    this.syncSelectedLine()
    const action = this.currentControlAction
    const applying = operation === "apply"
    if (this.hasControlActionInputTarget) this.controlActionInputTarget.value = action || ""
    if (this.hasControlOperationInputTarget) this.controlOperationInputTarget.value = operation
    if (this.hasControlReasonInputTarget) {
      this.controlReasonInputTarget.value = applying && this.hasControlReasonFieldTarget
        ? this.controlReasonFieldTarget.value
        : ""
    }
    if (this.hasControlNoteInputTarget) {
      this.controlNoteInputTarget.value = applying && this.hasControlNoteFieldTarget
        ? this.controlNoteFieldTarget.value.trim()
        : ""
    }
    if (this.hasControlPriceInputTarget) {
      this.controlPriceInputTarget.value = applying && action === "price_override" && this.hasControlPriceFieldTarget
        ? this.controlPriceFieldTarget.value.trim()
        : ""
    }
    if (this.hasControlDiscountInputTarget) {
      this.controlDiscountInputTarget.value = applying && action === "line_discount" && this.hasControlDiscountFieldTarget
        ? this.controlDiscountFieldTarget.value.trim()
        : ""
    }
    if (this.hasControlTaxInputTarget) {
      this.controlTaxInputTarget.value = applying && action === "tax_class_override" && this.hasControlTaxFieldTarget
        ? this.controlTaxFieldTarget.value
        : ""
    }
    const username = credentials?.username || ""
    const password = credentials?.password || ""
    if (this.hasControlApproverUserInputTarget) this.controlApproverUserInputTarget.value = username
    if (this.hasControlApproverPasswordInputTarget) this.controlApproverPasswordInputTarget.value = password
  }

  openAuthorizationOverlay(invocation) {
    if (!this.hasApprovalOverlayTarget) return
    // Whitelisted fields only — never store credentials or callbacks.
    this.confirmationInvocation = {
      consumer: invocation.consumer,
      operation: invocation.operation,
      parentOverlay: invocation.parentOverlay,
      formTarget: invocation.formTarget,
      context: { ...(invocation.context || {}) }
    }
    const ctx = this.confirmationInvocation.context
    if (this.hasApprovalActionLabelTarget) this.approvalActionLabelTarget.textContent = ctx.actionLabel || ""
    if (this.hasApprovalItemLabelTarget) this.approvalItemLabelTarget.textContent = ctx.itemLabel || ""
    if (this.hasApprovalCurrentLabelTarget) this.approvalCurrentLabelTarget.textContent = ctx.currentLabel || ""
    if (this.hasApprovalProposedLabelTarget) this.approvalProposedLabelTarget.textContent = ctx.proposedLabel || ""
    if (this.hasApprovalReasonLabelTarget) this.approvalReasonLabelTarget.textContent = ctx.reasonLabel || ""
    if (this.hasApprovalQtyLabelTarget) this.approvalQtyLabelTarget.textContent = ctx.qtyLabel || ""
    if (this.hasApprovalCurrentHeadingTarget) this.approvalCurrentHeadingTarget.textContent = "Current"
    if (this.hasApprovalProposedHeadingTarget) {
      this.approvalProposedHeadingTarget.textContent = ctx.proposedHeading || "Proposed"
    }
    this.toggleHidden(this.hasApprovalCurrentWrapTarget && this.approvalCurrentWrapTarget, ctx.showCurrent === false)
    this.toggleHidden(this.hasApprovalQtyWrapTarget && this.approvalQtyWrapTarget, !ctx.showQty)
    if (this.hasApprovalBackTarget) this.approvalBackTarget.textContent = ctx.backLabel || "Back"
    if (this.hasApprovalAuthorizeTarget) this.approvalAuthorizeTarget.textContent = ctx.authorizeLabel || "Authorize"
    this.clearApprovalCredentials({ keepUsername: false })
    this.clearOverlayError(this.approvalOverlayTarget)
    this.showOverlay(this.approvalOverlayTarget, this.hasApproverUsernameTarget && this.approverUsernameTarget)
  }

  backFromApprovalOverlay(event) {
    if (event) event.preventDefault()
    if (this.inFlight) return
    this.closeApprovalOverlay({ clearInvocation: true })
  }

  closeApprovalOverlay({ clearInvocation = true } = {}) {
    this.clearApprovalCredentials({ keepUsername: false })
    if (clearInvocation) this.confirmationInvocation = null
    this.hideOverlay(this.hasApprovalOverlayTarget && this.approvalOverlayTarget)
  }

  authorizeAndSubmit(event) {
    if (event) event.preventDefault()
    if (this.inFlight) return
    const invocation = this.confirmationInvocation
    if (!invocation) return
    const username = this.hasApproverUsernameTarget ? this.approverUsernameTarget.value.trim() : ""
    const password = this.hasApproverPasswordTarget ? this.approverPasswordTarget.value : ""
    if (!username || !password) {
      if (this.hasApproverUsernameTarget && !username) {
        this.approverUsernameTarget.focus()
        return
      }
      if (this.hasApproverPasswordTarget) this.approverPasswordTarget.focus()
      return
    }
    const credentials = { username, password }
    if (this.hasApproverPasswordTarget) this.approverPasswordTarget.value = ""
    if (invocation.formTarget === "controlForm") {
      this.commitControlOperation(invocation.operation, { credentials })
      return
    }
    if (invocation.formTarget === "unlinkedForm") {
      this.commitUnlinkedReturn({ credentials })
    }
  }

  clearApprovalCredentials({ keepUsername = false } = {}) {
    if (!keepUsername && this.hasApproverUsernameTarget) this.approverUsernameTarget.value = ""
    if (this.hasApproverPasswordTarget) this.approverPasswordTarget.value = ""
    this.clearHiddenApproverPasswords()
  }

  clearHiddenApproverPasswords() {
    if (this.hasControlApproverPasswordInputTarget) this.controlApproverPasswordInputTarget.value = ""
    if (this.hasUnlinkedApproverPasswordInputTarget) this.unlinkedApproverPasswordInputTarget.value = ""
  }

  clearConfirmationCredentials() {
    this.clearApprovalCredentials({ keepUsername: false })
    if (this.hasControlApproverUserInputTarget) this.controlApproverUserInputTarget.value = ""
    if (this.hasUnlinkedApproverUserInputTarget) this.unlinkedApproverUserInputTarget.value = ""
  }

  confirmCancel() {
    if (this.overlayTarget.hidden) return
    this.beginFlight()
    this.cancelFormTarget.requestSubmit()
  }

  moveSelection(delta) {
    if (this.inFlight) return
    const rows = Array.from(this.element.querySelectorAll(".pos-lines tbody tr"))
    if (rows.length === 0) return
    const current = rows.findIndex((row) => row.classList.contains("is-selected"))
    const nextIndex = Math.min(rows.length - 1, Math.max(0, (current < 0 ? 0 : current) + delta))
    rows.forEach((row, index) => {
      const selected = index === nextIndex
      row.classList.toggle("is-selected", selected)
      row.setAttribute("aria-selected", selected ? "true" : "false")
    })
    this.syncSelectedLine()
    this.enableReadyActions()
    this.scrollSelectedRowIntoView()
  }

  scrollSelectedRowIntoView() {
    const row = this.selectedRow()
    if (!row || typeof row.scrollIntoView !== "function") return
    row.scrollIntoView({ block: "nearest", inline: "nearest" })
  }

  overlayOpen() {
    return this.topOverlay() != null
  }

  activeOverlayElement() {
    return this.topOverlay()
  }

  dispatchOverlayKeydown(overlay, event, key) {
    if (this.hasEditTenderOverlayTarget && overlay === this.editTenderOverlayTarget) {
      this.onEditTenderOverlayKeydown(event, key)
      return
    }
    if (this.hasRemoveTenderOverlayTarget && overlay === this.removeTenderOverlayTarget) {
      this.onRemoveTenderOverlayKeydown(event, key)
      return
    }
    if (this.hasReturnToSaleOverlayTarget && overlay === this.returnToSaleOverlayTarget) {
      this.onReturnToSaleOverlayKeydown(event, key)
      return
    }
    if (this.hasClearTendersOverlayTarget && overlay === this.clearTendersOverlayTarget) {
      this.onClearTendersOverlayKeydown(event, key)
      return
    }
    if (this.hasProductOverlayTarget && overlay === this.productOverlayTarget) {
      this.onProductOverlayKeydown(event, key)
      return
    }
    if (this.hasVariantOverlayTarget && overlay === this.variantOverlayTarget) {
      this.onVariantOverlayKeydown(event, key)
      return
    }
    if (this.hasUnitOverlayTarget && overlay === this.unitOverlayTarget) {
      this.onUnitOverlayKeydown(event, key)
      return
    }
    if (this.hasOpenPriceOverlayTarget && overlay === this.openPriceOverlayTarget) {
      this.onOpenPriceOverlayKeydown(event, key)
      return
    }
    if (this.hasUnlinkedOverlayTarget && overlay === this.unlinkedOverlayTarget) {
      this.onUnlinkedOverlayKeydown(event, key)
      return
    }
    if (this.hasReturnChooserOverlayTarget && overlay === this.returnChooserOverlayTarget) {
      this.onReturnChooserKeydown(event, key)
      return
    }
    if (this.hasLinkedOverlayTarget && overlay === this.linkedOverlayTarget) {
      this.onLinkedOverlayKeydown(event, key)
      return
    }
    if (this.hasControlOverlayTarget && overlay === this.controlOverlayTarget) {
      this.onControlOverlayKeydown(event, key)
      return
    }
    if (this.hasApprovalOverlayTarget && overlay === this.approvalOverlayTarget) {
      this.onApprovalOverlayKeydown(event, key)
      return
    }
    if (this.hasOtherOverlayTarget && overlay === this.otherOverlayTarget) {
      this.onOtherOverlayKeydown(event, key)
      return
    }
    if (this.hasIssuanceOverlayTarget && overlay === this.issuanceOverlayTarget) {
      this.onIssuanceOverlayKeydown(event, key)
      return
    }
    if (this.hasSearchOverlayTarget && overlay === this.searchOverlayTarget) {
      this.onSearchOverlayKeydown(event, key)
      return
    }
    if (this.hasPickupOverlayTarget && overlay === this.pickupOverlayTarget) {
      this.onPickupOverlayKeydown(event, key)
      return
    }
    if (this.hasCustomerOverlayTarget && overlay === this.customerOverlayTarget) {
      this.onCustomerOverlayKeydown(event, key)
      return
    }
    if (this.hasQuickCustomerOverlayTarget && overlay === this.quickCustomerOverlayTarget) {
      this.onQuickCustomerOverlayKeydown(event, key)
      return
    }
    if (this.hasOverlayTarget && overlay === this.overlayTarget) {
      event.preventDefault()
      if (key === "Escape") this.closeOverlay()
      if (key === "F9") this.confirmCancel()
    }
  }

  topOverlay() {
    for (let index = this.overlayStack.length - 1; index >= 0; index -= 1) {
      const entry = this.overlayStack[index]
      if (entry?.overlay && !entry.overlay.hidden) return entry.overlay
    }
    return null
  }

  showOverlay(overlay, options = {}) {
    if (!overlay) return
    const opts = options && options.nodeType ? { initialFocus: options } : (options || {})
    this.clearOverlayError(overlay)
    const parent = opts.parent || this.topOverlay()
    const opener = opts.opener || document.activeElement
    const initialFocus = opts.initialFocus || this.overlayFocusables(overlay)[0]
    this.overlayStack = this.overlayStack.filter((entry) => entry.overlay !== overlay)
    this.overlayStack.push({
      overlay,
      opener,
      parent: parent && parent !== overlay ? parent : null,
      entryFocus: initialFocus
    })
    overlay.hidden = false
    overlay.setAttribute("aria-modal", "true")
    overlay.style.zIndex = String(1000 + (this.overlayStack.length * 10))
    if (parent && parent !== overlay) {
      parent.inert = true
      parent.setAttribute("aria-modal", "false")
    }
    this.syncWorkspaceBackgroundInert()
    this.focusOverlayEntry(initialFocus)
  }

  hideOverlay(overlay) {
    if (!overlay) return
    const index = this.overlayStack.findIndex((entry) => entry.overlay === overlay)
    if (index < 0) {
      this.hideOverlayNode(overlay)
      this.syncWorkspaceBackgroundInert()
      if (this.topOverlay() == null) this.restoreFocus()
      return
    }
    const entry = this.overlayStack[index]
    const descendants = this.overlayStack.slice(index + 1)
    descendants.reverse().forEach((child) => this.hideOverlayNode(child.overlay))
    this.hideOverlayNode(overlay)
    this.overlayStack.splice(index)
    this.syncWorkspaceBackgroundInert()
    this.restoreOverlayFocus(entry)
  }

  hideOverlayNode(overlay) {
    if (!overlay) return
    if (this.hasApprovalOverlayTarget && overlay === this.approvalOverlayTarget) {
      this.clearApprovalCredentials({ keepUsername: false })
      this.confirmationInvocation = null
    }
    if (this.hasOtherOverlayTarget && overlay === this.otherOverlayTarget) {
      this.tenderPickerInvocation = null
    }
    overlay.hidden = true
    overlay.inert = false
    overlay.style.zIndex = ""
    overlay.setAttribute("aria-modal", "true")
    this.clearOverlayError(overlay)
  }

  clearOverlayStack({ restoreCommand = true } = {}) {
    this.abortPendingLookups()
    this.clearConfirmationCredentials()
    this.confirmationInvocation = null
    this.tenderPickerInvocation = null
    const entries = [ ...this.overlayStack ]
    this.overlayStack = []
    entries.reverse().forEach((entry) => this.hideOverlayNode(entry.overlay))
    this.syncWorkspaceBackgroundInert()
    if (restoreCommand) this.restoreFocus()
  }

  syncWorkspaceBackgroundInert() {
    if (!this.hasBackgroundTarget) return
    this.backgroundTarget.inert = this.topOverlay() != null
  }

  restoreOverlayFocus(closedEntry) {
    if (!closedEntry) {
      if (this.topOverlay() == null) this.restoreFocus()
      return
    }
    const parent = closedEntry.parent
    if (parent && !parent.hidden) {
      parent.inert = false
      parent.setAttribute("aria-modal", "true")
      const parentEntry = this.overlayStack.find((entry) => entry.overlay === parent)
      const focusTarget = parent.querySelector("li.is-selected:not(.is-disabled)") ||
        parentEntry?.entryFocus ||
        this.overlayFocusables(parent)[0]
      this.focusOverlayEntry(focusTarget)
      return
    }
    if (this.topOverlay() == null) this.restoreFocus()
  }

  focusOverlayEntry(el) {
    if (!el || typeof el.focus !== "function") return
    el.focus()
    if (typeof el.select === "function" && "value" in el && String(el.value || "").length > 0) {
      el.select()
    }
  }

  abortPendingLookups() {
    if (this.searchAbort) this.searchAbort.abort()
    if (this.pickupAbort) this.pickupAbort.abort()
    if (this.customerAbort) this.customerAbort.abort()
    if (this.linkedAbort) this.linkedAbort.abort()
    if (this.unlinkedAbort) this.unlinkedAbort.abort()
    this.searchAbort = null
    this.pickupAbort = null
    this.customerAbort = null
    this.linkedAbort = null
    this.unlinkedAbort = null
    this.searchRequestToken += 1
    this.pickupRequestToken += 1
    this.customerRequestToken += 1
    this.linkedInvocation += 1
    this.unlinkedInvocation += 1
  }

  clearOverlayError(overlay) {
    const node = overlay?.querySelector("[data-overlay-error]")
    if (node) node.textContent = ""
  }

  overlayFocusables(overlay) {
    if (!overlay) return []
    return Array.from(overlay.querySelectorAll("input, select, textarea, button, [tabindex]:not([tabindex='-1'])")).filter((el) => {
      if (el.disabled || el.hidden || el.closest("[inert]")) return false
      return !el.closest("[hidden]")
    })
  }

  trapTabInOverlay(overlay, event) {
    const controls = this.overlayFocusables(overlay)
    if (controls.length === 0) return
    event.preventDefault()
    const current = controls.indexOf(document.activeElement)
    let next
    if (event.shiftKey) {
      next = current <= 0 ? controls.length - 1 : current - 1
    } else {
      next = current === controls.length - 1 || current < 0 ? 0 : current + 1
    }
    controls[next].focus()
  }

  decoratePickerItem(item, { selected = false, disabled = false } = {}) {
    item.setAttribute("role", "option")
    item.classList.toggle("is-selected", selected)
    item.classList.toggle("is-disabled", disabled)
    item.setAttribute("aria-selected", selected ? "true" : "false")
    item.tabIndex = selected ? 0 : -1
    if (disabled) item.setAttribute("aria-disabled", "true")
    else item.removeAttribute("aria-disabled")
  }

  recoverDialogRejection() {
    this.inFlight = false
    if (this.hasFieldTarget) this.fieldTarget.disabled = false
    if (this.hasReferenceFieldTarget) this.referenceFieldTarget.disabled = false
    this.enableReadyActions()
    this.syncUnlinkedPrimaryEnabled()
    this.syncLinkedPrimaryEnabled()

    const failure = this.readOverlayFailure()
    const kind = failure?.kind
    this.clearHiddenApproverPasswords()

    if (kind === "authorization_failed" || kind === "authorization_prohibited") {
      if (this.hasApproverPasswordTarget) this.approverPasswordTarget.value = ""
      const focusField = (kind === "authorization_prohibited" || failure?.field === "approver_username") && this.hasApproverUsernameTarget
        ? this.approverUsernameTarget
        : (this.hasApproverPasswordTarget && this.approverPasswordTarget)
      if (focusField) {
        focusField.focus()
        if (typeof focusField.select === "function") focusField.select()
      }
      return
    }

    if (kind === "parent_validation_failed") {
      if (this.approvalOverlayOpen()) this.closeApprovalOverlay({ clearInvocation: true })
      const parent = this.activeOverlayElement()
      if (!parent) return
      const focusables = this.overlayFocusables(parent)
      const firstField = focusables.find((el) => el.matches("input, select, textarea"))
      if (firstField) {
        firstField.focus()
        return
      }
      if (focusables[0]) focusables[0].focus()
      return
    }

    // stale_transaction replaces the workspace via Turbo — no overlay to recover.
    if (kind === "stale_transaction") return

    const overlay = this.activeOverlayElement()
    if (!overlay) return
    overlay.querySelectorAll("input[type='password']").forEach((field) => {
      field.value = ""
    })
    const password = this.overlayFocusables(overlay).find((el) => el.type === "password")
    if (password) {
      password.focus()
      return
    }
    if (overlay.contains(document.activeElement)) return
    const first = this.overlayFocusables(overlay)[0]
    if (first) first.focus()
  }

  readOverlayFailure() {
    const nodes = [
      ...(this.hasOverlayFailureMetaTarget ? this.overlayFailureMetaTargets : []),
      ...Array.from(this.element.querySelectorAll("[data-overlay-error-kind]"))
    ]
    const node = nodes.find((entry) => entry?.dataset?.overlayErrorKind)
    if (!node) return null
    return {
      kind: node.dataset.overlayErrorKind,
      field: node.dataset.overlayErrorField || null,
      message: node.textContent || ""
    }
  }

  cancelOverlayOpen() {
    return this.hasOverlayTarget && !this.overlayTarget.hidden
  }

  controlOverlayOpen() {
    return this.hasControlOverlayTarget && !this.controlOverlayTarget.hidden
  }

  approvalOverlayOpen() {
    return this.hasApprovalOverlayTarget && !this.approvalOverlayTarget.hidden
  }

  unlinkedOverlayOpen() {
    return this.hasUnlinkedOverlayTarget && !this.unlinkedOverlayTarget.hidden
  }

  otherOverlayOpen() {
    return this.hasOtherOverlayTarget && !this.otherOverlayTarget.hidden
  }

  issuanceOverlayOpen() {
    return this.hasIssuanceOverlayTarget && !this.issuanceOverlayTarget.hidden
  }

  searchOverlayOpen() {
    return this.hasSearchOverlayTarget && !this.searchOverlayTarget.hidden
  }

  pickupOverlayOpen() {
    return this.hasPickupOverlayTarget && !this.pickupOverlayTarget.hidden
  }

  customerOverlayOpen() {
    return this.hasCustomerOverlayTarget && !this.customerOverlayTarget.hidden
  }

  quickCustomerOverlayOpen() {
    return this.hasQuickCustomerOverlayTarget && !this.quickCustomerOverlayTarget.hidden
  }

  productOverlayOpen() {
    return this.hasProductOverlayTarget && !this.productOverlayTarget.hidden
  }

  variantOverlayOpen() {
    return this.hasVariantOverlayTarget && !this.variantOverlayTarget.hidden
  }

  unitOverlayOpen() {
    return this.hasUnitOverlayTarget && !this.unitOverlayTarget.hidden
  }

  openPriceOverlayOpen() {
    return this.hasOpenPriceOverlayTarget && !this.openPriceOverlayTarget.hidden
  }

  returnChooserOpen() {
    return this.hasReturnChooserOverlayTarget && !this.returnChooserOverlayTarget.hidden
  }

  linkedOverlayOpen() {
    return this.hasLinkedOverlayTarget && !this.linkedOverlayTarget.hidden
  }

  selectedRow() {
    return this.element.querySelector(".pos-lines tbody tr.is-selected")
  }

  selectedUnitLine() {
    const row = this.selectedRow()
    return Boolean(row && row.dataset.unitLine === "true")
  }

  syncSelectedLine() {
    const row = this.selectedRow()
    if (!row) return
    const id = row.dataset.lineId
    if (this.hasQuantityLineInputTarget) this.quantityLineInputTarget.value = id
    if (this.hasRemoveLineInputTarget) this.removeLineInputTarget.value = id
    if (this.hasControlLineInputTarget) this.controlLineInputTarget.value = id
    if (this.hasOpenPriceLineInputTarget) this.openPriceLineInputTarget.value = id
  }

  beginFlight() {
    this.inFlight = true
    this.disableMutationControls()
    if (this.hasReferenceFieldTarget) this.referenceFieldTarget.disabled = true
    if (this.hasFieldTarget) this.fieldTarget.disabled = true
  }

  disableMutationControls() {
    ["returnButton", "quantityButton", "overrideButton", "discountButton", "taxClassButton", "tenderButton", "removeButton", "cancelButton", "retry", "abandonButton", "cashButton", "cardButton", "checkButton", "otherButton", "storedValueButton"].forEach((name) => {
      this.setActionEnabled(name, false)
    })
  }

  enableTenderIdentityButtons() {
    const hasLines = this.hasCommercialContent()
    const enabled = hasLines && (this.modeValue === "sale_entry" || this.modeValue === "tender")
    this.setActionEnabled("cashButton", enabled && this.typesForCategory("cash").length > 0)
    this.setActionEnabled("cardButton", enabled && this.typesForCategory("card").length > 0)
    this.setActionEnabled("checkButton", enabled && this.typesForCategory("check").length > 0)
    this.setActionEnabled("otherButton", enabled && this.otherTypes().length > 0)
    this.setActionEnabled("storedValueButton", enabled && this.typesForCategory("stored_value").length > 0)
  }

  enableReadyActions() {
    if (this.modeValue === "sale_entry") {
      const hasSelection = Boolean(this.selectedRow())
      const hasLines = this.hasCommercialContent()
      const returnLine = this.selectedReturnLine()
      const quantityOk = hasSelection && !this.selectedUnitLine() && !this.selectedQuantityBlocked()
      this.setActionEnabled("returnButton", true)
      this.setActionEnabled("quantityButton", quantityOk)
      this.setActionEnabled("overrideButton", hasSelection && !returnLine && this.priceActionEnabled())
      this.setActionEnabled("discountButton", hasSelection && !returnLine && this.policyFor("line_discount") !== "prohibited")
      this.setActionEnabled("taxClassButton", hasSelection && !returnLine && this.policyFor("tax_class_override") !== "prohibited")
      this.setActionEnabled("tenderButton", hasLines)
      this.setActionEnabled("removeButton", hasSelection)
      this.setActionEnabled("cancelButton", hasLines)
      this.enableTenderIdentityButtons()
      return
    }
    if (this.modeValue === "tender") {
      this.enableTenderIdentityButtons()
      return
    }
    if (this.modeValue === "completion_failed") {
      this.setActionEnabled("cancelButton", true)
      this.setActionEnabled("retry", true)
      this.setActionEnabled("abandonButton", true)
    }
  }

  recoverFromTransportFailure(form) {
    if (this.hasCompleteFormTarget && form && (form === this.completeFormTarget || this.completeFormTarget.contains(form))) {
      this.recoverCompleteTransport()
      return
    }
    if (this.workspaceUrlValue) {
      window.location.assign(this.workspaceUrlValue)
    }
  }

  recoverCompleteTransport() {
    this.inFlight = false
    if (this.hasFeedbackTarget) {
      this.feedbackTarget.textContent = "Connection lost. Retry complete does not take Cash again."
      this.feedbackTarget.setAttribute("role", "alert")
    }
    if (this.hasRetryTarget) {
      this.retryTarget.disabled = false
      this.retryTarget.focus()
      return
    }
    if (this.hasClientRecoveryTarget) {
      this.clientRecoveryTarget.hidden = false
      const button = this.clientRecoveryTarget.querySelector("button")
      if (button) button.focus()
    }
  }

  restoreFocus() {
    if (this.hasRetryTarget && this.modeValue === "completion_failed") {
      this.retryTarget.focus()
      return
    }
    if (!this.hasFieldTarget) return
    if (this.fieldTarget.disabled) return
    this.fieldTarget.focus()
    requestAnimationFrame(() => {
      if (!this.hasFieldTarget || this.fieldTarget.disabled) return
      this.fieldTarget.focus()
    })
  }

  isCommandSurfaceInput(target) {
    if (!target) return false
    if (this.hasFieldTarget && target === this.fieldTarget) return true
    if (this.hasReferenceFieldTarget && target === this.referenceFieldTarget) return true
    if (this.hasGiftCardNumberFieldTarget && target === this.giftCardNumberFieldTarget) return true
    return false
  }

  reservedCommandGlyph(key, event) {
    return key === "*" || key === "+" || key === "/" || key === "." || key === "-" || event.code === "Minus"
  }

  redirectPrintableToCommandField(event) {
    if (event.defaultPrevented) return
    if (!this.hasFieldTarget || this.fieldTarget.disabled) return
    if (this.overlayOpen() && this.topOverlay()?.contains(event.target)) return
    if (this.isCommandSurfaceInput(event.target)) return
    if (event.isComposing) return
    if (event.metaKey || event.ctrlKey || event.altKey) return
    const key = event.key
    if (typeof key !== "string" || key.length !== 1 || key === " ") return
    if (this.commandFieldEmpty() && this.reservedCommandGlyph(key, event)) return

    event.preventDefault()
    const field = this.fieldTarget
    field.focus()
    const start = field.selectionStart ?? field.value.length
    const end = field.selectionEnd ?? field.value.length
    field.value = `${field.value.slice(0, start)}${key}${field.value.slice(end)}`
    const caret = start + key.length
    if (typeof field.setSelectionRange === "function") field.setSelectionRange(caret, caret)
  }

  setMode(mode, heading) {
    this.modeValue = mode
    this.element.dataset.registerWorkspaceModeValue = mode
    if (this.hasModeLabelTarget) this.modeLabelTarget.textContent = heading
  }

  setFieldLabel(text) {
    if (this.hasFieldLabelTarget) this.fieldLabelTarget.textContent = text
  }

  setActionEnabled(targetName, enabled) {
    const has = `has${targetName.charAt(0).toUpperCase()}${targetName.slice(1)}Target`
    if (!this[has]) return
    this[`${targetName}Target`].disabled = !enabled
  }

  isActionableControl(target) {
    if (!target || !target.closest) return false
    return Boolean(target.closest("button, [type=submit], a[href], [role=button]"))
  }

  populateReasons(actionType) {
    if (!this.hasControlReasonFieldTarget) return
    const catalog = (this.reasonsValue || {})[actionType] || {}
    this.controlReasonFieldTarget.replaceChildren()
    const blank = document.createElement("option")
    blank.value = ""
    blank.textContent = "Reason"
    this.controlReasonFieldTarget.append(blank)
    Object.entries(catalog).forEach(([code, name]) => {
      const option = document.createElement("option")
      option.value = code
      option.textContent = name
      this.controlReasonFieldTarget.append(option)
    })
    this.toggleHidden(this.hasControlNoteWrapTarget && this.controlNoteWrapTarget, true)
    if (this.hasControlNoteFieldTarget) this.controlNoteFieldTarget.value = ""
  }

  bindFunctionKeyCapture() {
    if (this.functionKeyListenersBound) return
    this.functionKeyListenersBound = true
    this.onWindowKeydown = (event) => this.onKeydown(event)
    this.onWindowKeyup = (event) => this.suppressBrowserFunctionKeys(event)
    window.addEventListener("keydown", this.onWindowKeydown, true)
    window.addEventListener("keyup", this.onWindowKeyup, true)
  }

  unbindFunctionKeyCapture() {
    if (!this.functionKeyListenersBound) return
    this.functionKeyListenersBound = false
    window.removeEventListener("keydown", this.onWindowKeydown, true)
    window.removeEventListener("keyup", this.onWindowKeyup, true)
  }

  functionKey(event) {
    if (typeof event.key === "string" && /^F\d{1,2}$/i.test(event.key)) return event.key.toUpperCase()
    if (typeof event.code === "string" && /^F\d{1,2}$/i.test(event.code)) return event.code.toUpperCase()
    return null
  }

  claimedFunctionKey(key) {
    return key === "F1" || key === "F2" || key === "F3" || key === "F4" || key === "F5" || key === "F6" || key === "F7" || key === "F8" || key === "F9"
  }

  claimFunctionKey(event) {
    event.preventDefault()
    if (typeof event.stopImmediatePropagation === "function") event.stopImmediatePropagation()
  }

  policyFor(actionType) {
    const policies = this.policiesValue || {}
    return policies[actionType] || "prohibited"
  }

  selectedReturnLine() {
    const row = this.selectedRow()
    return Boolean(row && row.dataset.direction === "return")
  }

  selectedQuantityBlocked() {
    const row = this.selectedRow()
    if (!row) return false
    if (row.dataset.direction === "return") return row.dataset.linkedReturn !== "true"
    return Boolean(row.dataset.priceOverridden === "true" || row.dataset.discounted === "true")
  }

  lineHasAction(row, actionType) {
    if (actionType === "price_override") return row.dataset.priceOverridden === "true"
    if (actionType === "line_discount") return row.dataset.discounted === "true"
    if (actionType === "tax_class_override") return row.dataset.taxOverridden === "true"
    return false
  }

  formatCents(cents) {
    const value = Number(cents || 0)
    const dollars = Math.trunc(value / 100)
    const remainder = Math.abs(value % 100).toString().padStart(2, "0")
    return `${dollars}.${remainder}`
  }

  toggleHidden(element, hidden) {
    if (!element) return
    element.hidden = hidden
  }
}
