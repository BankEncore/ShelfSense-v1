import { Controller } from "@hotwired/stimulus"

// Presents consequential server-backed forms in a native modal dialog. The browser
// supplies modal focus trapping; this controller owns initial focus and restores
// focus to the visible trigger after Escape or Cancel.
export default class extends Controller {
  static targets = [ "dialog", "initialFocus", "trigger" ]
  static values = { open: Boolean }

  connect() {
    if (this.openValue) this.show()
  }

  open(event) {
    event.preventDefault()
    this.show()
  }

  show() {
    this.dialogTarget.showModal()
    requestAnimationFrame(() => this.initialFocusTarget.focus())
  }

  close(event) {
    event.preventDefault()
    this.dialogTarget.close()
  }

  restoreFocus() {
    this.triggerTarget.focus()
  }
}
