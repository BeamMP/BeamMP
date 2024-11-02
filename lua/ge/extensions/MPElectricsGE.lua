-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- MPElectricsGE API.
--- Author of this documentation is Titch
--- @module MPElectricsGE
--- @usage applyElectrics(...) -- internal access
--- @usage MPElectricsGE.handle(...) -- external access


local M = {}



local lastElectrics


--- Called on specified interval by MPUpdatesGE to simulate our own tick event to collect data.
local function tick() -- Update electrics values of all vehicles
	local ownMap = MPVehicleGE.getOwnMap() -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("MPElectricsVE.check()") -- Check if any value changed
		end
	end
end



--- Wraps player own vehicle electrics into a packet and sends it to the Server.
-- INTERNAL USE
-- @param data table The electrics data from VE
-- @param gameVehicleID number The vehicle ID according to the local game
local function sendElectrics(data, gameVehicleID)
	if MPGameNetwork.launcherConnected() then
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) and data ~= lastElectrics then -- If serverVehicleID not null and player own vehicle
			MPGameNetwork.send('We:'..serverVehicleID..":"..data)
			lastElectrics = data
		end
	end
end


--- This function serves to send the electrics data received for another players vehicle from GE to VE, where it is handled.
-- @param data table The data to be applied as electrics
-- @param serverVehicleID string The VehicleID according to the server.
local function applyElectrics(data, serverVehicleID)
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		if not MPVehicleGE.isOwn(gameVehicleID) then
			veh:queueLuaCommand("MPElectricsVE.applyElectrics(mime.unb64(\'".. MPHelpers.b64encode(data) .."\'))")
		end
	end
end


--- The raw message from the server. This is unpacked first and then given to applyElectrics()
-- @param rawData string The raw message data.
local function handle(rawData)
	--print("MPElectricsGE.handle: "..rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")

	local veh = MPVehicleGE.getVehicles()[serverVehicleID]

	if not veh or veh.isLocal then
		return
	end

	if code == "e" then -- Electrics (indicators, lights etc...)
		applyElectrics(data, serverVehicleID)
	else
		log('W', 'handle', "Received unknown packet '"..tostring(code).."'! ".. rawData)
	end
end



M.tick 			 = tick
M.handle     	 = handle
M.sendElectrics  = sendElectrics
M.onInit = function() setExtensionUnloadMode(M, "manual") end

return M
