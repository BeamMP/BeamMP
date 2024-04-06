-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

-- when a function is set as 1 it will only sends data when there is a change
-- set as 2 it sends the data every time the function is called

-- alternativly using a table with ownerFunction and remoteFunction can be set with custom functions to read or change data before sending or on recieveing

--example from controllersVE.lua
--[[

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
["controllerFunctionName"] = {
  ownerFunction = couplerToggleCheck,
  remoteFunction = couplerToggleRecieve
},

]]

local includedControllerTypes = {
	["pw2"] = { -- PlayerWeapons mod sync
		["camForwardCallback"] = 1
	},

	-- me262 and Phoulkon --
	["bombs"] = {
		["deployWeaponDown"] = 2,
		["deployWeaponUp"] = 2
	},
	["countermeasures"] = {
		["activateCountermeasures"] = 2
	},
	["missiles"] = {
		["deployWeaponDown"] = 2,
		--["setTargetID"] = 1, --TODO make a local ID to server ID converter
		["deployWeaponUp"] = 2
	},
	["rockets"] = {
		["deployWeaponDown"] = 2,
		--["setTargetID"] = 1, --TODO make a local ID to server ID converter
		["deployWeaponUp"] = 2
	},
	["targetAim"] = {
		--["setTargetID"] = 1, --TODO make a local ID to server ID converter
		["setAimMode"] = 2,
		["setElevationChange"] = 2,
		["setRotationChange"] = 2,
		["killSystem"] = 2
	},
	-- Phulcan specific --
	["ciws"] = {
		["setTargetMode"] = 2,
		["fireWeapon"] = 2,
		["stopWeapon"] = 2,
	},
	["ram"] = {
		["setTargetMode"] = 2,
		["fireWeapon"] = 2,
		["stopWeapon"] = 2,
	},

	-- Javielucho Mad Mod --
	["madmod_missles"] = {
		["checkMissleLL"] = 2,
		["checkMissleL"] = 2,
		["checkMissleR"] = 2,
		["checkMissleRR"] = 2,
	},
}

if controllersVE ~= nil then
	controllersVE.addControllerTypes(includedControllerTypes)
end

return M
