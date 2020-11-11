--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}

-- Smoothing for vectors, original temporalSmoothingNonLinear created by BeamNG
local vectorSmoothing = {}
vectorSmoothing.__index = vectorSmoothing

local function newVectorSmoothing(rate)
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
local posForceMul = 5          -- How much acceleration is used to correct velocity
local minPosForce = 0.1        -- If force is smaller than this, ignore to save performance
local maxAcc = 500             -- Maximum acceleration (m/s^2)
local maxPosError = 3          -- Max allowed continuous position error (m)
local maxAccError = 3          -- If difference between target and actual acceleration larger than this, decrease force

-- Rotation
local rotCorrectMul = 7        -- How much velocity to use for correcting angle error (rad/s per rad)
local rotForceMul = 7          -- How much acceleration is used to correct angular velocity
local minRotForce = 0.05       -- If force is smaller than this, ignore to save performance
local maxRacc = 500            -- Maximum angular acceleration (rad/s^2)
local maxRotError = 2          -- Max allowed rotation error (rad)
local maxRaccError = 3         -- If difference between target and actual angular acceleration larger than this, decrease force

-- Prediction
local maxPredict = 0.3         -- Maximum prediction limit (s)
local packetTimeout = 0.1      -- Stop prediction if no packet received within this time (s)

-- Smoothing
local remoteVelSmoother = newVectorSmoothing(2)             -- Smoother for received velocity
local remoteRvelSmoother = newVectorSmoothing(2)            -- Smoother for received angular velocity
local remoteAccSmoother = newVectorSmoothing(1)             -- Smoother for acceleration calculated from received data
local remoteRaccSmoother = newVectorSmoothing(1)            -- Smoother for angular acceleration calculated from received data
local accErrorSmoother = newVectorSmoothing(50)             -- Smoother for acceleration error
local raccErrorSmoother = newVectorSmoothing(50)            -- Smoother for angular acceleration error
local timeOffsetSmoother = newTemporalSmoothingNonLinear(1) -- Smoother for getting average time offset

-- Persistent data
local timer = 0
local ownPing = 0
local lastDT = 0

local lastVehVel = nil
local lastVehRvel = nil

local lastAcc = nil
local lastRacc = nil

local tpTimer = 0

local remoteData = {
	pos = nil,
	vel = vec3(0,0,0),
	acc = vec3(0,0,0),
	rot = quat(0,0,0,0),
	rvel = vec3(0,0,0),
	racc = vec3(0,0,0),
	timer = 0,
	timeOffset = 0,
	recTime = 0
}

local debugDrawer = obj.debugDrawProxy

local abs = math.abs
local min = math.min
local max = math.max

-- ============= VARIABLES =============

local function setPing(p)
	-- some ping packets seem to go missing on local servers
	if p < 0.99 or p > 1.01 then
		ownPing = p
	end
end

local function updateGFX(dt)
	timer = timer + dt
	lastDT = dt

	if not remoteData.pos or (timer-remoteData.recTime) > packetTimeout then return end

	-- Local vehicle data
	local vehPos = vec3(obj:getPosition())
	local vehVel = vec3(obj:getVelocity())
	local vehAcc = vehVel-(lastVehVel or vehVel)

	local vehRot = quat(obj:getRotation())
	local vehRvel = vec3(obj:getYawAngularVelocity(), obj:getPitchAngularVelocity(), obj:getRollAngularVelocity())
	local vehRacc = vehRvel-(lastVehRvel or vehRvel)

	lastVehVel = vehVel
	lastVehRvel = vehRvel

	-- Smoothed difference between local and remote timestamps
	local timeOffset = timeOffsetSmoother:get(remoteData.timeOffset, dt)
	if abs(timeOffset - remoteData.timeOffset) > 1 then
		timeOffsetSmoother:set(remoteData.timeOffset)
		timeOffset = remoteData.timeOffset
	end

	-- Calculate back to local time using the remote timestamp and the smoothed time difference
	local calcLocalTime = remoteData.timer + timeOffset

	-- How far ahead the position needs to be predicted
	local predictTime = min(max(timer - calcLocalTime, -maxPredict), maxPredict)

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

	--[[
	-- Debug
	debugDrawer:drawSphere(0.3, remoteData.pos:toFloat3(), color(0,0,255,255))
	debugDrawer:drawLine(remoteData.pos:toFloat3(), (remoteData.pos + vec3(0,-5,0):rotated(remoteData.rot)):toFloat3(), color(0,0,255,255))
	debugDrawer:drawSphere(0.3, pos:toFloat3(), color(0,255,0,255))
	debugDrawer:drawLine(pos:toFloat3(), (pos + vec3(0,-5,0):rotated(rot)):toFloat3(), color(0,255,0,255))
	debugDrawer:drawText(pos:toFloat3(), color(0,0,0,255), string.format("Prediction: %.0f ms", predictTime*1000))
	--]]

	-- Error correction
	local posError = pos - vehPos
	local rotError = (rot / vehRot):toEulerYXZ()

	if posError:length() > maxPosError or rotError:length() > maxRotError then
		tpTimer = tpTimer + dt
		posError = posError:normalized()*maxPosError
	else
		tpTimer = 0
	end

	-- If position error is larger than limit, teleport the vehicle
	if tpTimer > abs(predictTime)*2 then
		if rotError:length() > maxRotError then
			-- Resets the vehicle, try to avoid unless absolutely necessary
			obj:queueGameEngineLua("vehicleSetPositionRotation("..obj:getID()..","..pos.x..","..pos.y..","..pos.z..","..rot.x..","..rot.y..","..rot.z..","..rot.w..")")
		else
			obj:queueGameEngineLua("positionGE.setPosition("..obj:getID()..","..pos.x..","..pos.y..","..pos.z..")")
		end

		velocityVE.setAngularVelocity(vel.x, vel.y, vel.z, rvel.y, rvel.z, rvel.x)

		remoteVelSmoother:set(remoteData.vel)
		remoteRvelSmoother:set(remoteData.rvel)

		remoteData.acc = vec3(0,0,0)
		remoteData.racc = vec3(0,0,0)
		remoteAccSmoother:reset()
		remoteRaccSmoother:reset()

		lastAcc = nil

		accErrorSmoother:reset()
		raccErrorSmoother:reset()

		return
	end

	local velError = vel - vehVel
	local accError = accErrorSmoother:get((lastAcc or vehAcc) - vehAcc, dt)
	--print("AccError: "..tostring(accError:length()/dt))

	local rvelError = rvel - vehRvel
	local raccError = raccErrorSmoother:get((lastRacc or vehRacc) - vehRacc, dt)
	--print("RaccError: "..tostring(raccError:length()/dt))

	local targetAcc = (velError + posError*posCorrectMul)*min(posForceMul*dt,1)
	local targetRacc = (rvelError + rotError*rotCorrectMul)*min(rotForceMul*dt,1)

	local targetAccMul = 1-min(max(targetAcc:dot(accError)/(targetAcc:squaredLength()+maxAccError*maxAccError*dt),0),1)
	--print("Force multiplier: "..targetAccMul)
	targetAcc = targetAcc*targetAccMul

	local targetRaccMul = 1-min(max(targetRacc:dot(raccError)/(targetRacc:squaredLength()+maxRaccError*maxRaccError*dt),0),1)
	--print("Rotation force multiplier: "..targetRaccMul)
	targetRacc = targetRacc*targetRaccMul

	--print("targetAcc: "..targetAcc:length())
	--print("targetRacc: "..targetRacc:length())
	if targetRacc:length() > minRotForce then
		velocityVE.addAngularVelocity(targetAcc.x, targetAcc.y, targetAcc.z, targetRacc.y, targetRacc.z, targetRacc.x)
	elseif targetAcc:length() > minPosForce then
		velocityVE.addVelocity(targetAcc.x, targetAcc.y, targetAcc.z)
	end

	lastAcc = targetAcc
	lastRacc = targetRacc
