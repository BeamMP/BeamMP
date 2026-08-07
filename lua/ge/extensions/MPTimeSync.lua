local M = {}

local abs = math.abs
local min = math.min
local max = math.max
local floor = math.floor

----options----

local allowSlowMotion = true
local speedShiftEnabled = false


ffi.cdef [[
	typedef struct {
		double gameTime;
        uint64_t serverTime;
	} timeStruct;

	typedef struct {
		double simTimeOffset;
        double cpuTimeOffset;
        double timeShiftSpeed;
	} timeSyncStruct;
]]

local cpuTime = ffi.new("double[1]")
local cpuTimeSize = ffi.sizeof("double")

local timeData = ffi.new("timeStruct[1]")
local timeOffsets = ffi.new("timeSyncStruct[1]")
local timeOffsetsSize = ffi.sizeof("timeSyncStruct")

local queuedSimSpeed = 0
local veSimTime = 0

local pingCount = 0
local pingTimer = 0
local pingSendRate = 1/2

local targetTimeOffset = 0
local timeOffsetCPU = 0
local lastTimeOffsetCPU = 0

local simTimeError = 0

local timeOffsetSim = 0
local lastTimeOffsetSim = 0
local timeOffsetSimSmooth = 0
local timeOffsetSimChangeRate = 0

local BeamMPSimTime = 0

local serverTimeRecOffsetSmoother = newTemporalSmoothingNonLinear(1,1)
local serverTimeOffsetSmoother = newTemporalSmoothingNonLinear(0.03,0.03)

local timeOffsetSimSmoother = newTemporalSmoothingNonLinear(3)

local accumulatedDTRaw = 0
local calculatedGameSpeedRaw = 1
local calculatedGameSpeed = 1

local speedSmoother = newTemporalSmoothingNonLinear(2,5)
local maxSpeedSmoother = newTemporalSmoothingNonLinear(25,15)

local maxCapableSpeed = 1
local avgSpeed = 1
local maxSpeedSmooth = 1
local speedAverage = {}
local speedAverageIteration = 0
local speedAverageBufferLen = 100
local speedAverageTime = 0.4

for i=1,speedAverageBufferLen do
	speedAverage[i] = {speed = 1,time = os.clock()}
end

local lastFrameTime = 0
local showFPSwarnTimer = 0

function getBeamMPServerTime()
	return os:clockhp()-timeOffsetCPU
end

function getBeamMPSimTime()
	return (veSimTime - timeOffsetSimSmooth) --+ tempShiftTimeSmoother:get(tempShiftTime,lastDT) -- 0.2
end

local function setSimOffset()
	local lastOffset = timeOffsetSim
	local serverTime = getBeamMPServerTime()
	timeOffsetSim = veSimTime - serverTime
	timeOffsetSimSmoother:set(timeOffsetSim)
	timeOffsetSimSmooth = timeOffsetSim
	lastTimeOffsetSim = timeOffsetSim
	timeOffsetSimChangeRate = 0

	BeamMPSimTime = getBeamMPSimTime()
	return timeOffsetSim-lastOffset
end

local function sendOffsetsToVE(vehID)
    timeOffsets[0].simTimeOffset = timeOffsetSimSmooth
    timeOffsets[0].cpuTimeOffset = timeOffsetCPU
    timeOffsets[0].timeShiftSpeed = timeOffsetSimChangeRate
    local data = ffi.string(timeOffsets, timeOffsetsSize)
	be:sendToMailbox("BeamMPTimeOffsets",data)
end

local function checkVehicleTime(dtSim)
    local time = 0
    if MPTimeSyncVehicleTracker then
        time = MPTimeSyncVehicleTracker.checkTrackingVehicle(dtSim, BeamMPSimTime, veSimTime)
    end
    return time
end

