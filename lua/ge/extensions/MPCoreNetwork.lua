-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- MPCoreNetwork API. Handles Main Launcher <-> Game Network. Version Check, Server list transfer, login, connect to X server, quiting a server etc.
--- Author of this documentation is Titch
--- @module MPCoreNetwork
--- @usage connectToLauncher() -- internal access
--- @usage MPCoreNetwork.connectToLauncher() -- external access


local M = {}


-- VV============= VARIABLES =============VV
-- launcher
local TCPLauncherSocket = nop -- Launcher socket
local socket = require('socket')
local launcherConnected = false
local isConnecting = false
local launcherVersion = "" -- used only for the server list
local modVersion = "4.11.0" -- the mod version
-- server

local serverList -- server list JSON
local currentServer = nil -- Table containing the current server IP, port and name
local isMpSession = false
local isGoingMpSession = false
local status = "" -- "", "waitingForResources", "LoadingResources", "LoadingMap", "LoadingMapNow", "Playing"

-- auth

local loggedIn = false

-- event functions

local onLauncherConnected = nop
local runPostJoin = nop
local originalFreeroamOnPlayerCameraReady

local loadMods = false -- gets set to true when mods should get loaded
--[[
Z  -> The client asks the launcher its version
B  -> The client asks the launcher for the servers list
QG -> The client tells the launcher that it's is leaving
C  -> The client asks for the server's mods
--]]

-- timer variables
local pingTimer = 0
local onUpdateTimer = 0
local updateUiTimer = 0
local heartbeatTimer = 0
local reconnectTimer = 0
local reconnectAttempt = 0

-- AA============= VARIABLES =============AA


-- VV============= LAUNCHER RELATED =============VV


