<template>
	<div
		class="beammp-player-list-app"
		:class="{ 'ui-style-redesigned': useUiAppRedesign }"
		@click="closeContextMenu"
	>
		<div class="main-container" :style="mainContainerStyle">
			<div v-show="isShown" class="plist-container" :style="panelAnchorStyle">
				<table class="players-table">
					<tr>
						<th v-show="showPlayerIDs" class="playerslist-col-1">ID</th>
						<th class="playerslist-col-2">
							<span>{{ $tt("ui.apps.beammp.playerlist.players") }}</span>
							<span class="player-count-badge">{{ players.length }}</span>
						</th>
						<th class="playerslist-col-3">
							<button
								class="buttons direction-buttons"
								type="button"
								:title="$tt('ui.apps.beammp.playerlist.moveHorizontal') || 'Move player list horizontally'"
								@click.stop="swapHorizontal"
							>
								↔
							</button>
							<button
								class="buttons direction-buttons"
								type="button"
								:title="$tt('ui.apps.beammp.playerlist.moveVertical') || 'Move player list vertically'"
								@click.stop="swapVertical"
							>
								↕
							</button>
						</th>
					</tr>
					<tr v-if="!players.length">
						<td :colspan="showPlayerIDs ? 3 : 2">{{ $tt("ui.apps.beammp.playerlist.error") }}</td>
					</tr>
					<tr
						v-for="player in players"
						:key="`player-${player.id}`"
						:class="{ queued: queuedPlayers[player.id] }"
						@contextmenu.prevent.stop="openContextMenu($event, player)"
					>
						<td
							v-show="showPlayerIDs"
							class="player-id"
							@click.stop="restorePlayerVehicle(player.name)"
						>
							{{ player.id }}
						</td>
						<td class="player-button" @click.stop="handlePrimaryAction(player)">
							{{ player.formatted_name || player.name }}
						</td>
						<td class="ping-cell">
							<button class="buttons tp-button" type="button" @click.stop>
								{{ formatPing(player.ping) }} ms
							</button>
						</td>
					</tr>
				</table>
			</div>

			<button
				class="buttons show-button"
				type="button"
				:style="panelAnchorStyle"
				:title="$tt('ui.apps.beammp.playerlist.toggle') || 'Show or hide player list'"
				@click.stop="toggleShown"
			>
				{{ showButtonLabel }}
			</button>
		</div>

		<div
			v-show="contextMenu.visible"
			class="playerlist-contextmenu"
			:style="contextMenuStyle"
			@mouseleave="closeContextMenu"
			@click.stop
		>
			<button type="button" @click="copyName(contextMenu.player?.name)">
				{{ $tt("ui.apps.beammp.playerlist.copyname") }}
			</button>
			<button type="button" @click="deleteAllVehicles(contextMenu.player?.name)">
				{{ $tt("ui.apps.beammp.playerlist.deleteAllVehicles") }}
			</button>
			<button type="button" @click="applyQueuesForPlayer(contextMenu.player?.id)">
				{{ $tt("ui.apps.beammp.playerlist.queueEvents") }}
			</button>
			<button type="button" @click="showPlayerInfo(contextMenu.player?.name)">
				{{ $tt("ui.apps.beammp.playerlist.switchCameraTo") }}
			</button>
			<button type="button" @click="openProfile(contextMenu.player?.name)">
				{{ $tt("ui.apps.beammp.playerlist.openProfile") }}
			</button>
			<button type="button" @click="restorePlayerVehicle(contextMenu.player?.name)">
				{{ $tt("ui.apps.beammp.playerlist.restoreVehicles") }}
			</button>
			<button
				v-for="label in customButtons"
				:key="label"
				type="button"
				@click="runCustomButton(label, contextMenu.player)"
			>
				{{ label }}
			</button>
		</div>
	</div>
</template>

<script setup>
import { computed, onMounted, onUnmounted, reactive, ref } from "vue"
import { useBridge } from "@/bridge"

