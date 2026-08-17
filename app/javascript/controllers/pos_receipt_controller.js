import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  onKeydown(event) {
    if (event.key === "Enter") event.preventDefault()
  }
}
