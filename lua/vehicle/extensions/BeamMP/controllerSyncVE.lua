-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

local controllers = controller:getAllControllers()

local OGcontrollerFunctionsTable = {}
local receiveFunctionsTable = {}

local includedControllers =  {}

local controllerState = {}
local cachedData = {}
local lastData = {}
local ownerReset

local framesSinceReset = 0
local hookExstensions

local function sendControllerData(tempTable) -- using nodesGE temporarely until launcher and server supports the new packet
	--obj:queueGameEngineLua("MPControllerGE.sendControllerData(\'" .. jsonEncode(tempTable) .. "\', " .. obj:getID() ..")") -- Send it to GE lua
	obj:queueGameEngineLua("nodesGE.sendControllerData(\'" .. jsonEncode(tempTable) .. "\', " .. obj:getID() ..")") -- Send it to GE lua
end

local function mergeTable(tempTable , table)
	if not (tempTable.controllerName or tempTable.functionName) then return end
	if not table[tempTable.controllerName] then
		table[tempTable.controllerName] = {}
	end
	if not table[tempTable.controllerName][tempTable.functionName] then
		table[tempTable.controllerName][tempTable.functionName] = {}
	end
	table[tempTable.controllerName][tempTable.functionName] = tempTable
end

local function storeState(tempTable)
	mergeTable(tempTable,controllerState)
end

local function cacheState(tempTable)
	mergeTable(tempTable,cachedData)
end

local function applyControllerData(data,isDecoded)
	M.isOnControllerSync = true
	local decodedData = data
	if not isDecoded then
		decodedData = jsonDecode(data)
	end
	local shouldBeUnpacked = false

	if decodedData.controllerName then
		--dump("applyControllerData",decodedData) --TODO for debugging, remove when controllersync is getting released

		local variables = decodedData.variables
		if type(variables) == "table" and unpack(variables) ~= nil then
			shouldBeUnpacked = true
		end
		if decodedData.functionName == "setCameraControlData" then --TODO change this to a universal system, maybe by storing what type of data it was?
			variables[1].cameraRotation = quat(
				variables[1].cameraRotation.x,
				variables[1].cameraRotation.y,
				variables[1].cameraRotation.z,
				variables[1].cameraRotation.w
			)
		end
		if receiveFunctionsTable[decodedData.controllerName] and receiveFunctionsTable[decodedData.controllerName][decodedData.functionName] then
			receiveFunctionsTable[decodedData.controllerName][decodedData.functionName](decodedData)

		elseif OGcontrollerFunctionsTable[decodedData.controllerName] and OGcontrollerFunctionsTable[decodedData.controllerName][decodedData.functionName] then
			if shouldBeUnpacked then
				OGcontrollerFunctionsTable[decodedData.controllerName][decodedData.functionName](unpack(variables))
			else
				OGcontrollerFunctionsTable[decodedData.controllerName][decodedData.functionName](variables)
			end
		end
		if includedControllers[decodedData.controllerName] and
			includedControllers[decodedData.controllerName][decodedData.functionName] and
			includedControllers[decodedData.controllerName][decodedData.functionName].storeState then
			storeState(decodedData)
		end
	end
end

local function compareTable(table, gamestateTable)
	local send = false
	for variableName, value in pairs(table) do
		if type(value) == "table" then
			send = compareTable(value, gamestateTable[variableName])
		elseif type(value) == "cdata" then --TODO find out if cdata can contain other things than x,y,z,w
			if value.x ~= gamestateTable[variableName].x or
				value.y ~= gamestateTable[variableName].y or
				value.z ~= gamestateTable[variableName].z or
				value.w ~= gamestateTable[variableName].w then
				send = true
			end
		elseif value ~= gamestateTable[variableName] then
			send = true
		end
	end
	return send
end

local function universalCompare(funcName, ...)
	local send = false
	if ... ~= nil or lastData[funcName] ~= nil then
		if not lastData[funcName] and ... ~= nil then
			lastData[funcName] = ...
			send = true
		elseif type(...) == "table" then
			if compareTable(..., lastData[funcName]) then
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
		local tempRemoteController = {}
		for funcName, data in pairs(functions) do
			tempOGcontrollerFunctions[funcName] = tempController[funcName]
			if data.receiveFunction then
				tempRemoteController[funcName] = data.receiveFunction
			end

			local function newfunction(...)
				local tempTable = {
					controllerName = controllerName,
					functionName = funcName,
					variables = { ... }
				}
				if v.mpVehicleType == "R" then
					-- leaving this blank disables the functions on the remote car which will prevent ghost controlling,
					-- this could also be used for requesting actions if we can send data back to the vehicle owner in the future,
					-- which can for example make it possible for others to open your car doors

					if data.remoteFunction then
						return data.remoteFunction(controllerName, funcName, tempTable, ...)
					end
				else
					if data.ownerFunction then
						return data.ownerFunction(controllerName, funcName, tempTable, ...)
					else
						if data.compare then
							cacheState(tempTable)
						else
							sendControllerData(tempTable)
						end
						return OGcontrollerFunctionsTable[controllerName][funcName](...)
					end
				end
			end
			if not data.remoteOnly or data.remoteOnly and v.mpVehicleType == "R" then
				controller.getControllerSafe(controllerName)[funcName] = newfunction
			end
		end
		OGcontrollerFunctionsTable[controllerName] = tempOGcontrollerFunctions
		receiveFunctionsTable[controllerName] = tempRemoteController
	end
	--dump("replaceFunctions",controllerName,OGcontrollerFunctionsTable[controllerName]) --TODO for debugging, remove when controllersync is getting released
end

local function addControllerTypes(controllerTypes)
	for controllerType, functions in pairs(controllerTypes) do
		for _, data in pairs(controller.getControllersByType(controllerType)) do
			if not OGcontrollerFunctionsTable[data.name] then
				if not includedControllers[data.name] then
					includedControllers[data.name] = functions
				end
				replaceFunctions(data.name, functions)
				--dump(controller.getControllersByType(controllerType),functions)  --TODO for debugging, remove when controllersync is getting released
			end
		end
	end
end

local function applyLastState()
	for _,functions in pairs(controllerState) do
		for _,functionData in pairs(functions) do
			applyControllerData(functionData,true)
		end
	end
end

local function getControllerData()
	if not cachedData then return end
	for controllerName, functions in pairs(cachedData) do
		for functionName , functionData in pairs(functions) do
			if universalCompare(functionName, functionData.variables) then
				local tempTable = {
					controllerName = controllerName,
					functionName = functionName,
					variables = functionData.variables
				}
				sendControllerData(tempTable)
			end
		end
	end
end

local function updateGFX(dt)
	if not hookExstensions then
		hookExstensions = true
		extensions.hook("loadControllerSyncFunctions") -- controllerSyncVE.lua doesn't exist for the other extensions when calling the hook with onExtensionLoaded
		controller.cacheAllControllerFunctions() -- recache functions to make UpdateGFX hooks work
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

local function onReset()
	lastData = {}
	framesSinceReset = 0
end

local function onBeamMPVehicleReset()
	ownerReset = true
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
M.onBeamMPVehicleReset = onBeamMPVehicleReset
M.updateGFX = updateGFX

return M
