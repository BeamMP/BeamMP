--====================================================================================
-- All work by Jojos38, Titch2000, 20dka.
-- You have no permission to edit, redistrobute or upload. Contact BeamMP for more info!
--====================================================================================
-- Electrics (and features derived from it) sync related functions
--====================================================================================

local M = {}



-- ============= VARIABLES =============
local lastElectrics = {}
local latestData
local electricsChanged = false
local absBehavior = settings.getValue("absBehavior") or "realistic"
local localSwingwing = 0 -- for DH Super bolide
local lastgear = 0 -- backwards compatibility
local geartimer = 0 -- backwards compatibility
local GearData = 0 -- backwards compatibility
-- ============= VARIABLES =============



local function getEsc()
	local driveModesController = controller.getController('driveModes')
	local escController = controller.getController('esc')
	if driveModesController ~= nil then
		return driveModesController.serialize().activeDriveModeKey
	elseif escController ~= nil then
		return escController.serialize().escConfigKey
	end
end

local function setEsc(key)
	local driveModesController = controller.getController('driveModes')
	local escController = controller.getController('esc')
	if driveModesController ~= nil then
		driveModesController.setDriveMode(key)
	elseif escController ~= nil then
		escController.setESCMode(key)
	end
end

local function getAbsBehavior()
	return absBehavior
end

local function setAbsBehavior(absMode)
	if wheels then
		wheels.setABSBehavior(absMode)
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
	electrics.values.absMode = getAbsBehavior()
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
local lastHazards = 0
local remoteignition = true
local remoteengineRunning = 1
local function applyElectrics(data)
	local decodedData = jsonDecode(data) -- Decode received data
	if (decodedData) then -- If received data is correct
		if not decodedData.signal_left_input then decodedData.signal_left_input = lastLeftSignal end
		if not decodedData.signal_right_input then decodedData.signal_right_input = lastRightSignal end
		if not decodedData.hazard_enabled then decodedData.hazard_enabled = lastHazards end

		lastLeftSignal = decodedData.signal_left_input
		lastRightSignal = decodedData.signal_right_input
		lastHazards = decodedData.hazard_enabled

		if decodedData.hazard_enabled == 1 then -- Apply hazard lights
			electrics.set_warn_signal(decodedData.hazard_enabled)
			--electrics.update(0) -- Update electrics values -- broke sync in 0.25, works fine without it
		end
		if decodedData.hazard_enabled == 0 then -- Apply left signal value
			if electrics.values.signal_left_input ~= decodedData.signal_left_input then
				electrics.toggle_left_signal()
			elseif electrics.values.signal_right_input ~= decodedData.signal_right_input then
				electrics.toggle_right_signal()
			end
			--electrics.update(0) -- Update electrics values -- broke sync in 0.25, works fine without it
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

		-- Fuel Level syncing
		if decodedData.fuelVolume then
			for name, storage in pairs(energyStorage.getStorages()) do
				if string.match(name, "mainTank") then -- This might not work with boats, aircraft or others but should work with stock vehicles.
					storage:setRemainingVolume(decodedData.fuelVolume)
				end
			end
		end

		-- Transbrake syncing
		if decodedData.transbrake and controller.getController("transbrake") then
			if electrics.values.transbrake ~= decodedData.transbrake then
				controller.getController("transbrake").setTransbrake(decodedData.transbrake)
			end
		end

		-- LineLock syncing
		if decodedData.linelock and controller.getController("lineLock") then
			if electrics.values.linelock ~= decodedData.linelock then
				controller.getController("lineLock").setLineLock(decodedData.linelock)
			end
		end

		-- Ignition syncing
		if decodedData.ignition ~= nil then
			remoteignition = decodedData.ignition
		end
		if decodedData.engineRunning then
			remoteengineRunning = decodedData.engineRunning
		end
		if electrics.values.ignition ~= (remoteignition and 1 or 0) or electrics.values.engineRunning ~= remoteengineRunning then
			local engine = powertrain.getDevice("mainEngine")
			if engine then
				if remoteengineRunning ~= electrics.values.engineRunning then
					if remoteengineRunning == 1 then
						if engine.starterEngagedCoef == 0 then
							engine:activateStarter()
						end
					elseif remoteengineRunning == 0 and engine.starterEngagedCoef == 0 then
						engine:deactivateStarter()
						engine:cutIgnition(1)
					end
				end
				if electrics.values.ignition ~= (remoteignition and 1 or 0) then
					controller.mainController.setEngineIgnition(remoteignition)
				end
				if not remoteignition and remoteengineRunning == 0 then
					engine:deactivateStarter()
				end
			end
		end
		
		-- Gear syncing backwards compatibility
		if decodedData.gear then
			GearData = decodedData.gear
		end
		
		geartimer = geartimer + 1
		
		if GearData and GearData ~= lastgear or GearData and geartimer == 2 then
			MPInputsVE.applyGearOld(GearData)
			geartimer = 0
			lastgear = GearData
		end

		-- Unicycle syncing
		local playerController = controller.getController('playerController')
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
		if decodedData.dooropen ~= nil then
			local doorsController = controller.getControllerSafe('doors')
			if doorsController then
				if decodedData.dooropen == 1 then
					doorsController.setBeamMin({'frontDoors', 'rearDoors'}) -- open doors
				else
					doorsController.setBeamMax({'frontDoors', 'rearDoors'}) -- close doors
				end
			end
		end
		-- Bus suspension height syncing
		if decodedData.kneel == 1 then
			local airbagsController = controller.getController('airbags')
			if airbagsController then
				airbagsController.setBeamPressureLevel({'rightAxle'}, 'kneelPressure') -- sets bus to kneel height
			end
		elseif decodedData.rideheight == 1 then
			local airbagsController = controller.getController('airbags')
			if airbagsController then
				airbagsController.setBeamPressureLevel({'rightAxle'}, 'maxPressure') -- sets bus to max height
			end
		elseif decodedData.rideheight == 0 then
			local airbagsController = controller.getController('airbags')
			if airbagsController then
				airbagsController.setBeamDefault({'rightAxle', 'leftAxle'})	-- sets bus to default height
			end
		end
		-- ESC Mode syncing
		if decodedData.escMode then
			setEsc(decodedData.escMode)
		end
		-- ABS Behavior syncing
		if decodedData.absMode then
			setAbsBehavior(decodedData.absMode)
		end
		-- ME262 missile sync
		if decodedData.missile4_motor == 1 or decodedData.missile3_motor == 1 or decodedData.missile2_motor == 1 or decodedData.missile1_motor == 1 then
			if controller.getController('missiles') ~= nil then
				controller.mainController.deployWeaponDown()
				controller.mainController.deployWeaponUp()
			end
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
	if v.mpVehicleType == "R" then
		controller.mainController.setGearboxMode("realistic")
		localSwingwing = 0
		remoteignition = true
		remoteengineRunning = 1
	end
end



local function onExtensionLoaded()
	if v.mpVehicleType == "R" then
		controller.mainController.setGearboxMode("realistic")
	end
end



local function applyLatestElectrics()
	applyElectrics(latestData)
end



M.onExtensionLoaded    = onExtensionLoaded
M.onReset			   = onReset
M.check				   = check
M.applyElectrics	   = applyElectrics
M.applyLatestElectrics = applyLatestElectrics
M.applyGearOld  	   = applyGearOld -- backwards compatibility



return M
