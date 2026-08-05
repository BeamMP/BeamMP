-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}



-- ============= VARIABLES =============
local lastElectrics = {}
local checkElectrics = {}
local electricsToSend = {}

local latestData
local electricsChanged = false
local localSwingwing = 0 -- for DH Super bolide
-- ============= VARIABLES =============



local disallowedKeys = {
	["wheelThermals"] = 1,
	["airflowspeed"] = 1,
	["airspeed"] = 1,
	["altitude"] = 1,
	["avgWheelAV"] = 1,
	["throttle_input"] = 1,
	["brake_input"] = 1,
	["clutch_input"] = 1,
	["steering_input"] = 1,
	["parkingbrake_input"] = 1,
	["throttle"] = 1,
	["brake"] = 1,
	["clutch"] = 1,
	["steering"] = 1,
	["brakelights"] = 1,
	["clutchRatio"] = 1,
	["parkingbrake"] = 1,
	["driveshaft"] = 1,
	["driveshaft_F"] = 1,
	["driveshaft_R"] = 1,
	["engineLoad"] = 1,
	["exhaustFlow"] = 1,
	["fuel"] = 1,
	--["fuelVolume"] = 1,
	["fuelCapacity"] = 1,
	["jatofuel"] = 1,
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
	["abs"] = 1,
	["hasABS"] = 1,
	["disp_P"] = 1,
	["disp_R"] = 1,
	["disp_N"] = 1,
	["disp_D"] = 1,
	["regenThrottle"] = 1,
	["disp_1"] = 1,
	["tcsActive"] = 1,
	["clutchRatio1"] = 1,
	["clutchRatio2"] = 1,
	["lockupClutchRatio"] = 1,
	["throttleOverride"] = 1,
	["cruiseControlTarget"] = 1,
	["isShifting"] = 1,
	["unicycle_body"] = 1,
	["led"] = 1,
	["led0"] = 1,
	["led1"] = 1,
	["led2"] = 1,
	["led3"] = 1,
	["led4"] = 1,
	["led5"] = 1,
	["led6"] = 1,
	["led7"] = 1,
	["red_1"] = 1,
	["red_2"] = 1,
	["red_3"] = 1,
	["blue_1"] = 1,
	["blue_2"] = 1,
	["blue_3"] = 1,
	["white_1"] = 1,
	["white_2"] = 1,
	["white_3"] = 1,
	["shouldShift"] = 1,
	["intershaft"] = 1,
	["lightbar_r"] = 1,
	["lightbar_l"] = 1,
	["lightbar_b"] = 1,
	["lightbar_r1"] = 1,
	["lightbar_r2"] = 1,
	["flasher_special_1"] = 1,
	["flasher_special_2"] = 1,
	["flasher_special_3"] = 1,
	["flasher_special_4"] = 1,
	["flasher_special_5"] = 1,
	["flasher_special_6"] = 1,
	["flasher_special_7"] = 1,
	["flasher_special_8"] = 1,
	["flasher_special_9"] = 1,
	["flasher_special_10"] = 1,
	["flasher_special_11"] = 1,
	["flasher_special_12"] = 1,
	["doorLever"] = 1,
	["gear_M"] = 1,
	["gear_A"] = 1,
	["cruiseControlActive"] = 1,
	["beaconSpin"] = 1,
	["rr1"] = 1,
	["rr2"] = 1,
	["rr3"] = 1,
	["rr4"] = 1,
	["rl1"] = 1,
	["rl2"] = 1,
	["rl3"] = 1,
	["rl4"] = 1,
	["wl1"] = 1,
	["w1"] = 1,
	["wr1"] = 1,
	["dseColor"] = 1,
	["clockh"] = 1,
	["clockmin"] = 1,
	["isYCBrakeActive"] = 1,
	["isTCBrakeActive"] = 1,
	["throttleFactor"] = 1,
	["spoiler"] = 1,
	["disp_2"] = 1,
	["disp_3"] = 1,
	["disp_4"] = 1,
	["disp_5"] = 1,
	["disp_6"] = 1,
	["throttleTop"] = 1,
	["throttleBottom"] = 1,
	["targetRPMRatioDecreate"] = 1,
	["4ws"] = 1,
	["disp_P_cvt"] = 1,
	["disp_R_cvt"] = 1,
	["disp_N_cvt"] = 1,
	["disp_D_cvt"] = 1,
	["disp_L_cvt"] = 1,
	["disp_Pa"] = 1,
	["disp_Ra"] = 1,
	["disp_Na"] = 1,
	["disp_Da"] = 1,
	["boost_1"] = 1,
	["boost_2"] = 1,
	["boost_3"] = 1,
	["boost_4"] = 1,
	["boost_5"] = 1,
	["boost_6"] = 1,
	["boost_7"] = 1,
	["boost_8"] = 1,
	["boost_9"] = 1,
	["boost_10"] = 1,
	["boost_11"] = 1,
	["nitrousOxideActive"] = 1,
	["FL"] = 1,
	["FR"] = 1,
	["RL"] = 1,
	["RR"] = 1,
	["FFL"] = 1,
	["FFR"] = 1,
	["RRL"] = 1,
	["RRR"] = 1,
	["smoothShiftLogicAV"] = 1,
	["odometer"] = 1,
	["steeringUnassisted"] = 1,
	["boost"] = 1,
	["superchargerBoost"] = 1,
	["trip"] = 1,
	["accXSmooth"] = 1,
	["accYSmooth"] = 1,
	["accZSmooth"] = 1,
	["engineRunning"] = 1, -- engine and ignition is synced in MPPowertrainVE
	["ignition"] = 1,
	["ignitionLevel"] = 1,
	["postCrashBrakeTriggered"] = 1,
	["hPatternAxisX"] = 1,
	["hPatternAxisY"] = 1,
	--["gear"] = 1, -- me262 uses the gear electric on the landing gear, so even though we sync gears through inputs, we still need this electric
	--["gearIndex"] = 1,
	--["gearModeIndex"] = 1,
	["steering_timestamp"] = 1,
	["strut_F_axleLift"] = 1,
	["strut_R_axleLift"] = 1,
	["dseWarningPulse"] = 1,
	["regenFromBrake"] = 1,
	["regenFromOnePedal"] = 1,
	["brakelight_signal_L"] = 1,
	["brakelight_signal_R"] = 1,
	["lowhighbeam_signal_R"] = 1,
	["lowhighbeam_signal_L"] = 1,
	["reverse_wigwag_L"] = 1,
	["reverse_wigwag_R"] = 1,
	["highbeam_wigwag_L"] = 1,
	["highbeam_wigwag_R"] = 1,
	["parkingbrakelight"] = 1,
	--["jato"] = 1, -- both jato electrics are needed to sync the jato, controller sync is purely on receiving side
	--["jatoInput"] = 1,
	---modded vehicles --
	-- me262 plane ------
	["inst_pitch"] = 1,
	["inst_roll"] = 1,
	["vsi"] = 1,
	["gun1_muzzleflash"] = 1,
	["gun2_muzzleflash"] = 1,
	["gun3_muzzleflash"] = 1,
	["gun4_muzzleflash"] = 1,
	["engSoundL"] = 1,
	["engSoundR"] = 1,
	["thrustL"] = 1,
	["thrustR"] = 1,
	-- DH Super GNAT
	["heli_pitchDeg"] = 1,
	["tail_rotor"] = 1,
	["main_rotor"] = 1,
	["heli_rollDeg"] = 1,
	-- DH Hyper bolide
	["super_speed"] = 1,
	["barrelspin"] = 1,
	["super_roll"] = 1,
	["super_thruster"] = 1,
	["super_throttle"] = 1,
	-- DH Quadcopter
	["dhq_throttle_rl"] = 1,
	["dhq_throttle_rr"] = 1,
	["dhq_throttle_fr"] = 1,
	["dhq_throttle_fl"] = 1,
	["dhq_rotorfl"] = 1,
	["dhq_rotorrl"] = 1,
	["dhq_rotorfr"] = 1,
	["dhq_rotorrr"] = 1,
	["shaft_rl"] = 1,
	["shaft_rr"] = 1,
	["shaft_fr"] = 1,
	["shaft_fl"] = 1,
	["shaftgau"] = 1,
	-- Pigeon STi-G
	["RPM_led2"] = 1,
	["RPM_led3"] = 1,
	-- DH Sport Bike
	["steeringBike"] = 1,
	["steeringBike2"] = 1,
	["steeringBike3"] = 1
}

