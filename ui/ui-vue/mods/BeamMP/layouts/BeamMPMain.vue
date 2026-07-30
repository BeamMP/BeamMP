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
            <span>{{ $tt("ui.common.beammp.players") }}: {{ state.beammpMetrics.value.players }}</span>
          </span>
          <span class="metric-item">
            <img src="../icons/dns.svg" alt="" />
            <span>{{ $tt("ui.common.beammp.servers") }}: {{ state.beammpMetrics.value.servers }}</span>
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
            {{ $tt("ui.beammp.accounts.logout") }}
          </BngButton>
        </section>
      </div>
    </header>

    <main class="main-grid" :style="{ marginBottom: infobarMarginBottom }">
      <aside class="sidebar">
        <img src="/ui/assets/BeamMP/beammp_new_cropped.png" alt="BeamMP" class="logo" />
        <div class="beammp-version">
          <span aria-hidden="true" />
          {{ $tt("ui.common.beammp.beammp") }} v{{ state.beammpMetrics.value.beammpGameVer }}
        </div>

        <button class="nav-btn" :class="{ active: isServerView('servers') }" @click="gotoView('servers')">{{ $tt("ui.common.beammp.servers") }}</button>
        <button class="nav-btn category-official" :class="{ active: isServerView('official') }" @click="gotoView('official')">{{ $tt("ui.common.beammp.official") }}</button>
        <button class="nav-btn category-featured" :class="{ active: isServerView('featured') }" @click="gotoView('featured')">{{ $tt("ui.common.beammp.featured") }}</button>
        <button class="nav-btn category-partner" :class="{ active: isServerView('partner') }" @click="gotoView('partner')">{{ $tt("ui.common.beammp.partner") }}</button>
        <button class="nav-btn category-favorite" :class="{ active: isServerView('favorites') }" @click="gotoView('favorites')">{{ $tt("ui.common.beammp.favorites") }}</button>
        <button class="nav-btn" :class="{ active: isServerView('recent') }" @click="gotoView('recent')">{{ $tt("ui.common.beammp.recent") }}</button>
        <button class="nav-btn" :class="{ active: route.name === BEAMMP_DIRECT_ROUTE_NAME }" @click="gotoRoute(BEAMMP_DIRECT_ROUTE_NAME)">{{ $tt("ui.common.beammp.direct_connect") }}</button>
        <!--<button class="nav-btn" :class="{ active: route.name === BEAMMP_TILES_ROUTE_NAME }" @click="gotoRoute(BEAMMP_TILES_ROUTE_NAME)">Tiles</button>-->

        <div class="spacer" />

        <button class="nav-btn secondary external-link external-link--patreon" @click="openExternal('https://www.patreon.com/BeamMP')">
          <img src="../icons/PATREON_SYMBOL_1_WHITE_RGB.svg" alt="" class="external-link-icon" />
          <span class="external-link-copy">
            <span class="external-link-title">{{ $tt("ui.common.beammp.patreon") }}</span>
            <small class="external-link-subtitle">{{ $tt("ui.beammp.patreon.message.user") }}</small>
          </span>
        </button>
        <button class="nav-btn secondary external-link" @click="openExternal('https://forum.beammp.com')">
          <img src="/ui/ui-vue/src/assets/fonts/bngIcons/svg/chatBubble.svg" alt="" class="external-link-icon external-link-icon--invert" />
          <span>{{ $tt("ui.common.beammp.forum") }}</span>
        </button>
        <button class="nav-btn secondary external-link" @click="openExternal('https://discord.gg/BeamMP')">
          <img src="../icons/icon_clyde_white_RGB.svg" alt="" class="external-link-icon" />
          <span>{{ $tt("ui.common.beammp.discord") }}</span>
        </button>
        <button class="nav-btn secondary external-link" @click="openExternal('https://docs.beammp.com')">
          <img src="/ui/ui-vue/src/assets/fonts/bngIcons/svg/info.svg" alt="" class="external-link-icon external-link-icon--invert" />
          <span>{{ $tt("ui.common.beammp.docs") }}</span>
        </button>
        <button class="nav-btn secondary external-link" @click="openExternal('https://github.com/BeamMP/')">
          <img src="../icons/github-mark.svg" alt="" class="external-link-icon" />
          <span>{{ $tt("ui.common.beammp.github") }}</span>
        </button>
      </aside>

      <section ref="contentPanel" class="content">
        <RouterView />
      </section>
    </main>

    <div v-if="state.loadingOverlayVisible.value" class="loading-overlay">
      <div class="loading-card">
        <h2>{{ $tt("ui.beammp.serverBrowser.connectingToServer") }}</h2>
        <p>{{ state.loadingStatus.value || $tt("ui.common.beammp.connecting") }}</p>

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
                <small>{{ index === 0 ? mod.speed : $tt("ui.beammp.download.downloaded") }}</small>
              </div>
              <div v-if="index === 0 && mod.progress < 100" class="progress-track">
                <span :style="{ width: `${Math.max(0, Math.min(100, mod.progress))}%` }" />
              </div>
            </div>
          </div>
        </div>

        <div class="loading-footer">
          <BngButton @click="closeLoadingOverlay">{{ $tt("ui.common.cancel") }}</BngButton>
        </div>
      </div>
    </div>

    <BeamMPModal
      :visible="state.securityPromptVisible.value"
      :title="$tt('ui.beammp.serverBrowser.modSecurityWarning.title')"
      :message="state.securityPromptMessage.value || $tt('ui.beammp.serverBrowser.modSecurityWarning.prompt')"
      :confirm-text="$tt('ui.beammp.serverBrowser.modSecurityWarning.accept_proceed')"
      :cancel-text="$tt('ui.beammp.serverBrowser.modSecurityWarning.no_return')"
      @confirm="approveSecurityPrompt"
      @cancel="rejectSecurityPrompt"
    />
  </div>
