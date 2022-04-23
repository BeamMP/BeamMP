--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}
print("Loading positionGE...")

local actualSimSpeed = 1


local function tick()
	local ownMap = MPVehicleGE.getOwnMap() -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("positionVE.getVehicleRotation()")
		end
	end
end



local function sendVehiclePosRot(data, gameVehicleID)
	if MPGameNetwork.connectionStatus() > 0 then -- If TCP connected
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			local decoded = jsonDecode(data)
			local simspeedReal = bullettime.getReal()

			decoded.isTransitioning = (bullettime.get() ~= simspeedReal) or nil

			simspeedReal = bullettime.getPause() and 0 or simspeedReal -- set velocities to 0 if game is paused

			for k,v in pairs(decoded.vel) do decoded.vel[k] = v*simspeedReal end
			for k,v in pairs(decoded.rvel) do decoded.rvel[k] = v*simspeedReal end

			data = jsonEncode(decoded)
			MPGameNetwork.send('Zp:'..serverVehicleID..":"..data)
		end
	end
end



local function applyPos(data, serverVehicleID)
	local vehicle = MPVehicleGE.getVehicleByServerID(serverVehicleID)
	if not vehicle then log('E', 'applyPos', 'Could not find vehicle by ID '..serverVehicleID) return end


	local decoded = jsonDecode(data)

	local simspeedFraction = 1/bullettime.getReal()

	for k,v in pairs(decoded.vel) do decoded.vel[k] = v*simspeedFraction end
	for k,v in pairs(decoded.rvel) do decoded.rvel[k] = v*simspeedFraction end

	decoded.localSimspeed = simspeedFraction

	data = jsonEncode(decoded)


	local veh = be:getObjectByID(vehicle.gameVehicleID)
	if veh then -- vehicle already spawned, send data
		if veh.mpVehicleType == nil then
			veh:queueLuaCommand("MPVehicleVE.setVehicleType('R')")
			veh.mpVehicleType = 'R'
		end
		veh:queueLuaCommand("positionVE.setVehiclePosRot('"..data.."')")
	end
	local deltaDt = math.max((decoded.tim or 0) - (vehicle.lastDt or 0), 0.001)
	vehicle.lastDt = decoded.tim
	local ping = math.floor(decoded.ping*1000) -- (d.ping-deltaDt)

	vehicle.ping = ping
	vehicle.fps = 1/deltaDt
	vehicle.position = Point3F(decoded.pos[1],decoded.pos[2],decoded.pos[3])

	local owner = vehicle:getOwner()
	if owner then UI.setPlayerPing(owner.name, ping) end-- Send ping to UI
end



local function handle(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")
	if code == 'p' then
		applyPos(data, serverVehicleID)
	else
		print("unknown positionGE code arrived: "..rawData)
	end
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


local function setActualSimSpeed(speed)
	actualSimSpeed = speed*(1/bullettime.getReal())
end

local function getActualSimSpeed()
	return actualSimSpeed
end

M.applyPos          = applyPos
M.tick              = tick
M.handle            = handle
M.sendVehiclePosRot = sendVehiclePosRot
M.setPosition       = setPosition
M.setPing           = setPing
M.setActualSimSpeed = setActualSimSpeed
M.getActualSimSpeed = getActualSimSpeed

print("positionGE loaded")
return M
