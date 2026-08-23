import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  keydown(event) {
    if (event.key !== "Escape") return

    this.cancel(event)
  }

  cancel(event) {
    const dialog = this.element.querySelector("dialog[open]")
    if (dialog) {
      event.preventDefault()
      dialog.close()
      return
    }

    const help = this.element.querySelector("[data-ops-shortcuts-target='help']:not([hidden])")
    if (help) {
      event.preventDefault()
      this.element.querySelector("[data-action~='ops-shortcuts#toggleHelp']")?.click()
      return
    }

    if (this.element.dataset.opsWorkspace === "location") {
      return
    }

    const dirtyForm = this.findDirtyDraftForm()
    if (dirtyForm) {
      event.preventDefault()
      this.resetDirtyForm(dirtyForm)
      return
    }

    const selected = this.element.querySelector("[data-row-selection-target='row'].is-selected")
    if (selected) {
      event.preventDefault()
      selected.classList.remove("is-selected")
      selected.setAttribute("aria-selected", "false")
      this.element.querySelector("[data-focus-restore-target='lookup']")?.focus()
    }
  }

  findDirtyDraftForm() {
    const activeForm = document.activeElement?.closest("form[data-dirty='true']")
    if (activeForm) return activeForm

    const selected = this.element.querySelector("[data-row-selection-target='row'].is-selected")
    if (selected) {
      const rowDirty = selected.querySelector("form[data-dirty='true']")
      if (rowDirty) return rowDirty
    }

    return this.element.querySelector("form[data-dirty='true']")
  }

  resetDirtyForm(form) {
    form.reset()
    form.dispatchEvent(new CustomEvent("ops:dirty-cancel", { bubbles: true, detail: { form } }))
    const row = form.closest("[data-row-selection-target='row']")
    if (row?.classList.contains("is-selected")) {
      row.classList.remove("is-selected")
      row.setAttribute("aria-selected", "false")
    }
    this.element.querySelector("[data-focus-restore-target='lookup']")?.focus()
  }
}
