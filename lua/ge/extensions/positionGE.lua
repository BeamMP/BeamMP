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

	-- 1 = pos.x
	-- 2 = pos.y
	-- 3 = pos.z

	-- 4 = vel.x
	-- 5 = vel.y
	-- 6 = vel.z

	-- 7 = ang.x
	-- 8 = ang.y
	-- 9 = ang.z

	local gameVehicleID = vehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		--print(data)
		local pr = jsonDecode(data) -- Decoded data
		--print(dump(pr))
		local pos = veh:getPosition()
		local diff = distance(pos.x, pos.y, pos.z, pr.pos.x, pr.pos.y, pr.pos.z)
		--print("Diff: "..diff)
		if diff > 0.5 then -- set to 0.5 for production
			veh:setPosition(Point3F(pr.pos.x, pr.pos.y, pr.pos.z))
		else
			local vel = vec3(pr.vel.x, pr.vel.y, pr.vel.z)
			--rot = vec3(pr[7], pr[8], pr[9])
			--veh:queueLuaCommand("positionVE.setVehiclePosRot(" .. tostring(pos) .. "," .. tostring(rot) .. "," .. timestamp .. ")")

			-- Apply velocities
			veh:queueLuaCommand("velocityVE.setVelocity("..pr.vel.x..", "..pr.vel.y..", "..pr.vel.z..")")
			-- TODO: shorten this line
			--print("Sending Rotation Data to VE")
			veh:queueLuaCommand("velocityVE.setAngularVelocity("..pr.ang.x..", "..pr.ang.y..", "..pr.ang.z..")")
		end
		veh:queueLuaCommand("electricsVE.applyLatestElectrics()") -- Redefine electrics values
	end
end

local function handle(rawData)
	--print("positionGE.handle: "..rawData)
	rawData = string.sub(rawData,3)
	local serverVehicleID = string.match(rawData,"(%w+)%:")
	local data = string.match(rawData,":(.*)")
	--print(serverVehicleID)
	--print(data)
	applyPos(data, serverVehicleID)
end


M.applyPos          = applyPos
M.tick              = tick
M.handle            = handle
M.sendVehiclePosRot = sendVehiclePosRot



print("positionGE Loaded.")
return M
