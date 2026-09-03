import { Controller } from "@hotwired/stimulus"

// Mirrors ProductVariants::NameComposer grammar for live derived-name preview.
// Server remains authoritative for persistence via prepare_attribute_identity.
export default class extends Controller {
  static targets = ["variantType", "conditionSelect", "optionValue1", "optionValue2", "preview"]
  static values  = { hasLabels: Boolean }

  connect() {
    this.recompute()
  }

  recompute() {
    const type = this.variantTypeValue()
    const conditionName = this.conditionNameValue()
    const v1 = this.trimDisplay(this.optionValue1Value())
    const v2 = this.trimDisplay(this.optionValue2Value())
    const hasLabels = this.hasLabelsValue
    const attributed = hasLabels && (v1 !== null || v2 !== null)

    let text
    if (type === "used") {
      const cond = conditionName || ""
      if (!attributed || (v1 === null && v2 === null)) {
        text = cond || null
      } else if (v2 === null) {
        text = `${cond} · ${v1}`
      } else {
        text = `${cond} · ${v1} / ${v2}`
      }
    } else {
      if (!attributed || (v1 === null && v2 === null)) {
        text = "Standard"
      } else if (v2 === null) {
        text = v1
      } else {
        text = `${v1} / ${v2}`
      }
    }

    this.updatePreview(text)
  }

  // --- private helpers ---

  variantTypeValue() {
    if (!this.hasVariantTypeTarget) return "standard"
    return this.variantTypeTarget.value || "standard"
  }

  conditionNameValue() {
    if (!this.hasConditionSelectTarget) return null
    const select = this.conditionSelectTarget
    if (!select.value) return null
    const option = select.options[select.selectedIndex]
    return option ? option.textContent.trim() : null
  }

  optionValue1Value() {
    if (!this.hasOptionValue1Target) return null
    return this.optionValue1Target.value
  }

  optionValue2Value() {
    if (!this.hasOptionValue2Target) return null
    return this.optionValue2Target.value
  }

  trimDisplay(raw) {
    if (raw === null || raw === undefined) return null
    const text = raw.replace(/\s+/g, " ").trim()
    return text.length > 0 ? text : null
  }

  updatePreview(text) {
    if (!this.hasPreviewTarget) return
    const el = this.previewTarget
    if (text) {
      el.textContent = text
      el.classList.remove("muted")
    } else {
      el.textContent = "Fill in fields above to preview"
      el.classList.add("muted")
    }
  }
}
