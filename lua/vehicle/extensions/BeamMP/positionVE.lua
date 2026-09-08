-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}



local abs = math.abs
local min = math.min
local max = math.max
local sqrt = math.sqrt



-- =============================== SOME FUNCTIONS ===============================
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
  local rate = min(self.rate * dt, 1)
  st.x = st.x + (sample.x - st.x)*rate
  st.y = st.y + (sample.y - st.y)*rate
  st.z = st.z + (sample.z - st.z)*rate
  return st
end

function vectorSmoothing:set(sample)
  self.state = sample
end

function vectorSmoothing:reset()
  self.state = vec3(0,0,0)
end
-- =============================== SOME FUNCTIONS ===============================



-- ============= VARIABLES =============
-- Position
local posCorrectMul = 5        -- How much velocity to use for correcting position error (m/s per m)
local posForceMul = 5          -- How much acceleration is used to correct velocity
local minPosForce = 0.04       -- If force is smaller than this, ignore to save performance
local maxPosForce = 100        -- Maximum position correction force (m/s^2)
local maxAcc = 100             -- Maximum acceleration in received data (m/s^2)
local maxAccError = 3          -- If difference between target and actual acceleration larger than this, decrease force

-- Rotation
local rotCorrectMul = 7        -- How much velocity to use for correcting angle error (rad/s per rad)
local rotForceMul = 7          -- How much acceleration is used to correct angular velocity
local minRotForce = 0.02       -- If force is smaller than this, ignore to save performance
local maxRotForce = 50         -- Maximum rotation correction force (rad/s^2)
local maxRacc = 50             -- Maximum angular acceleration in received data (rad/s^2)
local maxRaccError = 3         -- If difference between target and actual angular acceleration larger than this, decrease force

-- Teleport
local tpDelayAdd = 1           -- Additional teleport delay (s)
local tpDistAdd = 1            -- Additional teleport distance (m)
local tpDistMul1 = 0.1         -- Multiplier for delayed teleport distance based on velocity (m per m/s)
local tpDistMul2 = 0.5         -- Multiplier for instant teleport distance based on velocity (m per m/s)
local tpRotAdd = 0.5           -- Additional teleport rotation (rad)
local tpRotMul1 = 0.2          -- Multiplier for delayed teleport rotation based on rotation velocity (rad per rad/s)
local tpRotMul2 = 0.5          -- Multiplier for instant teleport rotation based on rotation velocity (rad per rad/s)
local tpVelSmoother = newTemporalSmoothingNonLinear(2,1000)  -- Smoother for filtering low velocities during collisions
local tpRvelSmoother = newTemporalSmoothingNonLinear(2,1000) -- Smoother for filtering low rotation velocities during collisions

-- Prediction
local maxPredict = 0.3         -- Maximum prediction limit (s)
local packetTimeout = 0.1      -- Stop prediction if no packet received within this time (s)

-- Smoothing
local localVelSmoother = newVectorSmoothing(50)             -- Smoother for local velocity
local localRvelSmoother = newVectorSmoothing(50)            -- Smoother for local angular velocity
local remoteVelSmoother = newVectorSmoothing(2)             -- Smoother for received velocity
local remoteRvelSmoother = newVectorSmoothing(2)            -- Smoother for received angular velocity
local remoteAccSmoother = newVectorSmoothing(1)             -- Smoother for acceleration calculated from received data
local remoteRaccSmoother = newVectorSmoothing(1)            -- Smoother for angular acceleration calculated from received data
local accErrorSmoother = newVectorSmoothing(50)             -- Smoother for acceleration error
local raccErrorSmoother = newVectorSmoothing(50)            -- Smoother for angular acceleration error
local timeOffsetSmoother = newTemporalSmoothingNonLinear(1) -- Smoother for getting average time offset

-- Persistent data
local lastMailboxVersion = 0
local framesSinceReset = 0
local timer = 0
local ownPing = 0
local lastDT = 0

local lastVehVel = nil
local lastVehRvel = nil

local lastAcc = nil
local lastRacc = nil

