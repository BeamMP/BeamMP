-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

local floor = math.floor

local function toggleBeamMinMax(controllerName, funcName, tempTable, ...)
	for _,group in pairs(...) do
		local pressure = controller.getController(controllerName).isBeamGroupAtPressureLevel(group, "minPressure")
		if pressure then
			controller.getController(controllerName).setBeamMax({group})
		else
			controller.getController(controllerName).setBeamMin({group})
		end
	end
end

--pneumatics/actuators
local beamGroups = {}
local beamGroupsToSend = {}

local function setBeamGroupValveState(controllerName, funcName, tempTable, ...)
	local groupName , valveState = ...
	local flooredvalveState = floor(valveState * 10) / 10
	if not beamGroups[groupName] or beamGroups[groupName] ~= flooredvalveState then
		beamGroups[groupName] = flooredvalveState
		if not beamGroupsToSend[groupName] then
			beamGroupsToSend[groupName] = tempTable
		end
		beamGroupsToSend[groupName].variables[2] = flooredvalveState
	end
	controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
end

local function setBeamGroupsValveState(controllerName, funcName, tempTable, ...)
	local beamGroup, valveState = ...
	for _, g in pairs(beamGroup) do
		controller.getController(controllerName).setBeamGroupValveState(g, valveState)
	end
end

local function toggleBeamGroupValveState(controllerName, funcName, tempTable, ...)
	local currentValveState = controller.getController(controllerName).getValveState(...)
	local valveState = currentValveState < 0 and 1 or -1
	controller.getController(controllerName).setBeamGroupValveState(...,valveState)
end

local function toggleBeamGroupsValveState(controllerName, funcName, tempTable, ...)
	for _,groupName in pairs(...) do
		toggleBeamGroupValveState(controllerName, funcName, tempTable, groupName)
	end
end

local includedControllerTypes = {
	["pneumatics"] = {
		["setBeamMin"] = {},
		["setBeamMax"] = {},
		["setBeamPressure"] = {},
		["setBeamPressureLevel"] = {},
		["toggleBeamMinMax"] = {
			ownerFunction = toggleBeamMinMax
		},
		["setBeamMomentaryIncrease"] = {},
		["setBeamMomentaryDecrease"] = {},
		["setBeamDefault"] = {}
	},

	["pneumatics/autoLevelSuspension"] = {
		["toggleDump"] = {},
		["setDump"] = {},
		["toggleMaxHeight"] = {},
		["setMaxHeight"] = {},
		["setMomentaryIncrease"] = {},
		["setMomentaryDecrease"] = {},
		["setAdjustmentRate"] = {},
		["stopAdjusting"] = {}
	},

	["pneumatics/actuators"] = {
		["setBeamGroupValveState"] = {
			ownerFunction = setBeamGroupValveState
		},
		["toggleBeamGroupValveState"] = {
			ownerFunction = toggleBeamMinMax
		},
		["setBeamGroupsValveState"] = {
			ownerFunction = setBeamGroupsValveState
		},
		["toggleBeamGroupsValveState"] = {
			ownerFunction = toggleBeamGroupsValveState
		}
	},
}

local function getBeamMPControllerData()
	for groupName, groupData in pairs(beamGroupsToSend) do
		controllerSyncVE.sendControllerData(groupData)
		beamGroupsToSend[groupName] = nil
	end
end

local function loadFunctions()
	if controllerSyncVE ~= nil then
		controllerSyncVE.addControllerTypes(includedControllerTypes)
	else
		dump("controllerSyncVE not found")
	end
end

local function onReset()
	beamGroups = {}
end

M.onBeamMPLoadControllerSyncFunctions = loadFunctions
M.getBeamMPControllerData = getBeamMPControllerData
M.onReset = onReset

return M
