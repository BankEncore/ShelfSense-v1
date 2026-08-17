import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  onKeydown(event) {
    if (event.key !== "Enter") return
    if (event.target && event.target.closest && event.target.closest("button, [type=submit], a[href]")) return
    event.preventDefault()
  }

  print(event) {
    event.preventDefault()
    window.print()
  }
}
