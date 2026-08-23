import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { selector: String }

  connect() {
    requestAnimationFrame(() => {
      const target = this.hasSelectorValue
        ? document.querySelector(this.selectorValue)
        : this.element.querySelector("a, button, [tabindex='-1']")
      target?.focus({ preventScroll: true })
    })
  }
}
