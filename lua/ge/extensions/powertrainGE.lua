--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}
print("powertrainGE Initialising...")



local function tick()
	local ownMap = vehicleGE.getOwnMap() -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("powertrainVE.sendAllPowertrain()") -- Send all devices values
		end
	end
end



local function sendPowertrain(data, gameVehicleID)
	if GameNetwork.connectionStatus() == 1 then -- If TCP connected
		local serverVehicleID = vehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and vehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			GameNetwork.send('Yp:'..serverVehicleID..":"..data)--Network.buildPacket(0, 2133, serverVehicleID, data))
		end
	end
end

local function applyPowertrain(data, serverVehicleID)
	local gameVehicleID = vehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		veh:queueLuaCommand("powertrainVE.applyPowertrain(\'"..data.."\')")
	end
end

local function handle(rawData)
	--print("powertrainGE.handle: "..rawData)
	local code = string.sub(rawData, 1, 1)
	local rawData = string.sub(rawData, 3)
	if code == "p" then
		local serverVehicleID = string.match(rawData,"^.-:")
		serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1)
		local data = string.match(rawData,":(.*)")
		applyPowertrain(data, serverVehicleID)
	end
end



M.tick                   = tick
M.handle                 = handle
M.sendPowertrain         = sendPowertrain
M.applyPowertrain        = applyPowertrain



print("powertrainGE Loaded.")
return M
