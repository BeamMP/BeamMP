import { BEAMMP_TEXT_STYLE_MAP } from "./constants.js"

export function parseBeamMPFormatting(raw) {
  const text = String(raw || "")
  if (!text) return []

  const tokens = text.split(/(\^.)/g)
  const segments = []
  let currentText = ""
  const activeClasses = new Set()

  const flushText = () => {
    if (!currentText) return
    const classList = Array.from(activeClasses)
    segments.push({
      type: "text",
      text: currentText,
      classes: classList.length ? classList : null
    })
    currentText = ""
  }

  for (let index = 0; index < tokens.length; index += 1) {
    const token = tokens[index]
    if (/^\^.$/.test(token)) {
      flushText()

      if (token === "^r") {
        activeClasses.clear()
        continue
      }

      if (token === "^p") {
        segments.push({ type: "br" })
        continue
      }

      const mappedClass = BEAMMP_TEXT_STYLE_MAP[token]
      if (mappedClass?.startsWith("color-")) {
        for (const className of [...activeClasses]) {
          if (className.startsWith("color-")) {
            activeClasses.delete(className)
          }
        }
        activeClasses.add(mappedClass)
      } else if (mappedClass) {
        activeClasses.add(mappedClass)
      }
      continue
    }

    currentText += token
  }

  flushText()
  return segments
}
