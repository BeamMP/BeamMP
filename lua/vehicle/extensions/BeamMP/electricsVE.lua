--====================================================================================
-- All work by Jojos38 & Titch2000.
-- You have no permission to edit, redistrobute or upload. Contact us for more info!
--====================================================================================



local M = {}



-- ============= VARIABLES =============
local le = {}
local slMem = -1
local srMem = -1
local hzMem = -1
local lsMem = -1
local lbMem = -1
local hrMem = -9
local exMem = -1
local tiMem = -1
local taMem = -1
local gearMem = -1
local sendNow = false -- When set to true, it send the electrics value at next update
local sendGearNow = false
local latestData
local eTable = {} -- This holds the data that is different from the last frame to be sent since it is different
local eChanged = false
-- ============= VARIABLES =============

local function DisallowedKey(k)
	local allow = false
	local keys = {
		"wheelThermals",
		"airflowspeed",
		"airspeed",
		"altitude",
		"avgWheelAV",
		"clutch_input",
		"driveshaft",
		"driveshaft_F",
		"engineLoad",
		"exhaustFlow",
		"fuel",
		"fuelVolume",
		"oiltemp",
		"rpm",
		"rpmTacho",
		"rpmspin",
		"virtualAirspeed",
		"watertemp",
		"wheelspeed",
		"turnsignal",
		"hazard",
		"signal_R",
		"signal_L",
		"radiatorFanSpin",
		"turboBoost",
		"turboSpin",
		"turboRPM",
		"turboRpmRatio",
		--"tilt",
		"engineThrottle",
		"throttle",
		"brake_input",
		"brake",
		"brakelights",
		"clutch",
		"clutchRatio",
		"steering",
		"steering_input",
		"throttle_input",
		"abs",
		"lights",
		"wheelaxleFR",
		"wheelaxleFL",
		"wheelaxleRR",
		"wheelaxleRL",
		"axle_FR",
		"axle_FL",
		"axle_RR",
		"axle_RL",
		"throttleFactorRear",
		"throttleFactorFront",
		"esc",
		"tcs",
		"escActive",
		"absActive",
		"disp_N",
		"regenThrottle",
		"disp_1",
		"tcsActive",
		"clutchRatio1",
		"lockupClutchRatio",
		"throttleOverride",
		"cruiseControlTarget",
	}
	for i=1,#keys do
		if k == keys[i] then
			allow = true
		end
	end
	return allow
end

-- TODO : Change "allowed" thing and use if player own vehicle don't send any data instead

local function onUpdate(dt) --ONUPDATE OPEN
	--[[local e = electrics.values
	if sendNow == true or e.signal_left_input ~= slMem or e.signal_right_input ~= srMem or e.hazard_enabled ~= hzMem or e.lights_state ~= lsMem or e.lightbar ~= lbMem or e.horn ~= hrMem or e.extend ~= exMem or e.tilt ~= tiMem or e.tailgate ~= taMem then
		local eTable = {}
		eTable[1] = e.signal_left_input   -- Left signal input
		eTable[2] = e.signal_right_input  -- Right signal input
		eTable[3] = e.hazard_enabled      -- Hazard light input
		eTable[4] = e.lights_state        -- Lights input
		eTable[5] = e.lightbar            -- Lightbar input
		eTable[6] = e.horn	              -- Horn input
		eTable[7] = e.extend              -- Flatbed extend value
		eTable[8] = e.tilt                -- Flatbed tilt value
		eTable[9] = e.tailgate            -- Tailgate value
		obj:queueGameEngineLua("electricsGE.sendElectrics(\'"..jsonEncode(eTable).."\', \'"..obj:getID().."\')") -- Send it to GE lua
		sendNow = false

	end
	slMem = e.signal_left_input
	srMem = e.signal_right_input
	hzMem = e.hazard_enabled
	lsMem = e.lights_state
	lbMem = e.lightbar
	hrMem = e.horn
	exMem = e.extend
	tiMem = e.tilt
	taMem = e.tailgate]]
	local e = electrics.values
	for k,v in pairs(e) do
		if le[k] == nil then
			le[k] = v
		end

		if not DisallowedKey(k) and le[k] ~= v then
			--print("Change Detected: "..tostring(k)..": "..tostring(le[k]).." -> "..tostring(v))
			eTable[k] = v
			le[k] = v
			eChanged = true
		end
	end

	if sendNow == true and eChanged == true then
		sendNow = false
		eChanged = false
		--print("[electricsVE] Sending: ")
		--dump(eTable)
		obj:queueGameEngineLua("electricsGE.sendElectrics(\'"..jsonEncode(eTable).."\', \'"..obj:getID().."\')") -- Send it to GE lua
		eTable = {}
	end

	if sendGearNow == true and e.gear ~= gearMem then
		obj:queueGameEngineLua("electricsGE.sendGear(\'"..e.gear.."\', \'"..obj:getID().."\')") -- Send it to GE lua
		sendGearNow = false
		gearMem = e.gear
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