local function excludeElectric(electricName)
	if electricName then
		disallowedKeys[electricName] = 1
	end
end

local function searchObjectForElectrics(object)
	for varname,val in pairs(object) do
		if string.match(varname,"ElectricsName") or string.match(varname,"electricsName") or string.match(varname,"ElectricName") then
			excludeElectric(val)
		end
	end
end

local function checkForElectricsToExclude()
	for _,storage in pairs(energyStorage.getStorages()) do
		searchObjectForElectrics(storage)
	end
	for _,device in pairs(powertrain.getDevices()) do
		searchObjectForElectrics(device)
	end
	for _,controller in pairs(controller.getAllControllers()) do
		if controller.typeName == "pneumatics/airbrakes" then
			if electrics.values[controller.name .. "_pressure_service"] then excludeElectric(controller.name .. "_pressure_service") end
			if electrics.values[controller.name .. "_pressure_parking"] then excludeElectric(controller.name .. "_pressure_parking") end
		end
		if controller.typeName == "pneumatics/liftAxleControl" then
			if electrics.values[controller.name .. "_main_airbags_pressure_avg"] then excludeElectric(controller.name .. "_main_airbags_pressure_avg") end
			if electrics.values[controller.name .. "_lift_airbags_pressure_avg"] then excludeElectric(controller.name .. "_lift_airbags_pressure_avg") end
			if electrics.values[controller.name .. "_lift_axle_mode"] then excludeElectric(controller.name .. "_lift_axle_mode") end
		end
		if controller.typeName == "pneumatics/actuators" then
			local jbeamData = v.data[controller.name]
			if jbeamData then
				local pressureBeamData = v.data[jbeamData.pressuredBeams] or {}
				for _, pressureData in pairs(pressureBeamData) do
					if pressureData.groupName then
						excludeElectric(controller.name .. "_" .. pressureData.groupName .. "_valveState")
						excludeElectric(controller.name .. "_" .. pressureData.groupName .. "_pressure_avg")
					end
				end
			end
		end
		if controller.typeName == "advancedCouplerControl" then
			if electrics.values[controller.name .. "_notAttached"] then excludeElectric(controller.name .. "_notAttached") end
		end
		if controller.typeName == "tirePressureControl" then
			excludeElectric(controller.name .. "_activeGroupPressure")
		end
	end
	for name,val in pairs(electrics.values) do
		if string.match(name,"_filament") then
			excludeElectric(name)
		end
	end
	for _, wheelData in pairs(wheels.wheels) do
		if wheelData.brakeGlowElectricsName then
			excludeElectric(wheelData.brakeGlowElectricsName)
		end
	end
