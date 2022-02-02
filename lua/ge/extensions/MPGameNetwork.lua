--====================================================================================
-- All work by Titch2000, jojos38 & 20dka.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading MPGameNetwork")



-- ============= VARIABLES =============
local sysTime = 0
local eventTriggers = {}
--keypress handling
local keyStates = {} -- table of keys and their states, used as a reference
local keysToPoll = {} -- list of keys we want to poll for state changes
local keypressTriggers = {}
-- ============= VARIABLES =============

setmetatable(_G,{}) -- temporarily disable global notifications

local function connectToLauncher()
	log('I', 'connectToLauncher', "ATTEMPTING TO CONNECT. THIS HAS BEEN DEPRECIATED")
end



local function disconnectLauncher()
	log('I', 'disconnectLauncher', "ATTEMPTING TO DISCONNECT. THIS HAS BEEN DEPRECIATED")
end



local function sendData(s)
	if MP then
		MP.Core(s)
	end
	if settings.getValue("showDebugOutput") == true then
		print('[MPGameNetwork] Sending Data ('..r..'): '..s)
	end
	if MPDebug then MPDebug.packetSent(r) end
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
	text = reason~="" and ("Reason: ".. reason) or ""
	log('M','quitMP',"Quit MP Called! reason: "..tostring(reason))

	UI.showMdDialog({
		dialogtype="alert", title="You have been kicked from the server", text=text, okText="Return to menu",
		okLua="MPCoreSystem.leaveServer(true)" -- return to main menu when clicking OK
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
	if type(f) ~= "function" or f == nop then
		log('W', 'AddEventHandler', "Event handler function can not be nil")
	else
		table.insert(eventTriggers, {name = n, func = f})
	end
end

-------------------------------------------------------------------------------
-- Keypress handling
-------------------------------------------------------------------------------
function addKeyEventListener(keyname, f, type)
	f = f or function() end
	log('W','AddKeyEventListener', "Adding a key event listener for key '"..keyname.."'")
	table.insert(keypressTriggers, {key = keyname, func = f, type = type or 'both'})
	table.insert(keysToPoll, keyname)

	be:queueAllObjectLua("if true then addKeyEventListener(".. serialize(keysToPoll) ..") end")
end

function onKeyPressed(keyname, f)
	addKeyEventListener(keyname, f, 'down')
end
function onKeyReleased(keyname, f)
	addKeyEventListener(keyname, f, 'up')
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

--====================================================== DATA HANDLE =======================================================
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
	['T'] = function(params) quitMP(params) end, -- Player Kicked Event (old, doesn't contain reason)
	['K'] = function(params) quitMP(params) end, -- Player Kicked Event (new, contains reason)
	['C'] = function(params) UI.chatMessage(params) end, -- Chat Message Event
}

--====================================================== DATA RECEIVE ======================================================
function handleGameMsg(msg)
	-- break it up into code + data
	local code = string.sub(msg, 1, 1)
	local data = string.sub(msg, 2)
	log('W','handleGameMsg','Received: '..code..' -> '..data)
	HandleNetwork[code](data)
	if MPDebug then MPDebug.packetReceived(string.len(msg)) end
end


local function onUpdate(dt)
	
end



local function connectionStatus()
	log('I', 'connectionStatus', "ATTEMPTING TO GET STATUS WHEN THERE IS NO STATUS!!!! THIS HAS BEEN DEPRECIATED")
	log('A', "connectionStatus", debug.traceback())
	return 0
end

detectGlobalWrites() -- reenable global write notifications


--events
M.onUpdate = onUpdate
M.onKeyStateChanged = onKeyStateChanged

--functions
M.connectionStatus    = connectionStatus
M.connectToLauncher   = connectToLauncher
M.disconnectLauncher  = disconnectLauncher
M.send                = sendData
--M.sendSplit           = sendDataSplit -- doesn't exist
M.CallEvent           = handleEvents
M.quitMP               = quitMP

M.addKeyEventListener = addKeyEventListener -- takes: string keyName, function listenerFunction
M.getKeyState         = getKeyState         -- takes: string keyName
M.onVehicleReady      = onVehicleReady

print("MPGameNetwork loaded")
return M
