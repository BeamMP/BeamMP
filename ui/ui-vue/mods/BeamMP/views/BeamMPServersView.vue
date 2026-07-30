<template>
  <section class="servers-wrap">
    <div class="browser-layout">
      <div class="server-pane">
        <header class="toolbar">
          <div class="toolbar-main">
            <BngInput
              class="search-input"
              :model-value="uiFilters.searchText"
              :placeholder="$tt('ui.common.beammp.searchPlaceholder')"
              @update:model-value="onSearch"
            />
            <BngButton class="refresh-btn" @click="requestServerList">{{ $tt("ui.common.beammp.refresh") }}</BngButton>
            <span class="mod-size-summary">Total Mod Size &lt; {{ maxModSizeLabel }}</span>
            <BngButton
              v-if="state.view.value === 'recent'"
              class="clear-recents-btn"
              accent="secondary"
              @click="clearRecents"
            >
              {{ $tt("ui.beammp.serverBrowser.clearRecent") }}
            </BngButton>
          </div>
          <span class="server-count">{{ visibleServers.length }} servers</span>
        </header>

        <table class="servers-table">
          <thead>
            <tr>
              <th>{{ $tt("ui.common.beammp.location") }}</th>
              <th>{{ $tt("ui.common.beammp.title") }}</th>
              <th>{{ $tt("ui.common.beammp.map") }}</th>
              <th>{{ $tt("ui.common.beammp.players") }}</th>
              <th></th>
            </tr>
          </thead>
          <tbody ref="serversTbody" @scroll.passive="onServersScroll">
            <template v-for="server in renderedServers" :key="server.id">
              <tr
                class="server-row"
                :class="[serverCategoryClass(server), { selected: state.selectedServerId.value === server.id }]"
                tabindex="0"
                @click="selectServer(server.id)"
                @keydown.enter.prevent="selectServer(server.id)"
                @keydown.space.prevent="selectServer(server.id)"
              >
                <td class="location-cell">
                  <img
                    class="location-flag"
                    :src="locationFlag(server.location)"
                    :alt="`${server.location || 'Unknown'} flag`"
                    :title="server.location || 'Unknown location'"
                    @error="useFallbackFlag"
                  />
                </td>
                <td class="title-cell">
                  <span class="server-title" v-html="serverTitleMarkup(server)"></span>
                </td>
                <td>{{ server.mapName }}</td>
                <td>{{ server.players }}/{{ server.maxplayers }}</td>
                <td class="details-cell">
                  <button class="details-button" @click.stop="selectServer(server.id)">
                    {{ state.selectedServerId.value === server.id ? "Hide" : "Details" }}
                  </button>
                </td>
              </tr>
              <tr v-if="state.selectedServerId.value === server.id" class="details-row">
                <td colspan="5">
                  <section class="details">
                    <h3 class="server-title server-title--detail" v-html="serverTitleMarkup(server)"></h3>

                    <div class="details-grid">
                      <section class="info-panel">
                        <h4 class="section-header">{{ $tt("ui.common.beammp.serverDetails") }}</h4>
                        <table class="description-table">
                          <tr>
                            <th>{{ $tt("ui.beammp.serverBrowser.server.owner") }}</th>
                            <td>{{ server.owner || "" }}</td>
                          </tr>
                          <tr>
                            <th>{{ $tt("ui.beammp.serverBrowser.server.map") }}</th>
                            <td>{{ server.mapName || "" }}</td>
                          </tr>
                          <tr>
                            <th>{{ $tt("ui.beammp.serverBrowser.server.description") }}</th>
                            <td class="desc-cell">{{ server.sdesc || "" }}</td>
                          </tr>
                          <tr>
                            <th>{{ $tt("ui.beammp.serverBrowser.server.tags") }}</th>
                            <td>
                              <span v-if="!server.tagsList.length">{{ $tt("ui.common.beammp.noTags") }}</span>
                              <div v-else class="tag-list-container">
                                <span v-for="tag in server.tagsList" :key="`${server.id}:${tag.raw}`" class="chip">{{ tag.text }}</span>
                              </div>
                            </td>
                          </tr>
                        </table>
                      </section>

                      <section class="players-panel">
                        <h4 class="section-header">{{ $tt("ui.common.beammp.playerList") }}</h4>
                        <div v-if="!playerNames(server).length" class="muted">{{ $tt("ui.common.beammp.noPlayers") }}</div>
                        <div v-else class="tag-list-container">
                          <span
                            v-for="playerName in playerNames(server)"
                            :key="`${server.id}:player:${playerName}`"
                            class="chip chip-player"
                          >
                            {{ playerName }}
                          </span>
                        </div>
                      </section>
                    </div>

                    <section class="mods mods-panel">
                      <h4 class="section-header">{{ $tt("ui.common.beammp.mods") }} ({{ modList(server.modlist).length }})</h4>
                      <div v-if="modList(server.modlist).length === 0">{{ $tt("ui.common.beammp.vanilla") }}</div>
                      <div v-else class="tag-list-container">
                        <span v-for="mod in modList(server.modlist)" :key="`${server.id}:${mod}`" class="chip">{{ mod }}</span>
                      </div>
                      <small>{{ $tt("ui.beammp.serverBrowser.server.modsTotalFilesize") }} {{ formatBytes(server.modstotalsize) }}</small>
                    </section>

                    <div class="actions">
                      <BngButton @click.stop="join(server)">{{ $tt("ui.common.beammp.connect") }}</BngButton>
                      <BngButton v-if="!isFavorite(server)" accent="secondary" @click.stop="addFavorite(server)">{{ $tt("ui.beammp.serverBrowser.addFavorite") }}</BngButton>
                      <BngButton v-else accent="secondary" @click.stop="removeFavorite(server)">{{ $tt("ui.beammp.serverBrowser.removeFavorite") }}</BngButton>
                    </div>
                  </section>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>

      <aside ref="filtersRail" class="filters-rail" :style="filtersRailStyle">
        <h2 class="rail-title">Search Filters</h2>
        <BngButton class="reset-button" accent="attention" @click="resetFilters">
          {{ $tt("ui.beammp.serverBrowser.filters.resetFilters") }}
        </BngButton>

        <section class="filter-group">
          <h3>Player Count</h3>
          <label class="filter-field">
            <span>Range Min</span>
            <input
              v-bng-text-input
              class="number-input"
              type="text"
              inputmode="numeric"
              pattern="[0-9]*"
              :aria-label="$tt('ui.beammp.serverBrowser.filters.playerCountMin')"
              :value="playerCountDrafts.min"
              @input="event => updatePlayerCountDraft('min', event)"
              @blur="commitPlayerCount('min')"
              @keydown.enter.prevent="event => event.currentTarget.blur()"
              @keydown.esc.prevent="restorePlayerCountDraft('min')"
            />
          </label>
          <label class="filter-field">
            <span>Range Max</span>
            <input
              v-bng-text-input
              class="number-input"
              type="text"
              inputmode="numeric"
              pattern="[0-9]*"
              :aria-label="$tt('ui.beammp.serverBrowser.filters.playerCountMax')"
              :value="playerCountDrafts.max"
              @input="event => updatePlayerCountDraft('max', event)"
              @blur="commitPlayerCount('max')"
              @keydown.enter.prevent="event => event.currentTarget.blur()"
              @keydown.esc.prevent="restorePlayerCountDraft('max')"
            />
          </label>
        </section>

        <section class="filter-group">
          <h3>Total Mod Size</h3>
          <div class="range-row">
            <input
              class="range-input"
              type="range"
              min="0"
              max="107520"
              step="10"
              :value="uiFilters.sliderMaxModSize"
              @input="event => updateNumber('sliderMaxModSize', event.target.value)"
            />
            <span>{{ maxModSizeLabel }}</span>
          </div>
        </section>

        <section class="filter-group">
          <h3>Matching</h3>
        <label class="match-all">
          <input
            type="checkbox"
            :checked="uiFilters.matchAll"
            @change="event => updateMatchAll(event.target.checked)"
          />
          <span class="checkmark" aria-hidden="true" />
          <span>
            <strong>Match all</strong>
            <small>Require every selected filter</small>
          </span>
        </label>
        </section>

        <section class="filter-group">
          <h3>{{ $tt("ui.common.beammp.tags") }}</h3>
        <div class="filter-options">
          <button
            v-for="tag in availableTags"
            :key="tag.raw"
            class="filter-option"
            :class="{ active: tagSelected(tag) }"
            @click="toggleTag(tag)"
          >
            {{ tag.text }}
          </button>
        </div>
        </section>

        <section class="filter-group">
          <h3>{{ $tt("ui.beammp.serverBrowser.filters.selectVersions") }}</h3>
        <div class="filter-options">
          <button
            v-for="version in availableVersions"
            :key="version"
            class="filter-option"
            :class="{ active: simpleFilterSelected('selectedServerVersions', version) }"
            @click="toggleSimpleFilter('selectedServerVersions', version)"
          >
            {{ version }}
          </button>
        </div>
        </section>

        <section class="filter-group">
          <h3>{{ $tt("ui.beammp.serverBrowser.filters.selectServerLocations") }}</h3>
        <div class="filter-options">
          <button
            v-for="location in availableLocations"
            :key="location"
            class="filter-option filter-option--location"
            :class="{ active: simpleFilterSelected('selectedServerLocations', location) }"
            @click="toggleSimpleFilter('selectedServerLocations', location)"
          >
            <img :src="locationFlag(location)" alt="" @error="useFallbackFlag" />
            {{ location }}
          </button>
        </div>
        </section>

        <section class="filter-group">
          <h3>{{ $tt("ui.common.beammp.maps") }}</h3>
        <div class="filter-options">
          <button
            v-for="map in availableMaps"
            :key="map"
            class="filter-option"
            :class="{ active: simpleFilterSelected('selectedMaps', map) }"
            @click="toggleSimpleFilter('selectedMaps', map)"
          >
            <img
              v-if="officialMaps.includes(map)"
              class="filter-option-icon filter-option-icon--beamng"
              alt=""
              aria-hidden="true"
            />
            {{ map }}
          </button>
        </div>
        </section>
      </aside>
    </div>
  </section>
