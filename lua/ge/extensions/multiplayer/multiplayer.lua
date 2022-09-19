local M = {state={}}

local logTag = 'multiplayer'
log("I", "", "Gamemode Loaded")

local inputActionFilter = extensions.core_input_actionFilter

local originalGetDriverData = nop
local originalToggleWalkingMode = nop


local function startMultiplayerHelper (level, startPointName)
	core_gamestate.requestEnterLoadingScreen(logTag .. '.startMultiplayerHelper')
	loadGameModeModules()
	M.state = {}
	M.state.multiplayerActive = true

	local levelPath = level
	if type(level) == 'table' then
		setSpawnpoint.setDefaultSP(startPointName, level.levelName)
		levelPath = level.misFilePath
	end

	inputActionFilter.clear(0)

	spawn.preventPlayerSpawning = true -- no default pickup pog
	core_levels.startLevel(levelPath)
	core_gamestate.requestExitLoadingScreen(logTag .. '.startMultiplayerHelper')
end

local function startAssociatedFlowgraph(level)
	-- load flowgaphs associated with this level.
		if level.flowgraphs then
			for _, absolutePath in ipairs(level.flowgraphs or {}) do
				local relativePath = level.misFilePath..absolutePath
				local path = FS:fileExists(absolutePath) and absolutePath or (FS:fileExists(relativePath) and (relativePath) or nil)
				if path then
					local mgr = core_flowgraphManager.loadManager(path)
					--core_flowgraphManager.startOnLoadingScreenFadeout(mgr)
					mgr:setRunning(true)
					mgr.stopRunningOnClientEndMission = true -- make mgr self-destruct when level is ended.
					mgr.removeOnStopping = true -- make mgr self-destruct when level is ended.
					log("I", "Flowgraph loading", "Loaded level-associated flowgraph from file "..dumps(path))
				 else
					 log("E", "Flowgraph loading", "Could not find file in either '" .. absolutePath.."' or '" .. relativePath.."'!")
				 end
			end
		end
	end

local function startMultiplayer(level, startPointName, wasDelayed)
	core_gamestate.requestEnterLoadingScreen(logTag)
	-- if this was a delayed start, load the FGs now.
	--if wasDelayed then
		--startAssociatedFlowgraph(level)
	--end

	-- this is to prevent bug where multiplayer is started while a different level is still loaded.
	-- Loading the new multiplayer causes the current loaded multiplayer to unload which breaks the new multiplayer
	local delaying = false
	if scenetree.MissionGroup then
		log('D', 'startMultiplayer', 'Delaying start of multiplayer until current level is unloaded...')
		M.triggerDelayedStart = function()
			log('D', 'startMultiplayer', 'Triggering a delayed start of multiplayer...')
			M.triggerDelayedStart = nil
			startMultiplayer(level, startPointName, true)
		end
		endActiveGameMode(M.triggerDelayedStart)
		delaying = true
	elseif not core_gamestate.getLoadingStatus(logTag .. '.startMultiplayerHelper') then -- remove again at some point
		startMultiplayerHelper(level, startPointName)
		core_gamestate.requestExitLoadingScreen(logTag)
	end
	-- if there was no delaying and the function call itself didnt
	-- come from a delayed start, load the FGs (starting from main menu)
	if not wasDelayed and not delaying then
		startAssociatedFlowgraph(level)
	end

	if not shipping_build and settings.getValue('enableCrashCam') then
    extensions.load('core_crashCamMode')
  end
end

local function startMultiplayerByName(levelName)
  local level = core_levels.getLevelByName(levelName)
  if level then
			startMultiplayer(level)
			return true
	end
	return false
end

local function onClientPreStartMission(mission)
	if MPCoreNetwork.isMPSession() then
		local path, file, ext = path.splitWithoutExt(mission)
		file = path .. 'mainLevel'
		if not FS:fileExists(file..'.lua') then return end
		extensions.loadAtRoot(file,"")
		if mainLevel and mainLevel.onClientPreStartMission then
			mainLevel.onClientPreStartMission(mission)
		end
	end
end

