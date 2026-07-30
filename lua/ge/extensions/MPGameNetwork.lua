-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- MPGameNetwork API. Handles Proxy Launcher <-> Game Network. Vehicle Spawns, edits, chat, position updates etc. Everything session related.
--- Author of this documentation is Titch2000
--- @module MPGameNetwork
--- @usage connectToLauncher() -- internal access
--- @usage MPGameNetwork.connectToLauncher() -- external access

local M = {}

local ffi = require("ffi")


-- ============= VARIABLES =============

local socket = require('socket')
local TCPLauncherSocket
local launcherConnected = false
local isConnecting = false
local socketPartialData

--[[ Format
	["eventname"] = table
		[1..n] = table
			[source] = path to source
			[func] = function
]]
local eventTriggers = {}

--keypress handling

local keyStates = {} -- table of keys and their states, used as a reference
local keysToPoll = {} -- list of keys we want to poll for state changes
local keypressTriggers = {}

-- ============= VARIABLES =============

setmetatable(_G,{}) -- temporarily disable global notifications


--- Attempt to establish a connection to the Launcher, Note that this connection is only used for when in-session.
-- @usage MPGameNetwork.connectToLauncher(true)
local function connectToLauncher()
	log('M', 'connectToLauncher', "Connecting MPGameNetwork!")
	if not launcherConnected then
		isConnecting = true
		socketPartialData = nil
		if not TCPLauncherSocket then
			TCPLauncherSocket = socket.tcp()
			TCPLauncherSocket:setoption("keepalive", true)
			TCPLauncherSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
			TCPLauncherSocket:connect((settings.getValue("launcherIp") or '127.0.0.1'), (settings.getValue("launcherPort") or 4444)+1)
		end
		M.send('A') -- will succeed once handshake completes, setting launcherConnected=true
	else
		log('W', 'connectToLauncher', 'Launcher already connected!')
	end
end


--- Disconnect from the Launcher by closing the TCP connection, Note that this connection is only used for when in-session.
-- @usage MPGameNetwork.disconnectLauncher(true)
local function disconnectLauncher()
	if TCPLauncherSocket then
		TCPLauncherSocket:close()
		TCPLauncherSocket = nil
	end
	launcherConnected = false
	isConnecting = false
	socketPartialData = nil
	connectRetryTimer = 0
end


