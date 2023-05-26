local M = {state={}}



local originalGetDriverData
local originalToggleWalkingMode
local original_onInstabilityDetected
local original_bigMapMode
local original_bullettime

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

local function modified_bigMapMode()
	bullettime.pause = nop
	return true --TODO: maybe add a check to stop map opening if no vehicle is present
end

original_bullettime = bullettime.pause

local function onBigMapActivated()
	bullettime.pause = original_bullettime -- re-enable pausing function after map has been opened
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
			--commands.setGameCamera()
		end
	end
end





local function runPostJoin()
	--save the original functions so they can be restored after leaving an mp session
	original_onInstabilityDetected = onInstabilityDetected
	original_bigMapMode = freeroam_bigMapMode.canBeActivated

	--replace the functions
	if settings.getValue("disableInstabilityPausing") then
		onInstabilityDetected = modified_onInstabilityDetected
	end
	onInstabilityDetected = modified_onInstabilityDetected
	freeroam_bigMapMode.canBeActivated = modified_bigMapMode
end


local function onServerLeave()
	if original_onInstabilityDetected then onInstabilityDetected = original_onInstabilityDetected end
	if original_bigMapMode then freeroam_bigMapMode.canBeActivated = original_bigMapMode end
	if originalGetDriverData then core_camera.getDriverData = originalGetDriverData end
	if originalToggleWalkingMode and gameplay_walk and gameplay_walk.toggleWalkingMode then gameplay_walk.toggleWalkingMode = originalToggleWalkingMode end
end


local function onWorldReadyState(state)
	log('W', 'onWorldReadyState', state)
	if state == 2 then
		if MPCoreNetwork and MPCoreNetwork.isMPSession() then
			log('M', 'onWorldReadyState', 'Setting game state to multiplayer.')
			core_gamestate.setGameState('multiplayer', 'multiplayer', 'multiplayer')
			
            -- QUICK DIRTY PATCH FOR THE CAMERA SPAWNING UNDERGROUND FROM THE 0.28 UDPATE
            local contents = jsonReadFile(getMissionPath() .. "main/MissionGroup/PlayerDropPoints/items.level.json")

            local position = contents["position"] or { 0, 0, 0 }

            position[3] = position[3] + 2 -- otherwise the cam spawns in the ground

            -- local rotation = contents["rotationMatrix"] -- the info in this table can be borked, so we use 0 for all rotations
            core_camera.setPosRot(0, position[1], position[2], position[3], 0, 0, 0, 0)
		end
	end
end

-- public interface
M.onUpdate          = onUpdate
M.onWorldReadyState = onWorldReadyState
M.onBigMapActivated = onBigMapActivated

M.runPostJoin = runPostJoin
M.onServerLeave = onServerLeave
return M
