import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "field",
    "overlay",
    "completeForm",
    "tenderForm",
    "merchandiseForm",
    "quantityForm",
    "removeForm",
    "cancelForm",
    "identifierInput",
    "quantityInput",
    "presentedInput",
    "quantityLineInput",
    "removeLineInput",
    "dontCancel"
  ]

  static values = {
    mode: String,
    autoComplete: Boolean
  }

  connect() {
    this.inFlight = false
    if (this.autoCompleteValue) {
      this.submitComplete()
      return
    }
    this.restoreFocus()
  }

  onKeydown(event) {
    if (this.overlayOpen()) {
      event.preventDefault()
      if (event.key === "Escape") this.closeOverlay()
      if (event.key === "F9") this.confirmCancel()
      return
    }

    if (this.inFlight || this.modeValue === "completion_pending") {
      if (event.key === "Enter" || event.key === "F9") event.preventDefault()
      return
    }

    if (this.modeValue === "completion_failed") {
      if (event.key === "Enter") {
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
    if (this.modeValue !== "sale_entry") return

    if (event.key === "*") {
      event.preventDefault()
      this.enterQuantity()
    } else if (event.key === "+") {
      event.preventDefault()
      this.enterTender()
    } else if (event.key === "Delete") {
      event.preventDefault()
      this.removeSelected()
    } else if (event.key === "ArrowUp" || event.key === "ArrowDown") {
      event.preventDefault()
      this.moveSelection(event.key === "ArrowUp" ? -1 : 1)
    }
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
    this.beginFlight()
    this.tenderFormTarget.requestSubmit()
  }

  submitComplete() {
    if (this.inFlight) return
    this.beginFlight()
    this.completeFormTarget.requestSubmit()
  }

  enterQuantity() {
    if (this.modeValue !== "sale_entry" || !this.selectedRow()) return
    this.modeValue = "quantity"
    this.element.dataset.registerWorkspaceModeValue = "quantity"
    const mode = this.element.querySelector(".pos-command__mode")
    if (mode) mode.textContent = "QUANTITY"
    this.fieldTarget.disabled = false
    this.fieldTarget.value = ""
    this.fieldTarget.focus()
  }

  enterTender() {
    if (this.modeValue !== "sale_entry") return
    if (!this.element.querySelector(".pos-lines tbody tr")) return
    this.modeValue = "tender"
    this.element.dataset.registerWorkspaceModeValue = "tender"
    const mode = this.element.querySelector(".pos-command__mode")
    if (mode) mode.textContent = "CASH TENDER"
    this.fieldTarget.disabled = false
    this.fieldTarget.value = ""
    this.fieldTarget.focus()
  }

  removeSelected() {
    if (this.modeValue !== "sale_entry" || !this.selectedRow()) return
    this.syncSelectedLine()
    this.beginFlight()
    this.removeFormTarget.requestSubmit()
  }

  escape() {
    if (this.modeValue === "quantity" || this.modeValue === "tender") {
      this.modeValue = "sale_entry"
      this.element.dataset.registerWorkspaceModeValue = "sale_entry"
      const mode = this.element.querySelector(".pos-command__mode")
      if (mode) mode.textContent = "SALE ENTRY"
      this.fieldTarget.value = ""
      this.fieldTarget.focus()
    }
  }

  openOverlay() {
    const cancel = this.element.querySelector(".pos-actions .btn--danger")
    if (!cancel || cancel.disabled) return
    this.overlayTarget.hidden = false
    this.dontCancelTarget.focus()
  }

  closeOverlay() {
    this.overlayTarget.hidden = true
    this.restoreFocus()
  }

  confirmCancel() {
    if (this.overlayTarget.hidden) return
    this.beginFlight()
    this.cancelFormTarget.requestSubmit()
  }

  moveSelection(delta) {
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
  }

  overlayOpen() {
    return this.hasOverlayTarget && !this.overlayTarget.hidden
  }

  selectedRow() {
    return this.element.querySelector(".pos-lines tbody tr.is-selected")
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
  }

  restoreFocus() {
    if (!this.hasFieldTarget) return
    if (this.modeValue === "completion_failed") {
      const retry = this.element.querySelector("[data-register-workspace-target='retry']")
      if (retry) retry.focus()
      return
    }
    if (this.fieldTarget.disabled) return
    this.fieldTarget.focus()
  }
}