</template>

<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from "vue"
import { useRoute } from "vue-router"
import { BngButton, BngInput } from "@/common/components/base"
import { vBngTextInput } from "@/common/directives"
import { useBeamMPState } from "../shared/beammpState.js"
import { icons as bngIcons } from "/ui/ui-vue/src/assets/fonts/bngIcons/bngIcons.js"

const route = useRoute()
const filtersRail = ref(null)
const serversTbody = ref(null)
const filtersRailMaxHeight = ref("")
const uiFilters = ref({})
const playerCountDrafts = ref({
  min: "0",
  max: "64",
})
let filtersRailResizeObserver = null
let applyFiltersDebounceTimer = null
const FILTERS_DEBOUNCE_MS = 400
const INITIAL_RENDER_COUNT = 180
const RENDER_BATCH_COUNT = 140
const RENDER_SCROLL_THRESHOLD_PX = 360
const renderedServerCount = ref(INITIAL_RENDER_COUNT)
const {
  addFavorite,
  availableLocations,
  availableMaps,
  availableTags,
  availableVersions,
  officialMaps,
  clearRecents,
  connectToServer,
  formatBytes,
  isFavorite,
  modList,
  removeFavorite,
  requestServerList,
  resetFilters,
  selectServer,
  setView,
  state,
  updateFilter,
  visibleServers,
} = useBeamMPState()

