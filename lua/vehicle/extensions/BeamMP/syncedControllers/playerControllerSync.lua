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

local function setSpeedCoef(controllerName, funcName, tempTable, ...)
	controllerSyncVE.sendControllerData(tempTable)
	movementSpeedCoef = ... --keeping track of the movementSpeedCoef state so the toggle function works properly
	controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
end

local includedControllerTypes = {
	["playerController"] = {
		["setCameraControlData"] = {
			compare = true
			},
		["jump"] = {
			compare = false
			},
		["walkLeftRightRaw"] = {
			compare = true,
			storeState = true
			},
		["walkLeftRight"] = {
			storeState = true
			},
		["walkUpDownRaw"] = {
			compare = true,
			storeState = true
			},
		["walkUpDown"] = {
			storeState = true
			},
		["setSpeedCoef"] = {
			compare = true,
			storeState = true,
			ownerFunction = setSpeedCoef
			},
		["toggleSpeedCoef"] = {
			ownerFunction = customtoggleSpeed
			},
		["crouch"] = {
			compare = true,
			storeState = true
			},
		["toggleCrouch"] = {
			ownerFunction = customtogglecrouch
		},
	},
}

local function onReset()
	isCrouching = false
end

local function loadFunctions()
	if controllerSyncVE ~= nil then
		controllerSyncVE.addControllerTypes(includedControllerTypes)
	else
		dump("controllerSyncVE not found")
	end
end

M.onBeamMPLoadControllerSyncFunctions = loadFunctions
M.onReset = onReset

return M
