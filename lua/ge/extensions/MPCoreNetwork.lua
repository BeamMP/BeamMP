--====================================================================================
-- All work by Titch2000, jojos38 & 20dka.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading MPCoreNetwork...")



-- ============= VARIABLES =============
local TCPLauncherSocket -- Launcher socket
local currentServer = {} -- Table containing server IP, port and name
local serverList -- server list JSON
local launcherConnected = false
local launcherConnectionTimer = 0
local status = "" -- "", "LoadingResources", "LoadingMap", "LoadingMapNow", "Playing"
local launcherVersion = "" -- used only for the server list
local loggedIn = false
local currentModHasLoaded = false
local isMpSession = false
local isGoingMpSession = false
local onLauncherConnected = nop
local runPostJoin = nop
local socket = require('socket')
--[[
Z  -> The client asks the launcher its version
B  -> The client asks the launcher for the servers list
QG -> The client tells the launcher that it's is leaving
C  -> The client asks for the server's mods
--]]
-- ============= VARIABLES =============



-- ============= LAUNCHER RELATED =============
local function send(s)
	local r = TCPLauncherSocket:send(string.len(s)..'>'..s)

	if not r and not launcherConnected then log('E', 'send', 'Launcher not connected!') return end --TODO: Improve this mess
	if not r and launcherConnected then launcherConnected = false log('W', 'send', 'Lost launcher connection!') return end
	if not launcherConnected then launcherConnected = true onLauncherConnected() end

	if not settings.getValue("showDebugOutput") then return end
	print('[MPCoreNetwork] Sending Data ('..r..'): '..s)
end

local function connectToLauncher(silent) -- TODO: proper reconnecting system
	if not silent then log('W', 'connectToLauncher', "connectToLauncher called! Current connection status: "..tostring(launcherConnected)) end
	if not launcherConnected then
		TCPLauncherSocket = socket.tcp()
		TCPLauncherSocket:setoption("keepalive", true) -- Keepalive to avoid connection closing too quickly
		TCPLauncherSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
		TCPLauncherSocket:connect((settings.getValue("launcherIp") or '127.0.0.1'), (settings.getValue("launcherPort") or 4444))
		send('A') -- immediately heartbeat to check if connection was established
	else
		log('W', 'connectToLauncher', 'Launcher already connected!')
	end
end

local function disconnectLauncher(reconnect)
	log('W', 'disconnectLauncher', 'Launcher disconnect called! reconnect: '..tostring(reconnect))
	if launcherConnected then
		log('W', 'disconnectLauncher', "Disconnecting from launcher")
		TCPLauncherSocket:close()
		launcherConnected = false
		log('W', 'disconnectLauncher', 'isGoingMpSession = false')
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
	return launcherVersion
end
local function isLoggedIn()
	return loggedIn
end
local function isLauncherConnected()
	return launcherConnected
end
local function login(identifiers)
	log('M', 'login', 'Attempting login...')
	if not identifiers then identifiers = "" else identifiers = jsonEncode(identifiers) end -- guest login fix
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


-- sends the current player and server count.
local function sendBeamMPInfo()
	local servers = jsonDecode(serverList)
	if not servers or tableIsEmpty(servers) then return log('E', 'Failed to retrieve server list.') end
	guihooks.trigger('onServersReceived', servers) -- server list
	local p, s = 0, 0
	for _,server in pairs(servers) do
		p = p + server.players
		s = s + 1
	end
	-- send player and server values to front end.
	guihooks.trigger('BeamMPInfo', { -- <players> count on the bottom of the screen
		players = ''..p,
		servers = ''..s
	})
end

