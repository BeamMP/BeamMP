-- Copyright (C) 2026 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

local socket = require("socket")
local udp = nil
M.socketConnected = false

local stringBuffer = require("string.buffer")
local sendStringBuff = stringBuffer.new()

local function send(...)
	if udp then
		sendStringBuff:reset()
		sendStringBuff:put(...)

		return udp:send(sendStringBuff:tostring())
	end
end

local function handleInput(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")
	if v.mpServerID ~= serverVehicleID then return end

	if code == 'i' then
		MPInputsVE.applyInputs(data)
	else
		log('W', 'handle', "Received unknown input packet '"..tostring(code).."'! ".. rawData)
	end
end

local function handleElectrics(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")
	if v.mpServerID ~= serverVehicleID then return end

	if code == "e" then -- Electrics (indicators, lights etc...)
		MPElectricsVE.applyElectrics(data, serverVehicleID)
	else
		log('W', 'handle', "Received unknown electrics packet '"..tostring(code).."'! ".. rawData)
	end
end

local function handleNodes(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:(.*)")
	if v.mpServerID ~= serverVehicleID then return end

	if code == "n" then
		nodesVE.applyNodes(data)
	elseif code == "g" then
		nodesVE.applyBreakGroups(data)
	elseif code == "c" then
		controllerSyncVE.applyControllerData(data)
	else
		log('W', 'handle', "Received unknown nodes packet '"..tostring(code).."'! ".. rawData)
	end
end

local function handlePowertrain(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")
	if v.mpServerID ~= serverVehicleID then return end

	if code == "l" then
		MPPowertrainVE.applyLivePowertrain(data)
	elseif code == "e" then
		MPPowertrainVE.applyEngineData(data)
	elseif code == "h" then
		MPPowertrainHydrosVE.applyHydroBeams(data)
	else
		log('W', 'handle', "Received unknown powertrain packet '"..tostring(code).."'! ".. rawData)
	end
end

local function handlePosition(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")
	if v.mpServerID ~= serverVehicleID then return end

	if code == 'p' then
		positionVE.applyPositionData(data)
	else
		log('W', 'handle', "Received unknown position packet '"..tostring(code).."'! ".. rawData)
	end
end

local HandleNetwork = {
	['V'] = function(params) handleInput(params) end, -- inputs and gears
	['W'] = function(params) handleElectrics(params) end,
	['X'] = function(params) handleNodes(params) end, -- currently disabled
	['Y'] = function(params) handlePowertrain(params) end, -- powertrain related things like diff locks and transfercases
	['Z'] = function(params) handlePosition(params) end, -- position and velocity
	--['R'] = function(params) MPControllerGE.handle(params) end, -- Controller data
}

local function updateGFX(dt)
	if udp and v.mpServerID then
		while true do
			local received, err = udp:receive()
			if received then
				-- break it up into code + data
				local code = string.sub(received, 1, 1)
				local data = string.sub(received, 2)
				if HandleNetwork[code] then
					HandleNetwork[code](data)
				else
					log('D', "updateGFX", "Vehicle " .. tostring(v.mpServerID) .. " received data: " .. tostring(data))
				end
			else
				break
			end
		end
	end
end

local function closeDirectVESocket()
	log('D', "closeDirectVESocket", "Closing direct VE UDP socket for vehicle " .. tostring(v.mpServerID))

	if udp then
		udp:close()
		udp = nil

		obj:queueGameEngineLua("MPCoreNetwork.setDirectVEPort('" .. tostring(v.mpServerID) .. "')")
	end

	M.socketConnected = false
end

local function createDirectVESocket()
	if not v.mpServerID then
		log('E', "createDirectVESocket", "Can not direct VE UDP socket: missing mpServerID")
		M.socketConnected = false
	end

	if udp then
		log('D', "createDirectVESocket", "Direct VE UDP socket for vehicle " .. tostring(v.mpServerID) .. " already exists, updating server ID.")

		local _, port = udp:getsockname()
		obj:queueGameEngineLua("MPCoreNetwork.setDirectVEPort('" .. tostring(v.mpServerID) .. "', " .. tostring(port) .. ")")
		return
	end

	log('D', "createDirectVESocket", "Setting up direct VE UDP socket for vehicle " .. tostring(v.mpServerID))

	udp = socket.udp()
	udp:settimeout(0)
	local success, err = udp:setsockname("127.0.0.1", 0)
	if success then
		udp:setpeername((settings.getValue("launcherIp") or "127.0.0.1"), (settings.getValue("launcherPort") or 4444)+2)
		local _, port = udp:getsockname()
		log('I', "createDirectVESocket", "Direct VE UDP socket for vehicle " .. tostring(v.mpServerID) .. " listening on port " .. tostring(port))
		obj:queueGameEngineLua("MPCoreNetwork.setDirectVEPort('" .. tostring(v.mpServerID) .. "', " .. tostring(port) .. ")")
	else
		log('E', "createDirectVESocket", "Failed to set up direct VE UDP socket for vehicle " .. tostring(v.mpServerID) .. ": " .. tostring(err))
	end
end

local function setSocketConnected(connected)
	M.socketConnected = connected
end

local function onExtensionLoaded()
	if v.mpServerID then
		createDirectVESocket()
	end
end

M.send = send
M.updateGFX = updateGFX
M.createDirectVESocket = createDirectVESocket
M.closeDirectVESocket = closeDirectVESocket
M.setSocketConnected = setSocketConnected
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = closeDirectVESocket

return M
