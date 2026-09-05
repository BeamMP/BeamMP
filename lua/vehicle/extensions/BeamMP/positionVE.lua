-- Copyright (C) 2026 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

local abs = math.abs
local min = math.min
local max = math.max
local acos = math.acos
local sqrt = math.sqrt

local ok, err = pcall(function()
    ffi.cdef[[
        typedef struct { float x, y, z; } Vec3;
        typedef struct { float x, y, z, w; } Quat;
        typedef struct { Vec3 pos; Quat rot; Vec3 vel; Vec3 rvel; double tim;} PosPacket;
    ]]
end)
if not ok then
    print("cdef error: " .. tostring(err))
end

local sendPacket = ffi.new("PosPacket")
local receivePacket = ffi.new("PosPacket")
local posPacketSize = ffi.sizeof(sendPacket);

local smoothers = require("common/BeamMP/smoothers")
local predictors = require("common/BeamMP/predictors")
local stringBuffer = require("string.buffer")
local debugDrawer = obj.debugDrawProxy
local enableDebug = false

-- ============= VARIABLES =============
-- Position
local maxPosForce = 4               -- Maximum position correction force ---(m/s^2)
local posCollisionMul = 0.7         -- position force reduction when in colliding with something, 0 is no reduction and 1 removes all forces
local posCollisionTrigger = 20
local posVehicleContactMul = 0.4    -- position force reduction when in contact with another vehicle, 0 is no reduction and 1 removes all forces
local posProportional  = 40
local posIntegral = 20
local posDerivative = 8
local minOutput = -1000
local maxOutput = 1000
local posMinIntegral = -0.7
local posMaxIntegral = 0.7

local posPIDx = newPIDParallel(posProportional, posIntegral, posDerivative, minOutput, maxOutput, 1, 1, posMinIntegral, posMaxIntegral)
local posPIDy = newPIDParallel(posProportional, posIntegral, posDerivative, minOutput, maxOutput, 1, 1, posMinIntegral, posMaxIntegral)
local posPIDz = newPIDParallel(posProportional, posIntegral, posDerivative, minOutput, maxOutput, 1, 1, posMinIntegral, posMaxIntegral)

-- Rotation
local maxRotForce = 2            -- Maximum rotation correction force ---(rad/s^2)
local rotCollisionMul = 0.65     -- rotation force reduction when in colliding with something, 0 is no reduction and 1 removes all forces
local posCollisionTrigger = 10
local rotVehicleContactMul = 0.5 -- rotation force reduction when in contact with another vehicle, 0 is no reduction and 1 removes all forces
local rotProportional = 50
local rotIntegral = 8
local rotDerivative = 8
--local minOutput = -1000
--local maxOutput = 1000
local rotMinIntegral = -0.1
local rotMaxIntegral = 0.1

local rotPIDx = newPIDParallel(rotProportional, rotIntegral, rotDerivative, minOutput, maxOutput, 1, 1, rotMinIntegral, rotMaxIntegral)
local rotPIDy = newPIDParallel(rotProportional, rotIntegral, rotDerivative, minOutput, maxOutput, 1, 1, rotMinIntegral, rotMaxIntegral)
local rotPIDz = newPIDParallel(rotProportional, rotIntegral, rotDerivative, minOutput, maxOutput, 1, 1, rotMinIntegral, rotMaxIntegral)

-- Teleport
local tpDelayAdd = 1           -- Additional teleport delay (s)
local tpDistAdd  = 1            -- Additional teleport distance (m)
local tpDistMul1 = 0.1         -- Multiplier for delayed teleport distance based on velocity (m per m/s)
local tpDistMul2 = 0.5         -- Multiplier for instant teleport distance based on velocity (m per m/s)
local tpRotAdd   = 0.5           -- Additional teleport rotation (rad)
local tpRotMul1  = 0.2          -- Multiplier for delayed teleport rotation based on rotation velocity (rad per rad/s)
local tpRotMul2  = 0.5          -- Multiplier for instant teleport rotation based on rotation velocity (rad per rad/s)
local tpVelSmoother  = newTemporalSmoothingNonLinear(2,1000)  -- Smoother for filtering low velocities during collisions
local tpRvelSmoother = newTemporalSmoothingNonLinear(2,1000) -- Smoother for filtering low rotation velocities during collisions

