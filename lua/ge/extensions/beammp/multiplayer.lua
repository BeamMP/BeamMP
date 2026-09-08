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
local originalToggleWalkingMode
local originalOnVehicleSwitched


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


--- Custom walking mode function that handles the getting of the unicycle and handles the deletion of it.
local function modifiedToggleWalkingMode()
	local unicycle = gameplay_walk.getCurrentUnicycle()
	if unicycle ~= nil then
		local veh = gameplay_walk.getVehicleInFront()
		if not veh or veh:getJBeamFilename() == "unicycle" then return end
	end
	originalToggleWalkingMode()
	
	-- If we were in a unicycle and entered a vehicle, delete it so it disappears for other players as well
	if unicycle ~= nil then
		unicycle:delete()
	end
end

--- Custom walking mode function that handles the getting of the unicycle and handles the deletion of it.
local function modifiedOnVehicleSwitched(oldId, newId, player)
  	local unicycle = scenetree.findObjectById(oldId)
	local walkData = gameplay_walk.onSerialize()

	originalOnVehicleSwitched(oldId, newId, player)
	-- If we were in a unicycle and entered a vehicle, delete it so it disappears for other players as well
	if unicycle ~= nil and walkData.unicycleId == oldId then
		unicycle:delete()
	end
end


--- Called when the Big Map is loaded by the user. 
local function onBigMapActivated() -- don't pause the game when opening the Big Map
	if MPCoreNetwork and MPCoreNetwork.isMPSession() then
		simTimeAuthority.pause(false)
	end
end

--- A custom onInstabilityDetected function to prevent the vehicles from being deleted instantly when in MP session
--- @param jbeamFilename table Object jbeam data of the object causing the instability
local vehicleInstabilityState = {}
local vehInstability = false
local instabilityTimer = 0
local instabilityFrameCount = 0
local hasRecovered = true
local function onInstabilityDetected(vid, returnData)
	local v = getObjectByID(vid)
	local jbeamFilename = v:getJBeamFilename()
  	v:queueLuaCommand('obj:requestReset(RESET_PHYSICS)')
	returnData.instabilityHandled = true -- tells BeamNG that we have handled the instability

	if vehicleInstabilityState[vid] then -- if vehicle has had an instability already
		local newTime = os:clock()
		local timeDiff = math.abs(vehicleInstabilityState[vid].time - newTime)
		if timeDiff > 4 then -- reset the instability counter if it's more than 4 seconds since last instability, to reduce vehicle deletions when doing crazy things 
			vehicleInstabilityState[vid].instabilityCount = 0
		elseif timeDiff < 1/30 then -- there often seem to be a duplicate instability, so if it's less than one 30th of a second since the last one we ignore it
			return
		end
		vehicleInstabilityState[vid].time = newTime
		vehicleInstabilityState[vid].instabilityCount = vehicleInstabilityState[vid].instabilityCount + 1
	else
		vehicleInstabilityState[vid] = {instabilityCount = 1, triggered = false, setActive = false, time = os:clock()}
	end

	if not vehicleInstabilityState[vid].setActive and vehicleInstabilityState[vid].instabilityCount > 3 then
		v:setActive(0) -- deactivate vehicle to prevent more vehicles from getting hit by the unstable vehicle
		if instabilityTimer == 0 then
			instabilityTimer = 1
			instabilityFrameCount = 0
		elseif instabilityTimer < 0 then
			instabilityFrameCount = 0
			instabilityTimer = 0.5
		end
		vehicleInstabilityState[vid].triggered = true
		vehInstability = true
		ui_message("Multiple Instabilities detected in \'"..jbeamFilename.."\' "..vehicleInstabilityState[vid].instabilityCount.." vehicle deactivated temporarily", 10, 'instability'..jbeamFilename..'', "danger")
	end

	if vehicleInstabilityState[vid].setActive then
		vehicleInstabilityState[vid].setActive = false
	end
end

