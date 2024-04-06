-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

local controllers = controller:getAllControllers()

local OGcontrollerFunctionsTable = {}

local ownerFunctionsTable = {}
local remoteFunctionsTable = {}

local function applyControllerData(data)
	local save = jsonDecode(data)

	dump(save) --TODO for debugging, remove when controllersync is getting released

	if save.controllerName then
		if save.functionName == "setCameraControlData" then --TODO change this to a universal system, maybe by storing what type of data it was?
			save.variables[1].cameraRotation = quat(save.variables[1].cameraRotation.x,
				save.variables[1].cameraRotation.y,
				save.variables[1].cameraRotation.z, save.variables[1].cameraRotation.w)
		end
		if save.customFunction then
			if remoteFunctionsTable[save.controllerName] then
				remoteFunctionsTable[save.controllerName][save.functionName](save)
			end
		else
			if OGcontrollerFunctionsTable[save.controllerName] then
				OGcontrollerFunctionsTable[save.controllerName][save.functionName](unpack(save.variables))
			end
		end
	end
end

-- playeController
-- the regular toggle will desync if player is crouching as the unicycle is spawned,
-- this fixes that by using the global crouch function instead of the local one
local isCrouching = false
local function customtogglecrouch()
	if electrics.values.freezeState then
		return
	end

	isCrouching = not isCrouching
	controller.getControllerSafe("playerController").crouch(isCrouching and -1 or 1)
end


local function couplerToggleCheck(controllerName, funcName, tempTable, ...)
	local groupState = controller.getControllerSafe(controllerName).getGroupState()
	tempTable.variables = {groupState = groupState}
	obj:queueGameEngineLua("nodesGE.sendControllerData(\'" .. jsonEncode(tempTable) .. "\', " .. obj:getID() .. ")") -- Send it to GE lua

	OGcontrollerFunctionsTable[controllerName][funcName](...)
end

local function couplerToggleRecieve(data)
	if v.mpVehicleType == "R" then
		if controller.getControllerSafe(data.controllerName).getGroupState() == data.variables.groupState then
			OGcontrollerFunctionsTable[data.controllerName][data.functionName]()
		end
	end
end

local function customToggleGroupConditional(controllerName, funcName, tempTable, ...) --disabled because recieveToggleGroupConditional need more work
	OGcontrollerFunctionsTable[controllerName][funcName](...)

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

	obj:queueGameEngineLua("nodesGE.sendControllerData(\'" .. jsonEncode(tempTable) .. "\', " .. obj:getID() .. ")") -- Send it to GE lua
	--dump((...))
	----(...)[1][2] = "test"
	--dump(controller.getControllerSafe((...)[1][1]).getGroupState())
	--if controller.getControllerSafe((...)[1][1]).getGroupState() == "attached" then
	--  OGcontrollerFunctionsTable[(...)[1][1]].detachGroup()
	--  OGcontrollerFunctionsTable[controllerName].detachGroup()
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
				OGcontrollerFunctionsTable[controllerName].toggleGroup()
			end
		end
	end
	if controller.getControllerSafe(data.controllerName).getGroupState() == data.variables.groupState then
		OGcontrollerFunctionsTable[data.controllerName][data.functionName](data.variables.conditions)
	end
end

-- 1 only sends data when there is a change
-- 2 sends the data every time the function is called
-- alternativly using a table with ownerFunction and remoteFunction can set custom functions to read or change data before sending or on recieveing
--["controllerFunctionName"] = {
--  ownerFunction = customFunctionOnSend,
--  remoteFunction = customFunctionOnRecieve
--},

local includedControllerTypes = {

	["playerController"] = {
		["setCameraControlData"] = 1,
		["jump"] = 2,
		["walkLeftRightRaw"] = 1,
		["walkLeftRight"] = 2,
		["walkUpDownRaw"] = 1,
		["walkUpDown"] = 2,
		["setSpeedCoef"] = 1,
		["toggleSpeedCoef"] = 2,
		["crouch"] = 1,
		["toggleCrouch"] = {
			ownerFunction = customtogglecrouch
		},
	},

	["rollover"] = {
		["cycle"] = 2,
		["prepare"] = 2
	},

	["spinner"] = {
		["toggleDirection"] = 2
	},

	["advancedCouplerControl"] = {
		["toggleGroup"] = {
			ownerFunction = couplerToggleCheck,
			remoteFunction = couplerToggleRecieve
		},
		["toggleGroupConditional"] = 2, --{ --disabled custom functions because recieveToggleGroupConditional doesn't work yet
		--  ownerFunction = customToggleGroupConditional,
		--  remoteFunction = recieveToggleGroupConditional
		--},
		["tryAttachGroupImpulse"] = 2,
		["detachGroup"] = 2,
	},

	["pneumatics"] = {
		["setBeamMin"] = 2,
		["setBeamMax"] = 2,
		["setBeamPressure"] = 2,
		["setBeamPressureLevel"] = 2,
		["toggleBeamMinMax"] = 2,
		["setBeamMomentaryIncrease"] = 2,
		["setBeamMomentaryDecrease"] = 2,
		["setBeamDefault"] = 2
	},

	["hydraulicSuspension"] = {
		["setGroupsPosition"] = 2,
		["setGroupsBleed"] = 2,
		["setGroupsMomentaryIncrease"] = 2
	},

	["tirePressureControl"] = {
		["toggleGroupState"] = 2,
		["startInflateActiveGroups"] = 2,
		["startDeflateActiveGroups"] = 2,
		["setGroupsMomentaryIncrease"] = 2,
		["stopActiveGroups"] = 2,
	},

	["hydraulics/hydraulicsCombustionEngineControl"] = {
		["toggleIdleRaise"] = 2,
		["setIdleRaise"] = 2
	},

	["hydraulics/hydraulicTrailerFeet"] = {
		["moveFeet"] = 2
	},

	["twoStepLaunch"] = {
		["setTwoStep"] = 2,
		["toggleTwoStep"] = 2,
		["changeTwoStepRPM"] = 2,
		["setParameters"] = 1
	},
}