const maxModSizeLabel = computed(() => formatBytes(
  Number(uiFilters.value.sliderMaxModSize || 0) * 1024 * 1024,
))

const renderedServers = computed(() => {
  return visibleServers.value.slice(0, renderedServerCount.value)
})

const filtersRailStyle = computed(() => {
  if (!filtersRailMaxHeight.value) return null
  return {
    maxHeight: filtersRailMaxHeight.value,
  }
})

function updateFiltersRailMaxHeight() {
  const rail = filtersRail.value
  if (!rail) return

  const container = rail.closest(".content")
  if (!container) {
    filtersRailMaxHeight.value = ""
    return
  }

  const railRect = rail.getBoundingClientRect()
  const containerRect = container.getBoundingClientRect()
  const containerStyle = window.getComputedStyle(container)
  const containerPaddingBottom = Number.parseFloat(containerStyle.paddingBottom) || 0
  const topOffsetInContainer = railRect.top - containerRect.top
  const availableHeight = Math.floor(containerRect.height - containerPaddingBottom - topOffsetInContainer)

  filtersRailMaxHeight.value = availableHeight > 0 ? `${availableHeight}px` : ""
}

function updateNumber(key, value) {
  uiFilters.value = {
    ...uiFilters.value,
    [key]: Number(value || 0),
  }
  queueFilterUpdate()
}

function playerCountFilterKey(field) {
  return field === "min" ? "playerCountMin" : "playerCountMax"
}

