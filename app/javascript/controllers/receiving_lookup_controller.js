import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "query", "message", "picker", "selection", "form", "lineId", "quantity", "cost", "confirm" ]
  static values = { url: String }

  connect() {
    this.matches = []
    this.selectedIndex = -1
  }

  async search(event) {
    event.preventDefault()
    const query = this.queryTarget.value.trim()
    if (!query) return this.showMessage("Enter or scan an identifier.")

    this.showMessage("Searching…")
    this.clearSelection()
    try {
      const response = await fetch(`${this.urlValue}?query=${encodeURIComponent(query)}`, {
        headers: { Accept: "application/json" }, credentials: "same-origin"
      })
      const payload = await response.json()
      if (payload.outcome === "selected") {
        this.selectMatch(payload.matches[0])
      } else if (payload.outcome === "multiple") {
        this.showPicker(payload.matches)
      } else {
        this.showMessage(payload.message || "No eligible open PO line found.")
      }
    } catch (_error) {
      this.showMessage("Lookup could not be completed. Try again.")
    }
  }

  clearMessage() {
    this.messageTarget.textContent = ""
  }

  showPicker(matches) {
    this.matches = matches
    this.selectedIndex = 0
    this.pickerTarget.replaceChildren()
    const heading = document.createElement("h3")
    heading.textContent = `${matches.length} open PO lines match. Use Up/Down and Enter to select.`
    this.pickerTarget.append(heading)

    const list = document.createElement("div")
    list.setAttribute("role", "listbox")
    list.addEventListener("keydown", (event) => this.pickerKeydown(event))
    matches.forEach((match, index) => {
      const button = document.createElement("button")
      button.type = "button"
      button.setAttribute("role", "option")
      button.dataset.index = index
      button.textContent = this.description(match)
      button.addEventListener("click", () => this.selectMatch(match))
      list.append(button)
    })
    this.pickerTarget.append(list)
    this.pickerTarget.hidden = false
    this.updatePickerSelection()
    this.showMessage("Multiple eligible lines found; select the correct purchase-order line.")
  }

  pickerKeydown(event) {
    if (![ "ArrowUp", "ArrowDown", "Enter", "Escape" ].includes(event.key)) return
    event.preventDefault()
    if (event.key === "Escape") {
      this.pickerTarget.hidden = true
      this.queryTarget.focus()
    } else if (event.key === "Enter") {
      this.selectMatch(this.matches[this.selectedIndex])
    } else {
      const step = event.key === "ArrowDown" ? 1 : -1
      this.selectedIndex = (this.selectedIndex + step + this.matches.length) % this.matches.length
      this.updatePickerSelection()
    }
  }

  updatePickerSelection() {
    const options = Array.from(this.pickerTarget.querySelectorAll("[role='option']"))
    options.forEach((option, index) => {
      const selected = index === this.selectedIndex
      option.setAttribute("aria-selected", selected.toString())
      option.classList.toggle("is-selected", selected)
      option.tabIndex = selected ? 0 : -1
    })
    options[this.selectedIndex]?.focus({ preventScroll: true })
  }

  selectMatch(match) {
    this.pickerTarget.hidden = true
    this.lineIdTarget.value = match.id
    this.quantityTarget.value = match.open_quantity
    this.costTarget.value = match.expected_unit_cost_cents
    this.quantityTarget.disabled = false
    this.costTarget.disabled = false
    this.confirmTarget.disabled = false
    this.selectionTarget.textContent = this.description(match)
    this.showMessage("Line selected. Confirm quantity and actual cost before adding.")
    this.quantityTarget.focus()
    this.quantityTarget.select()
  }

  clearSelection() {
    this.pickerTarget.hidden = true
    this.lineIdTarget.value = ""
    this.quantityTarget.value = ""
    this.costTarget.value = ""
    this.quantityTarget.disabled = true
    this.costTarget.disabled = true
    this.confirmTarget.disabled = true
    this.selectionTarget.textContent = "Scan or search to select an eligible PO line."
  }

  description(match) {
    const request = match.customer_request ? ` · customer request #${match.customer_request}` : " · stock order"
    return `PO #${match.po_number} · ${match.product} · SKU ${match.sku}${request} · ordered ${match.order_date} · open ${match.open_quantity} · expected ${match.expected_unit_cost_cents}¢`
  }

  showMessage(message) {
    this.messageTarget.textContent = message
  }
}
