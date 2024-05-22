-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

-- ============= VARIABLES =============
local smoothingRate = 30 -- setting this to half inputsTickrate in MPupdatesGE seems to give smooth results, though with a bit higher latency, matching it jitters at certian framerates

local lastInputs = {
	s = 0,
	t = 0,
	b = 0,
	p = 0,
	c = 0,
}

local inputCache = {}

local periodicGearSyncTimer = 0
local remoteGear
local unsupportedPowertrainDevice = false
local unsupportedPowertrainGearbox = false
local disableGhostInputs = false
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

local shortName = {
	steering = "s",
	throttle = "t",
	brake = "b",
	parkingbrake = "p",
	clutch = "c"
}

local function getInputs()
	local inputsToSend = {}
	for inputName, _ in pairs(input.state) do
		local state = electrics.values[inputName] -- the electric is the most accurate place to get the input value, the state.val is different with different filters and using the smoother states causes wrong inputs in arcade mode
		if state then
			if inputName == "steering" then
				if v.data.input then
					state = -state / (v.data.input.steeringWheelLock or 1) -- converts steering wheel degrees to an input value
				end
			end
			if math.abs(state) < 0.001 then -- prevent super small values to count as updates
				state = 0
			end
			state = math.floor(state * 1000) / 1000
			if shortName[inputName] then
				inputName = shortName[inputName]
			end
			if lastInputs[inputName] ~= state then
				inputsToSend[inputName] = state
				lastInputs[inputName] = state
			end
		end
	end

	if electrics.values.gear ~= lastInputs.g or periodicGearSyncTimer >= 5 then -- sending the gear every 5 seconds for when a car is spawned after it's been put into gear
		periodicGearSyncTimer = 0
		inputsToSend.g = electrics.values.gear
	end
	lastInputs.g = electrics.values.gear

	if tableIsEmpty(inputsToSend) then return end
	obj:queueGameEngineLua("MPInputsGE.sendInputs(\'"..jsonEncode(inputsToSend).."\', "..obj:getID()..")") -- Send it to GE lua
end

local function storeTargetValue(inputName,inputState)
	if not inputCache[inputName] then
		inputCache[inputName] = {smoother = newTemporalSmoothingNonLinear(smoothingRate), currentValue = 0, state = inputState}
		if v.mpVehicleType == "R" then -- non defined inputs do not exist in input.state until they are pressed once so we have to add those here instead
			input.setAllowedInputSource(inputName, "local", false)
			input.setAllowedInputSource(inputName, "BeamMP", true)
		end
	end
	inputCache[inputName].state = inputState
	inputCache[inputName].difference = math.abs(inputState-inputCache[inputName].currentValue) -- storing and using the difference for the smoother makes the input more responsive on big/quick changes
end

local function applyInputs(data)
	local decodedData = jsonDecode(data)
	if not decodedData then return end
	for inputName, inputState in pairs(decodedData) do
		if inputName == "g" then remoteGear = decodedData.g
		elseif inputName == "s" then storeTargetValue("steering",inputState)
		elseif inputName == "t" then storeTargetValue("throttle",inputState)
		elseif inputName == "b" then storeTargetValue("brake",inputState)
		elseif inputName == "p" then storeTargetValue("parkingbrake",inputState)
		elseif inputName == "c" then storeTargetValue("clutch",inputState)
		else
			storeTargetValue(inputName,inputState)
		end
	end
end

local function updateGFX(dt)
	if v.mpVehicleType == 'R' then
		if remoteGear then
			applyGear(remoteGear)
		end
		for inputName, inputData in pairs(inputCache) do -- smoothing and applying the inputs
			inputData.currentValue = inputData.smoother:get(inputData.state,dt)
			input.event(inputName, inputData.currentValue or 0, FILTER_DIRECT,nil,nil,nil,"BeamMP")
		end
		if not disableGhostInputs then
			disableGhostInputs = true
			for inputName, _ in pairs(input.state) do
				input.setAllowedInputSource(inputName, "local", false) -- disables local inputs, prevents ghost controlling
				input.setAllowedInputSource(inputName, "BeamMP", true)
			end
		end
	elseif v.mpVehicleType == 'L' then
		periodicGearSyncTimer = periodicGearSyncTimer + dt
		if disableGhostInputs then -- if we get vehicle owner change this will enable the inputs again when the vehicle is set to local
			disableGhostInputs = false
			for inputName, _ in pairs(input.state) do
				input.setAllowedInputSource(inputName, "local", true)
			end
		end
	end
end

local function onReset()
	lastInputs = {} -- clear the lastInputs table on reset so arcade auto brake, clutch and parking brake syncs correctly on reset
	for _, inputData in pairs(inputCache) do
		inputData.currentValue = 0
		inputData.difference = 0
		inputData.state = 0
		inputData.smoother:reset()
	end
end

local function onExtensionLoaded()
	for inputName, state in pairs(input.state) do
		storeTargetValue(inputName, state.val or 0)
	end
end

M.updateGFX = updateGFX
M.onReset = onReset
M.getInputs   = getInputs
M.applyInputs = applyInputs
M.onExtensionLoaded = onExtensionLoaded


return M
