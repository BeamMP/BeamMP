--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

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


--- This function is called by VE lua to send the data from VE to GE and then to the server.
--- INTERNAL USE
--- @param data table The node data from VE
--- @param gameVehicleID number The vehicle ID according to the local game
local function sendNodes(data, gameVehicleID)
	if MPGameNetwork.launcherConnected() then
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID)
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then
			MPGameNetwork.send('Xn:'..serverVehicleID..":"..data)
		end
	end
end


--- This function is called by VE lua to send the data from VE to GE and then to the server.
--- INTERNAL USE
--- @param data table The break group data from VE
--- @param gameVehicleID number The vehicle ID according to the local game
local function sendBreakGroups(data, gameVehicleID)
	if MPGameNetwork.launcherConnected() then
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID)
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then
			MPGameNetwork.send('Xg:'..serverVehicleID..":"..data)
		end
	end
end


--- This function serves to send the nodes data from GE to VE for application
--- @param data table The data to be applied as nodes
--- @param serverVehicleID string The VehicleID according to the server.
local function applyNodes(data, serverVehicleID)
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		veh:queueLuaCommand("nodesVE.applyNodes(\'"..data.."\')")
	end
end


--- This function serves to send the break groups data from GE to VE for application
--- @param data table The data to be applied as break groups
--- @param serverVehicleID string The VehicleID according to the server.
local function applyBreakGroups(data, serverVehicleID)
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		veh:queueLuaCommand("nodesVE.applyBreakGroups(\'"..data.."\')")
	end
end


--- The raw message from the server. This is unpacked first and then sent to be applied according to message code.
--- @param rawData string The raw message data.
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

M.sendBreakGroups  = sendBreakGroups

return M
