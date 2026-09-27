-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- MPVehiclePoolGE API.
--- Opt-in distance culling of remote vehicles, built on the game's core_vehicleActivePooling.
--- Remote vehicles further than `remoteVehicleCullDistance` from the camera are deactivated (no physics,
--- no rendering, dormant VE lua). Sync packets for them are held here and replayed when they wake,
--- so a woken vehicle ends up in the same state as if it had never been culled.
--- @module MPVehiclePoolGE
--- @usage MPVehiclePoolGE.intercept(serverVehicleID, "e", data) -- from packet handlers
--- @usage MPVehiclePoolGE.wake(serverVehicleID) -- force a vehicle awake before touching it

local M = {}

local POOL_NAME = "beammpRemoteVehicles"
local UPDATE_INTERVAL = 0.25 -- seconds between distance evaluations
local WAKE_BUFFER = 50 -- metres of hysteresis between waking and culling, prevents flickering at the edge
local HOLD_AWAKE_TIME = 5 -- seconds a vehicle stays awake after being woken by an event (edit, reset, etc)
local MAX_QUEUED_EVENTS = 64 -- per vehicle cap for ordered event streams

-- How held packets are combined while a vehicle is culled
--   merge   = deep merge of json objects (delta streams: inputs, electrics, powertrain)
--   union   = append json arrays (break groups)
--   latest  = keep only the last packet (full snapshots: nodes)
--   ordered = keep every packet in order, capped (controller events)
--   vehicle = vehicle packets (reset/coupler/paint), replayed first through MPVehicleGE.handle, resets collapsed
local streamPolicy = {
	i  = "merge",   -- MPInputsGE
	e  = "merge",   -- MPElectricsGE
	pl = "merge",   -- MPPowertrainGE live powertrain
	pe = "merge",   -- MPPowertrainGE engine data
	ph = "merge",   -- MPPowertrainGE hydros
	n  = "latest",  -- nodesGE nodes
	g  = "union",   -- nodesGE break groups
	c  = "ordered", -- MPControllerGE
	O  = "vehicle", -- MPVehicleGE resets, couplers, paint: replayed first, in order, repeated resets collapsed
}

-- replay order on wake, structural state first and inputs last
local flushOrder = { "n", "g", "e", "pl", "pe", "ph", "i" }

local enabled = false
local cullDistance = 500
local pool
local updateTimer = 0
local clock = 0

--[[
	culled["X-Y"] = table
		[gameVehicleID] = number
		[pos] = string, last raw position packet
		[posDirty] = bool
		[streams] = table, held packets per stream key
		[events] = array of { key, data }
		[vehicleEvents] = array of raw vehicle packets ("r:X-Y:{...}")
]]
local culled = {}
local culledByGameID = {} -- [gameVehicleID] = serverVehicleID
local holdAwakeUntil = {} -- [serverVehicleID] = clock time

local camPos = vec3()
local vehPos = vec3()


local function getPool()
	-- the pool can be deleted from under us (onClientEndMission, other mods calling deleteAllPools)
	if pool and core_vehicleActivePooling.getPoolById(pool.id) == pool then return pool end
	pool = core_vehicleActivePooling.getPool(POOL_NAME) or core_vehicleActivePooling.createPool({name = POOL_NAME})
	return pool
end

local function deepMerge(target, source)
	for k, v in pairs(source) do
		if type(v) == "table" and type(target[k]) == "table" then
			deepMerge(target[k], v)
		else
			target[k] = v
		end
	end
	return target
end

local function getApplyFunction(key)
	if key == "i" then return MPInputsGE.applyInputs
	elseif key == "e" then return MPElectricsGE.applyElectrics
	elseif key == "pl" then return MPPowertrainGE.applyLivePowertrain
	elseif key == "pe" then return MPPowertrainGE.applyEngineData
	elseif key == "ph" then return MPPowertrainGE.applyHydroBeams
	elseif key == "n" then return nodesGE.applyNodes
	elseif key == "g" then return nodesGE.applyBreakGroups
	elseif key == "c" then return MPControllerGE.applyControllerData
	elseif key == "O" then return function(data) MPVehicleGE.handle(data) end
	end
end


--- Returns true if the vehicle is currently culled by this module.
-- @param serverVehicleID string X-Y
local function isCulled(serverVehicleID)
	return culled[serverVehicleID] ~= nil
end

