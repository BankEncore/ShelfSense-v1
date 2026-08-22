import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "row", "panel", "initialFocus", "locateSection", "notLocatedSection", "specialOrderFields", "convertField" ]
  static values = { selectedId: String }

  connect() {
    this.selectedIndex = Math.max(0, this.rowTargets.findIndex((row) => row.dataset.requestId === this.selectedIdValue))
    this.select(this.selectedIndex, { focus: false })
    this.activePanel = this.panelTargets.find((panel) => !panel.hidden) || null
    this.restoreFailureState()
  }

  keydown(event) {
    if (event.defaultPrevented || event.altKey || event.ctrlKey || event.metaKey) return

    if (event.key === "Escape" && this.visiblePanel) {
      event.preventDefault()
      this.closePanel()
      return
    }
    if (event.target.closest("[data-location-queue-target='panel']")) return
    if (this.editable(event.target) || ![ "ArrowUp", "ArrowDown", "Enter" ].includes(event.key)) return
    event.preventDefault()
    if (event.key === "Enter") return this.openSelectedPanel()

    const step = event.key === "ArrowDown" ? 1 : -1
    this.select((this.selectedIndex + step + this.rowTargets.length) % this.rowTargets.length)
  }

  selectRow(event) {
    if (event.target.closest("button, a, input, select")) return
    this.select(this.rowTargets.indexOf(event.currentTarget))
  }

  openPanel(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("tr")
    this.select(this.rowTargets.indexOf(row), { focus: false })
    this.openSelectedPanel()
  }

  openSelectedPanel() {
    const panel = this.panelForSelection
    if (!panel) return
    this.panelTargets.forEach((item) => { item.hidden = item !== panel })
    this.activePanel = panel
    this.showLocate()
    this.focusLocate(panel)
  }

  closePanel(event) {
    event?.preventDefault?.()
    const panel = this.visiblePanel
    if (!panel) return
    panel.hidden = true
    this.activePanel = null
    this.rowTargets[this.selectedIndex]?.focus()
  }

  showLocate(event) {
    event?.preventDefault?.()
    const panel = this.panelForSelection
    this.sectionIn(panel, "locate")?.removeAttribute("hidden")
    this.sectionIn(panel, "not-located")?.setAttribute("hidden", "")
    this.focusLocate(panel)
  }

  showNotLocated(event) {
    event?.preventDefault?.()
    const panel = this.panelForSelection
    this.sectionIn(panel, "locate")?.setAttribute("hidden", "")
    const section = this.sectionIn(panel, "not-located")
    section?.removeAttribute("hidden")
    section?.querySelector("input[name='notes']")?.focus()
  }

  toggleResolution(event) {
    const panel = event.currentTarget.closest("[data-location-queue-target='panel']")
    const special = event.currentTarget.value === "special_order"
    const fields = panel.querySelector("[data-location-queue-target='specialOrderFields']")
    const convert = panel.querySelector("[data-location-queue-target='convertField']")
    const submit = panel.querySelector("[data-location-resolution-submit]")
    fields.hidden = !special
    convert.value = special ? "1" : "0"
    submit.textContent = special ? "Convert to special order" : "Cancel request"
    if (special) fields.querySelector("select, input")?.focus()
  }

  select(index, { focus = true } = {}) {
    if (index < 0) return
    this.selectedIndex = index
    this.rowTargets.forEach((row, rowIndex) => {
      const selected = rowIndex === index
      row.classList.toggle("is-selected", selected)
      row.setAttribute("aria-selected", selected.toString())
      row.tabIndex = selected ? 0 : -1
    })
    if (focus) this.rowTargets[index].focus()
  }

  restoreFailureState() {
    const sibling = this.element.previousElementSibling
    const summary = sibling?.matches?.("[data-ops-error-summary]")
      ? sibling
      : sibling?.querySelector?.("[data-ops-error-summary]")
    if (!summary) return
    this.openSelectedPanel()
    const error = this.panelForSelection?.querySelector(".ops-row-error")
    if (!error) return
    if (error.id.includes("confirm")) this.showLocate()
    else {
      this.showNotLocated()
      if (error.id.includes("special")) {
        const special = this.panelForSelection.querySelector("input[name='resolution'][value='special_order']")
        if (special) {
          special.checked = true
          this.toggleResolution({ currentTarget: special })
        }
      }
    }
    const described = this.panelForSelection.querySelector(`[aria-describedby='${error.id}']`)
    ;(described || error.closest("form")?.querySelector("input:not([type='hidden']), select, button"))?.focus()
  }

  focusLocate(panel) {
    const scan = panel?.querySelector("[data-location-scan]")
    ;(scan || panel?.querySelector("[data-location-submit]"))?.focus()
  }

  sectionIn(panel, name) {
    return panel?.querySelector(`[data-location-queue-target='${name === "locate" ? "locateSection" : "notLocatedSection"}']`)
  }

  get panelForSelection() {
    const id = this.rowTargets[this.selectedIndex]?.dataset.requestId
    return this.panelTargets.find((panel) => panel.dataset.requestId === id)
  }

  get visiblePanel() {
    return this.activePanel && !this.activePanel.hidden
      ? this.activePanel
      : this.panelTargets.find((panel) => !panel.hidden)
  }

  editable(target) {
    return target.matches("input, textarea, select, [contenteditable='true']")
  }
}
