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
		if k == "gearbox" or k == "differential_F" or k == "differential_R" or k == "wheelaxleFL" or k == "wheelaxleFR" or k == "wheelaxleRL" or k == "wheelaxleRR" then
			--print("applied "..k.." - "..tostring(v))
			for key,value in pairs(v) do
				print(devices[k].type)
				if key == "gearIndex" and (devices[k].type == "manualGearbox" or devices[k].type == "automaticGearbox") then
					print(k .. " -> " .. value)
					devices[k].setGearIndex(devices[k], value)
				end
				if key == "mode" then
					print(k .. " -> " .. value)
					devices[k].setMode(devices[k], value)
				end
			end
		end

		if k == "transfercase_F" or k == "transfercase_R" or k == "rangebox" then
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
	--[[mainEngine = {
		isBroken = "",
		isStalled = ""
	},]]
	gearbox = {
		type = "",
		gearIndex = "",
		mode = ""
	},
	transfercase_F = {
		mode = ""
	}
}

local function updateGFX(dt)
	local devices = powertrain.getDevices() -- Get all devices

	local currentPowertrain = {
		--[[mainEngine = {
			isBroken = "",
			isStalled = ""
		},]]
		gearbox = {
			type = "",
			gearIndex = "",
			mode = ""
		},
		transfercase_F = {
			mode = ""
		}
	}

	if devices["gearbox"] ~= nil then
		currentPowertrain.gearbox = {
			type = devices["gearbox"].type,
			gearIndex = devices["gearbox"].gearIndex,
			mode = devices["gearbox"].mode
		}
	end

	if devices["transfercase_F"] ~= nil then
		currentPowertrain.transfercase_F = {
			type = devices["transfercase_F"].type,
			mode = devices["transfercase_F"].mode
		}
	end

	if devices["transfercase_R"] ~= nil then
		currentPowertrain.transfercase_R = {
			type = devices["transfercase_R"].type,
			mode = devices["transfercase_R"].mode
		}
	end

	if devices["differential_F"] ~= nil then
		currentPowertrain.differential_F = {
			type = devices["differential_F"].type,
			mode = devices["differential_F"].mode
		}
	end

	if devices["differential_R"] ~= nil then
		currentPowertrain.differential_R = {
			type = devices["differential_R"].type,
			mode = devices["differential_R"].mode
		}
	end

	if devices["rangebox"] ~= nil then
		currentPowertrain.rangebox = {
			type = devices["rangebox"].type,
			mode = devices["rangebox"].mode
		}
	end

	if devices["wheelaxleFL"] ~= nil then
		currentPowertrain.wheelaxleFL = {
			type = devices["wheelaxleFL"].type,
			mode = devices["wheelaxleFL"].mode
		}
	end

	if devices["wheelaxleFR"] ~= nil then
		currentPowertrain.wheelaxleFR = {
			type = devices["wheelaxleFR"].type,
			mode = devices["wheelaxleFR"].mode
		}
	end

	if devices["wheelaxleRL"] ~= nil then
		currentPowertrain.wheelaxleRL = {
			type = devices["wheelaxleRL"].type,
			mode = devices["wheelaxleRL"].mode
		}
	end

	if devices["wheelaxleRR"] ~= nil then
		currentPowertrain.wheelaxleRR = {
			type = devices["wheelaxleRR"].type,
			mode = devices["wheelaxleRR"].mode
		}
	end

	--print(equals(lastPowertrain, currentPowertrain))
	if not equals(lastPowertrain, currentPowertrain) then
		dump(lastPowertrain)
		dump(currentPowertrain)
		print("Sending Powertrain Edits")
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