local tpTimer = 0

local remoteData = {
	pos = vec3(0,0,0),
	vel = vec3(0,0,0),
	acc = vec3(0,0,0),
	rot = quat(0,0,0,0),
	rvel = vec3(0,0,0),
	racc = vec3(0,0,0),
	timer = -1,
	timeOffset = 0,
	recTime = 0,
	localSimspeed = 1
}

local currentVel = vec3(0,0,0)
local currentRvel = vec3(0,0,0)

local smoothVel = vec3(0,0,0)
local smoothRvel = vec3(0,0,0)

local physHandlerAdded = false

local debugDrawer = obj.debugDrawProxy

local simSpeedReal = 1

local stringBuffer = require("string.buffer")
local posSendBuffer = stringBuffer.new()
local posSendTable = {
	pos = {0, 0, 0},
	vel = {0, 0, 0},
	rot = {0, 0, 0, 0},
	rvel = {0, 0, 0},
	tim = 0,
	ping = 0
}

-- Cached variables for calculations
local dir = vec3()
local dirUp = vec3()
local rot = quat()
local cog = vec3()
local rvel = vec3()
local pos = vec3()
local vel = vec3()

local vehRot = quat()
local vehRvel = vec3()
local vehRacc = vec3()
local vehPos = vec3()
local vehVel = vec3()
local vehAcc = vec3()
-- ============= VARIABLES =============



local function setPing(p)
	-- some ping packets seem to go missing on local servers
	if p < 0.99 or p > 1.01 then
		ownPing = p
	end
end



-- Limit vector length
local function limitVecLength(vec, length)
	local sqLength = vec:squaredLength()

	if sqLength > length*length then
		vec:setScaled(length/sqrt(sqLength))
	end

	return vec
end



local function onReset()
	-- Reset smoothers and state variables
	localVelSmoother:reset()
	localRvelSmoother:reset()
	tpVelSmoother:reset()
	tpRvelSmoother:reset()
	remoteVelSmoother:reset()
	remoteRvelSmoother:reset()
	remoteAccSmoother:reset()
	remoteRaccSmoother:reset()
	accErrorSmoother:reset()
	raccErrorSmoother:reset()

	lastVehVel = nil
	lastVehRvel = nil

	lastAcc = nil
	lastRacc = nil

	smoothVel:set(0,0,0)
	smoothRvel:set(0,0,0)
	remoteData.acc:set(0,0,0)
	remoteData.racc:set(0,0,0)
	remoteData.timer = -1
	framesSinceReset = 0
	tpTimer = 0
end



local function update(dtSim)
	-- Smooth vehicle velocity to prevent vibrating
	currentVel.x, currentVel.y, currentVel.z = obj:getVelocityXYZ()
	currentRvel.y, currentRvel.x, currentRvel.z = obj:getRollPitchYawAngularVelocity()

	smoothVel = localVelSmoother:get(currentVel, dtSim)
	smoothRvel = localRvelSmoother:get(currentRvel, dtSim)
end



local function updateRemoteData()
	if not v.mpServerID or v.mpServerID == "" then return end
	local mailBoxName = "vehPosPckt" .. v.mpServerID
	local currentMailBoxVersion = obj:getLastMailboxVersion(mailBoxName)
	if lastMailboxVersion ~= currentMailBoxVersion then
		local jsonData = obj:getLastMailbox(mailBoxName)
		local pr = jsonDecode(jsonData)
		local tim  = pr.tim
		local ping = pr.ping
		local simspeedfraction = 1/simSpeedReal

		if not tim then return end
		if remoteData.timer > tim then return end

		local remoteDT = max(tim - remoteData.timer, 0.001)

		vel:set(pr.vel[1], pr.vel[2], pr.vel[3])
		rvel:set(pr.rvel[1], pr.rvel[2], pr.rvel[3])

		remoteData.pos:set(pr.pos[1], pr.pos[2], pr.pos[3])
		remoteData.rot:set(pr.rot[1], pr.rot[2], pr.rot[3], pr.rot[4])
		remoteData.acc:set(vel)
		remoteData.acc:setSub(remoteData.vel)
		remoteData.acc:setScaled(1/remoteDT)
		limitVecLength(remoteData.acc, maxAcc)
		remoteData.racc:set(rvel)
		remoteData.racc:setSub(remoteData.rvel)
		remoteData.racc:setScaled(1/remoteDT)
		limitVecLength(remoteData.racc, maxRacc)
		remoteData.vel:set(vel)
		remoteData.vel:setScaled(simspeedfraction)
		remoteData.rvel:set(rvel)
		remoteData.rvel:setScaled(simspeedfraction)
		remoteData.timer = tim
		remoteData.timeOffset = timer-tim - ownPing/2 - ping/2 - lastDT
		remoteData.recTime = timer
		remoteData.localSimspeed = math.min(simspeedfraction, 25)
	end
	lastMailboxVersion = currentMailBoxVersion
