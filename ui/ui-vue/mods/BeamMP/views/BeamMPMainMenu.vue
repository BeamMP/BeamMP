<template>
  <div
    class="beammp-route"
    bng-ui-scope="beammp-route"
    v-bng-scoped-nav="{ scopeId: 'beammp-route', activateOnMount: true }"
    v-bng-blur
  >
    <header class="topbar">
      <BngButton
        class="back-button"
        :accent="ACCENTS.custom_old"
        :icon-left="icons.arrowSmallLeft"
        @click="goBack"
      >
        {{ $tt("ui.common.menu") }}
      </BngButton>

      <div class="topbar-tools">
        <div class="metrics">
          <span class="metric-item">
            <img src="../icons/account-multiple.svg" alt="" />
            <span>Players: {{ state.beammpMetrics.value.players }}</span>
          </span>
          <span class="metric-item">
            <img src="../icons/dns.svg" alt="" />
            <span>Servers: {{ state.beammpMetrics.value.servers }}</span>
          </span>
        </div>

        <section v-if="state.loggedIn.value" class="account-panel" aria-label="BeamMP account">
          <img
            class="account-avatar"
            :src="accountAvatar"
            alt=""
            @error="useFallbackAvatar"
          />
          <div class="account-details">
            <strong>{{ accountName }}</strong>
            <small>{{ accountRole }}</small>
          </div>
          <BngButton accent="secondary" class="logout-button" @click="handleLogout">
            {{ $tt("ui.multiplayer.logout") }}
          </BngButton>
        </section>
      </div>
    </header>

    <main class="main-grid">
      <aside class="sidebar">
        <img src="/ui/modModulesOLD/multiplayer/beammp_new_cropped.png" alt="BeamMP" class="logo" />
        <div class="beammp-version">
          <span aria-hidden="true" />
          BeamMP v{{ state.beammpMetrics.value.beammpGameVer }}
        </div>

        <button class="nav-btn" :class="{ active: isServerView('servers') }" @click="gotoView('servers')">{{ $tt("ui.multiplayer.servers") }}</button>
        <button class="nav-btn category-official" :class="{ active: isServerView('official') }" @click="gotoView('official')">{{ $tt("ui.multiplayer.official") }}</button>
        <button class="nav-btn category-featured" :class="{ active: isServerView('featured') }" @click="gotoView('featured')">{{ $tt("ui.multiplayer.featured") }}</button>
        <button class="nav-btn category-partner" :class="{ active: isServerView('partner') }" @click="gotoView('partner')">{{ $tt("ui.multiplayer.partner") }}</button>
        <button class="nav-btn category-favorite" :class="{ active: isServerView('favorites') }" @click="gotoView('favorites')">{{ $tt("ui.multiplayer.favorites") }}</button>
        <button class="nav-btn" :class="{ active: isServerView('recent') }" @click="gotoView('recent')">{{ $tt("ui.multiplayer.recent") }}</button>
        <button class="nav-btn" :class="{ active: route.name === BEAMMP_DIRECT_ROUTE_NAME }" @click="gotoRoute(BEAMMP_DIRECT_ROUTE_NAME)">{{ $tt("ui.multiplayer.direct_connect") }}</button>
        <button class="nav-btn" :class="{ active: route.name === BEAMMP_TILES_ROUTE_NAME }" @click="gotoRoute(BEAMMP_TILES_ROUTE_NAME)">Tiles</button>

        <div class="spacer" />

        <button class="nav-btn secondary" @click="openExternal('https://forum.beammp.com')">{{ $tt("ui.multiplayer.forum") }}</button>
        <button class="nav-btn secondary" @click="openExternal('https://discord.gg/BeamMP')">{{ $tt("ui.multiplayer.discord") }}</button>
        <button class="nav-btn secondary" @click="openExternal('https://docs.beammp.com')">{{ $tt("ui.multiplayer.docs") }}</button>
        <button class="nav-btn secondary" @click="openExternal('https://github.com/BeamMP/')">{{ $tt("ui.multiplayer.github") }}</button>
      </aside>

      <section ref="contentPanel" class="content">
        <RouterView />
      </section>
    </main>

    <div v-if="state.loadingOverlayVisible.value" class="loading-overlay">
      <div class="loading-card">
        <h2>{{ $tt("ui.multiplayer.connectingToServer") }}</h2>
        <p>{{ state.loadingStatus.value || $tt("ui.multiplayer.connecting") }}</p>

        <div v-if="state.downloadingMods.value.length" class="mods-list">
          <div
            v-for="(mod, index) in state.downloadingMods.value"
            :key="`${mod.number}:${mod.name}`"
            class="mod-row"
            :class="{ complete: index > 0 || mod.progress >= 100 }"
          >
            <span class="download-state" aria-hidden="true">{{ index > 0 || mod.progress >= 100 ? "✓" : "↓" }}</span>
            <div class="download-info">
              <div class="download-line">
                <code>{{ mod.number }} - {{ mod.name }}</code>
                <small>{{ index === 0 ? mod.speed : $tt("ui.multiplayer.download.downloaded") }}</small>
              </div>
              <div v-if="index === 0 && mod.progress < 100" class="progress-track">
                <span :style="{ width: `${Math.max(0, Math.min(100, mod.progress))}%` }" />
              </div>
            </div>
          </div>
        </div>

        <div class="loading-footer">
          <span>BeamMP v{{ state.beammpMetrics.value.beammpGameVer }}</span>
          <BngButton @click="closeLoadingOverlay">{{ $tt("ui.common.cancel") }}</BngButton>
        </div>
      </div>
    </div>

    <BeamMPModal
      :visible="state.securityPromptVisible.value"
      :title="$tt('ui.multiplayer.security.title')"
      :message="state.securityPromptMessage.value || $tt('ui.multiplayer.security.prompt')"
      :confirm-text="$tt('ui.multiplayer.security.accept_proceed')"
      :cancel-text="$tt('ui.multiplayer.security.no_return')"
      @confirm="approveSecurityPrompt"
      @cancel="rejectSecurityPrompt"
    />
  </div>
