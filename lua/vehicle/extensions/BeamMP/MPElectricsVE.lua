--====================================================================================
-- All work by Jojos38 & Titch2000.
-- You have no permission to edit, redistrobute or upload. Contact us for more info!
--====================================================================================



local M = {}



-- ============= VARIABLES =============
local lastElectrics = {}
local lastGear = -1
local latestData
local electricsChanged = false
local localGearIndex = 0
local latestGearData
local localGearMode
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



local function applyGear(data)
	if not electrics.values.gearIndex then return ends
	-- Detect the type of gearbox, frontMotor and rearMotor are for electrics car
	local gearboxType = (powertrain.getDevice("gearbox") or powertrain.getDevice("frontMotor") or powertrain.getDevice("rearMotor")).type
	if gearboxType == "manualGearbox" then
		local index = tonumber(data)
		if electrics.values.gearIndex ~= index then
			controller.mainController.shiftToGearIndex(index) -- Simply switch to the gear index
		end
	-- Sequential gearbox doesn't work with shiftToGearIndex, for some reason reverse is
	-- -2 and not -1 so we need to do a loop to down shift. The loop is because the game
	-- does not allow skipping gears when using shiftToGearIndex on sequential gearboxes
	elseif gearboxType == "sequentialGearbox" then
		local index = tonumber(data)
		if electrics.values.gearIndex < index then
			controller.mainController.shiftUp()
		elseif electrics.values.gearIndex > index then
			controller.mainController.shiftDown()
		end

	-- Nothing special
	elseif gearboxType == "automaticGearbox" or gearboxType == "electricMotor" then
		local index = translationTable[data]
		local state = string.sub(data, 1, 1)
		if localGearMode ~= state then
			controller.mainController.shiftToGearIndex(translationTable[state])
		end
		if state == 'M' and localGearMode == state then
			local index = tonumber(string.sub(data, 2, 2))
			if electrics.values.gearIndex < index then
				controller.mainController.shiftUp()
			elseif electrics.values.gearIndex > index then
				controller.mainController.shiftDown()
			end
		end
		localGearMode = state

	-- We use the same thing as automatic for all the first gears, and we use
	-- the same type of shifting as sequential for M gears.
	elseif gearboxType == "dctGearbox" or gearboxType == "cvtGearbox" then
		print("dctGearbox cvtGearbox")
		local state = string.sub(data, 1, 1)
		if state == 'M' then
			if localGearMode ~= 'M' then
				controller.mainController.shiftToGearIndex(translationTable[state])
				localGearMode = 'M'
			end
			local index = tonumber(string.sub(data, 2, 2))
			if electrics.values.gearIndex < index then
				controller.mainController.shiftUp()
			elseif electrics.values.gearIndex > index then
				controller.mainController.shiftDown()
			end
		else
			local index = translationTable[state]
			controller.mainController.shiftToGearIndex(index)
			localGearMode = state
		end
	end

	latestGearData = data
end

local allowedKeys = {
	["signal_left_input"] = 1,
	["signal_right_input"] = 1,
	["hazard_enabled"] = 1,
	["lights_state"] = 1,
	["lightbar"] = 1,
	["horn"] = 1,
	["fog"] = 1
}

local function checkGears()
	if latestGearData then
		applyGear(latestGearData)
	end
end

local function check()
	local electricsToSend = {} -- This holds the data that is different from the last frame to be sent since it is different
	local electricsChanged = false
	local e = electrics.values
	if not e or not e.gear then return end -- Error avoidance in console
	for k,v in pairs(e) do -- For each electric value
		if allowedKeys[k] then -- If it's not a disallowed key
			if lastElectrics[k] ~= v then -- If the value changed
				electricsChanged = true -- Send electrics
				lastElectrics[k] = v -- Define the new value
				electricsToSend[k] = v
			end
		end
	end	
	if electricsChanged then
		obj:queueGameEngineLua("MPElectricsGE.sendElectrics(\'"..jsonEncode(electricsToSend).."\', \'"..obj:getID().."\')")
	end	
	if e.gear ~= lastGear then
		obj:queueGameEngineLua("MPElectricsGE.sendGear(\'"..e.gear.."\', \'"..obj:getID().."\')")
		lastGear = e.gear
	end
end



local lastLeftSignal = 0
local lastRightSignal = 0
local lastHazards = 0
local function applyElectrics(data)
	local decodedData = jsonDecode(data) -- Decode received data
	if (decodedData) then -- If received data is correct
		if not decodedData.signal_left_input then decodedData.signal_left_input = lastLeftSignal end
		if not decodedData.signal_right_input then decodedData.signal_right_input = lastRightSignal end
		if not decodedData.hazard_enabled then decodedData.hazard_enabled = lastHazards end
		
		lastLeftSignal = decodedData.signal_left_input
		lastRightSignal = decodedData.signal_right_input
		lastHazards = decodedData.hazard_enabled

		if decodedData.hazard_enabled then -- Apply hazard lights
			electrics.set_warn_signal(decodedData.hazard_enabled)
			electrics.update(0) -- Update electrics values
		end
		if decodedData.hazard_enabled == 0 then -- Apply left signal value
			if electrics.values.signal_left_input ~= decodedData.signal_left_input then
				electrics.toggle_left_signal()
			elseif electrics.values.signal_right_input ~= decodedData.signal_right_input then
				electrics.toggle_right_signal()
			end
			electrics.update(0) -- Update electrics values
		end
		if decodedData.lights_state then
			electrics.setLightsState(decodedData.lights_state) -- Apply lights values
		end
		if decodedData.lightbar then
			electrics.set_lightbar_signal(decodedData.lightbar) -- Apply lightbar values		
		end
		if decodedData.horn then
			if decodedData.horn > 0.99 then electrics.horn(true)
			else electrics.horn(false) end
		end
		if decodedData.fog then
			electrics.set_fog_lights(decodedData.fog)
		end
		latestData = data
	end
end



local function onReset()
	if v.mpVehicleType == "R" then
		controller.mainController.setGearboxMode("realistic")
		localGearIndex = 0
	end
end



local function onExtensionLoaded()
	if v.mpVehicleType == "R" then
		controller.mainController.setGearboxMode("realistic")
		controller.mainController.setStarter(true)
		controller.mainController.setEngineIgnition(true)
	end
end



local function applyLatestElectrics()
	applyElectrics(latestData)
end



M.onExtensionLoaded    = onExtensionLoaded
M.onReset			   = onReset
M.check				   = check
M.checkGears		   = checkGears
M.applyGear			   = applyGear
M.applyElectrics	   = applyElectrics
M.applyLatestElectrics = applyLatestElectrics



return M