const { api, events } = useBridge()

const players = ref([])
const customButtons = ref([])
const queuedPlayers = ref({})
const showPlayerIDs = ref(true)
const playerlistLeftclick = ref(0)
const useUiAppRedesign = ref(false)
const pingByName = ref({})
const isShown = ref(localStorage.getItem("plShown") === "1")
const horizontal = ref(localStorage.getItem("plHorizontal") || "right")
const vertical = ref(localStorage.getItem("plVertical") || "top")
const contextMenu = reactive({
	visible: false,
	x: 0,
	y: 0,
	player: null,
})

const mainContainerStyle = computed(() => ({
	flexDirection: horizontal.value === "left" ? "row-reverse" : "row",
}))

const panelAnchorStyle = computed(() => ({
	marginTop: vertical.value === "bottom" ? "auto" : "0",
}))

const contextMenuStyle = computed(() => ({
	left: `${contextMenu.x}px`,
	top: `${contextMenu.y}px`,
}))

const showButtonLabel = computed(() => {
	if (isShown.value) return horizontal.value === "right" ? "<" : ">"
	return horizontal.value === "right" ? ">" : "<"
})

function safeJsonParse(payload, fallback) {
	try {
		return JSON.parse(payload)
	} catch {
		return fallback
	}
}

function syncStoredDirections() {
	localStorage.setItem("plHorizontal", horizontal.value)
	localStorage.setItem("plVertical", vertical.value)
	localStorage.setItem("plShown", isShown.value ? "1" : "0")
}

function normalizePingMap(payload) {
	const parsed = typeof payload === "string" ? safeJsonParse(payload, {}) : payload
	const result = {}
	if (!parsed || typeof parsed !== "object") return result
	for (const [name, rawPing] of Object.entries(parsed)) {
		const adjusted = Math.min(999, Math.max(0, Number(rawPing) - 16))
		result[name] = Number.isFinite(adjusted) ? adjusted : "?"
	}
	return result
}

function sortPlayers(list) {
	return [...list].sort((left, right) => Number(left?.id || 0) - Number(right?.id || 0))
}

function hydratePlayers(list) {
	players.value = sortPlayers(list).map((player) => ({
		...player,
		ping: pingByName.value[player.name] ?? player.ping ?? "?",
	}))
}

function requestSetting(settingName, setter, fallback) {
	api.engineLua(`settings.getValue(${api.serializeToLua(settingName)})`, (value) => {
		setter(value ?? fallback)
	})
}

function toggleShown() {
	isShown.value = !isShown.value
	syncStoredDirections()
}

function swapHorizontal() {
	horizontal.value = horizontal.value === "left" ? "right" : "left"
	syncStoredDirections()
}

function swapVertical() {
	vertical.value = vertical.value === "bottom" ? "top" : "bottom"
	syncStoredDirections()
}

function closeContextMenu() {
	contextMenu.visible = false
	contextMenu.player = null
}

function openContextMenu(event, player) {
	contextMenu.visible = true
	contextMenu.x = event.clientX
	contextMenu.y = event.clientY
	contextMenu.player = player
}

function formatPing(ping) {
	return ping === undefined || ping === null ? "?" : ping
}

function copyName(name) {
	if (!name) return closeContextMenu()
	api.engineLua(`setClipboard(${api.serializeToLua(String(name))})`)
	closeContextMenu()
}

function deleteAllVehicles(name) {
	if (!name) return closeContextMenu()
	const ownerName = api.serializeToLua(String(name))
	api.engineLua(`
		for id, veh in pairs(MPVehicleGE.getVehicles()) do
			if veh.ownerName == ${ownerName} then
				local vehicle = be:getObjectByID(veh.gameVehicleID)
				if vehicle then vehicle:delete() end
			end
		end
	`)
	closeContextMenu()
}

function applyQueuesForPlayer(id) {
	if (id === undefined || id === null) return closeContextMenu()
	api.engineLua(`MPVehicleGE.applyPlayerQueues(${Number(id)})`)
	closeContextMenu()
}

