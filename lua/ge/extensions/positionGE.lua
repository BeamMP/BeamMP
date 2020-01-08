--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}



local function tick()
	local ownMap = vehicleGE.getOwnMap() -- Get map of own vehicles
	--print(HelperFunctions.dump(ownMap))
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("positionVE.getVehicleRotation()")
		end
	end
end



local function sendVehiclePosRot(data, gameVehicleID)
	if Network.GetTCPStatus() == 2 then -- If UDP connected
		local serverVehicleID = vehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		--print("SVID: "..tostring(serverVehicleID))
		if serverVehicleID and vehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			NetworkHandler.send("U-VL"..serverVehicleID..data) -- Send it
		end
	end
end



local function applyPos(data, serverVehicleID)
	-- 1 = pos.x
	-- 2 = pos.y
	-- 3 = pos.z
	-- 4 = rot.x
	-- 5 = rot.y
	-- 6 = rot.z
	-- 7 = rot.w

	--planetsVE.moveTo(2000, data[1], data[2], data[3])

	println("applyPos()")
	local gameVehicleID = vehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		local pr = jsonDecode(data) -- Decoded data
		print(gameVehicleID)
		print(pr)
		veh:setPosRot(pr[1], pr[2], pr[3], pr[4], pr[5], pr[6], pr[7]) -- Apply position
		veh:queueLuaCommand("ElectricsVE.applyLatestElectrics()") -- Redefine electrics values
	end

end



M.applyPos          = applyPos
M.tick              = tick
M.sendVehiclePosRot = sendVehiclePosRot



return M
