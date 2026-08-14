local M = {}

local max = math.max
local min = math.min

M.showDebug = false

local targetSpeedSmoother = newTemporalSmoothingNonLinear(10,10)
local maxSpeedSmoother = newTemporalSmoothingNonLinear(15,15)

local toFarAheadTimer = 0
local toFarBehindTimer = 0
local runawayPause = false
local catchupMaxSpeed = false

local lastTimeError = 0

require("common/controlSystems")

local kP = 1.5
local tI = 0.6
local tD = 0.0

local minIntegral = -0.01
local maxIntegral = 1
local minOutput = -10
local maxOutput = 10
local integralInCoef = 1
local integralOutCoef = 1

local gameSpeedPID = newPIDParallel(kP, tI, tD, minOutput, maxOutput, integralInCoef, integralOutCoef, minIntegral, maxIntegral)

local function syncTime(dtRea, dtSim, dtRaw, allowSlowMotion)
	local maxCapableSpeedRaw = 1/dtRaw/20
	local timeError = getBeamMPServerTime() - (getBeamMPSimTime() + dtSim)

	local speedModify = -gameSpeedPID:get((getBeamMPSimTime() + dtSim),getBeamMPServerTime(),dtRaw)/2

	--TODO test catchupMaxSpeed on low spec machines
	local maxCapableSpeed = min(4,maxCapableSpeedRaw)
	local maxSpeedSmooth = maxSpeedSmoother:get(min(4,max(0.99,maxCapableSpeed)),dtRaw)

	if not runawayPause and timeError < -0.1 then
		toFarAheadTimer = toFarAheadTimer + dtRaw
		if toFarAheadTimer > 0.2 then
			runawayPause = true
			--dump("started runawayPause to align simTime",timeError)
		end
	else
		toFarAheadTimer = 0
	end

	if not catchupMaxSpeed and timeError > 0.1 and maxSpeedSmooth > 3 then
		toFarBehindTimer = toFarBehindTimer + dtRaw
		if toFarBehindTimer > 0.1 then
			catchupMaxSpeed = true
			--dump("started catchupMaxSpeed to align simTime",timeError)
		end
	else
		toFarBehindTimer = 0
	end

	if runawayPause and timeError > -(dtRea/2) then
		--dump("caught up on paused",timeError,-dtRaw)
		runawayPause = false
		gameSpeedPID:reset()
		toFarAheadTimer = 0
	end

	local errorVel = (timeError - lastTimeError)/dtRea
	local predictedError = timeError + errorVel * (dtRea*2)

	if catchupMaxSpeed and predictedError <= 0.02 then
		--dump("caught up with speed",timeError,dtRaw)
		catchupMaxSpeed = false
		toFarBehindTimer = 0
		be:setPhysicsSpeedFactor(0)
	end

	local speedModifyClamped = targetSpeedSmoother:get(max(-0.01,-speedModify),dtRaw)

	local targetSpeed = allowSlowMotion and simTimeAuthority.getReal() or 1
	local speed = targetSpeed + speedModifyClamped

	if runawayPause then
		speed = 0
	end

	if not catchupMaxSpeed and not isnaninf(speed) then
		be:setSimulationTimeScale(speed)
	elseif catchupMaxSpeed then
		be:setSimulationTimeScale(targetSpeed)
		be:setPhysicsSpeedFactor(1)
	end

	lastTimeError = timeError
end

local function reset()
	gameSpeedPID:reset()
end

local function onExtensionUnloaded()
	be:setSimulationTimeScale(simTimeAuthority.get()*(be:getEnabled() and 1 or 0))
	be:setPhysicsSpeedFactor(0)
	be:queueAllObjectLua("if positionVE then positionVE.enableSimTimeTracking = false end")
end

local function onDisableTimeSync()
	be:setSimulationTimeScale(simTimeAuthority.get()*(be:getEnabled() and 1 or 0))
	be:setPhysicsSpeedFactor(0)
end

M.syncTime = syncTime
M.reset = reset
M.onExtensionUnloaded = onExtensionUnloaded
M.onBeamMPServerLeave = onExtensionUnloaded
M.onDisableTimeSync = onDisableTimeSync

return M