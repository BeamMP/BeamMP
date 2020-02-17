--====================================================================================
-- All work by Jojos38 & Titch2000.
-- You have no permission to edit, redistrobute or upload. Contact us for more info!
--====================================================================================



local M = {}



local function tick() -- Update electrics values of all vehicles - The server check if the player own the vehicle itself
	local ownMap = vehicleGE.getOwnMap() -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("electricsVE.getElectrics()") -- Send electrics values
			veh:queueLuaCommand("electricsVE.getGear()") -- Send gears values
		end
	end
end



local function sendElectrics(data, gameVehicleID) -- Called by vehicle lua
	if Network.getStatus() == 2 then -- If TCP connected
		local serverVehicleID = vehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and vehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			Network.send(Network.buildPacket(0, 2131, serverVehicleID, data))
			--print("Electrics sent "..serverVehicleID)
		end
	end
end



local function applyElectrics(data, serverVehicleID)
	--print("gameVehicleID: "..vehicleGE.getGameVehicleID(serverVehicleID))
	local gameVehicleID = vehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		if not vehicleGE.isOwn() then
			veh:queueLuaCommand("electricsVE.applyElectrics(\'"..data.."\')")
		end
	end
end



local function sendGear(data, gameVehicleID)
	if Network.getStatus() == 2 then -- If TCP connected
		local serverVehicleID = vehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and vehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			Network.send(Network.buildPacket(0, 2135, serverVehicleID, data))
			--print("Gear sent "..serverVehicleID)
		end
	end
end



local function applyGear(data, serverVehicleID)
	local gameVehicleID = vehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		if not vehicleGE.isOwn() then
			veh:queueLuaCommand("electricsVE.applyGear(\'"..data.."\')")
		end
	end
end



M.tick 			 = tick
M.sendGear		 = sendGear
M.applyGear	 	 = applyGear
M.sendElectrics  = sendElectrics
M.applyElectrics = applyElectrics



return M