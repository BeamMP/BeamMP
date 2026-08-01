<template>
  <section class="current-server">
    <header class="page-header">
      <div>
        <span class="eyebrow">Current BeamMP session</span>
        <h2>{{ serverTitle }}</h2>
      </div>
      <span v-if="categoryLabel" class="category" :class="categoryClass">
        {{ categoryLabel }}
      </span>
    </header>

    <div v-if="loading" class="status-panel">
      Loading current server details…
    </div>

    <div v-else-if="!currentServer" class="status-panel status-panel--warning">
      No active BeamMP server was reported.
    </div>

    <template v-else>
      <div class="details-grid">
        <section class="panel">
          <h3>{{ $tt("ui.common.beammp.information") }}</h3>
          <dl>
            <div>
              <dt>{{ $tt("ui.options.protocols.address") }}</dt>
              <dd>
                <button
                  class="endpoint-reveal"
                  type="button"
                  :aria-pressed="endpointVisible"
                  :title="endpointVisible ? $tt('ui.beammp.server.hideAddress') : $tt('ui.beammp.server.revealAddress')"
                  @click="endpointVisible = !endpointVisible"
                >
                  <span :class="{ concealed: !endpointVisible }">{{ currentEndpoint }}</span>
                  <small>{{ endpointVisible ? $tt('ui.common.beammp.hide') : $tt('ui.common.beammp.reveal') }}</small>
                </button>
              </dd>
            </div>
            <div>
              <dt>{{ $tt("ui.beammp.serverBrowser.server.owner") }}</dt>
              <dd>{{ currentServer.owner || "—" }}</dd>
            </div>
            <div>
              <dt>{{ $tt("ui.beammp.serverBrowser.server.map") }}</dt>
              <dd>{{ currentServer.mapName || currentServer.map || "—" }}</dd>
            </div>
            <div>
              <dt>{{ $tt("ui.common.beammp.players") }}</dt>
              <dd>{{ playerCount }}</dd>
            </div>
          </dl>
        </section>

        <section class="panel">
          <h3>{{ $tt("ui.beammp.serverBrowser.server.tags") }}</h3>
          <div v-if="!serverTags.length" class="muted">
            {{ $tt("ui.beammp.server.noTags") }}
          </div>
          <div v-else class="chips">
            <span v-for="tag in serverTags" :key="tag.raw" class="chip">{{ tag.text }}</span>
          </div>
        </section>
      </div>

      <section class="panel">
        <h3>{{ $tt("ui.beammp.serverBrowser.server.description") }}</h3>
        <p class="description">{{ currentServer.sdesc || "No description supplied." }}</p>
      </section>

      <section class="panel">
        <div class="panel-heading">
          <h3>{{ $tt("ui.common.beammp.mods") }}</h3>
          <span>{{ displayedMods.length }}</span>
        </div>
        <div v-if="!displayedMods.length" class="muted">
          {{ $tt("ui.common.beammp.vanilla") }}
        </div>
        <div v-else class="chips">
          <span v-for="modName in displayedMods" :key="modName" class="chip chip--mod">{{ modName }}</span>
        </div>
        <small v-if="currentServer.modstotalsize">
          {{ $tt("ui.beammp.serverBrowser.server.modsTotalFilesize") }} {{ formatBytes(currentServer.modstotalsize) }}
        </small>
      </section>

      <div class="actions">
        <BngButton @click="resume">Resume</BngButton>
        <BngButton accent="secondary" @click="openServerList">Open Server List</BngButton>
      </div>
    </template>
  </section>
</template>

<script setup>
import { computed, onMounted, onUnmounted, ref } from "vue"
import { useRouter } from "vue-router"
import { useBridge } from "@/bridge"
import { BngButton } from "@/common/components/base"
import { BEAMMP_SERVERS_ROUTE_NAME } from "../shared/constants.js"
import { useBeamMPState } from "../shared/beammpState.js"

const { events } = useBridge()
const router = useRouter()
const bngVue = window.bngVue || { gotoGameState() {} }
const {
  extensionCall,
  formatBytes,
  modList,
  requestServerList,
  setView,
  state,
} = useBeamMPState(events)

const coreServer = ref(null)
const sessionMods = ref([])
const loading = ref(true)
const endpointVisible = ref(false)

const currentEndpoint = computed(() => {
  if (!coreServer.value?.ip || !coreServer.value?.port) return ""
  return `${coreServer.value.ip}:${coreServer.value.port}`
})

const listedServer = computed(() => {
  if (!currentEndpoint.value) return null
  return state.servers.value.find(server => server.endpoint === currentEndpoint.value) || null
})

const currentServer = computed(() => {
  if (!coreServer.value) return null
  return {
    ...coreServer.value,
    ...(listedServer.value || {}),
  }
})

const serverTitle = computed(() => (
  currentServer.value?.strippedName
  || currentServer.value?.name
  || currentEndpoint.value
  || "Server Details"
))

const serverTags = computed(() => currentServer.value?.tagsList || [])

const displayedMods = computed(() => {
  const listedMods = modList(currentServer.value?.modlist || "")
  return listedMods.length ? listedMods : sessionMods.value
})

