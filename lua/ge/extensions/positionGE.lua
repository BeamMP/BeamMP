--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}
print("positionGE Initialising...")



local function tick()
	local ownMap = MPVehicleGE.getOwnMap() -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("positionVE.getVehicleRotation()")
		end
	end
end



local function distance(x1, y1, z1, x2, y2, z2)
	local dx = x1 - x2
	local dy = y1 - y2
	local dz = z1 - z2
	return math.sqrt(dx*dx + dy*dy + dz*dz)
end



local function sendVehiclePosRot(data, gameVehicleID)
	if MPGameNetwork.connectionStatus() > 0 then -- If TCP connected
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			MPGameNetwork.send('Zp:'..serverVehicleID..":"..data)
		end
	end
end



local function applyPos(data, serverVehicleID)
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		veh:queueLuaCommand("positionVE.setVehiclePosRot('"..data.."')")
	end
end



local function handle(rawData)
	rawData = string.sub(rawData,3)
	local serverVehicleID = string.match(rawData,"^.-:")
	serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1)
	local data = string.match(rawData,":(.*)")
	applyPos(data, serverVehicleID)
end



local function setPing(ping)
	local p = ping/1000
	for i = 0, be:getObjectCount() - 1 do
		local veh = be:getObject(i)
		if veh then
			veh:queueLuaCommand("positionVE.setPing("..p..")")
		end
	end
end

-- TODO: this is only here because there seems to be no way to set vehicle position in vehicle lua
-- without resetting the vehicle
local function setPosition(gameVehicleID, x, y, z)
	local veh = be:getObjectByID(gameVehicleID)
	veh:setPosition(Point3F(x, y, z))
	veh:queueLuaCommand("MPElectricsVE.applyLatestElectrics()") -- Redefine electrics values
end



M.applyPos          = applyPos
M.tick              = tick
M.handle            = handle
M.sendVehiclePosRot = sendVehiclePosRot
M.setPosition       = setPosition
M.setPing           = setPing



return M
