--====================================================================================
-- All work by jojos38, Titch2000, Preston (Cobalt)
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}



-- ============= VARIABLES =============
local lastInputs = {}
local timeSinceLastApply = 0
local applyTime --when a new apply occurs, this mirrors timeSinceLastApply and is used to interpolate.
local currentApply = {}
local lastApply = nil
local steering = 0
local setSteeringSlope
local steeringSlope --I know slopes are kind of archiac, but it really is to just smooth steering back out.
local appliedBefore = false --because v.mpVehicleType isn't working
local steeringCorrectionThreshold = 0.1
local steeringStart = 0

local latestGearData
local localGearMode
local localCurrentGear = 0
local geartimer = 0
local lastgear
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
	latestGearData = data
	if not electrics.values.gearIndex or electrics.values.gear == data then return end
	-- Detect the type of gearbox, frontMotor and rearMotor are for electrics car
	local gearboxType = (powertrain.getDevice("gearbox") or powertrain.getDevice("frontMotor") or powertrain.getDevice("rearMotor") or "none").type
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

local function applyGearOld(data) -- backwards compatibility
	if not currentApply.g then
		applyGear(data)
	end
	
end

local function updateGFX(dt)
	timeSinceLastApply = timeSinceLastApply + dt

	--if appliedBefore then --v.mpVehicleType is acting up, so I had to use this workaround
	if lastApply then

		--all of this to make the steering wheel smooth, I understand that the steering is now techically going to be delayed, but I think this will make watching another car in first person actually managable.
		if steeringSlope then
		
			--DEBUG
			--if playerInfo.firstPlayerSeated then
				--print("----------------------")
				--print("   SLOPE:" .. steeringSlope)
				--print("STEERING:" .. steering)
				--print("   START:" .. steeringStart)
				--print("    LAST:" .. lastApply.s)
				--print("  TARGET:" .. currentApply.s)
				--print("----------------------")
			--end

			steering = (steeringSlope * timeSinceLastApply) + steering
			--print(steeringSlope)

			steeringSlope = setSteeringSlope * (math.abs(steering - currentApply.s)/math.abs(steeringStart - currentApply.s))

			if steeringStart > currentApply.s then --steering drops
				if steering <= currentApply.s then
					--steering = currentApply.s
					steeringSlope = 0
				end
			elseif steeringStart < currentApply.s then --steering rises
				if steering >= currentApply.s then
					--steering = currentApply.s
					steeringSlope = 0
				end
			elseif steering == currentApply.s then --steering is j chillin
				steeringSlope = 0
			end
			
			--error checking
			if steering < -1 then
				steering = -1
			elseif steering > 1 then
				steering = 1
			end
		end
		
		--we set the electrics values directly because it results in instantanious changes & disallows someone from "ghost controlling a car" where they get the illusion they have influence over someone else's vehicle
		--electrics.values.steering_input = steering

		--electrics.values.throttleOverride = lastApply.t
		--electrics.values.brake = lastApply.b
		--electrics.values.parkingbrake = lastApply.p
		--electrics.values.clutch_input = lastApply.c
		input.event("steering", steering, 2)			-- reverted back to using input.event because setting through electrics has some of the following issues 
		input.event("throttle", currentApply.t, 2)		-- 4 wheel steering doesn't sync when setting through electrics
		input.event("brake", currentApply.b, 2)			-- brake lights wouldn't activate on some cars
		input.event("parkingbrake", currentApply.p, 2)	-- setting the clutch through electrics doesn't work at all
		input.event("clutch", currentApply.c, 2)		-- changed filters to something more responsive resulting in a better synced experience
		--lastSteering = steering						-- reverted to using currentApply because lastApply currently has issues with inputs getting stuck when no input is present

		--gears
		geartimer = geartimer + 1
		
		if currentApply.g and currentApply.g ~= lastgear or currentApply.g and geartimer == 2 then
			applyGear(currentApply.g)
			geartimer = 0
		end
		
		lastgear = currentApply.g
	end
end

local function getInputs()
	-- Get inputs values
	local inputsTable = {
		s = electrics.values.steering_input,
		t = electrics.values.throttle,
		b = electrics.values.brake,
		p = electrics.values.parkingbrake,
		c = electrics.values.clutch,
		g = electrics.values.gear
	}

	-- If inputs didn't change then return
	if inputsTable.s == lastInputs.s
	and inputsTable.t == lastInputs.t
	and inputsTable.b == lastInputs.b
	and inputsTable.p == lastInputs.p
	and inputsTable.c == lastInputs.c
	and inputsTable.g == lastInputs.g
	then return end

	obj:queueGameEngineLua("MPInputsGE.sendInputs(\'"..jsonEncode(inputsTable).."\', "..obj:getID()..")") -- Send it to GE lua

	lastInputs = inputsTable
end


local function applyInputs(data)
	local decodedData = jsonDecode(data) -- Decode received data
	if decodedData.s and decodedData.t and decodedData.b and decodedData.p and decodedData.c then
		--input.event("steering", decodedData.s, 3)
		--steeringStart = input.steering or 0

		--input.event("throttle", decodedData.t, 3)
		--input.event("brake", decodedData.b, 3)
		--input.event("parkingbrake", decodedData.p, 3)
		--input.event("clutch", decodedData.c, 3)

		--update lastApply with currentApply before it's updated
		lastApply = {
			s = currentApply.s or decodedData.s,
			t = currentApply.t or decodedData.t,
			b = currentApply.b or decodedData.b,
			p = currentApply.p or decodedData.p,
			c = currentApply.c or decodedData.c,
			g = currentApply.g or decodedData.g
		}
		
		--update currentApply
		currentApply = {
			s = decodedData.s,
			t = decodedData.t,
			b = decodedData.b,
			p = decodedData.p,
			c = decodedData.c,
			g = decodedData.g
		}

		--update variables
		if appliedBefore == true then

			if timeSinceLastApply > 0 then
				applyTime = timeSinceLastApply
				timeSinceLastApply = 0
			end


				steeringStart = steering
				steeringSlope = ((currentApply.s + 1) - (steering + 1)) / applyTime 
				setSteeringSlope = steeringSlope
		else --first apply
			applyTime = 0.2
			timeSinceLastApply = 0
			steering = lastApply.s
			appliedBefore = true --turn this on so that updateGFX runs
		end
	end
end


M.updateGFX = updateGFX
M.getInputs   = getInputs
M.applyInputs = applyInputs
M.applyGearOld  = applyGearOld -- backwards compatibility



return M
