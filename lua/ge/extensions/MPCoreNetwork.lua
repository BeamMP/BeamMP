--====================================================================================
-- All work by Titch2000, jojos38 & 20dka.
-- You have no permission to edit, redistribute or upload other than for the purposes of contributing. 
-- Contact BeamMP for more info!
--====================================================================================

--- MPCoreNetwork API - This is the main networking and starting point for the BeamMP Multiplayer mod. It handles the Initial TCP connection establishment with the Launcher.
--- Author of this documentation is Titch2000
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
local modVersion = "4.9.5" -- the mod version
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
-- AA============= VARIABLES =============AA




-- VV============= LAUNCHER RELATED =============VV

-- Sends data through a TCP socket or IPC to the launcher depending on if the launcher is V2 or V2.1 Networking.
-- If V2.1 Networking is available, it will be used, otherwise V2 Networking will be used.
-- @param s string containing the data to send to the launcher
-- @usage send('N:LO') -- Internal Usage
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

-- Connects to the V2 Launcher using V2 Networking.
-- @param silent boolean determines if the connection request should be done silently
-- @usage MPCoreNetwork.connectToLauncher(true)
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

--- Disconnect from the Launcher by closing the TCP connection.
--- @param boolean reconnect - Used to automatically reopen the connection with the launcher
--- @usage `MPCoreNetwork.disconnectLauncher(true)`
--- unused, for debug purposes
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



-- VV================ UI ================VV

--- Return the version of the Launcher. This is used within the servers page to show compatible servers. It is called from multiplayer.js
--- @return string Example: "2.1.0"
--- @usage `MPCoreNetwork.getLauncherVersion()`
local function getLauncherVersion()
		return "2.0" --launcherVersion
end

--- Return if the launcher is using an authenticated session
--- @return boolean loggedIn Returns true if the launcher is logged in
--- @usage `MPCoreNetwork.isLoggedIn()`
local function isLoggedIn()
		return loggedIn
end

--- Return whether the launcher is connected to the game or not.
--- @return boolean Return the connection state of TCP with the launcher
--- @usage `MPCoreNetwork.isLauncherConnected()`
local function isLauncherConnected()
		return launcherConnected
end

--- Attempt to log the user into the account: Registered | Guest
--- @param identifiers string Players identifers / credentials
--- @usage `MPCoreNetwork.login(<credentials>)`
local function login(identifiers)
		log('M', 'login', 'Attempting login...')
		identifiers = identifiers and jsonEncode(identifiers) or ""
		send('N:'..identifiers)
end

--- Tell the launcher to attempt to auto login using the local key file
--- @usage `MPCoreNetwork.autoLogin()`
local function autoLogin()
		send('Nc')
end

--- Tell the launcher to log the current user out. This also removes the local key file
--- @usage `MPCoreNetwork.logout()`
local function logout()
		log('M', 'logout', 'Attempting logout')
		send('N:LO')
		loggedIn = false
end


--- Send the server list and network stats such as player and server count to the game's CEF UI
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

--- Request the server list from the launcher which actually makes the request to the backend. It also calls sendBeamMPInfo() internally to send the data to the CEF UI
--- @param integer gameVehicleID
--- @return nil
--- @usage `MPCoreNetwork.requestServerList()`
local function requestServerList()
	if not launcherConnected then return end
	if isMpSession then
		log('W', 'requestServerList', 'Currently in MP Session! Using cached server list.') --TODO: add UI warning when cached server list is being displayed
		sendBeamMPInfo()
		return
	end
	send('B') -- Request server list
end

--- Return the current server list and stat data to the CEF UI
--- @usage `MPCoreNetwork.requestPlayers()`
--- @todo rename this to be more appropriate, something like requestUIData()
local function requestPlayers()
	--log('M', 'requestPlayers', 'Requesting players.')
	sendBeamMPInfo()
end
-- AA================ UI ================AA



-- VV============= SERVER RELATED =============VV

--- Set the mods string for the server that we are joining.
--- @param string Mods string in a comma seperated string
--- @usage `MPCoreNetwork.setMods(<mods>)`
local function setMods(receivedMods) -- receiving mods means that the client authenticated with the server successfully
	isMpSession = true
	isGoingMpSession = true
	MPModManager.setServerMods(receivedMods)
end


