import { Controller } from "@hotwired/stimulus"

const ABANDON_COPY = "Discard this location entry?"

export default class extends Controller {
  static targets = [
    "row",
    "panel",
    "locateSection",
    "notLocatedSection",
    "specialOrderFields",
    "cancelAction",
    "convertField"
  ]
  static values = { selectedId: String }

  connect() {
    this.panelSnapshots = new Map()
    this.selectedIndex = Math.max(0, this.rowTargets.findIndex((row) => row.dataset.requestId === this.selectedIdValue))
    const panelOpen = this.panelTargets.some((panel) => !panel.hidden)
    this.select(this.selectedIndex, { focus: !panelOpen })
    this.activePanel = this.panelTargets.find((panel) => !panel.hidden) || null
    if (this.activePanel) this.snapshotPanel(this.activePanel)
    this.restoreFailureState()
    this.boundPreparePanelSubmit = this.preparePanelSubmit.bind(this)
    this.element.addEventListener("submit", this.boundPreparePanelSubmit, true)
  }

  disconnect() {
    this.element.removeEventListener("submit", this.boundPreparePanelSubmit, true)
  }

  keydown(event) {
    if (event.defaultPrevented || event.altKey || event.ctrlKey || event.metaKey) return

    if (event.key === "Escape" && this.visiblePanel) {
      event.preventDefault()
      event.stopPropagation()
      this.closePanel()
      return
    }
    if (event.target.closest("[data-location-queue-target='panel']")) return
    if (this.editable(event.target) || ![ "ArrowUp", "ArrowDown", "Enter" ].includes(event.key)) return
    event.preventDefault()
    if (event.key === "Enter") return this.openSelectedPanel()

    const step = event.key === "ArrowDown" ? 1 : -1
    const nextIndex = (this.selectedIndex + step + this.rowTargets.length) % this.rowTargets.length
    if (!this.prepareRequestChange(nextIndex)) return
    this.select(nextIndex)
  }

  selectRow(event) {
    if (event.target.closest("button, a, input, select")) return
    const index = this.rowTargets.indexOf(event.currentTarget)
    if (!this.prepareRequestChange(index)) return
    this.select(index)
  }

  openPanel(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("tr")
    const index = this.rowTargets.indexOf(row)
    if (!this.prepareRequestChange(index)) return
    this.select(index, { focus: false })
    this.openSelectedPanel()
  }

  openSelectedPanel() {
    const panel = this.panelForSelection
    if (!panel) return

    const outgoing = this.visiblePanel
    if (outgoing && outgoing !== panel) {
      if (!this.abandonDirtyPanel(outgoing)) {
        this.revertSelectionToPanel(outgoing)
        return
      }
      this.resetPanel(outgoing)
      outgoing.hidden = true
      this.activePanel = null
    }

    this.panelTargets.forEach((item) => { item.hidden = item !== panel })
    this.activePanel = panel
    this.showLocate()
    this.snapshotPanel(panel)
    this.focusLocate(panel)
  }

  closePanel(event) {
    event?.preventDefault?.()
    const panel = this.visiblePanel
    if (!panel) return
    if (!this.abandonDirtyPanel(panel)) return
    this.resetPanel(panel)
    panel.hidden = true
    this.activePanel = null
    this.rowTargets[this.selectedIndex]?.focus()
  }

  showLocate(event) {
    event?.preventDefault?.()
    const panel = this.panelForSelection || this.visiblePanel
    if (!panel) return
    if (!this.abandonDirtySection(panel, "not-located")) return
    this.sectionIn(panel, "locate")?.removeAttribute("hidden")
    this.sectionIn(panel, "not-located")?.setAttribute("hidden", "")
    this.focusLocate(panel)
  }

  showNotLocated(event) {
    event?.preventDefault?.()
    const panel = this.panelForSelection || this.visiblePanel
    if (!panel) return
    if (!this.abandonDirtySection(panel, "locate")) return
    this.sectionIn(panel, "locate")?.setAttribute("hidden", "")
    const section = this.sectionIn(panel, "not-located")
    section?.removeAttribute("hidden")
    this.showCancelAction({ currentTarget: panel })
    section?.querySelector("input[name='notes']")?.focus()
  }

  showCancelAction(event) {
    const panel = event.currentTarget.closest?.("[data-location-queue-target='panel']") || this.panelForSelection
    if (!panel) return
    panel.querySelector("[data-location-queue-target='cancelAction']")?.removeAttribute("hidden")
    panel.querySelector("[data-location-queue-target='specialOrderFields']")?.setAttribute("hidden", "")
    const convert = panel.querySelector("[data-location-queue-target='convertField']")
    if (convert) convert.value = "0"
  }

