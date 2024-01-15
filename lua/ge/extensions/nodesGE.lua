-- BeamMP, the BeamNG.drive multiplayer mod.
-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
--
-- BeamMP Ltd. can be contacted by electronic mail via contact@beammp.com.
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as published
-- by the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

--- nodesGE API.
--- Author of this documentation is Titch
--- @module nodesGE
--- @usage applyElectrics(...) -- internal access
--- @usage nodesGE.handle(...) -- external access


local M = {}


--- Called on specified interval by MPUpdatesGE to simulate our own tick event to collect data.
local function tick()
	local ownMap = MPVehicleGE.getOwnMap()
	for i,v in pairs(ownMap) do
		local veh = be:getObjectByID(i)
		if veh then
			--veh:queueLuaCommand("nodesVE.getNodes()")
			veh:queueLuaCommand("nodesVE.getBreakGroups()")
		end
	end
end


--- Wraps up node data from player own vehicles and sends it to the server.
-- INTERNAL USE
-- @param data table The node data from VE
-- @param gameVehicleID number The vehicle ID according to the local game
local function sendNodes(data, gameVehicleID)
	if MPGameNetwork.launcherConnected() then
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID)
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then
			MPGameNetwork.send('Xn:'..serverVehicleID..":"..data)
		end
	end
end


--- Wraps break group data of player own vehicles and sends it to the server.
-- INTERNAL USE
-- @param data table The break group data from VE
-- @param gameVehicleID number The vehicle ID according to the local game
local function sendBreakGroups(data, gameVehicleID)
	if MPGameNetwork.launcherConnected() then
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID)
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then
			MPGameNetwork.send('Xg:'..serverVehicleID..":"..data)
		end
	end
end


--- This function serves to send the nodes data received for another players vehicle from GE to VE, where it is handled.
-- @param data table The data to be applied as nodes
-- @param serverVehicleID string The VehicleID according to the server.
local function applyNodes(data, serverVehicleID)
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		veh:queueLuaCommand("nodesVE.applyNodes(\'"..data.."\')")
	end
end


--- This function serves to send the break groups data received for another players vehicle from GE to VE, where it is handled.
-- @param data table The data to be applied as break groups
-- @param serverVehicleID string The VehicleID according to the server.
local function applyBreakGroups(data, serverVehicleID)
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		veh:queueLuaCommand("nodesVE.applyBreakGroups(\'"..data.."\')")
	end
end


--- Handles raw node and break group packets received from other players vehicles. Disassembles and sends it to either applyNodes() or applyBreakGroups()
-- @param rawData string The raw message data.
local function handle(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:(.*)")
	if code == "n" then
		applyNodes(data, serverVehicleID)
	elseif code == "g" then
		applyBreakGroups(data, serverVehicleID)
	else
		log('W', 'handle', "Received unknown packet '"..tostring(code).."'! ".. rawData)
	end
end



M.tick       = tick
M.handle     = handle
M.sendNodes  = sendNodes
M.applyNodes = applyNodes
M.onInit = function() setExtensionUnloadMode(M, "manual") end

M.sendBreakGroups  = sendBreakGroups

return M
