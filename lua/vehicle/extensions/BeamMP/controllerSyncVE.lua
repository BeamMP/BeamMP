-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

local controllers = controller:getAllControllers()

local OGcontrollerFunctionsTable = {}
local ownerFunctionsTable = {}
local remoteFunctionsTable = {}

local controllerState = {}

local ownerReset

local function sendControllerData(tempTable) -- using nodesGE temporarely until launcher and server supports the new packet
	--obj:queueGameEngineLua("MPControllerGE.sendControllerData(\'" .. jsonEncode(tempTable) .. "\', " .. obj:getID() ..")") -- Send it to GE lua
	obj:queueGameEngineLua("nodesGE.sendControllerData(\'" .. jsonEncode(tempTable) .. "\', " .. obj:getID() ..")") -- Send it to GE lua
end

local function storeState(controllerName, funcName, ...)
	if not (controllerName or funcName) then return end
	if not controllerState[controllerName] then
		controllerState[controllerName] = {}
	end
	controllerState[controllerName][funcName] = ...
end

local function applyControllerData(data)
	local decodedData = jsonDecode(data)

	--dump("applyControllerData",decodedData) --TODO for debugging, remove when controllersync is getting released

	if decodedData.ownerReset then
		ownerReset = true
	end
	if decodedData.controllerName then
		if decodedData.functionName == "setCameraControlData" then --TODO change this to a universal system, maybe by storing what type of data it was?
			decodedData.variables[1].cameraRotation = quat(decodedData.variables[1].cameraRotation.x,
				decodedData.variables[1].cameraRotation.y,
				decodedData.variables[1].cameraRotation.z, decodedData.variables[1].cameraRotation.w)
		end
		if decodedData.customFunction then
			if remoteFunctionsTable[decodedData.controllerName] then
				remoteFunctionsTable[decodedData.controllerName][decodedData.functionName](decodedData)
			end
		else
			if OGcontrollerFunctionsTable[decodedData.controllerName] then
				if unpack(decodedData.variables) ~= nil then
					OGcontrollerFunctionsTable[decodedData.controllerName][decodedData.functionName](unpack(decodedData.variables))
				else
					OGcontrollerFunctionsTable[decodedData.controllerName][decodedData.functionName](decodedData.variables)
				end
			end
		end
		if decodedData.storeState then
			if unpack(decodedData.variables) ~= nil then
				storeState(decodedData.controllerName, decodedData.functionName, unpack(decodedData.variables))
			else
				storeState(decodedData.controllerName, decodedData.functionName, decodedData.variables)
			end
		end
	end
end

-- Custom functions

--spinner

local function toggleDirection(controllerName, funcName, tempTable, ...)
	local motor = powertrain.getDevice("motor")
	motor.motorDirection = motor.motorDirection * -1
	if tempTable.storeState then
		storeState(controllerName, funcName, motor.motorDirection)
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

local lastData = {}
local cachedData = {}

local function cacheState(tempTable)
	if not (tempTable.controllerName or tempTable.functionName) then return end
	if not cachedData[tempTable.controllerName] then
		cachedData[tempTable.controllerName] = {}
	end
	if not cachedData[tempTable.controllerName][tempTable.functionName] then
		cachedData[tempTable.controllerName][tempTable.functionName] = {}
	end
	cachedData[tempTable.controllerName][tempTable.functionName]["variables"] = tempTable.variables
	cachedData[tempTable.controllerName][tempTable.functionName]["storeState"] = tempTable.storeState
	cachedData[tempTable.controllerName][tempTable.functionName]["customFunction"] = tempTable.customFunction
