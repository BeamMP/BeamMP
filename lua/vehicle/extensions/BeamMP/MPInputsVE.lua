--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}



-- ============= VARIABLES =============
local lastInputs = {}
-- ============= VARIABLES =============



local function getInputs()
	-- Get inputs values
	local inputsTable = {
		input.state.steering.val,
		input.state.throttle.val,
		input.state.brake.val,
		input.state.parkingbrake.val,
		input.state.clutch.val
	}

	-- If inputs didn't change then return
	if inputsTable[1] == lastInputs[1]
	and inputsTable[2] == lastInputs[2]
	and inputsTable[3] == lastInputs[3]
	and inputsTable[4] == lastInputs[4]
	and inputsTable[5] == lastInputs[5]
	then return end

	obj:queueGameEngineLua("MPInputsGE.sendInputs(\'"..jsonEncode(inputsTable).."\', \'"..obj:getID().."\')") -- Send it to GE lua

	lastInputs = inputsTable
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
