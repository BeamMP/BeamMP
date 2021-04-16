--====================================================================================
-- All work by Titch2000 and jojos38.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading MPInputsGE...")



local function tick() -- Update electrics values of all vehicles - The server check if the player own the vehicle itself
	local ownMap = MPVehicleGE.getOwnMap() or {} -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("MPInputsVE.getInputs()") -- Send electrics values
		end
	end
end



local function sendInputs(data, gameVehicleID) -- Called by vehicle lua
	if MPGameNetwork.connectionStatus() > 0 then -- If TCP connected
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			MPGameNetwork.send('Vi:'..serverVehicleID..":"..data)--Network.buildPacket(0, 2130, serverVehicleID, data))
		end
	end
end



local function applyInputs(data, serverVehicleID)
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		veh:queueLuaCommand("MPInputsVE.applyInputs(\'"..data.."\')")
	end
end



local function handle(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")
	if code == 'i' then
		applyInputs(data, serverVehicleID)
	end
end



M.tick        = tick
M.handle      = handle
M.sendInputs  = sendInputs
M.applyInputs = applyInputs


print("MPInputsGE loaded")
return M
