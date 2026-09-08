-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- beammp_multiplayer API.
--- Author of this documentation is Titch
--- @module beammp_multiplayer
--- @usage modifiedGetDriverData(veh) -- internal access
--- @usage beammp_multiplayer.onWorldReadyState(1) -- external access

local M = {state={}}



local originalGetDriverData
local original_onInstabilityDetected


--- Custom GetDriverData for allowing the getting of the right hand door or not for passenger aspects.
--- @param veh userdata The vehicle data
--- @return unknown
local function modifiedGetDriverData(veh)
	if not veh then return nil end
	local caller = debug.getinfo(2).name
	if caller and caller == "getDoorsidePosRot" and veh.mpVehicleType and veh.mpVehicleType == 'R' then
		local id, right = core_camera.getDriverDataById(veh and veh:getID())
		return id, not right
	end
	return core_camera.getDriverDataById(veh and veh:getID())
end

local function onVehicleActiveChanged(vehicleID, active) -- delete unicycle if it gets deactivated locally so it syncs to others
	if not active then
		local MPVeh = getVehicleByGameID(vehicleID)
		if MPVeh and not MPVeh.isLocal then return end
		local walkData = gameplay_walk.onSerialize()
		if walkData.unicycleId and walkData.unicycleId == vehicleID then
  			local unicycle = getObjectByID(vehicleID)
			unicycle:delete()
		end
	end
end

--- A custom onInstabilityDetected function to prevent the freezing / pausing of the game for when in MP session
--- @param jbeamFilename table Object jbeam data of the object causing the instability
local function modified_onInstabilityDetected(jbeamFilename)
	log('E', "", "Instability detected for vehicle " .. tostring(jbeamFilename))
end


--- Called when the Big Map is loaded by the user. 
local function onBigMapActivated() -- don't pause the game when opening the Big Map
	if MPCoreNetwork and MPCoreNetwork.isMPSession() then
		simTimeAuthority.pause(false)
	end
end


--- onUpdate is a game eventloop function. It is called each frame by the game engine.
--- This is the main processing thread of BeamMP in the game
--- @param dt float
local function onUpdate(dt)
	if MPCoreNetwork and MPCoreNetwork.isMPSession() then
		--log('W', 'onUpdate', 'Running modified beammp code!')
		if core_camera.getDriverData ~= modifiedGetDriverData then
			log('W', 'onUpdate', 'Setting modifiedGetDriverData')
			originalGetDriverData = core_camera.getDriverData
			core_camera.getDriverData = modifiedGetDriverData
		end

		if worldReadyState == 0 then
			-- Workaround for worldReadyState not being set properly if there are no vehicles
			serverConnection.onCameraHandlerSetInitial()
			extensions.hook('onCameraHandlerSet')
			--commands.setGameCamera()
		end
	end
end




--- This function/event is triggered internally upon the joining on a map.
local function runPostJoin()
	--save the original functions so they can be restored after leaving an mp session
	original_onInstabilityDetected = onInstabilityDetected

	--replace the functions
	if settings.getValue("disableInstabilityPausing") then
		onInstabilityDetected = modified_onInstabilityDetected
	end
	onInstabilityDetected = modified_onInstabilityDetected
end


--- This function is called when the user leaves a server as part of cleanup 
local function onServerLeave()
	if original_onInstabilityDetected then onInstabilityDetected = original_onInstabilityDetected end
	if originalGetDriverData then core_camera.getDriverData = originalGetDriverData end
end


--- This function is called by BeamNG upon the change of the world ready state.
--- 1 = World is loading
--- 2 = World is ready, You are about to have the loading screen disappear. This is the time to show anything you have.
--- @param state number The state in numerical form.
local function onWorldReadyState(state)
	log('W', 'onWorldReadyState', state)
	if state == 2 then
		if MPCoreNetwork and MPCoreNetwork.isMPSession() then
			log('M', 'onWorldReadyState', 'Setting game state to BeamMP multiplayer.')
			local spawnDefaultGroups = { "CameraSpawnPoints", "PlayerSpawnPoints", "PlayerDropPoints", "spawnpoints" }
			if not commands.isFreeCamera() then
				commands.setFreeCamera()
			end
			for i, v in pairs(spawnDefaultGroups) do
				if scenetree.findObject(spawnDefaultGroups[i]) then
					local spawngroupPoint = scenetree.findObject(spawnDefaultGroups[i]):getRandom()
					if not spawngroupPoint then
						break
					end
					local sgPpointID = scenetree.findObjectById(spawngroupPoint:getId())
					if not sgPpointID then
						break
					end
					if sgPpointID and sgPpointID.obj then
						local spawnPos = sgPpointID.obj:getPosition()
						core_camera.setPosRot(0, spawnPos.x, spawnPos.y, spawnPos.z + 3, 0, 0, 0, 0)
						return
					end
				end
			end

			local defaultSpawn = scenetree.findObject(setSpawnpoint.loadDefaultSpawnpoint())
			if defaultSpawn and defaultSpawn.obj then
				local spawnPos = defaultSpawn.obj:getPosition()
				core_camera.setPosRot(0, spawnPos.x, spawnPos.y, spawnPos.z + 3, 0, 0, 0, 0)
				return
			end
		end
	end
end

-- public interface
M.onUpdate          = onUpdate
M.onWorldReadyState = onWorldReadyState
M.onBigMapActivated = onBigMapActivated
M.onBeamMPPostJoin = runPostJoin
M.onBeamMPServerLeave = onServerLeave
M.onVehicleActiveChanged = onVehicleActiveChanged
M.onInit = function() setExtensionUnloadMode(M, "manual") end

return M
