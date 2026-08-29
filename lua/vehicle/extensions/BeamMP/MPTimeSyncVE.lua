local M = {}

ffi.cdef [[
	typedef struct {
		double simTimeOffset;
        double cpuTimeOffset;
        double timeShiftSpeed;
	} timeSyncStruct;
]]

local timeOffsets = ffi.new("timeSyncStruct[1]")
local timeOffsetsSize = ffi.sizeof("timeSyncStruct")

M.isSimTimeTracker = false
M.useTimeSync = false
M.ready = false

local simTimeOffset = 0
local cpuTimeOffset = 0
local timeShiftSpeed = 0

local function getServerTime()
	return os:clockhp()-cpuTimeOffset
end

local lastTime = obj:getSimTime()
local function getSimTimeSafe()
	local time = obj:getSimTime()
	if time == 0 then -- if an updateGFX frame runs in between two physics ticks then getSimTime return 0 instead of the simulation time
		time = lastTime
	end
	return time
end

local function getServerSimTime()
	return getSimTimeSafe() - simTimeOffset
end

local function getSimSpeed()
	return (1 + timeShiftSpeed)
end

local lastMailboxVersion = -2
local lastMailboxVersion1 = -2
local lastMailboxVersion2 = -2
local function updateSimTime()
	local currentMailBoxVersion = obj:getLastMailboxVersion("BeamMPTimeOffsets")

	local currentMailBoxVersion1 = obj:getLastMailboxVersion("BeamMPUseTimeSync")
	local currentMailBoxVersion2 = obj:getLastMailboxVersion("BeamMPTimeSyncReady")
	if lastMailboxVersion ~= currentMailBoxVersion then
		local data = obj:getLastMailbox("BeamMPTimeOffsets")
		if #data ~= timeOffsetsSize then return end
		ffi.copy(timeOffsets, data, timeOffsetsSize)

    	simTimeOffset = timeOffsets[0].simTimeOffset
    	cpuTimeOffset = timeOffsets[0].cpuTimeOffset
    	timeShiftSpeed = timeOffsets[0].timeShiftSpeed
	end

	if lastMailboxVersion1 ~= currentMailBoxVersion1 then
		local data = obj:getLastMailbox("BeamMPUseTimeSync")
		if data == "true" then
			M.useTimeSync = true
		else
			M.useTimeSync = false
		end
	end

	if lastMailboxVersion2 ~= currentMailBoxVersion2 then
		local data = obj:getLastMailbox("BeamMPTimeSyncReady")
		if data == "true" then
			M.ready = true
		else
			M.ready = false
		end
	end

	lastMailboxVersion = currentMailBoxVersion
	lastMailboxVersion1 = currentMailBoxVersion1
	lastMailboxVersion2 = currentMailBoxVersion2
end

local function updateGFX(dt)
    updateSimTime()
	if M.isSimTimeTracker then
		local cpuTime = os:clockhp()
		obj:queueGameEngineLua("MPTimeSyncVehicleTracker.setSimTime("..getSimTimeSafe()..", "..cpuTime..","..objectId..")")
	end
end

M.getServerTime    = getServerTime
M.getServerSimTime = getServerSimTime
M.getSimSpeed      = getSimSpeed
M.onDebugDraw      = updateGFX

return M