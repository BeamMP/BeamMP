--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}

local actualSimSpeed = 1

local highVelocityFixPause = {} -- serverVehicleID:os.time()
local highVelocityFixPauseTime = 1 -- seconds
local highVelocityChangePositive = 20 -- m/s
local highVelocityChangeNegativ = -20 -- m/s
local gameIsLagging = false

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
	if MPGameNetwork.launcherConnected() then
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

local function _getVelocity(x, y, z)
	return math.sqrt(x^2 + y^2 + z^2)
end

local function getVelocityDifference(x1, y1, z1, x2, y2, z2)
	local vel1 = math.floor(_getVelocity(x1, y1, z1))
	local vel2 = math.floor(_getVelocity(x2, y2, z2))
	return vel1 - vel2
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

		--[[ The next piece of code fixes the vehicle demolition caused by lag, duo to high g-forces.
			This fix is not immediate, but it rather brings the vehicle into a position where it can easier handle
			the teleport, acceleration and deacceleration and therefore it reduces the chance of a vehicle demoliton.
			The code resets the vehicle, teleports it to the pos[] given in this packet and then sets its speed
			to the velocity given in vel[]. Once a fix was applied to the vehicle it cannot be applied again for
			1 second. This is because the fix is not perfect. It takes a couple vehicle updates for the vehicle to be
			fully synced again. Not doing this pause will cause the vehicle to get fixed over and over again.
			
			The fix is also not applied when the game is considered lagging. Vehicles dont drive smoothly anyway in a lagging
			environment and this fix would make it worse for those.
		--]]

		local performDefaultVehicleUpdate = true
		local currentVel = veh:getVelocity()
		local velocityChange = getVelocityDifference(currentVel.x, currentVel.y, currentVel.z, decoded.vel[1], decoded.vel[2], decoded.vel[3])

		-- only act when the current vehicular speed is to different from the vehicular speed given in this packet.
		if velocityChange > highVelocityChangePositive or velocityChange < highVelocityChangeNegativ then

			-- dont apply the fix if the game is lagging or paused
			if bullettime.getPause() == false and gameIsLagging == false then

				-- dont perform fixes for a vehicle to often or it will cause issues
				if highVelocityFixPause[serverVehicleID] == nil or os.difftime(os.time(), highVelocityFixPause[serverVehicleID]) > highVelocityFixPauseTime then

					print('performing HighG fix ' .. serverVehicleID .. ' - ' .. math.floor(velocityChange * 3.6)) -- temp

					-- get gear or alternativly get all current vehicle electrics
					-- ~ todo

					-- reset car
					veh:reset()

					-- tp. note: sets the vehicle a bit into the air unintentionally.
					-- doing the no physics reset and then the posrot update both somehow gives better results then if we do just one of these
					veh:setPositionNoPhysicsReset(vec3(decoded.pos[1], decoded.pos[2], decoded.pos[3]))
					veh:setPositionRotation(decoded.pos[1], decoded.pos[2], decoded.pos[3], decoded.rot[1], decoded.rot[2], decoded.rot[3], decoded.rot[4])

					-- release parking brake
					veh:queueLuaCommand("input.event('parkingbrake', 0, 1)")

					-- set back old gear or alternativly set back all previous vehicle electrics
					-- ~ todo

					-- set instant velocity
					veh:applyClusterVelocityScaleAdd(veh:getRefNodeId(), 1, decoded.vel[1], decoded.vel[2], decoded.vel[3])

					highVelocityFixPause[serverVehicleID] = os.time()
					performDefaultVehicleUpdate = false
				end
			end
		end

		if performDefaultVehicleUpdate then veh:queueLuaCommand("positionVE.setVehiclePosRot('"..data.."')") end
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
		log('W', 'handle', "Received unknown packet '"..tostring(code).."'! ".. rawData)
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
	veh:setPositionNoPhysicsReset(Point3F(x, y, z))
end


local function setActualSimSpeed(speed)
	actualSimSpeed = speed*(1/bullettime.getReal())
end

local function getActualSimSpeed()
	return actualSimSpeed
end

function onUpdate(dt)
	-- the game is considered lagging when the fps is to low. ~20fps
	if (dt * 60) > 2.5 then gameIsLagging = true else gameIsLagging = false end
end

M.applyPos          = applyPos
M.tick              = tick
M.handle            = handle
M.sendVehiclePosRot = sendVehiclePosRot
M.setPosition       = setPosition
M.setPing           = setPing
M.setActualSimSpeed = setActualSimSpeed
M.getActualSimSpeed = getActualSimSpeed
M.onUpdate			= onUpdate

return M
