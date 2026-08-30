import { Controller } from "@hotwired/stimulus"

// Blocking confirmation overlay for Register shell inquiry surfaces (e.g. O19).
// Opens/closes [data-register-blocking-overlay] so the shell can inert header/status
// and suppress F10, while this controller owns focus trap, Escape, and restoration.
export default class extends Controller {
  static targets = [ "overlay", "launcher", "initialFocus", "detail" ]

  connect() {
    this.returnFocusElement = null
    this.onWindowKeydown = (event) => this.onKeydown(event)
  }

  disconnect() {
    window.removeEventListener("keydown", this.onWindowKeydown, true)
    if (this.hasDetailTarget) this.detailTarget.inert = false
  }

  open(event) {
    if (event) event.preventDefault()
    if (!this.hasOverlayTarget || !this.overlayTarget.hidden) return

    this.returnFocusElement = this.hasLauncherTarget ? this.launcherTarget : document.activeElement
    this.overlayTarget.hidden = false
    this.overlayTarget.setAttribute("aria-modal", "true")
    if (this.hasDetailTarget) this.detailTarget.inert = true

    window.addEventListener("keydown", this.onWindowKeydown, true)
    requestAnimationFrame(() => this.focusEntry())
  }

  close(event) {
    if (event) event.preventDefault()
    this.hideOverlay({ restore: true })
  }

  onKeydown(event) {
    if (!this.hasOverlayTarget || this.overlayTarget.hidden) return

    const key = event.key
    if (key === "Escape") {
      this.claim(event)
      this.hideOverlay({ restore: true })
      return
    }
    if (key === "Tab") {
      this.trapTab(event)
      return
    }
    if (typeof key === "string" && /^F\d{1,2}$/i.test(key)) {
      this.claim(event)
    }
  }

  hideOverlay({ restore }) {
    if (!this.hasOverlayTarget) return
    if (this.overlayTarget.hidden) {
      window.removeEventListener("keydown", this.onWindowKeydown, true)
      return
    }

    this.overlayTarget.hidden = true
    if (this.hasDetailTarget) this.detailTarget.inert = false
    window.removeEventListener("keydown", this.onWindowKeydown, true)

    if (restore) this.restoreFocus()
  }

  focusEntry() {
    const candidate = this.hasInitialFocusTarget
      ? this.initialFocusTarget
      : this.focusables()[0]
    if (candidate && typeof candidate.focus === "function") candidate.focus()
  }

  trapTab(event) {
    const controls = this.focusables()
    if (controls.length === 0) return
    event.preventDefault()
    const current = controls.indexOf(document.activeElement)
    let next
    if (event.shiftKey) {
      next = current <= 0 ? controls.length - 1 : current - 1
    } else {
      next = current === controls.length - 1 || current < 0 ? 0 : current + 1
    }
    controls[next].focus()
  }

  focusables() {
    if (!this.hasOverlayTarget) return []
    return Array.from(
      this.overlayTarget.querySelectorAll(
        "a[href], button, input, select, textarea, [tabindex]:not([tabindex='-1'])"
      )
    ).filter((el) => {
      if (el.disabled || el.hidden) return false
      return !el.closest("[hidden]")
    })
  }

  restoreFocus() {
    const candidate = this.returnFocusElement
    this.returnFocusElement = null
    if (candidate && candidate.isConnected && typeof candidate.focus === "function") {
      candidate.focus()
    }
  }

  claim(event) {
    event.preventDefault()
    if (typeof event.stopImmediatePropagation === "function") event.stopImmediatePropagation()
  }
}
