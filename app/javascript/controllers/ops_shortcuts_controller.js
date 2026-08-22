import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "help", "helpButton" ]

  keydown(event) {
    if (event.defaultPrevented) return
    if (event.key === "/" && !this.editable(event.target)) {
      event.preventDefault()
      this.focusLookup()
    } else if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "s") {
      event.preventDefault()
      this.save()
    } else if ((event.ctrlKey || event.metaKey) && event.key === "Enter") {
      event.preventDefault()
      this.primary()
    }
  }

  focusLookup() {
    const lookup = this.element.querySelector("[data-focus-restore-target='lookup']")
    lookup?.focus()
    lookup?.select?.()
  }

  save() {
    const activeForm = document.activeElement?.closest("form[data-dirty-track]")
    const save = activeForm?.querySelector("[data-ops-save]") || this.element.querySelector("[data-ops-save]")
    save?.click()
  }

  primary() {
    this.element.querySelector("[data-ops-primary]")?.click()
  }

  toggleHelp() {
    const opening = !this.helpTarget.hidden
    this.helpTarget.hidden = opening
    this.helpButtonTarget.setAttribute("aria-expanded", (!opening).toString())
    if (!opening) this.helpTarget.querySelector("button")?.focus()
    else this.helpButtonTarget.focus()
  }

  editable(target) {
    return target.matches("input, textarea, select, [contenteditable='true']")
  }
}
