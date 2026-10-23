<template>
  <div
    class="beammpChat2"
    @mouseenter="isHovered = true"
    @mouseleave="isHovered = false"
  >
    <div v-show="!enableNewChatMenu" ref="chatWindowRef" class="chat-window" :style="chatWindowStyle">
      <ul
        ref="chatListRef"
        class="chat-list"
        :class="{ 'chat-list--scrollbar-hidden': !isScrollbarVisible }"
        :style="chatListStyle"
      >
        <li
          v-for="message in messages"
          :key="message.key"
          class="chat-message"
          :style="messageStyle(message)"
        >
          <span v-if="!message.hideTimestamp" class="chat-message-timestamp">{{ message.time }}</span>
          <span v-if="message.isServerMessage" class="chat-message-content" v-html="message.html"></span>
          <template v-else>
            <span v-if="message.nameColor" class="chat-message-username" :style="{ color: message.nameColor }">{{ message.username }}</span>
            <span class="chat-message-content">{{ message.text }}</span>
          </template>
        </li>
      </ul>

      <form ref="chatBoxRef" class="chatbox" :style="chatBoxStyle" @submit.prevent="sendChat" @keydown.capture="onInputKeydown">
        <button
          class="chat-control-button chat2-send-button"
          type="submit"
          :title="$tt('ui.apps.beammp.chat.send') || 'Send message'"
          :aria-label="$tt('ui.apps.beammp.chat.send') || 'Send message'"
        >
          {{ sendButtonText }}
        </button>
        <input
          ref="chatInputRef"
          v-model="inputText"
          class="chat2-message-input"
          type="text"
          maxlength="500"
          autocomplete="off"
          placeholder="Chat here"
          aria-label="BeamMP chat message"
          @focus="focusChat"
          @blur="blurChat"
          @keydown="onInputKeydown"
        />
        <button
          class="chat-control-button chat2-swap-button"
          type="button"
          :title="$tt('ui.apps.beammp.chat.moveHorizontal') || 'Move chat horizontally'"
          :aria-label="$tt('ui.apps.beammp.chat.moveHorizontal') || 'Move chat horizontally'"
          @click="swapHorizontal"
        >
          ↔
        </button>
        <button
          class="chat-control-button chat2-swap-button"
          type="button"
          :title="$tt('ui.apps.beammp.chat.moveVertical') || 'Move chat vertically'"
          :aria-label="$tt('ui.apps.beammp.chat.moveVertical') || 'Move chat vertically'"
          @click="swapVertical"
        >
          ↕
        </button>
      </form>
    </div>
  </div>
</template>

<script setup>
import { computed, nextTick, onMounted, onUnmounted, ref } from "vue"
import { useBridge } from "@/bridge"

const { api, events } = useBridge()

const chatWindowRef = ref(null)
const chatListRef = ref(null)
const chatBoxRef = ref(null)
const chatInputRef = ref(null)

const inputText = ref("")
const messages = ref([])
const lastSentMessage = ref("")
const lastMessageId = ref(0)
const enableNewChatMenu = ref(false)
const isHovered = ref(false)
const isFocused = ref(false)
const chatHorizontal = ref(localStorage.getItem("chatHorizontal") || "middle")
const chatVertical = ref(localStorage.getItem("chatVertical") || "bottom")
const nowTick = ref(Date.now())

let fadeTimer = null

const chatWindowStyle = computed(() => ({
  flexDirection: chatVertical.value === "top" ? "column-reverse" : "column",
  alignItems: chatHorizontal.value === "middle" ? "center" : "flex-start",
}))

const chatListStyle = computed(() => {
  return {
    flexDirection: chatVertical.value === "top" ? "column-reverse" : "column",
    marginTop: chatVertical.value === "top" ? "0px" : "auto",
    marginBottom: chatVertical.value === "top" ? "auto" : "0px",
  }
})

const isScrollbarVisible = computed(() => {
  if (enableNewChatMenu.value || isHovered.value || isFocused.value) return true
  const latestMessage = messages.value[messages.value.length - 1]
  return latestMessage ? messageStyle(latestMessage).opacity > 0 : false
})

const chatBoxStyle = computed(() => ({
  flexDirection: chatHorizontal.value === "right" ? "row-reverse" : "row",
  marginLeft: chatHorizontal.value === "right" ? "auto" : "0px",
}))

const sendButtonText = "Send"

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#39;")
}

function colorToRgba(color) {
  if (!color) return null
  const r = color.r ?? color[0]
  const g = color.g ?? color[1]
  const b = color.b ?? color[2]
  const a = color.a ?? color[3] ?? 255
  if (r == null || g == null || b == null) return null
  return `rgba(${r}, ${g}, ${b}, ${a / 255})`
}

