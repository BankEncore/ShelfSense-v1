// Slice 7C keyboard helpers: normalize → classify → resolve.
// The workspace controller owns execution. Shell owns F10 / Keyboard Lock.

export const FOCUS_ZONES = Object.freeze({
  overlay: "overlay",
  command_input: "command_input",
  other_editable: "other_editable",
  workspace_control: "workspace_control",
  basket_row: "basket_row",
  tender_row: "tender_row",
  workspace_background: "workspace_background",
  shell_chrome: "shell_chrome"
})

export const MODES = Object.freeze({
  sale: "sale",
  tender: "tender",
  completion_pending: "completion_pending",
  completion_failed: "completion_failed"
})

/** Actions that ignore event.repeat (packet lock). */
export const REPEAT_IGNORED_ACTIONS = new Set([
  "remove-selected-record",
  "remove-selected-tender",
  "cancel-transaction",
  "return-to-sale",
  "open-tender-selection",
  "open-product-lookup",
  "open-pickup-lookup",
  "open-return-chooser",
  "set-quantity",
  "edit-price",
  "edit-discount",
  "tender-cash",
  "tender-card",
  "tender-check",
  "tender-other",
  "tender-stored-value"
])

const EDITABLE_INPUT_TYPES = new Set([
  "text",
  "search",
  "tel",
  "email",
  "password",
  "number",
  "url",
  "date",
  "datetime-local",
  "month",
  "time",
  "week"
])

/**
 * @param {KeyboardEvent} event
 * @returns {string|null} normalized key or null when chord/composition should be ignored
 */
export function normalizeKey(event) {
  if (!event || event.isComposing) return null
  if (event.metaKey || event.ctrlKey || event.altKey) return null

  if (typeof event.key === "string" && /^F\d{1,2}$/i.test(event.key)) {
    return event.key.toUpperCase()
  }
  if (typeof event.code === "string" && /^F\d{1,2}$/i.test(event.code)) {
    return event.code.toUpperCase()
  }

  switch (event.code) {
    case "NumpadAdd":
      return "+"
    case "NumpadSubtract":
    case "Minus":
      return "-"
    case "NumpadMultiply":
      return "*"
    case "NumpadDivide":
      return "/"
    case "NumpadDecimal":
      return "."
    default:
      break
  }

  if (event.key === "Escape" || event.key === "Esc") return "Escape"
  if (event.key === "Enter") return "Enter"
  if (event.key === "ArrowUp" || event.key === "ArrowDown" || event.key === "ArrowLeft" || event.key === "ArrowRight") {
    return event.key
  }
  if (event.key === "Tab") return "Tab"
  if (event.key === " " || event.key === "Spacebar") return " "

  if (typeof event.key === "string" && event.key.length === 1) {
    return event.key
  }

  return event.key || null
}

/**
 * @param {Element|null|undefined} target
 * @returns {boolean}
 */
export function isEditableControl(target) {
  if (!target || !target.closest) return false
  if (target.isContentEditable) return true
  const el = target.closest("input, textarea, select, [contenteditable=true], [contenteditable='']")
  if (!el) return false
  if (el.matches("textarea, select, [contenteditable=true], [contenteditable='']")) return true
  if (el.matches("input")) {
    const type = (el.getAttribute("type") || "text").toLowerCase()
    if (type === "button" || type === "submit" || type === "reset" || type === "checkbox" || type === "radio" || type === "file" || type === "hidden" || type === "image" || type === "range" || type === "color") {
      return false
    }
    return EDITABLE_INPUT_TYPES.has(type) || type === "text" || !el.getAttribute("type")
  }
  return false
}

/**
 * @param {object} opts
 * @param {Element|null|undefined} opts.target
 * @param {Element|null|undefined} opts.commandField
 * @param {Element|null|undefined} opts.workspaceRoot
 * @param {Element|null|undefined} opts.activeOverlay
 * @param {boolean} opts.overlayOpen
 * @returns {string}
 */
export function classifyFocusZone({ target, commandField, workspaceRoot, activeOverlay, overlayOpen }) {
  if (overlayOpen && activeOverlay && target && activeOverlay.contains(target)) {
    return FOCUS_ZONES.overlay
  }
  if (commandField && target === commandField) {
    return FOCUS_ZONES.command_input
  }
  if (isEditableControl(target)) {
    return FOCUS_ZONES.other_editable
  }
  if (target?.closest?.("button, [type=submit], a[href], [role=button]")) {
    if (workspaceRoot && target && workspaceRoot.contains(target)) {
      return FOCUS_ZONES.workspace_control
    }
    return FOCUS_ZONES.shell_chrome
  }
  if (target?.closest?.(".pos-tenders__item")) {
    return FOCUS_ZONES.tender_row
  }
  if (target?.closest?.("[data-line-id], [data-issuance-id]")) {
    return FOCUS_ZONES.basket_row
  }
  if (workspaceRoot && target && workspaceRoot.contains(target)) {
    return FOCUS_ZONES.workspace_background
  }
  return FOCUS_ZONES.shell_chrome
}

/**
 * Map Stimulus modeValue to dispatcher mode.
 * @param {string} modeValue
 * @returns {string}
 */
