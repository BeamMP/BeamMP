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
local initDone = false
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
	local decodedData = jsonDecode(data) -- Decode data
	for k, v in pairs(decodedData) do -- For each device
		--print("applied "..k.." - "..v)
		powertrain.setDeviceMode(k, v) -- Apply it
	end
end

local function updateGFX()
	if initDone then return end
	
	for _, device in pairs(powertrain.getDevices()) do
		local hook = {func = device.setMode}
	
		setmetatable(hook, {
			__call = function(self, device, mode)
				print("Powertrain update: ID = "..obj:getID()..", name = "..device.name..", mode = "..mode)
				
				sendPowertrain(device.name, mode)
				
				return hook.func(device, mode)
			end
		})
		
		device.setMode = hook
	end
	
	print("Hooked powertrain device mode updates")
	
	initDone = true
end

M.updateGFX          = updateGFX
M.sendPowertrain     = sendPowertrain
M.sendAllPowertrain  = sendAllPowertrain
M.applyPowertrain    = applyPowertrain



return M