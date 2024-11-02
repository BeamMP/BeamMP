-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

local function tick()
	local ownMap = MPVehicleGE.getOwnMap() -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("controllerSyncVE.getControllerData()") -- Send all devices values
		end
	end
end

local function sendControllerData(data, gameVehicleID)
	if MPGameNetwork.launcherConnected() then
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID)
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then
			local decodedData = jsonDecode(data)
			if decodedData.vehID then
				decodedData.vehID = MPVehicleGE.getServerVehicleID(decodedData.vehID) -- used for controllers that call to another vehicle, like the me262 missile targeting system
			end
			data = jsonEncode(decodedData)
			dump(data, gameVehicleID)
			MPGameNetwork.send('Rc:'..serverVehicleID..":"..data)
		end
	end
end

local function applyControllerData(data, serverVehicleID)
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		local decodedData = jsonDecode(data)
		if decodedData.vehID then
			decodedData.vehID = MPVehicleGE.getGameVehicleID(decodedData.vehID)
		end
		data = jsonEncode(decodedData)
		veh:queueLuaCommand("controllerSyncVE.applyControllerData(mime.unb64(\'".. MPHelpers.b64encode(data) .."\'))")
	end
end

local function handle(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:(.*)")

	local veh = MPVehicleGE.getVehicles()[serverVehicleID]

	if not veh or veh.isLocal then
		return
	end

	if code == "c" then
		applyControllerData(data, serverVehicleID)
	else
		log('W', 'handle', "Received unknown packet '"..tostring(code).."'! ".. rawData)
	end
end

M.tick			 = tick
M.handle                 = handle
M.sendControllerData	 = sendControllerData

M.applyControllerData	 = applyControllerData

M.onInit = function() setExtensionUnloadMode(M, "manual") end


return M
