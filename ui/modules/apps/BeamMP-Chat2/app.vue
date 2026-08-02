<template>
  <div
    class="beammpChat2"
    :class="{ 'ui-style-redesigned': useUiAppRedesign }"
    @mouseenter="isHovered = true"
    @mouseleave="isHovered = false"
  >
    <div v-show="!enableNewChatMenu" ref="chatWindowRef" class="chat-window" :style="chatWindowStyle">
      <ul ref="chatListRef" class="chat-list" :style="chatListStyle">
        <li
          v-for="message in messages"
          :key="message.key"
          class="chat-message"
          :style="messageStyle(message)"
        >
          <span class="chat-message-timestamp">{{ message.time }}</span>
          <span v-if="message.html" class="chat-message-content" v-html="message.html"></span>
          <span v-else class="chat-message-content">{{ message.text }}</span>
        </li>
      </ul>

      <form ref="chatBoxRef" class="chatbox" :style="chatBoxStyle" @submit.prevent="sendChat">
        <button
          class="buttons send-button"
          type="submit"
          :title="$tt('ui.apps.beammp.chat.send') || 'Send message'"
          :aria-label="$tt('ui.apps.beammp.chat.send') || 'Send message'"
        >
          {{ sendButtonText }}
        </button>
        <input
          ref="chatInputRef"
          v-model="inputText"
          class="chat-input"
          type="text"
          maxlength="500"
          autocomplete="off"
          :placeholder="$tt('ui.apps.beammp.chat.placeholder') || 'Chat here'"
          :aria-label="$tt('ui.apps.beammp.chat.input') || 'BeamMP chat message'"
          @focus="focusChat"
          @mouseenter="isHovered = true"
          @mouseleave="isHovered = false"
          @keydown="onInputKeydown"
        >
        <button
          class="buttons swap-buttons"
          type="button"
          :title="$tt('ui.apps.beammp.chat.moveHorizontal') || 'Move chat horizontally'"
          :aria-label="$tt('ui.apps.beammp.chat.moveHorizontal') || 'Move chat horizontally'"
          @click="swapHorizontal"
        >
          ↔
        </button>
        <button
          class="buttons swap-buttons"
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
const useUiAppRedesign = ref(false)
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

const chatListStyle = computed(() => ({
  flexDirection: chatVertical.value === "top" ? "column-reverse" : "column",
  marginTop: chatVertical.value === "top" ? "0px" : "auto",
  marginBottom: chatVertical.value === "top" ? "auto" : "0px",
}))

const chatBoxStyle = computed(() => ({
  flexDirection: chatHorizontal.value === "right" ? "row-reverse" : "row",
  marginLeft: chatHorizontal.value === "right" ? "auto" : "0px",
}))

const sendButtonText = computed(() => (useUiAppRedesign.value ? "💬" : "Send"))

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#39;")
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

  const tokens = string.split(/(\^.)/g)
  const classes = new Set()
  let currentText = ""
  let result = ""

  const flush = () => {
    if (!currentText) return
    const encoded = escapeHtml(currentText)
    const classList = Array.from(classes).join(" ")
    result += classList ? `<span class="${classList}">${encoded}</span>` : encoded
    currentText = ""
  }

  for (let index = 0; index < tokens.length; index += 1) {
    const token = tokens[index]
    const nextToken = tokens[index + 1]?.trim() || ""

    if (/^\^.$/.test(token)) {
      flush()
      if (token === "^r") {
        classes.clear()
      } else if (token === "^p") {
        result += "<br>"
      } else if (token === "^*") {
        const cls = globalThis.beammpTextStyleMap?.[token]
        if (cls) classes.add(cls)
        if (globalThis.iconsOrig?.[nextToken]) currentText = globalThis.iconsOrig[nextToken].glyph
      } else {
        const cls = globalThis.beammpTextStyleMap?.[token]
        if (cls?.startsWith("color-")) {
          for (const activeClass of [...classes]) {
            if (activeClass.startsWith("color-")) classes.delete(activeClass)
          }
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
    })))
  )
}

function loadStoredMessages() {
  const storedMessages = localStorage.getItem("chatMessages")
  if (!storedMessages) return

  try {
    const parsed = JSON.parse(storedMessages)
    if (!Array.isArray(parsed)) return
    messages.value = parsed.slice(-70).map((entry, index) => createMessage(entry.message, entry.time, `stored-${index}`))
  } catch {
    messages.value = []
  }
}

