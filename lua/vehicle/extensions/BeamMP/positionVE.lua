--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}

-- Smoothing for vectors, original temporalSmoothingNonLinear created by BeamNG
local vectorSmoothing = {}
vectorSmoothing.__index = vectorSmoothing

function newVectorSmoothing(rate)
  local data = {rate = rate or 10, state = vec3(0,0,0)}
  setmetatable(data, vectorSmoothing)
  return data
end

function vectorSmoothing:get(sample, dt)
  local st = self.state
  local dif = sample - st
  st = st + dif * math.min(self.rate * dt, 1)
  self.state = st
  return st
end

function vectorSmoothing:set(sample)
  self.state = sample
end

function vectorSmoothing:reset()
  self.state = vec3(0,0,0)
end

-- ============= VARIABLES =============
-- Position
local posCorrectMul = 7        -- How much acceleration to use for correcting position error
local posForceMul = 0.1        -- How much acceleration is used to correct velocity (between 0 and 1)

-- Rotation
local rotCorrectMul = 5        -- How much acceleration to use for correcting angle error
local rotForceMul = 0.1        -- How much acceleration is used to correct angular velocity (between 0 and 1)

-- Prediction
local disableTimeMul = 0--1.5     -- At collision, position correction is disabled for ping*disableTimeMul to wait for data
local maxAccErrorMul = 1       -- Which amount of acceleration error is detected as a collision
local minAccError = 30         -- Minimum acceleration error to be detected as a collision
local maxPosError = 5          -- If position error is larger than this, teleport the vehicle
local remoteAccSmoother = newVectorSmoothing(5)             -- Smoother for acceleration calculated from received data
local remoteRaccSmoother = newVectorSmoothing(5)            -- Smoother for angular acceleration calculated from received data
local vehAccSmoother = newVectorSmoothing(20)               -- Smoother for acceleration of locally simulated vehicle
local accErrorSmoother = newVectorSmoothing(20)             -- Smoother for acceleration error
local timeOffsetSmoother = newTemporalSmoothingNonLinear(1) -- Smoother for getting average time offset

-- Persistent data
local timer = 0
local disableUntil = 0
local ping = 0

local lastVehVel = nil
local lastVehRvel = nil

local lastAcc = nil

local remoteData = {
	pos = vec3(0,0,0),
	vel = vec3(0,0,0),
	acc = vec3(0,0,0),
	rot = quat(0,0,0,0),
	rvel = vec3(0,0,0),
	racc = vec3(0,0,0),
	timer = 0,
	timeOffset = 0
}

local debugDrawer = obj.debugDrawProxy

-- ============= VARIABLES =============

local function setPing(p)
	ping = p
end

