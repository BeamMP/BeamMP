<template>
  <div class="card">
    <header class="card-header">
      <div>
        <h3>{{ $tt("ui.playmodes.multiplayer") }}</h3>
        <p class="subtitle">BeamMP session controls</p>
      </div>
      <div class="identity">
        <span class="online-dot"></span>
        <span>{{ state.auth.value?.username || "Guest" }}</span>
      </div>
    </header>

    <div class="actions">
      <Button class="action action--primary" @click="resume">
        <template #prefix><BngIcon :type="icons.play" /></template>
        <span>{{ $tt("ui.common.action.resume") }}</span>
      </Button>
      <Button class="action" @click="openBrowser">
        <template #prefix><BngIcon :type="icons.info" /></template>
        <span>{{ $tt("ui.multiplayer.pauseMenu.serverDetails") }}</span>
      </Button>
      <Button class="action action--wide" @click="openServerList">
        <template #prefix><BngIcon :type="icons.globe" /></template>
        <span>Server List</span>
      </Button>
      <Button class="action" @click="showLeaveConfirm = true">
        <template #prefix><BngIcon :type="icons.exit" /></template>
        <span>{{ $tt("ui.multiplayer.pauseMenu.disconnect") }}</span>
      </Button>
      <Button class="action action--danger" @click="showQuitConfirm = true">
        <template #prefix><BngIcon :type="icons.powerOnOff" /></template>
        <span>{{ $tt("ui.multiplayer.pauseMenu.quitGame") }}</span>
      </Button>
    </div>

    <BeamMPModal
      :visible="showLeaveConfirm"
      :title="$tt('ui.multiplayer.pauseMenu.areYouSure')"
      :message="$tt('ui.multiplayer.pauseMenu.disconnectConfirmation')"
      :confirm-text="$tt('ui.multiplayer.pauseMenu.disconnect')"
      :cancel-text="$tt('ui.common.cancel')"
      @confirm="confirmLeaveServer"
      @cancel="showLeaveConfirm = false"
    />

    <BeamMPModal
      :visible="showQuitConfirm"
      :title="$tt('ui.multiplayer.pauseMenu.areYouSure')"
      :message="$tt('ui.multiplayer.pauseMenu.quitToDesktopConfirmation')"
      :confirm-text="$tt('ui.multiplayer.pauseMenu.quitToDesktop')"
      :cancel-text="$tt('ui.common.cancel')"
      @confirm="confirmQuitGame"
      @cancel="showQuitConfirm = false"
    />
  </div>
</template>

<script setup>
import { ref } from "vue"
import { lua, useBridge } from "@/bridge"
import { BngIcon, icons } from "@/common/components/base"
import { Button } from "@/common/components/utility"
import {
  BEAMMP_CURRENT_SERVER_ROUTE_NAME,
  BEAMMP_SERVERS_ROUTE_NAME,
} from "../shared/constants.js"
import BeamMPModal from "../shared/BeamMPModal.vue"
import { useBeamMPState } from "../shared/beammpState.js"

const bngVue = window.bngVue || { gotoGameState() {} }
const { api } = useBridge()
const { state } = useBeamMPState()
const showLeaveConfirm = ref(false)
const showQuitConfirm = ref(false)

function resume() {
  bngVue.gotoGameState("play")
}

function openBrowser() {
  lua.extensions.ui_router.push(BEAMMP_CURRENT_SERVER_ROUTE_NAME)
}

function openServerList() {
  lua.extensions.ui_router.push(BEAMMP_SERVERS_ROUTE_NAME)
}

function confirmLeaveServer() {
  showLeaveConfirm.value = false
  api.engineLua("MPCoreNetwork.leaveServer(true)")
}

function confirmQuitGame() {
  showQuitConfirm.value = false
  api.engineLua("quit()")
}
</script>

<style scoped>
.card {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding: 0.5rem;
  color: var(--bng-off-white);
}

.card-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  padding: 0 0.15rem 0.85rem;
  border-bottom: 1px solid rgba(var(--bng-cool-gray-300-rgb), 0.24);
}

h3,
.subtitle {
  margin: 0;
}

h3 {
  font-size: 1.15rem;
}

.subtitle {
  margin-top: 0.2rem;
  color: var(--bng-cool-gray-300);
  font-size: 0.82rem;
}

.identity {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  min-width: 0;
  max-width: 48%;
  padding: 0.3rem 0.55rem;
  border-radius: var(--bng-corners-2);
  background: rgba(var(--bng-cool-gray-900-rgb), 0.72);
  color: var(--bng-cool-gray-100);
  font-size: 0.8rem;
}

.identity span:last-child {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.online-dot {
  width: 0.5rem;
  height: 0.5rem;
  flex: 0 0 auto;
  border-radius: 50%;
  background: var(--bng-add-green-400);
  box-shadow: 0 0 0.4rem rgba(var(--bng-add-green-400-rgb), 0.55);
}

.actions {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.5rem;
}

.action {
  --bng-icon-size: 1.5rem;
  --bng-bg-border-radius: var(--bng-corners-1);
  --bng-bg-border-width: 0.0625rem;
  --bng-bg-enabled: var(--bng-cool-gray-650);
  --bng-bg-hover: var(--bng-cool-gray-600);
  --bng-bg-active: var(--bng-cool-gray-600);
  --bng-bg-border-enabled: var(--bng-cool-gray-300);
  --bng-bg-border-hover: var(--bng-cool-gray-300);
  --bng-bg-border-active: var(--bng-cool-gray-300);
  --bng-bg-enabled-opacity: 0.6;
  --bng-bg-hover-opacity: 0.85;
  --bng-bg-active-opacity: 0.9;
  --bng-content-flow: row;
  --bng-content-align: center;
  --bng-content-justify: flex-start;
  --bng-button-padding: 0.65rem;
  --bng-button-margin: 0;
  --bng-button-min-width: 0;
  --bng-button-max-width: none;

  width: 100%;
  min-height: 3.25rem;
  gap: 0.55rem;
  font-size: 1rem;
}

.action--primary {
  --bng-bg-enabled: var(--bng-orange-500);
  --bng-bg-hover: var(--bng-orange-600);
  --bng-bg-active: var(--bng-orange-700);
  --bng-bg-border-enabled: var(--bng-orange-300);
  --bng-bg-border-hover: var(--bng-orange-200);
  --bng-bg-border-active: var(--bng-orange-300);
  --bng-bg-enabled-opacity: 1;
}

.action--wide {
  grid-column: 1 / -1;
}

.action--danger {
  --bng-bg-enabled: var(--bng-add-red-600);
  --bng-bg-hover: var(--bng-add-red-600);
  --bng-bg-active: var(--bng-add-red-600);
  --bng-bg-border-enabled: var(--bng-add-red-400);
  --bng-bg-border-hover: var(--bng-add-red-400);
  --bng-bg-border-active: var(--bng-add-red-400);
}
</style>
