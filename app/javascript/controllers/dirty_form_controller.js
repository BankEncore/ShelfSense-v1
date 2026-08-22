import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.dirtyForms = new Set()
  }

  change(event) {
    const form = event.target.closest("form[data-dirty-track]")
    if (!form) return
    this.dirtyForms.add(form)
    form.dataset.dirty = "true"
  }

  submit(event) {
    this.clear(event.target)
  }

  beforeVisit(event) {
    if (!this.dirty || window.confirm("Discard unsaved purchasing changes?")) return
    event.preventDefault()
  }

  beforeUnload(event) {
    if (!this.dirty) return
    event.preventDefault()
    event.returnValue = ""
  }

  cancel(event) {
    this.clear(event.detail.form)
  }

  clear(form) {
    if (!form?.matches("form[data-dirty-track]")) return
    this.dirtyForms.delete(form)
    delete form.dataset.dirty
  }

  get dirty() {
    return this.dirtyForms.size > 0
  }
}
