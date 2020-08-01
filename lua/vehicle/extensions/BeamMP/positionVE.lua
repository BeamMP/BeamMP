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
local posCorrectMul = 5        -- How much velocity to use for correcting position error (m/s per m)
local posForceMul = 0.1        -- How much acceleration is used to correct velocity (0.1 = 10% per frame, 1 = instant)
local minPosForce = 0.1        -- If force is smaller than this, ignore to save performance
local maxAcc = 1000            -- Maximum acceleration (m/s^2)

-- Rotation
local rotCorrectMul = 5        -- How much velocity to use for correcting angle error (rad/s per rad)
local rotForceMul = 0.1        -- How much acceleration is used to correct angular velocity (0.1 = 10% per frame, 1 = instant)
local minRotForce = 0.05       -- If force is smaller than this, ignore to save performance
local maxRacc = 1000           -- Maximum angular acceleration (rad/s^2)

-- Prediction
local maxPredict = 1           -- Timeout for prediction (s)
local maxPosError = 2          -- Max allowed continuous position error (m)
local teleportThreshold = 3    -- Max accumulated position error before teleporting vehicle (5 = 5m for 1s, 10m for 0.5s, ...)
local remoteVelSmoother = newVectorSmoothing(2)             -- Smoother for received velocity
local remoteRvelSmoother = newVectorSmoothing(2)            -- Smoother for received angular velocity
local remoteAccSmoother = newVectorSmoothing(2)             -- Smoother for acceleration calculated from received data
local remoteRaccSmoother = newVectorSmoothing(2)            -- Smoother for angular acceleration calculated from received data
local vehAccSmoother = newVectorSmoothing(5)                -- Smoother for acceleration of locally simulated vehicle
local accErrorSmoother = newVectorSmoothing(1)              -- Smoother for acceleration error
local timeOffsetSmoother = newTemporalSmoothingNonLinear(2) -- Smoother for getting average time offset

-- Persistent data
local timer = 0
local ping = 0

local lastVehVel = nil
local lastVehRvel = nil

local lastAcc = nil

local accPosError = 0

local remoteData = {
	pos = nil,
	vel = vec3(0,0,0),
	acc = vec3(0,0,0),
	rot = quat(0,0,0,0),
	rvel = vec3(0,0,0),
	racc = vec3(0,0,0),
	timer = 0,
	timeOffset = 0
}

local debugDrawer = obj.debugDrawProxy

local abs = math.abs
local max = math.max

-- ============= VARIABLES =============

local function setPing(p)
	ping = p
end