function showPlayerInfo(name) {
	if (!name) return closeContextMenu()
	api.engineLua(`MPVehicleGE.focusCameraOnPlayer(${api.serializeToLua(String(name))})`)
	closeContextMenu()
}

function openProfile(name) {
	if (!name) return closeContextMenu()
	globalThis.openExternalLink?.(`https://forum.beammp.com/u/${name}/summary`)
	closeContextMenu()
}

function restorePlayerVehicle(name) {
	if (!name) return closeContextMenu()
	api.engineLua(`MPVehicleGE.restorePlayerVehicle(${api.serializeToLua(String(name))})`)
	closeContextMenu()
}

function runCustomButton(label, player) {
	if (!label || !player) return closeContextMenu()
	api.engineLua(`
		UI.getCustomPlayerlistButtons()[${api.serializeToLua(String(label))}](
			${api.serializeToLua(String(player.name || ""))},
			${Number(player.id) || 0}
		)
	`)
	closeContextMenu()
}

function handlePrimaryAction(player) {
	switch (Number(playerlistLeftclick.value)) {
		case 0:
			applyQueuesForPlayer(player.id)
			break
		case 1:
			showPlayerInfo(player.name)
			break
		case 2:
			openProfile(player.name)
			break
		case 3:
			deleteAllVehicles(player.name)
			break
		case 4:
			restorePlayerVehicle(player.name)
			break
		case 5:
			copyName(player.name)
			break
		default:
			applyQueuesForPlayer(player.id)
			break
	}
}

function onPlayerList(payload) {
	const parsed = typeof payload === "string" ? safeJsonParse(payload, []) : payload
	hydratePlayers(Array.isArray(parsed) ? parsed : [])
}

function onPlayerPings(payload) {
	pingByName.value = normalizePingMap(payload)
	hydratePlayers(players.value)
}

function onQueueUpdate(payload) {
	const nextQueuedPlayers = payload?.queuedPlayers && typeof payload.queuedPlayers === "object"
		? payload.queuedPlayers
		: {}
	queuedPlayers.value = { ...nextQueuedPlayers }
}

function onCustomButtons(payload) {
	customButtons.value = Array.isArray(payload) ? payload : []
}

function onSettingsChanged(payload) {
	const values = payload?.values || {}
	if (Object.prototype.hasOwnProperty.call(values, "showPlayerIDs")) {
		showPlayerIDs.value = Boolean(values.showPlayerIDs)
	}
	if (Object.prototype.hasOwnProperty.call(values, "playerlistLeftclick")) {
		playerlistLeftclick.value = Number(values.playerlistLeftclick) || 0
	}
	if (Object.prototype.hasOwnProperty.call(values, "useUiAppRedesign")) {
		useUiAppRedesign.value = Boolean(values.useUiAppRedesign)
	}
}

function onEscape(event) {
	if (event.key === "Escape") closeContextMenu()
}

onMounted(() => {
	syncStoredDirections()
	requestSetting("showPlayerIDs", (value) => {
		showPlayerIDs.value = Boolean(value)
	}, true)
	requestSetting("playerlistLeftclick", (value) => {
		playerlistLeftclick.value = Number(value) || 0
	}, 0)
	requestSetting("useUiAppRedesign", (value) => {
		useUiAppRedesign.value = Boolean(value)
	}, false)

	events.on("SettingsChanged", onSettingsChanged)
	events.on("onBeamMPPlayerList", onPlayerList)
	events.on("onBeamMPPlayerPings", onPlayerPings)
	events.on("onBeamMPSetQueue", onQueueUpdate)
	events.on("onBeamMPUpdateCustomButtons", onCustomButtons)

	window.addEventListener("keydown", onEscape)
	window.addEventListener("click", closeContextMenu)

	api.engineLua("guihooks.trigger('onBeamMPUpdateCustomButtons', UI.getCustomButtonNames())")
	api.engineLua("UI.updatePlayersList(); UI.sendQueue()")
})

