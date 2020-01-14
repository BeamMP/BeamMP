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
			--print(i.." - > "..tostring(veh:getVelocity()))
			--print(i.." - > "..jsonEncode("["..tostring(veh:getVelocity()).."]"))
			velocityGE.sendVehicleVelocity(jsonEncode("["..tostring(veh:getVelocity()).."]"), i)
		end
	end
end



local function sendVehicleVelocity(data, gameVehicleID)
	if Network.GetTCPStatus() == 2 then -- If UDP connected
		local serverVehicleID = vehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		--print("U-VV: "..data)
		if serverVehicleID and vehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			NetworkHandler.send("U-VV"..serverVehicleID..data) -- Send it
		end
	end
end



local function applyVelocity(data, serverVehicleID)
	-- TEMP HACK PLEASE FIX IN LONG RUN
	data = data:gsub('"','')
	serverVehicleID = serverVehicleID:gsub('"','')
	local gameVehicleID = vehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		local pr = jsonDecode(data) -- Decoded data
		print(tostring(pr))
		veh.setVelocity(pr[1], pr[2], pr[3]) -- Apply velocity
	end

end



M.applyVelocity       = applyVelocity
M.tick                = tick
M.sendVehicleVelocity = sendVehicleVelocity



return M
