--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================
-- Powertrain sync related functions
--====================================================================================

local M = {}



-- ============= VARIABLES =============
local lastDevices = {}
-- ============= VARIABLES =============



local function applyLivePowertrain(data)
	controller.mainController.setGearboxMode("realistic")
	local decodedData = jsonDecode(data) -- Decode data
	local devices = powertrain.getDevices()
	for k, v in pairs(decodedData) do -- For each device	
		--k = "gearbox"
		--v.mode = "auto"
		if v.mode then
			powertrain.setDeviceMode(k, v.mode)
			local gearIndex = v.gearIndex
		end
	end
end



local function check()
	local devicesToSend = {}
	local devices = powertrain.getDevices() -- Get all devices
	for k, v in pairs(devices) do -- For each device
		if v.mode then -- If it's something that interests us
			local currDevice = { type = v.type, mode = v.mode, gearIndex = v.gearIndex }
			local lastDevice = lastDevices[k] or { type = "", mode = "" }
			-- If it has changed
			-- We don't send the gearbox because it's already synced into MPElectricsVE
			if currDevice.mode ~= lastDevice.mode and v.name ~= "gearbox" then
				devicesToSend[k] = currDevice -- Send it
				-- print(k.. " has changed")
			end
			lastDevices[k] = currDevice
		end
	end
	if next(devicesToSend) then
		obj:queueGameEngineLua("MPPowertrainGE.sendLivePowertrain(\'"..jsonEncode(devicesToSend).."\', "..obj:getID()..")")
		-- print("Devices "..jsonEncode(devicesToSend).." sent")
	end
end



M.check				  = check
M.applyLivePowertrain = applyLivePowertrain



return M
