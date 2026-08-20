import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "field",
    "fieldLabel",
    "modeLabel",
    "chrome",
    "overlay",
    "controlOverlay",
    "unlinkedOverlay",
    "unlinkedForm",
    "completeForm",
    "tenderForm",
    "removeTenderForm",
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
    "referenceLabel",
    "removeTenderInput",
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
    "controlPriceWrap",
    "controlDiscountWrap",
    "controlTaxWrap",
    "controlPriceField",
    "controlDiscountField",
    "controlTaxField",
    "controlReasonField",
    "controlNoteWrap",
    "controlNoteField",
    "controlApproverWrap",
    "approverUsername",
    "approverPassword",
    "controlCancel",
    "controlApply",
    "controlRemove",
    "unlinkedButton",
    "unlinkedIdentifierField",
    "unlinkedIdentifierInput",
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
    "unlinkedPreview",
    "unlinkedDescription",
    "unlinkedReferenceLabel",
    "unlinkedQuantityWrap",
    "unlinkedQuantityField",
    "unlinkedReasonField",
    "unlinkedNoteWrap",
    "unlinkedNoteField",
    "unlinkedPriceField",
    "unlinkedApproverWrap",
    "unlinkedApproverUsername",
    "unlinkedApproverPassword",
    "unlinkedCancel",
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
    "otherOverlay",
    "otherList",
    "searchOverlay",
    "searchList",
    "searchSkuField",
    "searchNameField",
    "searchQueryLabel",
    "variantOverlay",
    "variantList",
    "unitOverlay",
    "unitList",
    "openPriceOverlay",
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
    "linkedOverlay",
    "linkedLookupField",
    "linkedFeedback",
    "linkedList",
    "linkedQuantityField",
    "linkedReasonField",
    "linkedNoteWrap",
    "linkedNoteField",
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
    openPriceUrl: String,
    settlement: String,
    refundRemaining: Number,
    paymentRemaining: Number,
    transactionsUrl: String
  }

  connect() {
    this.inFlight = false
    this.bindFunctionKeyCapture()
    if (this.hasControlReasonFieldTarget) {
      this.controlReasonFieldTarget.addEventListener("change", () => {
        this.toggleHidden(this.hasControlNoteWrapTarget && this.controlNoteWrapTarget, this.controlReasonFieldTarget.value !== "other")
      })
    }
    if (this.hasUnlinkedReasonFieldTarget) {
      this.unlinkedReasonFieldTarget.addEventListener("change", () => {
        this.toggleHidden(this.hasUnlinkedNoteWrapTarget && this.unlinkedNoteWrapTarget, this.unlinkedReasonFieldTarget.value !== "other")
      })
    }
    if (this.autoCompleteValue) {
      this.submitComplete()
      return
    }
    this.enableReadyActions()
    this.restoreFocus()
  }

  disconnect() {
    this.unbindFunctionKeyCapture()
  }

  onKeydown(event) {
    const functionKey = this.functionKey(event)
    const key = functionKey || event.key
    if (this.claimedFunctionKey(functionKey)) this.claimFunctionKey(event)

    if (key === "F10") {
      event.preventDefault()
      this.openTransactions()
      return
    }

    const overlay = this.activeOverlayElement()
    if (overlay && key === "Tab") {
      this.trapTabInOverlay(overlay, event)
      return
    }

    if (this.unlinkedOverlayOpen()) {
      this.onUnlinkedOverlayKeydown(event, key)
      return
    }

    if (this.returnChooserOpen()) {
      this.onReturnChooserKeydown(event, key)
      return
    }

    if (this.linkedOverlayOpen()) {
      this.onLinkedOverlayKeydown(event, key)
      return
    }

    if (this.controlOverlayOpen()) {
      this.onControlOverlayKeydown(event, key)
      return
    }

    if (this.otherOverlayOpen()) {
      this.onOtherOverlayKeydown(event, key)
      return
    }

    if (this.searchOverlayOpen()) {
      this.onSearchOverlayKeydown(event, key)
      return
    }

    if (this.variantOverlayOpen()) {
      this.onVariantOverlayKeydown(event, key)
      return
    }

    if (this.unitOverlayOpen()) {
      this.onUnitOverlayKeydown(event, key)
      return
    }

    if (this.openPriceOverlayOpen()) {
      this.onOpenPriceOverlayKeydown(event, key)
      return
    }

    if (this.cancelOverlayOpen()) {
      event.preventDefault()
      if (key === "Escape") this.closeOverlay()
      if (key === "F9") this.confirmCancel()
      return
    }

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
    if (key === "F9") {
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
      if (this.approverPasswordTarget.value.trim() !== "") this.submitControlApply()
      return
    }
    if (this.isActionableControl(target)) return
    event.preventDefault()
    this.advanceOrApplyControlOverlay()
  }

  advanceOrApplyControlOverlay() {
    if (this.policyFor(this.currentControlAction) !== "approval_required") {
      this.submitControlApply()
      return
    }
    if (this.controlReasonNeedsNote()) {
      this.controlNoteFieldTarget.focus()
      return
    }
    if (this.hasApproverUsernameTarget && !this.controlApproverWrapTarget?.hidden) {
      if (this.approverUsernameTarget.value.trim() === "") {
        this.approverUsernameTarget.focus()
        return
      }
      if (this.hasApproverPasswordTarget) {
        this.approverPasswordTarget.focus()
        return
      }
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

  onUnlinkedOverlayKeydown(event, key = this.functionKey(event) || event.key) {
    if (key === "Escape") {
      event.preventDefault()
      this.closeUnlinkedOverlay()
      return
    }
    if (key === "F9") {
      event.preventDefault()
      return
    }
    if (key !== "Enter") return

    const target = event.target
    if (this.hasUnlinkedIdentifierFieldTarget && target === this.unlinkedIdentifierFieldTarget) {
      event.preventDefault()
      this.resolveUnlinkedIdentifier()
      return
    }
    if (this.hasUnlinkedApproverUsernameTarget && target === this.unlinkedApproverUsernameTarget) {
      event.preventDefault()
      if (this.hasUnlinkedApproverPasswordTarget) this.unlinkedApproverPasswordTarget.focus()
      return
    }
    if (this.hasUnlinkedApproverPasswordTarget && target === this.unlinkedApproverPasswordTarget) {
      event.preventDefault()
      if (this.unlinkedApproverPasswordTarget.value.trim() !== "") this.submitUnlinkedReturn()
      return
    }
    if (this.isActionableControl(target)) return
    event.preventDefault()
    this.advanceOrApplyUnlinkedOverlay()
  }

  advanceOrApplyUnlinkedOverlay() {
    if (!this.unlinkedPreviewPayload) return
    if (this.policyFor("unlinked_return") !== "approval_required") {
      this.submitUnlinkedReturn()
      return
    }
    if (this.hasUnlinkedReasonFieldTarget &&
        this.unlinkedReasonFieldTarget.value === "other" &&
        this.hasUnlinkedNoteFieldTarget &&
        this.unlinkedNoteFieldTarget.value.trim() === "" &&
        this.hasUnlinkedNoteWrapTarget &&
        !this.unlinkedNoteWrapTarget.hidden) {
      this.unlinkedNoteFieldTarget.focus()
      return
    }
    if (this.hasUnlinkedApproverUsernameTarget && !this.unlinkedApproverWrapTarget?.hidden) {
      if (this.unlinkedApproverUsernameTarget.value.trim() === "") {
        this.unlinkedApproverUsernameTarget.focus()
        return
      }
      if (this.hasUnlinkedApproverPasswordTarget) {
        this.unlinkedApproverPasswordTarget.focus()
        return
      }
    }
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
    if (!this.element.querySelector(".pos-lines tbody tr")) {
      this.showFeedback("Add merchandise before taking a tender.")
      return
    }
    if (this.settlementValue === "none") {
      this.submitComplete()
      return
    }
    this.beginTenderMode()
    this.applyTenderType(this.typesForCategory("cash")[0] || this.cashierTenderTypes()[this.cashTenderIndex()])
    this.prefillRemaining()
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
    this.openOtherPicker(types)
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
    if (!this.element.querySelector(".pos-lines tbody tr")) {
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

  openTransactions() {
    if (this.overlayOpen()) {
      this.showFeedback("Finish or cancel the current dialog before opening Transactions.")
      return
    }
    if (this.modeValue !== "sale_entry" && this.modeValue !== "tender") return
    if (!this.transactionsUrlValue) return
    window.location.assign(this.transactionsUrlValue)
  }

  showFeedback(message) {
    if (!this.hasFeedbackTarget) return
    this.feedbackTarget.textContent = message
    this.feedbackTarget.setAttribute("role", "alert")
  }

  openOtherPicker(types) {
    if (!this.hasOtherOverlayTarget || !this.hasOtherListTarget) return
    this.otherListTarget.replaceChildren()
    types.forEach((type, index) => {
      const item = document.createElement("li")
      item.dataset.tenderTypeId = type.id
      item.textContent = type.name
      this.decoratePickerItem(item, { selected: index === 0 })
      this.otherListTarget.append(item)
    })
    this.showOverlay(this.otherOverlayTarget, this.otherListTarget.querySelector("li.is-selected"))
  }

  closeOtherOverlay() {
    this.hideOverlay(this.hasOtherOverlayTarget && this.otherOverlayTarget)
  }

  onOtherOverlayKeydown(event, key) {
    if (key === "Escape") {
      event.preventDefault()
      this.closeOtherOverlay()
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
    this.closeOtherOverlay()
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
        this.postAddMerchandise({ variantId: result.variant.id })
        return
      case "addable_unit":
        this.postAddMerchandise({ unitId: result.unit.id })
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
    this.searchResultsReady = false
    if (this.hasSearchSkuFieldTarget) this.searchSkuFieldTarget.value = ""
    if (this.hasSearchNameFieldTarget) this.searchNameFieldTarget.value = ""
    if (this.hasSearchListTarget) this.searchListTarget.replaceChildren()
    if (this.hasSearchQueryLabelTarget) this.searchQueryLabelTarget.textContent = ""
    this.showOverlay(this.searchOverlayTarget, this.hasSearchSkuFieldTarget && this.searchSkuFieldTarget)
  }

  closeSearchOverlay() {
    this.hideOverlay(this.hasSearchOverlayTarget && this.searchOverlayTarget)
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
    if (inField && !this.searchResultsReady) {
      this.runMerchandiseSearch()
      return
    }
    if (inField) {
      this.runMerchandiseSearch()
      return
    }
    this.selectHighlightedSearch()
  }

  async runMerchandiseSearch() {
    const sku = this.hasSearchSkuFieldTarget ? this.searchSkuFieldTarget.value.trim() : ""
    const name = this.hasSearchNameFieldTarget ? this.searchNameFieldTarget.value.trim() : ""
    if (!sku && !name) return
    const url = new URL(this.searchUrlValue, window.location.origin)
    if (sku) url.searchParams.set("sku", sku)
    if (name) url.searchParams.set("name", name)
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" }, credentials: "same-origin" })
      const payload = await response.json()
      this.renderSearchResults(payload.results || [])
    } catch (_error) {
      this.renderSearchResults([])
      if (this.hasSearchQueryLabelTarget) this.searchQueryLabelTarget.textContent = "Search failed."
    }
  }

  renderSearchResults(rows) {
    if (!this.hasSearchListTarget) return
    this.searchListTarget.replaceChildren()
    this.searchResultsReady = true
    if (this.hasSearchQueryLabelTarget) {
      this.searchQueryLabelTarget.textContent = rows.length === 0 ? "No matching merchandise." : ""
    }
    rows.forEach((row, index) => {
      const item = document.createElement("li")
      item.dataset.variantId = row.id
      item.dataset.disabled = row.disabled ? "true" : "false"
      item.dataset.reason = row.reason || ""
      const availability = row.available == null ? "" : ` · ${row.available}`
      const reason = row.disabled && row.reason ? ` — ${row.reason}` : ""
      item.textContent = [row.sku, row.name, row.condition, row.price_label].filter(Boolean).join(" · ") + availability + reason
      this.decoratePickerItem(item, { selected: index === 0, disabled: Boolean(row.disabled) })
      this.searchListTarget.append(item)
    })
    const first = this.searchListTarget.querySelector("li.is-selected")
    if (first) first.focus()
  }

  selectHighlightedSearch() {
    const selected = this.hasSearchListTarget && this.searchListTarget.querySelector("li.is-selected")
    if (!selected) return
    if (selected.dataset.disabled === "true") {
      this.showFeedback(selected.dataset.reason || "merchandise is not sellable")
      return
    }
    const variantId = selected.dataset.variantId
    this.closeSearchOverlay()
    this.resolveAndHandle({ product_variant_id: variantId })
  }

  openVariantPicker(variants) {
    if (!this.hasVariantOverlayTarget || !this.hasVariantListTarget) return
    this.variantListTarget.replaceChildren()
    variants.forEach((variant, index) => {
      const item = document.createElement("li")
      item.dataset.variantId = variant.id
      const price = variant.price_label || this.formatCents(variant.price_cents)
      const availability = variant.available == null ? "" : ` · ${variant.available}`
      item.textContent = [variant.sku, variant.name, variant.condition, price].filter(Boolean).join(" · ") + availability
      this.decoratePickerItem(item, { selected: index === 0 })
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
    if (!selected) return
    const variantId = selected.dataset.variantId
    this.closeVariantOverlay()
    this.resolveAndHandle({ product_variant_id: variantId })
  }

  openUnitPicker(units) {
    if (!this.hasUnitOverlayTarget || !this.hasUnitListTarget) return
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
    if (!selected || !selected.dataset.unitId) return
    const unitId = selected.dataset.unitId
    this.closeUnitOverlay()
    this.resolveAndHandle({ inventory_unit_id: unitId })
  }

  movePickerList(list, delta) {
    if (!list) return
    const items = Array.from(list.querySelectorAll("li")).filter((item) => !item.classList.contains("is-disabled") || item.dataset.variantId)
    if (items.length === 0) return
    const current = items.findIndex((item) => item.classList.contains("is-selected"))
    const nextIndex = Math.min(items.length - 1, Math.max(0, (current < 0 ? 0 : current) + delta))
    items.forEach((item, index) => {
      const selected = index === nextIndex
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
      this.openPriceFieldTarget.value = currentCents ? this.formatCents(currentCents) : ""
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
    this.clearOverlayError(this.openPriceOverlayTarget)
    if (pending.kind === "edit") {
      if (this.hasOpenPriceLineInputTarget) this.openPriceLineInputTarget.value = pending.lineId
      if (this.hasOpenPriceEditInputTarget) this.openPriceEditInputTarget.value = value
      this.beginFlight()
      this.openPriceFormTarget.requestSubmit()
      return
    }
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
    items.forEach((item, index) => {
      this.decoratePickerItem(item, { selected: index === 0 })
    })
    this.showOverlay(this.returnChooserOverlayTarget, this.returnChooserListTarget.querySelector("li.is-selected"))
  }

  closeReturnChooser() {
    this.hideOverlay(this.hasReturnChooserOverlayTarget && this.returnChooserOverlayTarget)
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
      return
    }
    if (key === "Enter") {
      event.preventDefault()
      this.selectReturnChooser()
    }
  }

  selectReturnChooser() {
    const selected = this.hasReturnChooserListTarget && this.returnChooserListTarget.querySelector("li.is-selected")
    if (!selected) return
    const choice = selected.dataset.choice
    this.closeReturnChooser()
    if (choice === "unlinked") {
      if (this.policyFor("unlinked_return") === "prohibited") {
        this.showFeedback("Return without receipt is not available.")
        return
      }
      this.openUnlinkedOverlay()
      return
    }
    this.openLinkedOverlay()
  }

  openLinkedOverlay() {
    if (this.inFlight || this.modeValue !== "sale_entry") return
    if (!this.hasLinkedOverlayTarget) return
    this.linkedMode = "lookup"
    if (this.hasLinkedLookupFieldTarget) this.linkedLookupFieldTarget.value = ""
    if (this.hasLinkedFeedbackTarget) this.linkedFeedbackTarget.textContent = ""
    if (this.hasLinkedListTarget) this.linkedListTarget.replaceChildren()
    if (this.hasLinkedQuantityFieldTarget) this.linkedQuantityFieldTarget.value = "1"
    this.populateLinkedReasons()
    this.toggleHidden(this.hasLinkedNoteWrapTarget && this.linkedNoteWrapTarget, true)
    this.showOverlay(this.linkedOverlayTarget, this.hasLinkedLookupFieldTarget && this.linkedLookupFieldTarget)
  }

  closeLinkedOverlay() {
    this.hideOverlay(this.hasLinkedOverlayTarget && this.linkedOverlayTarget)
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

  onLinkedOverlayKeydown(event, key) {
    if (key === "Escape") {
      event.preventDefault()
      this.closeLinkedOverlay()
      return
    }
    if (key === "ArrowUp" || key === "ArrowDown") {
      event.preventDefault()
      this.movePickerList(this.linkedListTarget, key === "ArrowUp" ? -1 : 1)
      return
    }
    if (key !== "Enter") return
    event.preventDefault()
    if (event.target === this.linkedLookupFieldTarget) {
      this.runLinkedLookup()
      return
    }
    this.selectHighlightedLinked()
  }

  async runLinkedLookup(params = {}) {
    const query = this.hasLinkedLookupFieldTarget ? this.linkedLookupFieldTarget.value.trim() : ""
    const url = new URL(this.linkedLookupUrlValue, window.location.origin)
    if (params.transaction_id) url.searchParams.set("transaction_id", params.transaction_id)
    else if (query) url.searchParams.set("q", query)
    else return
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" }, credentials: "same-origin" })
      const payload = await response.json()
      this.renderLinkedLookup(payload)
    } catch (_error) {
      if (this.hasLinkedFeedbackTarget) this.linkedFeedbackTarget.textContent = "no returnable original found"
    }
  }

  renderLinkedLookup(payload) {
    if (this.hasLinkedFeedbackTarget) this.linkedFeedbackTarget.textContent = payload.message || ""
    if (!this.hasLinkedListTarget) return
    this.linkedListTarget.replaceChildren()
    if (payload.outcome === "receipts") {
      this.linkedMode = "receipts"
      ;(payload.receipts || []).forEach((receipt, index) => {
        const item = document.createElement("li")
        item.dataset.transactionId = receipt.id
        item.textContent = receipt.transaction_reference
        this.decoratePickerItem(item, { selected: index === 0 })
        this.linkedListTarget.append(item)
      })
    } else if (payload.outcome === "lines") {
      this.linkedMode = "lines"
      ;(payload.lines || []).forEach((line, index) => {
        const item = document.createElement("li")
        item.dataset.lineId = line.id
        item.dataset.remaining = String(line.remaining)
        item.dataset.quantityFixed = line.quantity_fixed ? "true" : "false"
        const unit = line.unit_identifier ? ` · ${line.unit_identifier}` : ""
        item.textContent = `${line.description} · remaining ${line.remaining}${unit}`
        this.decoratePickerItem(item, { selected: index === 0 })
        this.linkedListTarget.append(item)
      })
    }
    const first = this.linkedListTarget.querySelector("li.is-selected")
    if (first) first.focus()
  }

  selectHighlightedLinked() {
    const selected = this.hasLinkedListTarget && this.linkedListTarget.querySelector("li.is-selected")
    if (!selected) return
    if (this.linkedMode === "receipts") {
      this.runLinkedLookup({ transaction_id: selected.dataset.transactionId })
      return
    }
    if (this.linkedMode !== "lines") return
    const reason = this.hasLinkedReasonFieldTarget ? this.linkedReasonFieldTarget.value : ""
    if (!reason) {
      if (this.hasLinkedFeedbackTarget) this.linkedFeedbackTarget.textContent = "Select a return reason."
      if (this.hasLinkedReasonFieldTarget) this.linkedReasonFieldTarget.focus()
      return
    }
    if (reason === "other" && this.hasLinkedNoteFieldTarget && this.linkedNoteFieldTarget.value.trim() === "") {
      this.toggleHidden(this.hasLinkedNoteWrapTarget && this.linkedNoteWrapTarget, false)
      if (this.hasLinkedFeedbackTarget) this.linkedFeedbackTarget.textContent = "reason note is required"
      this.linkedNoteFieldTarget.focus()
      return
    }
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
    const dueText = due ? due.textContent.trim() : (refund ? "Refund due" : "Amount due")
    if (refund) {
      this.setFieldLabel(cash ? `${dueText}. Refund amount` : `${dueText}. ${name} amount`)
    } else {
      this.setFieldLabel(cash ? `${dueText}. Cash presented` : `${dueText}. ${name} amount`)
    }
    this.toggleReferenceField(type.reference_policy)
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
    if (!this.removeTenderInputTarget.value) return
    this.beginFlight()
    this.removeTenderFormTarget.requestSubmit()
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
      if (this.hasRemoveTenderInputTarget && this.removeTenderInputTarget.value) return
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
    this.openControlOverlay("price_override", "Price override")
  }

  openLineDiscount() {
    this.openControlOverlay("line_discount", "Line discount")
  }

  openTaxClassOverride() {
    this.openControlOverlay("tax_class_override", "Tax Class override")
  }

  openControlOverlay(actionType, title) {
    if (this.inFlight) return
    if (this.modeValue !== "sale_entry") return
    if (this.policyFor(actionType) === "prohibited") {
      this.showFeedback(`${title} is not available.`)
      return
    }
    if (this.selectedReturnLine()) {
      this.showFeedback(`${title} is not available on a return line.`)
      return
    }
    const row = this.selectedRow()
    if (!row || !this.hasControlOverlayTarget) {
      this.showFeedback("Select a sale line first.")
      return
    }

    this.currentControlAction = actionType
    if (this.hasControlTitleTarget) this.controlTitleTarget.textContent = title
    if (this.hasControlLineLabelTarget) this.controlLineLabelTarget.textContent = row.dataset.description || "Selected line"
    this.toggleHidden(this.hasControlPriceWrapTarget && this.controlPriceWrapTarget, actionType !== "price_override")
    this.toggleHidden(this.hasControlDiscountWrapTarget && this.controlDiscountWrapTarget, actionType !== "line_discount")
    this.toggleHidden(this.hasControlTaxWrapTarget && this.controlTaxWrapTarget, actionType !== "tax_class_override")
    if (this.hasControlPriceFieldTarget) this.controlPriceFieldTarget.value = ""
    if (this.hasControlDiscountFieldTarget) this.controlDiscountFieldTarget.value = ""
    if (actionType === "price_override" && this.hasControlPriceFieldTarget) {
      this.controlPriceFieldTarget.value = this.formatCents(row.dataset.sellingCents)
    }
    if (actionType === "line_discount" && this.hasControlDiscountFieldTarget) {
      this.controlDiscountFieldTarget.value = row.dataset.discountBp ? this.formatCents(row.dataset.discountBp) : ""
    }
    if (actionType === "tax_class_override" && this.hasControlTaxFieldTarget && row.dataset.taxClassId) {
      this.controlTaxFieldTarget.value = row.dataset.taxClassId
    }
    this.populateReasons(actionType)
    this.toggleHidden(this.hasControlNoteWrapTarget && this.controlNoteWrapTarget, true)
    if (this.hasControlNoteFieldTarget) this.controlNoteFieldTarget.value = ""
    const needsApprover = this.policyFor(actionType) === "approval_required"
    this.toggleHidden(this.hasControlApproverWrapTarget && this.controlApproverWrapTarget, !needsApprover)
    if (this.hasApproverUsernameTarget) this.approverUsernameTarget.value = ""
    if (this.hasApproverPasswordTarget) this.approverPasswordTarget.value = ""
    const hasExisting = this.lineHasAction(row, actionType)
    if (this.hasControlRemoveTarget) this.controlRemoveTarget.hidden = !hasExisting

    this.showOverlay(this.controlOverlayTarget)
  }

  closeControlOverlay() {
    this.hideOverlay(this.hasControlOverlayTarget && this.controlOverlayTarget)
  }

  openUnlinkedOverlay() {
    if (this.inFlight) return
    if (this.modeValue !== "sale_entry") return
    if (this.policyFor("unlinked_return") === "prohibited") return
    if (!this.hasUnlinkedOverlayTarget) return

    this.resetUnlinkedOverlay()
    this.populateUnlinkedReasons()
    const needsApprover = this.policyFor("unlinked_return") === "approval_required"
    this.toggleHidden(this.hasUnlinkedApproverWrapTarget && this.unlinkedApproverWrapTarget, !needsApprover)
    this.showOverlay(this.unlinkedOverlayTarget, this.hasUnlinkedIdentifierFieldTarget && this.unlinkedIdentifierFieldTarget)
  }

  closeUnlinkedOverlay() {
    this.hideOverlay(this.hasUnlinkedOverlayTarget && this.unlinkedOverlayTarget)
  }

  resetUnlinkedOverlay() {
    this.unlinkedPreviewPayload = null
    if (this.hasUnlinkedFeedbackTarget) this.unlinkedFeedbackTarget.textContent = ""
    if (this.hasUnlinkedIdentifierFieldTarget) this.unlinkedIdentifierFieldTarget.value = ""
    this.toggleHidden(this.hasUnlinkedPreviewTarget && this.unlinkedPreviewTarget, true)
    if (this.hasUnlinkedApplyTarget) this.unlinkedApplyTarget.hidden = true
    if (this.hasUnlinkedNoteFieldTarget) this.unlinkedNoteFieldTarget.value = ""
    this.toggleHidden(this.hasUnlinkedNoteWrapTarget && this.unlinkedNoteWrapTarget, true)
    if (this.hasUnlinkedApproverUsernameTarget) this.unlinkedApproverUsernameTarget.value = ""
    if (this.hasUnlinkedApproverPasswordTarget) this.unlinkedApproverPasswordTarget.value = ""
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

  async resolveUnlinkedIdentifier() {
    if (this.inFlight || !this.hasUnlinkedIdentifierFieldTarget) return
    const identifier = this.unlinkedIdentifierFieldTarget.value.trim()
    if (identifier === "") return
    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
    try {
      const response = await fetch(this.unlinkedLookupUrlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
          "X-CSRF-Token": token || ""
        },
        body: new URLSearchParams({ identifier }).toString()
      })
      const payload = await response.json()
      if (!response.ok) {
        this.showUnlinkedFeedback(payload.error || "merchandise not found")
        this.clearUnlinkedPreviewState()
        return
      }
      this.applyUnlinkedPreview(payload)
    } catch (_error) {
      this.showUnlinkedFeedback("merchandise not found")
      this.clearUnlinkedPreviewState()
    }
  }

  clearUnlinkedPreviewState() {
    this.unlinkedPreviewPayload = null
    this.toggleHidden(this.hasUnlinkedPreviewTarget && this.unlinkedPreviewTarget, true)
    if (this.hasUnlinkedApplyTarget) this.unlinkedApplyTarget.hidden = true
  }

  applyUnlinkedPreview(payload) {
    this.unlinkedPreviewPayload = payload
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
    if (this.hasUnlinkedApplyTarget) this.unlinkedApplyTarget.hidden = false
    if (this.hasUnlinkedQuantityFieldTarget && !fixed) {
      this.unlinkedQuantityFieldTarget.focus()
    } else if (this.hasUnlinkedReasonFieldTarget) {
      this.unlinkedReasonFieldTarget.focus()
    }
  }

  showUnlinkedFeedback(message) {
    if (this.hasUnlinkedFeedbackTarget) this.unlinkedFeedbackTarget.textContent = message
  }

  submitUnlinkedReturn() {
    if (this.inFlight || !this.hasUnlinkedFormTarget) return
    if (!this.unlinkedPreviewPayload) return
    if (this.hasUnlinkedIdentifierInputTarget) {
      this.unlinkedIdentifierInputTarget.value = this.hasUnlinkedIdentifierFieldTarget
        ? this.unlinkedIdentifierFieldTarget.value.trim()
        : ""
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
    if (this.hasUnlinkedApproverUserInputTarget) {
      this.unlinkedApproverUserInputTarget.value = this.hasUnlinkedApproverUsernameTarget
        ? this.unlinkedApproverUsernameTarget.value.trim()
        : ""
    }
    if (this.hasUnlinkedApproverPasswordInputTarget) {
      this.unlinkedApproverPasswordInputTarget.value = this.hasUnlinkedApproverPasswordTarget
        ? this.unlinkedApproverPasswordTarget.value
        : ""
    }
    this.clearOverlayError(this.unlinkedOverlayTarget)
    this.beginFlight()
    this.unlinkedFormTarget.requestSubmit()
  }

  submitControlApply() {
    if (this.inFlight || !this.hasControlFormTarget) return
    this.fillControlForm("apply")
    this.clearOverlayError(this.controlOverlayTarget)
    this.beginFlight()
    this.controlFormTarget.requestSubmit()
  }

  submitControlRemove() {
    if (this.inFlight || !this.hasControlFormTarget) return
    this.fillControlForm("remove")
    this.clearOverlayError(this.controlOverlayTarget)
    this.beginFlight()
    this.controlFormTarget.requestSubmit()
  }

  fillControlForm(operation) {
    this.syncSelectedLine()
    const action = this.currentControlAction
    const applying = operation === "apply"
    if (this.hasControlActionInputTarget) this.controlActionInputTarget.value = action || ""
    if (this.hasControlOperationInputTarget) this.controlOperationInputTarget.value = operation
    if (this.hasControlReasonInputTarget) this.controlReasonInputTarget.value = this.hasControlReasonFieldTarget ? this.controlReasonFieldTarget.value : ""
    if (this.hasControlNoteInputTarget) this.controlNoteInputTarget.value = this.hasControlNoteFieldTarget ? this.controlNoteFieldTarget.value.trim() : ""
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
    if (this.hasControlApproverUserInputTarget) {
      this.controlApproverUserInputTarget.value = this.hasApproverUsernameTarget ? this.approverUsernameTarget.value.trim() : ""
    }
    if (this.hasControlApproverPasswordInputTarget) {
      this.controlApproverPasswordInputTarget.value = this.hasApproverPasswordTarget ? this.approverPasswordTarget.value : ""
    }
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
  }

  overlayOpen() {
    return this.activeOverlayElement() != null
  }

  activeOverlayElement() {
    const overlays = [
      this.hasUnlinkedOverlayTarget && this.unlinkedOverlayTarget,
      this.hasReturnChooserOverlayTarget && this.returnChooserOverlayTarget,
      this.hasLinkedOverlayTarget && this.linkedOverlayTarget,
      this.hasControlOverlayTarget && this.controlOverlayTarget,
      this.hasOtherOverlayTarget && this.otherOverlayTarget,
      this.hasSearchOverlayTarget && this.searchOverlayTarget,
      this.hasVariantOverlayTarget && this.variantOverlayTarget,
      this.hasUnitOverlayTarget && this.unitOverlayTarget,
      this.hasOpenPriceOverlayTarget && this.openPriceOverlayTarget,
      this.hasOverlayTarget && this.overlayTarget
    ]
    return overlays.find((el) => el && !el.hidden) || null
  }

  showOverlay(overlay, initial) {
    if (!overlay) return
    this.clearOverlayError(overlay)
    overlay.hidden = false
    if (this.hasChromeTarget) this.chromeTarget.inert = true
    const target = initial || this.overlayFocusables(overlay)[0]
    if (target) target.focus()
  }

  hideOverlay(overlay) {
    if (!overlay) return
    overlay.hidden = true
    if (this.hasChromeTarget) this.chromeTarget.inert = false
    this.restoreFocus()
  }

  clearOverlayError(overlay) {
    const node = overlay?.querySelector("[data-overlay-error]")
    if (node) node.textContent = ""
  }

  overlayFocusables(overlay) {
    if (!overlay) return []
    return Array.from(overlay.querySelectorAll("input, select, textarea, button, [tabindex]:not([tabindex='-1'])")).filter((el) => {
      if (el.disabled || el.hidden) return false
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
  }

  recoverDialogRejection() {
    this.inFlight = false
    if (this.hasFieldTarget) this.fieldTarget.disabled = false
    if (this.hasReferenceFieldTarget) this.referenceFieldTarget.disabled = false
    this.enableReadyActions()
    if (this.hasControlApproverPasswordInputTarget) this.controlApproverPasswordInputTarget.value = ""
    if (this.hasUnlinkedApproverPasswordInputTarget) this.unlinkedApproverPasswordInputTarget.value = ""
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

  cancelOverlayOpen() {
    return this.hasOverlayTarget && !this.overlayTarget.hidden
  }

  controlOverlayOpen() {
    return this.hasControlOverlayTarget && !this.controlOverlayTarget.hidden
  }

  unlinkedOverlayOpen() {
    return this.hasUnlinkedOverlayTarget && !this.unlinkedOverlayTarget.hidden
  }

  otherOverlayOpen() {
    return this.hasOtherOverlayTarget && !this.otherOverlayTarget.hidden
  }

  searchOverlayOpen() {
    return this.hasSearchOverlayTarget && !this.searchOverlayTarget.hidden
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
    ["unlinkedButton", "returnButton", "quantityButton", "overrideButton", "discountButton", "taxClassButton", "tenderButton", "removeButton", "cancelButton", "retry", "abandonButton", "cashButton", "cardButton", "checkButton", "otherButton"].forEach((name) => {
      this.setActionEnabled(name, false)
    })
  }

  enableTenderIdentityButtons() {
    const hasLines = Boolean(this.element.querySelector(".pos-lines tbody tr"))
    const enabled = hasLines && (this.modeValue === "sale_entry" || this.modeValue === "tender")
    this.setActionEnabled("cashButton", enabled && this.typesForCategory("cash").length > 0)
    this.setActionEnabled("cardButton", enabled && this.typesForCategory("card").length > 0)
    this.setActionEnabled("checkButton", enabled && this.typesForCategory("check").length > 0)
    this.setActionEnabled("otherButton", enabled && this.otherTypes().length > 0)
  }

  enableReadyActions() {
    if (this.modeValue === "sale_entry") {
      const hasSelection = Boolean(this.selectedRow())
      const hasLines = Boolean(this.element.querySelector(".pos-lines tbody tr"))
      const returnLine = this.selectedReturnLine()
      const quantityOk = hasSelection && !this.selectedUnitLine() && !this.selectedQuantityBlocked()
      this.setActionEnabled("unlinkedButton", this.policyFor("unlinked_return") !== "prohibited")
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
    this.onWorkspacePointerDown = () => this.requestFunctionKeyLock()
    window.addEventListener("keydown", this.onWindowKeydown, true)
    window.addEventListener("keyup", this.onWindowKeyup, true)
    this.element.addEventListener("pointerdown", this.onWorkspacePointerDown)
    this.requestFunctionKeyLock()
  }

  unbindFunctionKeyCapture() {
    if (!this.functionKeyListenersBound) return
    this.functionKeyListenersBound = false
    window.removeEventListener("keydown", this.onWindowKeydown, true)
    window.removeEventListener("keyup", this.onWindowKeyup, true)
    this.element.removeEventListener("pointerdown", this.onWorkspacePointerDown)
    this.releaseFunctionKeyLock()
  }

  requestFunctionKeyLock() {
    const keyboard = navigator.keyboard
    if (!keyboard || typeof keyboard.lock !== "function") return
    keyboard.lock(["F1", "F2", "F3", "F4", "F6", "F7", "F8", "F9", "F10"]).catch(() => {})
  }

  releaseFunctionKeyLock() {
    const keyboard = navigator.keyboard
    if (!keyboard || typeof keyboard.unlock !== "function") return
    keyboard.unlock()
  }

  functionKey(event) {
    if (typeof event.key === "string" && /^F\d{1,2}$/i.test(event.key)) return event.key.toUpperCase()
    if (typeof event.code === "string" && /^F\d{1,2}$/i.test(event.code)) return event.code.toUpperCase()
    return null
  }

  claimedFunctionKey(key) {
    return key === "F1" || key === "F2" || key === "F3" || key === "F4" || key === "F6" || key === "F7" || key === "F8" || key === "F9" || key === "F10"
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
