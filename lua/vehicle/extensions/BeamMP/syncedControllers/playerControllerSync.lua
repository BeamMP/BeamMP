-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

-- playeController
-- the regular toggle will desync if the player is crouching as the unicycle is spawned,
-- this fixes that by using the global crouch function instead of the local one

local isCrouching = false
local function customtogglecrouch()
	if electrics.values.freezeState then
		return
	end
	isCrouching = not isCrouching
	controller.getControllerSafe("playerController").crouch(isCrouching and -1 or 1)
end

local movementSpeedCoef = 0
local function customtoggleSpeed()
	movementSpeedCoef = 1 - movementSpeedCoef
	controller.getControllerSafe("playerController").setSpeed(movementSpeedCoef)
end

--	electrics.values.unicycle_speed = movementSpeedCoef
local function setSpeedCoef(controllerName, funcName, tempTable, ...)
	controllerSyncVE.sendControllerData(tempTable)
	movementSpeedCoef = ... --keeping track of the movementSpeedCoef state so the toggle function works properly
	controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)

	electrics.values.unicycle_speed = ... -- for cross compatibility, remove when controller sync is out for everyone
end

-- the functions below are for cross compatibility, remove when controller sync is out for everyone --
-- electrics.values.unicycle_camera = -cameraRotation:toEulerYXZ().x
local function unicycle_camera(controllerName, funcName, tempTable, ...)
	controllerSyncVE.cacheState(tempTable)

	electrics.values.unicycle_camera = -tempTable.variables[1].cameraRotation:toEulerYXZ().x
	controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
end

--	electrics.values.unicycle_walk_x = guardedWalkVector.x
local function unicycle_walk_x(controllerName, funcName, tempTable, ...)
	controllerSyncVE.sendControllerData(tempTable)
	electrics.values.unicycle_walk_x = ...
	controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
end
--	electrics.values.unicycle_walk_y = guardedWalkVector.y
local function unicycle_walk_y(controllerName, funcName, tempTable, ...)
	controllerSyncVE.sendControllerData(tempTable)
	electrics.values.unicycle_walk_y = ...
	controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
end

--	electrics.values.unicycle_jump = jumpCooldown > 0.1
local function unicycle_jump(controllerName, funcName, tempTable, ...)
	controllerSyncVE.sendControllerData(tempTable)
	electrics.values.unicycle_jump = true

	controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
end
--	electrics.values.unicycle_crouch = (isCrouching and -1 or 1)

local function crouch(controllerName, funcName, tempTable, ...)
	controllerSyncVE.sendControllerData(tempTable)
	electrics.values.unicycle_crouch = ...

	controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
end

local includedControllerTypes = {
	["playerController"] = {
		["setCameraControlData"] = {
			compare = true,
			ownerFunction = unicycle_camera
			},
		["jump"] = {
			compare = false,
			ownerFunction = unicycle_jump
			},
		["walkLeftRightRaw"] = {
			compare = true,
			storeState = true,
			ownerFunction = unicycle_walk_x
			},
		["walkLeftRight"] = {
			compare = false,
			storeState = true,
			ownerFunction = unicycle_walk_x
			},
		["walkUpDownRaw"] = {
			compare = true,
			storeState = true,
			ownerFunction = unicycle_walk_y
			},
		["walkUpDown"] = {
			compare = false,
			storeState = true,
			ownerFunction = unicycle_walk_y
			},
		["setSpeedCoef"] = {
			compare = true,
			storeState = true,
			ownerFunction = setSpeedCoef
			},
		["toggleSpeedCoef"] = {
			compare = false,
			ownerFunction = customtoggleSpeed
			},
		["crouch"] = {
			compare = true,
			storeState = true,
			ownerFunction = crouch
			},
		["toggleCrouch"] = {
			ownerFunction = customtogglecrouch
		},
	},
}

local function onReset()
	isCrouching = false
	electrics.values.unicycle_crouch = 0 -- for cross compatibility, remove when controller sync is out for everyone
end

local lastunicycle_jump = 1
local time = 0
local function updateGFX(dt) -- this is all super wacky but it was the only way i got jump to work across BeamMP versions
	time = time + dt
	if time > 1/15 then
		time = 0
		if electrics.values.unicycle_jump == 1 and lastunicycle_jump == 1 then
			electrics.values.unicycle_jump = false
		end
		lastunicycle_jump = electrics.values.unicycle_jump
	end
	if electrics.values.unicycle_jump == 1 then
		electrics.values.unicycle_jump = true --  it would only send 1s and 0s, electricsVE checks for true on receive, but for whatever reason setting it to true for multiple frames works
	end
end --TODO definetly remove all this once controller sync is released to everyone

local function loadFunctions()
	if controllerSyncVE ~= nil then
		controllerSyncVE.addControllerTypes(includedControllerTypes)
	else
		dump("controllerSyncVE not found")
	end
end

M.loadControllerSyncFunctions = loadFunctions
M.onReset = onReset
M.updateGFX = updateGFX

return M
