--- @meta
--- @module "MPGameNetwork"

--[==[================================================================================
-- All work by Titch2000, jojos38 & 20dka.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
==================================================================================]==]

--- @class MPGameNetwork
local M = {}

local socket = require('socket')
local TCPSocket
local launcherConnected = false
local eventTriggers = {}

local keyStates = {}
local keysToPoll = {}
local keypressTriggers = {}

setmetatable(_G, {}) -- temporarily disable global notifications

local function connectToLauncher()
	log('M', 'connectToLauncher', "Connecting MPGameNetwork!")
	if not launcherConnected then
		TCPSocket = socket.tcp()
		TCPSocket:setoption("keepalive", true)
		TCPSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
		TCPSocket:connect((settings.getValue("launcherIp") or '127.0.0.1'), (settings.getValue("launcherPort") or 4444) +
		1)
		M.send('A')
	else
		log('W', 'connectToLauncher', 'Launcher already connected!')
	end
end



local function disconnectLauncher()
	if launcherConnected then
		TCPSocket:close()
		launcherConnected = false
	end
end

local dataMap = {}

local function parseAndSend(s)
	local bytes, error, index = TCPSocket:send(#s .. '>' .. s)
	if type(error) == 'string' then
		log('E', 'sendData', 'Socket error: ' .. error)
		if error == 'closed' and launcherConnected == true then
			log('W', 'sendData', 'Launcher disconnected!')
			launcherConnected = false
		elseif error == 'Socket is not connected' then

		else
			log('E', 'sendData', 'Stopped at index: ' .. index .. ' while trying to send ' .. #s .. ' bytes of data')
		end
	else
		if not launcherConnected then
			launcherConnected = true
		end
		if settings.getValue('showDebugOutput') then
			log('M', 'sendData', 'Sending data... (' .. #s .. ' bytes)')
		end
		if MPDebug then
			MPDebug.packetSent(bytes)
		end
	end
end

local function sendDataAsync(s)
	if not TCPSocket then
		return log('E', 'sendData', 'Socket not connected!')
	elseif type(s) ~= 'string' then
		return log('E', 'sendData', 'Data must be a string!')
	elseif dataMap[s] then
		return log('E', 'sendData', 'Data already queued!')
	end
	dataMap[s] = true
	pcall(parseAndSend, s)
	dataMap[s] = nil
end

local function sendData(s)
	local success, response = pcall(sendDataAsync, s)
	if success == true then
		return response
	elseif type(response) == 'string' then
		log('E', 'sendData', response)
	end
end

local function sessionData(data)
	local code = string.sub(data, 1, 1)
	local data = string.sub(data, 2)
	if code == "s" then
		local playerCount, playerList = string.match(data, "^(%d+%/%d+)%:(.*)") -- 1/10:player1,player2
		UI.setPlayerCount(playerCount)
		UI.updatePlayersList(playerList)
	elseif code == "n" then
		UI.setNickname(data)
		MPConfig.setNickname(data)
	end
end

local function quitMP(reason)
	local text = reason ~= "" and ("Reason: " .. reason) or ""
	log('M', 'quitMP', "Quit MP Called! reason: " .. tostring(reason))
	UI.showMdDialog({
		dialogtype = "alert",
		title = "You have been disconnected from the server",
		text = text,
		okText = "Return to menu",
		okLua = "MPCoreNetwork.leaveServer(true)" -- return to main menu when clicking OK
	})
end

-------------------------------------------------------------------------------
-- Events System
-------------------------------------------------------------------------------

local function handleEvents(p) --- code=E  p=:<NAME>:<DATA>
	local eventName, eventData = string.match(p, "^%:([^%:]+)%:(.*)")
	if not eventName then
		quitMP(p)
		return
	end
	for _, trigger in pairs(eventTriggers) do
		if trigger.name == eventName then
			if type(trigger.func) == "function" then
				trigger.func(eventData)
			end
		end
	end
end

--- @param name string
--- @param data string
function TriggerServerEvent(name, data)
	sendData('E:' .. name .. ':' .. data)
end

--- @param name string
--- @param data string
function TriggerClientEvent(name, data)
	handleEvents(':' .. name .. ':' .. data)
end

--- @param n string
--- @param f function
function AddEventHandler(n, f)
	log('M', 'AddEventHandler', "Adding Event Handler: Name = " .. tostring(n))
	if type(f) ~= "function" or f == nop then
		return log('W', 'AddEventHandler', "Event handler function can not be nil")
	end
	table.insert(eventTriggers, { name = n, func = f })
end

-------------------------------------------------------------------------------
-- Keypress handling
-------------------------------------------------------------------------------
function onKeyPressed(keyname, f)
	addKeyEventListener(keyname, f, 'down')
end

function onKeyReleased(keyname, f)
	addKeyEventListener(keyname, f, 'up')
end

--- Creates a new key event listener.
--- @param keyname string The name of the key to listen for.
--- @param f function The function to call when the key is pressed.
--- @param type string The type of event to listen for. Can be 'down', 'up', or 'both'.
function addKeyEventListener(keyname, f, type)
	if type(f) ~= 'function' then
		f = fi
	end
	log('W', 'AddKeyEventListener', "Adding a key event listener for key '" .. keyname .. "'")
	table.insert(keypressTriggers, { key = keyname, func = f, type = type or 'both' })
	table.insert(keysToPoll, keyname)
	be:queueAllObjectLua("if true then addKeyEventListener(" .. serialize(keysToPoll) .. ") end")
end

local function onKeyStateChanged(key, state)
	keyStates[key] = state
	for i = 1, #keypressTriggers do
		if keypressTriggers[i].key == key and (keypressTriggers[i].type == 'both' or keypressTriggers[i].type == (state and 'down' or 'up')) then
			keypressTriggers[i].func(state)
		end
	end
end

--- Returns the state of a key.
--- @return boolean state
function getKeyState(key)
	return keyStates[key] or false
end

local function onVehicleReady(gameVehicleID)
	local veh = be:getObjectByID(gameVehicleID)
	if not veh then
		log('R', 'onVehicleReady', 'Vehicle does not exist!')
		return
	end
	veh:queueLuaCommand("addKeyEventListener(" .. serialize(keysToPoll) .. ")")
end

-------------------------------------------------------------------------------

local HandleNetwork = {
	['V'] = function(params) MPInputsGE.handle(params) end,                              -- inputs and gears
	['W'] = function(params) MPElectricsGE.handle(params) end,
	['X'] = function(params) nodesGE.handle(params) end,                                 -- currently disabled
	['Y'] = function(params) MPPowertrainGE.handle(params) end,                          -- powertrain related things like diff locks and transfercases
	['Z'] = function(params) positionGE.handle(params) end,                              -- position and velocity
	['O'] = function(params) MPVehicleGE.handle(params) end,                             -- all vehicle spawn, modification and delete events, couplers
	['P'] = function(params) MPConfig.setPlayerServerID(params) end,
	['J'] = function(params)
		MPUpdatesGE.onPlayerConnect()
		UI.showNotification(params)
	end,                                                                                 -- A player joined
	['L'] = function(params) UI.showNotification(params) end,                            -- Display custom notification
	['S'] = function(params) sessionData(params) end,                                    -- Update Session Data
	['E'] = function(params) handleEvents(params) end,                                   -- Event For another Resource
	['T'] = function(params) quitMP(params) end,                                         -- Player Kicked Event (old, doesn't contain reason)
	['K'] = function(params) quitMP(params) end,                                         -- Player Kicked Event (new, contains reason)
	['C'] = function(params) UI.chatMessage(params) end,                                 -- Chat Message Event
}


local heartbeatTimer = 0
local function onUpdate(dt)
	--====================================================== DATA RECEIVE ======================================================
	if launcherConnected then
		while (true) do
			local received, status, partial = TCPSocket:receive() -- Receive data
			if received == nil or received == "" then break end

			if settings.getValue("showDebugOutput") == true then
				log('M', 'onUpdate', 'Receiving Data (' .. #received .. '): ' .. received)
			end

			-- break it up into code + data
			local code = string.sub(received, 1, 1)
			local data = string.sub(received, 2)
			HandleNetwork[code](data)

			if MPDebug then MPDebug.packetReceived(#received) end
		end
	end
	if heartbeatTimer >= 1 and MPCoreNetwork.isMPSession() then --TODO: something
		heartbeatTimer = 0
		sendData('A')
	end
end



local function isLauncherConnected()
	return launcherConnected
end

local function connectionStatus() --legacy, here because some mods use it
	return launcherConnected and 1 or 0
end

detectGlobalWrites() -- reenable global write notifications


--events
M.onUpdate            = onUpdate
M.onKeyStateChanged   = onKeyStateChanged

--functions
M.launcherConnected   = isLauncherConnected
M.connectionStatus    = connectionStatus --legacy
M.connectToLauncher   = connectToLauncher
M.disconnectLauncher  = disconnectLauncher
M.send                = sendData
M.CallEvent           = handleEvents
M.quitMP              = quitMP

M.addKeyEventListener = addKeyEventListener -- takes: string keyName, function listenerFunction
M.getKeyState         = getKeyState         -- takes: string keyName
M.onVehicleReady      = onVehicleReady

return M