function updatePlayerCountDraft(field, event) {
  const value = String(event?.target?.value ?? "").replace(/\D/g, "")
  if (event?.target) event.target.value = value
  playerCountDrafts.value = {
    ...playerCountDrafts.value,
    [field]: value,
  }
}

function restorePlayerCountDraft(field) {
  const key = playerCountFilterKey(field)
  playerCountDrafts.value = {
    ...playerCountDrafts.value,
    [field]: String(uiFilters.value[key] ?? 0),
  }
}

function commitPlayerCount(field) {
  const key = playerCountFilterKey(field)
  const draft = playerCountDrafts.value[field]

  if (draft === "") {
    restorePlayerCountDraft(field)
    return
  }

  const value = Math.max(0, Math.trunc(Number(draft)))
  uiFilters.value = {
    ...uiFilters.value,
    [key]: value,
  }
  playerCountDrafts.value = {
    ...playerCountDrafts.value,
    [field]: String(value),
  }
  applyFiltersNow()
}

function onSearch(value) {
  uiFilters.value = {
    ...uiFilters.value,
    searchText: value || "",
  }
  queueFilterUpdate()
}

function simpleFilterSelected(key, value) {
  return (uiFilters.value[key] || []).includes(value)
}

function toggleSimpleFilter(key, value) {
  const current = uiFilters.value[key] || []
  uiFilters.value = {
    ...uiFilters.value,
    [key]: current.includes(value)
      ? current.filter(item => item !== value)
      : [...current, value],
  }
  queueFilterUpdate()
}

function tagSelected(tag) {
  return (uiFilters.value.selectedTags || []).some(selected => String(selected.raw || selected) === tag.raw)
}

function toggleTag(tag) {
  const current = uiFilters.value.selectedTags || []
  uiFilters.value = {
    ...uiFilters.value,
    selectedTags: tagSelected(tag)
      ? current.filter(selected => String(selected.raw || selected) !== tag.raw)
      : [...current, tag.raw],
  }
  queueFilterUpdate()
}

function updateMatchAll(value) {
  uiFilters.value = {
    ...uiFilters.value,
    matchAll: Boolean(value),
  }
  queueFilterUpdate()
}

function normalizeFilters(filters = {}) {
  const source = filters || {}
  return {
    searchText: String(source.searchText || ""),
    playerCountMin: Number(source.playerCountMin || 0),
    playerCountMax: Number(source.playerCountMax || 0),
    sliderMaxModSize: Number(source.sliderMaxModSize || 0),
    selectedMaps: Array.isArray(source.selectedMaps) ? [...source.selectedMaps] : [],
    selectedServerVersions: Array.isArray(source.selectedServerVersions) ? [...source.selectedServerVersions] : [],
    selectedTags: Array.isArray(source.selectedTags)
      ? source.selectedTags
        .map(tag => (typeof tag === "string" ? tag : String(tag?.raw || "")))
        .filter(Boolean)
      : [],
    selectedServerLocations: Array.isArray(source.selectedServerLocations) ? [...source.selectedServerLocations] : [],
    matchAll: Boolean(source.matchAll),
  }
}

function queueFilterUpdate() {
  if (applyFiltersDebounceTimer) {
    clearTimeout(applyFiltersDebounceTimer)
  }
  applyFiltersDebounceTimer = setTimeout(() => {
    applyFiltersDebounceTimer = null
    updateFilter(normalizeFilters(uiFilters.value))
  }, FILTERS_DEBOUNCE_MS)
}

function applyFiltersNow() {
  if (applyFiltersDebounceTimer) {
    clearTimeout(applyFiltersDebounceTimer)
    applyFiltersDebounceTimer = null
  }
  updateFilter(normalizeFilters(uiFilters.value))
}

function growRenderedServers(batchSize = RENDER_BATCH_COUNT) {
  const total = visibleServers.value.length
  if (renderedServerCount.value >= total) return false
  renderedServerCount.value = Math.min(total, renderedServerCount.value + batchSize)
  return true
}

function resetRenderedServers() {
  renderedServerCount.value = Math.min(INITIAL_RENDER_COUNT, visibleServers.value.length)
}

function ensureRenderedServersFillContainer(maxIterations = 8) {
  const tbody = serversTbody.value
  if (!tbody) return

  let iterations = 0
  while (iterations < maxIterations && tbody.scrollHeight <= tbody.clientHeight + 2) {
    const grew = growRenderedServers()
    if (!grew) break
    iterations += 1
  }
}

