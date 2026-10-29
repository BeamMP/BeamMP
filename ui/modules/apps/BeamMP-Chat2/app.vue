<template>
  <div
    ref="chatAppRef"
    class="beammpChat2"
    :class="{ 'ui-style-redesigned': useUiAppRedesign }"
    @mouseenter="isHovered = true"
    @mouseleave="isHovered = false"
  >
    <div v-show="!enableNewChatMenu" ref="chatWindowRef" class="chat-window" :class="{ 'chat-window-top': chatVertical === 'top' }" :style="chatWindowStyle">
      <ul
        ref="chatListRef"
        class="chat-list"
        :class="{ 'chat-list-top': chatVertical === 'top' }"
        :style="chatListStyle"
        @scroll="handleChatScroll"
      >
        <li
          v-for="message in messages"
          :key="message.key"
          class="chat-message"
          :class="{
            'chat-message-server': message.isServer,
            'chat-message-mention': mentionsLocalUser(message),
            'chat-message-reply-target': message.key === activeReplyMessageKey,
          }"
          :style="messageStyle(message)"
        >
          <span v-if="!message.reply" class="chat-message-timestamp">{{ message.time }}</span>
          <div v-if="message.html && message.reply" class="chat-message-content" v-html="message.html"></div>
          <span v-else-if="message.html" class="chat-message-content" v-html="message.html"></span>
          <span v-else class="chat-message-content">{{ message.text }}</span>
          <button
            v-if="message.username && !message.isServer"
            class="chat-message-reply"
            type="button"
            :data-tooltip="$tt('ui.apps.beammp.chat.reply')"
            :aria-label="$tt('ui.apps.beammp.chat.reply')"
            @click.stop="replyToMessage(message)"
          >↩</button>
        </li>
      </ul>

      <button
        v-if="unreadMessages > 0"
        class="new-messages-indicator"
        :class="{ 'has-new-mention': unreadMentions > 0 }"
        type="button"
        aria-live="polite"
        @click="jumpToLatest"
      >
        <span>
          {{
            unreadMentions > 0 && unreadMessages === unreadMentions
              ? $tt("ui.apps.beammp.chat.newMention")
              : $tt("ui.apps.beammp.chat.newMessages")
          }}
        </span>
        <span class="new-messages-count">
          {{ unreadMentions > 0 && unreadMessages === unreadMentions ? unreadMentions : unreadMessages }}
        </span>
        <span v-if="unreadMentions > 0 && unreadMessages > unreadMentions">
          {{
            $tt("ui.apps.beammp.chat.includingMentions")
              .replace("{{count}}", unreadMentions)
          }}
        </span>
      </button>

      <div v-if="replyTarget" class="reply-composer">
        <div class="reply-composer-content">
          <span class="reply-composer-label">{{ $tt("ui.apps.beammp.chat.replyingTo") }}</span>
          <strong>{{ replyTarget.author }}</strong>
        </div>
        <button
          class="reply-composer-cancel"
          type="button"
          title="Cancel reply"
          aria-label="Cancel reply"
          @click="cancelReply"
        >×</button>
      </div>

      <form
        ref="chatBoxRef"
        class="chatbox"
        :style="chatBoxStyle"
        @focusin="focusChat"
        @focusout="blurChat"
        @submit.prevent="sendChat"
        @keydown.capture="onInputKeydown"
      >
        <div
          v-if="mentionQuery !== null && mentionSuggestions.length"
          class="mention-suggestions"
        >
          <div class="mention-suggestions-heading">
            {{ $tt("ui.apps.beammp.chat.mentionMembers") }}
          </div>
          <div
            class="mention-suggestion-list"
            :style="mentionSuggestionListStyle"
            role="listbox"
            :aria-label="$tt('ui.apps.beammp.chat.mentionMembers')"
          >
            <div
              v-for="(player, index) in mentionSuggestions"
              :key="`mention-${index}`"
              class="mention-suggestion"
              :class="{ selected: index === selectedMentionIndex }"
              role="option"
              :aria-selected="index === selectedMentionIndex"
              @mousedown.prevent
              @click="selectMention(player)"
            >
              <span class="mention-player-name">{{ player.name }}</span>
              <span class="mention-player-id">ID: {{ player.id }}</span>
            </div>
          </div>
        </div>
        <button
          class="buttons send-button"
		  id="send-button"
          type="submit"
          :title="$tt('ui.apps.beammp.chat.send')"
          :aria-label="$tt('ui.apps.beammp.chat.send')"
        >
          {{ sendButtonText }}
        </button>
        <div class="chat-input-wrap" :class="{ 'has-selection': hasInputSelection }">
          <div ref="chatInputHighlightRef" class="chat-input-highlight" aria-hidden="true">
            <span
              v-for="(segment, index) in chatInputSegments"
              :key="`input-segment-${index}`"
              :class="{ 'chat-input-mention': segment.isMention }"
            >{{ segment.text }}</span>
          </div>
          <input
            ref="chatInputRef"
            v-model="inputText"
            class="chat-input"
            :class="{ 'has-highlight-text': inputText.length > 0 }"
            type="text"
            :maxlength="inputMaxLength"
            autocomplete="off"
            :placeholder="$tt('ui.apps.beammp.chat.inputPlaceholder')"
            :aria-label="$tt('ui.apps.beammp.chat.inputPlaceholder')"
            @input="updateMentionSuggestions"
            @scroll="syncInputHighlight"
            @select="syncInputHighlight"
            @keyup="syncInputHighlight"
            @pointerup="syncInputHighlight"
            @keydown="onInputKeydown"
          />
        </div>
        <button
		  id="chat-horizontal-button"
          class="buttons swap-buttons"
          type="button"
          :title="$tt('ui.apps.beammp.chat.moveHorizontal')"
          :aria-label="$tt('ui.apps.beammp.chat.moveHorizontal')"
          @click="swapHorizontal"
        >
          ↔
        </button>
        <button
		  id="chat-vertical-button"
          class="buttons swap-buttons"
          type="button"
          :title="$tt('ui.apps.beammp.chat.moveVertical')"
          :aria-label="$tt('ui.apps.beammp.chat.moveVertical')"
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

