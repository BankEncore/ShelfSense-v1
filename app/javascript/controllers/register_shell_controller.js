import { Controller } from "@hotwired/stimulus"

const WORKSPACE_LOCK_KEYS = [ "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10" ]
const MENU_LOCK_KEYS = [ "F10" ]

export default class extends Controller {
  static targets = [ "background", "menu", "launcher", "close", "announce", "group", "proxyItem" ]

  connect() {
    this.returnFocusElement = null
    this.onWindowKeydown = (event) => this.onKeydown(event)
    this.onWindowKeyup = (event) => this.onKeyup(event)
    this.onPointerOrFocus = () => this.requestFunctionKeyLock()
    this.onVisibilityChange = () => this.onVisibility()
    this.onBeforeRender = () => this.closeMenuOnRender()
    window.addEventListener("keydown", this.onWindowKeydown, true)
    window.addEventListener("keyup", this.onWindowKeyup, true)
    document.addEventListener("pointerdown", this.onPointerOrFocus, true)
    document.addEventListener("focusin", this.onPointerOrFocus, true)
    document.addEventListener("visibilitychange", this.onVisibilityChange)
    document.addEventListener("turbo:before-render", this.onBeforeRender)
    this.syncContextualItems()
    this.requestFunctionKeyLock()
  }

  disconnect() {
    window.removeEventListener("keydown", this.onWindowKeydown, true)
    window.removeEventListener("keyup", this.onWindowKeyup, true)
    document.removeEventListener("pointerdown", this.onPointerOrFocus, true)
    document.removeEventListener("focusin", this.onPointerOrFocus, true)
    document.removeEventListener("visibilitychange", this.onVisibilityChange)
    document.removeEventListener("turbo:before-render", this.onBeforeRender)
    this.releaseFunctionKeyLock()
  }

  toggleMenu(event) {
    if (event) event.preventDefault()
    if (this.menuIsOpen()) {
      this.closeMenu()
      return
    }
    this.requestMenuOpen()
  }

  closeMenu(event) {
    if (event) event.preventDefault()
    if (!this.menuIsOpen()) return
    this.menuTarget.hidden = true
    this.backgroundTarget.inert = false
    this.launcherTarget.setAttribute("aria-expanded", "false")
    this.restoreFocus()
  }

  activateProxy(event) {
    const name = event.params.proxy
    const target = this.liveProxy(name)
    if (!target) return
    this.closeMenuWithoutRestore()
    target.click()
  }

  onKeydown(event) {
    this.requestFunctionKeyLock()
    const key = this.functionKey(event) || event.key
    if (this.menuIsOpen()) {
      if (key === "Tab") {
        this.trapTab(event)
        this.claim(event)
        return
      }
      if (key === "Escape" || key === "F10") {
        this.closeMenu()
        this.claim(event)
        return
      }
      this.claim(event)
      return
    }

    if (key !== "F10") return
    this.claim(event)
    this.requestMenuOpen()
  }

  onKeyup(event) {
    const key = this.functionKey(event)
    if (!key) return
    if (this.menuIsOpen() || key === "F10") this.claim(event)
  }

  onVisibility() {
    if (document.visibilityState === "hidden") {
      this.releaseFunctionKeyLock()
      return
    }
    this.requestFunctionKeyLock()
  }

  closeMenuOnRender() {
    if (!this.menuIsOpen()) return
    this.closeMenu()
  }

  requestMenuOpen() {
    if (this.blockingOverlay()) {
      this.announce("Finish or cancel the current dialog before opening the Register Menu.")
      return
    }

    this.openMenu()
  }

  openMenu() {
    this.syncContextualItems()
    this.returnFocusElement = document.activeElement
    this.menuTarget.hidden = false
    this.backgroundTarget.inert = true
    this.launcherTarget.setAttribute("aria-expanded", "true")
    const first = this.firstMenuItem()
    if (first) first.focus()
  }

  menuIsOpen() {
    return this.hasMenuTarget && !this.menuTarget.hidden
  }

  blockingOverlay() {
    return this.backgroundTarget.querySelector("[data-register-blocking-overlay]:not([hidden])")
  }

  syncContextualItems() {
    this.proxyItemTargets.forEach((item) => {
      const name = item.dataset.registerShellProxyParam
      const target = this.liveProxy(name)
      const available = Boolean(target && !target.disabled)
      const row = item.closest("li")
      item.hidden = !available
      if (row) row.hidden = !available
    })
    this.groupTargets.forEach((group) => {
      const visible = Array.from(group.querySelectorAll("li")).some((row) => !row.hidden)
      group.hidden = !visible
    })
  }

  liveProxy(name) {
    if (!name) return null
    const node = this.backgroundTarget.querySelector(`[data-register-shell-proxy="${name}"]`)
    if (!node) return null
    if (node.matches("form")) return node.querySelector("button, input[type=submit]")
    return node
  }

  firstMenuItem() {
    return this.focusables(this.menuTarget).find((el) => el !== this.closeTarget) || this.closeTarget
  }

  focusables(root) {
    return Array.from(root.querySelectorAll("a[href], button, input, select, textarea, [tabindex]:not([tabindex='-1'])")).filter((el) => {
      if (el.disabled || el.hidden) return false
      return !el.closest("[hidden]")
    })
  }

  trapTab(event) {
    const controls = this.focusables(this.menuTarget)
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

  restoreFocus() {
    const candidate = this.returnFocusElement
    this.returnFocusElement = null
    if (candidate && candidate.isConnected && !candidate.closest("[inert]")) {
      candidate.focus()
      return
    }
    if (this.hasLauncherTarget) this.launcherTarget.focus()
  }

  closeMenuWithoutRestore() {
    if (!this.menuIsOpen()) return
    this.menuTarget.hidden = true
    this.backgroundTarget.inert = false
    this.launcherTarget.setAttribute("aria-expanded", "false")
    this.returnFocusElement = null
  }

  announce(message) {
    if (!this.hasAnnounceTarget) return
    this.announceTarget.textContent = ""
    this.announceTarget.textContent = message
  }

  lockedKeys() {
    return this.element.querySelector("#pos_workspace") ? WORKSPACE_LOCK_KEYS : MENU_LOCK_KEYS
  }

  requestFunctionKeyLock() {
    const keyboard = navigator.keyboard
    if (!keyboard || typeof keyboard.lock !== "function") return
    keyboard.lock(this.lockedKeys()).catch(() => {})
  }

  releaseFunctionKeyLock() {
    const keyboard = navigator.keyboard
    if (!keyboard || typeof keyboard.unlock !== "function") return
    keyboard.unlock()
  }

  functionKey(event) {
    if (typeof event.key === "string" && /^F\d{1,2}$/i.test(event.key)) return event.key.toUpperCase()
    if (typeof event.code === "string" && /^F\d{1,2}$/i.test(event.code)) return event.code.toUpperCase()
    return null
  }

  claim(event) {
    event.preventDefault()
    if (typeof event.stopImmediatePropagation === "function") event.stopImmediatePropagation()
  }
}
