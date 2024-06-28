-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

-- compare set to true only sends data when there is a change
-- compare set to false sends the data every time the function is called
-- storeState stores the incoming data and then if the remote car was reset for whatever reason it reapplies the state
-- adding ownerFunction and/or remoteFunction can set custom functions to read or change data before sending or on recieveing

--example
--[[
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

["controllerFunctionName"] = {
  ownerFunction = couplerToggleCheck,
  remoteFunction = couplerToggleRecieve
},
]]

local lastvehID = 0

local function prepairID(controllerName, funcName, tempTable, ...)
	if tempTable.variables[1] or lastvehID then -- the Phulcan spams the setTargetID in auto mode, but just comparing to last can break normal targeting, and we still need to send an empty table once, so instead I'm checking if either is true
		if tempTable.variables[1] then
			-- syncing targeting missiles, missiles have the vehicleID of the original vehicle but with it's own id added at the end
			-- this system checks if removing two numbers make it match with a vehicle, if it does then we know that this is the vehicle it belongs too,
			-- if not then we try removing just one number and check again, it has to be done in this order or id 11 will mistake the missile with id 1 as being it's vehicle
			-- thanks Stefan750 for helping me figure out this system
			local mapObjects = mapmgr.getObjects() or {}
			local flooredID100 = math.floor((tempTable.variables[1]/100))
			local found = false
			for k,_ in pairs(mapObjects) do
				if k == flooredID100 then
					tempTable.variables[2] = tempTable.variables[1] - (k*100)
					tempTable.variables[1] = flooredID100
					found = true
				end
			end
			local flooredID10 = math.floor((tempTable.variables[1]/10))
			if not found then -- if we already found a matching id we skip this loop
				for k,_ in pairs(mapObjects) do
					if k == flooredID10 then
						tempTable.variables[2] = tempTable.variables[1] - (k*10)
						tempTable.variables[1] = flooredID10
					end
				end
			end
		end
		tempTable["vehID"] = tempTable.variables[1] -- store vehicleID separately so we can convert it to serverVehID in GE
		controllerSyncVE.sendControllerData(tempTable)
	end
	lastvehID = tempTable.variables[1]
	return controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
end

local function recieveID(data)
	if data.variables[2] and data.vehID then
		if data.variables[2] >= 10 then
			data.vehID = (data.vehID*100)+data.variables[2]
		else
			data.vehID = (data.vehID*10)+data.variables[2]
		end
	end
	controllerSyncVE.OGcontrollerFunctionsTable[data.controllerName][data.functionName](data.vehID)
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
		["deployWeaponDown"] = {
			compare = false
			},
		["deployWeaponUp"] = {
			compare = false
			},
	},
	["countermeasures"] = {
		["activateCountermeasures"] = {
			compare = false
			}
	},
	["missiles"] = {
		["deployWeaponDown"] = {
			compare = false
			},
		["setTargetID"] = {
			ownerFunction = prepairID,
			remoteFunction = recieveID
		},
		["deployWeaponUp"] = {
			compare = false
			}
	},
	["rockets"] = {
		["deployWeaponDown"] = {
			compare = false
			},
		["setTargetID"] = {
			ownerFunction = prepairID,
			remoteFunction = recieveID
		},
		["deployWeaponUp"] = {
			compare = false
			}
	},
	["targetAim"] = {
		["setTargetID"] = {
			ownerFunction = prepairID,
			remoteFunction = recieveID
		},
		["setAimMode"] = {
			compare = false
			},
		["setElevationChange"] = {
			compare = false
			},
		["setRotationChange"] = {
			compare = false
			},
		["killSystem"] = {
			compare = false
			}
	},
	["missileTargetSelector"] = {
		["toggleTargetMode"] = {
			compare = false
			}
	},
	-- Phulcan specific --
	["ciws"] = {
		["setTargetMode"] = {
			compare = false
			},
		["fireWeapon"] = {
			compare = false
			},
		["stopWeapon"] = {
			compare = false
			},
	},
	["ram"] = {
		["setTargetMode"] = {
			compare = false
			},
		["fireWeapon"] = {
			compare = false
			},
		["stopWeapon"] = {
			compare = false
			},
	},

	-- Javielucho Mad Mod --
	["madmod_missles"] = {
		["checkMissleLL"] = {
			compare = false
			},
		["checkMissleL"] = {
			compare = false
			},
		["checkMissleR"] = {
			compare = false
			},
		["checkMissleRR"] = {
			compare = false
			},
	},
}

local function onReset()

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