  showSpecialOrderAction(event) {
    const panel = event.currentTarget.closest?.("[data-location-queue-target='panel']") || this.panelForSelection
    if (!panel) return
    panel.querySelector("[data-location-queue-target='cancelAction']")?.setAttribute("hidden", "")
    const fields = panel.querySelector("[data-location-queue-target='specialOrderFields']")
    fields?.removeAttribute("hidden")
    const convert = panel.querySelector("[data-location-queue-target='convertField']")
    if (convert) convert.value = "1"
    fields?.querySelector("select, input:not([type='hidden'])")?.focus()
  }

  preparePanelSubmit(event) {
    const form = event.target
    if (!form.matches?.("form[data-dirty-track]")) return
    const panel = form.closest("[data-location-queue-target='panel']")
    if (!panel) return
    panel.querySelectorAll("form[data-dirty-track]").forEach((other) => {
      if (other !== form) this.resetForm(other)
    })
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
    if (focus) this.rowTargets[index]?.focus()
  }

  restoreFailureState() {
    const summary = this.element.parentElement?.querySelector?.("[data-ops-error-summary]")
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
          this.showSpecialOrderAction({ currentTarget: special })
        }
      } else {
        const cancel = this.panelForSelection.querySelector("input[name='resolution'][value='cancel']")
        if (cancel) {
          cancel.checked = true
          this.showCancelAction({ currentTarget: cancel })
        }
      }
    }
    const described = this.panelForSelection.querySelector(`[aria-describedby='${error.id}']`)
    ;(described || error.closest("form")?.querySelector("input:not([type='hidden']), select, button"))?.focus()
  }

  focusLocate(panel) {
    const scan = panel?.querySelector("[data-location-scan]")
    const checkbox = panel?.querySelector("input[name='physical_copy_confirmed']")
    ;(scan || checkbox || panel?.querySelector("[data-location-submit]"))?.focus()
  }

  prepareRequestChange(nextIndex) {
    if (nextIndex === this.selectedIndex) return true
    const outgoing = this.visiblePanel
    if (!outgoing) return true
    const nextPanel = this.panelForRowIndex(nextIndex)
    if (!nextPanel || outgoing === nextPanel) return true
    if (!this.abandonDirtyPanel(outgoing)) return false
    this.resetPanel(outgoing)
    outgoing.hidden = true
    this.activePanel = null
    return true
  }

  abandonDirtySection(panel, sectionKey) {
    const section = this.sectionIn(panel, sectionKey)
    if (!section || section.hidden) return true
    const forms = section.querySelectorAll("form[data-dirty-track]")
    if (!Array.from(forms).some((form) => this.isFormDirty(form))) return true
    if (!window.confirm(ABANDON_COPY)) return false
    forms.forEach((form) => this.resetForm(form))
    return true
  }

  abandonDirtyPanel(panel) {
    if (!this.isPanelDirty(panel)) return true
    if (!window.confirm(ABANDON_COPY)) return false
    return true
  }

  revertSelectionToPanel(panel) {
    const index = this.rowTargets.findIndex((row) => row.dataset.requestId === panel.dataset.requestId)
    if (index >= 0) this.select(index, { focus: true })
  }

  snapshotPanel(panel) {
    panel.querySelectorAll("form[data-dirty-track]").forEach((form) => {
      this.panelSnapshots.set(form, this.serializeForm(form))
    })
  }

  serializeForm(form) {
    const values = {}
    Array.from(form.elements).forEach((element) => {
      if (!element.name || element.disabled) return
      if (element.type === "checkbox" || element.type === "radio") {
        values[element.name] = element.checked ? element.value : ""
      } else {
        values[element.name] = element.value
      }
    })
    return values
  }

  isFormDirty(form) {
    if (form.dataset.dirty === "true") return true
    const snapshot = this.panelSnapshots.get(form)
    if (!snapshot) return false
    const current = this.serializeForm(form)
    return Object.keys(snapshot).some((key) => snapshot[key] !== current[key])
  }

  isPanelDirty(panel) {
    return Array.from(panel.querySelectorAll("form[data-dirty-track]")).some((form) => this.isFormDirty(form))
  }

  resetPanel(panel) {
    panel.querySelectorAll("form[data-dirty-track]").forEach((form) => this.resetForm(form))
    this.snapshotPanel(panel)
  }

  resetForm(form) {
    form.reset()
    delete form.dataset.dirty
    form.dispatchEvent(new CustomEvent("ops:dirty-cancel", { bubbles: true, detail: { form } }))
    this.panelSnapshots.set(form, this.serializeForm(form))
  }

  sectionIn(panel, name) {
    return panel?.querySelector(`[data-location-queue-target='${name === "locate" ? "locateSection" : "notLocatedSection"}']`)
  }

  panelForRowIndex(index) {
    const id = this.rowTargets[index]?.dataset.requestId
    return this.panelTargets.find((panel) => panel.dataset.requestId === id)
  }

  get panelForSelection() {
    return this.panelForRowIndex(this.selectedIndex)
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
