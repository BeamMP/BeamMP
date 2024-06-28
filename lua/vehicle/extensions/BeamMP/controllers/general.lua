-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

-- Custom functions

--spinner

local function toggleDirection(controllerName, funcName, tempTable, ...)
	dump(controllerName, funcName, tempTable, ...)
	local motor = powertrain.getDevice("motor")
	if not motor then return end
	motor.motorDirection = motor.motorDirection * -1
	if tempTable.storeState then
		--storeState(controllerName, funcName, motor.motorDirection)
		storeState(tempTable)
	end
	tempTable.variables = {motorDirection = motor.motorDirection}
	sendControllerData(tempTable)
end

local function recieveToggleDirection(data)
	local motor = powertrain.getDevice("motor")
	motor.motorDirection = data.variables.motorDirection
end

--hydraulics/hydraulicsCombustionEngineControl
local manualIdleRaise = false

-- using the global function instead of the local one so we can send it's state rather than just the toggle
local function toggleIdleRaise(controllerName, funcName, tempTable, ...)
	controller.getControllerSafe(controllerName).setIdleRaise(not manualIdleRaise)
end

-- these are needed to keep track of the manualIdleRaise state because it's only a local in the controller
local function setIdleRaise(controllerName, funcName, tempTable, ...)
	manualIdleRaise = ...
	OGcontrollerFunctionsTable[controllerName][funcName](...)
	sendControllerData(tempTable)
end

local function setIdleRaiseRecieve(data)
	manualIdleRaise = unpack(data.variables)
	OGcontrollerFunctionsTable[data.controllerName][data.functionName](manualIdleRaise)
end

-- compare set to true only sends data when there is a change
-- compare set to false sends the data every time the function is called
-- adding ownerFunction and/or remoteFunction can set custom functions to read or change data before sending or on recieveing
--["controllerFunctionName"] = {
--  ownerFunction = customFunctionOnSend,
--  remoteFunction = customFunctionOnRecieve
--},
-- storeState stores the incoming data and then if the remote car was reset for whatever reason it reapplies the state

local includedControllerTypes = {

	["rollover"] = {
		["cycle"] = {
			compare = false
			},
		["prepare"] = {
			compare = false
			}
	},

	["spinner"] = {
		["toggleDirection"] = {
			ownerFunction = toggleDirection,
			remoteFunction = recieveToggleDirection,
			storeState = true
		}
	},

	["pneumatics"] = {
		["setBeamMin"] = {
			compare = false
			},
		["setBeamMax"] = {
			compare = false
			},
		["setBeamPressure"] = {
			compare = false
			},
		["setBeamPressureLevel"] = {
			compare = false
			},
		["toggleBeamMinMax"] = {
			compare = false
			},
		["setBeamMomentaryIncrease"] = {
			compare = false
			},
		["setBeamMomentaryDecrease"] = {
			compare = false
			},
		["setBeamDefault"] = {
			compare = false
			}
	},

	["pneumatics/autoLevelSuspension"] = {
		["toggleDump"] = {
			compare = false
			},
		["setDump"] = {
			compare = false
			},
		["toggleMaxHeight"] = {
			compare = false
			},
		["setMaxHeight"] = {
			compare = false
			},
		["setMomentaryIncrease"] = {
			compare = false
			},
		["setMomentaryDecrease"] = {
			compare = false
			}
	},

	["hydraulicSuspension"] = {
		["setGroupsPosition"] = {
			compare = false
			},
		["setGroupsBleed"] = {
			compare = false
			},
		["setGroupsMomentaryIncrease"] = {
			compare = false
			}
	},

	["tirePressureControl"] = {
		["toggleGroupState"] = {
			compare = false
			},
		["startInflateActiveGroups"] = {
			compare = false
			},
		["startDeflateActiveGroups"] = {
			compare = false
			},
		["setGroupsMomentaryIncrease"] = {
			compare = false
			},
		["stopActiveGroups"] = {
			compare = false
			},
	},

	["hydraulics/hydraulicsCombustionEngineControl"] = {
		["toggleIdleRaise"] = {
			ownerFunction = toggleIdleRaise
		},
		["setIdleRaise"] = {
			ownerFunction = setIdleRaise,
			remoteFunction = setIdleRaiseRecieve,
			storeState = true
		}
	},

	["hydraulics/hydraulicTrailerFeet"] = {
		["moveFeet"] = {
			compare = false
			}
	},

	["twoStepLaunch"] = {
		["setTwoStep"] = {
			compare = false
			},
		["toggleTwoStep"] = {
			compare = false
			},
		["changeTwoStepRPM"] = {
			compare = false
			},
		["setParameters"] = {
			compare = true
			}
	},
}

local function onReset()
	-- "hydraulics/hydraulicsCombustionEngineControl" --
	manualIdleRaise = false
end

local function loadFunctions()
	if controllerSyncVE ~= nil then
		controllerSyncVE.addControllerTypes(includedControllerTypes)
	else
		dump("controllerSyncVE not found")
	end
end

M.loadFunctions = loadFunctions
M.onReset = onReset

return M
