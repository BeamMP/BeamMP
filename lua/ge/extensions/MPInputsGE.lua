--====================================================================================
-- All work by Titch2000 and jojos38.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================

--- MPInputsGE API. - This is responsible for collecting and setting inputs on vehicle
--- Author of this documentation is Titch
--- @module MPInputsGE
--- @usage applyInputs(...) -- internal access
--- @usage MPInputsGE.handle(...) -- external access


local M = {}


--- Called on specified interval by MPUpdatesGE to simulate our own tick event to collect data.
local function tick() -- Update inputs values of all vehicles - The server check if the player own the vehicle itself
	local ownMap = MPVehicleGE.getOwnMap() or {} -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("MPInputsVE.getInputs()") -- Send inputs values
		end
	end
end



--- This function is called by VE lua to send the data from VE to GE and then to the server.
--- INTERNAL USE
--- @param data table The inputs data from VE
--- @param gameVehicleID number The vehicle ID according to the local game
local function sendInputs(data, gameVehicleID) -- Called by vehicle lua
	if MPGameNetwork.launcherConnected() then
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			MPGameNetwork.send('Vi:'..serverVehicleID..":"..data)--Network.buildPacket(0, 2130, serverVehicleID, data))
		end
	end
end


--- This function serves to send the inputs data from GE to VE for application
--- @param data table The data to be applied as inputs
--- @param serverVehicleID string The VehicleID according to the server.
local function applyInputs(data, serverVehicleID)
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		veh:queueLuaCommand("MPInputsVE.applyInputs(\'"..data.."\')")
	end
end


--- The raw message from the server. This is unpacked first and then sent to be applied according to message code.
--- @param rawData string The raw message data.
local function handle(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")
	if code == 'i' then
		applyInputs(data, serverVehicleID)
	else
		log('W', 'handle', "Received unknown packet '"..tostring(code).."'! ".. rawData)
	end
end



M.tick        = tick
M.handle      = handle
M.sendInputs  = sendInputs
M.applyInputs = applyInputs


return M
