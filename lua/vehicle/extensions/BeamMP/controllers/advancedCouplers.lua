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

local function couplerToggleRecieve(data)
	if v.mpVehicleType == "R" then
		if controller.getControllerSafe(data.controllerName).getGroupState() == data.variables.groupState then
			controllerSyncVE.OGcontrollerFunctionsTable[data.controllerName][data.functionName]()
		end
	end
end

local function customToggleGroupConditional(controllerName, funcName, tempTable, ...) --disabled because recieveToggleGroupConditional need more work
	controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)

	for _, c in ipairs(...) do
		if #c < 2 then
			--log("E", "advancedCouplerControl.toggleGroupConditional", "Wrong amount of data for condition, expected 2:")
			--log("E", "advancedCouplerControl.toggleGroupConditional", dumps(c))
			return
		end
		local controllerName = c[1]
		local nonAllowedState = c[2]
		local errorMessage = c[3]
		if not controllerName or not nonAllowedState then
			--log("E", "advancedCouplerControl.toggleGroupConditional", string.format("Wrong condition data, groupName: %q, nonAllowedState: %q", controllerName, nonAllowedState))
			return
		end
		local groupController = controller.getController(controllerName)
		if not groupController or groupController.typeName ~= "advancedCouplerControl" then
			--log("D", "advancedCouplerControl.toggleGroupConditional", string.format("Can't find group controller with name %q or it's the wrong type", controllerName))
		end
		if groupController and groupController.typeName == "advancedCouplerControl" then
			local groupState = groupController.getGroupState()
			if groupState == nonAllowedState then
				-- group is in wrong state, don't continue
				--guihooks.message(errorMessage, 5, "vehicle.advancedCouplerControl." .. controllerName .. nonAllowedState .. errorMessage)
				return
			end
		end
	end

	local groupState = controller.getControllerSafe(controllerName).getGroupState()
	tempTable.variables = { groupState = groupState, conditions = ... }

	controllerSyncVE.sendControllerData(tempTable)
	--dump((...))
	----(...)[1][2] = "test"
	--dump(controller.getControllerSafe((...)[1][1]).getGroupState())
	--if controller.getControllerSafe((...)[1][1]).getGroupState() == "attached" then
	--  controllerSyncVE.OGcontrollerFunctionsTable[(...)[1][1]].detachGroup()
	--  controllerSyncVE.OGcontrollerFunctionsTable[controllerName].detachGroup()
	--end
	--dump(controller.getControllerSafe(controllerName).getGroupState())
end

local function recieveToggleGroupConditional(data) -- TODO make this work, disabled for now -- i regret this comment, i don't remember why it doesn't work now
	dump(data)
	local conditions = data.variables.conditions
	if not conditions then return end
	for _, c in ipairs(data.variables.conditions) do
		if #c < 2 then
			--log("E", "advancedCouplerControl.toggleGroupConditional", "Wrong amount of data for condition, expected 2:")
			--log("E", "advancedCouplerControl.toggleGroupConditional", dumps(c))
			return
		end
		local controllerName = c[1]
		local nonAllowedState = c[2]

		local groupController = controller.getController(controllerName)

		if groupController and groupController.typeName == "advancedCouplerControl" then
			local groupState = groupController.getGroupState()
			if groupState == nonAllowedState then
				dump("foundwrongstate toggling", groupController.getGroupState(), controllerName)
				controllerSyncVE.OGcontrollerFunctionsTable[controllerName].toggleGroup()
			end
		end
	end
	if controller.getControllerSafe(data.controllerName).getGroupState() == data.variables.groupState then
		controllerSyncVE.OGcontrollerFunctionsTable[data.controllerName][data.functionName](data.variables.conditions)
	end
end

local includedControllerTypes = {
	["advancedCouplerControl"] = {
		["toggleGroup"] = {
			ownerFunction = couplerToggleCheck,
			remoteFunction = couplerToggleRecieve,
		},
		["toggleGroupConditional"] = {
			compare = false
			}, --{ --disabled custom functions because recieveToggleGroupConditional doesn't work yet
		--  ownerFunction = customToggleGroupConditional,
		--  remoteFunction = recieveToggleGroupConditional
		--},
		["tryAttachGroupImpulse"] = {
			compare = false,
			},
		["detachGroup"] = {
			compare = false,
			},
	},
}

local function loadFunctions()
	if controllerSyncVE ~= nil then
		controllerSyncVE.addControllerTypes(includedControllerTypes)
	else
		dump("controllerSyncVE not found")
	end
end

M.loadFunctions = loadFunctions

return M
