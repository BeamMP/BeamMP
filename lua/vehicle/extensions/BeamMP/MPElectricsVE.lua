-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}



-- ============= VARIABLES =============
local lastElectrics = {}
local latestData
local electricsChanged = false
local localSwingwing = 0 -- for DH Super bolide
-- ============= VARIABLES =============



local function getEsc()
	if controller.getController('driveModes') then
		return controller.getController('driveModes').serialize().activeDriveModeKey
	elseif controller.getController('esc') then
		return controller.getController('esc').serialize().escConfigKey
	end
end

local function setEsc(key)
	if controller.getController('driveModes') then
		controller.getController('driveModes').setDriveMode(key)
	elseif controller.getController('esc') then
		controller.getController('esc').setESCMode(key)
	end
end


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

local function round2(num, numDecimalPlaces)
  return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
end

local function check()
	local electricsToSend = {} -- This holds the data that is different from the last frame to be sent since it is different
	local electricsChanged = false
	electrics.values.escMode = getEsc()
	local e = electrics.values
	if not e then return end -- Error avoidance in console
	for k,v in pairs(e) do -- For each electric value
		if not disallowedKeys[k] then -- If it's not a disallowed key
			if k == "fuelVolume" then
				if lastElectrics[k] ~= round2(v, 1) then -- If the value changed
					electricsChanged = true -- Send electrics
					lastElectrics[k] = round2(v, 1) -- Define the new value
					electricsToSend[k] = round2(v, 1)
				end
			else
				if lastElectrics[k] ~= v then -- If the value changed
					electricsChanged = true -- Send electrics
					lastElectrics[k] = v -- Define the new value
					electricsToSend[k] = v
				end
			end
		end
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
		if decodedData.transbrake and electrics.values.transbrake ~= decodedData.transbrake then
			controller.getControllerSafe("transbrake").setTransbrake(decodedData.transbrake)
		end

		-- LineLock syncing
		if decodedData.linelock and electrics.values.linelock ~= decodedData.linelock then
			controller.getControllerSafe("lineLock").setLineLock(decodedData.linelock)
		end

		if not controllerSyncVE.isOnControllerSync then
			-- Unicycle syncing -- for cross compatibility with non controller sync versions of beammp,
			-- can be removed once controller sync is fully released
			local playerController = controllerSyncVE.OGcontrollerFunctionsTable['playerController']
			if playerController then
				-- direction
				if decodedData.unicycle_camera ~= nil then
					playerController.setCameraControlData({cameraRotation = quatFromEuler(0, 0, -decodedData.unicycle_camera)})
				end
				-- walking left/right
				if decodedData.unicycle_walk_x ~= nil then
					playerController.walkLeftRightRaw(decodedData.unicycle_walk_x)
				end
				-- walking forward/backward
				if decodedData.unicycle_walk_y ~= nil then
					playerController.walkUpDownRaw(decodedData.unicycle_walk_y)
				end
				-- jump, check if boolean because there are sometimes 0s in the received values
				if decodedData.unicycle_jump == true then
					playerController.jump(1)
				end
				-- crouch
				if decodedData.unicycle_crouch ~= nil then
					playerController.crouch(decodedData.unicycle_crouch)
				end
				-- sprint
				if decodedData.unicycle_speed ~= nil then
					playerController.setSpeedCoef(decodedData.unicycle_speed)
				end
			end
			-- Bus door syncing
			if decodedData.dooropen then
				local doorController = controllerSyncVE.OGcontrollerFunctionsTable['doors']
				if doorController then
					if decodedData.dooropen == 1 then
						doorController.setBeamMin({'frontDoors', 'rearDoors'}) -- open doors
					else
						doorController.setBeamMax({'frontDoors', 'rearDoors'}) -- close doors
					end
				end
			end
			-- Bus suspension height syncing
			local airbagsController = controllerSyncVE.OGcontrollerFunctionsTable['airbags']
			if airbagsController then
				if decodedData.kneel == 1 then
					airbagsController.setBeamPressureLevel({'rightAxle'}, 'kneelPressure') -- sets bus to kneel height
				elseif decodedData.rideheight == 1 then
					airbagsController.setBeamPressureLevel({'rightAxle'}, 'maxPressure') -- sets bus to max height
				elseif decodedData.rideheight == 0 then
					airbagsController.setBeamDefault({'rightAxle', 'leftAxle'})	-- sets bus to default height
				end
			end
			
			-- ME262 missile sync
			local missilesController = controllerSyncVE.OGcontrollerFunctionsTable['missiles']
			if missilesController then
				local missleID = 0
				for i=1,11 do -- Phulcan has 11 missiles
					if decodedData["missile"..i.."_motor"] == 1 then
						missilesController.deployWeaponDown(i,false)
						missilesController.deployWeaponUp()
					end
				end
			end
		end

		-- ESC Mode syncing
		if decodedData.escMode then
			setEsc(decodedData.escMode)
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
			electrics.values[k] = v
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



local function applyLatestElectrics()
	applyElectrics(latestData)
end



M.onExtensionLoaded    = onReset
M.onReset			   = onReset
M.check				   = check
M.applyElectrics	   = applyElectrics
M.applyLatestElectrics = applyLatestElectrics


return M
