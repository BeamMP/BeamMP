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

local function setOnlineModeRestrictions()
	vehicles.spawnNewVehicle = hook.add(vehicles.spawnNewVehicle, preventVehicleSpawn)
	bullettime.selectPreset = hook.add(bullettime.selectPreset, disableBullettime)
	bullettime.togglePause = hook.add(bullettime.togglePause, disablePause)
	bullettime.getPause = hook.add(bullettime.getPause, disablePause)
	bullettime.pause = hook.add(bullettime.pause, disablePause)
end

local function disableOnlineModeRestrictions()
	vehicles.spawnNewVehicle = hook.remove(vehicles.spawnNewVehicle, preventVehicleSpawn)
	bullettime.selectPreset = hook.remove(bullettime.selectPreset, disableBullettime)
	bullettime.togglePause = hook.remove(bullettime.togglePause, disablePause)
	bullettime.getPause = hook.remove(bullettime.getPause, disablePause)
	bullettime.pause = hook.remove(bullettime.pause, disablePause)
end

M.disableOnlineModeRestrictions = disableOnlineModeRestrictions
M.setOnlineModeRestrictions = setOnlineModeRestrictions

return M
