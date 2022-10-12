local M = {state={}}

log("M", "multiplayer", "Gamemode Loaded")

--TODO: Move this file where the rest of the extensions are, or get rid of it completely

local originalGetDriverData = nop
local originalToggleWalkingMode = nop
local original_onInstabilityDetected = nop


local function modifiedGetDriverData(veh)
	if not veh then return nil end
	local caller = debug.getinfo(2).name
	if caller and caller == "getDoorsidePosRot" and veh.mpVehicleType and veh.mpVehicleType == 'R' then
		local id, right = core_camera.getDriverDataById(veh and veh:getID())
		return id, not right
	end
	return core_camera.getDriverDataById(veh and veh:getID())
end

local function modifiedToggleWalkingMode()
	local unicycle = gameplay_walk.getPlayerUnicycle()
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

local function modified_onInstabilityDetected(jbeamFilename)
	log('E', "", "Instability detected for vehicle " .. tostring(jbeamFilename))
end

local function onUpdate(dt)
	if MPCoreNetwork and MPCoreNetwork.isMPSession() then
		--log('W', 'onUpdate', 'Running modified beammp code!')
		if core_camera.getDriverData ~= modifiedGetDriverData then
			log('W', 'onUpdate', 'Setting modifiedGetDriverData')
			originalGetDriverData = core_camera.getDriverData
			core_camera.getDriverData = modifiedGetDriverData
		end
		if gameplay_walk and gameplay_walk.toggleWalkingMode ~= modifiedToggleWalkingMode then
			log('W', 'onUpdate', 'Setting modifiedToggleWalkingMode')
			originalToggleWalkingMode = gameplay_walk.toggleWalkingMode
			gameplay_walk.toggleWalkingMode = modifiedToggleWalkingMode
		end

		if worldReadyState == 0 then
			-- Workaround for worldReadyState not being set properly if there are no vehicles
			serverConnection.onCameraHandlerSetInitial()
			extensions.hook('onCameraHandlerSet')
		end
	end
end


local function onWorldReadyState(state)
	log('W', 'onWorldReadyState', state)
	if state == 2 then
		if MPCoreNetwork and MPCoreNetwork.isMPSession() then
			log('M', 'onWorldReadyState', 'Setting game state to multiplayer.')
			core_gamestate.setGameState('multiplayer', 'multiplayer', 'multiplayer')
			freeroam_bigMapMode.canBeActivated = function() return true end -- replace the game function to enable the big map mode in 'multiplayer' state --TODO: set back the original function, disable pausing when opening the map
			spawn.preventPlayerSpawning = false -- re-enable spawning of default vehicle, TODO: put this and instability pause disable into their own function
		end
	end
end

local function replaceGameFunctions()
	--save the original functions so they can be restored once we're not in a session anymore
	original_onInstabilityDetected = onInstabilityDetected

	--replace the functions
	if settings.getValue("disableInstabilityPausing") then
		onInstabilityDetected = modified_onInstabilityDetected
	end
end

local function restoreGameFunctions()
	onInstabilityDetected = original_onInstabilityDetected
end

-- public interface
M.onUpdate          = onUpdate
M.onWorldReadyState = onWorldReadyState
return M