local function updateGFX(dt)
	timer = timer + dt
	
	if not remoteData.pos then
		return
	end
	
	-- Local vehicle data
	local vehPos = vec3(obj:getPosition())
	local vehVel = vec3(obj:getVelocity())
	local vehAcc = vehAccSmoother:get(vehVel-(lastVehVel or vehVel), dt)
	
	local vehRot = quat(obj:getRotation())
	local vehRvel = vec3(obj:getYawAngularVelocity(), obj:getPitchAngularVelocity(), obj:getRollAngularVelocity())
	--local vehRacc = (vehRvel-(lastVehRvel or vehRvel))/dt
	
	lastVehVel = vehVel
	--lastVehRvel = vehRvel
	
	-- Smoothed difference between local and remote timestamps
	local timeOffset = timeOffsetSmoother:get(remoteData.timeOffset, dt)
	
	if abs(timeOffset - remoteData.timeOffset) > 1 then
		timeOffsetSmoother:set(remoteData.timeOffset)
		timeOffset = remoteData.timeOffset
	end
	
	-- Calculate back to local time using the remote timestamp and the smoothed time difference
	local calcLocalTime = remoteData.timer + timeOffset
	
	-- How far ahead the position needs to be predicted
	local predictTime = timer - calcLocalTime + ping
	
	if predictTime > maxPredict then
		--print("Prediction timeout! Vehicle ID: "..obj:getID())
		return
	end
	
	-- More prediction = slower smoothing
	local smootherDT = dt / guardZero(abs(predictTime))
	
	local remoteVel = remoteVelSmoother:get(remoteData.vel, smootherDT)
	local remoteRvel = remoteRvelSmoother:get(remoteData.rvel, smootherDT)
	local remoteAcc = remoteAccSmoother:get(remoteData.acc, smootherDT)
	local remoteRacc = remoteRaccSmoother:get(remoteData.racc, smootherDT)
	
	-- Use received position, and smoothed velocity and acceleration to predict vehicle position
	local pos = remoteData.pos + remoteVel*predictTime + 0.5*remoteAcc*predictTime*predictTime
	local vel = remoteVel + remoteAcc*predictTime
	local rotAdd = remoteRvel*predictTime + 0.5*remoteRacc*predictTime*predictTime
	local rot = remoteData.rot * quatFromEuler(rotAdd.y, rotAdd.z, rotAdd.x)
	local rvel = remoteRvel + remoteRacc*predictTime

	--DEBUG
	debugDrawer:drawSphere(0.3, remoteData.pos:toFloat3(), color(0,0,255,255))
	debugDrawer:drawSphere(0.3, pos:toFloat3(), color(0,255,0,255))
	
	-- Error correction
	local posError = pos - vehPos
	local rotError = (rot / vehRot):toEulerYXZ()
	
	local posErrLen = posError:length()
	if posErrLen > maxPosError then
		accPosError = accPosError + posErrLen*dt
	else
		accPosError = 0
	end
	
	-- If position error is larger than limit, teleport the vehicle
	if accPosError > teleportThreshold then
		obj:queueGameEngineLua("positionGE.setPosition("..obj:getID()..","..pos.x..","..pos.y..","..pos.z..")")
		--obj:queueGameEngineLua("vehicleSetPositionRotation("..obj:getID()..","..pos.x..","..pos.y..","..pos.z..","..rot.x..","..rot.y..","..rot.z..","..rot.w..")")
		
		--velocityVE.setVelocity(vel.x, vel.y, vel.z)
		velocityVE.setAngularVelocity(vel.x, vel.y, vel.z, rvel.y, rvel.z, rvel.x)
		
		remoteVelSmoother:set(vel)
		remoteRvelSmoother:set(rvel)
		remoteAccSmoother:reset()
		remoteRaccSmoother:reset()
		
		lastAcc = nil
		
		vehAccSmoother:reset()
		accErrorSmoother:reset()
	
		return
	end
	
	local velError = vel - vehVel
	local accError = accErrorSmoother:get((lastAcc or vehAcc) - vehAcc, dt)
	
	local rvelError = rvel - vehRvel
	--local raccError = racc - vehRacc
	
	local targetAcc = (velError + posError*posCorrectMul)*posForceMul
	local targetRacc = (rvelError + rotError*rotCorrectMul)*rotForceMul
	
	--local targetAccMul = 1-math.max(math.min(targetAcc:dot(accError)/accError:squaredLength(),1),0)
	
	--print("targetAcc: "..targetAcc:length())
	--print("targetRacc: "..targetRacc:length())
	if targetRacc:length() > minRotForce then
		velocityVE.addAngularVelocity(targetAcc.x, targetAcc.y, targetAcc.z, targetRacc.y, targetRacc.z, targetRacc.x)
	elseif targetAcc:length() > minPosForce then
		velocityVE.addVelocity(targetAcc.x, targetAcc.y, targetAcc.z)
	end
	
	lastAcc = targetAcc
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

local function setVehiclePosRot(pos, vel, rot, rvel, tim)

	local remoteDT = guardZero(tim - remoteData.timer)
	
	-- If packets arrive in wrong order, print warning message
	if remoteDT < 0 then
		print("Wrong position packet order! Vehicle ID: "..obj:getID()..", Old Timestamp: "..remoteData.timer..", New Timestamp: "..tim)
		
		--return
	end
	
	-- Sanity checks for acceleration
	if vel:length() < (remoteData.vel:length() + maxAcc*remoteDT) then
		remoteData.acc = (vel - remoteData.vel)/remoteDT
		remoteData.vel = vel
	else
		print("Acceleration too high! Vehicle ID: "..obj:getID())
		remoteData.acc = vec3(0,0,0)
	end
	if rvel:length() < (remoteData.rvel:length() + maxRacc*remoteDT) then
		remoteData.racc = (rvel - remoteData.rvel)/remoteDT
		remoteData.rvel = rvel
	else
		print("Angular acceleration too high! Vehicle ID: "..obj:getID())
		remoteData.racc = vec3(0,0,0)
	end
	
	remoteData.pos = pos
	remoteData.rot = rot
	remoteData.timer = tim
	remoteData.timeOffset = timer-tim

end



M.updateGFX = updateGFX
M.getVehicleRotation = getVehicleRotation
M.setVehiclePosRot = setVehiclePosRot
M.setPing = setPing


return M