-- Prediction
local maxPredict = 0.6         -- Maximum prediction limit (s)
local packetTimeout = 0.6      -- Stop prediction if no packet received within this time (s)

local bufferLength = 50
local AngularVelSmoothing = 3
local AngularAccSmoothing = 4
local DirectionSmoothing = 20
local totalVelSmoothing = 20

local rotVelSmooth = 1.3
local rotAccSmooth = 0.2

local dirPredictor = predictors.newDirectionVectorPredictor(bufferLength,AngularVelSmoothing,AngularAccSmoothing,DirectionSmoothing,totalVelSmoothing)
local quaternionPredictor = predictors.newQuaternionPredictor(bufferLength, rotVelSmooth, rotAccSmooth)

-- Smoothing
local localVelSmoother = smoothers.newVectorSmoothing(50)             -- Smoother for local velocity
local localAccSmoother = smoothers.newVectorSmoothing(50)
local localRvelSmoother = smoothers.newVectorSmoothing(50)            -- Smoother for local angular velocity
local timeOffsetSmoother = newTemporalSmoothingNonLinear(1)           -- Smoother for getting average time offset
local timeOffset = 0

local collisionSmoother = newTemporalSmoothing(2,10000)
local notCollidingSmoother = newTemporalSmoothing(1)

local ownPing = 0

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

local tpTimer = 0

local dtRaw = 0

local varCache = {
	framesSinceReset = 0,
	framesSinceTeleport = 0,
	lastUpdateTime = os:clockhp()
}

local vecCache = {
	cog = vec3(),
	vehPos = vec3(),
	vehVel = vec3(),
	vehAcc = vec3(),
	vehRvel = vec3(),
	vehRacc = vec3(),
	errorDir = vec3(),
	rotError = vec3(),
	posError = vec3(),
	rawVehAcc = vec3(),
	targetPos = vec3(),
	targetAcc = vec3(),
	targetRacc = vec3(),
	targetRvel = vec3(),
	lastVehVel = vec3(),
	lastVehRvel = vec3(),
	posErrorVel = vec3(),
	rotErrorVel = vec3(),
	posErrorMul = vec3(),
	rotErrorMul = vec3(),
	lastPosError = vec3(),
	lastRotError = vec3(),
	posErrorTimer = vec3(),
	rotErrorTimer = vec3()
}

local quatCache = {
	vehRot = quat(),
	targetRot = quat(),
	inverseRot = quat(),
	rotErrorQuat = quat()
}

local receivedData = {
	timer = 0,
	recTime = 0,
	timeOffset = 0,
	pos = vec3()
}

local smoothVel = vec3(0,0,0)
local smoothRvel = vec3(0,0,0)

local accurateVel = vec3()
local rawRVel = vec3()
local cog1 = vec3()
local dir = vec3()
local dirUp = vec3()
local rot1 = quat()

local function onReset()
	-- Reset smoothers and state variables
	posPIDx:reset()
	posPIDy:reset()
	posPIDz:reset()

	rotPIDx:reset()
	rotPIDy:reset()
	rotPIDz:reset()

	collisionSmoother:reset()

	smoothVel:set(0,0,0)
	smoothRvel:set(0,0,0)

	localVelSmoother:set(0,0,0)
	localRvelSmoother:set(0,0,0)
	tpVelSmoother:reset()
	tpRvelSmoother:reset()
	localAccSmoother:reset()

	vecCache.lastPosError:set(0,0,0)
	vecCache.lastRotError:set(0,0,0)
	vecCache.lastVehVel:set(0,0,0)
	vecCache.lastVehRvel:set(0,0,0)

	dirPredictor:reset()
	quaternionPredictor:reset()

	vecCache.posErrorTimer:set(0,0,0)
	if varCache.framesSinceReset > 0 then varCache.framesSinceReset = 0 end

	receivedData.timer = 0
end