local function onClientPostStartMission()
	if MPCoreNetwork.isMPSession() then
		core_gamestate.setGameState('multiplayer', 'multiplayer', 'multiplayer') -- This is added to set the UI elements
		log('M', 'onClientPostStartMission', 'Setting game state to multiplayer.')
		MPGameNetwork.connectToLauncher()
	end
end

local function onClientStartMission(mission)
	be:executeJS("document.getElementsByTagName('fancy-background')[0].remove();")
	if M.state.multiplayerActive then
		extensions.hook('onMultiplayerLoaded', mission)
		local ExplorationCheckpoints = scenetree.findObject("ExplorationCheckpointsActionMap")
		local am = scenetree.findObject("ExplorationCheckpointsActionMap")
    if am then am:push() end
	end
end

local function onClientEndMission(mission)
	if M.state.multiplayerActive then
		M.state.multiplayerActive = false
		local am = scenetree.findObject("ExplorationCheckpointsActionMap")
    if am then am:pop() end
	end

	if not mainLevel then return end
	local path, file, ext = path.splitWithoutExt(mission)
	extensions.unload(path .. 'mainLevel')
end



-- Resets previous vehicle alpha when switching between different vehicles
-- Used to fix multipart highlighting when switching vehicles
local function onVehicleSwitched(oldId, newId, player)
  if oldId then
    local veh = be:getObjectByID(oldId)
    if veh then
      extensions.core_vehicle_partmgmt.selectReset()
    end
  end
  if newId then
    local veh = be:getObjectByID(newId)
    if veh then
      veh:refreshLastAlpha()
    end
  end
end

local function onResetGameplay(playerID)
  if scenario_scenarios and scenario_scenarios.getScenario() then return end
  if campaign_campaigns and campaign_campaigns.getCampaign() then return end
  if career_career      and career_career.isEnabled()        then return end
  for _, mgr in ipairs(core_flowgraphManager.getAllManagers()) do
    if mgr:blocksOnResetGameplay() then return end
  end
  be:resetVehicle(playerID)
end

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

local function onUpdate(dt)
	if core_camera.getDriverData ~= modifiedGetDriverData then
		originalGetDriverData = core_camera.getDriverData
		core_camera.getDriverData = modifiedGetDriverData
	end
	if gameplay_walk and gameplay_walk.toggleWalkingMode ~= modifiedToggleWalkingMode then
		originalToggleWalkingMode = gameplay_walk.toggleWalkingMode
		gameplay_walk.toggleWalkingMode = modifiedToggleWalkingMode
	end
	
	if worldReadyState == 0 then
    -- When the world is ready, we have to set the camera we want to use. However, we want to do this
    -- when we have vehicles spawned.
    local vehicles = scenetree.findClassObjects('BeamNGVehicle')
    for k, vecName in ipairs(vehicles) do
      local to = scenetree.findObject(vecName)
      if to and to.obj and to.obj:getId() then
        commands.setGameCamera()
        break
      end
    end
	-- Workaround for worldReadyState not being set properly if there are no vehicles
	serverConnection.onCameraHandlerSetInitial()
	extensions.hook('onCameraHandlerSet')
  end
end

local function onAnyActivityChanged(state)
  if not shipping_build then
    if state == "started" then
      if core_crashCamMode then
        extensions.unload('core_crashCamMode')
      end
    elseif state == "stopped" then
      if settings.getValue('enableCrashCam') then
        extensions.load('core_crashCamMode')
      end
    end
  end
end

local function onSettingsChanged()
  if not shipping_build then
    if settings.getValue('enableCrashCam') then
      extensions.load('core_crashCamMode')
    elseif core_crashCamMode then
      extensions.unload('core_crashCamMode')
    end
  end
end

-- public interface
M.startMultiplayer          = startMultiplayer
M.startMultiplayerByName    = startMultiplayerByName
M.onClientPreStartMission   = onClientPreStartMission
M.onClientPostStartMission  = onClientPostStartMission
M.onClientStartMission      = onClientStartMission
M.onClientEndMission        = onClientEndMission
M.onVehicleSwitched         = onVehicleSwitched
M.onResetGameplay           = onResetGameplay
M.onUpdate                  = onUpdate
M.onAnyActivityChanged    = onAnyActivityChanged
M.onSettingsChanged       = onSettingsChanged

return M
