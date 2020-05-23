--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}

local dequeue = require('dequeue')

-- ============= VARIABLES =============
local maxBuffer = 0.4          -- How many seconds packets will be kept in buffer
local posCorrectMul = 2        -- How much acceleration to use for correcting position error
local maxPosError = 1          -- If position error is larger than this, teleport the vehicle
local rotCorrectMul = 2        -- How much acceleration to use for correcting angle error

local timer = 0
local buffer = dequeue.new()
-- ============= VARIABLES =============

local function updateGFX(dt)
	timer = timer + dt

	-- Remove packets older than bufferTime from buffer, but keep at least 1
	while buffer:length() > 1 and timer-buffer:peek_left().localTime > maxBuffer do
		buffer:pop_left()
	end

	local data = buffer:peek_right()

	-- If there is no data in the buffer, skip everything
	if not data then return end

	-- Average remote to local time difference over buffer
	local avgTimeDiff = 0
	for d in buffer:iter_left() do
		avgTimeDiff = avgTimeDiff + d.localTime-d.remoteTime
	end
	avgTimeDiff = avgTimeDiff/buffer:length()

	-- Calculate back to local time using the time at which the packet was sent and the average time difference
	local calcLocalTime = data.remoteTime+avgTimeDiff

	-- Get difference between calculated and actual local time
	-- If you add the ping delay to this, we would have a simple form of lag compensation
	local timeDiff = timer - calcLocalTime

	-- Extrapolate position where the car should be right now
	local pos = data.pos + data.vel*timeDiff
	local vel = data.vel
	local rot = data.rot -- + data.rvel*timeDiff (TODO: rot is quat and rvel is vec3, so this doesn't work)
	local rvel = data.rvel

	--DEBUG
	--local debugDrawer = obj.debugDrawProxy
	--debugDrawer:drawSphere(0.8, data.pos:toFloat3(), color(0,0,255,255))
	--debugDrawer:drawSphere(0.8, pos:toFloat3(), color(0,255,0,255))

	local vehPos = vec3(obj:getPosition())
	local vehRot = quat(obj:getRotation())

	local posError = (pos - vehPos)
	local rotError = (rot / vehRot):toEulerYXZ()

	-- If position error is larger than limit, teleport the vehicle
	if posError:length() > maxPosError then
		--print("PosError = " .. tostring(posError))

		obj:queueGameEngineLua("positionGE.setPosition("..obj:getID()..","..pos.x..","..pos.y..","..pos.z..")")
	else
		-- Add correction forces to stop position and angle from drifting apart
		vel = vel + posError*posCorrectMul
		rvel = rvel + rotError*rotCorrectMul
	end

	velocityVE.setVelocity(vel.x, vel.y, vel.z)
	velocityVE.setAngularVelocity(rvel.y, rvel.z, rvel.x)
	--velocityVE.setAngularVelocity(rvel.x, rvel.y, rvel.z)
end

local function getVehicleRotation()
	local tempTable = {}
	local pos = obj:getPosition()
	local vel = obj:getVelocity()
	local rot = obj:getRotation()
	local dirVector = obj:getDirectionVector()
	local dirVectorUp = obj:getDirectionVectorUp()
	local roll = dirVectorUp.x * -dirVector.y + dirVectorUp.y * dirVector.x
	local pitch = dirVector.z
	local yaw = dirVector.x
	local rvel = {}
	rvel.y = obj:getPitchAngularVelocity()
	rvel.z = obj:getRollAngularVelocity()
	rvel.x = obj:getYawAngularVelocity()
	tempTable['pos'] = {}
	tempTable['pos'].x = tonumber(pos.x)
	tempTable['pos'].y = tonumber(pos.y)
	tempTable['pos'].z = tonumber(pos.z)
	tempTable['vel'] = {}
	tempTable['vel'].x = tonumber(vel.x)
	tempTable['vel'].y = tonumber(vel.y)
	tempTable['vel'].z = tonumber(vel.z)
	tempTable['ang'] = {}
	tempTable['ang'].x = tonumber(rot.x)
	tempTable['ang'].y = tonumber(rot.y)
	tempTable['ang'].z = tonumber(rot.z)
	tempTable['ang'].w = tonumber(rot.w)
	tempTable['rvel'] = {}
	tempTable['rvel'].x = tonumber(rvel.x)
	tempTable['rvel'].y = tonumber(rvel.y)
	tempTable['rvel'].z = tonumber(rvel.z)
	tempTable['tim'] = timer
	--print(dump(tempTable))
	--print("tempTable ^ ")
	obj:queueGameEngineLua("positionGE.sendVehiclePosRot(\'"..jsonEncode(tempTable).."\', \'"..obj:getID().."\')") -- Send it
end

local function setVehiclePosRot(pos, vel, rot, rvel, tim)

	-- Package data for storing in buffer
	local data = {
		pos = pos,
		vel = vel or vec3(0,0,0),
		rot = rot or quat(0,0,0,0),
		rvel = rvel or vec3(0,0,0),
		remoteTime = tim or 0,
		localTime = timer
	}

	buffer:push_right(data)
end



M.updateGFX = updateGFX
M.getVehicleRotation = getVehicleRotation
M.setVehiclePosRot = setVehiclePosRot


return M
