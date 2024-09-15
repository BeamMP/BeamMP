-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

-- compare set to true only sends data when there is a change
-- compare set to false sends the data every time the function is called
-- storeState stores the incoming data and then if the remote car was reset for whatever reason it reapplies the state
-- adding ownerFunction and/or receiveFunction can set custom functions to read or change data before sending or on receiveing

--example
--[[
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

["controllerFunctionName"] = {
  ownerFunction = couplerToggleCheck,
  receiveFunction = couplerToggleReceive
},
]]

local lastvehID = 0

local aimMode = "auto"

local function prepairID(controllerName, funcName, tempTable, ...)
	local vehID = tempTable.variables[1]
	if vehID or lastvehID then -- the Phulcan spams the setTargetID in auto mode, but just comparing to last can break normal targeting, and we still need to send an empty table once, so instead I'm checking if either is true
		if vehID then
			-- syncing targeting missiles, missiles have the vehicleID of the original vehicle but with it's own id added at the end
			-- this system checks if removing two numbers make it match with a vehicle, if it does then we know that this is the vehicle it belongs too,
			-- if not then we try removing just one number and check again, it has to be done in this order or id 11 will mistake the missile with id 1 as being it's vehicle
			-- thanks Stefan750 for helping me figure out this system
			local mapObjects = mapmgr.getObjects() or {}
			local flooredID100 = math.floor((vehID/100))
			local found = false
			for k,_ in pairs(mapObjects) do
				if k == flooredID100 then
					tempTable.missileID = vehID - (k*100)
					vehID = flooredID100
					found = true
				end
			end
			local flooredID10 = math.floor((vehID/10))
			if not found then -- if we already found a matching id we skip this loop
				for k,_ in pairs(mapObjects) do
					if k == flooredID10 then
						tempTable.missileID = vehID - (k*10)
						vehID = flooredID10
					end
				end
			end
		end
		tempTable["vehID"] = vehID -- store vehicleID separately so we can convert it to serverVehID in GE
		controllerSyncVE.sendControllerData(tempTable)
	end
	lastvehID = vehID
	return controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
end

local function receiveID(data)
	if data.missileID and data.vehID then
		if data.missileID >= 10 then
			data.vehID = (data.vehID*100)+data.missileID
		else
			data.vehID = (data.vehID*10)+data.missileID
		end
	end
	controllerSyncVE.OGcontrollerFunctionsTable[data.controllerName][data.functionName](data.vehID)
end

local function setAimMode(controllerName, funcName, tempTable, ...)
	aimMode = ...
	controllerSyncVE.sendControllerData(tempTable)
	return controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
end

local function setAimModeReceive(data)
	aimMode = data.variables[1]
	if controllerSyncVE.OGcontrollerFunctionsTable["ciws"] then
		controllerSyncVE.OGcontrollerFunctionsTable["ciws"]["setTargetMode"](aimMode)
	end
	controllerSyncVE.OGcontrollerFunctionsTable[data.controllerName][data.functionName](aimMode)
end

local lastElevationDirection = 0

local function prepairSetElevationChange(controllerName, funcName, tempTable, ...)
	local servo = powertrain.getDevice("elevationServo")
	if aimMode == "manual" and servo then
		local servoAngle = servo.currentAngle
		if ... ~= 0 then
			lastElevationDirection = ...
			servoAngle = servoAngle + (...* 0.013) -- we have to add a bit extra rotation because servo.currentAngle is a frame behind
		else
			servoAngle = servoAngle + (lastElevationDirection* 0.013) -- we also need it for stopping so it doesn't stop short, but because stopping has an input of 0 we need to use the previous state
		end
		tempTable.servoAngle = servoAngle
		controllerSyncVE.sendControllerData(tempTable)
	end
	return controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
end

local function receiveSetElevationChange(data)
	local servo = powertrain.getDevice("elevationServo")
	if aimMode == "manual" and servo then
		servo:setTargetAngle(data.servoAngle)
	end
	controllerSyncVE.OGcontrollerFunctionsTable[data.controllerName][data.functionName](unpack(data.variables))
end

local lastRotationDirection = 0

local function prepairSetRotationChange(controllerName, funcName, tempTable, ...)
	local servo = powertrain.getDevice("rotationServo")
	if aimMode == "manual" and servo then
		local servoAngle = servo.currentAngle
		if ... ~= 0 then
			lastRotationDirection = ...
			servoAngle = servoAngle + (...* 0.003)
		else
			servoAngle = servoAngle + (lastRotationDirection* 0.003)
		end
		tempTable.servoAngle = servoAngle
		controllerSyncVE.sendControllerData(tempTable)
	end
	local returnData = controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
	return returnData
end

local function receiveSetRotationChange(data)
	local servo = powertrain.getDevice("rotationServo")
	if aimMode == "manual" and servo then
		servo:setTargetAngle(data.servoAngle)
	end
	controllerSyncVE.OGcontrollerFunctionsTable[data.controllerName][data.functionName](unpack(data.variables))
end

local includedControllerTypes = {
	-- PlayerWeapons mod --
	["pw2"] = {
		["camForwardCallback"] = {
			compare = true
			},
	},

	-- me262 and Phoulkon --
	["bombs"] = {
		["deployWeaponDown"] = {},
		["deployWeaponUp"] = {},
	},
	["countermeasures"] = {
		["activateCountermeasures"] = {}
	},
	["missiles"] = {
		["deployWeaponDown"] = {},
		["setTargetID"] = {
			ownerFunction = prepairID,
			receiveFunction = receiveID,
			storeState = true,
		},
		["deployWeaponUp"] = {}
	},
	["rockets"] = {
		["deployWeaponDown"] = {},
		["setTargetID"] = {
			ownerFunction = prepairID,
			receiveFunction = receiveID,
			storeState = true,
		},
		["deployWeaponUp"] = {}
	},
	["targetAim"] = {
		["setAimMode"] = {
			ownerFunction = setAimMode,
			receiveFunction = setAimModeReceive,
			storeState = true
		},
		["setTargetID"] = {
			ownerFunction = prepairID,
			receiveFunction = receiveID,
			storeState = true, -- restoring the states happens in the wrong order for this and setAimMode causing it not to aim on local reset
		},
		["setElevationChange"] = {
			ownerFunction = prepairSetElevationChange,
			receiveFunction = receiveSetElevationChange,
			storeState = true
		},
		["setRotationChange"] = {
			ownerFunction = prepairSetRotationChange,
			receiveFunction = receiveSetRotationChange,
			storeState = true
		},
		["killSystem"] = {}
	},
	["missileTargetSelector"] = {
		["toggleTargetMode"] = {}
	},
	-- Phulcan specific --
	["ciws"] = {
		["setTargetMode"] = {storeState = true},
		["fireWeapon"] = {storeState = true},
		["stopWeapon"] = {storeState = true},
	},
	["ram"] = {
		["setTargetMode"] = {storeState = true},
		["fireWeapon"] = {storeState = true},
		["stopWeapon"] = {storeState = true},
	},

	-- Javielucho Mad Mod --
	["madmod_missles"] = {
		["checkMissleLL"] = {},
		["checkMissleL"] = {},
		["checkMissleR"] = {},
		["checkMissleRR"] = {},
	},
}

local function loadFunctions()
	if controllerSyncVE ~= nil then
		controllerSyncVE.addControllerTypes(includedControllerTypes)
	else
		dump("controllerSyncVE not found")
	end
end

local function onReset()
	aimMode = "auto"
end

M.loadControllerSyncFunctions = loadFunctions
M.onReset = onReset

return M