local function onPhysicsStep(dtSim)
	-- Smooth vehicle velocity to prevent vibrating
	-- now also corrects velocity when vehicle is spinning
	local roll,pitch,yaw = obj:getRollPitchYawAngularVelocity() -- this is faster than doing them separately
	rawRVel:set(pitch,roll,yaw) -- but it's in the wrong order so we need to correct them

	dir:set(obj:getDirectionVectorXYZ())
	dir:setScaled(-1)
	dirUp:set(obj:getDirectionVectorUpXYZ())
	rot1:setFromDir(dir, dirUp)

	rawRVel:setRotate(rot1)
	cog1:set(velocityVE.cogRel)
	cog1:setRotate(rot1)

	accurateVel:setCross(cog1,rawRVel) -- remove angular velocity from the directional velocity
	accurateVel:setAddXYZ(obj:getVelocityXYZ()) -- this is where the actual velocity is added

	smoothVel:set(localVelSmoother:get(accurateVel, dtSim))
	smoothRvel:set(localRvelSmoother:get(rawRVel, dtSim))
end

local recPos  = vec3()
local recVel  = vec3()
local recRot  = quat()
local recRvel = vec3()
local posPacketRecBuff = stringBuffer.new()

-- caching these here removes garbage creation when reading the receivePacket data
local structPos = receivePacket.pos
local structVel = receivePacket.vel
local structRot = receivePacket.rot
local structRvel = receivePacket.rvel
local tim = 0
local recPing = 0