end

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
	if ... ~= nil or lastData[funcName] ~= nil then
		if not lastData[funcName] and ... ~= nil then
			lastData[funcName] = ...
			send = true
		elseif type(...) == "table" then
			if compareTable(..., lastData[funcName]) == true then
				send = true
			end
		elseif type(...) == "number" or ... ~= nil then
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
		for funcName, data in pairs(functions) do
			local customFunction
			tempOGcontrollerFunctions[funcName] = tempController[funcName]
			if data.ownerFunction then
				tempOwnerController[funcName] = data.ownerFunction
			end
			if data.remoteFunction then
				tempRemoteController[funcName] = data.remoteFunction
				customFunction = true
			end
			if data.storeState then
				if not controllerState[controllerName] then
					controllerState[controllerName] = {}
				end
				controllerState[controllerName][funcName] = nil
			end

			local function newfunction(...)
				if v.mpVehicleType == "R" then
					-- leaving this blank disables the functions on the remote car which will prevent ghost controlling,

					-- this could also be used for requesting actions if we can send data back to the vehicle owner in the future,
					-- which can for example make it possible for others to open your car doors
				else
					local tempTable = {
						controllerName = controllerName,
						functionName = funcName,
						customFunction = customFunction,
						storeState = data.storeState,
						variables = { ... }
					}
					if data.ownerFunction or data.remoteFunction then
						return data.ownerFunction(controllerName, funcName, tempTable, ...)
					elseif data.compare then
						if data.storeState then
							storeState(controllerName, funcName, ...)
						end
						cacheState(tempTable)
						return OGcontrollerFunctionsTable[controllerName][funcName](...)

					elseif not data.compare then
						if data.storeState then
							storeState(controllerName, funcName, ...)
						end
						sendControllerData(tempTable)
						return OGcontrollerFunctionsTable[controllerName][funcName](...)
					end
				end
			end

			controller.getControllerSafe(controllerName)[funcName] = newfunction
		end
		OGcontrollerFunctionsTable[controllerName] = tempOGcontrollerFunctions
		ownerFunctionsTable[controllerName] = tempOwnerController
		remoteFunctionsTable[controllerName] = tempRemoteController
	end
	--dump("replaceFunctions",controllerName,OGcontrollerFunctionsTable[controllerName]) --TODO for debugging, remove when controllersync is getting released
end

local function checkIncludedControllers()
	for controllerType, functions in pairs(includedControllerTypes) do
		for _, data in pairs(controller.getControllersByType(controllerType)) do
			replaceFunctions(data.name, functions)
		end
	end
end

checkIncludedControllers()

local function addControllerTypes(controllerTypes) -- allows modders to add their own controller functions
	for controllerType, functions in pairs(controllerTypes) do
		for _, data in pairs(controller.getControllersByType(controllerType)) do
			if not OGcontrollerFunctionsTable[data.name] then
				replaceFunctions(data.name, functions)
				--dump(controller.getControllersByType(controllerType),functions)  --TODO for debugging, remove when controllersync is getting released
			end
		end
	end
end

local framesSinceReset = 0

local function onReset()
	lastData = {}

	-- "hydraulics/hydraulicsCombustionEngineControl" --
	manualIdleRaise = false

	if v.mpVehicleType == "L" then
		local tempTable = {ownerReset = true}
		sendControllerData(tempTable) -- Send it to GE lua
	end

	framesSinceReset = 0
end

local function applyLastState()
	for controllerName,data in pairs(controllerState) do
		for funcName,var in pairs(data) do
			if remoteFunctionsTable[controllerName] and remoteFunctionsTable[controllerName][funcName] then
				local tempTable = {
					controllerName = controllerName,
					functionName = funcName,
					variables = {var}
				}
				remoteFunctionsTable[controllerName][funcName](tempTable)
			else
				OGcontrollerFunctionsTable[controllerName][funcName](var)
			end
		end
	end
end

local function getControllerData()
	if not cachedData then return end
	for controllerName, controllers in pairs(cachedData) do
		for functionName , functionData in pairs(controllers) do
			if universalCompare(functionName, functionData.variables[1]) == true then
				local tempTable = {
					controllerName = controllerName,
					functionName = functionName,
					customFunction = functionData.customFunction,
					storeState = functionData.storeState,
					variables = functionData.variables
				}
				sendControllerData(tempTable)
			end
		end
	end
end

local hookExstensions

local function updateGFX(dt)
	if not hookExstensions then
		extensions.hook("loadFunctions") -- for some reason controllerSyncVE.lua doesn't exist for the other extensions when calling the hook with onExtensionLoaded
	end
	-- here im resyncing function states after the remote vehicle was reset
	if framesSinceReset == 1 then -- we have to wait one frame so the controller's reset function don't override the state again
		if v.mpVehicleType == "R" then
			if ownerReset then -- if the owner has reset the vehicle assume the state is already the same
				ownerReset = false
				controllerState = {}
			else
				applyLastState()
			end
		end
	end
	framesSinceReset = framesSinceReset + 1
end

M.OGcontrollerFunctionsTable = OGcontrollerFunctionsTable
M.universalCompare = universalCompare
M.cacheState = cacheState
M.getControllerData = getControllerData
M.sendControllerData = sendControllerData
M.applyControllerData = applyControllerData
M.addControllerTypes = addControllerTypes
M.storeState = storeState
M.onReset = onReset
M.updateGFX = updateGFX

return M
