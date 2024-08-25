-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}



local abs = math.abs
local min = math.min
local max = math.max



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
  local dif = sample - st
  st = st + dif * min(self.rate * dt, 1)
  self.state = st
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
	pos = nil,
	vel = vec3(0,0,0),
	acc = vec3(0,0,0),
	rot = quat(0,0,0,0),
	rvel = vec3(0,0,0),
	racc = vec3(0,0,0),
	timer = 0,
	timeOffset = 0,
	recTime = 0,
	localSimspeed = 1
}

local smoothVel = vec3(0,0,0)
local smoothRvel = vec3(0,0,0)

local physHandlerAdded = false

local debugDrawer = obj.debugDrawProxy
-- ============= VARIABLES =============



local function setPing(p)
	-- some ping packets seem to go missing on local servers
	if p < 0.99 or p > 1.01 then
		ownPing = p
	end
end



-- Limit vector length
local function limitVecLength(vec, length)
	local vecLength = vec:length()
	
	if vecLength > length then
		return vec*(length/vecLength)
	end
	
	return vec
end



-- Rotate the vehicle relative to its current rotation
local function rotateVehicle(rot)
	for _, n in pairs(v.data.nodes) do
		obj:setNodePosition(n.cid, vec3(obj:getNodePosition(n.cid)):rotated(rot):toFloat3())
	end
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

	smoothVel = vec3(0,0,0)
	smoothRvel = vec3(0,0,0)
	remoteData.acc = vec3(0,0,0)
	remoteData.racc = vec3(0,0,0)
	remoteData.timer = 0
	framesSinceReset = 0
end

local physcounter = 0
local physstart = 0

local physmult = 1

local function update(dtSim)
	if physcounter == 0 then
		physstart = os.clock()
	end
	physcounter = physcounter+1
	if physcounter == 2000 then
		physcounter = 0
		local physend = os.clock()
		local physdiff = physend - physstart
		if playerInfo.firstPlayerSeated then
			physmult = 1/physdiff -- (physdiff == 0) and 0 or 1/physdiff
			--print(tostring(physmult*100) .."% realtime")
			obj:queueGameEngineLua("positionGE.setActualSimSpeed("..tostring(physmult)..")")
		end
	end


	-- Smooth vehicle velocity to prevent vibrating
	smoothVel = localVelSmoother:get(vec3(obj:getVelocity()), dtSim)
	smoothRvel = localRvelSmoother:get(vec3(obj:getPitchAngularVelocity(), obj:getRollAngularVelocity(), obj:getYawAngularVelocity()), dtSim)
end



