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
		end
	end
end



local function sendElectrics(data, gameVehicleID) -- Called by vehicle lua
	if Network.GetTCPStatus() == 2 then -- If TCP connected
		local serverVehicleID = vehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		print(serverVehicleID)
		if serverVehicleID and vehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			NetworkHandler.send("U-VE"..serverVehicleID..data) -- Send it
			print("Electrics sent "..serverVehicleID)
		end
	end
end



local function applyElectrics(data, serverVehicleID)
	--print("gameVehicleID: "..vehicleGE.getGameVehicleID(serverVehicleID))
	-- TODO parfois le gameVehicleID est incorrecte !
	local gameVehicleID = vehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		if not vehicleGE.isOwn() then
			--print("ok")
			--print("data")
			veh:queueLuaCommand("electricsVE.applyElectrics(\'"..data.."\')")
		end
	end
end


M.tick 			 = tick
M.sendElectrics  = sendElectrics
M.applyElectrics = applyElectrics



return M