const chatAppRef = ref(null)
const chatWindowRef = ref(null)
const chatListRef = ref(null)
const chatBoxRef = ref(null)
const chatInputRef = ref(null)
const chatInputHighlightRef = ref(null)
const inputText = ref("")
const replyTarget = ref(null)
const activeReplyMessageKey = ref(null)
const hasInputSelection = ref(false)
const messages = ref([])
const unreadMessages = ref(0)
const unreadMentions = ref(0)
const players = ref([])
const localUsername = ref("")
const mentionQuery = ref(null)
const selectedMentionIndex = ref(0)
const lastSentMessage = ref("")
const lastMessageId = ref(0)
const enableNewChatMenu = ref(false)
const useUiAppRedesign = ref(false)
const isHovered = ref(false)
const isFocused = ref(false)
const chatHorizontal = ref(localStorage.getItem("chatHorizontal") || "middle")
const chatVertical = ref(localStorage.getItem("chatVertical") || "bottom")
const nowTick = ref(Date.now())
const inputMaxLength = computed(() => 500 - (replyTarget.value?.prefix.length || 0))
const chatInputSegments = computed(() => buildMentionSegments(
  inputText.value,
  players.value.map(player => player.name)
))

let fadeTimer = null
let chatScrollAnimation = null
let chatScrollTarget = null
function comparePlayerIds(first, second) {
  const firstId = Number(first.id)
  const secondId = Number(second.id)
  if (Number.isFinite(firstId) && Number.isFinite(secondId)) return firstId - secondId
  if (Number.isFinite(firstId)) return -1
  if (Number.isFinite(secondId)) return 1
  return String(first.id).localeCompare(String(second.id))
}

const mentionSuggestions = computed(() => {
  if (mentionQuery.value === null) return []
  const query = mentionQuery.value.toLocaleLowerCase()
  const isIdQuery = /^\d+$/.test(query)
  return players.value
    .filter(player => {
      const name = typeof player.name === "string" ? player.name.toLocaleLowerCase() : ""
      const id = String(player.id).toLocaleLowerCase()
      return isIdQuery ? id.startsWith(query) : name.includes(query)
    })
    .sort((first, second) => {
      if (!query || isIdQuery) return comparePlayerIds(first, second)
      const rank = player => {
        const name = player.name.toLocaleLowerCase()
        return name.startsWith(query) ? 0 : 1
      }
      return rank(first) - rank(second) || comparePlayerIds(first, second)
    })
})

const mentionSuggestionListStyle = computed(() => ({
  height: `${Math.min(mentionSuggestions.value.length * 2.15, 6.45)}rem`,
}))

const chatWindowStyle = computed(() => ({
  flexDirection: chatVertical.value === "top" ? "column-reverse" : "column",
  alignItems: chatHorizontal.value === "middle" ? "center" : "flex-start",
}))

const chatListStyle = computed(() => ({
  flexDirection: chatVertical.value === "top" ? "column-reverse" : "column",
  justifyContent: "flex-start",
  marginTop: "0px",
  marginBottom: "0px",
}))

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

function stripChatFormatCodes(value) {
  return String(value ?? "").replace(/\^p/g, " ").replace(/\^./g, "").replace(/\s+/g, " ").trim()
}

function sanitizeReplyRoleColor(value) {
  return typeof value === "string" && /^#[0-9a-f]{6}$/i.test(value) ? value.toLowerCase() : ""
}

function getReplyRoleColor(roleTag, color) {
  if (typeof roleTag !== "string" || !roleTag.trim()) return ""
  const channels = [0, 1, 2].map(index => Number(color?.[index]))
  if (!channels.every(Number.isFinite)) return ""
  return `#${channels
    .map(channel => Math.round(Math.max(0, Math.min(255, channel))).toString(16).padStart(2, "0"))
    .join("")}`
}

function sanitizeReplyRoleTag(value) {
  return Array.from(stripChatFormatCodes(value))
    .slice(0, 32)
    .join("")
    .replace(/[{}|]/g, " ")
    .replace(/@/g, "＠")
}

function buildReplyPrefix(author, quote, roleColor, roleTag) {
  const safeRoleColor = sanitizeReplyRoleColor(roleColor)
  const safeRoleTag = sanitizeReplyRoleTag(roleTag)
  const safeAuthor = author.replace(/[|\]]/g, " ").replace(/@/g, "＠")
  const safeQuote = quote.replace(/\|/g, "¦").replace(/@/g, "＠")
  return `↪ [${safeAuthor}]${safeRoleColor ? ` {${safeRoleColor}}` : ""}${safeRoleTag ? ` {tag:${safeRoleTag}}` : ""} ${safeQuote} | `
}

function createReplyTarget(author, value, roleColor = "", roleTag = "") {
  let authorText = Array.from(stripChatFormatCodes(author)).slice(0, 48).join("")
  let quote = truncateReplyQuote(value)
  roleColor = sanitizeReplyRoleColor(roleColor)
  roleTag = sanitizeReplyRoleTag(roleTag)

  let prefix = buildReplyPrefix(authorText, quote, roleColor, roleTag)
  while (prefix.length > 300 && quote.length > 0) {
    quote = Array.from(quote).slice(0, -1).join("")
    prefix = buildReplyPrefix(authorText, quote, roleColor, roleTag)
  }
  while (prefix.length > 300 && authorText.length > 0) {
    authorText = Array.from(authorText).slice(0, -1).join("")
    prefix = buildReplyPrefix(authorText, quote, roleColor, roleTag)
  }
  return { author: authorText, quote, roleColor, roleTag, prefix }
}

function truncateReplyQuote(value) {
  const characters = Array.from(stripChatFormatCodes(value))
  return characters.length > 50 ? `${characters.slice(0, 50).join("")}…` : characters.join("")
}

