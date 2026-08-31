import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    printUrl: String,
    tapeUrl: String
  }

  onKeydown(event) {
    if (event.key !== "Enter") return
    if (event.target && event.target.closest && event.target.closest("button, [type=submit], a[href]")) return
    event.preventDefault()
  }

  async print(event) {
    event.preventDefault()
    if (this.hasPrintUrlValue && this.printUrlValue) {
      await this.printAuthorized(this.printUrlValue)
      return
    }
    document.body.classList.remove("is-printing-voucher")
    document.body.classList.remove("is-printing-tape")
    await this.prepareFonts()
    window.print()
  }

  async printTape(event) {
    event.preventDefault()
    if (this.hasTapeUrlValue && this.tapeUrlValue) {
      await this.printAuthorized(this.tapeUrlValue)
      return
    }
    document.body.classList.remove("is-printing-voucher")
    document.body.classList.add("is-printing-tape")
    const cleanup = () => document.body.classList.remove("is-printing-tape")
    window.addEventListener("afterprint", cleanup, { once: true })
    await this.prepareFonts()
    window.print()
    window.setTimeout(cleanup, 1000)
  }

  async printVoucher(event) {
    event.preventDefault()
    document.body.classList.remove("is-printing-tape")
    document.body.classList.add("is-printing-voucher")
    const cleanup = () => document.body.classList.remove("is-printing-voucher")
    window.addEventListener("afterprint", cleanup, { once: true })
    await this.prepareFonts()
    window.print()
    window.setTimeout(cleanup, 1000)
  }

  async printAuthorized(url) {
    const response = await fetch(url, {
      credentials: "same-origin",
      headers: { Accept: "text/html", "X-Requested-With": "XMLHttpRequest" }
    })
    if (!response.ok) {
      window.alert("Unable to print. Reload and try again.")
      return
    }
    const html = await response.text()
    const iframe = document.createElement("iframe")
    iframe.setAttribute("aria-hidden", "true")
    iframe.style.position = "fixed"
    iframe.style.right = "0"
    iframe.style.bottom = "0"
    iframe.style.width = "0"
    iframe.style.height = "0"
    iframe.style.border = "0"
    document.body.appendChild(iframe)

    const frameDoc = iframe.contentDocument
    frameDoc.open()
    frameDoc.write(html)
    frameDoc.close()

    await this.prepareFonts()
    const cleanup = () => iframe.remove()
    iframe.contentWindow.addEventListener("afterprint", cleanup, { once: true })
    iframe.contentWindow.focus()
    iframe.contentWindow.print()
    window.setTimeout(cleanup, 1500)
  }

  async prepareFonts() {
    if (document.fonts && document.fonts.load) {
      try {
        await document.fonts.load('700 11px "Noto Sans Mono"')
        await document.fonts.load('800 16px "Plus Jakarta Sans"')
        await document.fonts.ready
      } catch (_error) {
        // Print with the stack fallback if a packaged face fails to load.
      }
    }
  }
}
