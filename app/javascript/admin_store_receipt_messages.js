function selectedMode(inputs) {
  const checked = Array.from(inputs).find((input) => input.checked)
  return checked ? checked.value : ""
}

function sync(root) {
  const header = root.querySelector("[data-receipt-message='header']")
  const footer = root.querySelector("[data-receipt-message='footer']")
  if (header) {
    header.disabled = selectedMode(root.querySelectorAll("[data-receipt-message='header-mode']")) !== "custom"
  }
  if (footer) {
    footer.disabled = selectedMode(root.querySelectorAll("[data-receipt-message='footer-mode']")) !== "custom"
  }
}

function boot() {
  document.querySelectorAll("[data-store-receipt-messages]").forEach((root) => {
    sync(root)
    root.addEventListener("change", (event) => {
      if (event.target.matches("[data-receipt-message='header-mode'], [data-receipt-message='footer-mode']")) {
        sync(root)
      }
    })
  })
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", boot)
} else {
  boot()
}