onUnmounted(() => {
	events.off("SettingsChanged", onSettingsChanged)
	events.off("onBeamMPPlayerList", onPlayerList)
	events.off("onBeamMPPlayerPings", onPlayerPings)
	events.off("onBeamMPSetQueue", onQueueUpdate)
	events.off("onBeamMPUpdateCustomButtons", onCustomButtons)

	window.removeEventListener("keydown", onEscape)
	window.removeEventListener("click", closeContextMenu)
})
</script>

<style scoped lang="scss">
.beammp-player-list-app {
	position: relative;
	width: 100%;
	height: 100%;
	color: var(--bng-off-white);
}

.main-container {
	display: flex;
	justify-content: flex-end;
	align-content: flex-end;
	width: 100%;
	height: 100%;
	font-family: var(--bmp-fnt-defs);
	font-size: 1rem;
	font-weight: 600;
}

.plist-container {
	width: 100%;
	margin: 0;
	padding: 0;
	overflow-y: auto;
	border: 0.0625rem solid rgba(var(--bng-cool-gray-300-rgb), 0.34);
	border-top: 0.1875rem solid var(--bng-orange-500);
	border-radius: var(--bng-corners-2, 0.375rem);
	background: rgba(var(--bng-cool-gray-900-rgb), 0.88);
	box-shadow: 0 0.1875rem 0.75rem rgba(var(--bng-off-black-rgb), 0.28);
	backdrop-filter: blur(0.75rem);
}

.ui-style-redesigned .plist-container,
.ui-style-redesigned .show-button {
	border-color: rgba(var(--bng-cool-gray-100-rgb), 0.24);
	background: rgba(var(--bng-cool-gray-900-rgb), 0.34);
	box-shadow:
		0 0.1875rem 0.75rem rgba(var(--bng-off-black-rgb), 0.2),
		inset 0 0 0 0.0625rem rgba(var(--bng-off-white-rgb), 0.04);
	backdrop-filter: blur(0.625rem) saturate(115%);
}

.players-table {
	width: 100%;
	padding: 0;
	border: 0;
	border-collapse: collapse;
	background: transparent;
	color: var(--bng-off-white);
	table-layout: fixed;
}

.players-table tr:first-child {
	min-height: 2.125rem;
	background: rgba(var(--bng-cool-gray-700-rgb), 0.58);
}

.ui-style-redesigned .players-table tr:first-child {
	background: rgba(var(--bng-cool-gray-700-rgb), 0.26);
}

.players-table th {
	min-height: 2.125rem;
	padding: 0.4375rem;
	border: 0;
	border-bottom: 0.0625rem solid rgba(var(--bng-cool-gray-300-rgb), 0.24);
	color: var(--bng-cool-gray-100);
	text-align: left;
	text-transform: uppercase;
	line-height: 1.25rem;
	box-sizing: border-box;
}

.players-table td {
	min-height: 2.125rem;
	max-width: 0;
	padding: 0.4375rem;
	overflow: hidden;
	border: 0;
	border-bottom: 0.0625rem solid rgba(var(--bng-cool-gray-300-rgb), 0.14);
	color: var(--bng-off-white);
	text-overflow: ellipsis;
	text-shadow: none;
	white-space: nowrap;
	line-height: 1.25rem;
	box-sizing: border-box;
}

.ui-style-redesigned .players-table th,
.ui-style-redesigned .players-table td,
.ui-style-redesigned .show-button {
	text-shadow: 0 0.0625rem 0.125rem rgba(var(--bng-off-black-rgb), 0.95);
}

.players-table tr:not(:first-child) {
	background: transparent;
	transition: background-color 120ms ease;
}

.players-table tr:not(:first-child):hover {
	background: rgba(var(--bng-orange-500-rgb), 0.16);
}

.players-table tr.queued {
	background: rgba(var(--bng-orange-500-rgb), 0.18);
}

