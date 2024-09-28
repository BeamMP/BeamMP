-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

-- Custom functions

--spinner
local function toggleDirection(controllerName, funcName, tempTable, ...)
	local motor = powertrain.getDevice("motor")
	if not motor then return end
	motor.motorDirection = motor.motorDirection * -1

	tempTable.variables = motor.motorDirection
	controllerSyncVE.sendControllerData(tempTable)
end

local function receiveToggleDirection(data)
	local motor = powertrain.getDevice("motor")
	motor.motorDirection = data.variables
end

--hydraulics/hydraulicsCombustionEngineControl
local manualIdleRaise = false

-- using the global set function instead of the local one so we can send it's state rather than just the toggle
local function toggleIdleRaise(controllerName, funcName, tempTable, ...)
	controller.getControllerSafe(controllerName).setIdleRaise(not manualIdleRaise)
end

-- these are needed to keep track of the manualIdleRaise state because it's only a local in the controller
local function setIdleRaise(controllerName, funcName, tempTable, ...)
	manualIdleRaise = ...
	controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
	controllerSyncVE.sendControllerData(tempTable)
end

local function setIdleRaiseReceive(data)
	manualIdleRaise = data.variables[1]
	controllerSyncVE.OGcontrollerFunctionsTable[data.controllerName][data.functionName](manualIdleRaise)
end

--tirePressureControl
-- using the global set function instead of the local one so we can send it's state rather than just the toggle
local function toggleGroupState(controllerName, funcName, tempTable, ...)
	local groupActive = true
	local isActiveElectricsName = controllerName .. "_" .. ... .. "_isActive"
	if electrics.values[isActiveElectricsName] == 1 then
		groupActive = true
	else
		groupActive = false
	end
	controller.getControllerSafe(controllerName).setGroupState(... ,not groupActive)
end

--axleLift
local currentMode
local modes = { auto = "auto", manual = "manual", off = "off" }

local function getNextMode()
	if currentMode == modes.auto then
		return modes.manual
	elseif currentMode == modes.manual then
		return modes.off
	else
		return modes.auto
	end
end

local function toggleMode(controllerName, funcName, tempTable, ...)
	currentMode = getNextMode()
	controller.getControllerSafe(controllerName).setMode(currentMode)
end

--TwoStep
local function TwoStep(controllerName, funcName, tempTable, ...)
	local returnData = controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
	local twoStepData = controller.getControllerSafe(controllerName):serialize() -- returns state and rpm, i just sync both state and RPM with all functions so it will resync both whenever any of them are called
	if twoStepData then
		tempTable.twoStepData = twoStepData
		tempTable.variables = nil -- since the twoStepData is synced every time we don't need the actual function variable
		controllerSyncVE.sendControllerData(tempTable)
	end
	return returnData
end

local function receiveTwoStep(data)
	local twoStepData = data.twoStepData
	if twoStepData then
		controller.getControllerSafe(data.controllerName).deserialize(data.twoStepData) -- applies the two step data
	end
end

--postCrashBrake
local postCrashBrakeTriggered = 0
local function postCrashBrakeRemoteUpdateGFX(controllerName, funcName, tempTable, ...)
	if postCrashBrakeTriggered ~= electrics.values.postCrashBrakeTriggered then
		postCrashBrakeTriggered = electrics.values.postCrashBrakeTriggered
		if electrics.values.postCrashBrakeTriggered == 1 then
			guihooks.message("Impact detected, stopping car...", 10, "vehicle.postCrashBrake.impact")
		end
	end
end

local function postCrashBrakeinit(controllerName, funcName, tempTable, ...)
	controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
	electrics.values.postCrashBrakeTriggered = 0 -- postCrashBrakeinit set's the electric to nil which beamMP doesn't detect, so to fix that i set it to 0
end

-- jato
local jatoFrames = 0

local function jatoRemoteUpdateGFX(controllerName, funcName, tempTable, ...) -- fixes jato being on when it shouldn't when driving on keyboard
	if electrics.values.jato == 1 then -- if electrics.values.jato is 1 then the vehicle owner is using rockets
		electrics.values.jatoInput = 1 -- the controller will set jato back to 0 on the first frame when jatoInput is 0, setting it to 1 here prevents that
		jatoFrames = 2 -- if we don't allow the function to run for at least 2 more frames the audio will not start and stop correctly
	else
		electrics.values.jatoInput = 0 -- prevents it from being stuck on
		input.throttle = 0 -- prevents it from being stuck on when using keyboard
	end

	if electrics.values.jato == 1 or jatoFrames ~= 0 then
		controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
	end

	if jatoFrames ~= 0 then
		jatoFrames = jatoFrames - 1
	end
