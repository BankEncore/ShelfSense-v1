import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "row" ]

  connect() {
    this.selectedIndex = this.rowTargets.findIndex((row) => row.classList.contains("is-selected"))
  }

  keydown(event) {
    if (event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return
    if (![ "ArrowUp", "ArrowDown", "Enter" ].includes(event.key)) return
    if (this.editingText(event.target) && event.key !== "Enter") return

    if (event.key === "Enter") {
      const row = this.rowTargets[this.selectedIndex]
      const action = row?.querySelector("[data-row-primary]")
      if (!action || this.editingText(event.target)) return
      event.preventDefault()
      action.click()
      return
    }

    event.preventDefault()
    const step = event.key === "ArrowDown" ? 1 : -1
    const start = this.selectedIndex < 0 ? (step > 0 ? -1 : 0) : this.selectedIndex
    this.select((start + step + this.rowTargets.length) % this.rowTargets.length)
  }

  select(index) {
    this.rowTargets.forEach((row, rowIndex) => {
      const selected = rowIndex === index
      row.classList.toggle("is-selected", selected)
      row.setAttribute("aria-selected", selected.toString())
      row.tabIndex = selected ? 0 : -1
    })
    this.selectedIndex = index
    this.rowTargets[index]?.focus({ preventScroll: true })
  }

  editingText(target) {
    return target.matches("input, textarea, select, [contenteditable='true']")
  }
}