--- Return the current server information
--- @return table currentServer the current server information
--- @usage `MPCoreNetwork.getCurrentServer()
local function getCurrentServer()
	--dump(currentServer)
  return currentServer
end

--- Set the current servers information
--- @param string Server IP
--- @param string Server Port
--- @param string Server Name
--- @usage `MPCoreNetwork.setCurrentServer(<ip>, <port>, <name>)`
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

--- Tell the launcher to connect to the desired server over TCP. 
--- @param string Server IP
--- @param string Server Port
--- @param string Server Name
--- @usage `MPCoreNetwork.connectToServer(<ip>, <port>, <name>)`
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

--- Tell the game to load a map and start a freeroam session
--- @param string The map as a string
--- @usage `MPCoreNetwork.loadLevel(<map>)`
--- @todo This needs changing over to use the multiplayer_multiplayer gamemode rather than freeroam.
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

--- On Launcher account login success, this function is triggered to make the mod and game aware of the session
--- @param table login status
--- @usage This event is called from the network events and not script -- internal use
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


local returnToMenu = true

--- Tell the Lua and Launcher to close the active session and if wanted return them to the main menu too using the goBack boolean.
--- @param boolean goBack - Should the leaving of the server also return the user to the game main menu
--- @usage `MPCoreNetwork.leaveServer(true)` -- Returns the player to the main menu of the game
local function leaveServer(goBack)
	log('W', 'leaveServer', 'Reset Session Called! goBack: ' .. tostring(goBack))
	send('QS') -- Quit session, disconnecting MPCoreNetwork socket is not necessary
	extensions.hook('onServerLeave')
	isMpSession = false
	isGoingMpSession = false
	loadMods = false
	currentServer = nil
	status = "" -- Reset status
	UI.updateLoading("")
	MPGameNetwork.disconnectLauncher()
	MPVehicleGE.onDisconnect()
	local callback = nop
	if not settings.getValue("disableLuaReload") then callback = function() MPModManager.reloadLuaReloadWithDelay() end end
	if goBack then endActiveGameMode(callback) end
end

--- Get if we are in a multiplayer session
--- @treturn boolean If in session then true otherwise false
--- @usage `MPCoreNetwork.isMPSession()`
local function isMPSession()
	return isMpSession
end

--- Get if we are loading into a multiplayer session
--- @treturn boolean If loading a multiplayer session then true otherwise false
--- @usage `MPCoreNetwork.isGoingMPSession()`
local function isGoingMPSession()
	return isGoingMpSession
end

-- AA============= OTHERS =============AA

--- Ask the launcher for what map we need the game to load. This value is provided by the server
--- @usage `MPCoreNetwork.requestMap()`
local function requestMap()
	log('M', 'requestMap', 'Requesting map!')
	send('M') -- request map string from launcher 
	status = "LoadingMap"
	loadMods = false
end

--- Handle U network message events. These events relate directly to the CEF User Interface
--- @param params string The network message
--- @usage `handleU(<network message>)`
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
--- @param params string The parameters received for auto join confirmation.
--- @usage `MPCoreNetwork.promptAutoJoin(...)`
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
	['Z'] = function(params) launcherVersion = params; end,
}

local pingTimer = 0
local onUpdateTimer = 0
local updateUiTimer = 0
local heartbeatTimer = 0
local reconnectTimer = 0
local reconnectAttempt = 0


--- onUpdate is called each game frame by the games engine. It is used to run scripts in a loop such as getting data from the network buffer.
--- @param dt integer delta time
--- @usage INTERNAL ONLY / GAME SPECIFIC
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
		core_gamestate.setGameState('multiplayer', 'multiplayer', 'multiplayer')
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

--- This event is called when it is required to end the current game session level.
--- @usage `extensions.hook('onClientStartMission')`
local function onClientEndMission(mission)
	log('W', 'onClientEndMission', 'isGoingMpSession: '..tostring(isGoingMpSession))
	log('W', 'onClientEndMission', 'isMpSession: '..tostring(isMpSession))
	if not isGoingMpSession then -- leaves server when loading into another freeroam map from an MP sesison
		leaveServer(false)
	end
end

--- This function is here to check what the UI state is and to help keep the UI moving to the correct location such as the mainmenu
--- @param curUIState string the current UI state
--- @param prevUIState string the previous UI state
--- @usage `onUiChangedState(<current>, <previous>)`
local function onUiChangedState (curUIState, prevUIState)
	if curUIState == 'menu' and getMissionFilename() == "" then -- required due to game bug that happens if UI is reloaded on the main menu
		guihooks.trigger('ChangeState', 'menu.mainmenu')
	end
end

--- This function is used to wrap up data into the game memory rather than dedicated memory space for this mod. This allows for semi persistent storage even between reloads of the mod / Lua environment
--- @usage INTERNAL ONLY / GAME SPECIFIC
local function onSerialize()
	return {currentServer = currentServer,
			isMpSession = isMpSession}
end

--- This function is used to unwrap data into the lua memory rather than being a clean state for this mod. This allows for us to recover information between reloads of the mod / Lua environment
--- @usage INTERNAL ONLY / GAME SPECIFIC
local function onDeserialized(data)
	log('M', 'onDeserialized', dumps(data))

	currentServer = data and data.currentServer or nil
	isMpSession = data and data.isMpSession

	if isMpSession and currentServer then
		log('I', 'onDeserialized', 'reconnecting')
	end
end

--- LEGACY this function is called by the games mod loading system. The contents are legacy at this point.
--- @usage INTERNAL ONLY / GAME SPECIFIC
--- @todo Review and Remove
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


-- TODO: finish all this

return M
