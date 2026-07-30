<template>
  <div class="card">
    <BngCardHeading type="ribbon" outline class="beammp-player-list-heading">
		{{ $tt("ui.common.beammp.playerList") }} ({{ players.length }} {{ players.length === 1 ? "player" : "players" }} connected)
    </BngCardHeading>

    <div class="card-content">
      <div v-if="!players.length" class="empty">{{ $tt("ui.beammp.server.noPlayers") }}</div>
      <div v-for="player in players" :key="`${player.id}:${player.name}`" class="player-row">
      <div class="avatar"><BngIcon :type="icons.personSolid" /></div>
      <div class="player">
        <span class="name">{{ player.name }}</span>
        <span v-if="settings.values.showPlayerIDs" class="id">ID {{ player.id }}</span>
      </div>
      <span class="ping"><span class="ping-dot"></span>{{ player.ping || "?" }}ms</span>
      <BngButton
        class="player-action"
        :accent="ACCENTS.menu"
        :icon="icons.copy"
        :aria-label="$tt('ui.apps.beammp.playerlist.copyname')"
        :title="$tt('ui.apps.beammp.playerlist.copyname')"
        @click="copyName(player.name)"
      />
      <BngButton
        class="player-action"
        :accent="ACCENTS.menu"
        :icon="icons.external"
        :aria-label="$tt('ui.apps.beammp.playerlist.openProfile')"
        :title="$tt('ui.apps.beammp.playerlist.openProfile')"
        @click="openProfile(player.name)"
      />
      </div>
    </div>
  </div>
</template>

<script setup>
import { onMounted, onUnmounted, ref } from "vue"
import { useBridge } from "@/bridge"
import { ACCENTS, BngButton, BngIcon, icons } from "@/common/components/base"
import { BngBinding, BngCardHeading } from "@/common/components/base"
import { useBeamMPState } from "../shared/beammpState.js"
import { useSettings } from "@/services/settings"

const settings = useSettings()

const { api, events } = useBridge()
const { extensionCommand } = useBeamMPState()
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
  extensionCommand("MPCoreNetwork", "openURL", api.serializeToLua(url))
}

onMounted(() => {
  events.on("onBeamMPPlayerList", onPlayerList)
  events.on("onBeamMPPlayerPings", onPlayerPings)
  extensionCommand("UI", "updatePlayersList")
})

onUnmounted(() => {
  events.off("onBeamMPPlayerList", onPlayerList)
  events.off("onBeamMPPlayerPings", onPlayerPings)
})
</script>

<style scoped lang="scss">
.card {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  color: var(--bng-off-white);
}

.beammp-player-list-heading {
  --bng-card-heading-ribbon-color: var(--bng-cool-gray-700);
  margin: 0;
  margin-left: 0;
  margin-top: 0.5rem;
  font-size: 1.25em;
  line-height: 1.625em;
}

.card-content {
	display: flex;
	flex-direction: column;
	padding: 0 0.5rem 0.5rem 0.5rem;
	gap: 0.5rem;
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
  font-weight: 500;
}

.player-row {
  display: grid;
  grid-template-columns: 2.25rem minmax(0, 1fr) auto 2.5rem 2.5rem;
  gap: 0.5rem;
  align-items: center;
  min-height: 3.5rem;
  padding: 0.35rem 0.5rem;
  border-radius: var(--bng-corners-1);
  border-width: 0.0625em;
  border-style: solid;
  background-color: var(--bng-cool-gray-750);
  border-color: var(--bng-cool-gray-500);
  &:hover {
	background-color: ar(--bng-cool-gray-700);
  };
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
  font-weight: 500;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.ping {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  color: var(--bng-cool-gray-300);
  font-family: 'Noto Sans Mono';
  font-size: 0.78rem;
  font-weight: 500;
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
