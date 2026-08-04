import { BEAMMP_TEXT_STYLE_MAP } from "./constants.js"

const HEX = "[0-9a-fA-F]{6}"
const TOKEN_PATTERN = new RegExp(`(\\^@#${HEX}|\\^#${HEX}|\\^.)`, "g")
const HEX_FG_PATTERN = new RegExp(`^\\^#${HEX}$`)
const HEX_BG_PATTERN = new RegExp(`^\\^@#${HEX}$`)
const SIMPLE_TOKEN_PATTERN = /^\^.$/
const STRIP_PATTERN = new RegExp(`\\^@#${HEX}|\\^#${HEX}|\\^[0-9a-frlmnop*]`, "gi")

const SERVER_PREFIX = "Server: "
const BLOCKED_TAGS = new Set(["script", "iframe", "form", "input", "button", "a"])
const DANGEROUS_ATTRIBUTE_PATTERN = /^(?:on.*|(?:form).*|action)$/i
const DANGEROUS_VALUE_PATTERN = /javascript:|data:/i

export function escapeHtml(value = "") {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;")
}

export function isSafeServerHtml(html) {
  const parser = new DOMParser()
  const doc = parser.parseFromString(`<div>${html}</div>`, "text/html")

  for (const element of doc.body.querySelectorAll("*")) {
    if (BLOCKED_TAGS.has(element.tagName.toLowerCase())) return false
    for (const attr of element.attributes) {
      if (DANGEROUS_ATTRIBUTE_PATTERN.test(attr.name)) return false
      if (DANGEROUS_VALUE_PATTERN.test(attr.value)) return false
    }
  }
  return true
}

export function stripBeamMPFormatting(value = "") {
  return String(value).replace(STRIP_PATTERN, "")
}

export function formatBeamMPText(value, options = {}) {
  const {
    escape = escapeHtml,
    renderIcon = null,
    allowServerHtml = false,
    styleMap = BEAMMP_TEXT_STYLE_MAP,
  } = options

  const raw = String(value ?? "")
  if (!raw) return ""

  if (allowServerHtml && raw.startsWith(SERVER_PREFIX)) {
    const body = raw.slice(SERVER_PREFIX.length)
    if (body.includes("<") && body.includes(">") && isSafeServerHtml(body)) {
      return `${SERVER_PREFIX}${body}`
    }
  }

  const tokens = raw.split(TOKEN_PATTERN)
  const classes = new Set()
  let result = ""
  let currentText = ""
  let hexColor = null
  let hexBackground = null

  const clearColorClasses = () => {
    for (const className of [...classes]) {
      if (className.startsWith("color-")) classes.delete(className)
    }
  }

  const flush = () => {
    if (!currentText) return

    const classList = Array.from(classes)
    let attributes = classList.length ? ` class="${classList.join(" ")}"` : ""

    let style = ""
    if (hexColor) style += `color:${hexColor};`
    if (hexBackground) style += `background-color:${hexBackground};`
    if (style) attributes += ` style="${style}"`

    const encoded = escape(currentText)
    result += attributes ? `<span${attributes}>${encoded}</span>` : encoded
    currentText = ""
  }

  for (let index = 0; index < tokens.length; index += 1) {
    const token = tokens[index]

    if (HEX_BG_PATTERN.test(token)) {
      flush()
      hexBackground = token.slice(2)
      continue
    }

    if (HEX_FG_PATTERN.test(token)) {
      flush()
      clearColorClasses()
      hexColor = token.slice(1)
      continue
    }

    if (!SIMPLE_TOKEN_PATTERN.test(token)) {
      currentText += token
      continue
    }

    flush()

    if (token === "^r") {
      classes.clear()
      hexColor = null
      hexBackground = null
      continue
    }

    if (token === "^p") {
      result += "<br>"
      continue
    }

    if (token === "^*") {
      const next = tokens[index + 1] ?? ""
      const trimmed = next.trim()

      let icon = trimmed && renderIcon ? renderIcon(trimmed) : null
      let remainder = ""

      if (!icon && trimmed && renderIcon) {
        const firstWord = trimmed.split(/\s+/)[0]
        if (firstWord !== trimmed) {
          icon = renderIcon(firstWord)
          if (icon) remainder = next.slice(next.indexOf(firstWord) + firstWord.length)
        }
      }

      if (!icon) continue

      if (icon.html) {
        result += icon.html
      } else if (icon.text) {
        if (icon.className) classes.add(icon.className)
        currentText = icon.text
        flush()
        if (icon.className) classes.delete(icon.className)
      }

      index += 1
      if (remainder) currentText += remainder
      continue
    }

    const mappedClass = styleMap?.[token]
    if (mappedClass?.startsWith("color-")) {
      clearColorClasses()
      classes.add(mappedClass)
      hexColor = null
    } else if (mappedClass) {
      classes.add(mappedClass)
    }
  }

  flush()
  return result
}

globalThis.beammpFormatText = formatBeamMPText
globalThis.beammpStripFormatting = stripBeamMPFormatting
