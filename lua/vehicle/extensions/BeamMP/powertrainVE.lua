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
	--obj:queueGameEngineLua("powertrainGE.sendPowertrain(\'"..jsonEncode(tableToSend).."\', \'"..obj:getID().."\')")
end



local function sendPowertrain(name, mode)
	local tableToSend = {}  -- Create table with gameVehicleID
	tableToSend[name] = mode -- Add device to the table
	obj:queueGameEngineLua("powertrainGE.sendPowertrain(\'"..jsonEncode(tableToSend).."\', \'"..obj:getID().."\')")
end



local function applyPowertrain(data)
	local decodedData = jsonDecode(data) -- Decode data
	for k, v in pairs(decodedData) do -- For each device
		print("applied "..k.." - "..tostring(v))
		powertrain.setDeviceMode(k, v) -- Apply it
	end
end

local function applyLivePowertrain(data)
	local decodedData = jsonDecode(data) -- Decode data
	--dump(decodedData)
	local devices = powertrain.getDevices()
	for k, v in pairs(decodedData) do -- For each device
		for key,value in pairs(v) do
			if key == "mode" then
				print(k .. " -> " .. value)
				devices[k].setMode(devices[k], value)
			end
		end
		if k == "gearbox" or k == "differential_F" or k == "differential_R" or k == "differential_R_1" or k == "differential_R_2" or k == "wheelaxleFL" or k == "wheelaxleFR" or k == "wheelaxleRL" or k == "wheelaxleRR" then
			--print("applied "..k.." - "..tostring(v))
			for key,value in pairs(v) do
				print(devices[k].type)
				if key == "gearIndex" and (devices[k].type == "manualGearbox" or devices[k].type == "automaticGearbox") then
					print(k .. " -> " .. value)
					devices[k].setGearIndex(devices[k], value)
				end
			end
		end

		if string.match(k, "transfercase") or k == "rangebox" then
			--print("applied "..k.." - "..tostring(v))
			for key,value in pairs(v) do
				print(devices[k].type)
				if key == "mode" then
					print(k.." ("..key..")  -> "..value)
					if devices[k].mode ~= value then
						powertrain.toggleDeviceMode(k)
					end
				end
			end
		end
	end
end

local function onInit()
	local devices = powertrain.getDevices() -- Get all devices
	for k,v in pairs(devices) do
		--print(k .. " = " .. tostring(v))
	end
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
	local devices = powertrain.getDevices() -- Get all devices

	local currentPowertrain = {
		gearbox = {
			type = "",
			gearIndex = "",
			mode = ""
		},
	}

	for k,v in pairs(devices) do
		currentPowertrain[k] = {
			type = v.type,
			mode = v.mode
		}
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