--- Sends data through a TCP socket or IPC to the launcher depending on if the launcher is V2 or V2.1 Networking.
-- If V2.1 Networking is available, it will be used, otherwise V2 Networking will be used.
-- @param s string containing the data to send to the launcher
local function send(s)
	-- First check if we are V2.1 Networking or not
	if mp_core then
		mp_core(s)
		if not launcherConnected then launcherConnected = true isConnecting = false onLauncherConnected() end

		if not settings.getValue("showDebugOutput") then return end
		log('M', 'send', 'Sending Data ('..#s..'): '..s)
		return
	
	end
	-- Else we now will use the V2 Networking
	if TCPLauncherSocket == nop then return end

	local bytes, error, index = TCPLauncherSocket:send(#s..'>'..s)
	if error then
		isConnecting = false
		log('E', 'send', 'Socket error: '..error)
		if error == "closed" and launcherConnected then
			log('W', 'send', 'Lost launcher connection!')
			if launcherConnected then guihooks.trigger('LauncherConnectionLost') end
			launcherConnected = false
		elseif error == "Socket is not connected" then

		else
			log('E', 'send', 'Stopped at index: '..index..' while trying to send '..#s..' bytes of data.')
		end
	else
		if not launcherConnected then launcherConnected = true isConnecting = false onLauncherConnected() end

		if not settings.getValue("showDebugOutput") then return end
		log('M', 'send', 'Sending Data ('..bytes..'): '..s)
	end
end

--- Connects to the Launcher.
-- @param silent boolean determines if the connection request should be done silently
local function connectToLauncher(silent)
	--log('M', 'connectToLauncher', debug.traceback())
	-- Check if we are using V2.1
	if mp_core then
		send('A') -- immediately heartbeat to check if connection was established
		log('W', 'connectToLauncher', 'Launcher already connected!')
		guihooks.trigger('onLauncherConnected')
		return
	end

	-- Okay we are not using V2.1, lets do the V2 stuff
	isConnecting = true
	if not silent then log('W', 'connectToLauncher', "connectToLauncher called! Current connection status: "..tostring(launcherConnected)) end
	if not launcherConnected and not mp_core then
		TCPLauncherSocket = socket.tcp()
		TCPLauncherSocket:setoption("keepalive", true) -- Keepalive to avoid connection closing too quickly
		TCPLauncherSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
		TCPLauncherSocket:connect(settings.getValue("launcherIp", '127.0.0.1'), settings.getValue("launcherPort", 4444))
		send('A') -- immediately heartbeat to check if connection was established
	else
		log('W', 'connectToLauncher', 'Launcher already connected!')
		guihooks.trigger('onLauncherConnected')
	end
end

--- Disconnect from the Launcher --unused, for debug purposes
-- @param reconnect boolean Should Lua reconnect to the launcher after disconnecting?
-- @usage MPCoreNetwork.disconnectLauncher(true)
-- @return nil
local function disconnectLauncher(reconnect) 
	log('W', 'disconnectLauncher', 'Launcher disconnect called! reconnect: '..tostring(reconnect))
	if launcherConnected then
		log('W', 'disconnectLauncher', "Disconnecting from launcher")
		TCPLauncherSocket:close()
		launcherConnected = false
		isGoingMpSession = false
	end
	if reconnect then connectToLauncher() end
end


-- This is called everytime we receive a heartbeat from the launcher
local function receiveLauncherHeartbeat() -- TODO: add some purpose to this function or remove it

end
-- AA============= LAUNCHER RELATED =============AA



-- ================ UI ================
--- Called from multiplayer.js UI
-- Returns the version of the launcher.
-- @return string version The version of the launcher.
local function getLauncherVersion()
	return "2.0" --launcherVersion
end

--- Returns true or false if the user is logged in.
-- @return boolean loggedIn True if the user is logged in, false otherwise.
local function isLoggedIn()
	return loggedIn
end

--- Returns true or false if the launcher is connected.
-- @return boolean launcherConnected True if the launcher is connected, false otherwise.
local function isLauncherConnected()
	return launcherConnected
end

--- Logs in the user with the given identifiers by sending the request to the launcher
-- @param identifiers table The identifiers used for login.
local function login(identifiers)
	log('M', 'login', 'Attempting login...')
	identifiers = identifiers and jsonEncode(identifiers) or ""
	send('N:'..identifiers)
end

--- Automatically logs in the user.
-- @usage autoLogin() -- Tells the launcher to attempt to auto authenticate with BeamMP Services
local function autoLogin()
	send('Nc')
end

--- Tells the launcher to log out the user.
-- @usage logout() -- Tells the launcher to logout from BeamMP Services
local function logout()
	log('M', 'logout', 'Attempting logout')
	send('N:LO')
	loggedIn = false
end

--- Sends the current player and server count plus the mod and launcher version to the CEF UI.
-- @usage MPCoreNetwork.sendBeamMPInfo()
local function sendBeamMPInfo()
	local servers = jsonDecode(serverList)
	if not servers or tableIsEmpty(servers) then return log('M', 'No server list.') end
	guihooks.trigger('onServerListReceived', servers) -- server list
	local p, s = 0, 0
	for _,server in pairs(servers) do
		p = p + server.players
		s = s + 1
	end
	-- send player and server values to front end.
	guihooks.trigger('BeamMPInfo', { -- <players> count on the bottom of the screen
		players = ''..p,
		servers = ''..s,
		beammpGameVer = ''..modVersion,
		beammpLauncherVer = ''..launcherVersion
	})
end

--- Request the server list data from the launcher.
-- @usage MPCoreNetwork.requestServerList()
local function requestServerList()
	if not launcherConnected then return end
	if isMpSession then
		log('W', 'requestServerList', 'Currently in MP Session! Using cached server list.') --TODO: add UI warning when cached server list is being displayed
		sendBeamMPInfo()
		return
	end
	send('B') -- Request server list
end

--- Request the UI counts and other metrics by calling `sendBeamMPInfo()`
-- @usage `MPCoreNetwork.requestPlayers()`
-- @see sendBeamMPInfo
local function requestPlayers()
	--log('M', 'requestPlayers', 'Requesting players.')
	sendBeamMPInfo()
end
-- AA================ UI ================AA



-- ============= SERVER RELATED =============
--- Set the mods for the server you are joining
-- @param receivedMods string The mods from the server in string form.
-- @usage setMods(`<modsstring>`)
local function setMods(receivedMods) -- receiving mods means that the client authenticated with the server successfully
	isMpSession = true
	isGoingMpSession = true
	MPModManager.setServerMods(receivedMods)
end

--- Returns the current server information
-- @return currentServer table
-- @usage MPCoreNetwork.getCurrentServer()
local function getCurrentServer()
	--dump(currentServer)
  return currentServer
end

--- Set the current server information for later use
-- @param ip string The IP/URL of the server
-- @param port number The Port of the server
-- @param name string The Name of the server (Used at the top of the screen when in session)
-- @usage MPCoreNetwork.setCurrentServer('localhost', 30814, 'Test Server')
local function setCurrentServer(ip, port, name)
	-- If the server is different then lets also clear the existing chat data as this does not always done on leaving
	if currentServer ~= nil then
		if currentServer.port ~= port and currentServer.ip ~= ip then
			print('Clearing Chat!')
			be:executeJS('localStorage.removeItem("chatMessages");')
		end
	else
		-- otherwise lets clear it again anyway for good measure as the server we are joining may not be the same server.
		be:executeJS('localStorage.removeItem("chatMessages");')
	end
	currentServer = {
		ip		   = ip,
		port	   = port,
		name	   = name
	}
end

-- Tell the launcher to open the connection to the server so the MPGameNetwork can connect to the launcher once ready. This starts the setup and download of mods and other session related data.
-- @param ip string The IP/URL of the server
-- @param port number The Port of the server
-- @param name string The Name of the server (Used at the top of the screen when in session)
-- @usage MPCoreNetwork.connectToServer('localhost', 30814, 'Test Server')
local function connectToServer(ip, port, name)
	if isMpSession then log('W', 'connectToServer', 'Already in an MP Session! Leaving server!') M.leaveServer() end

	if ip and port then -- Direct connect
		currentServer = nil
		setCurrentServer(ip, port, name)
	else
		log('E', 'connectToServer', 'IP and PORT are required for connecting to a server.')
		return
	end

	local ipString = currentServer.ip..':'..currentServer.port
	send('C'..ipString..'')

	log('M', 'connectToServer', "Connecting to server "..ipString)
	status = "waitingForResources"
	
	guihooks.trigger('clearChatHistory')
end

--- Parse the map file name into its loadable string form and return it.
--- @param string The Map file
--- @treturn string the maps misFilePath
--- @usage `MPCoreNetwork.parseMapName(<map>)`
--- @todo this needs finishing and using.
local function parseMapName(map) -- TODO: finish
	local mapName = string.lower(map)
	if string.match(mapName, '/(.*).mis') then
		mapName = string.match(mapName, '/(.*)/') or mapName
	end
	mapName = mapName:gsub(' ', '_')
	mapName = mapName:gsub('levels/', '')
	mapName = mapName:gsub('info.json', '')
	mapName = mapName:gsub('.mis', '')
	mapName = mapName:gsub('/', '')
	for _,v in pairs(core_levels.getList()) do
		if string.match(string.lower(v.misFilePath), map) or string.match(string.lower(v.misFilePath), mapName) then
			log('M', 'loadLevel', 'Found match!')
			log('M', 'loadLevel', mapName..' matches '..v.misFilePath)
			return v.misFilePath
		end
	end
end

--- Load the desired map/level by name.
-- @param map string The Map String
-- @usage MPCoreNetwork.loadLevel('/levels/gridmap_v2/info.json')
local function loadLevel(map)
	if getMissionFilename() ~= "" then log("W","loadLevel", "REMOVING ALL VEHICLES") core_vehicles.removeAll() end -- remove old vehicles if joining a server with the same map

	log("W","loadLevel", "loading map " ..map)
	log('W', 'loadLevel', 'Loading level from MPCoreNetwork -> freeroam_freeroam.startFreeroam')

	spawn.preventPlayerSpawning = true -- don't spawn default vehicle when joining server

	currentServer.map = map

	--local parsedMapName = parseMapName(map)

	if freeroam_freeroam.onPlayerCameraReady ~= nop then -- temp fix for traffic spawning in MP
		originalFreeroamOnPlayerCameraReady = freeroam_freeroam.onPlayerCameraReady
		freeroam_freeroam.onPlayerCameraReady = nop
	end

	if getMissionFilename() == map then --or string.match(getMissionFilename(), parsedMapName) then
		log('W', 'loadLevel', 'Requested map matches current map, rejoining')
		runPostJoin()
		return
	end
	if not core_levels.expandMissionFileName(map) then --and not parsedMapName then
		UI.updateLoading("lMap "..map.." not found. Check your server config.")
		status = ""
		M.leaveServer()
		return
	else
		log('W', 'loadLevel', 'not core_levels.expandMissionFileName')
		--map = parsedMapName
	end

	freeroam_freeroam.startFreeroam(map)
	status = "LoadingMapNow"
end

-- VV============= OTHERS =============VV

--- Handles the login result received from the launcher.
-- @param params string The JSON-encoded login results.
local function loginReceived(params)
	--log('M', 'loginReceived', 'Logging result received')
	local result = jsonDecode(params)
	if (result.success == true or result.Auth == 1) then
		log('M', 'loginReceived', 'Login successful.')
		loggedIn = true
		guihooks.trigger('LoggedIn', result.message or '')
	else
		log('M', 'loginReceived', 'Login failed.')
		loggedIn = false
		guihooks.trigger('LoginError', result.message or '')
	end
end


--- Leaves the server and performs necessary cleanup.
-- @param goBack boolean Whether to go back to the previous screen after leaving the server.
-- @usage MPCoreNetwork.leaveServer(true)
local function leaveServer(goBack)
	log('W', 'leaveServer', 'Reset Session Called! goBack: ' .. tostring(goBack))
	send('QS') -- Quit session, disconnecting MPCoreNetwork socket is not necessary
	extensions.hook('onServerLeave')
	isMpSession = false
	isGoingMpSession = false
	loadMods = false
	currentServer = nil
	status = "" -- Reset status
	updateUiTimer = 0
	UI.updateLoading("")
	MPGameNetwork.disconnectLauncher()
	MPVehicleGE.onDisconnect()
	local callback = nop
	--if not settings.getValue("disableLuaReload") then callback = function() MPModManager.reloadLuaReloadWithDelay() end end
	callback = function() MPModManager.reloadLuaReloadWithDelay() end -- force lua reload every time until a proper fix is introduced
	if goBack then endActiveGameMode(callback) end
end

--- Informs the Launcher that we do not want to download the mods from this server.
-- @usage MPCoreNetwork.rejectModDownload()
local function rejectModDownload()
	if status == "waitingForResources" then
		send('WN') -- Inform the Launcher that we decline
		isMpSession = false
		isGoingMpSession = false
		loadMods = false
		currentServer = nil
		status = "" -- Reset status
		updateUiTimer = 0
		UI.updateLoading("")
	end
end

--- Informs the Launcher that we do not want to download the mods from this server.
-- @usage MPCoreNetwork.approveModDownload()
local function approveModDownload()
	if status == "waitingForResources" then
		send('WY') -- Inform the Launcher that we accept the risk
	end
end


--- Returns if the current session is a multiplayer session / if we expect to be in one.
-- @return boolean isMpSession True if it is a multiplayer session, false otherwise.
-- @usage if MPCoreNetwork.isMPSession() then `code` end
local function isMPSession()
	return isMpSession
end

--- Returns if the game is currently transitioning to a multiplayer session.
-- @return boolean isGoingMpSession True if transitioning to a multiplayer session, false otherwise.
-- @usage if MPCoreNetwork.isGoingMPSession() then `code` end
local function isGoingMPSession()
	return isGoingMpSession
end

-- AA============= OTHERS =============AA

--- Requests the map from the launcher
-- @usage MPCoreNetwork.requestMap()
local function requestMap()
	log('M', 'requestMap', 'Requesting map!')
	send('M') -- request map string from launcher 
	status = "LoadingMap"
	loadMods = false
end

--- Handles the update of the loading UI and performs necessary actions based on the received parameters.
-- @param params string The parameters received for updating the loading UI.
-- @usage MPCoreNetwork.handleU('lstart')
local function handleU(params)
	UI.updateLoading(params)
	local code = string.sub(params, 1, 1)
	local data = string.sub(params, 2)
	if code == "l" then
		if data == "start" then
		end
		if string.match(data, 'Loading') then send('R'..math.random()) end --get the launcher to copy all the mods without loading them one by one
		if data == "done" and status == "LoadingResources" and not loadMods then --load all the mods once they have been copied over
			loadMods = true
			MPModManager.loadServerMods()
		end
		--if string.sub(data, 1, 17) == "Connection Failed" then
		--	leaveServer(false) -- reset session variables
		--end
	elseif code == "p" and isMpSession then
		UI.setPing(data.."")
		positionGE.setPing(data)
	end
end

--- Prompts the user for auto join confirmation.
-- @param params string The parameters received for auto join confirmation.
-- @usage MPCoreNetwork.promptAutoJoin(`...`)
local function promptAutoJoin(params)
	UI.promptAutoJoinConfirmation(params)
end

-- VV============= EVENTS =============VV

--- Handle network message events.
--- @param code string The network message code
--- @param params string The network message content/parameters
--- @usage `HandleNetwork[<code>]('<params>')`
local HandleNetwork = {
	['A'] = function(params) receiveLauncherHeartbeat() end, -- Launcher heartbeat
	['B'] = function(params) serverList = params; sendBeamMPInfo() end, -- Server list received
	['J'] = function(params) promptAutoJoin(params) end, -- Automatic Server Joining
	['L'] = function(params) setMods(params) status = "LoadingResources" end, --received after sending 'C' packet
	['M'] = function(params) log('W', 'HandleNetwork', 'Received Map! '..params) loadLevel(params) end,
	['N'] = function(params) loginReceived(params) end,
	['U'] = function(params) handleU(params) end, -- Loading into server UI, handles loading mods, pre-join kick messages and ping
	['W'] = function(params) if params == 'MODS_FOUND' and settings.getValue("skipModSecurityWarning", false) == false then guihooks.trigger('DownloadSecurityPrompt', params) else send('WY') end end,
	['Z'] = function(params) launcherVersion = params; end,
}

--- onUpdate is a game eventloop function. It is called each frame by the game engine.
-- This is the main processing thread of BeamMP in the game
-- @param dt float
local function onUpdate(dt)
	pingTimer = pingTimer + dt
	reconnectTimer = reconnectTimer + dt
	if status == "LoadingResources" then
		updateUiTimer = updateUiTimer + dt
	end
	if not mp_core then -- This is not required in V2.1
		heartbeatTimer = heartbeatTimer + dt
	end
	--====================================================== DATA RECEIVE ======================================================
	if launcherConnected then
		if mp_core then
			while (true) do
				local msg = mp_try_pop()
				if msg then
					local code = string.sub(msg, 1, 1)
					local received = string.sub(msg, 2)
					if settings.getValue("showDebugOutput") == true and code == 'C' then
						log('M', 'onUpdate', 'Receiving Data ('..#received..'): '..received)
					end
			

					-- break it up into code + data
					local c = string.sub(received, 1, 1)
					local d = string.sub(received, 2)
					if code == 'C' then
						HandleNetwork[c](d)
					elseif code == 'G' and MPGameNetwork.launcherConnected() then
						MPGameNetwork.receiveIPCGameData(c, d)
					end
			
					if MPDebug then MPDebug.packetReceived(#received) end
				else
					break
				end
			end
		end

		if TCPLauncherSocket ~= nop then
			while(true) do
				local received, stat, partial = TCPLauncherSocket:receive()
				if not received or received == "" then
					break
				end
				if settings.getValue("showDebugOutput") then -- TODO: add option to filter out heartbeat packets
					log('M', 'onUpdate', 'Receiving Data ('..#received..'): '..received)
				end

				-- break it up into code + data
				local code = string.sub(received, 1, 1)
				local data = string.sub(received, 2)
				HandleNetwork[code](data)
			end
		end
		--================================ SECONDS TIMER ================================
		if heartbeatTimer >= 1 then
			heartbeatTimer = 0
			send('A') -- Launcher heartbeat
		end
		if updateUiTimer >= 0.1 and status == "LoadingResources" then
			updateUiTimer = 0
			send('Ul') -- Ask the launcher for a loading screen update
		end
		if MPGameNetwork and MPGameNetwork.launcherConnected() and pingTimer >= 1 and isMPSession() then
			pingTimer = 0
			send('Up')
		end
	else
		if reconnectAttempt < 10 and reconnectTimer >= 2 and not isConnecting then
			reconnectAttempt = reconnectAttempt + 1
			reconnectTimer = 0
			connectToLauncher(true) --TODO: add counter and stop attempting after enough failed attempts
		end
	end
end

-- EVENTS

--- onLauncherConnected is an event which is called by internal scripts. This one is called when connection to the launcher is established
--- @usage INTERNAL ONLY / GAME SPECIFIC
onLauncherConnected = function()
	reconnectAttempt = 0
	log('W', 'onLauncherConnected', 'onLauncherConnected')
	send('Z') -- request launcher version
	requestServerList()
	extensions.hook('onLauncherConnected')
	guihooks.trigger('onLauncherConnected')
	autoLogin()
	if isMpSession and currentServer then
		connectToServer(currentServer.ip, currentServer.port, currentServer.name)
	end
end

--- runPostJoin is an event which is called by internal scripts. This one is called when the game has finishing loading into a map as part of loading into a session
--- @usage INTERNAL ONLY / GAME SPECIFIC
runPostJoin = function() -- gets called once loaded into a map
	log('W', 'runPostJoin', 'isGoingMpSession: '..tostring(isGoingMpSession))
	log('W', 'runPostJoin', 'isMpSession: '..tostring(isMpSession))
	if freeroam_freeroam.onPlayerCameraReady == nop and originalFreeroamOnPlayerCameraReady then -- restore function to original once already loaded in so it works if user switches to freeroam
		freeroam_freeroam.onPlayerCameraReady = originalFreeroamOnPlayerCameraReady
	end
	if isMpSession and isGoingMpSession then
		extensions.hook('runPostJoin')
		spawn.preventPlayerSpawning = false -- re-enable spawning of default vehicle so it gets spawned if the user switches to freeroam
		MPGameNetwork.connectToLauncher()
		log('W', 'runPostJoin', 'isGoingMpSession = false')
		isGoingMpSession = false
		--core_gamestate.setGameState('multiplayer', 'multiplayer', 'multiplayer')
		status = "Playing"
		guihooks.trigger('onServerJoined')
		if mp_core then
			send('A')
		end
	end
end

--- This event is called as part of the games level loading process. It also works as the start event which can be paired with the end event onClientEndMission
--- @usage `extensions.hook('onClientStartMission')`
local function onClientStartMission()
	if isMpSession and isGoingMpSession then runPostJoin() end
end

--- Executes when the user or mod ends a mission/session (map) .
-- @param mission table The mission object.
local function onClientEndMission(mission)
	log('W', 'onClientEndMission', 'isGoingMpSession: '..tostring(isGoingMpSession))
	log('W', 'onClientEndMission', 'isMpSession: '..tostring(isMpSession))
	if not isGoingMpSession then -- leaves server when loading into another freeroam map from an MP sesison
		leaveServer(false)
	end
end

--- Executes when the UI state changes.
-- @param curUIState string The current UI state.
-- @param prevUIState string The previous UI state.
local function onUiChangedState (curUIState, prevUIState)
	if curUIState == 'menu' and getMissionFilename() == "" then -- required due to game bug that happens if UI is reloaded on the main menu
		guihooks.trigger('ChangeState', 'menu.mainmenu')
	end
end

--- Serializes data for saving to be loaded on lua reload. Allows for lua state memory persistence between reloads
-- @return table The serialized data.
local function onSerialize()
	return {currentServer = currentServer,
			isMpSession = isMpSession}
end

--- Deserializes data after loading lua state. Allows for lua state memory persistence between reloads
-- @param data table The deserialized data.
local function onDeserialized(data)
	log('M', 'onDeserialized', dumps(data))

	currentServer = data and data.currentServer or nil
	isMpSession = data and data.isMpSession

	if isMpSession and currentServer then
		log('I', 'onDeserialized', 'reconnecting')
	end
end

--- Triggered by BeamNG when the lua mod is loaded by the modmanager system.
-- We use this to load our UI info and connect to the launcher
local function onExtensionLoaded()
	if mp_core then
		onLauncherConnected()
	end
	if not mp_core then
		connectToLauncher(true)
	end
	if FS:fileExists('settings/BeamMP/ui_info.json') then --TODO: remove this after a while
		FS:removeFile('settings/BeamMP/ui_info.json')
	end
	reloadUI() -- required to show modified mainmenu
end

-- TODO: remove functions that shouldnt be public
-- launcher
M.connectToLauncher    = connectToLauncher
M.disconnectLauncher   = disconnectLauncher
M.isLauncherConnected  = isLauncherConnected
M.getLauncherVersion   = getLauncherVersion
-- security
M.rejectModDownload    = rejectModDownload
M.approveModDownload   = approveModDownload
-- auth
M.login                = login
M.autoLogin            = autoLogin
M.logout               = logout
M.isLoggedIn           = isLoggedIn
-- events
M.onUiChangedState     = onUiChangedState
M.onExtensionLoaded    = onExtensionLoaded
M.onUpdate             = onUpdate
M.onClientEndMission   = onClientEndMission
M.onClientStartMission = onClientStartMission
-- UI
M.sendBeamMPInfo       = sendBeamMPInfo
M.requestPlayers       = requestPlayers
M.requestServerList    = requestServerList
-- server
M.connectToServer      = connectToServer
M.leaveServer          = leaveServer
M.getCurrentServer     = getCurrentServer
M.isMPSession          = isMPSession
M.isGoingMPSession     = isGoingMPSession

M.onSerialize          = onSerialize
M.onDeserialized       = onDeserialized

M.requestMap           = requestMap
M.send                 = send
M.onInit = function() setExtensionUnloadMode(M, "manual") end

-- TODO: finish all this

return M