.player-id {
	color: var(--bng-cool-gray-400);
	font-size: 0.75rem;
	cursor: pointer;
}

.player-button {
	cursor: pointer;
	font-weight: 700;
}

.ping-cell {
	color: var(--bng-cool-gray-300);
	font-variant-numeric: tabular-nums;
}

.playerslist-col-1 { width: 2rem; }
.playerslist-col-2 { width: auto; min-width: 6.25rem; }
.playerslist-col-3 {
	width: 4rem;
	padding: 0 !important;
	text-align: right !important;
}

.player-count-badge {
	display: inline-grid;
	min-width: 1.0625rem;
	height: 1.0625rem;
	margin-left: 0.3125rem;
	padding: 0 0.1875rem;
	place-items: center;
	border-radius: 0.5625rem;
	background: var(--bng-orange-500);
	color: var(--bng-off-white);
	font-size: 0.75rem;
	box-sizing: border-box;
}

.buttons {
	border: 0;
	background: transparent;
	color: var(--bng-cool-gray-200);
	cursor: pointer;
	transition: background-color 120ms ease, color 120ms ease;
}

.buttons:hover {
	background: rgba(var(--bng-orange-500-rgb), 0.2);
	color: var(--bng-off-white);
}

.direction-buttons {
	width: 1.875rem;
	min-height: 2.125rem;
	padding: 0;
	font-size: 0.9375rem;
	line-height: 2.125rem;
	box-sizing: border-box;
}

.tp-button {
	width: 100%;
	min-height: 2.125rem;
	padding: 0 0.3125rem;
	color: var(--bng-cool-gray-300);
	font-variant-numeric: tabular-nums;
	line-height: 2.125rem;
	box-sizing: border-box;
}

.show-button {
	width: 1.75rem;
	min-height: 4.6875rem;
	margin: 0 0 0 0.25rem;
	padding: 0;
	align-self: flex-start;
	border: 0.0625rem solid rgba(var(--bng-cool-gray-300-rgb), 0.34);
	border-left: 0.1875rem solid var(--bng-orange-500);
	border-radius: var(--bng-corners-2, 0.375rem);
	background: rgba(var(--bng-cool-gray-900-rgb), 0.88);
	box-shadow: 0 0.1875rem 0.75rem rgba(var(--bng-off-black-rgb), 0.28);
	backdrop-filter: blur(0.75rem);
	font-size: 1.0625rem;
	font-weight: 700;
	box-sizing: border-box;
}

.playerlist-contextmenu {
	position: fixed;
	z-index: 1000;
	max-width: 13.125rem;
	padding: 0.375rem;
	border: 0.0625rem solid rgba(var(--bng-cool-gray-300-rgb), 0.34);
	border-radius: var(--bng-corners-2, 0.375rem);
	background: rgba(var(--bng-cool-gray-900-rgb), 0.96);
	box-shadow: 0 0.3125rem 1.125rem rgba(var(--bng-off-black-rgb), 0.4);
	box-sizing: border-box;
}

.playerlist-contextmenu > button {
	width: 100%;
	min-height: 1.875rem;
	margin: 0 0 0.1875rem;
	padding: 0.4375rem 0.5625rem;
	border: 0;
	border-radius: var(--bng-corners-1, 0.1875rem);
	background: rgba(var(--bng-cool-gray-700-rgb), 0.72);
	color: var(--bng-off-white);
	text-align: left;
	cursor: pointer;
	line-height: 1.25;
	white-space: normal;
	box-sizing: border-box;
}

.playerlist-contextmenu > button:hover {
	background: rgba(var(--bng-orange-500-rgb), 0.32);
}

.plist-container::-webkit-scrollbar {
	width: 0.25rem;
}

.plist-container::-webkit-scrollbar-thumb {
	border-radius: 0.125rem;
	background: rgba(var(--bng-cool-gray-300-rgb), 0.5);
}
</style>