function onServersScroll(event) {
  const tbody = event?.target
  if (!tbody) return

  const nearBottom = tbody.scrollTop + tbody.clientHeight >= tbody.scrollHeight - RENDER_SCROLL_THRESHOLD_PX
  if (!nearBottom) return

  const grew = growRenderedServers()
  if (grew) {
    nextTick(() => ensureRenderedServersFillContainer(2))
  }
}

function escapeHtml(value = "") {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;")
}

function serverTitleMarkup(server) {
  const raw = String(server?.sname || server?.strippedName || "")
  if (!raw) return ""

  const tokens = raw.split(/(\^.)/g)
  let result = ""

  for (let index = 0; index < tokens.length; index += 1) {
    const token = tokens[index]
    const nextToken = (tokens[index + 1] || "").trim()

    if (/^\^.$/.test(token)) {
      if (token === "^*") {
        const icon = bngIcons?.[nextToken]
        if (icon?.fileSvg) {
          result += `<img class="server-title-icon" src="/ui/ui-vue/src/assets/fonts/bngIcons/${icon.fileSvg}" alt="" aria-hidden="true" />`
        }
        index += 1
      }
      continue
    }

    result += escapeHtml(token)
  }

  return result
}

function playerNames(server) {
  const list = String(server?.playerslist || "")
    .replace(/^Current players:\s*/i, "")
    .trim()
  if (!list) return []
  return list
    .split(/[;,]/)
    .map(name => name.trim())
    .filter(Boolean)
}

function locationFlag(location) {
  const code = String(location || "--").trim().toLowerCase()
  const safeCode = /^[a-z]{2}(?:-[a-z]{3})?$/.test(code) ? code : "--"
  return `/ui/assets/BeamMP/flags/${safeCode}.png`
}

function useFallbackFlag(event) {
  const image = event.currentTarget
  image.onerror = null
  image.src = "/ui/assets/BeamMP/flags/--.png"
}

function serverCategoryClass(server) {
  if (server?.official) return "category-official"
  if (server?.featured) return "category-featured"
  if (server?.partner) return "category-partner"
  if (isFavorite(server)) return "category-favorite"
  return ""
}

async function join(server) {
  if (!server) return
  await connectToServer(server.ip, server.port, server.sname)
}

function syncView() {
  const view = String(route.params.view || "servers")
  setView(view)
}

watch(() => route.params.view, syncView, { immediate: true })

watch(
  () => state.filters.value,
  filters => {
    uiFilters.value = normalizeFilters(filters)
    playerCountDrafts.value = {
      min: String(uiFilters.value.playerCountMin),
      max: String(uiFilters.value.playerCountMax),
    }
  },
  { deep: true, immediate: true },
)

watch(
  visibleServers,
  async () => {
    resetRenderedServers()
    await nextTick()
    const tbody = serversTbody.value
    if (tbody) tbody.scrollTop = 0
    ensureRenderedServersFillContainer()
  },
  { immediate: true },
)

onMounted(async () => {
  await nextTick()
  updateFiltersRailMaxHeight()
  ensureRenderedServersFillContainer()

  const rail = filtersRail.value
  const container = rail?.closest(".content")
  if (container && "ResizeObserver" in window) {
    filtersRailResizeObserver = new ResizeObserver(() => updateFiltersRailMaxHeight())
    filtersRailResizeObserver.observe(container)
  }

  window.addEventListener("resize", updateFiltersRailMaxHeight)
})

onBeforeUnmount(() => {
  if (applyFiltersDebounceTimer) {
    clearTimeout(applyFiltersDebounceTimer)
    applyFiltersDebounceTimer = null
  }
  if (filtersRailResizeObserver) {
    filtersRailResizeObserver.disconnect()
    filtersRailResizeObserver = null
  }
  window.removeEventListener("resize", updateFiltersRailMaxHeight)
})
</script>

<style scoped lang="scss">
.servers-wrap {
  box-sizing: border-box;
  height: 100%;
  min-height: 0;
}

.browser-layout {
  display: grid;
  grid-template-columns: minmax(0, 1fr) clamp(22rem, 25vw, 29rem);
  gap: 0.45rem;
  align-items: start;
  height: 100%;
  min-height: 0;
}

.server-pane {
  display: flex;
  flex-direction: column;
  height: 100%;
  min-height: 0;
  min-width: 0;
}

