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
local posCorrectMul = 5        -- How much velocity to use for correcting position error
local posForceMul = 0.1        -- How much acceleration is used to correct velocity (between 0 and 1)

-- Rotation
local rotCorrectMul = 5        -- How much velocity to use for correcting angle error
local rotForceMul = 0.1        -- How much acceleration is used to correct angular velocity (between 0 and 1)

-- Prediction
local maxPredict = 1           -- Timeout for prediction in seconds
local maxPosError = 5          -- If position error is larger than this, teleport the vehicle
local remoteVelSmoother = newVectorSmoothing(1)             -- Smoother for received velocity
local remoteRvelSmoother = newVectorSmoothing(1)            -- Smoother for received angular velocity
local remoteAccSmoother = newVectorSmoothing(1)             -- Smoother for acceleration calculated from received data
local remoteRaccSmoother = newVectorSmoothing(1)            -- Smoother for angular acceleration calculated from received data
local vehAccSmoother = newVectorSmoothing(5)                -- Smoother for acceleration of locally simulated vehicle
local accErrorSmoother = newVectorSmoothing(1)              -- Smoother for acceleration error
local timeOffsetSmoother = newTemporalSmoothingNonLinear(1) -- Smoother for getting average time offset

-- Persistent data
local timer = 0
local ping = 0

local lastVehVel = nil
local lastVehRvel = nil

local lastAcc = nil

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
	
	if math.abs(timeOffset - remoteData.timeOffset) > 1 then
		timeOffsetSmoother:set(remoteData.timeOffset)
		timeOffset = remoteData.timeOffset
	end
	
	-- Calculate back to local time using the remote timestamp and the smoothed time difference
	local calcLocalTime = remoteData.timer + timeOffset
	
	-- How far ahead the position needs to be predicted
	local predictTime = timer - calcLocalTime + ping
	
	if predictTime > maxPredict then
		print("Prediction timeout! Vehicle ID: "..obj:getID())
		return
	end
	
	-- More prediction = slower smoothing
	local smootherDT = dt / guardZero(math.abs(predictTime))
	
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
	local accError = accErrorSmoother:get((lastAcc or vehAcc) - vehAcc, dt)
	
	local rvelError = rvel - vehRvel
	--local raccError = racc - vehRacc
	
	local targetAcc = (velError + posError*posCorrectMul)*posForceMul
	local targetRacc = (rvelError + rotError*rotCorrectMul)*rotForceMul
	
	--local targetAccMul = 1-math.max(math.min(targetAcc:dot(accError)/accError:squaredLength(),1),0)
	
	velocityVE.addVelocity(targetAcc.x, targetAcc.y, targetAcc.z)
	velocityVE.addAngularVelocity(targetRacc.y, targetRacc.z, targetRacc.x)
	
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

	local remoteDT = tim - remoteData.timer
	
	-- If packets arrive in wrong order, print warning message
	if remoteDT < 0 then
		print("Wrong position packet order! Vehicle ID: "..obj:getID()..", Old Timestamp: "..remoteData.timer..", New Timestamp: "..tim)
		
		--return
	end
	
	remoteData.acc = (vel - remoteData.vel)/math.max(remoteDT, 0.01)
	remoteData.racc = (rvel - remoteData.rvel)/math.max(remoteDT, 0.01)
	
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
