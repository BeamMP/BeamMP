--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}

-- ============= VARIABLES =============
-- Position
local posCorrectMul = 5        -- How much acceleration to use for correcting position error
local posForceMul = 0.2           -- How much acceleration is used to correct velocity (between 0 and 1)

-- Rotation
local rotCorrectMul = 2        -- How much acceleration to use for correcting angle error
local rotForceMul = 0.2        -- How much acceleration is used to correct angular velocity (between 0 and 1)

-- Prediction
local disableTimeMul = 1.2     -- At collision, position correction is disabled for ping*disableTimeMul to wait for data
local maxAccErrorMul = 0.5     -- Which amount of acceleration error is detected as a collision
local minAccError = 5          -- Minimum acceleration error to be detected as a collision
local maxPosError = 10         -- If position error is larger than this, teleport the vehicle
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
-- ============= VARIABLES =============

local function setPing(p)
	ping = p
end

local function updateGFX(dt)
	timer = timer + dt
	
	-- Local vehicle data
	local vehPos = vec3(obj:getPosition())
	local vehVel = vec3(obj:getVelocity())
	local vehAcc = (vehVel-(lastVehVel or vehVel))/dt
	
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
	
	-- If prediction is disabled, stop here
	if remoteData.timer < disableUntil then
		return
	end
	
	-- Calculate back to local time using the remote timestamp and the smoothed time difference
	local calcLocalTime = remoteData.timer + timeOffset
	
	-- Get difference between calculated and actual local time
	local timeDiff = timer - calcLocalTime
	
	-- How far ahead the position needs to be predicted
	local predictTime = timeDiff + ping

	-- Use received position, velocity, and acceleration to predict vehicle position
	local pos = remoteData.pos + remoteData.vel*predictTime + 0.5*remoteData.acc*predictTime*predictTime
	local vel = remoteData.vel + remoteData.acc*predictTime
	local rotAdd = remoteData.rvel*predictTime + 0.5*remoteData.racc*predictTime*predictTime
	local rot = remoteData.rot * quatFromEuler(rotAdd.y, rotAdd.z, rotAdd.x)
	local rvel = remoteData.rvel + remoteData.racc*predictTime

	--DEBUG
	local debugDrawer = obj.debugDrawProxy
	debugDrawer:drawSphere(0.3, remoteData.pos:toFloat3(), color(0,0,255,255))
	debugDrawer:drawSphere(0.3, pos:toFloat3(), color(0,255,0,255))
	
	-- Error correction
	local posError = pos - vehPos
	local rotError = (rot / vehRot):toEulerYXZ()
	
	-- If position error is larger than limit, teleport the vehicle
	if posError:length() > maxPosError then
		--print("PosError = " .. tostring(posError))

		obj:queueGameEngineLua("positionGE.setPosition("..obj:getID()..","..pos.x..","..pos.y..","..pos.z..")")
		velocityVE.setVelocity(vel.x, vel.y, vel.z)
		velocityVE.setAngularVelocity(rvel.y, rvel.z, rvel.x)
		
		lastAcc = nil
	
		return
	end
	
	local velError = vel - vehVel
	local accError = lastAcc - vehAcc
	
	local rvelError = rvel - vehRvel
	--local raccError = racc - vehRacc
	
	-- Disable prediction if acceleration error is larger than threshold
	if accError:length() > max(minAccError, lastAcc:length()*maxAccErrorMul) then
		disableUntil = remoteData.timer + predictTime*disableTimeMul
		print("Prediction disabled for "..predictTime*disableTimeMul.." sec! accError "..accError:length().." > "..max(minAccError, lastAcc:length()*maxAccErrorMul))
		return
	end
	
	local targetAcc = (velError + posError*posCorrectMul)*posForceMul
	local targetRacc = (rvelError + rotError*rotCorrectMul)*rotForceMul
	
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

local function setVehiclePosRot(pos, vel, rot, rvel, tim, realtime)

	--TODO: Engine.Platform does not work in vehicle lua, find other way to get real time
	--local processDelay = Engine.Platform.getRealMilliseconds() - realtime
	--print("Position packet processing delay: "..processDelay)
	
	local remoteDT = tim - remoteData.timer
	
	-- If packets arrive in wrong order, print warning message
	if remoteDT < 0 then
		print("Wrong position packet order! Vehicle ID: "..obj:getID()..", Old Timestamp: "..remoteData.timer..", New Timestamp: "..tim)
		
		-- Vehicle probably reset, so also reset disable time
		if remoteData.timer < 1 then
			disableUntil = 0
		end
		
		--return
	end
	
	remoteData.acc = (vel - remoteData.vel)/remoteDT
	remoteData.racc = (rvel - remoteData.rvel)/remoteDT
	
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