.toolbar {
  flex: 0 0 auto;
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 0.55rem;
  align-items: center;
  min-height: 3.5rem;
  padding: 0.6rem 0.7rem;
  margin-bottom: 0.5rem;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: var(--bng-corners-2);
  background:
    linear-gradient(180deg, rgba(60, 66, 75, 0.96), rgba(44, 49, 57, 0.96)),
    radial-gradient(circle at 12% 0%, rgba(var(--bng-orange-500-rgb), 0.15), transparent 38%);
}

.toolbar-main {
  display: flex;
  min-width: 0;
  gap: 0.5rem;
  align-items: center;
  flex-wrap: nowrap;
}

.search-input {
  flex: 1 1 22rem;
  min-width: 12rem;
}

.refresh-btn,
.clear-recents-btn {
  flex: 0 0 auto;
}

.mod-size-summary {
  display: inline-flex;
  align-items: center;
  min-height: 2.1rem;
  padding: 0 0.72rem;
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: var(--bng-corners-1);
  color: var(--bng-cool-gray-50);
  background: rgba(20, 24, 31, 0.6);
  font-size: 0.8rem;
  font-weight: 600;
  white-space: nowrap;
}

.server-count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 2.1rem;
  padding: 0 0.75rem;
  border: 1px solid rgba(var(--bng-orange-500-rgb), 0.35);
  border-radius: var(--bng-corners-1);
  color: var(--bng-cool-gray-100);
  background: rgba(0, 0, 0, 0.28);
  font-size: 0.78rem;
  font-weight: 700;
  letter-spacing: 0.02em;
  white-space: nowrap;
}

.filters-rail {
  position: sticky;
  top: 0;
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
  box-sizing: border-box;
  min-height: 0;
  max-height: 100%;
  padding: 0.75rem;
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: var(--bng-corners-2);
  background: rgba(50, 57, 66, 0.94);
  overflow-y: auto;
  overscroll-behavior: contain;
}

.rail-title {
  position: relative;
  margin: 0;
  padding: 0.05rem 0 0.1rem 1rem;
  color: var(--bng-off-white);
  font-size: 1.15rem;
  font-style: italic;

  &::before {
    content: "";
    position: absolute;
    left: 0;
    top: 0;
    bottom: 0;
    width: 0.38rem;
    background: var(--bng-orange-500);
    transform: skew(-12deg);
  }
}

.reset-button {
  width: 100%;
}

.filter-group {
  min-width: 0;
  padding-top: 0.2rem;

  h3 {
    position: relative;
    margin: 0 0 0.45rem;
    padding-left: 0.8rem;
    color: var(--bng-off-white);
    font-size: 0.95rem;
    font-style: italic;

    &::before {
      content: "";
      position: absolute;
      left: 0;
      top: 0.05rem;
      bottom: 0.05rem;
      width: 0.28rem;
      background: var(--bng-orange-500);
      transform: skew(-12deg);
    }
  }
}

.filter-options {
  display: flex;
  flex-wrap: wrap;
  align-content: flex-start;
  gap: 0.3rem;
}

.filter-option {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.22rem 0.42rem;
  border: 1px solid rgba(255, 255, 255, 0.14);
  border-radius: var(--bng-corners-1);
  color: var(--bng-cool-gray-200);
  background: rgba(22, 29, 36, 0.62);
  font: inherit;
  font-size: 0.7rem;
  cursor: pointer;

  &:hover {
    border-color: rgba(var(--bng-orange-500-rgb), 0.7);
  }

  &.active {
    border-color: rgba(255, 255, 255, 0.32);
    color: var(--bng-off-white);
    background: rgba(82, 94, 105, 0.88);

    &::after {
      content: "✓";
      margin-left: 0.15rem;
      font-weight: 700;
    }
  }
}

.filter-option--location img {
  width: auto;
  height: 0.8rem;
  max-width: 1.5rem;
}

.filter-field {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  margin-bottom: 0.35rem;
  color: var(--bng-cool-gray-200);
  font-size: 0.76rem;
  font-weight: 600;
}

.number-input {
  box-sizing: border-box;
  width: 100%;
  min-height: 2.35rem;
  padding: 0.4rem 0.55rem;
  border: 1px solid rgba(255, 255, 255, 0.22);
  border-radius: var(--bng-corners-1);
  outline: 0;
  color: var(--bng-off-white);
  background: rgba(14, 18, 24, 0.88);
  font: inherit;

  &:hover {
    border-color: rgba(255, 255, 255, 0.4);
  }

  &:focus {
    border-color: var(--bng-orange-500);
    box-shadow: 0 0 0 0.12rem rgba(var(--bng-orange-500-rgb), 0.32);
  }
}

