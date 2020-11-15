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
local checkNow = false
-- ============= VARIABLES =============



local disallowedKeys = {
	["wheelThermals"] = 1,
	["airflowspeed"] = 1,
	["airspeed"] = 1,
	["altitude"] = 1,
	["avgWheelAV"] = 1,
	["clutch_input"] = 1,
	["driveshaft"] = 1,
	["driveshaft_F"] = 1,
	["engineLoad"] = 1,
	["exhaustFlow"] = 1,
	["fuel"] = 1,
	["fuelVolume"] = 1,
	["oiltemp"] = 1,
	["rpm"] = 1,
	["rpmTacho"] = 1,
	["rpmspin"] = 1,
	["virtualAirspeed"] = 1,
	["watertemp"] = 1,
	["wheelspeed"] = 1,
	["turnsignal"] = 1,
	["hazard"] = 1,
	["signal_R"] = 1,
	["signal_L"] = 1,
	["radiatorFanSpin"] = 1,
	["turboBoost"] = 1,
	["turboSpin"] = 1,
	["turboRPM"] = 1,
	["turboRpmRatio"] = 1,
	["engineThrottle"] = 1,
	["throttle"] = 1,
	["brake_input"] = 1,
	["brake"] = 1,
	["brakelights"] = 1,
	["clutch"] = 1,
	["clutchRatio"] = 1,
	["steering"] = 1,
	["steering_input"] = 1,
	["throttle_input"] = 1,
	["abs"] = 1,
	["lights"] = 1,
	["wheelaxleFR"] = 1,
	["wheelaxleFL"] = 1,
	["wheelaxleRR"] = 1,
	["wheelaxleRL"] = 1,
	["axle_FR"] = 1,
	["axle_FL"] = 1,
	["axle_RR"] = 1,
	["axle_RL"] = 1,
	["throttleFactorRear"] = 1,
	["throttleFactorFront"] = 1,
	["esc"] = 1,
	["tcs"] = 1,
	["escActive"] = 1,
	["absActive"] = 1,
	["disp_N"] = 1,
	["regenThrottle"] = 1,
	["disp_1"] = 1,
	["tcsActive"] = 1,
	["clutchRatio1"] = 1,
	["lockupClutchRatio"] = 1,
	["throttleOverride"] = 1,
	["cruiseControlTarget"] = 1
}



local function onUpdate(dt) --ONUPDATE OPEN
	if checkNow then -- Defined by MPUpdatesGE
		local electricsToSend = {} -- This holds the data that is different from the last frame to be sent since it is different
		local electricsChanged = false
		local e = electrics.values
		for k,v in pairs(e) do -- For each electric value
			if not disallowedKeys[k] then -- If it's not a disallowed key
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
		checkNow = false
	end
end --ONUPDATE CLOSE



local function applyGear(data)
	if not (data) then return end
	if data == "R" then
		controller.mainController.shiftToGearIndex(-1)
	elseif data == "N" then
		controller.mainController.shiftToGearIndex(0)
	elseif data == "P" then
		controller.mainController.shiftToGearIndex(1)
	elseif data == "D" then
		controller.mainController.shiftToGearIndex(2)
	else
		controller.mainController.shiftToGearIndex(tonumber(data))
	end
end



local function check()
	checkNow = true
end



local function applyElectrics(data)
	local decodedData = jsonDecode(data) -- Decode received data
	if (decodedData) then -- If received data is correct
		for k,v in pairs(decodedData) do
			electrics.values[k] = v
			if k == "hazard_enabled" then
				electrics.set_warn_signal(v)
			elseif k == "signal_left_input" then
				electrics.toggle_left_signal()
			elseif k == "signal_right_input" then
				electrics.toggle_right_signal()
				--electrics.update(0) -- Update electrics values
			elseif k == "lights_state" then
				electrics.setLightsState(v) -- Apply lights values
			elseif k == "fog" then
				electrics.set_fog_lights(v)
			elseif k == "lightbar" then
				electrics.set_lightbar_signal(v) -- Apply lightbar values
			elseif k == "engineRunning" then
				if v > 0.99 then
					controller.mainController.setStarter(true)
				else
					controller.mainController.setEngineIgnition(false)
				end
			elseif k == "horn" then
				if v > 0.99 then
					electrics.horn(true)
				else
					electrics.horn(false)
				end
			else
			end
		end
		latestData = data
	end
end



local function applyLatestElectrics()
	applyElectrics(latestData)
end



M.check				   = check
M.applyGear			   = applyGear
M.applyElectrics	   = applyElectrics
M.applyLatestElectrics = applyLatestElectrics
M.updateGFX	    	   = onUpdate



return M
