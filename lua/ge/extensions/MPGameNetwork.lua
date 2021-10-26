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
--keypress handling
local keyStates = {} -- table of keys and their states, used as a reference
local keysToPoll = {} -- list of keys we want to poll for state changes
local keypressTriggers = {}
-- ============= VARIABLES =============



local function connectToLauncher()
	print("Connecting to the Launcher for mp session")
	if launcherConnectionStatus == 0 then -- If launcher is not connected yet
		local socket = require('socket')
		TCPSocket = socket.tcp() -- Set socket to TCP
		TCPSocket:setoption("keepalive", true)
		TCPSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
		TCPSocket:connect((settings.getValue("launcherIp") or '127.0.0.1'), (settings.getValue("launcherPort") or 4444)+1); -- Connecting
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
	if TCPSocket then
		local r = TCPSocket:send(string.len(s)..'>'..s)
		if settings.getValue("showDebugOutput") == true then
			print('[MPGameNetwork] Sending Data ('..r..'): '..s)
		end
		if MPDebug then MPDebug.packetSent(r) end
	end
end



local function onPlayerConnect() -- Function called when a player connect to the server
	MPUpdatesGE.onPlayerConnect()
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
	log('M','quitMP',"Quit MP Called! reason: "..tostring(reason))

	UI.showMdDialog({
		dialogtype="alert", title="You have been kicked from the server", text="Reason: ".. reason or "none", okText="Return to menu",
		okLua="MPCoreNetwork.resetSession(true)" -- return to main menu when clicking OK
	})

	--send('QG') -- Quit game
end

-------------------------------------------------------------------------------
-- Events System
-------------------------------------------------------------------------------

local function handleEvents(p)  --- code=E  p=:<NAME>:<DATA>
	local eventName = string.match(p,"%:(%w+)%:")
	if not eventName then quitMP(p) return end
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
	log('M', 'AddEventHandler', "Adding Event Handler: Name = "..tostring(n))
	table.insert(eventTriggers, {name = n, func = f})
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

function addKeyEventListener(keyname, f, type)
	f = f or function() end
	log('W','[GE] AddKeyEventListener', "Adding a key event listener for key '"..keyname.."'")
	table.insert(keypressTriggers, {key = keyname, func = f, type = type or 'both'})
	table.insert(keysToPoll, keyname)

	be:queueAllObjectLua("if true then addKeyEventListener(".. serialize(keysToPoll) ..") end")
end

local function onKeyStateChanged(key, state)
	keyStates[key] = state
	--dump(keyStates)
	--dump(keypressTriggers)
	for i=1,#keypressTriggers do
		if keypressTriggers[i].key == key and (keypressTriggers[i].type == 'both' or keypressTriggers[i].type == (state and 'down' or 'up')) then
			keypressTriggers[i].func(state)
		end
	end
end

function getKeyState(key)
	return keyStates[key] or false
end

local function onVehicleReady(gameVehicleID)
	local veh = be:getObjectByID(gameVehicleID)
	if not veh then
		log('R', 'onVehicleReady', 'Vehicle does not exist!')
		return
	end
	veh:queueLuaCommand("addKeyEventListener(".. serialize(keysToPoll) ..")")
end

-------------------------------------------------------------------------------

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
	['T'] = nop,--function(params) MPCoreNetwork.resetSession(params) end, -- Event For another Resource
	['K'] = function(params) quitMP(params) end, -- Player Kicked Event
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
			if MPDebug then MPDebug.packetReceived(string.len(received)) end
		end
	end
end



local function connectionStatus()
	return launcherConnectionStatus
end


--events
M.onUpdate = onUpdate
M.onKeyStateChanged = onKeyStateChanged

--functions
M.connectionStatus    = connectionStatus
M.connectToLauncher   = connectToLauncher
M.disconnectLauncher  = disconnectLauncher
M.send                = sendData
M.sendSplit           = sendDataSplit
M.CallEvent           = handleEvents

M.addKeyEventListener = addKeyEventListener -- takes: string keyName, function listenerFunction
M.getKeyState         = getKeyState         -- takes: string keyName
M.onVehicleReady      = onVehicleReady

print("MPGameNetwork loaded")
return M