local function instabilityHandlerUpdate(dt)
	if vehInstability then
		if instabilityTimer < 0 then
			instabilityFrameCount = instabilityFrameCount + 1
			if instabilityFrameCount == 1 then
				hasRecovered = false
				ui_message("Attempting to reactivate unstable vehicles", 10, 'instabilityReactivate', "warning")
			elseif instabilityFrameCount == 2 then
				log("E", "", "reactivating vehicles")
				for vehID, states in pairs(vehicleInstabilityState) do
					if states.triggered then
						local veh = getObjectByID(vehID)
						if veh then
							if states.instabilityCount > 10 then
								ui_message(""..veh:getJBeamFilename().." had too many instabilities and was deleted\n\nRight click the player's name and queue deleted vehicles to respawn it", 20, 'instabilityDelete'..veh:getJBeamFilename()..''.. vehID, "warning")
								veh:delete()
								vehicleInstabilityState[vehID] = nil --TODO put in spawn queue instead of clearing it
							else
								veh:setActive(1)
								vehicleInstabilityState[vehID].setActive = true
							end
						end
					end
				end
			elseif instabilityFrameCount > 3 and not hasRecovered then
				local isStable = true
				for vehID, states in pairs(vehicleInstabilityState) do
					local veh = getObjectByID(vehID)
					if veh then
						if not veh:getActive() then
							veh:setActive(1)
							vehicleInstabilityState[vehID].setActive = true
  							veh:queueLuaCommand('obj:requestReset(RESET_PHYSICS)')
						end
						if isnaninf(veh:getVelocity():length()) then
							isStable = false
						else
							if states.triggered then
								vehicleInstabilityState[vehID].triggered = false
							end
						end
					end
				end

				if isStable or instabilityTimer < -10 then
					instabilityFrameCount = 0
					vehInstability = false
					instabilityTimer = 0
					hasRecovered = true
					return
				end
			end
		end
		instabilityTimer = instabilityTimer - dt
	end
end


--- onUpdate is a game eventloop function. It is called each frame by the game engine.
--- This is the main processing thread of BeamMP in the game
--- @param dt float
local function onUpdate(dt)
	instabilityHandlerUpdate(dt)
	if MPCoreNetwork and MPCoreNetwork.isMPSession() then
		--log('W', 'onUpdate', 'Running modified beammp code!')
		if core_camera.getDriverData ~= modifiedGetDriverData then
			log('W', 'onUpdate', 'Setting modifiedGetDriverData')
			originalGetDriverData = core_camera.getDriverData
			core_camera.getDriverData = modifiedGetDriverData
		end
		if gameplay_walk then
			if gameplay_walk.toggleWalkingMode ~= modifiedToggleWalkingMode then
				log('W', 'onUpdate', 'Setting modifiedToggleWalkingMode')
				originalToggleWalkingMode = gameplay_walk.toggleWalkingMode
				gameplay_walk.toggleWalkingMode = modifiedToggleWalkingMode
			end
			if gameplay_walk.onVehicleSwitched ~= modifiedOnVehicleSwitched then
				log('W', 'onUpdate', 'Setting modifiedOnVehicleSwitched')
				originalOnVehicleSwitched = gameplay_walk.onVehicleSwitched
				gameplay_walk.onVehicleSwitched = modifiedOnVehicleSwitched
			end
		end

		if worldReadyState == 0 then
			-- Workaround for worldReadyState not being set properly if there are no vehicles
			serverConnection.onCameraHandlerSetInitial()
			extensions.hook('onCameraHandlerSet')
			--commands.setGameCamera()
		end
	end
end


--- This function is called when the user leaves a server as part of cleanup 
local function onServerLeave()
	if originalGetDriverData then core_camera.getDriverData = originalGetDriverData end
	if originalToggleWalkingMode and gameplay_walk and gameplay_walk.toggleWalkingMode then gameplay_walk.toggleWalkingMode = originalToggleWalkingMode end
	if originalOnVehicleSwitched and gameplay_walk and gameplay_walk.onVehicleSwitched then gameplay_walk.onVehicleSwitched = originalOnVehicleSwitched end
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
M.onBeamMPServerLeave = onServerLeave
M.onInstabilityDetected = onInstabilityDetected
M.onInit = function() setExtensionUnloadMode(M, "manual") end

return M