end

local function round2(num, numDecimalPlaces)
  return math.floor((num*(10^numDecimalPlaces)+0.5))/(10^numDecimalPlaces)
end

local function check()
	local e = electrics.values
	if not e then return end -- Error avoidance in console
	electricsChanged = false
	table.clear(electricsToSend)

	for name,val in pairs(e) do -- check for new electrics
		if lastElectrics[name] == nil then
			if not disallowedKeys[name] then
				if string.match(name,"_filament") then
					excludeElectric(name)
				else
					if type(val) == "number" then
						if name == "fuelVolume" then
							val = round2(val,1)
						else
							val = round2(val,4)
						end
					end
					checkElectrics[name] = val
					electricsToSend[name] = val
					electricsChanged = true
				end
			end
			lastElectrics[name] = val
		end
	end

	for name,val in pairs(checkElectrics) do
		local newVal = e[name]
		if newVal == nil then
			electricsToSend[name] = "isnil"
			checkElectrics[name] = nil
			lastElectrics[name] = nil
			electricsChanged = true
			goto skip_electric
		end
		if type(newVal) == "number" then
			if name == "fuelVolume" then
				newVal = round2(newVal,1)
			else
				newVal = round2(newVal,4)
			end
		end
		if newVal ~= val then
			electricsToSend[name] = newVal
			checkElectrics[name] = newVal
			electricsChanged = true
		end
		:: skip_electric ::
	end
	if electricsChanged then
		obj:queueGameEngineLua("MPElectricsGE.sendElectrics(\'"..jsonEncode(electricsToSend).."\', "..obj:getID()..")")
	end