const playerCount = computed(() => {
  const server = currentServer.value
  if (server?.players !== undefined && server?.maxplayers !== undefined) {
    return `${server.players}/${server.maxplayers}`
  }
  return "—"
})

const categoryLabel = computed(() => {
  if (currentServer.value?.official) return "Official"
  if (currentServer.value?.featured) return "Featured"
  if (currentServer.value?.partner) return "Partner"
  return ""
})

const categoryClass = computed(() => (
  categoryLabel.value ? `category--${categoryLabel.value.toLowerCase()}` : ""
))

function normalizeMods(value) {
  if (Array.isArray(value)) return value.filter(Boolean).map(String)
  if (!value || typeof value !== "object") return []
  return Object.keys(value)
    .sort((a, b) => Number(a) - Number(b))
    .map(key => value[key])
    .filter(Boolean)
    .map(String)
}

function updateSessionMods(value) {
  sessionMods.value = normalizeMods(value)
}

async function refreshCurrentServer() {
  loading.value = true
  const [server, mods] = await Promise.all([
    extensionCall("MPCoreNetwork", "getCurrentServer"),
    extensionCall("MPModManager", "getServerMods"),
  ])
  coreServer.value = server || null
  updateSessionMods(mods)
  loading.value = false
}

function resume() {
  bngVue.gotoGameState("play")
}

function openServerList() {
  setView("servers")
  router.push({ name: BEAMMP_SERVERS_ROUTE_NAME })
}

onMounted(async () => {
  events.on("onBeamMPServerModsChanged", updateSessionMods)
  refreshCurrentServer()
  await requestServerList()
})

onUnmounted(() => {
  events.off("onBeamMPServerModsChanged", updateSessionMods)
})
</script>

<style scoped lang="scss">
.current-server {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  max-width: 70rem;
}

.page-header,
.panel-heading,
.actions {
  display: flex;
  align-items: center;
}

.page-header {
  justify-content: space-between;
  gap: 1rem;
  padding: 0.25rem 0.2rem 0.7rem;
  border-bottom: 1px solid rgba(255, 255, 255, 0.14);

  h2 {
    margin: 0.15rem 0 0;
  }
}

.eyebrow {
  color: var(--bng-orange-300);
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
}

.details-grid {
  display: grid;
  grid-template-columns: minmax(0, 2fr) minmax(16rem, 1fr);
  gap: 0.75rem;
}

.panel,
.status-panel {
  padding: 0.8rem;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: var(--bng-corners-2);
  background: rgba(12, 16, 22, 0.72);
}

.panel h3 {
  margin: 0 0 0.65rem;
  font-size: 0.95rem;
}

.panel-heading {
  justify-content: space-between;

  span {
    min-width: 1.8rem;
    padding: 0.15rem 0.4rem;
    border-radius: 999px;
    background: var(--bng-orange-500);
    text-align: center;
    font-weight: 700;
  }
}

dl {
  margin: 0;

  div {
    display: grid;
    grid-template-columns: 8rem minmax(0, 1fr);
    gap: 0.75rem;
    padding: 0.28rem 0;
  }
}

dt {
  color: var(--bng-cool-gray-300);
  font-weight: 600;
}

dd {
  margin: 0;
  overflow-wrap: anywhere;
}

.endpoint-reveal {
  display: inline-flex;
  align-items: center;
  gap: 0.65rem;
  max-width: 100%;
  padding: 0.2rem 0.45rem;
  border: 1px solid rgba(255, 255, 255, 0.14);
  border-radius: var(--bng-corners-1);
  color: var(--bng-off-white);
  background: rgba(255, 255, 255, 0.05);
  cursor: pointer;

  .concealed {
    filter: blur(0.32rem);
    opacity: 0.65;
    user-select: none;
  }

  small {
    margin: 0;
    color: var(--bng-orange-300);
    font-size: 0.7rem;
    font-weight: 700;
    text-transform: uppercase;
  }
}

.description {
  margin: 0;
  white-space: pre-wrap;
}

.chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
}

.chip {
  padding: 0.2rem 0.5rem;
  border: 1px solid rgba(255, 255, 255, 0.15);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.08);
  font-size: 0.82rem;
}

.chip--mod {
  border-color: rgba(var(--bng-orange-500-rgb), 0.35);
}

.category {
  padding: 0.28rem 0.65rem;
  border-radius: 999px;
  font-size: 0.8rem;
  font-weight: 700;
}

.category--official {
  background: rgba(var(--bng-orange-500-rgb), 0.28);
  color: var(--bng-orange-200);
}

.category--featured {
  background: rgba(var(--bng-add-green-550-rgb), 0.28);
  color: var(--bng-add-green-200);
}

.category--partner {
  background: rgba(var(--bng-add-blue-500-rgb), 0.28);
  color: var(--bng-add-blue-200);
}

.muted,
small {
  color: var(--bng-cool-gray-300);
}

small {
  display: block;
  margin-top: 0.55rem;
}

.status-panel--warning {
  border-color: rgba(var(--bng-ter-yellow-500-rgb), 0.45);
}

.actions {
  gap: 0.5rem;
}

@media (max-width: 850px) {
  .details-grid {
    grid-template-columns: 1fr;
  }
}
</style>