end



local function updateGFX(dt)
	updateRemoteData()
	dt = dt * (remoteData.localSimspeed or 1)
	timer = timer + dt
	lastDT = dt
	framesSinceReset = framesSinceReset + 1


	-- If there is no received data, or data is older than timeout, do nothing
	if v.mpVehicleType == "L" or remoteData.timer < 0 or (timer-remoteData.recTime) > packetTimeout then return end

	-- Local vehicle data
	dir:set(obj:getDirectionVectorXYZ())
	dir:setScaled(-1)
	dirUp:set(obj:getDirectionVectorUpXYZ())
	vehRot:setFromDir(dir, dirUp)
	vehRvel:set(smoothRvel)
	vehRvel:setRotate(vehRot)
	if lastVehRvel then
		vehRacc:set(vehRvel)
		vehRacc:setSub(lastVehRvel)
		lastVehRvel:set(vehRvel)
	else
		vehRacc:set(0,0,0)
		lastVehRvel = vehRvel:copy()
	end

	cog:set(velocityVE.cogRel)
	cog:setRotate(vehRot)
	vehPos:set(obj:getPositionXYZ())
	vehPos:setAdd(cog)
	vehVel:set(smoothVel)
	cog:setCross(cog, vehRvel)
	vehVel:setAdd(cog)
	if lastVehVel then
		vehAcc:set(vehVel)
		vehAcc:setSub(lastVehVel)
		lastVehVel:set(vehVel)
	else
		vehAcc:set(0,0,0)
		lastVehVel = vehVel:copy()
	end

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
	local predictTimeAcc = 0.5*predictTime*predictTime
	pos:set(push3(remoteData.pos) + push3(remoteVel)*predictTime + push3(remoteAcc)*predictTimeAcc)
	vel:set(push3(remoteVel) + push3(remoteAcc)*predictTime)
	local rotAdd = push3(remoteRvel)*predictTime + push3(remoteRacc)*predictTimeAcc
	rot:set(remoteData.rot * quatFromEuler(rotAdd:xyz()))
	rvel:set(push3(remoteRvel) + push3(remoteRacc)*predictTime)

	--[[
	-- Debug
	debugDrawer:drawSphere(0.3, remoteData.pos, color(0,0,255,200))
	debugDrawer:drawLine(remoteData.pos, (remoteData.pos + vec3(0,-5,0):rotated(remoteData.rot)), color(0,0,255,200))
	debugDrawer:drawSphere(0.3, pos, color(0,255,0,200))
	debugDrawer:drawLine(pos, (pos + vec3(0,-5,0):rotated(rot)), color(0,255,0,200))
	debugDrawer:drawSphere(0.3, vehPos, color(255,0,0,200))
	debugDrawer:drawLine(vehPos, (vehPos + vec3(0,-5,0):rotated(vehRot)), color(255,0,0,200))
	debugDrawer:drawText(pos, color(0,0,0,255), string.format("Prediction: %.0f ms", predictTime*1000))
	--]]

	-- Error correction
	local posError = pos - vehPos
	local rotErrorQuat = vehRot:inversed() * rot
	local rotError = rotErrorQuat:toEulerYXZ()
	local x = rotError.x
	rotError.x = rotError.y
	rotError.y = rotError.z
	rotError.z = x
	
	-- Calculate teleport thresholds
	local maxVel = tpVelSmoother:get(max(vel:length(), vehVel:length()), dt)
	local tpDist1 = tpDistAdd + maxVel*tpDistMul1
	local tpDist2 = tpDistAdd + maxVel*tpDistMul2
	
	-- Debug for teleport distances
	--debugDrawer:drawSphere(tpDist1, vehPos, color(0,0,255,50))
	--debugDrawer:drawSphere(tpDist2, vehPos, color(255,0,0,50))
	
	local maxRvel = tpRvelSmoother:get(max(rvel:length(), vehRvel:length()), dt)
	local tpRot1 = tpRotAdd + maxRvel*tpRotMul1
	local tpRot2 = tpRotAdd + maxRvel*tpRotMul2
	
	local posErrorLenSq = posError:squaredLength()
	local rotErrorLenSq = rotError:squaredLength()
	
	if posErrorLenSq > tpDist1*tpDist1 or rotErrorLenSq > tpRot1*tpRot1 then
		tpTimer = tpTimer + dt
	else
		tpTimer = 0
	end

	-- If instant teleport distance or teleport timer exceeded, teleport
	if framesSinceReset > 5 then -- wating 6 frames then always teleporting the 6th frame makes reseting/recovering a remote vehicle at speed teleport much more consistent, maybe the smoothers catching up?
		if framesSinceReset == 6 or tpTimer > (tpDelayAdd + abs(predictTime)) or posErrorLenSq > tpDist2*tpDist2 or rotErrorLenSq > tpRot2*tpRot2 then
			local predictTime = predictTime + dt -- add one frame so postion is correct when arriving in GE
			-- Use received position, and smoothed velocity and acceleration to predict vehicle position
			local predictTimeAcc = 0.5*predictTime*predictTime
			pos:set(push3(remoteData.pos) + push3(remoteVel)*predictTime + push3(remoteAcc)*predictTimeAcc)
			vel:set(push3(remoteVel) + push3(remoteAcc)*predictTime)
			local rotAdd = push3(remoteRvel)*predictTime + push3(remoteRacc)*predictTimeAcc
			rot:set(remoteData.rot * quatFromEuler(rotAdd:xyz()))
			rvel:set(push3(remoteRvel) + push3(remoteRacc)*predictTime)
			-- Subtract COG offset because setPosition works relative to refNode
			local tpPos = pos - velocityVE.cogRel:rotated(rot)

			local noCounterVelocity = 0
			if framesSinceReset == 6 then
				noCounterVelocity = 1 -- logs on the t series count as not attached so they would fly backwards on spawn, this disables the counter velocity preventing that
			end
			local posData = {pos = tpPos, vel = vel, vehVel = vehVel, rot = rot,rvel = rvel , noCounter = noCounterVelocity}
			
			obj:queueGameEngineLua("positionGE.setPositionRotationVelocity("..obj:getID()..","..serialize(posData)..")")
	
			remoteVelSmoother:set(remoteData.vel)
			remoteRvelSmoother:set(remoteData.rvel)
	
			remoteData.acc:set(0,0,0)
			remoteData.racc:set(0,0,0)
			remoteAccSmoother:reset()
			remoteRaccSmoother:reset()
	
			lastAcc = nil
	
			accErrorSmoother:reset()
			raccErrorSmoother:reset()

			return
		end
	end

	local velError = vel
	velError:setSub(vehVel)
	local accError = accErrorSmoother:get((lastAcc or vehAcc) - vehAcc, dt)
	--print("AccError: "..tostring(accError:length()/dt))

	local rvelError = rvel
	rvelError:setSub(vehRvel)
	local raccError = raccErrorSmoother:get((lastRacc or vehRacc) - vehRacc, dt)
	--print("RaccError: "..tostring(raccError:length()/dt))

	local targetAcc = ((push3(velError) + push3(posError)*posCorrectMul)*min(posForceMul*dt,1)):copy()
	limitVecLength(targetAcc, maxPosForce*dt)
	local targetRacc = ((push3(rvelError) + push3(rotError)*rotCorrectMul)*min(rotForceMul*dt,1)):copy()
	limitVecLength(targetRacc, maxRotForce*dt)

	local targetAccMul = 1-min(max(push3(targetAcc):dot(accError)/(targetAcc:squaredLength()+maxAccError*maxAccError*dt),0),1)
	--print("Force multiplier: "..targetAccMul)
	targetAcc:setScaled(targetAccMul)

	local targetRaccMul = 1-min(max(push3(targetRacc):dot(raccError)/(targetRacc:squaredLength()+maxRaccError*maxRaccError*dt),0),1)
	--print("Rotation force multiplier: "..targetRaccMul)
	targetRacc:setScaled(targetRaccMul)

	--print("targetAcc: "..targetAcc:length())
	--print("targetRacc: "..targetRacc:length())
	if framesSinceReset > 5 then
		if targetRacc:squaredLength() > minRotForce*minRotForce or vehVel:squaredLength() > 1 then
			velocityVE.addAngularVelocity(targetAcc.x, targetAcc.y, targetAcc.z, targetRacc.x, targetRacc.y, targetRacc.z)
			--profiler:add("velocityVE.addAngularVelocity")
		elseif targetAcc:squaredLength() > minPosForce*minPosForce then
			velocityVE.addVelocity(targetAcc.x, targetAcc.y, targetAcc.z)
			--profiler:add("velocityVE.addVelocity")
		end
	end

	lastAcc = targetAcc
	lastRacc = targetRacc
