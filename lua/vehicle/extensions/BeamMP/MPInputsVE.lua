--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================
-- Input (pedals & steering) sync related functions
--====================================================================================

local M = {}



-- ============= VARIABLES =============
local lastInputs = {}
-- ============= VARIABLES =============



local function getInputs()
	-- Get inputs values
	local inputsTable = {
		s = electrics.values.steering_input,
		t = electrics.values.throttle,
		b = electrics.values.brake,
		p = electrics.values.parkingbrake,
		c = electrics.values.clutch
	}

	-- If inputs didn't change then return
	if inputsTable.s == lastInputs.s
	and inputsTable.t == lastInputs.t
	and inputsTable.b == lastInputs.b
	and inputsTable.p == lastInputs.p
	and inputsTable.c == lastInputs.c
	then return end

	obj:queueGameEngineLua("MPInputsGE.sendInputs(\'"..jsonEncode(inputsTable).."\', "..obj:getID()..")") -- Send it to GE lua

	lastInputs = inputsTable
end



local function applyInputs(data)
	local decodedData = jsonDecode(data) -- Decode received data
	if decodedData.s and decodedData.t and decodedData.b and decodedData.p and decodedData.c then
		input.event("steering", decodedData.s, 1)
		input.event("throttle", decodedData.t, 1)
		input.event("brake", decodedData.b, 1)
		input.event("parkingbrake", decodedData.p, 1)
		input.event("clutch", decodedData.c, 1)
	end
end



M.getInputs   = getInputs
M.applyInputs = applyInputs



return M