</template>

<script setup>
import { computed, nextTick, onMounted, ref, watch } from "vue"
import { RouterView, useRoute, useRouter } from "vue-router"
import { useBridge } from "@/bridge"
import { BngButton, ACCENTS, icons } from "@/common/components/base"
import { vBngBlur, vBngScopedNav } from "@/common/directives"
import {
  BEAMMP_CURRENT_SERVER_ROUTE_NAME,
  BEAMMP_DIRECT_ROUTE_NAME,
  BEAMMP_LAUNCHER_ROUTE_NAME,
  BEAMMP_LOGIN_ROUTE_NAME,
  BEAMMP_SERVERS_ROUTE_NAME,
  BEAMMP_TILES_ROUTE_NAME,
  BEAMMP_TOS_ROUTE_NAME,
} from "../shared/constants.js"
import { useBeamMPState } from "../shared/beammpState.js"
import BeamMPModal from "../shared/BeamMPModal.vue"

const { events } = useBridge()
const route = useRoute()
const router = useRouter()
const bngVue = window.bngVue || { goBack() {} }
const authStateReady = ref(false)
const contentPanel = ref(null)

const {
  state,
  closeLoadingOverlay,
  loadFavorites,
  logout,
  openExternal,
  approveSecurityPrompt,
  rejectSecurityPrompt,
  refreshConnectionState,
  requestServerList,
  setView,
} = useBeamMPState(events)

async function gotoRoute(name) {
  if (route.name === name) return
  await router.push({ name })
  scrollContentToTop()
}

async function gotoView(view) {
  const nextView = view || "servers"
  const currentView = String(route.params.view || "servers")
  if (route.name === BEAMMP_SERVERS_ROUTE_NAME && currentView === nextView) {
    setView(nextView)
    scrollContentToTop()
    return
  }
  setView(nextView)
  await router.replace({
    name: BEAMMP_SERVERS_ROUTE_NAME,
    params: { view: nextView === "servers" ? "" : nextView },
  })
  scrollContentToTop()
}

function isServerView(view) {
  return route.name === BEAMMP_SERVERS_ROUTE_NAME && state.view.value === view
}

async function scrollContentToTop() {
  await nextTick()
  if (contentPanel.value) contentPanel.value.scrollTop = 0
}

const fallbackAvatar = "/ui/ui-vue/mods/BeamMP/icons/account-multiple.svg"
const accountAvatar = computed(() => {
  const avatar = String(state.auth.value?.avatar || "")
  if (!avatar || avatar.includes("Q291bGQgbm90IGVzdGFibGlzaCBjb25uZWN0aW9u")) {
    return fallbackAvatar
  }
  return avatar
})
const accountName = computed(() => state.auth.value?.username || "Guest")
const accountRole = computed(() => state.auth.value?.role || "BeamMP")