end



local function getVehicleRotation()
	-- this attempts to send a full table of nan if there are several rapid instability causing VE lua to break after next vehicle reload, seems to be caused by a game issue
	dir:set(obj:getDirectionVectorXYZ())
	dir:setScaled(-1)
	dirUp:set(obj:getDirectionVectorUpXYZ())
	rot:setFromDir(dir, dirUp)
	rvel:set(smoothRvel)
	rvel:setRotate(rot)

	cog:set(velocityVE.cogRel)
	cog:setRotate(rot)
	pos:set(obj:getPositionXYZ())
	pos:setAdd(cog)
	vel:set(smoothVel)
	cog:setCross(cog, rvel)
	vel:setAdd(cog)
	if vel ~= vel then log('E','getVehicleRotation', 'skipped invalid velocity values') return end

	vel:setScaled(simSpeedReal)
	rvel:setScaled(simSpeedReal)

	posSendTable.pos[1] = pos.x
	posSendTable.pos[2] = pos.y
	posSendTable.pos[3] = pos.z
	posSendTable.vel[1] = vel.x
	posSendTable.vel[2] = vel.y
	posSendTable.vel[3] = vel.z
	posSendTable.rot[1] = rot.x
	posSendTable.rot[2] = rot.y
	posSendTable.rot[3] = rot.z
	posSendTable.rot[4] = rot.w
	posSendTable.rvel[1] = rvel.x
	posSendTable.rvel[2] = rvel.y
	posSendTable.rvel[3] = rvel.z
	posSendTable.tim = timer
	posSendTable.ping = ownPing + lastDT

	posSendBuffer:reset()
	posSendBuffer:put("positionGE.sendVehiclePosRot(\'", jsonEncode(posSendTable), "\', ", obj:getID(), ")")
	obj:queueGameEngineLua(posSendBuffer) -- Send it
end



local function onInit()
	enablePhysicsStepHook()
end

local function setGameSpeed(speed)
	simSpeedReal = speed
end

M.onReset            = onReset
M.onInit             = onInit
M.onExtensionLoaded  = onInit
M.onPhysicsStep      = update
M.updateGFX          = updateGFX
M.getVehicleRotation = getVehicleRotation
M.setPing            = setPing
M.setGameSpeed       = setGameSpeed


return M
