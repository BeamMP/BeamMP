--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading MPPowertrainGE...")



local function tick()
	local ownMap = MPVehicleGE.getOwnMap() -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("MPPowertrainVE.check()") -- Send all devices values
		end
	end
end



local function sendLivePowertrain(data, gameVehicleID)
	if MPGameNetwork.connectionStatus() > 0 then -- If TCP connected
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			MPGameNetwork.send('Yl:'..serverVehicleID..":"..data) -- Send powertrain to server
		end
	end
end



local function applyLivePowertrain(data, serverVehicleID)
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		veh:queueLuaCommand("MPPowertrainVE.applyLivePowertrain(\'"..data.."\')")
	end
end



local function handle(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")
	if code == "l" then
		applyLivePowertrain(data, serverVehicleID)
	end
end



M.tick                   = tick
M.handle                 = handle
M.sendPowertrain         = sendPowertrain
M.sendLivePowertrain     = sendLivePowertrain



print("MPPowertrainGE loaded")
return M