function isSafeServerHtml(html) {
  const parser = new DOMParser()
  const doc = parser.parseFromString(`<div>${html}</div>`, "text/html")
  const blockedTags = new Set(["script", "iframe", "form", "input", "button", "a"])
  const elements = doc.body.querySelectorAll("*")

  for (const element of elements) {
    if (blockedTags.has(element.tagName.toLowerCase())) return false
    for (const attr of element.attributes) {
      if (/^(?:on.*|(?:form).*|action)$/i.test(attr.name)) return false
      if (/javascript:|data:/i.test(attr.value)) return false
    }
  }
  return true
}

function formatChatMessage(value) {
  const string = String(value ?? "")
  if (string.startsWith("Server: ")) {
    const messageContent = string.slice(8)
    if (messageContent.includes("<") && messageContent.includes(">") && isSafeServerHtml(messageContent)) {
      return `Server: ${messageContent}`
    }
  }

  // ^#RRGGBB / ^@RRGGBB are arbitrary text/background colours; only validated hex reaches the style attribute.
  const tokens = string.split(/(\^(?:\+{1,2}|[#@][0-9a-fA-F]{6}|.))/g)
  const classes = new Set()
  let inlineColor = ""
  let inlineBackground = ""
  let currentText = ""
  let result = ""

  const isForegroundClass = (cls) => cls.startsWith("color-") || cls === "rainbow"
  const isBackgroundClass = (cls) => cls.startsWith("bg-")
  const isFontClass = (cls) => cls.startsWith("font-")
  const isTypefaceClass = (cls) => cls.startsWith("typeface-")

  const clearForeground = () => {
    for (const activeClass of [...classes]) {
      if (isForegroundClass(activeClass)) classes.delete(activeClass)
    }
    inlineColor = ""
  }

  const clearBackground = () => {
    for (const activeClass of [...classes]) {
      if (isBackgroundClass(activeClass)) classes.delete(activeClass)
    }
    inlineBackground = ""
  }

  const clearFont = () => {
    for (const activeClass of [...classes]) {
      if (isFontClass(activeClass)) classes.delete(activeClass)
    }
  }

  const clearTypeface = () => {
    for (const activeClass of [...classes]) {
      if (isTypefaceClass(activeClass)) classes.delete(activeClass)
    }
  }

  const flush = () => {
    if (!currentText) return
    const encoded = escapeHtml(currentText)
    const classList = Array.from(classes).join(" ")
    const styles = []
    if (inlineColor) styles.push(`color:${inlineColor}`)
    if (inlineBackground) styles.push(`background-color:${inlineBackground}`)
    const classAttr = classList ? ` class="${classList}"` : ""
    const styleAttr = styles.length ? ` style="${styles.join(";")}"` : ""
    result += classAttr || styleAttr ? `<span${classAttr}${styleAttr}>${encoded}</span>` : encoded
    currentText = ""
  }

  for (let index = 0; index < tokens.length; index += 1) {
    const token = tokens[index]
    const nextToken = tokens[index + 1]?.trim() || ""

    if (/^\^/.test(token)) {
      flush()
      if (token === "^r") {
        classes.clear()
        inlineColor = ""
        inlineBackground = ""
      } else if (token === "^p") {
        result += "<br>"
      } else if (token === "^*") {
        const cls = globalThis.beammpTextStyleMap?.[token]
        if (cls) classes.add(cls)
        if (globalThis.iconsOrig?.[nextToken]) currentText = globalThis.iconsOrig[nextToken].glyph
      } else if (/^\^#[0-9a-fA-F]{6}$/.test(token)) {
        clearForeground()
        inlineColor = `#${token.slice(2)}`
      } else if (/^\^@[0-9a-fA-F]{6}$/.test(token)) {
        clearBackground()
        inlineBackground = `#${token.slice(2)}`
      } else {
        const cls = globalThis.beammpTextStyleMap?.[token]
        if (cls && isForegroundClass(cls)) {
          clearForeground()
          classes.add(cls)
        } else if (cls && isBackgroundClass(cls)) {
          clearBackground()
          classes.add(cls)
        } else if (cls && isFontClass(cls)) {
          clearFont()
          classes.add(cls)
        } else if (cls && isTypefaceClass(cls)) {
          clearTypeface()
          classes.add(cls)
        } else if (cls) {
          classes.add(cls)
        }
      }
    } else if (tokens[index - 1] !== "^*") {
      currentText += token
    }
  }

  flush()
  return result
}

function storeChatMessages() {
  localStorage.setItem(
    "chatMessages",
    JSON.stringify(messages.value.slice(-70).map((message) => ({
      message: message.raw,
      time: message.time,
      color: message.color,
    })))
  )
}

function loadStoredMessages() {
  const storedMessages = localStorage.getItem("chatMessages")
  if (!storedMessages) return

  try {
    const parsed = JSON.parse(storedMessages)
    if (!Array.isArray(parsed)) return
    messages.value = parsed.slice(-70).map((entry, index) => createMessage(entry.message, entry.time, `stored-${index}`, entry.color))
  } catch {
    messages.value = []
  }
}

function createMessage(message, time, key, color = null) {
  const raw = String(message ?? "")
  const isServerMessage = raw.startsWith("Server: ")
  let clean = raw
  let hideTimestamp = false
  let hideServerPrefix = false

  if (isServerMessage) {
    // ^t and ^x are per-message flags, not formatting styles.
    hideTimestamp = raw.includes("^t")
    hideServerPrefix = raw.includes("^x")
    clean = raw.replace(/\^[tx]/g, "")
  }

  let formatted = isServerMessage ? formatChatMessage(clean) : ""
  if (hideServerPrefix) formatted = formatted.replace(/^Server: /, "")

  let nameColor = isServerMessage ? null : colorToRgba(color)
  let username = ""
  let text = raw

  if (nameColor) {
    const usernameEnd = raw.indexOf(": ")
    if (usernameEnd > 0) {
      username = raw.slice(0, usernameEnd + 2)
      text = raw.slice(usernameEnd + 2)
    } else {
      nameColor = null
    }
  }

  return {
    key,
    raw,
    color,
    text,
    username,
    nameColor,
    html: formatted,
    isServerMessage,
    hideTimestamp,
    time,
    createdAt: Date.now(),
  }
}

function currentTimeString() {
  const now = new Date()
  const hours = String(now.getHours()).padStart(2, "0")
  const minutes = String(now.getMinutes()).padStart(2, "0")
  const seconds = String(now.getSeconds()).padStart(2, "0")
  return `${hours}:${minutes}:${seconds}`
}

function scrollToLastMessage() {
  nextTick(() => {
    const chatWindow = chatWindowRef.value
    const chatList = chatListRef.value
    if (!chatWindow || !chatList) return
    const isReversed = getComputedStyle(chatWindow).flexDirection === "column-reverse"
    chatList.scrollTop = isReversed ? -chatList.scrollHeight : chatList.scrollHeight
  })
}

function messageStyle(message) {
  if (enableNewChatMenu.value || isHovered.value || isFocused.value) {
    return { opacity: 1 }
  }

  const visibleFor = 3500
  const fadeDuration = 1000
  const elapsed = nowTick.value - message.createdAt
  if (elapsed <= visibleFor) return { opacity: 1 }

  const fadeProgress = Math.max(0, 1 - ((elapsed - visibleFor) / fadeDuration))
  return { opacity: fadeProgress }
}

function persistDirection() {
  localStorage.setItem("chatHorizontal", chatHorizontal.value)
  localStorage.setItem("chatVertical", chatVertical.value)
}

function swapHorizontal() {
  if (chatHorizontal.value === "left") chatHorizontal.value = "middle"
  else if (chatHorizontal.value === "middle") chatHorizontal.value = "right"
  else chatHorizontal.value = "left"
  persistDirection()
  scrollToLastMessage()
}

function swapVertical() {
  chatVertical.value = chatVertical.value === "top" ? "bottom" : "top"
  persistDirection()
  scrollToLastMessage()
}

function focusChat() {
  isFocused.value = true
  api.engineLua("setCEFFocus(true)")
}

function blurChat() {
  isFocused.value = false
}

function sendChat() {
  const text = inputText.value
  if (!text) return

  lastSentMessage.value = text
  if (text.length > 500) {
    addMessage("Your message is over the character limit! (500)")
    return
  }

  api.engineLua(`UI.chatSend(${api.serializeToLua(text)})`)
  inputText.value = ""
}

function onInputKeydown(event) {
  if (event.key === "ArrowUp") {
    inputText.value = lastSentMessage.value
    nextTick(() => {
      const input = chatInputRef.value
      input?.setSelectionRange(lastSentMessage.value.length, lastSentMessage.value.length)
    })
  } else if (event.key === "Enter") {
    event.preventDefault()
    event.stopPropagation()
    sendChat()
  }
}

function addMessage(message, time = currentTimeString(), messageId = null, color = null) {
  const entry = createMessage(message, time, messageId ?? `local-${Date.now()}-${messages.value.length}`, color)
  messages.value = [...messages.value, entry].slice(-70)
  storeChatMessages()
  scrollToLastMessage()
}

function onBeamMPChatMessage(payload) {
  if (!payload || payload.id <= lastMessageId.value) return
  lastMessageId.value = payload.id
  const time = currentTimeString()
  addMessage(payload.message, time, `remote-${payload.id}`, payload.colorRgb || payload.color)
}

function onClearHistory() {
  localStorage.removeItem("chatMessages")
}

function onSettingsChanged(payload) {
  const values = payload?.values || {}
  if (Object.prototype.hasOwnProperty.call(values, "enableNewChatMenu")) {
    enableNewChatMenu.value = Boolean(values.enableNewChatMenu)
  }
  scrollToLastMessage()
}

function requestSetting(settingName, setter, fallback) {
  api.engineLua(`settings.getValue(${api.serializeToLua(settingName)})`, (value) => {
    setter(value ?? fallback)
  })
}

onMounted(() => {
  persistDirection()
  loadStoredMessages()
  requestSetting("enableNewChatMenu", (value) => {
    enableNewChatMenu.value = Boolean(value)
  }, false)

  events.on("onBeamMPChatMessage", onBeamMPChatMessage)
  events.on("onBeamMPClearChatHistory", onClearHistory)
  events.on("SettingsChanged", onSettingsChanged)

  fadeTimer = window.setInterval(() => {
    nowTick.value = Date.now()
  }, 100)

  scrollToLastMessage()
})

onUnmounted(() => {
  events.off("onBeamMPChatMessage", onBeamMPChatMessage)
  events.off("onBeamMPClearChatHistory", onClearHistory)
  events.off("SettingsChanged", onSettingsChanged)

  if (fadeTimer) {
    window.clearInterval(fadeTimer)
    fadeTimer = null
  }
})
</script>

<style lang="scss">
@import url("/ui/assets/BeamMP/shared_styles/formatCodes.css");

.beammpChat2 {
  box-sizing: border-box;
  width: 100%;
  height: 100%;
  color: var(--bng-off-white);
}

.beammpChat2 *,
.beammpChat2 *::before,
.beammpChat2 *::after {
  box-sizing: border-box;
}

.beammpChat2 .chat-window {
  display: flex;
  width: 100%;
  height: 100%;
  min-width: 0;
  min-height: 0;
  gap: 0.35rem;
  padding: 0.25rem;
  font-size: 1rem;
}

.beammpChat2 .chat-list {
  display: flex;
  width: 100%;
  min-height: 0;
  flex: 1 1 auto;
  gap: 0.1rem;
  padding: 0;
  overflow-x: hidden;
  overflow-y: auto;
  overflow-wrap: anywhere;
  list-style: none;
}

.beammpChat2 .chat-message {
  padding: 0.32rem 0.5rem;
  border-left: 0.16rem solid transparent;
  border-radius: var(--bng-corners-1, 3px);
  background: rgba(var(--bng-cool-gray-900-rgb), 0.76);
  color: var(--bng-off-white);
  line-height: 1.3;
  text-shadow: 0 1px 2px rgba(var(--bng-off-black-rgb), 0.95);
  transition: border-color 100ms ease, background-color 100ms ease, opacity 120ms ease;
}

.beammpChat2 .chat-message:nth-child(2n + 1) {
  background: rgba(var(--bng-cool-gray-800-rgb), 0.7);
}

.beammpChat2 .chat-message:hover {
  border-left-color: var(--bng-orange-500);
  background: rgba(var(--bng-cool-gray-700-rgb), 0.82);
}

.beammpChat2 .chat-message-content {
  white-space: pre-wrap;
}

.beammpChat2 .chat-message-timestamp {
  padding-right: 0.45rem;
  color: var(--bng-cool-gray-300);
  font-family: "Noto Sans Mono", monospace;
  font-size: 0.75em;
  font-variant-numeric: tabular-nums;
  line-height: 1;
}

.beammpChat2 .chatbox {
  display: flex;
  width: 100%;
  min-width: 0;
  min-height: 2.6rem;
  flex: 0 0 auto;
  align-items: stretch;
  overflow: hidden;
  border: 1px solid rgba(var(--bng-cool-gray-300-rgb), 0.4);
  border-left: 0.2rem solid var(--bng-orange-500);
  border-radius: var(--bng-corners-2, 6px);
  background: rgba(var(--bng-cool-gray-900-rgb), 0.9);
  box-shadow: 0 0.2rem 0.75rem rgba(var(--bng-off-black-rgb), 0.3);
  backdrop-filter: blur(10px);
  transition: border-color 100ms ease, background-color 100ms ease, box-shadow 100ms ease;
}

.beammpChat2 .chatbox:hover {
  border-color: rgba(var(--bng-cool-gray-100-rgb), 0.6);
  border-left-color: var(--bng-orange-500);
  background: rgba(var(--bng-cool-gray-800-rgb), 0.94);
}

.beammpChat2 .chatbox:focus-within {
  border-color: var(--bng-orange-400);
  box-shadow: 0 0 0 0.12rem rgba(var(--bng-orange-500-rgb), 0.35), 0 0.2rem 0.75rem rgba(var(--bng-off-black-rgb), 0.35);
}

.beammpChat2 .chat2-message-input {
  width: 100%;
  height: 100%;
  min-width: 0;
  flex: 1 1 auto;
  padding: 0.45rem 0.65rem;
  border: 0;
  outline: 0;
  background: transparent;
  color: var(--bng-off-white);
  font: inherit;
}

.beammpChat2 .chat2-message-input:focus {
  background: rgba(var(--bng-cool-gray-800-rgb), 0.5);
}

.beammpChat2 .chat2-message-input::placeholder {
  color: var(--bng-cool-gray-300);
}

.beammpChat2 .chat-control-button {
  min-width: 2.35rem;
  height: auto;
  margin: 0;
  padding: 0 0.55rem;
  border: 0;
  border-left: 1px solid rgba(var(--bng-cool-gray-300-rgb), 0.2);
  background: rgba(var(--bng-cool-gray-700-rgb), 0.52);
  color: var(--bng-cool-gray-100);
  cursor: pointer;
  font-family: var(--bmp-fnt-defs);
  font-weight: 700;
  text-align: center;
  transition: background-color 100ms ease, color 100ms ease;
}

.beammpChat2 .chat-control-button:hover,
.beammpChat2 .chat-control-button:focus-visible {
  outline: 0;
  background: rgba(var(--bng-orange-500-rgb), 0.32);
  color: var(--bng-off-white);
}

.beammpChat2 .chatbox > .chat2-send-button {
  min-width: 3.7rem;
  flex: 0 0 3.7rem;
  border-left: 0;
  border-right: 1px solid rgba(var(--bng-cool-gray-300-rgb), 0.2);
  background: rgba(var(--bng-orange-500-rgb), 0.85) !important;
  color: var(--bng-off-white) !important;
}

.beammpChat2 .chatbox > .chat2-send-button:hover,
.beammpChat2 .chatbox > .chat2-send-button:focus-visible {
  background: var(--bng-orange-500) !important;
}

.beammpChat2 .chatbox > .chat2-swap-button {
  flex: 0 0 2.35rem;
  padding: 0;
  border-left: 1px solid rgba(var(--bng-cool-gray-300-rgb), 0.2) !important;
  background: rgba(var(--bng-cool-gray-700-rgb), 0.52) !important;
  color: var(--bng-cool-gray-100) !important;
}

.beammpChat2 .chatbox > .chat2-swap-button:hover,
.beammpChat2 .chatbox > .chat2-swap-button:focus-visible {
  background: rgba(var(--bng-orange-500-rgb), 0.32) !important;
  color: var(--bng-off-white) !important;
}

.beammpChat2 .chat-list::-webkit-scrollbar {
  width: 0.3rem;
}

.beammpChat2 .chat-list::-webkit-scrollbar-track {
  border-radius: 0.2rem;
  background: rgba(var(--bng-cool-gray-900-rgb), 0.75);
}

.beammpChat2 .chat-list::-webkit-scrollbar-thumb {
  border-radius: 0.2rem;
  background: rgba(var(--bng-orange-500-rgb), 0.85);
}

.beammpChat2 .chat-list--scrollbar-hidden {
  scrollbar-width: none;
}

.beammpChat2 .chat-list--scrollbar-hidden::-webkit-scrollbar {
  display: none !important;
  width: 0 !important;
  height: 0 !important;
}

@media (max-width: 420px) {
  .beammpChat2 .chat-window {
    font-size: 0.75rem;
  }

  .beammpChat2 .chat2-send-button {
    min-width: 2.5rem;
    flex-basis: 2.5rem;
    overflow: hidden;
    font-size: 0;
  }

  .beammpChat2 .chat2-send-button::before {
    content: "↗";
    font-size: 1rem;
  }
}
</style>