</template>

<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from "vue"
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
const infobarMarginBottom = ref("1.75rem")
let infobarResizeObserver = null

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

const fallbackAvatar = "/ui/ui-vue/src/assets/fonts/bngIcons/svg/personSolid.svg"
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

function updateInfobarMarginBottom() {
  const element = document.querySelector("#vue-app > div.vue-app-main > div.app-infobar-wrapper")
  if (!element) return
  const height = Math.ceil(element.getBoundingClientRect().height)
  if (height > 0) {
    infobarMarginBottom.value = `${height-24}px`
  }
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
  updateInfobarMarginBottom()
  const element = document.querySelector("#vue-app > div.vue-app-main > div.app-infobar-wrapper")
  if (element && "ResizeObserver" in window) {
    infobarResizeObserver = new ResizeObserver(() => updateInfobarMarginBottom())
    infobarResizeObserver.observe(element)
  }

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

onBeforeUnmount(() => {
  if (infobarResizeObserver) {
    infobarResizeObserver.disconnect()
    infobarResizeObserver = null
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
  flex-wrap: nowrap;
  gap: 0.55rem;
  margin-right: 2.75rem;
  max-width: calc(100% - 2.75rem);
}

.metrics {
  display: flex;
  flex: 0 1 auto;
  min-width: fit-content;
  flex-wrap: nowrap;
  align-items: center;
  gap: 0;
  padding: 0.5rem 0.75rem;
  border-radius: var(--bng-corners-2);
  background: rgba(0, 0, 0, 0.35);

  .metric-item {
    display: flex;
    flex: 0 1 auto;
    min-width: fit-content;
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
  flex: 0 1 19rem;
  min-width: 14.5rem;
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
  padding: 0.75rem 0.75rem;
  border: 1px solid rgba(var(--bng-orange-400-rgb), 0.35);
  border-radius: var(--bng-corners-2);
  background: rgba(0, 0, 0, 0.35);
}

.logo {
  width: 8.5rem;
  display: block;
  margin: 1rem auto;
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

.external-link {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;

  .external-link-icon {
    width: 1rem;
    height: 1rem;
    flex: 0 0 1rem;
    object-fit: contain;
  }

  .external-link-icon--invert {
    filter: contrast(0) brightness(2);
  }

  span {
    line-height: 1;
  }

  .external-link-copy {
    display: inline-flex;
    min-width: 0;
    flex: 1;
    flex-direction: column;
    align-items: flex-start;
    gap: 0.12rem;
  }

  .external-link-title {
    font-weight: 600;
    line-height: 1;
  }

  .external-link-subtitle {
    color: var(--bng-cool-gray-300);
    font-size: 0.68rem;
    line-height: 1.2;
    white-space: normal;
  }
}

.external-link--patreon {
  border-color: rgba(var(--bng-add-green-550-rgb), 0.92);
  background: rgba(var(--bng-add-green-550-rgb), 0.2);

  &:hover {
    border-color: rgba(var(--bng-add-green-550-rgb), 1);
    background: rgba(var(--bng-add-green-550-rgb), 0.32);
  }

  .external-link-subtitle {
    color: var(--bng-add-green-200);
  }
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
  padding: 0.9rem 0.9rem;
}

.loading-overlay {
  position: absolute;
  inset: 0;
  display: grid;
  place-items: center;
  background: rgba(0, 0, 0, 0.72);
}

.loading-card {
  box-sizing: border-box;
  width: min(50vw, 56rem);
  max-width: 94vw;
  max-height: 40vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  background: rgba(16, 16, 16, 0.95);
  border: 0.125rem solid var(--bng-cool-gray-700);
  border-radius: var(--bng-corners-3);
  padding: 1.25rem;

  h2 {
    margin: 0 0 0.35rem;
  }

  > p {
    margin: 0;
  }
}

.mods-list {
  display: flex;
  flex-direction: column;
  height: 25vh;
  overflow-x: hidden;
  overflow-y: auto;
  gap: 0;
  margin-top: 0.5rem;
  padding: 0.25rem 0.25rem 0;
  border-radius: var(--bng-corners-1);
  background: rgba(255, 255, 255, 0.06);
}

.mod-row {
  display: flex;
  align-items: center;
  gap: 1rem;
  min-height: 1.8rem;
  margin-bottom: 0.6rem;
  padding: 0.1rem 0.35rem;

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
  align-items: baseline;
  justify-content: flex-start;
  gap: 0.45rem;

  code {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
}

.progress-track {
  height: 0.35rem;
  margin-top: 0.3rem;
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
  justify-content: flex-end;
  gap: 1rem;
  margin-top: 0.5rem;
}

@media (max-width: 1000px) {
  .topbar-tools {
    gap: 0.35rem;
    margin-right: 2rem;
    max-width: calc(100% - 2rem);
  }

  .metrics {
    padding-inline: 0.55rem;
    font-size: 0.88rem;
  }

  .account-panel {
    min-width: 12.5rem;
  }

  .main-grid {
    grid-template-columns: 1fr;
  }
}
</style>
