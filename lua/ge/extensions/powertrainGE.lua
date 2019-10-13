--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}



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
	if Network.GetTCPStatus() == 2 then -- If UDP is connected
		local serverVehicleID = vehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and vehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			Network.send("2133"..serverVehicleID..data) -- Send data
			print("Powertrain sent")
		end
	end
end



local function applyPowertrain(data, serverVehicleID)
	print("Powertrain received")
	local gameVehicleID = vehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		print("ok")
		veh:queueLuaCommand("powertrainVE.applyPowertrain(\'"..data.."\')")
	end
end



M.tick                   = tick
M.sendPowertrain         = sendPowertrain
M.applyPowertrain        = applyPowertrain



return M