local function updateGFX(dt)
	timer = timer + dt
	
	if remoteData.pos:length() < 1 or remoteData.timer < 1 then
		return
	end
	
	-- Local vehicle data
	local vehPos = vec3(obj:getPosition())
	local vehVel = vec3(obj:getVelocity())
	local vehAcc = vehAccSmoother:get((vehVel-(lastVehVel or vehVel))/dt, dt)
	
	local vehRot = quat(obj:getRotation())
	local vehRvel = vec3(obj:getYawAngularVelocity(), obj:getPitchAngularVelocity(), obj:getRollAngularVelocity())
	--local vehRacc = (vehRvel-(lastVehRvel or vehRvel))/dt
	
	if not lastAcc then
		lastAcc = vehAcc
	end
	
	lastVehVel = vehVel
	--lastVehRvel = vehRvel
	
	-- Smoothed difference between local and remote timestamps
	local timeOffset = timeOffsetSmoother:get(remoteData.timeOffset, dt)
	local remoteAcc = remoteAccSmoother:get(remoteData.acc, dt)
	local remoteRacc = remoteRaccSmoother:get(remoteData.racc, dt)
	
	if math.abs(timeOffset - remoteData.timeOffset) > 1 then
		timeOffsetSmoother:set(remoteData.timeOffset)
		timeOffset = remoteData.timeOffset
	end
	
	-- If prediction is disabled, stop here
	if remoteData.timer < disableUntil then
		debugDrawer:drawSphere(2, obj:getPosition(), color(255,0,0,150))
		return
	end
	
	-- Calculate back to local time using the remote timestamp and the smoothed time difference
	local calcLocalTime = remoteData.timer + timeOffset
	
	-- Get difference between calculated and actual local time
	local timeDiff = timer - calcLocalTime
	
	-- How far ahead the position needs to be predicted
	local predictTime = timeDiff + ping

	-- Use received position, velocity, and acceleration to predict vehicle position
	local pos = remoteData.pos + remoteData.vel*predictTime + 0.5*remoteAcc*predictTime*predictTime
	local vel = remoteData.vel + remoteAcc*predictTime
	local rotAdd = remoteData.rvel*predictTime + 0.5*remoteRacc*predictTime*predictTime
	local rot = remoteData.rot * quatFromEuler(rotAdd.y, rotAdd.z, rotAdd.x)
	local rvel = remoteData.rvel + remoteRacc*predictTime

	--DEBUG
	debugDrawer:drawSphere(0.3, remoteData.pos:toFloat3(), color(0,0,255,255))
	debugDrawer:drawSphere(0.3, pos:toFloat3(), color(0,255,0,255))
	
	-- Error correction
	local posError = pos - vehPos
	local rotError = (rot / vehRot):toEulerYXZ()
	
	-- If position error is larger than limit, teleport the vehicle
	if posError:length() > maxPosError then
		print("PosError = " .. tostring(posError))

		obj:queueGameEngineLua("positionGE.setPosition("..obj:getID()..","..pos.x..","..pos.y..","..pos.z..")")
		velocityVE.setVelocity(vel.x, vel.y, vel.z)
		velocityVE.setAngularVelocity(rvel.y, rvel.z, rvel.x)
		
		lastAcc = nil
		
		vehAccSmoother:reset()
		accErrorSmoother:reset()
	
		return
	end
	
	local velError = vel - vehVel
	local accError = accErrorSmoother:get(lastAcc - vehAcc, dt)
	
	local rvelError = rvel - vehRvel
	--local raccError = racc - vehRacc
	
	-- Disable prediction if acceleration error is larger than threshold
	if accError:length() > math.max(minAccError, lastAcc:length()*maxAccErrorMul) then
		disableUntil = remoteData.timer + predictTime*disableTimeMul
		
		print("Prediction disabled! accError: "..accError:length().." > "..lastAcc:length()*maxAccErrorMul)
		
		lastAcc = nil
		
		accErrorSmoother:reset()
		
		return
	end
	
	local targetAcc = (velError + posError*posCorrectMul)*posForceMul
	local targetRacc = (rvelError + rotError*rotCorrectMul)*rotForceMul
	
	velocityVE.addVelocity(targetAcc.x, targetAcc.y, targetAcc.z)
	velocityVE.addAngularVelocity(targetRacc.y, targetRacc.z, targetRacc.x)
	
	lastAcc = targetAcc / dt
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

	--TODO: Engine.Platform does not work in vehicle lua, find other way to get real time
	--local processDelay = Engine.Platform.getRealMilliseconds() - realtime
	--print("Position packet processing delay: "..processDelay)
	
	local remoteDT = tim - remoteData.timer
	
	-- If packets arrive in wrong order, print warning message
	if remoteDT < 0 then
		print("Wrong position packet order! Vehicle ID: "..obj:getID()..", Old Timestamp: "..remoteData.timer..", New Timestamp: "..tim)
		
		-- Vehicle probably reset, so also reset disable time
		if tim < 1 then
			disableUntil = 0
		end
		
		--return
	end
	
	remoteData.acc = (vel - remoteData.vel)/math.max(remoteDT, 0.005)
	remoteData.racc = (rvel - remoteData.rvel)/math.max(remoteDT, 0.005)
	
	remoteData.pos = pos
	remoteData.vel = vel
	remoteData.rot = rot
	remoteData.rvel = rvel
	remoteData.timer = tim
	remoteData.timeOffset = timer-tim

end



M.updateGFX = updateGFX
M.getVehicleRotation = getVehicleRotation
M.setVehiclePosRot = setVehiclePosRot
M.setPing = setPing


return M