local function updateGFX(dt)
	dt = dt * (remoteData.localSimspeed or 1)
	timer = timer + dt
	lastDT = dt
	framesSinceReset = framesSinceReset + 1

	-- If there is no received data, or data is older than timeout, do nothing
	if not remoteData.pos or (timer-remoteData.recTime) > packetTimeout then return end
	
	-- Since the line above returns end if there is no remote data we know this vehicle should be remote if this runs
	if v.mpVehicleType == "L" then v.mpVehicleType = "R" end

	-- Local vehicle data
	local vehRot = quatFromDir(-vec3(obj:getDirectionVector()), vec3(obj:getDirectionVectorUp()))
	local vehRvel = smoothRvel:rotated(vehRot)
	local vehRacc = vehRvel-(lastVehRvel or vehRvel)
	
	local cog = velocityVE.cogRel:rotated(vehRot)
	local vehPos = vec3(obj:getPosition()) + cog
	local vehVel = smoothVel + cog:cross(vehRvel)
	local vehAcc = vehVel-(lastVehVel or vehVel)

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
	local rot = remoteData.rot * quatFromEuler(rotAdd.x, rotAdd.y, rotAdd.z)
	local rvel = remoteRvel + remoteRacc*predictTime

	--[[
	-- Debug
	debugDrawer:drawSphere(0.3, remoteData.pos:toFloat3(), color(0,0,255,200))
	debugDrawer:drawLine(remoteData.pos:toFloat3(), (remoteData.pos + vec3(0,-5,0):rotated(remoteData.rot)):toFloat3(), color(0,0,255,200))
	debugDrawer:drawSphere(0.3, pos:toFloat3(), color(0,255,0,200))
	debugDrawer:drawLine(pos:toFloat3(), (pos + vec3(0,-5,0):rotated(rot)):toFloat3(), color(0,255,0,200))
	debugDrawer:drawSphere(0.3, vehPos:toFloat3(), color(255,0,0,200))
	debugDrawer:drawLine(vehPos:toFloat3(), (vehPos + vec3(0,-5,0):rotated(vehRot)):toFloat3(), color(255,0,0,200))
	debugDrawer:drawText(pos:toFloat3(), color(0,0,0,255), string.format("Prediction: %.0f ms", predictTime*1000))
	--]]

	-- Error correction
	local posError = pos - vehPos
	local rotErrorQuat = vehRot:inversed() * rot
	local rotError = rotErrorQuat:toEulerYXZ()
	rotError = vec3(rotError.y, rotError.z, rotError.x)
	
	-- Calculate teleport thresholds
	local maxVel = tpVelSmoother:get(max(vel:length(), vehVel:length()), dt)
	local tpDist1 = tpDistAdd + maxVel*tpDistMul1
	local tpDist2 = tpDistAdd + maxVel*tpDistMul2
	
	-- Debug for teleport distances
	--debugDrawer:drawSphere(tpDist1, vehPos:toFloat3(), color(0,0,255,50))
	--debugDrawer:drawSphere(tpDist2, vehPos:toFloat3(), color(255,0,0,50))
	
	local maxRvel = tpRvelSmoother:get(max(rvel:length(), vehRvel:length()), dt)
	local tpRot1 = tpRotAdd + maxRvel*tpRotMul1
	local tpRot2 = tpRotAdd + maxRvel*tpRotMul2
	
	local posErrorLen = posError:length()
	local rotErrorLen = rotError:length()
	
	if posErrorLen > tpDist1 or rotErrorLen > tpRot1 then
		tpTimer = tpTimer + dt
	else
		tpTimer = 0
	end

	-- If instant teleport distance or teleport timer exceeded, teleport
	if framesSinceReset > 5 then -- wating 6 frames then always teleporting the 6th frame makes reseting/recovering a remote vehicle at speed teleport much more consistent, maybe the smoothers catching up?
		if framesSinceReset == 6 or tpTimer > (tpDelayAdd + abs(predictTime)) or posErrorLen > tpDist2 or rotErrorLen > tpRot2 then
			local predictTime = predictTime + dt -- add one frame so postion is correct when arriving in GE
			-- Use received position, and smoothed velocity and acceleration to predict vehicle position
			local pos = remoteData.pos + remoteVel*predictTime + 0.5*remoteAcc*predictTime*predictTime
			local vel = remoteVel + remoteAcc*predictTime
			local rotAdd = remoteRvel*predictTime + 0.5*remoteRacc*predictTime*predictTime
			local rot = remoteData.rot * quatFromEuler(rotAdd.x, rotAdd.y, rotAdd.z)
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
	
			remoteData.acc = vec3(0,0,0)
			remoteData.racc = vec3(0,0,0)
			remoteAccSmoother:reset()
			remoteRaccSmoother:reset()
	
			lastAcc = nil
	
			accErrorSmoother:reset()
			raccErrorSmoother:reset()
	
			return
		end
	end

	local velError = vel - vehVel
	local accError = accErrorSmoother:get((lastAcc or vehAcc) - vehAcc, dt)
	--print("AccError: "..tostring(accError:length()/dt))

	local rvelError = rvel - vehRvel
	local raccError = raccErrorSmoother:get((lastRacc or vehRacc) - vehRacc, dt)
	--print("RaccError: "..tostring(raccError:length()/dt))

	local targetAcc = limitVecLength((velError + posError*posCorrectMul)*min(posForceMul*dt,1), maxPosForce*dt)
	local targetRacc = limitVecLength((rvelError + rotError*rotCorrectMul)*min(rotForceMul*dt,1), maxRotForce*dt)

	local targetAccMul = 1-min(max(targetAcc:dot(accError)/(targetAcc:squaredLength()+maxAccError*maxAccError*dt),0),1)
	--print("Force multiplier: "..targetAccMul)
	targetAcc = targetAcc*targetAccMul

	local targetRaccMul = 1-min(max(targetRacc:dot(raccError)/(targetRacc:squaredLength()+maxRaccError*maxRaccError*dt),0),1)
	--print("Rotation force multiplier: "..targetRaccMul)
	targetRacc = targetRacc*targetRaccMul

	--print("targetAcc: "..targetAcc:length())
	--print("targetRacc: "..targetRacc:length())
	if framesSinceReset > 5 then
		if targetRacc:length() > minRotForce or vehVel:length() > 1 then
			velocityVE.addAngularVelocity(targetAcc.x, targetAcc.y, targetAcc.z, targetRacc.x, targetRacc.y, targetRacc.z)
		elseif targetAcc:length() > minPosForce then
			velocityVE.addVelocity(targetAcc.x, targetAcc.y, targetAcc.z)
		end
	end

	lastAcc = targetAcc
	lastRacc = targetRacc