end

local function getVehicleRotation()
	local pos = obj:getPosition()
	local vel = obj:getVelocity()
	local rot = obj:getRotation()
	local tempTable = {
		pos = {
			x = pos.x,
			y = pos.y,
			z = pos.z
		},
		vel = {
			x = vel.x,
			y = vel.y,
			z = vel.z
		},
		rot = {
			x = rot.x,
			y = rot.y,
			z = rot.z,
			w = rot.w
		},
		rvel = {
			x = obj:getPitchAngularVelocity(),
			y = obj:getYawAngularVelocity(),
			z = obj:getRollAngularVelocity()
		},
		tim = timer,
		ping = ownPing + lastDT
	}
	obj:queueGameEngineLua("positionGE.sendVehiclePosRot(\'"..jsonEncode(tempTable).."\', \'"..obj:getID().."\')") -- Send it
end

local function setVehiclePosRot(data)

	local pr   = jsonDecode(data)
	local pos  = vec3(pr.pos.x, pr.pos.y, pr.pos.z)
	local vel  = vec3(pr.vel.x, pr.vel.y, pr.vel.z)
	local rot  = quat(pr.rot.x, pr.rot.y, pr.rot.z, pr.rot.w)
	local rvel = vec3(pr.rvel.x, pr.rvel.y, pr.rvel.z)
	local tim  = pr.tim
	local ping = pr.ping

	local remoteDT = max(tim - remoteData.timer, 0.001)

	-- Sanity checks for acceleration
	if vel:length() < (remoteData.vel:length() + maxAcc*remoteDT) then
		remoteData.acc = (vel - remoteData.vel)/remoteDT
		remoteData.vel = vel
	else
		--print("Acceleration too high! Vehicle ID: "..obj:getID())
		remoteData.acc = vec3(0,0,0)
		remoteData.vel = vel:normalized()*(vel:length()+maxAcc*remoteDT)
	end

	if rvel:length() < (remoteData.rvel:length() + maxRacc*remoteDT) then
		remoteData.racc = (rvel - remoteData.rvel)/remoteDT
		remoteData.rvel = rvel
	else
		--print("Angular acceleration too high! Vehicle ID: "..obj:getID())
		remoteData.racc = vec3(0,0,0)
		remoteData.rvel = rvel:normalized()*(rvel:length()+maxRacc*remoteDT)
	end

	remoteData.pos = pos
	remoteData.rot = rot
	remoteData.timer = tim
	remoteData.timeOffset = timer-tim - ownPing/2 - ping/2 - lastDT
	remoteData.recTime = timer

	--print("OwnPing = "..ownPing.." Ping = "..ping)
	obj:queueGameEngineLua("UI.setVehPing(\'"..obj:getID().."\', \'".. math.floor(ping*1000) .."\')") -- Send ping
end

M.updateGFX = updateGFX
M.getVehicleRotation = getVehicleRotation
M.setVehiclePosRot = setVehiclePosRot
M.setPing = setPing


return M
