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
		if k == "gearbox" then
			--print("applied "..k.." - "..tostring(v))
			for key,value in pairs(v) do
				if key == "gearIndex" then
					devices["gearbox"].setGearIndex(devices["gearbox"], value)
				end
			end
		end
	end
end

local function onInit()
	local setModeNil = false
	for k, device in pairs(powertrain.getDevices()) do
		if device.setMode == nil and (k == "mainEngine" or k == "gearbox") then
			setModeNil = true
			print("FOUND A NIL")
			print(device)
			print(k)
		end
	end

	if not setModeNil then
		print("Not Nil Now")
	else
		print(" Still Nil Reload?")
		--onInit()
	end

	--[[for _, device in pairs(powertrain.getDevices()) do

		local setMode = device.setMode

		device.setMode = function(device, mode, ...)
			--print("Powertrain update: ID = "..obj:getID()..", name = "..device.name..", mode = "..mode)

			sendPowertrain(device.name, mode)

			return setMode(device, mode, ...)
		end
	end]]

	print("Hooked powertrain device mode updates")
end

local function equals(t1, t2)
  for k,v in pairs(t1["gearbox"]) do
		--print(tostring(t1["gearbox"][k]).." ~= "..tostring(t2["gearbox"][k]))
		if t1["gearbox"][k] ~= t2["gearbox"][k] then
			return false
		end
	end
	--[[for k,v in pairs(t1["mainEngine"]) do
		--print(tostring(t1["mainEngine"][k]).." ~= "..tostring(t2["mainEngine"][k]))
		if t1["mainEngine"][k] ~= t2["mainEngine"][k] then
			return false
		end
	end]]
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
		}
	}

	if --[[devices["mainEngine"] ~= nil and]] devices["gearbox"] ~= nil then
		currentPowertrain = {
			--[[mainEngine = {
				isBroken = devices["mainEngine"].isBroken,
				isStalled = devices["mainEngine"].isStalled
			},]]
			gearbox = {
				type = devices["gearbox"].type,
				gearIndex = devices["gearbox"].gearIndex,
				mode = devices["gearbox"].mode
			}
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
