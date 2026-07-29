<template>
  <div class="card">
    <header class="card-header">
      <div>
        <h3>{{ $tt("ui.multiplayer.server.playerList") }}</h3>
        <p>{{ players.length }} {{ players.length === 1 ? "player" : "players" }} connected</p>
      </div>
      <span class="count">{{ players.length }}</span>
    </header>

    <div v-if="!players.length" class="empty">{{ $tt("ui.multiplayer.server.noPlayers") }}</div>
    <div v-for="player in players" :key="`${player.id}:${player.name}`" class="player-row">
      <div class="avatar"><BngIcon :type="icons.personSolid" /></div>
      <div class="player">
        <span class="name">{{ player.name }}</span>
        <span class="id">ID {{ player.id }}</span>
      </div>
      <span class="ping"><span class="ping-dot"></span>{{ player.ping || "?" }}ms</span>
      <BngButton
        class="player-action"
        :accent="ACCENTS.menu"
        :icon="icons.copy"
        :aria-label="$tt('ui.apps.multiplayer.playerlist.copyname')"
        :title="$tt('ui.apps.multiplayer.playerlist.copyname')"
        @click="copyName(player.name)"
      />
      <BngButton
        class="player-action"
        :accent="ACCENTS.menu"
        :icon="icons.external"
        :aria-label="$tt('ui.apps.multiplayer.playerlist.openProfile')"
        :title="$tt('ui.apps.multiplayer.playerlist.openProfile')"
        @click="openProfile(player.name)"
      />
    </div>
  </div>
</template>

<script setup>
import { onMounted, onUnmounted, ref } from "vue"
import { useBridge } from "@/bridge"
import { ACCENTS, BngButton, BngIcon, icons } from "@/common/components/base"

const { api, events } = useBridge()
const players = ref([])

function onPlayerList(payload) {
  try {
    const parsed = JSON.parse(payload)
    if (Array.isArray(parsed)) players.value = parsed
  } catch {
    players.value = []
  }
}

function onPlayerPings(payload) {
  try {
    const pings = JSON.parse(payload)
    players.value = players.value.map(player => ({
      ...player,
      ping: pings[player.name] ?? player.ping,
    }))
  } catch {
    // ignore malformed data
  }
}

function copyName(name) {
  api.engineLua(`setClipboard(${api.serializeToLua(String(name || ""))})`)
}

function openProfile(name) {
  const url = `https://forum.beammp.com/u/${name}/summary`
  api.engineLua(`MPCoreNetwork.openURL(${api.serializeToLua(url)})`)
}

onMounted(() => {
  events.on("BeamMP_PlayerList", onPlayerList)
  events.on("BeamMP_PlayerPings", onPlayerPings)
  api.engineLua("UI.updatePlayersList()")
})

onUnmounted(() => {
  events.off("BeamMP_PlayerList", onPlayerList)
  events.off("BeamMP_PlayerPings", onPlayerPings)
})
</script>

<style scoped lang="scss">
.card {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
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
  color: var(--bng-off-white);
  font-weight: 700;
}

.player-row {
  display: grid;
  grid-template-columns: 2.25rem minmax(0, 1fr) auto 2.5rem 2.5rem;
  gap: 0.5rem;
  align-items: center;
  min-height: 3.5rem;
  padding: 0.35rem 0.5rem;
  border-radius: var(--bng-corners-2);
  background:
    linear-gradient(90deg,
      rgba(var(--bng-cool-gray-900-rgb), 0.96) 0%,
      rgba(var(--bng-cool-gray-900-rgb), 0.86) 68%,
      rgba(var(--bng-cool-gray-900-rgb), 0.45) 100%);
}

.avatar {
  display: grid;
  place-items: center;
  width: 2.25rem;
  height: 2.25rem;
  border-radius: 50%;
  background: rgba(var(--bng-orange-500-rgb), 0.18);
  color: var(--bng-orange-300);
}

.player {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.id {
  color: var(--bng-cool-gray-400);
  font-size: 0.72rem;
}

.name {
  overflow: hidden;
  color: var(--bng-off-white);
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.ping {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  color: var(--bng-cool-gray-300);
  font-size: 0.78rem;
  font-weight: 600;
}

.ping-dot {
  width: 0.4rem;
  height: 0.4rem;
  border-radius: 50%;
  background: var(--bng-add-green-400);
}

.player-action {
  --bng-button-min-width: 2.5rem;
  --bng-button-max-width: 2.5rem;
  --bng-button-padding: 0.45rem;
  --bng-button-margin: 0;
  --bng-bg-border-radius: var(--bng-corners-1);
}

.empty {
  padding: 1rem 0.25rem;
  color: var(--bng-cool-gray-300);
}
</style>
