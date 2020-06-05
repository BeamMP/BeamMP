--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}

-- ============= VARIABLES =============
local timeDiffSmoother = newTemporalSmoothingNonLinear(1)
local posCorrectMul = 5        -- How much acceleration to use for correcting position error
local maxPosError = 10         -- If position error is larger than this, teleport the vehicle
local rotCorrectMul = 2        -- How much acceleration to use for correcting angle error

local timer = 0
local data = nil
local ping = 0
-- ============= VARIABLES =============

local function setPing(p)
	ping = p
end

local function updateGFX(dt)
	timer = timer + dt

	-- If there is no data, skip everything
	if not data then return end
	
	-- Smoothed difference between local and remote timestamps
	local packetTimeDiff = timeDiffSmoother:get(data.localOffset, dt)
	
	-- Calculate back to local time using the time at which the packet was sent and the smoothed time difference
	local calcLocalTime = data.remoteTime + packetTimeDiff
	
	-- Get difference between calculated and actual local time
	local timeDiff = timer - calcLocalTime
	
	-- How far ahead the position needs to be predicted
	local predictTime = timeDiff + ping

	-- Extrapolate position where the car should be right now
	local pos = data.pos + data.vel*predictTime + 0.5*data.acc*predictTime*predictTime
	local vel = data.vel + data.acc*predictTime
	local rvelAdd = data.rvel*predictTime + 0.5*data.racc*predictTime*predictTime
	local rot = data.rot * quatFromEuler(rvelAdd.y, rvelAdd.z, rvelAdd.x)
	local rvel = data.rvel + data.racc*predictTime

	--DEBUG
	local debugDrawer = obj.debugDrawProxy
	debugDrawer:drawSphere(0.8, data.pos:toFloat3(), color(0,0,255,255))
	debugDrawer:drawSphere(0.8, pos:toFloat3(), color(0,255,0,255))

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
end

local function getVehicleRotation()
	local tempTable = {}
	local pos = obj:getPosition()
	local vel = obj:getVelocity()
	local rot = obj:getRotation()
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

local function setVehiclePosRot(pos, vel, rot, rvel, tim, realtime)

	--local processDelay = Engine.Platform.getRealMilliseconds() - realtime
	--print("Position packet processing delay: "..processDelay)
	
	if data then
		local remoteDT = tim - data.remoteTime
		
		-- If packets arrive in wrong order, only keep newest one
		if remoteDT < 0 then
			print("Wrong position packet order! Vehicle ID: "..obj:getID()..", Old Timestamp: "..data.remoteTime..", New Timestamp: "..tim)
			--return
		end
		
		local acc = (vel - data.vel)/remoteDT
		local racc = (rvel - data.rvel)/remoteDT
	end
	
	-- Package data for storing
	data = {
		pos = pos,
		vel = vel or vec3(0,0,0),
		acc = acc or vec3(0,0,0),
		rot = rot or quat(0,0,0,0),
		rvel = rvel or vec3(0,0,0),
		racc = racc or vec3(0,0,0),
		remoteTime = tim or 0,
		localOffset = timer-tim or 0
	}

end



M.updateGFX = updateGFX
M.getVehicleRotation = getVehicleRotation
M.setVehiclePosRot = setVehiclePosRot
M.setPing = setPing


return M
