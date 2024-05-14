-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

-- ============= VARIABLES =============
local currentInputs = {}
local lastInputs = {
	s = 0,
	t = 0,
	b = 0,
	p = 0,
	c = 0,
}

local lastInputsTable = {}
local inputCache = {}

local remoteGear
local unsupportedPowertrainDevice = false
local unsupportedPowertrainGearbox = false
-- ============= VARIABLES =============

local translationTable = {
	['R'] = -1,
	['N'] = 0,
	['P'] = 1,
	['D'] = 2,
	['S'] = 3,
	['2'] = 4,
	['1'] = 5,
	['M'] = 6
}

local gearBoxHandler = {
	["manualGearbox"] = 1,
	["sequentialGearbox"] = 1,
	["dctGearbox"] = 2,
	["cvtGearbox"] = 2,
	["automaticGearbox"] = 2,
	["electricMotor"] = 2
}

local function applyGear(data) --TODO: add handling for mismatched gearbox types between local and remote vehicle
	if not electrics.values.gearIndex or electrics.values.gear == data then return end
	local powertrainDevice = powertrain.getDevice("gearbox") or powertrain.getDevice("frontMotor") or powertrain.getDevice("rearMotor") or powertrain.getDevice("mainMotor")
	if powertrainDevice == nil then -- mods that introduce custom powertrains can trigger this
		if not unsupportedPowertrainDevice then
			unsupportedPowertrainDevice = true -- prevent spamming the log
			print('MPInputsVE Error in "applyGear()". Unsupported powertrain')
		end
		return nil
	end 
	
	-- certain gearbox need to be shifted with setGearIndex() while others need to be shifted with shiftXOnY()
	if gearBoxHandler[powertrainDevice.type] == 1 then
		local index = tonumber(data)
		if not index then return end
		powertrainDevice:setGearIndex(index)
		
	elseif gearBoxHandler[powertrainDevice.type] == 2 then
		if electrics.values.isShifting then return end
		local remoteGearMode = string.sub(data, 1, 1)
		local localGearMode = string.sub(electrics.values.gear, 1, 1)
		local remoteIndex = tonumber(string.sub(data, 2))
		if remoteGearMode == 'M' and localGearMode == 'M' then
			if electrics.values.gearIndex < remoteIndex then
				controller.mainController.shiftUpOnDown()
			elseif electrics.values.gearIndex > remoteIndex then
				controller.mainController.shiftDownOnDown()
			end
		else
			controller.mainController.shiftToGearIndex(translationTable[remoteGearMode])
		end
		
	else
		if not unsupportedPowertrainGearbox then
			unsupportedPowertrainGearbox = true -- prevent spamming the log
			print('MPInputsVE Error in "applyGear()" unknown GearBoxType "' .. powertrainDevice.type .. '"')
		end
	end
end

local function getInputs()
	local inputTableToSend = {}
	for input, _ in pairs(input.state) do
		local state = electrics.values[input] -- the electric is the most accurate place to get the value, the state.val is different with different filters and using the smoother states causes wrong inputs in arcade mode
		if state then
			if input == "steering" then
				if v.data.input then
					state = -state / v.data.input.steeringWheelLock or 1 -- converts steering wheel degrees to an input value
				end
			end
			if math.abs(state) < 0.001 then -- prevent super small values to count as updates
				state = 0
			end
			state = math.floor(state * 1000) / 1000
			if lastInputsTable[input] ~= state then
				inputTableToSend[input] = {state = state}
				lastInputsTable[input] = state
			end
		end
	end
	if not tableIsEmpty(inputTableToSend) then
		inputTableToSend.g = electrics.values.gear -- if there is any input we also send the gear in case a vehicle is spawned after it's been put into gear
		obj:queueGameEngineLua("MPInputsGE.sendInputs(\'"..jsonEncode(inputTableToSend).."\', "..obj:getID()..")") -- Send it to GE lua
	end

	 -- Old sync, keeping for temporary cross compatibility --
	local inputsToSend = {}
	currentInputs = {
		s = electrics.values.steering_input and math.floor(electrics.values.steering_input * 1000) / 1000,
		t = electrics.values.throttle and math.floor(electrics.values.throttle * 100) / 100,
		b = electrics.values.brake and math.floor(electrics.values.brake * 100) / 100,
		p = electrics.values.parkingbrake and math.floor(electrics.values.parkingbrake * 100) / 100,
		c = electrics.values.clutch and math.floor(electrics.values.clutch * 100) / 100,
		g = electrics.values.gear
	}
	if lastInputs.s and currentInputs.s and math.abs(math.abs(lastInputs.s) - math.abs(currentInputs.s)) > 0.005 then inputsToSend.s = currentInputs.s end
	for k,v in pairs(currentInputs) do
		if currentInputs[k] ~= lastInputs[k] and k ~= "s" then
			inputsToSend[k] = currentInputs[k]
		end
	end
	lastInputs = currentInputs

	if tableIsEmpty(inputsToSend) then return end
	inputsToSend.g = electrics.values.gear -- if there is any input we also send the gear in case a vehicle is spawned after it's been put into gear
	obj:queueGameEngineLua("MPInputsGE.sendInputs(\'"..jsonEncode(inputsToSend).."\', "..obj:getID()..")") -- Send it to GE lua
end

local recievedNewData -- for temporary cross compatibility

local function applyInputs(data)
	local decodedData = jsonDecode(data)
	if not decodedData then return end
	for inputName, inputData in pairs(decodedData) do
		if inputName and inputData and type(inputData) == "table" then
			if not inputCache[inputName] then
				inputCache[inputName] = {smoother = newTemporalSmoothing(1, 1, nil, 0), currentValue = 0, state = inputData.state}
			end
			inputCache[inputName].state = inputData.state
			inputCache[inputName].diffrence = math.abs(inputData.state-inputCache[inputName].currentValue)
			recievedNewData = true
		end
	end
	if decodedData.g then remoteGear = decodedData.g end

	if not recievedNewData then -- Old sync, keeping for temporary cross compatibility
		if decodedData.s then input.event("steering", decodedData.s, FILTER_PAD) end -- using gamepad filter for better smoothing
		if decodedData.t then input.event("throttle", decodedData.t, FILTER_DIRECT) end
		if decodedData.b then input.event("brake", decodedData.b, FILTER_DIRECT) end
		if decodedData.p then input.event("parkingbrake", decodedData.p, FILTER_DIRECT) end
		if decodedData.c then input.event("clutch", decodedData.c, FILTER_DIRECT) end
	end
end

local GEtickrate = 30 -- match this to inputsTickrate in MPupdatesGE

local function updateGFX(dt)
	if v.mpVehicleType == 'R' then
		if remoteGear then
			applyGear(remoteGear)
		end
		for inputName, inputData in pairs(inputCache) do
			inputData.currentValue = inputData.smoother:get(inputData.state,inputData.diffrence*(dt*GEtickrate))
			input.event(inputName, inputData.currentValue or 0, FILTER_DIRECT)
		end
	end
end

local function onReset()
	for _, inputData in pairs(inputCache) do
		inputData.smoother:reset()
	end
end

M.updateGFX = updateGFX
M.onReset = onReset
M.getInputs   = getInputs
M.applyInputs = applyInputs


return M
