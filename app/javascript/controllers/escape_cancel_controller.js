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

    const selected = this.element.querySelector("[data-row-selection-target='row'].is-selected")
    if (selected) {
      event.preventDefault()
      selected.classList.remove("is-selected")
      selected.setAttribute("aria-selected", "false")
      this.element.querySelector("[data-focus-restore-target='lookup']")?.focus()
      return
    }

    const dirtyForm = document.activeElement?.closest("form[data-dirty='true']") || this.element.querySelector("form[data-dirty='true']")
    if (!dirtyForm) return
    event.preventDefault()
    dirtyForm.reset()
    dirtyForm.dispatchEvent(new CustomEvent("ops:dirty-cancel", { bubbles: true, detail: { form: dirtyForm } }))
  }
}