local function setVehiclePosRot(dt, jsonData)
	if jsonData then
		local decodedData = jsonDecode(jsonData)
		if not decodedData.pos then
			log('E','setVehicleRotation', 'Received invalid position packet')
			return
		end
		recPos:set(decodedData.pos[1],decodedData.pos[2],decodedData.pos[3])
		recVel:set(decodedData.vel[1],decodedData.vel[2],decodedData.vel[3])
		recRot:set(decodedData.rot[1],decodedData.rot[2],decodedData.rot[3],decodedData.rot[4])
		recRvel:set(decodedData.rvel[1],decodedData.rvel[2],decodedData.rvel[3])
		tim  = decodedData.tim
		recPing = decodedData.ping
	elseif posPacketSize == #posPacketRecBuff then
		ffi.copy(receivePacket, posPacketRecBuff, #posPacketRecBuff)
		recPos:set(structPos.x,structPos.y,structPos.z)
		recVel:set(structVel.x,structVel.y,structVel.z)
		recRot:set(structRot.x,structRot.y,structRot.z,structRot.w)
		recRvel:set(structRvel.x,structRvel.y,structRvel.z)
		tim  = receivePacket.tim
	else
		log('E','setVehicleRotation', 'Received invalid position packet with size '..#posPacketRecBuff)
		return
	end

	local speed = 1

	local timer = MPTimeSyncVE.getServerSimTime()
	if not tim then
		return
	end

	if receivedData.timer > tim then
		if receivedData.timer - tim > 5 then
			receivedData.timer = tim
			receivedData.recTime = timer
		end
		return
	end

	if tim ~= receivedData.timer then
		local localTime = timer
		if not MPTimeSyncVE.useTimeSync or jsonData then
			receivedData.timeOffset = timer-tim - ownPing/2 - recPing/2 - (dt or lastDt)
			localTime = localTime - timeOffset
		end
		dirPredictor:add(recPos, recVel, tim, speed, localTime)
		quaternionPredictor:add(recRot, recRvel, tim, speed, localTime)
		receivedData.pos:set(recPos)
	end

	receivedData.timer = tim
	receivedData.recTime = timer
end

local lastMailboxVersion = -2
local lastFFITime = 0
local lastMailboxVersionJson = -2
local lastJsonTime = 0

local function updateRemoteData(dt)
	if not v.mpServerID or v.mpServerID == "" or v.mpVehicleType ~= "R" then return end
	local mailboxName = "vehPosPcktFFI" .. v.mpServerID
	local mailboxNameJson = "vehPosPcktJson" .. v.mpServerID
	local currentMailBoxVersion = obj:getLastMailboxVersion(mailboxName)
	local currentMailBoxVersionJson = obj:getLastMailboxVersion(mailboxNameJson)

	if lastMailboxVersion ~= currentMailBoxVersion then
		obj:getLastMailboxToBuffer(mailboxName, posPacketRecBuff)
		lastFFITime = 0
		setVehiclePosRot()
	end
	if lastMailboxVersionJson ~= currentMailBoxVersionJson then
		local jsonData = obj:getLastMailbox(mailboxNameJson, posPacketRecBuff)
		if jsonData ~= "" then
			setVehiclePosRot(dt,jsonData)
			lastJsonTime = 0
		end
	end
	lastMailboxVersion = currentMailBoxVersion
	lastMailboxVersionJson = currentMailBoxVersionJson
end

local posPacketBuff = stringBuffer.new()
local rot = quat()
local rvel = vec3()
local vel = vec3()
local cog = vec3()
local pos = vec3()
local sendStructPos = sendPacket.pos
local sendStructVel = sendPacket.vel
local sendStructRot = sendPacket.rot
local sendStructRvel = sendPacket.rvel
local sendStructTim = sendPacket.tim

local function getVehicleRotation(serverID)
	if not MPTimeSyncVE.ready then return end -- TODO start with a nop function and switch it to this instead of checking every tick
	dir:set(obj:getDirectionVectorXYZ())
	dir:setScaled(-1)
	dirUp:set(obj:getDirectionVectorUpXYZ())
	rot:setFromDir(dir, dirUp)

	rvel:set(smoothRvel)

	cog:set(velocityVE.InitCogRel)
	cog:setRotate(rot)
	pos:set(obj:getPositionXYZ())
	pos:setAdd(cog)
	vel:set(smoothVel)
	local simSpeed = MPTimeSyncVE.getSimSpeed()
	local timeToSend = MPTimeSyncVE.getServerSimTime()

	vel:setScaled(simSpeed)
	rvel:setScaled(simSpeed)

	if isnaninf(pos:squaredLength()) or isnaninf(vel:squaredLength()) or isnaninf(rvel:squaredLength()) then log('E','getVehicleRotation', 'skipped invalid velocity values') return end

	if MPTimeSyncVE.useTimeSync then
		sendPacket.tim = timeToSend
		sendStructPos.x, sendStructPos.y, sendStructPos.z = pos.x, pos.y, pos.z
		sendStructVel.x, sendStructVel.y, sendStructVel.z = vel.x, vel.y, vel.z
		sendStructRot.x, sendStructRot.y, sendStructRot.z, sendStructRot.w = rot.x, rot.y, rot.z, rot.w
		sendStructRvel.x, sendStructRvel.y, sendStructRvel.z = rvel.x, rvel.y, rvel.z

		local serializedFFIString = serialize(ffi.string(sendPacket, posPacketSize))
		posPacketBuff:reset()
		posPacketBuff:put('positionGE.sendVehiclePosRotFFI(', serializedFFIString, ",", objectId, ")")

		-- this would be faster, but queues break with binary data so we need to serialize it
		--posPacketBuff:put(",", objectId, ")")
		--posPacketBuff:put('positionGE.sendVehiclePosRot(')
		--posPacketBuff:putcdata(sendPacket, posPacketSize)
	else
		posPacketBuff:set('positionGE.sendVehiclePosRot(')
		posPacketBuff:put("'{")
		posPacketBuff:putf('\"tim\":%.4f', timeToSend)
		posPacketBuff:putf(',\"vel\":[%.3f,%.3f,%.3f]', vel.x, vel.y, vel.z)
		posPacketBuff:putf(',\"rot\":[%.4f,%.4f,%.4f,%.4f]', rot.x, rot.y, rot.z, rot.w)
		posPacketBuff:putf(',\"rvel\":[%.3f,%.3f,%.3f]', rvel.x, rvel.y, rvel.z)
		posPacketBuff:putf(',\"pos\":[%.3f,%.3f,%.3f]', pos.x, pos.y, pos.z)
		posPacketBuff:putf(',\"ping\":%.4f', ownPing + lastDt)
		posPacketBuff:put("}'")
		posPacketBuff:put(", ", objectId, ")")
	end

	obj:queueGameEngineLua(posPacketBuff)
end

local function calculateForceReduction(errorDir,posError,posErrorVel,posErrorTimer,triggerError,dt,predictTime)
	if abs(posErrorVel) > triggerError then
		--local mul = min(2,(abs(posErrorVel)-triggerError)/10)
		posErrorTimer = predictTime*1

		--posErrorTimer = min(predictTime*2,posErrorTimer + dt)
		if posError > 0 and posErrorVel > 0 or posError < 0 and posErrorVel < 0 then
			errorDir = 1
		elseif posError > 0 and posErrorVel < 0 or posError < 0 and posErrorVel > 0 then
			errorDir = -1
		end
	else
		posErrorTimer = max(0,posErrorTimer - dt)
	end
	return posErrorTimer,errorDir
end

local function updateGFX(dt)
	local timer = MPTimeSyncVE.getServerSimTime()
	dtRaw = os:clockhp() - varCache.lastUpdateTime
	lastFFITime = lastFFITime + dtRaw
	lastJsonTime = lastJsonTime + dtRaw
	updateRemoteData(dtRaw)
	varCache.lastUpdateTime = os:clockhp()

	varCache.framesSinceReset = varCache.framesSinceReset + 1
	varCache.framesSinceTeleport = varCache.framesSinceTeleport + 1

	local framesSinceReset = varCache.framesSinceReset
	local framesSinceTeleport = varCache.framesSinceTeleport

	if framesSinceReset == 5 then
		velocityVE.onReset() -- TODO find better fix, temp fix for instability de-syncing COG
	end

	if v.mpVehicleType == "L" or timer == 0 or receivedData.timer == 0 or not receivedData.pos or (timer-receivedData.recTime) > packetTimeout+2 or framesSinceTeleport < 2 then
		return
	end

	-- Local vehicle data
	local vehPos = vecCache.vehPos
	local vehRot = quatCache.vehRot
	local vehVel = vecCache.vehVel
	local vehAcc = vecCache.vehAcc
	local vehRacc = vecCache.vehRacc
	local rawVehAcc = vecCache.rawVehAcc
	local inverseRot = quatCache.inverseRot
	local rotErrorQuat = quatCache.rotErrorQuat
	local rotError = vecCache.rotError
	local vehRvel = vecCache.vehRvel
	local cog = vecCache.cog
	local lastVehVel = vecCache.lastVehVel
	local lastVehRvel = vecCache.lastVehRvel

	dir:set(obj:getDirectionVectorXYZ())
	dir:setScaled(-1)
	dirUp:set(obj:getDirectionVectorUpXYZ())
	vehRot:setFromDir(dir, dirUp)

	vehRvel:set(smoothRvel)
	if isnaninf(vehRvel:squaredLength()) then return end

	vehRacc:setSub2(vehRvel,lastVehRvel or vehRvel)
	if isnaninf(vehRacc:squaredLength()) then return end

	cog:set(velocityVE.InitCogRel)
	cog:setRotate(vehRot)

	vehPos:set(obj:getPositionXYZ()) -- functions that end with XYZ are usually garbage free
	vehPos:setAdd(cog)
	if isnaninf(vehPos:squaredLength()) then return end

	vehVel:set(smoothVel)
	if isnaninf(vehVel:squaredLength()) then return end

	rawVehAcc:setSub2(vehVel,lastVehVel)
	if dt ~= 0 then
		rawVehAcc:setScaled(1/dt)
	end
	if isnaninf(rawVehAcc:squaredLength()) then return end

	vehAcc:set(localAccSmoother:get(rawVehAcc,dt))

	lastVehVel:set(vehVel)
	lastVehRvel:set(vehRvel)

	if not MPTimeSyncVE.useTimeSync or lastFFITime > 1 and lastJsonTime < 1 then
		-- Smoothed difference between local and remote timestamps
		timeOffset = timeOffsetSmoother:get(receivedData.timeOffset, dt)
		if abs(timeOffset - receivedData.timeOffset) > 1 then
			timeOffsetSmoother:set(receivedData.timeOffset)
			timeOffset = receivedData.timeOffset
		end
		timer = timer - timeOffset + dt
	end

	local predictOffset = 0

	local simSpeed = MPTimeSyncVE.getSimSpeed()
	local predictedPos, predictedVel, predictedAcc, isTeleport, predictTime = dirPredictor:get(timer, dt, predictOffset, simSpeed)

	if abs(predictTime) > 0.5 then return end --TODO maybe implement a ghosting controller?

	local targetPos = vecCache.targetPos
	targetPos:set(predictedPos)
	if targetPos:squaredLength() == 0 then
		return
	end

	local predictedRot, predictedRvel, isRotTeleport = quaternionPredictor:get(timer,dt,predictOffset, simSpeed)

	if enableDebug then
    	debugDrawer:drawSphere(0.1, vehPos, color(255,0,0,200))
		debugDrawer:drawCylinder(vehPos, (vehPos + vec3(0,-3,0):rotated(vehRot):toFloat3()),0.05, color(255,0,0,200))
		debugDrawer:drawCylinder(vehPos, (vehPos + vec3( 3,0,0):rotated(vehRot):toFloat3()),0.05, color(255,0,0,200))
	end

	local targetRot = quatCache.targetRot
	local targetRvel = vecCache.targetRvel
	targetRot:set(predictedRot)
	targetRvel:set(predictedRvel)

	-- Error correction
	local posError = vecCache.posError
	posError:setSub2(targetPos,vehPos)
	if posError ~= posError then
		posError:set(0,0,0)
	end

	if vehRot:dot(targetRot) < 0 then
		targetRot:scale(-1)
	end
	inverseRot:set(vehRot)
	inverseRot:inverse()
	rotErrorQuat:setMul2(targetRot , inverseRot)
	rotError:set(rotErrorQuat.x, rotErrorQuat.y, rotErrorQuat.z)
	rotError:setScaled(2)
	rotError:setRotate(vehRot)
	local rotErrorLen =  2 * acos(max(-1, min(1, rotErrorQuat.w)))

	-- Calculate teleport thresholds
	local maxVel = tpVelSmoother:get(sqrt(max(predictedAcc:squaredLength(), vehAcc:squaredLength())/100), dt)

	local tpDist1 = tpDistAdd + maxVel*tpDistMul1
	local tpDist2 = tpDistAdd + maxVel*tpDistMul2

	-- Debug for teleport distances
	--debugDrawer:drawSphere(tpDist1, vehPos, color(0,0,255,50))
	--debugDrawer:drawSphere(tpDist2, vehPos, color(255,0,0,50))

	local maxRvel = tpRvelSmoother:get(sqrt(max(targetRvel:squaredLength(), vehRvel:squaredLength())), dt)
	local tpRot1 = tpRotAdd + maxRvel*tpRotMul1
	local tpRot2 = tpRotAdd + maxRvel*tpRotMul2

	local posErrorLen = posError:squaredLength()

	local posErrorTimer = vecCache.posErrorTimer
	local rotErrorTimer = vecCache.rotErrorTimer

	if posErrorLen > tpDist1^2 or rotErrorLen > tpRot1 then
		tpTimer = tpTimer + dt
	else
		tpTimer = 0
	end
	-- If instant teleport distance or teleport timer exceeded, teleport
	if framesSinceReset > 5 or isTeleport then -- wating 6 frames then always teleporting the 6th frame makes reseting/recovering a remote vehicle at speed teleport much more consistent, maybe the smoothers catching up?
		if framesSinceReset == 6 or isTeleport or tpTimer > (tpDelayAdd + abs(predictTime)) or posErrorLen > tpDist2^2 or rotErrorLen > tpRot2 then
			local tpPos = vec3()
			local tpVel = vec3()
			local tpRot, tpRvel = quaternionPredictor:get(timer + min(dtRaw,0.3),dt,predictOffset,simSpeed,true)

			if not tpRot then return end
			local predictPos, predictVel = dirPredictor:get(timer + min(dtRaw,0.3),dt,predictOffset,simSpeed,true)
			tpPos:setSub2(predictPos, velocityVE.InitCogRel:rotated(predictedRot))

			if isnaninf(posError:squaredLength()) or isnaninf(predictVel:squaredLength()) or isnaninf(tpRvel:squaredLength()) or isnaninf(vehVel:squaredLength()) or targetRot ~= targetRot then
			else
				local noCounterVelocity = 0
				if framesSinceReset == 6 then
					noCounterVelocity = 1 -- logs on the t series count as not attached so they would fly backwards on spawn, this disables the counter velocity preventing that
				end
				local posData = {pos = tpPos, rot = tpRot, vel = predictVel, rvel = tpRvel ,vehVel = vehVel, noCounter = noCounterVelocity}
				obj:queueGameEngineLua("positionGE.setPositionRotationVelocity("..obj:getID()..","..serialize(posData)..")")
			end
			varCache.framesSinceTeleport = 0

			localAccSmoother:reset()

			posPIDx:reset()
			posPIDy:reset()
			posPIDz:reset()

			rotPIDx:reset()
			rotPIDy:reset()
			rotPIDz:reset()

			posErrorTimer:set(0,0,0)
			rotErrorTimer:set(0,0,0)

			vecCache.lastPosError:set(0,0,0)
			vecCache.lastRotError:set(0,0,0)
			return
		end
	end

	local velPIDX = posPIDx:get(-posError.x, 0, dt)
	local velPIDY = posPIDy:get(-posError.y, 0, dt)
	local velPIDZ = posPIDz:get(-posError.z, 0, dt)

	local targetAcc = vecCache.targetAcc
	targetAcc:set(velPIDX,velPIDY,velPIDZ)

	local rvelPIDX = rotPIDx:get(-rotError.x, 0, dt)
	local rvelPIDY = rotPIDy:get(-rotError.y, 0, dt)
	local rvelPIDZ = rotPIDz:get(-rotError.z, 0, dt)

	local targetRacc = vecCache.targetRacc
	targetRacc:set(rvelPIDX,rvelPIDY,rvelPIDZ)

	-- if vehicle gets pushed locally we reduce force for a certian time to make jumps and collisions more natural
	-- TODO: reduce force more if the position error is very low on impact

	local rotErrorVel = vecCache.rotErrorVel
	rotErrorVel:setSub2(rotError,vecCache.lastRotError)
	rotErrorVel:setScaled(1/dt)

	local posErrorVel = vecCache.posErrorVel
	posErrorVel:setSub2(posError,vecCache.lastPosError)
	posErrorVel:setScaled(1/dt)

	vecCache.lastRotError:set(rotError)
	vecCache.lastPosError:set(posError)

	local errorDir = vecCache.errorDir
	local colliding = false

	if next(mapmgr.objectCollisionIds) ~= nil then
		colliding = true
	end
	local collidingSmooth = collisionSmoother:get(colliding and 1 or 0,dt)
	--local notCollidingSmooth = notCollidingSmoother:get(colliding and 0 or 1,dt)

	local posErrorColMul = 1
	local rotErrorColMul = 1

	if collidingSmooth > 0 then -- TODO properly test this
		--local contactMul = ((posVehicleContactMul*collidingSmooth)+((1-posVehicleContactMul)*notCollidingSmooth))*collidingSmooth
		--local contactMulR = ((rotVehicleContactMul*collidingSmooth)+((1-rotVehicleContactMul)*notCollidingSmooth))*collidingSmooth
		--posErrorColMul = max(0,min(1,1-contactMul))
		--rotErrorColMul = max(0,min(1,1-contactMulR))

		posErrorColMul = max(0,min(1,1-(posVehicleContactMul*collidingSmooth)))
		rotErrorColMul = max(0,min(1,1-(rotVehicleContactMul*collidingSmooth)))

		posPIDx.integral = 0
		posPIDy.integral = 0
		posPIDz.integral = 0

		rotPIDx.integral = 0
		rotPIDy.integral = 0
		rotPIDz.integral = 0
	end

	if predictTime > 0.01 then
		local estimatedSimSpeed = 1
		-- TODO: find a better way to do this, It's quite bouncy and can oscillate a fair bit
		posErrorTimer.x , errorDir.x = calculateForceReduction(errorDir.x,posError.x,posErrorVel.x,posErrorTimer.x,posCollisionTrigger/estimatedSimSpeed,dt,predictTime)
		posErrorTimer.y , errorDir.y = calculateForceReduction(errorDir.y,posError.y,posErrorVel.y,posErrorTimer.y,posCollisionTrigger/estimatedSimSpeed,dt,predictTime)
		posErrorTimer.z , errorDir.z = calculateForceReduction(errorDir.z,posError.z,posErrorVel.z,posErrorTimer.z,posCollisionTrigger/estimatedSimSpeed,dt,predictTime)

		rotErrorTimer.x  = calculateForceReduction(errorDir.x,rotError.x,rotErrorVel.x,rotErrorTimer.x,posCollisionTrigger/estimatedSimSpeed,dt,predictTime)
		rotErrorTimer.y  = calculateForceReduction(errorDir.y,rotError.y,rotErrorVel.y,rotErrorTimer.y,posCollisionTrigger/estimatedSimSpeed,dt,predictTime)
		rotErrorTimer.z  = calculateForceReduction(errorDir.z,rotError.z,rotErrorVel.z,rotErrorTimer.z,posCollisionTrigger/estimatedSimSpeed,dt,predictTime)

		local posErrorMul = vecCache.posErrorMul
		posErrorMul.x = (1 - min(1,(posCollisionMul*(posErrorTimer.x/(predictTime*2)))))
		posErrorMul.y = (1 - min(1,(posCollisionMul*(posErrorTimer.y/(predictTime*2)))))
		posErrorMul.z = (1 - min(1,(posCollisionMul*(posErrorTimer.z/(predictTime*2)))))

		local rotErrorMul = vecCache.rotErrorMul
		rotErrorMul.x = (1 - min(1,(rotCollisionMul*(rotErrorTimer.x/(predictTime*2)))))
		rotErrorMul.y = (1 - min(1,(rotCollisionMul*(rotErrorTimer.y/(predictTime*2)))))
		rotErrorMul.z = (1 - min(1,(rotCollisionMul*(rotErrorTimer.z/(predictTime*2)))))

		targetAcc.x = (targetAcc.x*min(posErrorColMul,posErrorMul.x))
		targetAcc.y = (targetAcc.y*min(posErrorColMul,posErrorMul.y))
		targetAcc.z = (targetAcc.z*min(posErrorColMul,posErrorMul.z))

		local highestRotErrorTimer = min(rotErrorMul.x,min(rotErrorMul.y,min(rotErrorMul.z)))
		targetRacc:setScaled(min(rotErrorColMul,highestRotErrorTimer))

	end
	targetAcc:setScaled(dt)
	targetRacc:setScaled(dt)

	targetAcc = limitVecLength(targetAcc,maxPosForce)
	targetRacc = limitVecLength(targetRacc,maxRotForce)

	if isnaninf(targetAcc:squaredLength()) or isnaninf(targetRacc:squaredLength()) then
	elseif framesSinceReset > 5 then
		velocityVE.addAngularVelocity(targetAcc.x, targetAcc.y, targetAcc.z, targetRacc.x, targetRacc.y, targetRacc.z)
	end
end

local function checkDebug()
	if settings.getValue("enablePredictionDebug") then
		dirPredictor.enableDebug = true
		quaternionPredictor.enableDebug = true
		enableDebug = true
	else
		dirPredictor.enableDebug = false
		quaternionPredictor.enableDebug = false
		enableDebug = false
	end
end

local function onExtensionLoaded()
	enablePhysicsStepHook()
	checkDebug()
end

M.setPing            = setPing
M.onReset            = onReset
M.onPhysicsStep      = onPhysicsStep
M.updateGFX          = updateGFX
M.getVehicleRotation = getVehicleRotation
M.onExtensionLoaded  = onExtensionLoaded
M.checkDebug = checkDebug

return M