export function classifyMode(modeValue) {
  switch (modeValue) {
    case "tender":
      return MODES.tender
    case "completion_pending":
      return MODES.completion_pending
    case "completion_failed":
      return MODES.completion_failed
    case "sale_entry":
    default:
      return MODES.sale
  }
}

function punctuationShortcutZone(focusZone) {
  return focusZone === FOCUS_ZONES.basket_row ||
    focusZone === FOCUS_ZONES.tender_row ||
    focusZone === FOCUS_ZONES.workspace_background
}

/**
 * @param {object} context
 * @returns {{ kind: "action"|"literal"|"none"|"delegate_overlay"|"native_control", action?: string, key?: string }}
 */
export function resolveBinding(context) {
  const {
    mode,
    focusZone,
    key,
    overlayOpen,
    inFlight,
    repeat
  } = context

  if (!key) return { kind: "none" }

  if (key === "F10") return { kind: "none" }

  if (overlayOpen || focusZone === FOCUS_ZONES.overlay) {
    return { kind: "delegate_overlay", key }
  }

  if (inFlight || mode === MODES.completion_pending) {
    if (key === "Enter" && focusZone === FOCUS_ZONES.workspace_control) {
      return { kind: "native_control" }
    }
    if (key === "Enter" || key === "F9") return { kind: "none" }
    return { kind: "none" }
  }

  if (mode === MODES.completion_failed) {
    if (key === "Enter") {
      if (focusZone === FOCUS_ZONES.workspace_control) return { kind: "native_control" }
      return actionResult("submit-complete", repeat)
    }
    if (key === "F9") return actionResult("cancel-transaction", repeat)
    if (key === "Escape") return { kind: "none" }
    return { kind: "none" }
  }

  if (focusZone === FOCUS_ZONES.command_input || focusZone === FOCUS_ZONES.other_editable) {
    if (key === "Enter") {
      if (focusZone === FOCUS_ZONES.workspace_control) return { kind: "native_control" }
      return actionResult("submit-command", repeat)
    }
    if (key === "Escape") return actionResult("escape", repeat)
    if (key === "F9") return actionResult("cancel-transaction", repeat)
    if (key.length === 1 || key === " ") return { kind: "literal", key }
    // F-keys and arrows still resolve in sale/tender below when not swallowed
  }

  if (key === "Enter" && focusZone === FOCUS_ZONES.workspace_control) {
    return { kind: "native_control" }
  }

  if (key === "Enter") {
    if (mode === MODES.tender && focusZone === FOCUS_ZONES.tender_row) {
      return actionResult("open-selected-tender-actions", repeat)
    }
    return actionResult("submit-command", repeat)
  }

  if (key === "Escape") return actionResult("escape", repeat)
  if (key === "F9") return actionResult("cancel-transaction", repeat)

  if (mode !== MODES.sale && mode !== MODES.tender) {
    return { kind: "none" }
  }

  const tenderFamily = {
    F1: "tender-cash",
    F2: "tender-card",
    F3: "tender-check",
    F4: "tender-other",
    F5: "tender-stored-value"
  }[key]
  if (tenderFamily) return actionResult(tenderFamily, repeat)

  if (mode === MODES.tender) {
    if (key === "ArrowUp") return actionResult("move-tender-selection-up", repeat)
    if (key === "ArrowDown") return actionResult("move-tender-selection-down", repeat)
    if (key === "F8" || (key === "-" && punctuationShortcutZone(focusZone))) {
      return actionResult("remove-selected-tender", repeat)
    }
    if (key === "+" && punctuationShortcutZone(focusZone)) {
      return actionResult("open-tender-selection", repeat)
    }
    if (focusZone === FOCUS_ZONES.command_input || focusZone === FOCUS_ZONES.other_editable) {
      if (key.length === 1) return { kind: "literal", key }
    }
    if (focusZone === FOCUS_ZONES.shell_chrome && key.length === 1) {
      return { kind: "literal", key }
    }
    return { kind: "none" }
  }

  // SALE
  if (key === "ArrowUp") return actionResult("move-basket-selection-up", repeat)
  if (key === "ArrowDown") return actionResult("move-basket-selection-down", repeat)
  if (key === "F6") return actionResult("edit-price", repeat)
  if (key === "F7") return actionResult("edit-discount", repeat)
  if (key === "F8") return actionResult("remove-selected-record", repeat)

  if (punctuationShortcutZone(focusZone)) {
    if (key === "*") return actionResult("set-quantity", repeat)
    if (key === "+") return actionResult("open-tender-selection", repeat)
    if (key === "/") return actionResult("open-product-lookup", repeat)
    if (key === ".") return actionResult("open-pickup-lookup", repeat)
    if (key === "-") return actionResult("open-return-chooser", repeat)
  }

  if (focusZone === FOCUS_ZONES.shell_chrome && key.length === 1) {
    return { kind: "literal", key }
  }

  if ((focusZone === FOCUS_ZONES.command_input || focusZone === FOCUS_ZONES.other_editable) && key.length === 1) {
    return { kind: "literal", key }
  }

  return { kind: "none" }
}

function actionResult(action, repeat) {
  if (repeat && REPEAT_IGNORED_ACTIONS.has(action)) {
    return { kind: "none" }
  }
  return { kind: "action", action }
}