end



local function getVehicleRotation()
	-- this attempts to send a full table of nan if there are several rapid instability causing VE lua to break after next vehicle reload, seems to be caused by a game issue
	local rot = quatFromDir(-vec3(obj:getDirectionVector()), vec3(obj:getDirectionVectorUp()))
	local rvel = smoothRvel:rotated(rot)
	
	local cog = velocityVE.cogRel:rotated(rot)
	local pos = vec3(obj:getPosition()) + cog
	local vel = smoothVel + cog:cross(rvel)
	if vel ~= vel then log('E','getVehicleRotation', 'skipped invalid velocity values') return end

	-- disabled because the GE implementation of slowmo sync is instant, but doesn't account for low fps compensation
	--vel = vel * physmult
	--rvel = rvel * physmult

	local tempTable = {
		pos = {pos.x, pos.y, pos.z},
		vel = {vel.x, vel.y, vel.z},
		rot = {rot.x, rot.y, rot.z, rot.w},
		rvel = {rvel.x, rvel.y, rvel.z},
		tim = timer,
		ping = ownPing + lastDT
	}
	obj:queueGameEngineLua("positionGE.sendVehiclePosRot(\'"..jsonEncode(tempTable).."\', "..obj:getID()..")") -- Send it
end



local function setVehiclePosRot(data)

	local pr   = jsonDecode(data)
	local pos  = vec3(pr.pos)
	local vel  = vec3(pr.vel)
	local rot  = quat(pr.rot)
	local rvel = vec3(pr.rvel)
	local tim  = pr.tim
	local ping = pr.ping
	local simspeedfraction = pr.localSimspeed

	if not tim then return end
	if remoteData.timer > tim then return end

	local remoteDT = max(tim - remoteData.timer, 0.001)

	remoteData.pos = pos
	remoteData.rot = rot
	remoteData.acc = limitVecLength((vel - remoteData.vel)/remoteDT, maxAcc)
	remoteData.racc = limitVecLength((rvel - remoteData.rvel)/remoteDT, maxRacc)
	remoteData.vel = vel
	remoteData.rvel = rvel
	remoteData.timer = tim
	remoteData.timeOffset = timer-tim - ownPing/2 - ping/2 - lastDT
	remoteData.recTime = timer
	remoteData.localSimspeed = math.min(simspeedfraction, 25)
end

local function onInit()
	enablePhysicsStepHook()
end



M.onReset            = onReset
M.onInit             = onInit
M.onExtensionLoaded  = onInit
M.onPhysicsStep      = update
M.updateGFX          = updateGFX
M.getVehicleRotation = getVehicleRotation
M.setVehiclePosRot   = setVehiclePosRot
M.setPing            = setPing


return M