function useFallbackAvatar(event) {
  const image = event.currentTarget
  image.onerror = null
  image.src = fallbackAvatar
}

async function handleLogout() {
  await logout()
  await router.replace({ name: BEAMMP_LOGIN_ROUTE_NAME })
}

async function goBack() {
  bngVue.goBack()
}

const unauthenticatedRoutes = new Set([
  BEAMMP_LAUNCHER_ROUTE_NAME,
  BEAMMP_LOGIN_ROUTE_NAME,
  BEAMMP_TOS_ROUTE_NAME,
])

function enforceAuthentication() {
  if (!authStateReady.value || state.loggedIn.value) return
  if (!unauthenticatedRoutes.has(route.name)) {
    router.replace({ name: BEAMMP_LOGIN_ROUTE_NAME })
  }
}

watch(
  [() => route.name, () => state.loggedIn.value, authStateReady],
  enforceAuthentication,
  { flush: "post" },
)

onMounted(async () => {
  await loadFavorites()
  await refreshConnectionState()
  if (state.loggedIn.value) await requestServerList()
  authStateReady.value = true

  if (!state.tosAccepted.value) {
    router.replace({ name: BEAMMP_TOS_ROUTE_NAME })
    return
  }
  if (!state.launcherConnected.value) {
    router.replace({ name: BEAMMP_LAUNCHER_ROUTE_NAME })
    return
  }
  if (!state.loggedIn.value) {
    router.replace({ name: BEAMMP_LOGIN_ROUTE_NAME })
    return
  }

  const contentRoutes = new Set([
    BEAMMP_CURRENT_SERVER_ROUTE_NAME,
    BEAMMP_DIRECT_ROUTE_NAME,
    BEAMMP_SERVERS_ROUTE_NAME,
    BEAMMP_TILES_ROUTE_NAME,
  ])
  if (!contentRoutes.has(route.name)) {
    router.replace({ name: BEAMMP_SERVERS_ROUTE_NAME })
  }
})
</script>

<style scoped lang="scss">
.beammp-route {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  padding: 1rem;
  gap: 0.75rem;
  color: var(--bng-off-white);
  pointer-events: all;
  background:
    linear-gradient(120deg, rgba(22, 22, 22, 0.95), rgba(39, 39, 39, 0.88)),
    radial-gradient(circle at 85% 10%, rgba(var(--bng-orange-500-rgb), 0.22), transparent 35%);
}

.topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}

.topbar-tools {
  display: flex;
  min-width: 0;
  align-items: stretch;
  justify-content: flex-end;
  gap: 0.55rem;
  margin-right: 2.75rem;
}

.metrics {
  display: grid;
  width: 18rem;
  flex: 0 0 18rem;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  align-items: center;
  gap: 0;
  padding: 0.5rem 0.75rem;
  border-radius: var(--bng-corners-2);
  background: rgba(0, 0, 0, 0.35);

  .metric-item {
    display: flex;
    min-width: 0;
    align-items: center;
    gap: 0.35rem;
    white-space: nowrap;

    + .metric-item {
      margin-left: 0.65rem;
      padding-left: 0.65rem;
      border-left: 1px solid rgba(255, 255, 255, 0.16);
    }
  }

  img {
    width: 1rem;
    height: 1rem;
    flex: 0 0 1rem;
    filter: brightness(1.6);
  }
}

.account-panel {
  display: flex;
  min-width: 15rem;
  align-items: center;
  gap: 0.55rem;
  padding: 0.3rem 0.4rem 0.3rem 0.35rem;
  border: 1px solid rgba(255, 255, 255, 0.14);
  border-radius: var(--bng-corners-2);
  background: rgba(0, 0, 0, 0.42);
}

.account-avatar {
  box-sizing: border-box;
  width: 2.2rem;
  height: 2.2rem;
  flex: 0 0 2.2rem;
  object-fit: cover;
  border: 1px solid rgba(var(--bng-orange-500-rgb), 0.65);
  border-radius: 50%;
  background: var(--bng-cool-gray-700);
}