end

local lastLeftSignal = 0
local lastRightSignal = 0
local function applyElectrics(data)
	local decodedData = jsonDecode(data) -- Decode received data
	if (decodedData) then -- If received data is correct
		if decodedData.signal_left_input or decodedData.signal_right_input then
			electrics.set_warn_signal(0) -- set all signals to 0 so we know the states
			lastLeftSignal = decodedData.signal_left_input or lastLeftSignal
			lastRightSignal = decodedData.signal_right_input or lastRightSignal
			if lastLeftSignal == 1 and lastRightSignal == 1 then
				electrics.set_warn_signal(1)
			elseif lastLeftSignal == 1 then
				electrics.toggle_left_signal()
			elseif lastRightSignal == 1 then
				electrics.toggle_right_signal()
			end
		end
		if decodedData.lights_state then
			electrics.setLightsState(decodedData.lights_state) -- Apply lights values
		end
		if decodedData.lightbar then
			electrics.set_lightbar_signal(decodedData.lightbar) -- Apply lightbar values
		end
		if decodedData.horn then
			if decodedData.horn == 1 then electrics.horn(true)
			else electrics.horn(false) end
		end
		if decodedData.fog then
			electrics.set_fog_lights(decodedData.fog)
		end

		-- Fuel Level syncing
		if decodedData.fuelVolume then
			for name, storage in pairs(energyStorage.getStorages()) do
				if string.match(name, "mainTank") then -- This might not work with boats, aircraft or others but should work with stock vehicles.
					storage:setRemainingVolume(decodedData.fuelVolume)
				end
			end
		end

		-- Transbrake syncing
		if decodedData.transbrake ~= nil and electrics.values.transbrake ~= decodedData.transbrake then
			controller.getControllerSafe("transbrake").setTransbrake(decodedData.transbrake)
		end

		-- LineLock syncing
		if decodedData.linelock and electrics.values.linelock ~= decodedData.linelock then
			controller.getControllerSafe("lineLock").setLineLock(decodedData.linelock)
		end

		-- ABS Behavior syncing
		if decodedData.absMode and wheels then
			wheels.setABSBehavior(decodedData.absMode)
		end

		if decodedData.mainEngine_compressionBrake_setting then
			controller.getControllerSafe('compressionBrake').setCompressionBrakeCoef(decodedData.mainEngine_compressionBrake_setting)
		end

		-- DH Super bolide
		if decodedData.swingwing and supertact then
			if decodedData.swingwing ~= localSwingwing then
				supertact.toggleFlightMode()
				localSwingwing = decodedData.swingwing
			end
		end

		-- Anything else
		for k,v in pairs(decodedData) do
			if v == "isnil" then
				electrics.values[k] = nil
			else
				electrics.values[k] = v
			end
		end

		latestData = data
	end
end



local function onReset()
	if v.mpVehicleType == 'L' then
		electrics.values.absMode = settings.getValue("absBehavior", "realistic")
	end
	if v.mpVehicleType == "R" then
		if wheels then wheels.setABSBehavior(electrics.values.absMode or "realistic") end
		localSwingwing = 0
	end
end

local function onExtensionLoaded()
	checkForElectricsToExclude()
	onReset()
end

local function applyLatestElectrics()
	applyElectrics(latestData)
end



M.onExtensionLoaded    = onExtensionLoaded
M.onReset			   = onReset
M.check				   = check
M.applyElectrics	   = applyElectrics
M.applyLatestElectrics = applyLatestElectrics
M.excludeElectric	   = excludeElectric


return M