end

local function readDriveMode(controllerName, funcName, tempTable, ...)
	local controller = controller.getControllerSafe(controllerName)
	if controller then
		controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)

		tempTable.driveMode = controller.getCurrentDriveModeKey()
		controllerSyncVE.sendControllerData(tempTable)
	end
end

local function recieveDriveMode(data)
	controllerSyncVE.OGcontrollerFunctionsTable[data.controllerName]["setDriveMode"](data.driveMode)
end

-- compare set to true only sends data when there is a change
-- compare set to false sends the data every time the function is called
-- adding ownerFunction and/or receiveFunction can set custom functions to read or change data before sending or on receiveing
--["controllerFunctionName"] = {
--  ownerFunction = customFunctionOnSend,
--  receiveFunction = customFunctionOnReceive
--},
-- storeState stores the incoming data and then if the remote car was reset locally for whatever reason it reapplies the state

local includedControllerTypes = {

	["axleLift"] = {
		["setMode"] = {
			storeState = true
		},
		["toggleMode"] = {
			ownerFunction = toggleMode,
		},
		["setParameters"] = {
			compare = true
			}
	},
	
	["driveModes"] = {
		["setDriveMode"] = {},
		["nextDriveMode"] = {
			ownerFunction = readDriveMode,
			receiveFunction = recieveDriveMode
		},
		["previousDriveMode"] = {
			ownerFunction = readDriveMode,
			receiveFunction = recieveDriveMode
		},
	},

	["hydraulicSuspension"] = {
		["setGroupsPosition"] = {},
		["setGroupsBleed"] = {},
		["setGroupsMomentaryIncrease"] = {}
	},

	["hydraulics/hydraulicsCombustionEngineControl"] = {
		["toggleIdleRaise"] = {
			ownerFunction = toggleIdleRaise
		},
		["setIdleRaise"] = {
			ownerFunction = setIdleRaise,
			receiveFunction = setIdleRaiseReceive,
			storeState = true
		}
	},

	["hydraulics/hydraulicTrailerFeet"] = {
		["moveFeet"] = {}
	},

	["jato"] = {
		["updateGFX"] = {
			remoteOnly = true,
			remoteFunction = jatoRemoteUpdateGFX
		}
	},

	["lightbar"] = {
		["toggleMode"] = {
		}
	},

	["postCrashBrake"] = {
		["updateGFX"] = { -- disables postCrashBrake on remote vehicles by replacing the function with an empty one
			remoteOnly = true, -- so it only runs on remote vehicles so we don't send DT every frame :P
			remoteFunction = postCrashBrakeRemoteUpdateGFX, -- makes the impact detected message still show when the owner vehicle crashes
		},
		["init"] = {
			ownerFunction = postCrashBrakeinit --hooks into init to set the electric to 0 instead of nil, this is so BeamMP picks up the change
		}
	},

	["rollover"] = {
		["cycle"] = {},
		["prepare"] = {}
	},

	["spinner"] = {
		["toggleDirection"] = {
			ownerFunction = toggleDirection,
			receiveFunction = receiveToggleDirection,
			storeState = true
		}
	},

	["tirePressureControl"] = {
		["toggleGroupState"] = {
			ownerFunction = toggleGroupState
			},
		["setGroupState"] = {},
		["startInflateActiveGroups"] = {},
		["startDeflateActiveGroups"] = {},
		["setGroupsMomentaryIncrease"] = {},
		["stopActiveGroups"] = {},
	},

	["twoStepLaunch"] = {
		["setTwoStep"] = {
			ownerFunction = TwoStep,
			receiveFunction = receiveTwoStep
		},
		["toggleTwoStep"] = {
			ownerFunction = TwoStep,
			receiveFunction = receiveTwoStep
		},
		["changeTwoStepRPM"] = {
			ownerFunction = TwoStep,
			receiveFunction = receiveTwoStep
		}
	}
}

local function onReset()
	-- "hydraulics/hydraulicsCombustionEngineControl" --
	manualIdleRaise = false
	-- "axleLift"
	currentMode = "auto"
end

local function loadFunctions()
	if controllerSyncVE ~= nil then
		controllerSyncVE.addControllerTypes(includedControllerTypes)
	else
		dump("controllerSyncVE not found")
	end
end

M.loadControllerSyncFunctions = loadFunctions
M.onReset = onReset

return M