--- Send given packet to the Server, over the Launcher.
-- @tparam string s The packet to be sent to the Launcher/server.
-- @usage MPGameNetwork.sendData(`<data>`)
local function sendData(data) -- TODO currently the socket keeps retrying indefinitely if timed out, this freezes the game if the launcher is frozen, breaking the loop with offset the header and break the connection, we could maybe buffer data and try again next frame?
	-- if not connected return
	if not TCPLauncherSocket then return end
	local header = ffi.string(ffi.new("uint32_t[?]", 4, #data), 4)
	local packet = header .. data

	local retries = 1

	local bytes, error, index = TCPLauncherSocket:send(packet)

	if error == 'timeout' then
		while (retries > 0 and error) do
			isConnecting = false
			log('E', 'sendData', 'Socket error: '..error)
			if error == "timeout" then
				log('W', 'sendData', 'Stopped at index: '..index..' while trying to send '..#packet..' bytes of data. retries:' .. retries)
				packet = string.sub(packet, index + 1)

				bytes, error, index = TCPLauncherSocket:send(packet)
			end
		end
	end

	if error then
		if error == "Socket is not connected" then
			-- tcp handshake still in progress; keep isConnecting=true and let onUpdate retry
			return
		end
		isConnecting = false
		log('E', 'sendData', 'Socket error: '..error)
		if error == "closed" and launcherConnected then
			log('W', 'sendData', 'Lost launcher connection!')
			launcherConnected = false
			TCPLauncherSocket = nil
		elseif error == "closed" then
			TCPLauncherSocket = nil
		else
			log('W', 'sendData', 'Stopped at index: '..index..' while trying to send '..#packet..' bytes of data.')
		end
		return
	else
		if not launcherConnected then launcherConnected = true isConnecting = false end
		if settings.getValue("showDebugOutput") then
			log('M', 'sendData', 'Sending Data ('..bytes..'): '..data)
		end
		if MPDebug then MPDebug.packetSent(bytes) end
	end
end

--- Process session data received from the Launcher.
-- @tparam string data The session data received.
-- @usage MPGameNetwork.sessionData(`<data>`)
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

--- Display given disconnect reason to the Player
-- @tparam string reason The reason for quitting the session.
-- @usage MPGameNetwork.quitMP(`<reason>`)
local function quitMP(reason)
	local text = reason~="" and ("Reason: ".. reason) or ""
	log('M','quitMP',"Quit MP Called! reason: "..tostring(reason))

	UI.showMdDialog({
		dialogtype="alert", title="You have been disconnected from the server", text=text, okText="Return to menu",
		okLua="MPCoreNetwork.leaveServer(true)" -- return to main menu when clicking OK
	})
end

local function playerLeft(params)
	local leftName = string.match(params, "^(.+) left the server!$") 
	if leftName then 
		MPVehicleGE.onPlayerLeft(leftName) 
		UI.showNotification(params, nil, "exit_to_app")
	end 
end

--[[
	Format
	[title] = String (Optional. The Title of the Dialog)
	[body] = String (Optional. The text [question] displayed to the user)
	[buttons] = table (Optional)
		[1..n] = table
			[label] = String (Ok, Cancel..)
			[default] = bool (When the user presses the ENTER key this button will be executed)
			[isCancel] = bool (When the user presses the ESC key this button will be executed)
			[key] = String (Optional. The "event" that will be broadcasted to the server and/or the extensions)
	[class] = String (Optional)
		experimental = Draws hazard lines around the dialog
	[interactionID] = String (Optional. The name of the interaction)
	[reportToServer] = bool (Optional. If true will report the button "key" together with the "interactionID" to the server)
	[reportToExtensions] = bool (Optional. If true will report the button "key" together with the "interactionID" to the local extensions)
	
	Example
	
	MPGameNetwork.spawnUiDialog({
		title = "Awesome Title",
		body = "Hey do you rather like Pepsi or Cola?",
		buttons = {
			{
				label = "Pepsi",
				key = "favoriteDrinkPepsi"
			},
			{
				label = "Cola",
				key = "favoriteDrinkCola"
			}
		},
		interactionID = "favoriteDrink",
		reportToServer = true,
		reportToExtensions = true
	})
	
	-- Server side
	function favoriteDrinkPepsi(player_id, interactionID)
		print(MP.GetPlayerName(player_id) .. ' likes Pepsi!")
	end
	
	function favoriteDrinkCola(player_id, interactionID)
		print(MP.GetPlayerName(player_id) .. ' likes Cola!")
	end
	
	MP.RegisterEvent("favoriteDrinkPepsi", "favoriteDrinkPepsi")
	MP.RegisterEvent("favoriteDrinkCola", "favoriteDrinkCola")
	
	-- Locally
	M.favoriteDrinkPepsi = function()
		print("I Like Pepsi!")
	end
	
	M.favoriteDrinkCola = function()
		print("I like Cola!")
	end
]]
local function spawnUiDialog(dialogInfo)
	local buttons = next(dialogInfo.buttons or {}) and dialogInfo.buttons or {
		{
			label = "OK",
			key = nil,
			default = true,
			isCancel = true
		}
	}
	
	if dialogInfo.reportToServer == nil then dialogInfo.reportToServer = false end
	if dialogInfo.reportToExtensions == nil then dialogInfo.reportToExtensions = false end
	
	if dialogInfo.class ~= "experimental" then
		dialogInfo.class = ""
	end

	be:queueJS(string.format([[
			angular.element(document.body).injector().get('ConfirmationDialog').open(
				DOMPurify.sanitize(JSON.parse(atob(`%s`))), 
				DOMPurify.sanitize(JSON.parse(atob(`%s`))),
				JSON.parse(atob(`%s`)),
				{ class: atob(`%s`) }
			).then(res => {
				if (res) {
					if (%s) {
						bngApi.engineLua(`TriggerServerEvent(MPHelpers.b64decode("` + btoa(res) + `"), MPHelpers.b64decode("%s"))`)
					}
					if (%s) {
						bngApi.engineLua(`extensions.hook(MPHelpers.b64decode("` + btoa(res) + `"), MPHelpers.b64decode("%s"))`)
					}
				}
			});
		]],
		MPHelpers.b64encode(jsonEncode(dialogInfo.title or "Dialog")),
		MPHelpers.b64encode(jsonEncode(dialogInfo.body or "")),
		MPHelpers.b64encode(jsonEncode(buttons)),
		MPHelpers.b64encode(dialogInfo.class or ""),
		type(dialogInfo.reportToServer) == "boolean" and dialogInfo.reportToServer,
		MPHelpers.b64encode(dialogInfo.interactionID or ""),
		type(dialogInfo.reportToExtensions) == "boolean" and dialogInfo.reportToExtensions,
		MPHelpers.b64encode(dialogInfo.interactionID or "")
	))
end

-- -----------------------------------------------------------------------------
-- Events System
-- -----------------------------------------------------------------------------

--- Handles events triggered by MP.TriggerClientEvent send from the Server or localy with TriggerClientEvent.
-- @tparam string p The event data to be parsed and handled. Should be in the format ":<NAME>:<DATA>"
-- @usage MPGameNetwork.CallEvent(`<event data string>`)
local function handleEvents(p)
	local name, data = string.match(p,"^%:([^%:]+)%:(.*)")
	if not name then log('W', 'Attempted to call event with malformed data: '..tostring(p)) return end
	for _, calls in ipairs(eventTriggers[name] or {}) do
		local ok, err = pcall(calls.func, data)
		if not ok then
			log('E', 'BeamMP - handleEvents', err)
		end
	end
end

--- Triggers a server event with the specified name and data.
-- @tparam string name - The name of the event
-- @tparam string data - The data to be sent with the event
-- @usage TriggerServerEvent(`<name>`, `<data>`)
function TriggerServerEvent(name, data)
	M.send('E:'..name..':'..data)
end

--- Triggers a local client event with the specified name and data.
-- @tparam string name - The name of the event
-- @tparam string data - The data to be sent with the event
-- @usage `TriggerClientEvent(`<name>`, `<data>`)
function TriggerClientEvent(name, data)
	handleEvents(':'..name..':'..data)
end

--- Adds an event handler for the specified event name and function.
-- @tparam string event_name - The name of the event
-- @tparam function func - The event handler function
-- @tparam string name - The internal name (optional)
-- @usage AddEventHandler(`<name>`, `<function>`)
-- @usage if AddEventHandler then AddEventHandler(`<name>`, `<function>`) end -- if your mod is also singleplayer available
function AddEventHandler(event_name, func, name)
	if event_name == nil or type(event_name) ~= "string" or (type(event_name) == "string" and event_name:len() == 0) then
		log('E', 'BeamMP - AddEventHandler', 'Error, given event_name is not a valid string name')
		return
	end
	if (func == nil or func == nop) or type(func) ~= "function" then
		log('E', 'BeamMP - AddEventHandler', 'Error, given function is not a valid function')
		return
	end
	
	local source = name or debug.getinfo(2).source
	if source == nil or source:len() == 0 then
		log('E', 'BeamMP - AddEventHandler', 'Error, invalid source of event')
		return
	end
	
	local calls = eventTriggers[event_name]
	if not calls then
		calls = {}
		eventTriggers[event_name] = calls
	end
	
	local patch = false
	for index, call in ipairs(calls) do
		if call.source == source then
			patch = true
			local max = #calls
			calls[index] = calls[max]
			if max > 1 then
				calls[max] = nil
			end
			break
		end
	end
	
	if not patch then
		log('M', 'BeamMP - AddEventHandler', 'Adding new Event Handler to "' .. event_name .. '" from source "' .. source .. '"')
	else
		log('M', 'BeamMP - AddEventHandler', 'Patching Event Handler from "' .. event_name .. '" from source "' .. source .. '"')
	end
	
	table.insert(calls, {
		source = source,
		func = func
	})
end

--- Removes an event handler for the specified event name
-- @tparam string event_name - The name of the event
-- @tparam string name - The internal name (optional)
-- @usage RemoveEventHandler(`<name>`, `<function>`)
function RemoveEventHandler(event_name, name)
	if event_name == nil or type(event_name) ~= "string" or (type(event_name) == "string" and event_name:len() == 0) then
		log('E', 'BeamMP - RemoveEventHandler', 'Error, given event_name is not a valid string name')
		return
	end
	local source = name or debug.getinfo(2).source
	if source == nil or source:len() == 0 then
		log('E', 'BeamMP - RemoveEventHandler', 'Error, invalid source of event')
		return
	end
	
	local calls = eventTriggers[event_name]
	if not calls then
		log('E', 'BeamMP - RemoveEventHandler', '"' .. event_name .. '" is unknown')
		return
	end
	
	for index, call in ipairs(calls) do
		if call.source == source then
			local max = #calls
			calls[index] = calls[max]
			calls[max] = nil
			log('I', 'BeamMP - RemoveEventHandler', '"' .. event_name .. '" has been removed from source "' .. source .. '"')
			return
		end
	end
	log('E', 'BeamMP - RemoveEventHandler', '"' .. event_name .. '" is unknown from source "' .. source .. '"')
end

-- -----------------------------------------------------------------------------
-- Keypress handling
-- -----------------------------------------------------------------------------

--- Sets a function to be called when the specified key is pressed.
-- @tparam string keyname - The name of the key
-- @tparam function f - The function to be called when the key is pressed
-- @usage onKeyPressed("NUMPAD1", `<function>`)
function onKeyPressed(keyname, f)
	addKeyEventListener(keyname, f, 'down')
end

--- Sets a function to be called when the specified key is released.
-- @tparam string keyname - The name of the key
-- @tparam function f - The function to be called when the key is released
-- @usage onKeyPressed("NUMPAD1", `<function>`)
function onKeyReleased(keyname, f)
	addKeyEventListener(keyname, f, 'up')
end

--- Adds a key event listener for the specified key and function.
-- @tparam string keyname - The name of the key
-- @tparam function f - The function to be called when the key event is triggered
-- @tparam string type - The type of key event ('down', 'up', or 'both')
-- @usage addKeyEventListener("NUMPAD1", `<function>`, "up")
function addKeyEventListener(keyname, f, type)
	f = f or function() end
	log('W','addKeyEventListener', "Adding a key event listener for key '"..keyname.."'")
	table.insert(keypressTriggers, {key = keyname, func = f, type = type or 'both'})
	table.insert(keysToPoll, keyname)

	be:queueAllObjectLua("if true then addKeyEventListener(".. serialize(keysToPoll) ..") end")
end

--- Handles the state change of a key.
-- @tparam string key - The name of the key
-- @tparam boolean state - The state of the key ('true' for pressed, 'false' for released)
-- @usage INTERNAL ONLY / GAME SPECIFIC
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

--- Returns the state of the specified key.
-- @tparam string key - The name of the key
-- @return boolean - The state of the key ('true' for pressed, 'false' for released)
-- @usage local state = getKeyState('NUMPAD1')
function getKeyState(key)
	return keyStates[key] or false
end

--- Handles the event when a vehicle is ready.
-- @tparam integer gameVehicleID - The ID of the game vehicle
-- @usage MPGameNetwork.onVehicleReady(`<game vehicle id>`)
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
	['V'] = function(params) MPInputsGE.handle(params) end, -- inputs and gears
	['W'] = function(params) MPElectricsGE.handle(params) end,
	['X'] = function(params) nodesGE.handle(params) end, -- currently disabled
	['Y'] = function(params) MPPowertrainGE.handle(params) end, -- powertrain related things like diff locks and transfercases
	['Z'] = function(params) positionGE.handle(params) end, -- position and velocity
	['O'] = function(params) MPVehicleGE.handle(params) end, -- all vehicle spawn, modification and delete events, couplers
	['P'] = function(params) MPConfig.setPlayerServerID(params) end,
	['J'] = function(params) MPUpdatesGE.onPlayerConnect() UI.showNotification(params,nil,"person_add") end, -- A player joined
	['L'] = function(params) playerLeft(params) end, -- A player left
	['S'] = function(params) sessionData(params) end, -- Update Session Data
	['E'] = function(params) handleEvents(params) end, -- Event For another Resource
	['T'] = function(params) quitMP(params) end, -- Player Kicked Event (old, doesn't contain reason)
	['K'] = function(params) quitMP(params) end, -- Player Kicked Event (new, contains reason)
	['C'] = function(params) UI.chatMessage(params) end, -- Chat Message Event
	['R'] = function(params) MPControllerGE.handle(params) end, -- Controller data
	['n'] = function(params) local category, icon, message = params:match("([^:]+):?(.-):(.+)") UI.showNotification(message, category, icon) end, -- Custom UI notification
	['D'] = function(params) spawnUiDialog(jsonDecode(params)) end, -- Custom UI Dialog
}


local heartbeatTimer = 0
local connectRetryTimer = 0

local recvState = {
	-- 'ready': ready to receive a new packet, data is contained within `data` if any
	-- 'partial': `partialData` contains data, we're missing `missing` bytes
	-- 'error': errorneous state
	state = 'ready',
	data = "",
	missing = 0,
}

--- Tries to receive data from the Launcher every tick from the gameengine and handles the launcher <-> game heartbeat.
-- @tparam integer dt delta time
-- @usage INTERNAL ONLY / GAME SPECIFIC
local function onUpdate(dt)
	--====================================================== DATA RECEIVE ======================================================
	if launcherConnected then
		if TCPLauncherSocket ~= nop then
			while(true) do
				recvState = MPNetworkHelpers.receive(TCPLauncherSocket, recvState)
				if recvState.state == 'error' then
					-- error! :(
					break
				end
				if recvState.state ~= 'ready' then
					-- full packet NOT received, retry
					break
				end
				if recvState.data == "" then
					break
				end

				local received = recvState.data

				if settings.getValue("showDebugOutput") == true then
					log('M', 'onUpdate', 'Receiving Data ('..#received..'): '..received)
				end

				-- break it up into code + data
				local code = string.sub(received, 1, 1)
				local data = string.sub(received, 2)
				HandleNetwork[code](data)

				if MPDebug then MPDebug.packetReceived(#received) end
			end
		end
	end
	if heartbeatTimer >= 1 and MPCoreNetwork.isMPSession() and launcherConnected then --TODO: something
		heartbeatTimer = 0
		M.send('A')
	end
	-- retry proxy connection while handshake is still completing
	if isConnecting and not launcherConnected and TCPLauncherSocket then
		connectRetryTimer = connectRetryTimer + dt
		if connectRetryTimer >= 0.25 then
			connectRetryTimer = 0
			M.send('A')
		end
	end
end


--- Return whether the launcher is connected to the game or not.
-- @treturn[1] boolean Return the connection state of TCP with the launcher
-- @usage local connected = MPGameNetwork.isLauncherConnected()
local function isLauncherConnected()
	return launcherConnected
end

--- Return the launcher connection status.
-- @treturn[1] boolean Return the connection state of TCP with the launcher
-- @usage local status = MPGameNetwork.connectionStatus()
local function connectionStatus() --legacy, here because some mods use it
	return launcherConnected and 1 or 0
end


detectGlobalWrites() -- reenable global write notifications

local simTimeAuthority_set = simTimeAuthority.set
simTimeAuthority.set = function(...)
	if debug.getinfo(2, "Sl").source ~= "lua/ge/extensions/core/quickAccess.lua" or not MPCoreNetwork.isMPSession() then
		simTimeAuthority_set(...)
	end
end

local simTimeAuthority_pushPauseRequest = simTimeAuthority.pushPauseRequest
simTimeAuthority.pushPauseRequest = function(id)
	if MPCoreNetwork.isMPSession() and id ~= "menu.photomode" then
		return
	end
	simTimeAuthority_pushPauseRequest(id)
end

local simTimeAuthority_popPauseRequest = simTimeAuthority.popPauseRequest
simTimeAuthority.popPauseRequest = function(id)
	if MPCoreNetwork.isMPSession() and id ~= "menu.photomode" then
		return
	end
	simTimeAuthority_popPauseRequest(id)
end

--events
M.onUpdate = onUpdate
M.onKeyStateChanged = onKeyStateChanged

--functions
M.launcherConnected   = isLauncherConnected
M.connectionStatus    = connectionStatus --legacy
M.connectToLauncher   = connectToLauncher
M.disconnectLauncher  = disconnectLauncher
M.send                = sendData
M.CallEvent           = handleEvents
M.quitMP              = quitMP
M.spawnUiDialog       = spawnUiDialog

M.addKeyEventListener = addKeyEventListener -- takes: string keyName, function listenerFunction
M.getKeyState         = getKeyState         -- takes: string keyName
M.onVehicleReady      = onVehicleReady
M.onInit = function() setExtensionUnloadMode(M, "manual") end

return M
