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
	return timeShiftSpeed
end

local function updateSimTime()
	local data = obj:getLastMailbox("BeamMPTimeOffsets")
	if #data ~= timeOffsetsSize then return end
	ffi.copy(timeOffsets, data, timeOffsetsSize)

    simTimeOffset = timeOffsets[0].simTimeOffset
    cpuTimeOffset = timeOffsets[0].cpuTimeOffset
    timeShiftSpeed = timeOffsets[0].timeShiftSpeed

	--dump("simTimeOffset",simTimeOffset)
	--dump("cpuTimeOffset",cpuTimeOffset)
	--dump("timeShiftSpeed",timeShiftSpeed)
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
M.updateGFX        = updateGFX

return M