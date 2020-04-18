--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}
print("positionGE Initialising...")



local function tick()
	local ownMap = vehicleGE.getOwnMap() -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("positionVE.getVehicleRotation()")
		end
	end
end



local function sendVehiclePosRot(data, gameVehicleID)
	if GameNetwork.connectionStatus() == 1 then -- If TCP connected
		local serverVehicleID = vehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and vehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			GameNetwork.send('Zp:'..serverVehicleID..":"..data)--Network.buildPacket(0, 2134, serverVehicleID, data))
		end
	end
end

local function handle(data)
	print("positionGE.handle: "..data)
end

local counter = 0
local function applyPos(data, serverVehicleID)

	-- 1 = pos.x
	-- 2 = pos.y
	-- 3 = pos.z
	-- 4 = rot.x
	-- 5 = rot.y
	-- 6 = rot.z
	-- 7 = rot.w

	local gameVehicleID = vehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		local pr = jsonDecode(data) -- Decoded data
		if counter < 1 then
			veh:setPosition(Point3F(pr[1], pr[2], pr[3]))
			counter = counter + 1
		else
			veh:setPosRot(pr[1], pr[2], pr[3], pr[4], pr[5], pr[6], pr[7]) -- Apply position
			counter = 0
		end
		--veh:setPosition(Point3F(pr[1], pr[2], pr[3])) -- Apply position
		veh:queueLuaCommand("electricsVE.applyLatestElectrics()") -- Redefine electrics values
	end

end



M.applyPos          = applyPos
M.tick              = tick
M.handle            = handle
M.sendVehiclePosRot = sendVehiclePosRot



print("positionGE Loaded.")
return M
