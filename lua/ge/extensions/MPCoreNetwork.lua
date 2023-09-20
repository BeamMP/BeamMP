--====================================================================================
-- All work by Titch2000, jojos38 & 20dka.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}



-- ============= VARIABLES =============
-- launcher
local TCPLauncherSocket = nop -- Launcher socket
local socket = require('socket')
local launcherConnected = false
local isConnecting = false
local launcherVersion = "" -- used only for the server list
local modVersion = "4.9.3" -- the mod version
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
-- ============= VARIABLES =============



-- ============= LAUNCHER RELATED =============

-- Sends data through a TCP socket or IPC to the launcher depending on if the launcher is V2 or V2.1 Networking.
-- If V2.1 Networking is available, it will be used, otherwise V2 Networking will be used.
-- @param s string containing the data to send to the launcher
local function send(s)
	-- First check if we are V2.1 Networking or not
	if MP then
		MP.Core(s)
		if not launcherConnected then launcherConnected = true isConnecting = false onLauncherConnected() end

		if not settings.getValue("showDebugOutput") then return end
		log('M', 'send', 'Sending Data ('..#s..'): '..s)
		return
	
	end
	-- Else we now will use the V2 Networking
	if not TCPLauncherSocket then return end

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
local function connectToLauncher(silent)
	--log('M', 'connectToLauncher', debug.traceback())
	-- Check if we are using V2.1
	if MP then
		send('A') -- immediately heartbeat to check if connection was established
		log('W', 'connectToLauncher', 'Launcher already connected!')
		guihooks.trigger('onLauncherConnected')
		return
	end

	-- Okay we are not using V2.1, lets do the V2 stuff
	isConnecting = true
	if not silent then log('W', 'connectToLauncher', "connectToLauncher called! Current connection status: "..tostring(launcherConnected)) end
	if not launcherConnected and not MP then
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

local function disconnectLauncher(reconnect) --unused, for debug purposes
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
-- ============= LAUNCHER RELATED =============



-- ================ UI ================
-- Called from multiplayer.js UI
local function getLauncherVersion()
	return "2.0" --launcherVersion
end
local function isLoggedIn()
	return loggedIn
end
local function isLauncherConnected()
	return launcherConnected
end
local function login(identifiers)
	log('M', 'login', 'Attempting login...')
	identifiers = identifiers and jsonEncode(identifiers) or ""
	send('N:'..identifiers)
end
local function autoLogin()
	send('Nc')
end
local function logout()
	log('M', 'logout', 'Attempting logout')
	send('N:LO')
	loggedIn = false
end


-- sends the current player and server count plus the mod and launcher version.
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

local function requestServerList()
	if not launcherConnected then return end
	if isMpSession then
		log('W', 'requestServerList', 'Currently in MP Session! Using cached server list.') --TODO: add UI warning when cached server list is being displayed
		sendBeamMPInfo()
		return
	end
	send('B') -- Request server list
end

local function requestPlayers()
	--log('M', 'requestPlayers', 'Requesting players.')
	sendBeamMPInfo()
end
-- ================ UI ================



-- ============= SERVER RELATED =============
local function setMods(receivedMods) -- receiving mods means that the client authenticated with the server successfully
	isMpSession = true
	isGoingMpSession = true
	MPModManager.setServerMods(receivedMods)
end

local function getCurrentServer()
	--dump(currentServer)
  return currentServer
end

local function setCurrentServer(ip, port, name)
	currentServer = {
		ip		   = ip,
		port	   = port,
		name	   = name
	}
end

-- Tell the launcher to open the connection to the server so the MPMPGameNetwork can connect to the launcher once ready
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
end

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

-- ============= OTHERS =============

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


local function isMPSession()
	return isMpSession
end

local function isGoingMPSession()
	return isGoingMpSession
end

-- ============= OTHERS =============
local function requestMap()
	log('M', 'requestMap', 'Requesting map!')
	send('M') -- request map string from launcher 
	status = "LoadingMap"
	loadMods = false
end

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

local function promptAutoJoin(params)
	UI.promptAutoJoinConfirmation(params)
end

-- ============= EVENTS =============
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

local function onUpdate(dt)
	pingTimer = pingTimer + dt
	reconnectTimer = reconnectTimer + dt
	if status == "LoadingResources" then
		updateUiTimer = updateUiTimer + dt
	end
	if not MP then -- This is not required in V2.1
		heartbeatTimer = heartbeatTimer + dt
	end
	--====================================================== DATA RECEIVE ======================================================
	if launcherConnected then
		if MP then
			while (true) do
				local msg = MP:try_pop()
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
		if MP then
			send('A')
		end
	end
end

local function onClientStartMission()
	if isMpSession and isGoingMpSession then runPostJoin() end
end

local function onClientEndMission(mission)
	log('W', 'onClientEndMission', 'isGoingMpSession: '..tostring(isGoingMpSession))
	log('W', 'onClientEndMission', 'isMpSession: '..tostring(isMpSession))
	if not isGoingMpSession then -- leaves server when loading into another freeroam map from an MP sesison
		leaveServer(false)
	end
end

local function onUiChangedState (curUIState, prevUIState)
	if curUIState == 'menu' and getMissionFilename() == "" then -- required due to game bug that happens if UI is reloaded on the main menu
		guihooks.trigger('ChangeState', 'menu.mainmenu')
	end
end

local function onSerialize()
	return {currentServer = currentServer,
			isMpSession = isMpSession}
end
local function onDeserialized(data)
	log('M', 'onDeserialized', dumps(data))

	currentServer = data and data.currentServer or nil
	isMpSession = data and data.isMpSession

	if isMpSession and currentServer then
		log('I', 'onDeserialized', 'reconnecting')
	end
end

local function onExtensionLoaded()
	if MP then
		onLauncherConnected()
	end
	if not MP then
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
M.send = send


-- TODO: finish all this

return M