local lastData = {}

local function compareTable(table, gamestateTable)
	for variableName, value in pairs(table) do
		if type(value) == "table" then
			compareTable(value, gamestateTable[variableName])
		elseif type(value) == "cdata" then --TODO find out if cdata can contain other things than x,y,z,w
			if value.x ~= gamestateTable[variableName].x or
				value.y ~= gamestateTable[variableName].y or
				value.z ~= gamestateTable[variableName].z or
				value.w ~= gamestateTable[variableName].w then
				return true
			end
		elseif value ~= gamestateTable[variableName] then
			return true
		end
	end
	return false
end

local function universalCompare(funcName, ...)
	local send = false
	if ... ~= nil then
		if not lastData[funcName] then
			lastData[funcName] = ...
			send = true
		elseif type(...) == "table" then
			if compareTable(..., lastData[funcName]) == true then
				send = true
			end
		elseif type(...) == "number" then
			if ... ~= lastData[funcName] then
				lastData[funcName] = ...
				send = true
			end
		end
		lastData[funcName] = ...
	end
	return send
end

local function replaceFunctions(controllerName, functions)
	local tempController = controllers[controllerName]
	if tempController then
		local tempOGcontrollerFunctions = {}
		local tempOwnerController = {}
		local tempRemoteController = {}
		for funcName, checkingtype in pairs(functions) do
			local customFunction = false
			tempOGcontrollerFunctions[funcName] = tempController[funcName]
			if type(checkingtype) == "table" then
				if checkingtype.ownerFunction then
					tempOwnerController[funcName] = checkingtype.ownerFunction
				end
				if checkingtype.remoteFunction then
					tempRemoteController[funcName] = checkingtype.remoteFunction
					customFunction = true
				end
			end

			local function newfunction(...)
				local tempTable = {
					controllerName = controllerName,
					functionName = funcName,
					customFunction = customFunction,
					variables = { ... }
				}
				if v.mpVehicleType == "R" then
					-- leaving this blank disables the functions on the remote car which will prevent ghost controlling,

					-- this could also be used for requesting actions if we can send data back to the vehicle owner in the future,
					-- which can for example make it possible for others to open your car doors
				else
					if checkingtype == 1 then
						if universalCompare(funcName, ...) == true then
							obj:queueGameEngineLua("nodesGE.sendControllerData(\'" .. jsonEncode(tempTable) .. "\', " ..obj:getID() .. ")") -- Send it to GE lua
						end
						return OGcontrollerFunctionsTable[controllerName][funcName](...)

					elseif checkingtype == 2 then
						obj:queueGameEngineLua("nodesGE.sendControllerData(\'" .. jsonEncode(tempTable) .. "\', " .. obj:getID() ..")") -- Send it to GE lua
						return OGcontrollerFunctionsTable[controllerName][funcName](...)

					elseif type(checkingtype) == "table" then
						return checkingtype.ownerFunction(controllerName, funcName, tempTable, ...)

					end
				end
			end
			controller.getControllerSafe(controllerName)[funcName] = newfunction
		end
		OGcontrollerFunctionsTable[controllerName] = tempOGcontrollerFunctions
		ownerFunctionsTable[controllerName] = tempOwnerController
		remoteFunctionsTable[controllerName] = tempRemoteController
	end
	dump(OGcontrollerFunctionsTable[controllerName]) --TODO for debugging, remove when controllersync is getting released
end

local function checkIncludedControllers()
	for controllerType, functions in pairs(includedControllerTypes) do
		for _, data in pairs(controller.getControllersByType(controllerType)) do
			replaceFunctions(data.name, functions)
		end
	end
end

checkIncludedControllers()

local function reset()
	-- playerController --
	isCrouching = false
end

local function addControllerTypes(controllerTypes) -- allows modders to add their own controller functions
	for controllerType, functions in pairs(controllerTypes) do
		for _, data in pairs(controller.getControllersByType(controllerType)) do
			if not OGcontrollerFunctionsTable[data.name] then
				replaceFunctions(data.name, functions)
				dump(controller.getControllersByType(controllerType),functions)  --TODO for debugging, remove when controllersync is getting released
			end
		end
	end
end

M.OGcontrollerFunctionsTable = OGcontrollerFunctionsTable
M.applyControllerData = applyControllerData
M.addControllerTypes = addControllerTypes
M.reset = reset

return M