local function requestServerList()
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
local function setMods(modsString)
	--log('W', 'setMods', 'isGoingMpSession = true') --TODO: look into why this is called after being loaded into a map >:(
	--isGoingMpSession = true
	if modsString == "" then log('M', 'setMods', 'Received no mods.') return end
	log('W', 'setMods', modsString)
	local mods = {}
	if (modsString) then -- takes: mod1.zip;mod2.zip;mod3.zip, returns a table of mod1,mod2,mod3
		for mod in string.gmatch(modsString, "([^;]+)") do
			local modFileName = mod:gsub(".zip",""):gsub(";","")
			table.insert(mods, modFileName)
		end
	end

	MPModManager.setServerMods(mods) -- Setting the mods from the server
	log('W', 'setMods', dumps(mods))
end

local function getCurrentServer()
	--dump(currentServer)
  return currentServer
end

local function setCurrentServer(ip, port, modsString, name)
	currentServer = {
		ip		   = ip,
		port	   = port,
		name	   = name
	}
end

-- Tell the launcher to open the connection to the server so the MPMPGameNetwork can connect to the launcher once ready
local function connectToServer(ip, port, mods, name)
	if MPCoreNetwork.isMPSession() then log('W', 'connectToServer', 'Already in an MP Session! Leaving server!') MPCoreNetwork.leaveServer() end
	--if getMissionFilename() ~= "" then leaveServer(false) end
	if ip and port then -- Direct connect
		currentServer = nil
		setCurrentServer(ip, port, mods, name)
	else log('E', 'connectToServer', 'IP and PORT are required for connecting to a server.') return end

	local ipString = currentServer.ip..':'..currentServer.port
	send('C'..ipString..'')

	log('M', 'connectToServer', "Connecting to server "..ipString)
	status = "LoadingResources"
end

local function loadLevel(map) --TODO: all this, ensure this is only being run after all the mods have successfully loaded
	--if true then return end
	if getMissionFilename() ~= "" then core_vehicles.removeAll() end
	isMpSession = true
	isGoingMpSession = true
	log("W","loadLevel", "loading map " ..map)
	log('W', 'loadLevel', 'Loading level from MPCoreNetwork -> freeroam_freeroam.startFreeroam')

	spawn.preventPlayerSpawning = true -- don't spawn default vehicle when joining server

	if getMissionFilename() == map then
		runPostJoin() return
	end

	freeroam_freeroam.startFreeroam(map)
	status = "LoadingMapNow"

	currentServer.map = map
	--[[
	if getMissionFilename() == map then
		log('W', 'loadLevel', 'Requested map matches current map, rejoining')
		--set modlist to current mods
	else
		if not core_levels.expandMissionFileName(map) then
			UI.updateLoading("lMap "..map.." not found. Check your server config.")
			status = ""
			M.leaveServer()
			return
		else
			print('not core_levels.expandMissionFileName')
		end
	end

	status = "LoadingMapNow"

	currentServer.map = map

	if getMissionFilename() ~= map then
		print('LOADING LEVEL/MAP BY USING MPCORENETWORK -> freeroam_freeroam.startFreeroam')
		spawn.preventPlayerSpawning = true -- don't spawn default vehicle when joining server
		freeroam_freeroam.startFreeroam(map)
	else
		MPGameNetwork.disconnectLauncher()
		MPGameNetwork.connectToLauncher()
	end
	]]--

end
-- ============= SERVER RELATED =============


local function modLoaded(modname)
	if modname ~= "beammp" then -- We don't want to check beammp mod
		send('R'..modname..'')
	end
end

-- ============= OTHERS =============

local function loginReceived(params)
	log('M', 'loginReceived', 'Logging result received')
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
	print(debug.traceback())
	isMpSession = false
	isGoingMpSession = false
	currentServer = {}
	send('QS') -- Quit session, disconnecting MPCoreNetwork is not necessary
	MPGameNetwork.disconnectLauncher()
	MPVehicleGE.onDisconnect()
	status = "" -- Reset status
	extensions.hook('onServerLeave')
	MPModManager.cleanUpSessionMods()
	core_modmanager.enableAutoMount() -- re-enable auto-mount
	if goBack then returnToMainMenu() end
end


local function isMPSession()
	return isMpSession
end

local function isGoingMPSession()
	return isGoingMpSession
end

-- ============= OTHERS =============
local autoMountDisabled = false
local function handleU(params)
	UI.updateLoading(params)
	local code = string.sub(params, 1, 1)
	local data = string.sub(params, 2)
	if code == "l" then
		--log('W',"handleU", data)
		if settings.getValue('beammpAlternateModloading') then --TODO: take a look at mod loading stuff
			if data == "start" and not autoMountDisabled then-- starting modloading, disable automount
				log('W',"handleU", "starting mod dl process, disabling automount")
				core_modmanager.disableAutoMount()
				autoMountDisabled = true

			elseif string.match(data, "^Loading Resource") then
				log('W',"handleU", "mod downloaded, manually check for it")

				local modName = string.match(data, "^Loading Resource %d+/%d+: %/(.+)%.zip")

				if currentModHasLoaded then
					modLoaded(modName)
					currentModHasLoaded = false
				else
					core_modmanager.initDB() -- manually check for new mod
					currentModHasLoaded = true
				end
				send('Ul') -- update the UI
			end
		end

		if data == "done" and status == "LoadingResources" then --TODO: check if all the resources have actually been loaded before requesting map
			send('M') -- request map string from launcher
			log('W', 'handleU', 'Requested map!')
			status = "LoadingMap"
		elseif string.sub(data, 1, 12) == "Disconnected" then
			--log('W', 'handleU', 'leaveServer by launcher!') --commented out because a disconnected message is received while joining a server for whatever reason
			--leaveServer(false) -- reset session variables
		end
	elseif code == "p" and isMpSession then
		UI.setPing(data.."")
		positionGE.setPing(data)
	end
end

-- ============= EVENTS =============
local HandleNetwork = {
	['A'] = function(params) receiveLauncherHeartbeat() end, -- Launcher heartbeat
	['B'] = function(params) serverList = params; sendBeamMPInfo() end, -- Server list received
	['U'] = function(params) handleU(params) end, -- Loading into server UI
	['M'] = function(params) log('W', 'HandleNetwork', 'Received Map! '..params) loadLevel(params) end,
	['N'] = function(params) loginReceived(params) end,
	['L'] = function(params) setMods(params) end,
	['Z'] = function(params) launcherVersion = params; end,
	--['K'] = function(params) log('E','HandleNetwork','K packet - UNUSED') end, -- pre-join kick is currently handled launcher-side
}

local onUpdateTimer = 0
local pingTimer = 0
local updateUITimer = 0
local heartbeatTimer = 0
local function onUpdate(dt)
	pingTimer = pingTimer + dt -- TODO: clean this up a bit
	onUpdateTimer = onUpdateTimer + dt
	updateUITimer = updateUITimer + dt
	heartbeatTimer = heartbeatTimer + dt
	--====================================================== DATA RECEIVE ======================================================
	if launcherConnected then
		while(true) do
			local received, stat, partial = TCPLauncherSocket:receive()
			--print(stat) -- nil when receiving data, timeout when not
			if not received or received == "" then
				break
			end
			if settings.getValue("showDebugOutput") == true then -- TODO: add option to filter out heartbeat packets
				print('[MPCoreNetwork] Receiving Data ('..string.len(received)..'): '..received)
			end

			-- break it up into code + data
			local code = string.sub(received, 1, 1)
			local data = string.sub(received, 2)
			HandleNetwork[code](data)
		end
		--================================ SECONDS TIMER ================================
		if heartbeatTimer >= 5 then
			heartbeatTimer = 0
			send('A') -- Launcher heartbeat
		end
		if updateUITimer >= 0.1 and status == "LoadingResources" then
			updateUITimer = 0
			send('Ul') -- Ask the launcher for a loading screen update
		end
		if pingTimer >= 5 then --TODO: only ask for ping if in session and loaded in a map
			pingTimer = 0
			send('Up') -- request ping packet
		end
		--[[
			if launcherConnectionTimer > 15 then
				disconnectLauncher(true) -- reconnect to launcher (this breaks the launcher if the connection
				connectToServer(currentServer.ip, currentServer.port, currentServer.modsString, currentServer.name)
			end
		end
		]]--
	else
		if onUpdateTimer >= 1 then -- if connection is lost re-attempt connecting every second
			onUpdateTimer = 0
			connectToLauncher(true)
		end
	end
end


-- EVENTS
local function onExtensionLoaded()
	reloadUI() -- required to show modified mainmenu
	connectToLauncher()
end

onLauncherConnected = function()
	log('W', 'onLauncherConnected', 'onLauncherConnected')
	send('Z') -- request launcher version
	autoLogin()
	requestServerList()
	extensions.hook('onLauncherConnected')
	if isMpSession then --TODO: WIP, verify and test / finish -- if the launcher closed while in a session, this reconnects back to the session once reopened
		connectToServer(currentServer.ip, currentServer.port, currentServer.modsString, currentServer.name)
	end
end

local function onClientStartMission(mission) --TODO: 
	if status == "Playing" and getMissionFilename() ~= currentServer.map then
		log('W', 'onClientStartMission', 'The user has loaded another mission!')
		--Lua:requestReload()
	elseif getMissionFilename() == currentServer.map then
		status = "Playing"
	end
end

runPostJoin = function() -- TODO: put all the functions that should run after joining server, then call this function from events
	log('W', 'onClientPostStartMission', 'isGoingMpSession: '..tostring(isGoingMpSession))
	log('W', 'onClientPostStartMission', 'isMpSession: '..tostring(isMpSession))
	if isMpSession and isGoingMpSession then
		log('W', 'onClientPostStartMission', 'Connecting MPGameNetwork!')
		MPGameNetwork.connectToLauncher()
		log('W', 'onClientPostStartMission', 'isGoingMpSession = false')
		isGoingMpSession = false
		core_gamestate.setGameState('multiplayer', 'multiplayer', 'multiplayer') -- TODO: clean this up, dont call this twice
		guihooks.trigger('ChangeState', 'play')
	end
end

local function onClientPostStartMission() --TODO: move to onWorldReadyState
	runPostJoin()
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

local function onSerialize() --TODO: reimplement server rejoin on lua reload
	return {currentServer = currentServer,
			isMpSession = isMpSession}
end
local function onDeserialized(data)
	log('M', 'onDeserialized', dumps(data))

	currentServer = data and data.currentServer or nil
	isMpSession = data and data.isMpSession

	if not currentServer then return end
	if isMpSession then
		log('I', 'onDeserialized', 'reconnecting')
		connectToServer(currentServer.ip, currentServer.port, currentServer.modsString, currentServer.name)
	end
end


-- ================ UI ================
M.getLauncherVersion   = getLauncherVersion -- TODO: remove functions that shouldnt be public
M.isLoggedIn           = isLoggedIn
M.isLauncherConnected  = isLauncherConnected
M.disconnectLauncher   = disconnectLauncher
M.autoLogin            = autoLogin
M.onUiChangedState     = onUiChangedState

M.requestPlayers       = requestPlayers
M.onExtensionLoaded    = onExtensionLoaded
M.onUpdate             = onUpdate
M.onClientEndMission   = onClientEndMission
M.onClientStartMission = onClientStartMission
M.onClientPostStartMission = onClientPostStartMission
M.login                = login
M.logout               = logout
M.modLoaded            = modLoaded
M.requestServerList    = requestServerList
M.isMPSession          = isMPSession
M.leaveServer          = leaveServer
M.connectToServer      = connectToServer
M.getCurrentServer     = getCurrentServer
M.setCurrentServer     = setCurrentServer
M.isGoingMPSession     = isGoingMPSession
M.connectToLauncher    = connectToLauncher
M.send = send

M.onSerialize          = onSerialize
M.onDeserialized       = onDeserialized

print("MPCoreNetwork loaded")

-- TODO: finish all this

return M
