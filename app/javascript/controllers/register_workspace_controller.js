import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "field",
    "fieldLabel",
    "modeLabel",
    "chrome",
    "overlay",
    "completeForm",
    "tenderForm",
    "removeTenderForm",
    "merchandiseForm",
    "quantityForm",
    "removeForm",
    "cancelForm",
    "identifierInput",
    "quantityInput",
    "presentedInput",
    "tenderTypeInput",
    "referenceInput",
    "referenceField",
    "removeTenderInput",
    "quantityLineInput",
    "removeLineInput",
    "dontCancel",
    "confirmCancel",
    "retry",
    "abandonButton",
    "quantityButton",
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
    tenderTypeIds: String,
    tenderTypeNames: String,
    tenderTypeCash: String
  }

  connect() {
    this.inFlight = false
    if (this.autoCompleteValue) {
      this.submitComplete()
      return
    }
    this.enableReadyActions()
    this.restoreFocus()
  }

  onKeydown(event) {
    if (this.overlayOpen()) {
      if (event.key === "Tab") {
        this.trapOverlayTab(event)
        return
      }
      event.preventDefault()
      if (event.key === "Escape") this.closeOverlay()
      if (event.key === "F9") this.confirmCancel()
      return
    }

    if (this.inFlight || this.modeValue === "completion_pending") {
      if (event.key === "Enter" && this.isActionableControl(event.target)) return
      if (event.key === "Enter" || event.key === "F9") event.preventDefault()
      return
    }

    if (this.modeValue === "completion_failed") {
      if (event.key === "Enter") {
        if (this.isActionableControl(event.target)) return
        event.preventDefault()
        this.submitComplete()
      }
      if (event.key === "F9") {
        event.preventDefault()
        this.openOverlay()
      }
      if (event.key === "Escape") event.preventDefault()
      return
    }

    if (event.key === "Enter") {
      if (this.isActionableControl(event.target)) return
      event.preventDefault()
      this.submitMode()
      return
    }
    if (event.key === "Escape") {
      event.preventDefault()
      this.escape()
      return
    }
    if (event.key === "F9") {
      event.preventDefault()
      this.openOverlay()
      return
    }
    if (this.modeValue !== "sale_entry" && this.modeValue !== "tender") return

    if (this.modeValue === "tender") {
      if (event.key === "F2") {
        event.preventDefault()
        this.cycleTenderType()
      } else if (event.key === "F8") {
        event.preventDefault()
        this.removeLastTender()
      }
      return
    }

    if (event.key === "*") {
      event.preventDefault()
      this.enterQuantity()
    } else if (event.key === "+") {
      event.preventDefault()
      this.enterTender()
    } else if (event.key === "F8") {
      event.preventDefault()
      this.removeSelected()
    } else if (event.key === "ArrowUp" || event.key === "ArrowDown") {
      event.preventDefault()
      this.moveSelection(event.key === "ArrowUp" ? -1 : 1)
    }
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
    if (this.hasReferenceFieldTarget && this.hasReferenceInputTarget) {
      this.referenceInputTarget.value = this.referenceFieldTarget.value.trim()
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
    if (this.selectedUnitLine()) return
    const row = this.selectedRow()
    this.setMode("quantity", "QUANTITY")
    const description = row.dataset.description || "Selected line"
    const quantity = row.dataset.quantity || ""
    this.setFieldLabel(`${description} · Current quantity ${quantity}`)
    this.fieldTarget.disabled = false
    this.fieldTarget.inputMode = "numeric"
    this.fieldTarget.value = quantity
    this.setActionEnabled("quantityButton", false)
    this.setActionEnabled("tenderButton", false)
    this.setActionEnabled("removeButton", false)
    this.fieldTarget.focus()
    this.fieldTarget.select()
  }

  enterTender() {
    if (this.inFlight) return
    if (this.modeValue !== "sale_entry") return
    if (!this.element.querySelector(".pos-lines tbody tr")) return
    this.setMode("tender", "CASH TENDER")
    this.selectTenderType(this.cashTenderIndex())
    const due = this.element.querySelector(".pos-totals__due")
    const dueText = due ? due.textContent.trim() : "Amount due"
    this.setFieldLabel(`${dueText}. Cash presented`)
    this.fieldTarget.disabled = false
    this.fieldTarget.inputMode = "decimal"
    this.fieldTarget.value = ""
    this.setActionEnabled("quantityButton", false)
    this.setActionEnabled("tenderButton", false)
    this.setActionEnabled("removeButton", false)
    this.fieldTarget.focus()
  }

  removeSelected() {
    if (this.inFlight) return
    if (this.modeValue !== "sale_entry" || !this.selectedRow()) return
    this.syncSelectedLine()
    this.beginFlight()
    this.removeFormTarget.requestSubmit()
  }

  cycleTenderType() {
    const ids = this.tenderTypeList()
    if (ids.length === 0) return
    const current = this.hasTenderTypeInputTarget ? this.tenderTypeInputTarget.value : ids[0]
    const index = Math.max(0, ids.indexOf(current))
    this.selectTenderType((index + 1) % ids.length)
  }

  selectTenderType(index) {
    const ids = this.tenderTypeList()
    const names = this.tenderTypeNameList()
    const cashFlags = this.tenderTypeCashList()
    if (ids.length === 0) return
    const safeIndex = ((index % ids.length) + ids.length) % ids.length
    if (this.hasTenderTypeInputTarget) this.tenderTypeInputTarget.value = ids[safeIndex]
    const cash = cashFlags[safeIndex] === "1"
    const name = names[safeIndex] || (cash ? "Cash" : "Tender")
    this.setMode("tender", cash ? "CASH TENDER" : "TENDER")
    const due = this.element.querySelector(".pos-totals__due")
    const dueText = due ? due.textContent.trim() : "Amount due"
    this.setFieldLabel(cash ? `${dueText}. Cash presented` : `${dueText}. ${name} amount`)
  }

  cashTenderIndex() {
    const cashFlags = this.tenderTypeCashList()
    const index = cashFlags.indexOf("1")
    return index >= 0 ? index : 0
  }

  tenderTypeList() {
    return (this.tenderTypeIdsValue || "").split(",").filter(Boolean)
  }

  tenderTypeNameList() {
    return (this.tenderTypeNamesValue || "").split("|")
  }

  tenderTypeCashList() {
    return (this.tenderTypeCashValue || "").split(",")
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
      this.enableReadyActions()
      this.fieldTarget.focus()
    }
  }

  openOverlay() {
    if (this.inFlight) return
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
    return this.hasOverlayTarget && !this.overlayTarget.hidden
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
  }

  beginFlight() {
    this.inFlight = true
    if (this.hasFieldTarget) this.fieldTarget.disabled = true
    this.disableMutationControls()
  }

  disableMutationControls() {
    ["quantityButton", "tenderButton", "removeButton", "cancelButton", "retry", "abandonButton"].forEach((name) => {
      this.setActionEnabled(name, false)
    })
  }

  enableReadyActions() {
    if (this.modeValue === "sale_entry") {
      const hasSelection = Boolean(this.selectedRow())
      const hasLines = Boolean(this.element.querySelector(".pos-lines tbody tr"))
      this.setActionEnabled("quantityButton", hasSelection && !this.selectedUnitLine())
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
}
