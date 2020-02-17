--====================================================================================
-- All work by Jojos38 & Titch2000.
-- You have no permission to edit, redistrobute or upload. Contact us for more info!
--====================================================================================



local M = {}



-- ============= VARIABLES =============
local slMem = -1
local srMem = -1
local hzMem = -1
local lsMem = -1
local lbMem = -1
local hrMem = -9
local gearMem = -1
local sendNow = false -- When set to true, it send the electrics value at next update
local sendGearNow = false
local latestData
-- ============= VARIABLES =============

-- TODO : Change "allowed" thing and use if player own vehicle don't send any data instead

local function onUpdate(dt) --ONUPDATE OPEN
	local e = electrics.values
	if sendNow == true or e.signal_left_input ~= slMem or e.signal_right_input ~= srMem or e.hazard_enabled ~= hzMem or e.lights_state ~= lsMem or e.lightbar ~= lbMem or e.horn ~= hrMem then
		local eTable = {}	
		eTable[1] = e.signal_left_input   -- Left signal input
		eTable[2] = e.signal_right_input  -- Right signal input
		eTable[3] = e.hazard_enabled      -- Hazard light input
		eTable[4] = e.lights_state        -- Lights input
		eTable[5] = e.lightbar            -- Lightbar input
		eTable[6] = e.horn	              -- Horn input
		obj:queueGameEngineLua("electricsGE.sendElectrics(\'"..jsonEncode(eTable).."\', \'"..obj:getID().."\')") -- Send it to GE lua
		sendNow = false

	end
	slMem = e.signal_left_input
	srMem = e.signal_right_input
	hzMem = e.hazard_enabled
	lsMem = e.lights_state
	lbMem = e.lightbar
	hrMem = e.horn
	
	if sendGearNow == true or e.gearIndex ~= gearMem then
		obj:queueGameEngineLua("electricsGE.sendGear(\'"..e.gearIndex.."\', \'"..obj:getID().."\')") -- Send it to GE lua
		sendGearNow = false
	end
	gearMem = e.gearIndex
	
end --ONUPDATE CLOSE



local function applyGear(data)
	if (data) then controller.mainController.shiftToGearIndex(tonumber(data)) end
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
		local e = electrics.values	
		if (decodedData) then -- If received data is correct
		if decodedData[3] ~= e.hazard_enabled then -- Apply hazard lights
			electrics.set_warn_signal(decodedData[3])
			electrics.update(0) -- Update electrics values
		end		
		if e.signal_left_input  ~= decodedData[1] then -- Apply left signal value
			electrics.toggle_left_signal() 
			electrics.update(0) -- Update electrics values
		end
		if e.signal_right_input ~= decodedData[2] then -- Apply right signal value
			electrics.toggle_right_signal()
		end		
		electrics.setLightsState(decodedData[4]) -- Apply lights values
		electrics.set_lightbar_signal(decodedData[5]) -- Apply lightbar values		
		-- Apply horn value
		if decodedData[6] == 1 and e.horn == 0 then
			electrics.horn(true)
		elseif decodedData[6] == 0 and e.horn == 1 then
			electrics.horn(false)
		end		
		latestData = data
	end
end



local function applyLatestElectrics()
	applyElectrics(latestData)
end



M.applyGear			   = applyGear
M.getGear			   = getGear
M.getElectrics         = getElectrics
M.applyElectrics	   = applyElectrics
M.applyLatestElectrics = applyLatestElectrics
M.updateGFX	    	   = onUpdate



return M