function decodeReplyMessage(value) {
  const match = String(value ?? "").match(/^↪ \[([^\]]*)\](?: \{(#[0-9a-f]{6})\})?(?: \{tag:([^{}|]*)\})? ([\s\S]*?) \| /i)
  if (!match) return null

  return {
    author: match[1],
    roleColor: sanitizeReplyRoleColor(match[2]),
    roleTag: sanitizeReplyRoleTag(match[3]),
    quote: match[4],
    body: String(value).slice(match[0].length),
  }
}

function replyToMessage(message) {
  const body = typeof message.body === "string" ? message.body : message.raw
  const decoded = decodeReplyMessage(body)
  const quote = decoded?.body ?? body
  replyTarget.value = createReplyTarget(message.username, quote, message.replyRoleColor, message.replyRoleTag)
  activeReplyMessageKey.value = message.key
  nextTick(() => chatInputRef.value?.focus())
}

function cancelReply() {
  replyTarget.value = null
  activeReplyMessageKey.value = null
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

function buildMentionSegments(value, usernames) {
  const names = [...new Set(usernames.filter(name => typeof name === "string" && name.length))]
    .sort((first, second) => second.length - first.length)
  if (!names.length) return [{ text: value, isMention: false }]

  const alternatives = names.map(name => name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
  const mentionPattern = new RegExp(`(^|[^\\w])(@(?:${alternatives.join("|")}))(?=$|[^\\w])`, "gi")
  const segments = []
  let lastIndex = 0
  for (const match of value.matchAll(mentionPattern)) {
    const mentionIndex = match.index + match[1].length
    if (mentionIndex > lastIndex) {
      segments.push({ text: value.slice(lastIndex, mentionIndex), isMention: false })
    }
    segments.push({ text: match[2], isMention: true })
    lastIndex = mentionIndex + match[2].length
  }
  if (lastIndex < value.length || !segments.length) {
    segments.push({ text: value.slice(lastIndex), isMention: false })
  }
  return segments
}

function formatTextWithMention(value, username) {
  const usernames = [username].filter(name => typeof name === "string" && name.length)
  const names = [...new Set(usernames
    .filter(name => typeof name === "string" && name.length)
    .sort((first, second) => second.length - first.length))]
  if (!names.length) return escapeHtml(value)
  const alternatives = names.map(name => name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
  const mentionPattern = new RegExp(`(^|[^\\w])(@(?:${alternatives.join("|")}))(?=$|[^\\w])`, "gi")
  let result = ""
  let lastIndex = 0

  for (const match of value.matchAll(mentionPattern)) {
    const mentionIndex = match.index + match[1].length
    result += escapeHtml(value.slice(lastIndex, mentionIndex))
    result += `<span class="chat-mention">${escapeHtml(match[2])}</span>`
    lastIndex = mentionIndex + match[2].length
  }
  return result + escapeHtml(value.slice(lastIndex))
}

function formatChatMessage(value, username = localUsername.value) {
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
    const encoded = formatTextWithMention(currentText, username)
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
      username: message.username,
      roleTag: message.roleTag,
      body: message.body,
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
    messages.value = parsed.slice(-70).map((entry, index) => createMessage(entry.message, entry.time, `stored-${index}`, entry))
  } catch {
    messages.value = []
  }
}

function createMessage(message, time, key, chatData = null) {
  const raw = String(message ?? "")
  const hasChatIdentity = typeof chatData?.username === "string" && typeof chatData?.body === "string"
  const isServer = chatData?.username === "Server" || raw.startsWith("Server: ")
  const reply = hasChatIdentity ? decodeReplyMessage(chatData.body) : null
  let formatted = ""

  if (isServer) {
    formatted = formatChatMessage(raw)
  } else if (hasChatIdentity) {
    const channels = [0, 1, 2].map(index => Number(chatData.color?.[index]))
    const roleColor = channels.every(Number.isFinite)
      ? ` style="color: rgb(${channels.map(channel => Math.max(0, Math.min(255, channel))).join(", ")})"`
      : ""
    const roleTag = chatData.roleTag ? `${escapeHtml(chatData.roleTag)} ` : ""
    const replyAuthorStyle = reply?.roleColor ? ` style="color: ${reply.roleColor}"` : ""
    const replyRoleTag = reply?.roleTag
      ? `<span class="chat-message-reply-role"${replyAuthorStyle}>${escapeHtml(reply.roleTag)} </span>`
      : ""
    const messageBody = reply?.body ?? chatData.body
    const replyPreview = reply
      ? `<span class="chat-message-reply-preview"><span class="chat-message-reply-arrow">↪</span>${replyRoleTag}<span class="chat-message-reply-author"${replyAuthorStyle}>${escapeHtml(reply.author)}</span>: <span class="chat-message-reply-quote">${formatTextWithMention(truncateReplyQuote(reply.quote), localUsername.value)}</span></span><span class="chat-message-reply-content"><span class="chat-message-timestamp">${escapeHtml(time)}</span><span${roleColor} class="chat-message-identity">${roleTag}${escapeHtml(chatData.username)}</span>: <span class="chat-message-reply-body">${formatTextWithMention(messageBody, localUsername.value)}</span></span>`
      : formatTextWithMention(messageBody, localUsername.value)
    formatted = reply
      ? replyPreview
      : `<span${roleColor} class="chat-message-identity">${roleTag}${escapeHtml(chatData.username)}</span>: ${replyPreview}`
  }

  return {
    key,
    raw,
    text: raw,
    html: formatted,
    username: hasChatIdentity ? chatData.username : null,
    roleTag: hasChatIdentity ? chatData.roleTag : null,
    replyRoleColor: hasChatIdentity ? getReplyRoleColor(chatData.roleTag, chatData.color) : "",
    replyRoleTag: hasChatIdentity ? sanitizeReplyRoleTag(chatData.roleTag) : "",
    body: hasChatIdentity ? chatData.body : null,
    reply,
    color: hasChatIdentity ? chatData.color : null,
    isServer,
    time,
    createdAt: Date.now(),
  }
}

function mentionsLocalUser(message) {
  const username = localUsername.value
  const rawText = typeof message.body === "string" ? message.body : message.raw
  const reply = decodeReplyMessage(rawText)
  if (reply?.author && username && reply.author.toLowerCase() === username.toLowerCase()) return true
  const text = reply?.body ?? rawText
  if (!username || !text) return false
  const escapedUsername = username.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
  return new RegExp(`(^|[^\\w])@${escapedUsername}(?=$|[^\\w])`, "i").test(text)
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
    if (chatScrollAnimation !== null) {
      cancelAnimationFrame(chatScrollAnimation)
      chatScrollAnimation = null
    }
    chatScrollTarget = null
    const isReversed = getComputedStyle(chatWindow).flexDirection === "column-reverse"
    chatList.scrollTop = isReversed ? -chatList.scrollHeight : chatList.scrollHeight
  })
}

function isFollowingLatestMessage(chatList = chatListRef.value) {
  if (!chatList) return true
  const isReversed = getComputedStyle(chatList).flexDirection === "column-reverse"
  const distanceFromLatest = isReversed
    ? Math.abs(chatList.scrollTop - (chatList.clientHeight - chatList.scrollHeight))
    : chatList.scrollHeight - chatList.clientHeight - chatList.scrollTop
  return distanceFromLatest <= 32
}

function handleChatScroll() {
  if (unreadMessages.value > 0 && isFollowingLatestMessage()) {
    clearUnreadMessages()
  }
}

function clearUnreadMessages() {
  unreadMessages.value = 0
  unreadMentions.value = 0
}

function jumpToLatest() {
  scrollToLastMessage()
  clearUnreadMessages()
}

function syncInputHighlight() {
  const input = chatInputRef.value
  const highlight = chatInputHighlightRef.value
  if (input && highlight) highlight.scrollLeft = input.scrollLeft
  if (input) hasInputSelection.value = input.selectionStart !== input.selectionEnd
}

function scheduleInputHighlightScroll() {
  requestAnimationFrame(syncInputHighlight)
}

function updateMentionSuggestions() {
  const input = chatInputRef.value
  if (!input) {
    mentionQuery.value = null
    return
  }
  const beforeCursor = input.value.slice(0, input.selectionStart ?? input.value.length)
  const match = beforeCursor.match(/(?:^|\s)@([^\s@]*)$/)
  const wasMentionActive = mentionQuery.value !== null
  const nextMentionQuery = match ? match[1] : null
  if (nextMentionQuery !== mentionQuery.value) {
    selectedMentionIndex.value = 0
  }
  mentionQuery.value = nextMentionQuery
  nextTick(scheduleInputHighlightScroll)
  if (mentionQuery.value !== null && !wasMentionActive) {
    api.engineLua("UI.updatePlayersList()")
  }
  selectedMentionIndex.value = mentionSuggestions.value.length
    ? Math.min(selectedMentionIndex.value, mentionSuggestions.value.length - 1)
    : 0
}

function scrollSelectedMentionIntoView() {
  const list = chatBoxRef.value?.querySelector(".mention-suggestion-list")
  const selected = list?.querySelector(".mention-suggestion.selected")
  if (!list || !selected) return
  const listRect = list.getBoundingClientRect()
  const selectedRect = selected.getBoundingClientRect()
  if (selectedRect.bottom > listRect.bottom) {
    list.scrollTop += selectedRect.bottom - listRect.bottom
  } else if (selectedRect.top < listRect.top) {
    list.scrollTop -= listRect.top - selectedRect.top
  }
}

function handleChatAtSignKeydown(event) {
  const input = chatInputRef.value
  if (!input || document.activeElement !== input || enableNewChatMenu.value) return

  const isAtSign = event.key === "@" || (
    event.key === "à"
    && (event.ctrlKey || event.altKey || event.getModifierState("AltGraph"))
  )
  const isAltGrZero = (event.ctrlKey || event.altKey || event.getModifierState("AltGraph"))
    && !event.metaKey
    && (event.code === "Digit0" || event.code === "Numpad0")
  const isCtrlZero = event.ctrlKey && !event.metaKey && (
    event.key === "0" || event.code === "Digit0" || event.code === "Numpad0"
  )
  if (!isAtSign && !isAltGrZero && !isCtrlZero) return

  event.preventDefault()
  event.stopImmediatePropagation()
  const start = input.selectionStart ?? input.value.length
  const end = input.selectionEnd ?? start
  input.setRangeText("@", start, end, "end")
  input.dispatchEvent(new Event("input", { bubbles: true }))
}

function selectMention(player) {
  const input = chatInputRef.value
  if (!input) return

  const caret = input.selectionStart ?? input.value.length
  const mentionStartIndex = input.value.slice(0, caret).lastIndexOf("@")
  if (mentionStartIndex < 0) return

  const insertion = `@${player.name} `
  inputText.value = `${input.value.slice(0, mentionStartIndex)}${insertion}${input.value.slice(caret)}`
  mentionQuery.value = null
  nextTick(() => {
    input.focus()
    const nextCaret = mentionStartIndex + insertion.length
    input.setSelectionRange(nextCaret, nextCaret)
    scheduleInputHighlightScroll()
  })
}

function scrollChatList(event) {
  const chatList = chatListRef.value
  if (!chatList) return

  const lineHeight = Number.parseFloat(getComputedStyle(chatList).lineHeight) || 16
  const scrollDelta = event.deltaMode === 1
    ? event.deltaY * lineHeight
    : event.deltaMode === 2
      ? event.deltaY * chatList.clientHeight
      : event.deltaY

  const isReversed = getComputedStyle(chatList).flexDirection === "column-reverse"
  const maxScroll = Math.max(0, chatList.scrollHeight - chatList.clientHeight)
  chatScrollTarget = (chatScrollTarget ?? chatList.scrollTop) + scrollDelta
  chatScrollTarget = Math.max(isReversed ? -maxScroll : 0, Math.min(isReversed ? 0 : maxScroll, chatScrollTarget))

  if (chatScrollAnimation !== null) return

  const animateScroll = () => {
    const remaining = chatScrollTarget - chatList.scrollTop
    if (Math.abs(remaining) < 0.5) {
      chatList.scrollTop = chatScrollTarget
      chatScrollAnimation = null
      chatScrollTarget = null
      return
    }

    chatList.scrollTop += remaining * 0.28
    chatScrollAnimation = requestAnimationFrame(animateScroll)
  }

  chatScrollAnimation = requestAnimationFrame(animateScroll)
}

function handleChatListWheel(event) {
  const chatApp = chatAppRef.value
  if (!chatApp || !chatApp.contains(event.target) || !chatListRef.value) return

  const suggestionPanel = event.target.closest?.(".mention-suggestions")
  if (suggestionPanel) {
    const suggestionList = event.target.closest?.(".mention-suggestion-list")
    if (!suggestionList) {
      event.preventDefault()
      event.stopPropagation()
      return
    }
    event.preventDefault()
    event.stopPropagation()
    const lineHeight = Number.parseFloat(getComputedStyle(suggestionList).lineHeight) || 16
    const scrollDelta = event.deltaMode === 1
      ? event.deltaY * lineHeight
      : event.deltaMode === 2
        ? event.deltaY * suggestionList.clientHeight
        : event.deltaY
    suggestionList.scrollTop += scrollDelta
    return
  }

  event.preventDefault()
  event.stopPropagation()
  scrollChatList(event)
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
  clearUnreadMessages()
}

function focusChat() {
  isFocused.value = true
  api.engineLua("setCEFFocus(true)")
}

function blurChat(event) {
  if (chatBoxRef.value?.contains(event.relatedTarget)) return
  isFocused.value = false
  jumpToLatest()
}

function handleWindowBlur() {
  isFocused.value = false
  jumpToLatest()
}

function handleChatOutsidePointerDown(event) {
  if (chatAppRef.value && !chatAppRef.value.contains(event.target)) {
    isFocused.value = false
    jumpToLatest()
  }
}

function sendChat() {
  const text = inputText.value
  if (!text) return

  lastSentMessage.value = text
  const message = `${replyTarget.value?.prefix || ""}${text}`
  if (message.length > 500) {
    addMessage("Your message is over the character limit! (500)")
    return
  }

  api.engineLua(`UI.chatSend(${api.serializeToLua(message)})`)
  inputText.value = ""
  cancelReply()
  mentionQuery.value = null
  if (chatInputRef.value) chatInputRef.value.scrollLeft = 0
  nextTick(scheduleInputHighlightScroll)
}

function onInputKeydown(event) {
  if (mentionQuery.value !== null && mentionSuggestions.value.length) {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      const direction = event.key === "ArrowDown" ? 1 : -1
      selectedMentionIndex.value = (selectedMentionIndex.value + direction + mentionSuggestions.value.length) % mentionSuggestions.value.length
      nextTick(scrollSelectedMentionIntoView)
      return
    }
    if (event.key === "Escape") {
      event.preventDefault()
      mentionQuery.value = null
      return
    }
    if (event.key === "Enter" || event.key === "Tab") {
      event.preventDefault()
      const player = mentionSuggestions.value[selectedMentionIndex.value]
      if (player) selectMention(player)
      return
    }
  }

  if (event.key === "Escape" && replyTarget.value) {
    event.preventDefault()
    cancelReply()
    return
  }

  if (event.key === "ArrowUp") {
    inputText.value = lastSentMessage.value
    nextTick(() => {
      const input = chatInputRef.value
      input?.setSelectionRange(lastSentMessage.value.length, lastSentMessage.value.length)
      scheduleInputHighlightScroll()
    })
  } else if (event.key === "Enter") {
    event.preventDefault()
    event.stopPropagation()
    sendChat()
  }
}

function addMessage(message, time = currentTimeString(), messageId = null, chatData = null) {
  const chatList = chatListRef.value
  const shouldFollowLatestMessage = isFollowingLatestMessage(chatList)
  const entry = createMessage(message, time, messageId ?? `local-${Date.now()}-${messages.value.length}`, chatData)
  messages.value = [...messages.value, entry].slice(-70)
  storeChatMessages()
  if (shouldFollowLatestMessage) scrollToLastMessage()
}

function onBeamMPChatMessage(payload) {
  if (!payload || payload.id <= lastMessageId.value) return
  lastMessageId.value = payload.id
  const wasFollowingLatestMessage = isFollowingLatestMessage()
  const time = currentTimeString()
  addMessage(payload.message, time, `remote-${payload.id}`, payload)
  if (!isFocused.value || wasFollowingLatestMessage) {
    scrollToLastMessage()
    clearUnreadMessages()
  } else {
    unreadMessages.value += 1
    const messageText = typeof payload.body === "string" ? payload.body : payload.message
    if (mentionsLocalUser({ body: messageText, raw: payload.message })) {
      unreadMentions.value += 1
    }
  }
}

function onBeamMPPlayerList(payload) {
  let parsed = payload
  if (typeof payload === "string") {
    try {
      parsed = JSON.parse(payload)
    } catch (error) {
      console.error("Failed to parse BeamMP player list for chat mentions", error)
      players.value = []
      updateMentionSuggestions()
      return
    }
  }
  players.value = Array.isArray(parsed) ? parsed.filter(player => player && player.id !== undefined && typeof player.name === "string") : []
  updateMentionSuggestions()
}

function onBeamMPSetNickname(payload) {
  if (typeof payload === "string" && payload.trim()) {
    localUsername.value = payload.trim()
    updateMentionSuggestions()
  }
}

function onClearHistory() {
  localStorage.removeItem("chatMessages")
  clearUnreadMessages()
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
  clearUnreadMessages()
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

  events.on("onBeamMPChatMessage", onBeamMPChatMessage)
  events.on("onBeamMPPlayerList", onBeamMPPlayerList)
  events.on("onBeamMPSetNickname", onBeamMPSetNickname)
  events.on("onBeamMPClearChatHistory", onClearHistory)
  events.on("SettingsChanged", onSettingsChanged)
  window.addEventListener("wheel", handleChatListWheel, { capture: true, passive: false })
  window.addEventListener("blur", handleWindowBlur)
  document.addEventListener("pointerdown", handleChatOutsidePointerDown, true)
  window.addEventListener("keydown", handleChatAtSignKeydown, true)
  api.engineLua("MPConfig.getNickname()", onBeamMPSetNickname)
  api.engineLua("UI.updatePlayersList()")

  fadeTimer = window.setInterval(() => {
    nowTick.value = Date.now()
  }, 100)

  scrollToLastMessage()
})

onUnmounted(() => {
  events.off("onBeamMPChatMessage", onBeamMPChatMessage)
  events.off("onBeamMPPlayerList", onBeamMPPlayerList)
  events.off("onBeamMPSetNickname", onBeamMPSetNickname)
  events.off("onBeamMPClearChatHistory", onClearHistory)
  events.off("SettingsChanged", onSettingsChanged)
  window.removeEventListener("wheel", handleChatListWheel, true)
  window.removeEventListener("blur", handleWindowBlur)
  window.removeEventListener("keydown", handleChatAtSignKeydown, true)
  document.removeEventListener("pointerdown", handleChatOutsidePointerDown, true)
  if (chatScrollAnimation !== null) {
    cancelAnimationFrame(chatScrollAnimation)
    chatScrollAnimation = null
  }
  chatScrollTarget = null

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
  position: relative;
  display: flex;
  width: 100%;
  height: 100%;
  min-width: 0;
  min-height: 0;
  gap: 0.35rem;
  padding: 0.25rem;
  font-size: 1rem;
}

.beammpChat2 .new-messages-indicator {
  position: absolute;
  z-index: 2;
  right: 0.5rem;
  bottom: 2.9rem;
  left: 0.5rem;
  display: flex;
  min-height: 1.8rem;
  align-items: center;
  justify-content: center;
  gap: 0.4rem;
  padding: 0.2rem 0.65rem;
  border: 1px solid rgba(var(--bng-cool-gray-300-rgb), 0.32);
  border-radius: 999px;
  background: rgba(var(--bng-cool-gray-800-rgb), 0.94);
  box-shadow: 0 0.15rem 0.5rem rgba(var(--bng-off-black-rgb), 0.35);
  color: var(--bng-off-white);
  cursor: pointer;
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
}

.beammpChat2 .chat-window.chat-window-top .new-messages-indicator {
  top: 2.9rem;
  bottom: auto;
}

.beammpChat2 .new-messages-indicator:hover {
  border-color: var(--bng-orange-500);
  background: rgba(var(--bng-cool-gray-700-rgb), 0.98);
}

.beammpChat2 .new-messages-count {
  color: inherit;
  font-variant-numeric: tabular-nums;
}

.beammpChat2 .new-messages-indicator.has-new-mention {
  border-color: var(--bng-orange-500);
}

.beammpChat2 .chat-list {
  display: flex;
  width: 100%;
  min-height: 0;
  flex: 1 1 0%;
  gap: 0.1rem;
  padding: 0;
  overflow-x: hidden;
  overflow-y: auto;
  overflow-wrap: anywhere;
  justify-content: flex-start;
  margin: 0;
  list-style: none;
  scrollbar-width: none;
  -ms-overflow-style: none;
}

.beammpChat2 .chat-list::before {
  content: "";
  flex: 1 0 auto;
}

.beammpChat2 .chat-list.chat-list-top::before {
  display: none;
}

.beammpChat2 .chat-message {
  flex: 0 0 auto;
  padding: 0.32rem 0.5rem;
  border-left: 0.16rem solid transparent;
  border-radius: var(--bng-corners-1, 3px);
  background: rgba(var(--bng-cool-gray-900-rgb), 0.76);
  color: var(--bng-off-white);
  line-height: 1.3;
  text-shadow: 0 1px 2px rgba(var(--bng-off-black-rgb), 0.95);
  transition: border-color 100ms ease, background-color 100ms ease, opacity 120ms ease;
}

.beammpChat2 .chat-mention {
  padding: 0.04em 0.3em;
  border-radius: 0.3rem;
  background: rgba(250, 166, 26, 0.18);
  color: var(--bng-orange-400);
  font-weight: 700;
}

.beammpChat2 .chat-message:nth-child(2n + 1) {
  background: rgba(var(--bng-cool-gray-800-rgb), 0.7);
}

.beammpChat2 .chat-message:hover {
  border-left-color: var(--bng-orange-500);
  background: rgba(var(--bng-cool-gray-700-rgb), 0.82);
}

.beammpChat2 .chat-message.chat-message-mention {
  border-left-color: var(--bng-orange-500);
  background:
    linear-gradient(rgba(var(--bng-orange-500-rgb), 0.2), rgba(var(--bng-orange-500-rgb), 0.2)),
    rgba(var(--bng-cool-gray-900-rgb), 0.92);
}

.beammpChat2 .chat-message.chat-message-mention:hover {
  background:
    linear-gradient(rgba(var(--bng-orange-500-rgb), 0.26), rgba(var(--bng-orange-500-rgb), 0.26)),
    rgba(var(--bng-cool-gray-700-rgb), 0.94);
}

.beammpChat2.ui-style-redesigned .chat-message {
  border-left-width: 0.16rem;
  background: rgba(var(--bng-cool-gray-900-rgb), 0.52);
  text-shadow: 0 0 4px #000, 0 0 6px #000, 0 0 8px #000;
  transition: transform 120ms ease, opacity 120ms ease, border-color 120ms ease, background-color 120ms ease;
}

.beammpChat2.ui-style-redesigned .chat-message:nth-child(2n + 1) {
  background: rgba(var(--bng-cool-gray-800-rgb), 0.64);
}

.beammpChat2.ui-style-redesigned .chat-message:hover {
  transform: translateX(3px);
  border-left-color: var(--bng-orange-500);
  background: rgba(var(--bng-cool-gray-700-rgb), 0.78);
}

.beammpChat2.ui-style-redesigned .chat-message.chat-message-mention {
  border-left-color: var(--bng-orange-500);
  background:
    linear-gradient(rgba(var(--bng-orange-500-rgb), 0.2), rgba(var(--bng-orange-500-rgb), 0.2)),
    rgba(var(--bng-cool-gray-900-rgb), 0.92);
}

.beammpChat2.ui-style-redesigned .chat-message.chat-message-mention:hover {
  background:
    linear-gradient(rgba(var(--bng-orange-500-rgb), 0.26), rgba(var(--bng-orange-500-rgb), 0.26)),
    rgba(var(--bng-cool-gray-700-rgb), 0.94);
}

.beammpChat2 .chat-message.chat-message-reply-target,
.beammpChat2 .chat-message.chat-message-reply-target:hover,
.beammpChat2.ui-style-redesigned .chat-message.chat-message-reply-target,
.beammpChat2.ui-style-redesigned .chat-message.chat-message-reply-target:hover {
  border-left-color: var(--bng-orange-400);
  background:
    linear-gradient(rgba(var(--bng-orange-500-rgb), 0.34), rgba(var(--bng-orange-500-rgb), 0.34)),
    rgba(var(--bng-cool-gray-900-rgb), 0.92);
  box-shadow: inset 0 0 0 1px rgba(var(--bng-orange-500-rgb), 0.65);
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
  position: relative;
  position: relative;
  display: flex;
  width: 100%;
  min-width: 0;
  min-height: 2.6rem;
  flex: 0 0 auto;
  align-items: stretch;
  overflow: visible;
  border: 1px solid rgba(var(--bng-cool-gray-300-rgb), 0.4);
  border-left: 0.2rem solid var(--bng-orange-500);
  border-radius: var(--bng-corners-2, 6px);
  background: rgba(var(--bng-cool-gray-900-rgb), 0.9);
  box-shadow: 0 0.2rem 0.75rem rgba(var(--bng-off-black-rgb), 0.3);
  backdrop-filter: blur(10px);
  transition: border-color 100ms ease, background-color 100ms ease, box-shadow 100ms ease;
}

.beammpChat2 .mention-suggestions {
  position: absolute;
  z-index: 5;
  right: 0;
  bottom: calc(100% + 0.35rem);
  left: 0;
  display: block;
  height: auto;
  max-height: 9rem;
  padding: 0.35rem;
  overflow: hidden;
  border: 1px solid rgba(var(--bng-cool-gray-300-rgb), 0.35);
  border-radius: var(--bng-corners-2, 6px);
  background: rgba(var(--bng-cool-gray-900-rgb), 0.97);
  box-shadow: 0 0.25rem 0.9rem rgba(var(--bng-off-black-rgb), 0.45);
}

.beammpChat2 .mention-suggestion {
  display: flex;
  width: 100%;
  min-height: 2rem;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.35rem 0.5rem;
  border: 0;
  border-radius: var(--bng-corners-1, 3px);
  background: transparent;
  color: var(--bng-off-white);
  cursor: pointer;
  text-align: left;
  box-sizing: border-box;
}

.beammpChat2 .mention-suggestions-heading {
  padding: 0.25rem 0.5rem 0.35rem;
  color: var(--bng-cool-gray-300);
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
}

.beammpChat2 .mention-suggestion-list {
  display: block;
  height: 6.45rem;
  max-height: 6.45rem;
  overflow-y: auto;
  overscroll-behavior: contain;
}

.beammpChat2 .mention-suggestion:hover,
.beammpChat2 .mention-suggestion.selected {
  background: rgba(var(--bng-orange-500-rgb), 0.24);
}

.beammpChat2 .mention-player-name {
  overflow: hidden;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.beammpChat2 .mention-player-id {
  flex: 0 0 auto;
  color: var(--bng-cool-gray-300);
  font-size: 0.75rem;
  font-variant-numeric: tabular-nums;
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
  width: 100%;
  min-height: 40px;
  border: 1px solid rgba(var(--bng-cool-gray-100-rgb), 0.28);
  border-radius: 8px;
  border-left-width: 1px;
  background-color: rgba(var(--bng-cool-gray-900-rgb), 0.68);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2);
  transition: background-color 0.3s ease;
  align-items: center;
}

.beammpChat2.ui-style-redesigned .chatbox:hover {
  background-color: rgba(var(--bng-cool-gray-800-rgb), 0.86);
}

.beammpChat2.ui-style-redesigned .chatbox:focus-within {
  border-color: var(--bng-orange-500);
  box-shadow: 0 0 0 0.12rem rgba(var(--bng-orange-500-rgb), 0.3), 0 0.2rem 0.75rem rgba(var(--bng-off-black-rgb), 0.35);
}

.beammpChat2 .chat-input {
  position: relative;
  z-index: 1;
  width: 100%;
  height: 100%;
  min-width: 0;
  flex: 1 1 auto;
  padding: 0 0.65rem;
  border: 0;
  outline: 0;
  background: transparent;
  color: var(--bng-off-white);
  caret-color: var(--bng-off-white);
  font: inherit;
}

.beammpChat2 .chat-input-wrap {
  position: relative;
  min-width: 0;
  flex: 1 1 auto;
  align-self: stretch;
  overflow: hidden;
}

.beammpChat2 .chat-input-highlight {
  position: absolute;
  z-index: 0;
  inset: 0;
  display: flex;
  align-items: center;
  padding: 0 0.65rem;
  overflow: hidden;
  color: var(--bng-off-white);
  font: inherit;
  pointer-events: none;
  white-space: pre;
}

.beammpChat2 .chat-input-highlight > span {
  flex: 0 0 auto;
}

.beammpChat2 .chat-input-mention {
  color: var(--bng-orange-400);
}

.beammpChat2 .chat-input.has-highlight-text {
  color: transparent;
}

.beammpChat2 .chat-input-wrap.has-selection .chat-input-highlight {
  visibility: hidden;
}

.beammpChat2 .chat-input-wrap.has-selection .chat-input {
  color: var(--bng-off-white);
}

.beammpChat2 .chat-input-wrap.has-selection .chat-input::selection {
  color: var(--bng-off-white);
  background: rgba(var(--bng-orange-500-rgb), 0.72);
}

.beammpChat2 .chat-input::placeholder {
  color: var(--bng-cool-gray-300);
}

.beammpChat2.ui-style-redesigned .chat-input::placeholder {
  text-align: left;
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
  box-sizing: border-box;
  flex: 0 0 auto;
  align-self: center;
  min-width: 3.7rem;
  min-height: 30px;
  height: 30px;
  margin: 4px 3px;
  padding: 0 0.75rem;
  border-radius: 5px;
  background: var(--bng-orange-500);
  color: var(--bng-off-white);
  font-weight: 700;
  line-height: 1;
}

.beammpChat2.ui-style-redesigned .send-button:hover,
.beammpChat2.ui-style-redesigned .send-button:focus-visible {
  background: var(--bng-orange-500);
}

.beammpChat2 .swap-buttons {
  flex: 0 0 2.35rem;
  padding: 0;
}

.beammpChat2 .chat-list::-webkit-scrollbar {
  display: none !important;
  width: 0 !important;
  height: 0 !important;
}

.beammpChat2 .chat-message {
  position: relative;
}

.beammpChat2 .chat-message-reply {
  position: absolute;
  top: 0.15rem;
  right: 0.2rem;
  display: grid;
  width: 1.5rem;
  height: 1.5rem;
  place-items: center;
  padding: 0;
  border: 1px solid rgba(var(--bng-cool-gray-300-rgb), 0.3);
  border-radius: var(--bng-corners-1, 3px);
  background: rgba(var(--bng-cool-gray-900-rgb), 0.92);
  color: var(--bng-off-white);
  cursor: pointer;
  opacity: 0;
  transition: opacity 100ms ease, background-color 100ms ease;
}

.beammpChat2 .chat-message:hover .chat-message-reply,
.beammpChat2 .chat-message-reply:focus-visible {
  opacity: 1;
}

.beammpChat2 .chat-message-reply:hover,
.beammpChat2 .chat-message-reply:focus-visible {
  background: var(--bng-orange-500);
  outline: 0;
}

.beammpChat2 .chat-message-reply::after {
  position: absolute;
  right: calc(100% + 0.35rem);
  top: 50%;
  z-index: 3;
  padding: 0.25rem 0.45rem;
  border: 1px solid rgba(var(--bng-cool-gray-300-rgb), 0.35);
  border-radius: var(--bng-corners-1, 3px);
  background: rgba(var(--bng-cool-gray-900-rgb), 0.97);
  box-shadow: 0 0.15rem 0.5rem rgba(var(--bng-off-black-rgb), 0.35);
  color: var(--bng-off-white);
  content: attr(data-tooltip);
  font-size: 0.75rem;
  font-weight: 600;
  line-height: 1.2;
  opacity: 0;
  pointer-events: none;
  transform: translateY(-50%);
  transition: opacity 100ms ease;
  white-space: nowrap;
}

.beammpChat2 .chat-message-reply:hover::after,
.beammpChat2 .chat-message-reply:focus-visible::after {
  opacity: 1;
}

.beammpChat2 .chat-message-reply-preview,
.beammpChat2 .chat-message-reply-content {
  display: block;
  min-width: 0;
  margin-left: 0.65rem;
  padding-left: 0.5rem;
  border-left: 1px solid rgba(var(--bng-orange-500-rgb), 0.65);
}

.beammpChat2 .chat-message-reply-preview {
  display: flex;
  align-items: baseline;
  gap: 0.3rem;
  overflow: hidden;
  color: var(--bng-cool-gray-200);
  font-size: 0.82em;
  opacity: 0.82;
  white-space: nowrap;
}

.beammpChat2 .chat-message-reply-arrow {
  flex: 0 0 auto;
  color: var(--bng-cool-gray-300);
}

.beammpChat2 .chat-message-reply-role {
  min-width: 0;
  max-width: 30%;
  flex: 0 1 auto;
  overflow: hidden;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.beammpChat2 .chat-message-reply-author {
  min-width: 0;
  max-width: 40%;
  flex: 0 1 auto;
  overflow: hidden;
  color: inherit;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.beammpChat2 .chat-message-reply-quote {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.beammpChat2 .chat-message-reply-content {
  overflow-wrap: anywhere;
}

.beammpChat2 .chat-message-reply-body {
  overflow-wrap: anywhere;
}

.beammpChat2 .reply-composer {
  display: flex;
  width: 100%;
  min-width: 0;
  min-height: 1.65rem;
  flex: 0 0 auto;
  align-items: center;
  gap: 0.35rem;
  margin-bottom: -0.35rem;
  padding: 0.3rem 0.5rem;
  border: 1px solid rgba(var(--bng-cool-gray-300-rgb), 0.28);
  border-left: 0.2rem solid var(--bng-orange-500);
  border-radius: var(--bng-corners-2, 6px) var(--bng-corners-2, 6px) 0 0;
  background: rgba(var(--bng-cool-gray-900-rgb), 0.97);
  box-shadow: 0 0.15rem 0.5rem rgba(var(--bng-off-black-rgb), 0.3);
  color: var(--bng-off-white);
  font-size: 0.8rem;
}

.beammpChat2 .reply-composer + .chatbox {
  border-top-left-radius: 0;
  border-top-right-radius: 0;
}

.beammpChat2 .chat-window.chat-window-top .reply-composer {
  margin: 0;
  margin-top: -0.35rem;
  border-radius: 0 0 var(--bng-corners-2, 6px) var(--bng-corners-2, 6px);
}

.beammpChat2 .chat-window.chat-window-top .reply-composer + .chatbox {
  border-top-left-radius: var(--bng-corners-2, 6px);
  border-top-right-radius: var(--bng-corners-2, 6px);
  border-bottom-right-radius: 0;
  border-bottom-left-radius: 0;
}

.beammpChat2 .reply-composer-content {
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  align-items: baseline;
  gap: 0.25rem;
  overflow: hidden;
}

.beammpChat2 .reply-composer-content .reply-composer-label {
  flex: 0 0 auto;
  color: var(--bng-cool-gray-200);
}

.beammpChat2 .reply-composer-content strong {
  min-width: 0;
  overflow: hidden;
  color: var(--bng-orange-400);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.beammpChat2 .reply-composer-cancel {
  display: grid;
  width: 1.35rem;
  height: 1.35rem;
  flex: 0 0 auto;
  place-items: center;
  padding: 0;
  border: 0;
  background: transparent;
  color: var(--bng-cool-gray-100);
  cursor: pointer;
  font-size: 1rem;
  line-height: 1;
}

.beammpChat2 .reply-composer-cancel:hover,
.beammpChat2 .reply-composer-cancel:focus-visible {
  border-radius: var(--bng-corners-1, 3px);
  background: rgba(var(--bng-orange-500-rgb), 0.25);
  color: var(--bng-off-white);
  outline: 0;
}

@media (max-width: 420px) {
  .beammpChat2 .chat-window {
    font-size: 0.75rem;
  }

  .beammpChat2 .send-button {
    min-width: 2.5rem;
    overflow: hidden;
    font-size: 0;
  }

  .beammpChat2 .send-button::before {
    content: "↗";
    font-size: 1rem;
  }
}
</style>