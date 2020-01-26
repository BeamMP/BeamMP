--====================================================================================
-- All work by Jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local M = {}
local hook = require('hook')
local vehicles = require('core/vehicles')

local function preventVehicleSpawn()
	if be:getObjectCount() == 1 then
		ui_message("You cannot have more than one vehicle spawned when online", 5, "")
		return true
	end
end

local function disablePause()
	ui_message("You cannot pause when online", 5, "")
	return true
end

local function disableBullettime()
	ui_message("You cannot use slow-motion when online", 5, "")
	return true
end

local function disableState()
	ui_message("You cannot change environment variables when online", 5, "")
	return true
end

local function setBullettimeRestrictions()
	bullettime.selectPreset = hook.add(bullettime.selectPreset, disableBullettime)
	bullettime.togglePause = hook.add(bullettime.togglePause, disablePause)
	bullettime.getPause = hook.add(bullettime.getPause, disablePause)
	bullettime.pause = hook.add(bullettime.pause, disablePause)
end

local function removeBullettimeRestrictions()
	bullettime.selectPreset = hook.remove(bullettime.selectPreset, disableBullettime)
	bullettime.togglePause = hook.remove(bullettime.togglePause, disablePause)
	bullettime.getPause = hook.remove(bullettime.getPause, disablePause)
	bullettime.pause = hook.remove(bullettime.pause, disablePause)
end

local function setOnlineModeRestrictions()
	core_environment.setState = hook.add(core_environment.setState, disableState)
	vehicles.spawnNewVehicle = hook.add(vehicles.spawnNewVehicle, preventVehicleSpawn)
	setBullettimeRestrictions()
end

local function disableOnlineModeRestrictions()
	core_environment.setState = hook.remove(core_environment.setState, disableState)
	vehicles.spawnNewVehicle = hook.remove(vehicles.spawnNewVehicle, preventVehicleSpawn)
	removeBullettimeRestrictions()
end

local function iAmAdmin()
	core_environment.setState = hook.remove(core_environment.setState, disableState)
	core_environment.setState = hook.add(core_environment.setState, Network.updateWeatherOnline)
end

local function clearAdminRights()
	core_environment.setState = hook.remove(core_environment.setState, Network.updateWeatherOnline)
end

M.disableOnlineModeRestrictions = disableOnlineModeRestrictions
M.setOnlineModeRestrictions = setOnlineModeRestrictions
M.updateWeatherInServer = updateWeatherInServer
M.clearAdminRights = clearAdminRights
M.iAmAdmin = iAmAdmin

return M