local function getElectrics()
	sendNow = true
end



local function getGear()
	sendGearNow = true
end



local function applyElectrics(data)
	-- 1 = signal_left_input
	-- 2 = signal_right_input
	-- 3 = hazard_enabled
	-- 4 = lights_state
	-- 5 = lightbar
	-- 6 = horn
	local decodedData = jsonDecode(data) -- Decode received data
	--local e = electrics.values
	if (decodedData) then -- If received data is correct
		--[[if decodedData[3] ~= e.hazard_enabled and decodedData[3] ~= nil then -- Apply hazard lights
			electrics.set_warn_signal(decodedData[3])
			electrics.update(0) -- Update electrics values
		end
		if e.signal_left_input  ~= decodedData[1] and decodedData[1] ~= nil then -- Apply left signal value
			electrics.toggle_left_signal()
			electrics.update(0) -- Update electrics values
		end
		if e.signal_right_input ~= decodedData[2] and decodedData[2] ~= nil then -- Apply right signal value
			electrics.toggle_right_signal()
		end

		if e.extend ~= decodedData[7] and decodedData[7] ~= nil then
			electrics.values.extend = decodedData[7]
		end
		if e.tilt ~= decodedData[8] and decodedData[8] ~= nil then
			electrics.values.tilt = decodedData[8]
		end
		if e.feet ~= decodedData[10] and decodedData[10] ~= nil then
			print("Setting Tailgate to: "..decodedData[10].." from "..electrics.values.tailgate)
			electrics.values.tailgate = decodedData[10]
		end
		if e.tailgate ~= decodedData[9] and decodedData[9] ~= nil then
			print("Setting Tailgate to: "..decodedData[9].." from "..electrics.values.tailgate)
			electrics.values.tailgate = decodedData[9]
		end
		if e.lights_state ~= decodedData[4] and decodedData[4] ~= nil then
			electrics.setLightsState(decodedData[4]) -- Apply lights values
		end
		if e.lightbar ~= decodedData[5] and decodedData[5] ~= nil then
			electrics.set_lightbar_signal(decodedData[5]) -- Apply lightbar values
		end

		-- Apply horn value
		if decodedData[6] == 1 and e.horn == 0 then
			electrics.horn(true)
		elseif decodedData[6] == 0 and e.horn == 1 then
			electrics.horn(false)
		end]]

		for k,v in pairs(decodedData) do
			--print("Setting: "..k.." -> "..tostring(v))

			electrics.values[k] = v

			if k == "hazard_enabled" then
				--electrics.values.hazard = 0
				electrics.set_warn_signal(v)
				--electrics.update(0) -- Update electrics values
			elseif k == "signal_left_input" then
				electrics.toggle_left_signal()
				--electrics.update(0) -- Update electrics values
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



M.applyGear			       = applyGear
M.getGear			         = getGear
M.getElectrics         = getElectrics
M.applyElectrics	     = applyElectrics
M.applyLatestElectrics = applyLatestElectrics
M.updateGFX	    	     = onUpdate



return M
