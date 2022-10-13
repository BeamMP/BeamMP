--====================================================================================
-- All work by jojos38, Titch2000, Preston (Cobalt)
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}

-- ============= VARIABLES =============
local currentInputs = {}
local lastInputs = {}
local inputsToSend = {}
local localGearMode
local geartimer = 0
local lastgear
local remoteGear
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

local function applyGear(data) --TODO: revisit this
	if not electrics.values.gearIndex or electrics.values.gear == data then return end
	-- Detect the type of gearbox, frontMotor and rearMotor are for electrics car
	local gearboxType = (powertrain.getDevice("gearbox") or powertrain.getDevice("frontMotor") or powertrain.getDevice("rearMotor") or powertrain.getDevice("mainMotor") or "none").type
	if gearboxType == "manualGearbox" then
		local index = tonumber(data)
		if not index then return end
		if electrics.values.gearIndex ~= index then
			controller.mainController.shiftToGearIndex(index) -- Simply switch to the gear index
		end
	-- Sequential gearbox doesn't work with shiftToGearIndex. The loop is because the game
	-- does not allow skipping gears when using shiftToGearIndex on sequential gearboxes
	elseif gearboxType == "sequentialGearbox" then
		local index = tonumber(data)
		if not index then return end
		if electrics.values.gearIndex < index then
			controller.mainController.shiftUp()
		elseif electrics.values.gearIndex > index then
			controller.mainController.shiftDown()
		end
	-- We use the same thing as automatic for all the first gears, and we use
	-- the same type of shifting as sequential for M gears.
	elseif gearboxType == "dctGearbox" or gearboxType == "cvtGearbox" or gearboxType == "automaticGearbox" or gearboxType == "electricMotor" then
		local state = string.sub(data, 1, 1)
		local localstate = string.sub(electrics.values.gear, 1, 1)
		local index = tonumber(string.sub(data, 2, 3))
		local gearIndex = electrics.values.gearIndex
		if state == 'M' then
			if localGearMode ~= 'M' or localstate ~= 'M' then
				if localGearMode == 'S' or localGearMode == 'D' or localstate ~= 'M' then
					controller.mainController.shiftUp() -- this is so it doesn't go into M1 when switching into M modes at higher speed
					localGearMode = 'M1'
				else
					controller.mainController.shiftToGearIndex(translationTable[state])	--shifts into M1
					localGearMode = state
					gearIndex = 1
				end
			end
			if (localGearMode and localstate) == 'M' then
				if gearIndex < index then
					controller.mainController.shiftUp()
				elseif gearIndex > index then
					controller.mainController.shiftDown()
				end
			end
		else
			local index = translationTable[state]
			controller.mainController.shiftToGearIndex(index) -- shifts into gear using translation table
			localGearMode = state
		end
	end
end

local function updateGFX(dt) -- TODO: a better fix to ghost controlling than just setting inputs on every frame
	if not v.mpVehicleType == 'R' then return end
	geartimer = geartimer + 1
	if remoteGear and remoteGear ~= lastgear or remoteGear and geartimer == 2 then
		applyGear(remoteGear)
		geartimer = 0
	end
	lastgear = remoteGear
end


local function getInputs() --TODO: uncomment the difference checking for final release, currently commented because the current release will not apply inputs if all the inputs are not present in the data
	currentInputs = {
		s = electrics.values.steering_input and math.floor(electrics.values.steering_input * 1000) / 1000,
		t = electrics.values.throttle and math.floor(electrics.values.throttle * 1000) / 1000,
		b = electrics.values.brake and math.floor(electrics.values.brake * 1000) / 1000,
		p = electrics.values.parkingbrake and math.floor(electrics.values.parkingbrake * 1000) / 1000,
		c = electrics.values.clutch and math.floor(electrics.values.clutch * 1000) / 1000,
		g = electrics.values.gear
	}
	--for k,v in pairs(currentInputs) do
	--	if currentInputs[k] ~= lastInputs[k] then
	--		inputsToSend[k] = currentInputs[k]
	--	end
	--end
	--lastInputs = currentInputs

	--obj:queueGameEngineLua("MPInputsGE.sendInputs(\'"..jsonEncode(inputsToSend).."\', "..obj:getID()..")") -- Send it to GE lua
	obj:queueGameEngineLua("MPInputsGE.sendInputs(\'"..jsonEncode(currentInputs).."\', "..obj:getID()..")") -- Send it to GE lua
end


local function applyInputs(data)
	local decodedData = jsonDecode(data)
	if not decodedData then return end
	if decodedData.s then input.event("steering", decodedData.s, 3) end -- using gamepad filter for better smoothing
	if decodedData.t then input.event("throttle", decodedData.t, 2) end
	if decodedData.b then input.event("brake", decodedData.b, 2) end
	if decodedData.p then input.event("parkingbrake", decodedData.p, 2) end
	if decodedData.c then input.event("clutch", decodedData.c, 2) end
	if decodedData.g then remoteGear = decodedData.g end
end


M.updateGFX = updateGFX
M.getInputs   = getInputs
M.applyInputs = applyInputs


return M