.range-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 4.5rem;
  gap: 0.6rem;
  align-items: center;
  color: var(--bng-cool-gray-100);
  font-size: 0.76rem;
  text-align: right;
}

.range-input {
  width: 100%;
  accent-color: var(--bng-orange-500);
}

.match-all {
  position: relative;
  display: flex;
  align-items: center;
  gap: 0.6rem;
  min-height: 2.35rem;
  padding: 0.35rem 0.55rem;
  border: 1px solid rgba(255, 255, 255, 0.14);
  border-radius: var(--bng-corners-1);
  background: rgba(255, 255, 255, 0.04);
  cursor: pointer;

  input {
    position: absolute;
    opacity: 0;
    pointer-events: none;
  }

  strong,
  small {
    display: block;
  }

  small {
    margin-top: 0.08rem;
    color: var(--bng-cool-gray-300);
    font-size: 0.72rem;
  }

  input:checked + .checkmark {
    border-color: var(--bng-orange-500);
    background: var(--bng-orange-500);

    &::after {
      opacity: 1;
    }
  }

  input:focus-visible + .checkmark {
    box-shadow: 0 0 0 0.12rem rgba(var(--bng-orange-500-rgb), 0.35);
  }
}

.checkmark {
  position: relative;
  flex: 0 0 1.15rem;
  width: 1.15rem;
  height: 1.15rem;
  border: 1px solid rgba(255, 255, 255, 0.4);
  border-radius: 0.2rem;
  background: rgba(0, 0, 0, 0.35);

  &::after {
    content: "";
    position: absolute;
    left: 0.32rem;
    top: 0.12rem;
    width: 0.3rem;
    height: 0.58rem;
    border: solid white;
    border-width: 0 0.13rem 0.13rem 0;
    transform: rotate(45deg);
    opacity: 0;
  }
}

.servers-table {
  flex: 1 1 0;
  min-height: 0;
  width: 100%;
  border-collapse: collapse;
  background: rgba(42, 47, 54, 0.42);
  display: grid;
  grid-template-rows: auto minmax(0, 1fr);

  thead,
  tbody {
    display: block;
  }

  tbody {
    min-height: 0;
    overflow-y: auto;
    overflow-x: hidden;
    overscroll-behavior: contain;
  }

  thead tr,
  tbody tr {
    display: table;
    width: 100%;
    table-layout: fixed;
  }

  thead th:nth-child(1),
  .server-row td:nth-child(1) {
    width: 3.5rem;
  }

  thead th:nth-child(2),
  .server-row td:nth-child(2) {
    width: 46%;
  }

  thead th:nth-child(3),
  .server-row td:nth-child(3) {
    width: 22%;
  }

  thead th:nth-child(4),
  .server-row td:nth-child(4) {
    width: 8.5rem;
  }

  thead th:nth-child(5),
  .server-row td:nth-child(5) {
    width: 5.5rem;
  }

  th,
  td {
    padding: 0.26rem 0.42rem;
    border-bottom: 1px solid rgba(255, 255, 255, 0.08);
    text-align: left;
  }
}

.server-row {
  cursor: pointer;
  box-shadow: inset 0.22rem 0 transparent;
  transition: background-color 120ms ease, box-shadow 120ms ease;
  content-visibility: auto;
  contain-intrinsic-size: auto 2rem;
  font-size: 0.82rem;

  &:hover {
    background: rgba(255, 255, 255, 0.06);
  }

  &.category-official {
    background: rgba(var(--bng-orange-500-rgb), 0.2);
    box-shadow: inset 0.22rem 0 rgba(var(--bng-orange-500-rgb), 0.95);
  }

  &.category-featured {
    background: rgba(var(--bng-add-green-550-rgb), 0.2);
    box-shadow: inset 0.22rem 0 rgba(var(--bng-add-green-550-rgb), 0.95);
  }

  &.category-partner {
    background: rgba(var(--bng-add-blue-500-rgb), 0.2);
    box-shadow: inset 0.22rem 0 rgba(var(--bng-add-blue-500-rgb), 0.95);
  }

  &.category-favorite {
    background: rgba(var(--bng-ter-yellow-500-rgb), 0.16);
    box-shadow: inset 0.22rem 0 rgba(var(--bng-ter-yellow-500-rgb), 0.95);
  }

  &.category-official:hover {
    background: rgba(var(--bng-orange-500-rgb), 0.3);
  }

  &.category-featured:hover {
    background: rgba(var(--bng-add-green-550-rgb), 0.3);
  }

  &.category-partner:hover {
    background: rgba(var(--bng-add-blue-500-rgb), 0.3);
  }
}

