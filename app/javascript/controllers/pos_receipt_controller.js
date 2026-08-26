import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  onKeydown(event) {
    if (event.key !== "Enter") return
    if (event.target && event.target.closest && event.target.closest("button, [type=submit], a[href]")) return
    event.preventDefault()
  }

  async print(event) {
    event.preventDefault()
    document.body.classList.remove("is-printing-voucher")
    await this.prepareFonts()
    window.print()
  }

  async printVoucher(event) {
    event.preventDefault()
    document.body.classList.add("is-printing-voucher")
    const cleanup = () => document.body.classList.remove("is-printing-voucher")
    window.addEventListener("afterprint", cleanup, { once: true })
    await this.prepareFonts()
    window.print()
    window.setTimeout(cleanup, 1000)
  }

  async prepareFonts() {
    if (document.fonts && document.fonts.load) {
      try {
        await document.fonts.load('700 12px "Inconsolata"')
        await document.fonts.ready
      } catch (_error) {
        // Print with the stack fallback if the local face is unavailable.
      }
    }
  }
}
