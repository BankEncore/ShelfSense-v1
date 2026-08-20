import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["header", "footer", "headerMode", "footerMode"]

  connect() {
    this.sync()
  }

  sync() {
    if (this.hasHeaderTarget) this.headerTarget.disabled = this.selectedMode(this.headerModeTargets) !== "custom"
    if (this.hasFooterTarget) this.footerTarget.disabled = this.selectedMode(this.footerModeTargets) !== "custom"
  }

  selectedMode(targets) {
    const checked = targets.find((input) => input.checked)
    return checked ? checked.value : ""
  }
}