local function checkSimulationSpeed(dtRea, dtSim, dtRaw)
	if dtSim ~= 0 then
		calculatedGameSpeedRaw = dtSim/(dtRaw + accumulatedDTRaw)

		accumulatedDTRaw = 0
	else
		accumulatedDTRaw = accumulatedDTRaw + dtRaw
	end

	calculatedGameSpeed = speedSmoother:get(calculatedGameSpeedRaw,dtRaw)

	local maxCapableSpeedRaw = 1/dtRaw/20

	speedAverageIteration = speedAverageIteration + 1
	if speedAverageBufferLen <= speedAverageIteration then
		speedAverageIteration = 1
	end
	speedAverage[speedAverageIteration].speed = maxCapableSpeedRaw
	speedAverage[speedAverageIteration].time = os.clock()

	avgSpeed = 0
	local count = 0
	local curTime = os.clock()
	for k,v in pairs(speedAverage) do
		if curTime - v.time < speedAverageTime then
			avgSpeed = avgSpeed + v.speed
			count = count + 1
		end
	end
	avgSpeed = avgSpeed/count

	local gameSpeed = simTimeAuthority.getReal()
	if gameSpeed == 0 then
		gameSpeed = 1
	end

	maxCapableSpeed = min(1.2,maxCapableSpeedRaw)

	maxSpeedSmooth = maxSpeedSmoother:get(min(1.1,max(0.99,maxCapableSpeed)),dtRaw)

	local targetGameSpeed = allowSlowMotion and gameSpeed or 1
	local timeShift = 0
	local decoupledTimeShift = 1
	local lowFPStimeShift = 1

	if targetGameSpeed ~= 1 or maxSpeedSmooth < 1 and calculatedGameSpeed < 1 then-- prevent prediction runaway if fps is lower than 20, aka game can't run full speed, this may cause issues with competitive timers if they use this mod's server or sim time, will need to investigate
		local roundedGameSpeed = (floor((calculatedGameSpeed*1000)+0.5)/1000)
		local gameSpeedPercent = floor(roundedGameSpeed*100)
		if avgSpeed < 1 and gameSpeedPercent < 100 then
			lowFPStimeShift = min(1,avgSpeed - (simTimeError*0.5*(gameSpeed*2)))
			if lastFrameTime ~= floor(1/(dtRaw)) or showFPSwarnTimer < 0 then
				showFPSwarnTimer = 2
				guihooks.message("fps is low, should be above 20 : currently "..floor(1/(dtRaw)).."fps \nsimulation speed is running slow : currently "..gameSpeedPercent.."%", 3, "serverSimSyncFPSWarn" , "warning")
			end
			showFPSwarnTimer = showFPSwarnTimer - dtRaw
		elseif avgSpeed < 1 then
			showFPSwarnTimer = showFPSwarnTimer - dtRaw
			if lastFrameTime ~= floor(1/(dtRaw)) or showFPSwarnTimer < 0 then
				showFPSwarnTimer = 2
				guihooks.message("fps is good, should be above 20 : currently "..floor(1/(dtRaw)).."fps \nsimulation speed is running real time", 3, "serverSimSyncFPSWarn" , "warning")
			end
		end
		lastFrameTime = floor(1/(dtRaw))
	end

	timeShift = (dtRaw*max((1-targetGameSpeed),(1-lowFPStimeShift)))

	if not speedShiftEnabled then
		decoupledTimeShift = simTimeError/5
		timeShift = timeShift + decoupledTimeShift*dtRaw
	end

	if timeShift ~= 0 then
		timeOffsetSim = timeOffsetSim - timeShift
	end
end

local function timeSyncUpdate(dtReal, dtSim, dtRaw)
    veSimTime = checkVehicleTime(dtSim)
	timeOffsetCPU = serverTimeOffsetSmoother:get(targetTimeOffset,dtRaw)

	local timeOffsetError = abs(timeOffsetCPU - targetTimeOffset)
	if timeOffsetError > 1 or pingCount == 15 then
		serverTimeOffsetSmoother:set(targetTimeOffset)
        timeOffsetCPU = targetTimeOffset
		setSimOffset()
	end

	local isPaused = not be:getEnabled()
	if isPaused then
		timeOffsetSim = timeOffsetSim - dtRaw
		timeOffsetSimSmoother:set(timeOffsetSim)
		timeOffsetSimSmooth = timeOffsetSim
		lastTimeOffsetSim = timeOffsetSim
		timeOffsetSimChangeRate = 1
		sendOffsetsToVE()
		return
	end

	simTimeError = getBeamMPServerTime() - getBeamMPSimTime()
	if abs(simTimeError) > 1 then
		setSimOffset()
		simTimeError = 0
	end

	timeOffsetSimSmooth = timeOffsetSimSmoother:get(timeOffsetSim,dtRaw)
	timeOffsetSimChangeRate = (timeOffsetSimSmooth - lastTimeOffsetSim)/dtRaw

	if lastTimeOffsetCPU ~= timeOffsetCPU or queuedSimSpeed ~= 0 then
		sendOffsetsToVE()
	end

	checkSimulationSpeed(dtReal, dtSim, dtRaw)

	lastTimeOffsetCPU = timeOffsetCPU
	lastTimeOffsetSim = timeOffsetSimSmooth
end

local function sendPing()
    cpuTime[0] = os:clockhp()
    local data = ffi.string(cpuTime, cpuTimeSize)
    MPGameNetwork.send("t"..data)
end

local function receivePing(data, dtRaw)
    if #data ~= ffi.sizeof("timeStruct") then return end
	ffi.copy(timeData, data, ffi.sizeof("timeStruct"))

    local gameTime = timeData[0].gameTime
    local serverTime = tonumber(timeData[0].serverTime)/1000

	pingCount = pingCount + 1

	local responseTime = math.max(0,os:clockhp() - gameTime - dtRaw) -- dtRaw removes frame time from ping so it's not divided by 2

	local rawOffset = os:clockhp() - serverTime - dtRaw + responseTime/2 -- but dtRaw needs to also be subtracted here to get the correct offset

	if abs(targetTimeOffset - rawOffset) > 1 or pingCount == 1 then
		serverTimeRecOffsetSmoother:set(rawOffset)
	end

	targetTimeOffset = serverTimeRecOffsetSmoother:get(rawOffset, pingSendRate)
end

local function onUpdate(dtReal, dtSim,dtRaw)
	pingTimer = pingTimer + dtRaw
	if pingTimer >= pingSendRate then
		pingTimer = 0
		sendPing()
	end

    timeSyncUpdate(dtReal, dtSim, dtRaw)
end

local function onExtensionUnloaded()
	be:setSimulationTimeScale(simTimeAuthority.get()*(be:getEnabled() and 1 or 0))
	be:setPhysicsSpeedFactor(0)
	be:queueAllObjectLua("if positionVE then positionVE.enableSimTimeTracking = false end")
end

M.receivePing = receivePing
M.onUpdate = onUpdate
M.onExtensionUnloaded = onExtensionUnloaded

return M