--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}



-- ============= VARIABLES =============
local lastInputs = {}
local sendInputsDelay = 0
-- ============= VARIABLES =============



local function getInputs()
	local eTable = {}
	eTable[1] = input.state.steering.val
	eTable[2] = input.state.throttle.val
	eTable[3] = input.state.brake.val
	eTable[4] = input.state.parkingbrake.val
	eTable[5] = input.state.clutch.val
	
	if eTable[1] == lastInputs[1]
	and eTable[2] == lastInputs[2]
	and eTable[3] == lastInputs[3]
	and eTable[4] == lastInputs[4]
	and eTable[5] == lastInputs[5]
	then return end

	obj:queueGameEngineLua("inputsGE.sendInputs(\'"..jsonEncode(eTable).."\', \'"..obj:getID().."\')") -- Send it to GE lua

	lastInputs = eTable
end



local function applyInputs(data)
	local decodedData = jsonDecode(data) -- Decode received data
	input.event("steering", decodedData[1], 1)
	input.event("throttle", decodedData[2], 1)
	input.event("brake", decodedData[3], 1)
	input.event("parkingbrake", decodedData[4], 1)
	input.event("clutch", decodedData[5], 1)
end



M.getInputs   = getInputs
M.applyInputs = applyInputs



return M