.account-details {
  display: flex;
  min-width: 5rem;
  flex: 1;
  flex-direction: column;
  line-height: 1.1;

  strong {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  small {
    margin-top: 0.16rem;
    color: var(--bng-cool-gray-300);
    font-size: 0.72rem;
    text-transform: capitalize;
  }
}

.logout-button {
  flex: 0 0 auto;
}

.main-grid {
  flex: 1;
  min-height: 0;
  display: grid;
  grid-template-columns: 16rem minmax(0, 1fr);
  gap: 0.75rem;
}

.sidebar {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  min-height: 0;
  overflow: auto;
  padding: 0.75rem 0.75rem 3.25rem;
  border: 1px solid rgba(var(--bng-orange-400-rgb), 0.35);
  border-radius: var(--bng-corners-2);
  background: rgba(0, 0, 0, 0.35);
}

.logo {
  width: 8.5rem;
  margin-bottom: 0.1rem;
}

.beammp-version {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  margin-bottom: 0.45rem;
  color: var(--bng-cool-gray-200);
  font-size: 0.76rem;
  font-weight: 600;

  span {
    width: 0.18rem;
    height: 1.25rem;
    background: var(--bng-orange-500);
    transform: skew(-18deg);
  }
}

.nav-btn {
  border: 1px solid rgba(255, 255, 255, 0.15);
  color: var(--bng-off-white);
  background: rgba(36, 36, 36, 0.75);
  border-radius: var(--bng-corners-1);
  text-align: left;
  padding: 0.45rem 0.6rem;
  cursor: pointer;
  transition: border-color 100ms ease, background-color 100ms ease, box-shadow 100ms ease;

  &:hover {
    border-color: rgba(var(--bng-orange-500-rgb), 0.8);
    background: rgba(var(--bng-orange-500-rgb), 0.2);
  }

  &.active {
    border-color: rgba(var(--bng-orange-500-rgb), 0.9);
    background: rgba(var(--bng-orange-500-rgb), 0.28);
    box-shadow: inset 0.22rem 0 var(--bng-orange-500);
  }

  &:focus-visible {
    outline: 0.12rem solid var(--bng-orange-500);
    outline-offset: 0.08rem;
  }

  &.category-official {
    border-left: 0.22rem solid rgba(var(--bng-orange-500-rgb), 0.95);
  }

  &.category-featured {
    border-left: 0.22rem solid rgba(var(--bng-add-green-550-rgb), 0.95);
  }

  &.category-partner {
    border-left: 0.22rem solid rgba(var(--bng-add-blue-500-rgb), 0.95);
  }

  &.category-favorite {
    border-left: 0.22rem solid rgba(var(--bng-ter-yellow-500-rgb), 0.95);
  }
}

.secondary {
  opacity: 0.9;
}

.spacer {
  flex: 1;
}

.content {
  min-height: 0;
  overflow: auto;
  border: 1px solid rgba(var(--bng-orange-400-rgb), 0.35);
  border-radius: var(--bng-corners-2);
  background: rgba(0, 0, 0, 0.28);
  padding: 0.9rem;
}

.loading-overlay {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  background: rgba(0, 0, 0, 0.72);
}

.loading-card {
  width: min(44rem, 94vw);
  max-height: 80vh;
  overflow: auto;
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
  background: rgba(16, 16, 16, 0.95);
  border: 1px solid rgba(var(--bng-orange-500-rgb), 0.55);
  border-radius: var(--bng-corners-2);
  padding: 1rem;
}

.mods-list {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}

.mod-row {
  display: flex;
  align-items: flex-start;
  gap: 0.65rem;
  background: rgba(255, 255, 255, 0.05);
  padding: 0.4rem 0.55rem;
  border-radius: var(--bng-corners-1);

  &.complete .download-state {
    color: var(--bng-add-green-400);
  }

  small {
    color: var(--bng-cool-gray-300);
  }
}

.download-state {
  display: grid;
  width: 1.35rem;
  height: 1.35rem;
  flex: 0 0 1.35rem;
  place-items: center;
  color: var(--bng-orange-400);
  font-weight: 800;
}

.download-info {
  min-width: 0;
  flex: 1;
}

.download-line {
  display: flex;
  justify-content: space-between;
  gap: 0.75rem;

  code {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
}

.progress-track {
  height: 0.35rem;
  margin-top: 0.4rem;
  overflow: hidden;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.12);

  span {
    display: block;
    height: 100%;
    border-radius: inherit;
    background: var(--bng-orange-500);
    transition: width 120ms linear;
  }
}

.loading-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  margin-top: 0.25rem;
  color: var(--bng-cool-gray-300);
  font-size: 0.78rem;
}

@media (max-width: 1000px) {
  .topbar-tools {
    flex-wrap: wrap;
  }

  .main-grid {
    grid-template-columns: 1fr;
  }
}
</style>