function createMessage(message, time, key) {
  const raw = String(message ?? "")
  const formatted = raw.startsWith("Server: ") ? formatChatMessage(raw) : ""
  return {
    key,
    raw,
    text: raw,
    html: formatted,
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

function addMessage(message, time = currentTimeString(), messageId = null) {
  const entry = createMessage(message, time, messageId ?? `local-${Date.now()}-${messages.value.length}`)
  messages.value = [...messages.value, entry].slice(-70)
  storeChatMessages()
  scrollToLastMessage()
}

function onChatMessage(payload) {
  if (!payload || payload.id <= lastMessageId.value) return
  lastMessageId.value = payload.id
  const time = currentTimeString()
  addMessage(payload.message, time, `remote-${payload.id}`)
}

function onClearHistory() {
  localStorage.removeItem("chatMessages")
}

function onSettingsChanged(payload) {
  const values = payload?.values || {}
  if (Object.prototype.hasOwnProperty.call(values, "useUiAppRedesign")) {
    useUiAppRedesign.value = Boolean(values.useUiAppRedesign)
  }
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
  requestSetting("useUiAppRedesign", (value) => {
    useUiAppRedesign.value = Boolean(value)
  }, false)
  requestSetting("enableNewChatMenu", (value) => {
    enableNewChatMenu.value = Boolean(value)
  }, false)

  events.on("onBeamMPChatMessage", onChatMessage)
  events.on("onBeamMPClearChatHistory", onClearHistory)
  events.on("SettingsChanged", onSettingsChanged)

  chatInputRef.value?.addEventListener("blur", blurChat)

  fadeTimer = window.setInterval(() => {
    nowTick.value = Date.now()
  }, 100)

  scrollToLastMessage()
})

onUnmounted(() => {
  events.off("onBeamMPChatMessage", onChatMessage)
  events.off("onBeamMPClearChatHistory", onClearHistory)
  events.off("SettingsChanged", onSettingsChanged)

  chatInputRef.value?.removeEventListener("blur", blurChat)

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
  font-family: var(--bmp-fnt-defs);
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
  font-size: 0.9rem;
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
  scrollbar-gutter: stable;
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

.beammpChat2.ui-style-redesigned .chat-message {
  border-left-width: 0;
  background: transparent;
  text-shadow: 0 0 4px #000, 0 0 6px #000, 0 0 8px #000;
  transition: transform 120ms ease, opacity 120ms ease;
}

.beammpChat2.ui-style-redesigned .chat-message:hover {
  transform: translateY(-2px);
  background: transparent;
}

.beammpChat2 .chat-message-timestamp {
  padding-right: 0.45rem;
  color: var(--bng-cool-gray-300);
  font-family: "VueNotoSans Mono", monospace;
  font-size: 0.72em;
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

.beammpChat2.ui-style-redesigned .chatbox {
  width: 250px;
  min-height: 40px;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 8px;
  border-left-width: 1px;
  background-color: rgba(30, 30, 30, 0.25);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2);
  transition: width 0.2s ease-in-out, background-color 0.3s ease;
  transition-delay: 700ms;
  align-items: center;
}

.beammpChat2.ui-style-redesigned .chatbox:hover {
  width: 100%;
  transition-delay: 0ms;
  background-color: rgba(30, 30, 30, 0.4);
}

.beammpChat2 .chat-input {
  width: 100%;
  min-width: 0;
  flex: 1 1 auto;
  padding: 0.45rem 0.65rem;
  border: 0;
  outline: 0;
  background: transparent;
  color: var(--bng-off-white);
  font: inherit;
}

.beammpChat2 .chat-input::placeholder {
  color: var(--bng-cool-gray-300);
}

.beammpChat2 .buttons {
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

.beammpChat2 .buttons:hover,
.beammpChat2 .buttons:focus-visible {
  outline: 0;
  background: rgba(var(--bng-orange-500-rgb), 0.32);
  color: var(--bng-off-white);
}

.beammpChat2.ui-style-redesigned .buttons {
  border-left: 0;
  background-color: transparent;
  color: #dddddd;
}

.beammpChat2.ui-style-redesigned .buttons:hover,
.beammpChat2.ui-style-redesigned .buttons:focus-visible {
  background-color: rgba(0, 0, 0, 0.2);
  color: #ffffff;
}

.beammpChat2 .send-button {
  min-width: 3.7rem;
  border-left: 0;
  border-right: 1px solid rgba(var(--bng-cool-gray-300-rgb), 0.2);
  background: rgba(var(--bng-orange-500-rgb), 0.85);
  color: var(--bng-off-white);
}

.beammpChat2 .send-button:hover,
.beammpChat2 .send-button:focus-visible {
  background: var(--bng-orange-500);
}

.beammpChat2.ui-style-redesigned .send-button {
  border-right: 0;
  background: transparent;
}

.beammpChat2 .swap-buttons {
  flex: 0 0 2.35rem;
  padding: 0;
}

.beammpChat2 .chat-list::-webkit-scrollbar {
  width: 0.3rem;
}

.beammpChat2 .chat-list::-webkit-scrollbar-track {
  background: transparent;
}

.beammpChat2 .chat-list::-webkit-scrollbar-thumb {
  border-radius: 0.2rem;
  background: rgba(var(--bng-cool-gray-300-rgb), 0.55);
}

@media (max-width: 420px) {
  .beammpChat2 .chat-window {
    font-size: 0.82rem;
  }

  .beammpChat2 .send-button {
    min-width: 2.7rem;
    overflow: hidden;
    font-size: 0;
  }

  .beammpChat2 .send-button::before {
    content: "↗";
    font-size: 1rem;
  }
}
</style>