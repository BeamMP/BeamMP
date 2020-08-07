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
			--veh:queueLuaCommand("positionVE.getVehicleVelocity()")
			--veh:queueLuaCommand("positionVE.getVehicleAngularVelocity()")
		end
	end
end

local function distance( x1, y1, z1, x2, y2, z2 )
	local dx = x1 - x2
	local dy = y1 - y2
	local dz = z1 - z2
	return math.sqrt ( dx*dx + dy*dy + dz*dz)
end

local function sendVehiclePosRot(data, gameVehicleID)
	if GameNetwork.connectionStatus() == 1 then -- If TCP connected
		local serverVehicleID = vehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and vehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			GameNetwork.send('Zp:'..serverVehicleID..":"..data)--Network.buildPacket(0, 2134, serverVehicleID, data))
		end
	end
end


local function applyPos(data, serverVehicleID)

	local gameVehicleID = vehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	--if gameVehicleID ~= -1 or not gameVehicleID then
		--GameNetwork.send('On:'..serverVehicleID)
	--end
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		--print(data)
		local pr = jsonDecode(data) -- Decoded data
		--print(dump(pr))

		local pos = vec3(pr.pos.x, pr.pos.y, pr.pos.z)
		local vel = vec3(pr.vel.x, pr.vel.y, pr.vel.z)
		local ang = quat(pr.ang.x, pr.ang.y, pr.ang.z, pr.ang.w)
		local rvel = vec3(pr.rvel.x, pr.rvel.y, pr.rvel.z)
		local tim = pr.tim
		local ping = pr.ping

		veh:queueLuaCommand("positionVE.setVehiclePosRot("..tostring(pos)..","..tostring(vel)..","..tostring(ang)..","..tostring(rvel)..","..tim..","..ping..")")
	end
end

local function handle(rawData)
	--print("positionGE.handle: "..rawData)
	rawData = string.sub(rawData,3)
	local serverVehicleID = string.match(rawData,"^.-:")
	serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1)
	local data = string.match(rawData,":(.*)")
	--print(serverVehicleID)
	--print(data)
	applyPos(data, serverVehicleID)
end

--TODO: this is only here because there seems to be no way to set vehicle position in vehicle lua
--without resetting the vehicle
local function setPosition(gameVehicleID, x, y, z)
	local veh = be:getObjectByID(gameVehicleID)
	veh:setPosition(Point3F(x, y, z))
	veh:queueLuaCommand("electricsVE.applyLatestElectrics()") -- Redefine electrics values
end

local function setPing(ping)
	local p = ping/1000
	for i = 0, be:getObjectCount()-1 do
		local veh = be:getObject(i)
		if veh then
			veh:queueLuaCommand("positionVE.setPing("..p..")")
		end
	end
end

M.applyPos          = applyPos
M.tick              = tick
M.handle            = handle
M.sendVehiclePosRot = sendVehiclePosRot
M.setPosition       = setPosition
M.setPing           = setPing


print("positionGE Loaded.")
return M
