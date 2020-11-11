--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}



-- ============= VARIABLES =============
local sendNow = false -- When set to true, it send the electrics value at next update
local allowed  = true -- Allow or not the user to send electrics value at next update
local getElectricsDelay = 0
local latestData

local expectedGear = 0
local gearType = ""

local gearTranslationTable = {
	["R"] = -1,
	["N"] = 0,
	["P"] = 1,
	["D"] = 2,
	["M"] = 6,
	["1"] = 5,
	["2"] = 4,
	["S"] = 3,
}

-- ============= VARIABLES =============

local function sendAllPowertrain()
	local tableToSend = {} -- Create table with gameVehicleID
	local devices = powertrain.getDevices() -- Get all devices
	for k,v in pairs(devices) do -- For each device
		local name = k -- Get name
		local mode = v.mode -- Get mode
		if mode then -- If mode is not null
			tableToSend[name] = mode -- Add device to the table
		end
  end
	obj:queueGameEngineLua("powertrainGE.sendPowertrain(\'"..jsonEncode(tableToSend).."\', \'"..obj:getID().."\')")
end

local function sendPowertrain(name, mode)
	local tableToSend = {}  -- Create table with gameVehicleID
	tableToSend[name] = mode -- Add device to the table
	obj:queueGameEngineLua("powertrainGE.sendPowertrain(\'"..jsonEncode(tableToSend).."\', \'"..obj:getID().."\')")
end

local function applyPowertrain(data)
	print("Initial data for powertrain received")
	drivetrain.setShifterMode(2)
	local decodedData = jsonDecode(data) -- Decode data
	for k, v in pairs(decodedData) do -- For each device
		print("applied "..k.." - "..tostring(v))
		powertrain.setDeviceMode(k, v) -- Apply it
	end
end

local function applyLivePowertrain(data)
	-- shifterMode = 0 : realistic (manual)
	-- shifterMode = 1 : realistic (manual autoclutch)
	-- shifterMode = 2 : arcade
	-- shifterMode = 3 : realistic (automatic)
	--drivetrain.setShifterMode(2)
	controller.mainController.setGearboxMode("realistic")
	--print("Applying Data")
	local decodedData = jsonDecode(data) -- Decode data
	--dump(decodedData)
	local devices = powertrain.getDevices()
	for k, v in pairs(decodedData) do -- For each device
		for key,value in pairs(v) do
			if key == "mode" then
				--print(k .. " -> " .. value)
				devices[k].setMode(devices[k], value)
			end
		end
		if k == "gearbox" then
			--print(devices[k].type)
			--print("Gearbox Data: "..tostring(k))
			--print("applied "..k.." - "..tostring(v))
			for key,value in pairs(v) do
				if (devices[k].type == "manualGearbox" or devices[k].type == "sequentialGearbox") and key == "gearIndex" then
					--print("Shifting to Gear "..value)
					controller.mainController.shiftToGearIndex(tonumber(value))
					gearType = "manual"
					expectedGear = value
				elseif (devices[k].type == "dctGearbox" or devices[k].type == "automaticGearbox") and key == "gearIndex" then
					--print("Shifting to Gear "..value)
					controller.mainController.shiftToGearIndex(tonumber(value))
					gearType = "auto"
					expectedGear = value
				else
					if key == "gearIndex" and (devices[k].type == "manualGearbox" or devices[k].type == "automaticGearbox") then
						--print(k .. " -> " .. value)
						controller.mainController.shiftToGearIndex(value)
						devices[k].setGearIndex(devices[k], value)
					end
				end
			end
		end

		if string.match(k, "transfercase") or k == "rangebox" then
			--print("applied "..k.." - "..tostring(v))
			for key,value in pairs(v) do
				--print(devices[k].type)
				if key == "mode" then
					--print(k.." ("..key..")  -> "..value)
					if devices[k].mode ~= value then
						powertrain.toggleDeviceMode(k)
					end
				end
			end
		end
	end
end

local function onInit()
	print("MPInit!")
	electrics.values.MPGear = 0
end

local function equals(t1, t2)
  for k,_ in pairs(t1) do
		--print(tostring(t1["gearbox"][k]).." ~= "..tostring(t2["gearbox"][k]))
		for key,_ in pairs(t1[k]) do
			if t1[k][key] ~= t2[k][key] then
				return false
			end
		end
	end
	return true
end

local lastPowertrain = {
	gearbox = {
		type = "",
		gearIndex = "",
		mode = ""
	},
}

local function updateGFX(dt)
	if v.mpVehicleType == 'remote' then
		if gearType == "auto" then
			if gearTranslationTable[string.sub(electrics.values.gear, 1, 1)] ~= tonumber(expectedGear) then
				controller.mainController.shiftToGearIndex(tonumber(expectedGear))
			end
		else
			if electrics.values.MPGear ~= tonumber(expectedGear) then
				--print("Looping gear!")
				if powertrain.getDevices().gearbox.type == "manualGearbox" then
					controller.mainController.shiftToGearIndex(tonumber(expectedGear))
					electrics.values.MPGear = expectedGear
				else
					if electrics.values.MPGear < tonumber(expectedGear) then
						controller.mainController.shiftToGearIndex(tonumber(electrics.values.MPGear)+1)
						electrics.values.MPGear = electrics.values.MPGear + 1
					else
						controller.mainController.shiftToGearIndex(tonumber(electrics.values.MPGear)-1)
						electrics.values.MPGear = electrics.values.MPGear - 1
					end
				end
			end
		end
	end

	local devices = powertrain.getDevices() -- Get all devices

	local currentPowertrain = {
		gearbox = {
			type = "",
			gearIndex = "",
			mode = ""
		},
	}

	for k,v in pairs(devices) do
		if k == "gearbox" then
			if v.type == "automaticGearbox" or v.type == "dctGearbox" then
				currentPowertrain[k] = {
					type = v.type,
					mode = v.mode,
					gearIndex = gearTranslationTable[string.sub(electrics.values.gear, 1, 1)]
				}
			else
				currentPowertrain[k] = {
					type = v.type,
					mode = v.mode,
					gearIndex = v.gearIndex
				}
			end
		elseif k == "frontMotor" then
			currentPowertrain[k] = {
				type = v.type,
				mode = v.mode,
				gearIndex = v.gearIndex
			}
		elseif k == "rearMotor" then
			currentPowertrain[k] = {
				type = v.type,
				mode = v.mode,
				gearIndex = v.gearIndex
			}
		else
			currentPowertrain[k] = {
				type = v.type,
				mode = v.mode
			}
		end
	end

	--print(equals(lastPowertrain, currentPowertrain))
	if not equals(lastPowertrain, currentPowertrain) then
		--dump(lastPowertrain)
		--dump(currentPowertrain)
		--print("Sending Powertrain Edits")
		obj:queueGameEngineLua("powertrainGE.sendLivePowertrain(\'"..jsonEncode(currentPowertrain).."\', \'"..obj:getID().."\')")
		lastPowertrain = currentPowertrain
	end
end

M.onInit              = onInit
M.onExtensionLoaded   = onInit
M.sendPowertrain      = sendPowertrain
M.sendAllPowertrain   = sendAllPowertrain
M.applyPowertrain     = applyPowertrain
M.applyLivePowertrain = applyLivePowertrain
M.updateGFX			      = updateGFX


return M
