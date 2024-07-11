-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

-- Couplers

local function couplerToggleCheck(controllerName, funcName, tempTable, ...)
	local groupState = controller.getControllerSafe(controllerName).getGroupState()
	tempTable.variables = {groupState = groupState}
	controllerSyncVE.sendControllerData(tempTable)

	controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
end

local function couplerToggleReceive(data)
	if v.mpVehicleType == "R" then
		if controller.getControllerSafe(data.controllerName).getGroupState() == data.variables.groupState then
			controllerSyncVE.OGcontrollerFunctionsTable[data.controllerName][data.functionName]()
		end
	end
end

local includedControllerTypes = {
	["advancedCouplerControl"] = {
		["toggleGroup"] = {
			ownerFunction = couplerToggleCheck,
			receiveFunction = couplerToggleReceive,
		},
		["toggleGroupConditional"] = {},
		["tryAttachGroupImpulse"] = {},
		["detachGroup"] = {},
	},
}

local function loadFunctions()
	if controllerSyncVE ~= nil then
		controllerSyncVE.addControllerTypes(includedControllerTypes)
	else
		dump("controllerSyncVE not found")
	end
end

M.loadControllerSyncFunctions = loadFunctions

return M
