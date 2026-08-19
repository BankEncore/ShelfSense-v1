import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "field",
    "fieldLabel",
    "modeLabel",
    "chrome",
    "overlay",
    "controlOverlay",
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
    settlement: String,
    refundRemaining: Number
  }

  connect() {
    this.inFlight = false
    this.bindFunctionKeyCapture()
    if (this.hasControlReasonFieldTarget) {
      this.controlReasonFieldTarget.addEventListener("change", () => {
        this.toggleHidden(this.hasControlNoteWrapTarget && this.controlNoteWrapTarget, this.controlReasonFieldTarget.value !== "other")
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

    if (this.controlOverlayOpen()) {
      this.onControlOverlayKeydown(event, key)
      return
    }

    if (this.cancelOverlayOpen()) {
      if (key === "Tab") {
        this.trapOverlayTab(event)
        return
      }
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

    if (this.modeValue === "tender") {
      if (key === "F2") {
        event.preventDefault()
        this.cycleTenderType()
      } else if (key === "F8") {
        event.preventDefault()
        this.removeLastTender()
      }
      return
    }

    if (key === "*") {
      event.preventDefault()
      this.enterQuantity()
    } else if (key === "+") {
      event.preventDefault()
      this.enterTender()
    } else if (key === "F5") {
      event.preventDefault()
      this.openPriceOverride()
    } else if (key === "F6") {
      event.preventDefault()
      this.openLineDiscount()
    } else if (key === "F7") {
      event.preventDefault()
      this.openTaxClassOverride()
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
    if (key === "Tab") {
      this.trapControlOverlayTab(event)
      return
    }
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
      return
    }
    if (this.hasApproverPasswordTarget && target === this.approverPasswordTarget) {
      event.preventDefault()
      if (this.approverPasswordTarget.value.trim() !== "") this.submitControlApply()
      return
    }
    if (this.isActionableControl(target)) return
    event.preventDefault()
  }

  onSubmitEnd(event) {
    if (event.detail?.success) return
    if (!this.inFlight) return
    this.recoverFromTransportFailure(event.target)
  }

  submitMode() {
    if (this.inFlight) return
    if (this.modeValue === "sale_entry") this.submitMerchandise()
    else if (this.modeValue === "quantity") this.submitQuantity()
    else if (this.modeValue === "tender") this.submitTender()
  }

  submitMerchandise() {
    const value = this.fieldTarget.value.trim()
    if (!value) return
    this.identifierInputTarget.value = value
    this.beginFlight()
    this.merchandiseFormTarget.requestSubmit()
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
    if (!this.element.querySelector(".pos-lines tbody tr")) return
    if (this.settlementValue === "none") {
      this.submitComplete()
      return
    }
    const refund = this.settlementValue === "refund"
    this.setMode("tender", refund ? "REFUND" : "CASH TENDER")
    this.selectTenderType(this.cashTenderIndex())
    const due = this.element.querySelector(".pos-totals__due")
    const dueText = due ? due.textContent.trim() : (refund ? "Refund due" : "Amount due")
    this.setFieldLabel(refund ? `${dueText}. Refund amount` : `${dueText}. Cash presented`)
    this.fieldTarget.disabled = false
    this.fieldTarget.inputMode = "decimal"
    this.fieldTarget.value = refund ? this.formatCents(this.refundRemainingValue) : ""
    this.setActionEnabled("quantityButton", false)
    this.setActionEnabled("overrideButton", false)
    this.setActionEnabled("discountButton", false)
    this.setActionEnabled("taxClassButton", false)
    this.setActionEnabled("tenderButton", false)
    this.setActionEnabled("removeButton", false)
    this.fieldTarget.focus()
    if (refund) this.fieldTarget.select()
  }

  removeSelected() {
    if (this.inFlight) return
    if (this.modeValue !== "sale_entry" || !this.selectedRow()) return
    this.syncSelectedLine()
    this.beginFlight()
    this.removeFormTarget.requestSubmit()
  }

  cycleTenderType() {
    const types = this.cashierTenderTypes()
    if (types.length === 0) return
    const current = this.hasTenderTypeInputTarget ? this.tenderTypeInputTarget.value : types[0].id
    const index = Math.max(0, types.findIndex((type) => type.id === current))
    this.selectTenderType((index + 1) % types.length)
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
    this.overlayTarget.hidden = false
    if (this.hasChromeTarget) this.chromeTarget.inert = true
    this.dontCancelTarget.focus()
  }

  closeOverlay() {
    this.overlayTarget.hidden = true
    if (this.hasChromeTarget) this.chromeTarget.inert = false
    this.restoreFocus()
  }

  openPriceOverride() {
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
    if (this.policyFor(actionType) === "prohibited") return
    if (this.selectedReturnLine()) return
    const row = this.selectedRow()
    if (!row || !this.hasControlOverlayTarget) return

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

    this.controlOverlayTarget.hidden = false
    if (this.hasChromeTarget) this.chromeTarget.inert = true
    this.focusControlOverlay()
  }

  closeControlOverlay() {
    if (!this.hasControlOverlayTarget) return
    this.controlOverlayTarget.hidden = true
    if (this.hasChromeTarget) this.chromeTarget.inert = false
    this.restoreFocus()
  }

  submitControlApply() {
    if (this.inFlight || !this.hasControlFormTarget) return
    this.fillControlForm("apply")
    this.beginFlight()
    this.controlFormTarget.requestSubmit()
  }

  submitControlRemove() {
    if (this.inFlight || !this.hasControlFormTarget) return
    this.fillControlForm("remove")
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
    return this.cancelOverlayOpen() || this.controlOverlayOpen()
  }

  cancelOverlayOpen() {
    return this.hasOverlayTarget && !this.overlayTarget.hidden
  }

  controlOverlayOpen() {
    return this.hasControlOverlayTarget && !this.controlOverlayTarget.hidden
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
  }

  beginFlight() {
    this.inFlight = true
    this.disableMutationControls()
    if (this.hasReferenceFieldTarget) this.referenceFieldTarget.disabled = true
    if (this.hasFieldTarget) this.fieldTarget.disabled = true
  }

  disableMutationControls() {
    ["quantityButton", "overrideButton", "discountButton", "taxClassButton", "tenderButton", "removeButton", "cancelButton", "retry", "abandonButton"].forEach((name) => {
      this.setActionEnabled(name, false)
    })
  }

  enableReadyActions() {
    if (this.modeValue === "sale_entry") {
      const hasSelection = Boolean(this.selectedRow())
      const hasLines = Boolean(this.element.querySelector(".pos-lines tbody tr"))
      const returnLine = this.selectedReturnLine()
      const quantityOk = hasSelection && !this.selectedUnitLine() && !this.selectedQuantityBlocked()
      this.setActionEnabled("quantityButton", quantityOk)
      this.setActionEnabled("overrideButton", hasSelection && !returnLine && this.policyFor("price_override") !== "prohibited")
      this.setActionEnabled("discountButton", hasSelection && !returnLine && this.policyFor("line_discount") !== "prohibited")
      this.setActionEnabled("taxClassButton", hasSelection && !returnLine && this.policyFor("tax_class_override") !== "prohibited")
      this.setActionEnabled("tenderButton", hasLines)
      this.setActionEnabled("removeButton", hasSelection)
      this.setActionEnabled("cancelButton", hasLines)
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

  trapOverlayTab(event) {
    const controls = this.overlayControls()
    if (controls.length === 0) return
    event.preventDefault()
    const current = controls.indexOf(document.activeElement)
    let next = current
    if (event.shiftKey) {
      next = current <= 0 ? controls.length - 1 : current - 1
    } else {
      next = current === controls.length - 1 || current < 0 ? 0 : current + 1
    }
    controls[next].focus()
  }

  overlayControls() {
    return [this.dontCancelTarget, this.confirmCancelTarget].filter(Boolean)
  }

  trapControlOverlayTab(event) {
    const controls = this.controlOverlayControls()
    if (controls.length === 0) return
    event.preventDefault()
    const current = controls.indexOf(document.activeElement)
    let next = current
    if (event.shiftKey) {
      next = current <= 0 ? controls.length - 1 : current - 1
    } else {
      next = current === controls.length - 1 || current < 0 ? 0 : current + 1
    }
    controls[next].focus()
  }

  controlOverlayControls() {
    if (!this.hasControlOverlayTarget) return []
    return Array.from(this.controlOverlayTarget.querySelectorAll("input, select, button")).filter((el) => {
      if (el.disabled || el.hidden) return false
      return !el.closest("[hidden]")
    })
  }

  focusControlOverlay() {
    const first = this.controlOverlayControls()[0]
    if (first) first.focus()
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
    keyboard.lock(["F2", "F5", "F6", "F7", "F8", "F9"]).catch(() => {})
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
    return key === "F2" || key === "F5" || key === "F6" || key === "F7" || key === "F8" || key === "F9"
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
    if (!row || row.dataset.direction === "return") return false
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
