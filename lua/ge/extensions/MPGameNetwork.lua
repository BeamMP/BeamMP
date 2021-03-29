--====================================================================================
-- All work by Titch2000, jojos38 & 20dka.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading MPGameNetwork")



-- ============= VARIABLES =============
local TCPSocket
local launcherConnectionStatus = 0 -- Status: 0 not connected | 1 connecting or connected
local sysTime = 0
local eventTriggers = {}
-- ============= VARIABLES =============



local function connectToLauncher()
	print("Connecting to the Launcher for mp session")
	if launcherConnectionStatus == 0 then -- If launcher is not connected yet
		local socket = require('socket')
		TCPSocket = socket.tcp() -- Set socket to TCP
		TCPSocket:setoption("keepalive", true)
		TCPSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
		TCPSocket:connect('127.0.0.1', (settings.getValue("launcherPort") or 4444)+1); -- Connecting
		launcherConnectionStatus = 1
	end
end



local function disconnectLauncher()
	if launcherConnectionStatus > 0 then -- If player were connected
		TCPSocket:close()-- Disconnect from server
		launcherConnectionStatus = 0
	end
end



local function sendData(s)
	local r = TCPSocket:send(string.len(s)..'>'..s)
	if settings.getValue("showDebugOutput") == true then
		print('[MPGameNetwork] Sending Data ('..r..'): '..s)
	end
	MPDebug.packetSent(r)
end



local function onPlayerConnect() -- Function called when a player connect to the server
	MPUpdatesGE.onPlayerConnect()
end



local function sessionData(data)
	local code = string.sub(data, 1, 1)
	local data = string.sub(data, 2)
	if code == "s" then
		local players = string.match(data,"(.*)%:")
		data = string.match(data, ":(.*)")
		UI.updatePlayersList(data)
		UI.setPlayerCount(players)
	elseif code == "n" then
		UI.setNickname(data)
		MPConfig.setNickname(data)
	end
end

-------------------------------------------------------------------------------
-- Events System
-------------------------------------------------------------------------------

local function handleEvents(p)  --- code=E  p=:<NAME>:<DATA>
	local eventName = string.match(p,"%:(%w+)%:")
	local data = p:gsub(":"..eventName..":", "")
	for i=1,#eventTriggers do
		if eventTriggers[i].name == eventName then
			eventTriggers[i].func(data)
		end
	end
end

function TriggerServerEvent(n, d)
	sendData('E:'..n..':'..d)
end

function TriggerClientEvent(n, d)
	handleEvents(':'..n..':'..d)
end

function AddEventHandler(n, f)
	print("Adding Event Handler: Name = "..tostring(n))
	table.insert(eventTriggers, {name = n, func = f})
end

local HandleNetwork = {
	['V'] = function(params) MPInputsGE.handle(params) end,
	['W'] = function(params) MPElectricsGE.handle(params) end,
	['X'] = function(params) nodesGE.handle(params) end,
	['Y'] = function(params) MPPowertrainGE.handle(params) end,
	['Z'] = function(params) positionGE.handle(params) end,
	['O'] = function(params) MPVehicleGE.handle(params) end,
	['P'] = function(params) MPConfig.setPlayerServerID(params) end,
	['J'] = function(params) onPlayerConnect() UI.showNotification(params) end, -- A player joined
	['L'] = function(params) UI.showNotification(params) end, -- Display custom notification
	['S'] = function(params) sessionData(params) end, -- Update Session Data
	['E'] = function(params) handleEvents(params) end, -- Event For another Resource
	['T'] = function(params) MPCoreNetwork.resetSession('true') end, -- Event For another Resource
	['C'] = function(params) UI.chatMessage(params) end, -- Chat Message Event
}



local function onUpdate(dt)
	--====================================================== DATA RECEIVE ======================================================
	if launcherConnectionStatus > 0 then -- If player is connecting or connected
		while (true) do
			local received, status, partial = TCPSocket:receive() -- Receive data
			if received == nil or received == "" then break end
			-- break it up into code + data
			local code = string.sub(received, 1, 1)
			local data = string.sub(received, 2)
			HandleNetwork[code](data)

			MPDebug.packetReceived(string.len(received))
		end
	end
end



local function connectionStatus()
	return launcherConnectionStatus
end



M.onUpdate = onUpdate
M.connectToLauncher = connectToLauncher
M.disconnectLauncher = disconnectLauncher
M.send = sendData
M.sendSplit = sendDataSplit
M.connectionStatus = connectionStatus
M.CallEvent = handleEvents


print("MPGameNetwork loaded")
return M
