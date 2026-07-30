<template>
  <div class="mods-card">
    <header class="card-header">
      <div>
        <h3>Server Mods</h3>
        <p>Content supplied by the current server</p>
      </div>
      <span class="count">{{ serverMods.length }}</span>
    </header>

    <div class="mod-list">
      <div v-if="!serverMods.length" class="empty">
        This server has no additional mods.
      </div>
      <div v-for="modName in serverMods" :key="modName" class="mod-row">
        <BngIcon :type="icons.puzzleModule" />
        <span>{{ modName }}</span>
      </div>
    </div>

    <BngButton class="browser-button" :icon="icons.globe" @click="openRoute">
      Open Server List
    </BngButton>
  </div>
</template>

<script setup>
import { onMounted, onUnmounted, ref } from "vue"
import { lua, useBridge } from "@/bridge"
import { BngButton, BngIcon, icons } from "@/common/components/base"
import { BEAMMP_SERVERS_ROUTE_NAME } from "../shared/constants.js"
import { useBeamMPState } from "../shared/beammpState.js"

const { events } = useBridge()
const { extensionCall } = useBeamMPState()
const serverMods = ref([])

function normalizeMods(value) {
  if (Array.isArray(value)) return value.filter(Boolean).map(String)
  if (value && typeof value === "object") {
    return Object.keys(value)
      .sort((a, b) => Number(a) - Number(b))
      .map(key => value[key])
      .filter(Boolean)
      .map(String)
  }
  return []
}

function updateServerMods(value) {
  serverMods.value = normalizeMods(value)
}

async function requestServerMods() {
  updateServerMods(await extensionCall("MPModManager", "getServerMods"))
}

function openRoute() {
  lua.extensions.ui_router.push(BEAMMP_SERVERS_ROUTE_NAME)
}

onMounted(() => {
  events.on("onBeamMPServerModsChanged", updateServerMods)
  requestServerMods()
})

onUnmounted(() => {
  events.off("onBeamMPServerModsChanged", updateServerMods)
})
</script>

<style scoped lang="scss">
.mods-card {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  height: 100%;
  padding: 0.5rem;
  color: var(--bng-off-white);
}

.card-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  padding: 0 0.15rem 0.75rem;
  border-bottom: 1px solid rgba(var(--bng-cool-gray-300-rgb), 0.24);
}

h3,
.card-header p {
  margin: 0;
}

h3 {
  font-size: 1.15rem;
}

.card-header p {
  margin-top: 0.2rem;
  color: var(--bng-cool-gray-300);
  font-size: 0.82rem;
}

.count {
  display: grid;
  place-items: center;
  min-width: 1.8rem;
  height: 1.8rem;
  padding: 0 0.25rem;
  border-radius: var(--bng-corners-2);
  background: var(--bng-orange-500);
  font-weight: 700;
}

.mod-list {
  display: flex;
  flex: 1 1 auto;
  min-height: 0;
  flex-direction: column;
  gap: 0.35rem;
  overflow-y: auto;
}

.mod-row {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  min-height: 2.6rem;
  padding: 0.35rem 0.6rem;
  border-radius: var(--bng-corners-2);
  background: rgba(var(--bng-cool-gray-900-rgb), 0.78);
}

.mod-row :deep(.bng-icon) {
  color: var(--bng-orange-300);
}

.mod-row span {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.empty {
  padding: 0.8rem 0.25rem;
  color: var(--bng-cool-gray-300);
}

.browser-button {
  --bng-button-margin: 0;
  width: 100%;
}
</style>