--- Called by packet handlers before sending data to VE. Returns true if the vehicle is culled,
--- in which case the packet has been held and must not be sent to VE.
-- @param serverVehicleID string X-Y
-- @param key string stream key, see streamPolicy
-- @param data string raw json
local function intercept(serverVehicleID, key, data)
	local state = culled[serverVehicleID]
	if not state then return false end

	local policy = streamPolicy[key] or "latest"
	if policy == "latest" then
		state.streams[key] = data
	elseif policy == "vehicle" then
		local last = state.vehicleEvents[#state.vehicleEvents]
		if last and last:sub(1, 1) == "r" and data:sub(1, 1) == "r" then
			state.vehicleEvents[#state.vehicleEvents] = data -- a newer reset supersedes the previous one
		else
			if #state.vehicleEvents >= MAX_QUEUED_EVENTS then table.remove(state.vehicleEvents, 1) end
			table.insert(state.vehicleEvents, data)
		end
	elseif policy == "ordered" then
		if #state.events >= MAX_QUEUED_EVENTS then table.remove(state.events, 1) end
		table.insert(state.events, { key, data })
	else
		local decoded = jsonDecode(data)
		if type(decoded) ~= "table" then return true end
		local held = state.streams[key]
		if not held then
			state.streams[key] = decoded
		elseif policy == "merge" then
			deepMerge(held, decoded)
		else -- union
			for _, v in ipairs(decoded) do table.insert(held, v) end
		end
	end
	return true
end

--- Called by positionGE. Returns true if the vehicle is culled, the packet is then held instead of
--- being sent to the VE mailbox.
-- @param serverVehicleID string X-Y
-- @param data string raw position json
local function interceptPosition(serverVehicleID, data)
	local state = culled[serverVehicleID]
	if not state then return false end
	state.pos = data
	state.posDirty = true
	return true
end

local function refreshPosition(vehicle, state)
	if not state.posDirty then return end
	state.posDirty = false
	local decoded = jsonDecode(state.pos)
	if not decoded or not decoded.pos or not decoded.rot then return end
	vehicle.position:set(decoded.pos[1], decoded.pos[2], decoded.pos[3])
	vehicle.rotation:set(decoded.rot[1], decoded.rot[2], decoded.rot[3], decoded.rot[4])
end

local function flush(serverVehicleID, state)
	-- vehicle events first: a reset places and repairs the vehicle, the stream data then applies on top
	for _, data in ipairs(state.vehicleEvents) do
		MPVehicleGE.handle(data)
	end
	for _, key in ipairs(flushOrder) do
		local held = state.streams[key]
		if held then
			local apply = getApplyFunction(key)
			if apply then
				apply(type(held) == "table" and jsonEncode(held) or held, serverVehicleID)
			end
		end
	end
	for _, event in ipairs(state.events) do
		local apply = getApplyFunction(event[1])
		if apply then apply(event[2], serverVehicleID) end
	end
	-- the latest position goes straight to the mailbox, positionVE teleports the vehicle if it is far off
	if state.pos then
		be:sendToMailbox("vehPosPckt" .. serverVehicleID, state.pos)
	end
end

local function cull(serverVehicleID, gameVehicleID, veh)
	local p = getPool()
	if not p.allVehs[gameVehicleID] then p:insertVeh(gameVehicleID) end

	culled[serverVehicleID] = { gameVehicleID = gameVehicleID, streams = {}, events = {}, vehicleEvents = {} }
	culledByGameID[gameVehicleID] = serverVehicleID

	p.fadeQueue[gameVehicleID] = nil
	veh:setMeshAlpha(1, "")
	if not p:setVeh(gameVehicleID, false) then veh:setActive(0) end
end

-- clears culled state and replays held packets, the vehicle must already be active
local function release(serverVehicleID)
	local state = culled[serverVehicleID]
	if not state then return end
	culled[serverVehicleID] = nil
	culledByGameID[state.gameVehicleID] = nil
	if getObjectByID(state.gameVehicleID) then
		flush(serverVehicleID, state)
	end
end

--- Reactivates a culled vehicle and replays its held packets. Safe to call for any vehicle.
-- @param serverVehicleID string X-Y
-- @param holdAwake bool optional, keep the vehicle awake for a few seconds regardless of distance
local function wake(serverVehicleID, holdAwake)
	if holdAwake then holdAwakeUntil[serverVehicleID] = clock + HOLD_AWAKE_TIME end

	local state = culled[serverVehicleID]
	if not state then return end
	local gameVehicleID = state.gameVehicleID
	local veh = getObjectByID(gameVehicleID)

	-- clear before activating so onVehicleActiveChanged does not treat this as an external activation
	culled[serverVehicleID] = nil
	culledByGameID[gameVehicleID] = nil
	if not veh then return end

	local p = getPool()
	if not (p.allVehs[gameVehicleID] and p:setVeh(gameVehicleID, true, true)) then veh:setActive(1) end
	if p:fadeInVeh(gameVehicleID) then veh:setMeshAlpha(0, "") end

	flush(serverVehicleID, state)
end

local function wakeAll()
	for serverVehicleID, _ in pairs(culled) do
		wake(serverVehicleID)
	end
end

local function reset()
	culled = {}
	culledByGameID = {}
	holdAwakeUntil = {}
	pool = nil
end


local function onUpdate(dtReal)
	clock = clock + dtReal
	if not enabled then return end
	if not (MPGameNetwork and MPGameNetwork.launcherConnected()) then return end

	updateTimer = updateTimer - dtReal
	if updateTimer > 0 then return end
	updateTimer = UPDATE_INTERVAL

	camPos:set(core_camera.getPositionXYZ())
	local playerVeh = getPlayerVehicle(0)
	local playerVehID = playerVeh and playerVeh:getID()
	local wakeDist2 = cullDistance * cullDistance
	local cullDist2 = (cullDistance + WAKE_BUFFER) * (cullDistance + WAKE_BUFFER)

	for serverVehicleID, vehicle in pairs(MPVehicleGE.getVehicles()) do
		local gameVehicleID = vehicle.gameVehicleID
		if vehicle.isLocal or not vehicle.isSpawned or not gameVehicleID then goto continue end
		local veh = getObjectByID(gameVehicleID)
		if not veh then goto continue end

		local state = culled[serverVehicleID]
		if state then
			refreshPosition(vehicle, state)
			if gameVehicleID == playerVehID or vehicle.position:squaredDistance(camPos) < wakeDist2 then
				wake(serverVehicleID)
			end
		elseif gameVehicleID ~= playerVehID and veh:getActive() and (holdAwakeUntil[serverVehicleID] or 0) < clock then
			vehPos:set(veh:getPositionXYZ())
			if vehPos:squaredDistance(camPos) > cullDist2 then
				cull(serverVehicleID, gameVehicleID, veh)
			end
		end
		::continue::
	end
end

local function onVehicleActiveChanged(gameVehicleID, active)
	-- something else (eg the instability handler) activated a vehicle we culled, hand it back
	if active and culledByGameID[gameVehicleID] then
		release(culledByGameID[gameVehicleID])
	end
end

local function onVehicleSwitched(oldGameVehicleID, newGameVehicleID)
	local serverVehicleID = culledByGameID[newGameVehicleID]
	if serverVehicleID then wake(serverVehicleID, true) end
end

local function onVehicleDestroyed(gameVehicleID)
	local serverVehicleID = culledByGameID[gameVehicleID]
	if serverVehicleID then
		culled[serverVehicleID] = nil
		culledByGameID[gameVehicleID] = nil
		holdAwakeUntil[serverVehicleID] = nil
	end
end

local function onSettingsChanged()
	enabled = settings.getValue("remoteVehicleCulling") == true
	cullDistance = math.max(50, tonumber(settings.getValue("remoteVehicleCullDistance")) or 500)
	if not enabled then wakeAll() end
end

local function onBeamMPServerLeave()
	wakeAll()
	reset()
end

local function onClientEndMission()
	reset()
end

--- Returns the number of currently culled vehicles, for debugging / UI.
local function getCulledCount()
	local count = 0
	for _ in pairs(culled) do count = count + 1 end
	return count
end


M.intercept              = intercept
M.interceptPosition      = interceptPosition
M.isCulled               = isCulled
M.wake                   = wake
M.wakeAll                = wakeAll
M.getCulledCount         = getCulledCount

M.onUpdate               = onUpdate
M.onVehicleActiveChanged = onVehicleActiveChanged
M.onVehicleSwitched      = onVehicleSwitched
M.onVehicleDestroyed     = onVehicleDestroyed
M.onSettingsChanged      = onSettingsChanged
M.onBeamMPServerLeave    = onBeamMPServerLeave
M.onClientEndMission     = onClientEndMission
M.onExtensionLoaded      = onSettingsChanged
M.onInit = function() setExtensionUnloadMode(M, "manual") end

return M
