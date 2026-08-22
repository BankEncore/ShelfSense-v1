import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "lookup" ]

  connect() {
    requestAnimationFrame(() => this.focus())
  }

  focus() {
    if (!this.hasLookupTarget || this.lookupTarget.disabled || this.lookupTarget.closest("[hidden]")) return
    if (this.element.querySelector(":popover-open, dialog[open]")) return

    this.lookupTarget.focus({ preventScroll: true })
    if (typeof this.lookupTarget.select === "function") this.lookupTarget.select()
  }
}
