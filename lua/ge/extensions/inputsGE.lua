--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}



local function tick() -- Update electrics values of all vehicles - The server check if the player own the vehicle itself
	local ownMap = vehicleGE.getOwnMap() -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("inputsVE.getInputs()") -- Send electrics values
		end
	end
end



local function sendInputs(data, gameVehicleID) -- Called by vehicle lua
	if Network.getStatus() == 2 then -- If TCP connected
		local serverVehicleID = vehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and vehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			Network.send(Network.buildPacket(0, 2130, serverVehicleID, data))
		end
	end
end



local function applyInputs(data, serverVehicleID)
	local gameVehicleID = vehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		veh:queueLuaCommand("inputsVE.applyInputs(\'"..data.."\')")
	end
end



M.tick        = tick
M.sendInputs  = sendInputs
M.applyInputs = applyInputs



return M