.location-cell {
  width: 3.5rem;
  text-align: center !important;
}

.title-cell {
  min-width: 18rem;
}

.server-title {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  line-height: 1.1;
}

.server-title-icon {
  display: inline-flex;
  width: 1rem;
  height: 1rem;
  object-fit: contain;
}

.location-flag {
  display: block;
  width: auto;
  height: 1rem;
  max-width: 2rem;
  margin: 0 auto;
  object-fit: contain;
  border-radius: 0.1rem;
  box-shadow: 0 0.08rem 0.2rem rgba(0, 0, 0, 0.45);
}

.filter-option-icon--beamng {
  width: 1rem;
  height: 1rem;
  display: inline-block;
  flex: 0 0 1rem;
  background-color: var(--bng-orange-400);
  -webkit-mask: url("/ui/ui-vue/src/assets/fonts/bngIcons/svg/beamNG.svg") center / contain no-repeat;
  mask: url("/ui/ui-vue/src/assets/fonts/bngIcons/svg/beamNG.svg") center / contain no-repeat;
}

.details-cell {
  width: 5.5rem;
  text-align: right !important;
}

.details-button {
  min-width: 4.6rem;
  padding: 0.25rem 0.55rem;
  border: 1px solid rgba(255, 255, 255, 0.16);
  border-radius: var(--bng-corners-1);
  color: var(--bng-off-white);
  background: rgba(var(--bng-add-blue-500-rgb), 0.45);
  font: inherit;
  font-size: 0.78rem;
  font-weight: 700;
  cursor: pointer;

  &:hover {
    border-color: rgba(255, 255, 255, 0.32);
    background: rgba(var(--bng-add-blue-500-rgb), 0.62);
  }
}

.selected {
  background: rgba(var(--bng-orange-500-rgb), 0.25);
}

.details {
  margin: 0;
  padding: 0.8rem;
  border-radius: 0;
  background: rgba(17, 17, 17, 0.7);
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.details-row td {
  padding: 0 !important;
  border-bottom: 1px solid rgba(255, 255, 255, 0.08);
}

.details-grid {
  display: grid;
  grid-template-columns: minmax(0, 2fr) minmax(0, 1fr);
  gap: 0.75rem;
}

.info-panel,
.players-panel,
.mods-panel {
  background: rgba(255, 255, 255, 0.03);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: var(--bng-corners-1);
  padding: 0.65rem;
}

.server-title {
  margin: 0;
  font-size: 1.05rem;
}

.server-title--detail {
  gap: 0.4rem;
  font-size: 1.1rem;
}

.section-header {
  margin: 0 0 0.5rem;
  font-size: 0.95rem;
  color: var(--bng-cool-gray-100);
}

.description-table {
  width: 100%;
  border-collapse: collapse;

  th,
  td {
    padding: 0.22rem 0;
    border: 0;
    vertical-align: top;
  }

  th {
    width: 8rem;
    color: var(--bng-cool-gray-200);
    font-weight: 600;
  }
}

.desc-cell {
  white-space: pre-wrap;
  word-break: break-word;
}

.tag-list-container {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
}

.chip {
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid rgba(255, 255, 255, 0.15);
  border-radius: 999px;
  padding: 0.2rem 0.5rem;
  font-size: 0.82rem;
}

.chip-player {
  background: rgba(var(--bng-orange-500-rgb), 0.2);
  border-color: rgba(var(--bng-orange-500-rgb), 0.45);
}

.muted {
  color: var(--bng-cool-gray-300);
}

.actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

@media (max-width: 1180px) {
  .toolbar {
    grid-template-columns: 1fr;
  }

  .toolbar-main {
    flex-wrap: wrap;
  }

  .server-count {
    justify-self: end;
  }

  .browser-layout {
    grid-template-columns: minmax(0, 1fr) 20rem;
  }
}

@media (max-width: 900px) {
  .browser-layout {
    grid-template-columns: 1fr;
  }

  .filters-rail {
    position: static;
    max-height: none;
  }

  .details-grid {
    grid-template-columns: 1fr;
  }
}
</style>
