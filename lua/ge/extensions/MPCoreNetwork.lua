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
local launcherConnectionStatus = false -- status 0: not connected, 1: connected
local launcherConnectionTimer = 0
local status = "" -- "", "LoadingResources", "LoadingMap", "LoadingMapNow", "Playing"
local launcherVersion = "" -- used only for the server list
local loggedIn = false
local currentModHasLoaded = false
local isMpSession = false
local isGoingMpSession = false
local connectionIssuesShown = false
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
	if r and not launcherConnectionStatus then
		launcherConnectionStatus = true
		log('W', 'send', 'Launcher connected!')
	elseif not launcherConnectionStatus then
		log('W', 'send', 'Lost launcher connection!')
		launcherConnectionStatus = false
		return
	end

	if not settings.getValue("showDebugOutput") then return end
	print('[MPCoreNetwork] Sending Data ('..r..'): '..s)
end

local function connectToLauncher()
	log('W', 'connectToLauncher', "connectToLauncher called! Current connection status: "..tostring(launcherConnectionStatus))
	if launcherConnectionStatus == false then
		log('M', 'connectToLauncher', "MPCoreNetwork connecting to launcher...")
		TCPLauncherSocket = socket.tcp()
		TCPLauncherSocket:setoption("keepalive", true) -- Keepalive to avoid connection closing too quickly
		TCPLauncherSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
		TCPLauncherSocket:connect((settings.getValue("launcherIp") or '127.0.0.1'), (settings.getValue("launcherPort") or 4444))
		send("Up") -- immediately heartbeat to check if connection was established
	end
end

local function disconnectLauncher(reconnect)
	log('W', 'disconnectLauncher', 'Launcher disconnect called! reconnect: '..tostring(reconnect))
	if launcherConnectionStatus == true then
		log('W', 'disconnectLauncher', "Disconnecting from launcher")
		TCPLauncherSocket:close()
		launcherConnectionStatus = false
		isGoingMpSession = false
	end
	if reconnect then connectToLauncher() end
end


-- This is called everytime we receive a heartbeat from the launcher
local function receiveLauncherHeartbeat()
	if launcherConnectionStatus ~= true then
		guihooks.trigger('launcherConnected')
	end
	--guihooks.trigger('showConnectionIssues', false)
	--connectionIssuesShown = false
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
	return launcherConnectionStatus
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
local function getServers()
	send('B') -- Request server list
end

-- sends the current player and server count.
local function sendBeamMPInfo()
	local servers = jsonDecode(serverList)
	if not servers or tableIsEmpty(servers) then return log('E', 'Failed to retrieve server list.') end
	local p, s = 0, 0
	for _,server in pairs(servers) do
		p = p + server.players
		s = s + 1
	end
	-- send player and server values to front end.
	guihooks.trigger('BeamMPInfo', {
		players = ''..p,
		servers = ''..s
	})
end

local function requestPlayers()
	if not isMpSession then -- launcher breaks connection if the server list is requested
		getServers()
	end
	sendBeamMPInfo()
end
-- ================ UI ================



-- ============= SERVER RELATED =============
local function setMods(modsString)
	if modsString == "" then return log('M', 'setMods', 'Received no mods.') end
	local mods = {}
	if (modsString) then
		for mod in string.gmatch(modsString, "([^;]+)") do
			local modFileName = mod:gsub("Resources/Client/",""):gsub(".zip",""):gsub(";","")
			table.insert(mods, modFileName)
		end
	end
	isGoingMpSession = true
	MPModManager.setServerMods(mods) -- Setting the mods from the server
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
	if MPCoreNetwork.isMPSession() then MPCoreNetwork.leaveServer() end
	--if getMissionFilename() ~= "" then leaveServer(false) end
	if ip and port then -- Direct connect
		currentServer = nil
		setCurrentServer(ip, port, mods, name)
	end

	local ipString = currentServer.ip..':'..currentServer.port
	send('C'..ipString..'')

	log('M', 'connectToServer', "Connecting to server "..ipString)
	status = "LoadingResources"
end

local function loadLevel(map)
	log("W","loadLevel", "loading map " ..map)
	log('W', 'loadLevel', 'Loading level from MPCoreNetwork -> freeroam_freeroam.startFreeroam')

	spawn.preventPlayerSpawning = true -- don't spawn default vehicle when joining server

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
	isMpSession = true

	-- replaces the instability detected function with one that doesn't pause physics or sends messages to the UI
	-- but left logging in so you can still see what car it is -- credit to deerboi for showing me that this is possible
	-- it resets to default on leaving the server
	-- we should probably consider a system to detect if a vehicle is in a instability loop and then delete it or respawn it (rapid instabilities causes VE to break on reload so it would need to be respawned)
	--onInstabilityDetected = function(jbeamFilename) if not settings.getValue("disableInstabilityPausing") then bullettime.pause(true) ui_message({txt="vehicle.main.instability", context={vehicle=tostring(jbeamFilename)}}, 10, 'instability', "warning") end log('E', "", "Instability detected for vehicle " .. tostring(jbeamFilename)) end
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
	log('W', 'leaveServer', 'Reset Session Called! ' .. tostring(goBack))
	print("Reset Session Called! " .. tostring(goBack))
	isMpSession = false
	isGoingMpSession = false
	send('QS') -- Tell the launcher that we quit server / session
	disconnectLauncher()
	MPGameNetwork.disconnectLauncher()
	MPVehicleGE.onDisconnect()
	status = "" -- Reset status
	if goBack then returnToMainMenu() end -- return to main menu
	-- resets the instability function back to default
	onInstabilityDetected = function (jbeamFilename)  bullettime.pause(true)  log('E', "", "Instability detected for vehicle " .. tostring(jbeamFilename))  ui_message({txt="vehicle.main.instability", context={vehicle=tostring(jbeamFilename)}}, 10, 'instability', "warning")end
	MPModManager.cleanUpSessionMods()
	connectToLauncher()
end

local function isMPSession()
	return isMpSession
end

local function isGoingMPSession()
	return isGoingMpSession
end

-- ============= OTHERS =============

local function handleU(params)
	UI.updateLoading(params)
	local code = string.sub(params, 1, 1)
	local data = string.sub(params, 2)
	if code == "l" then
		--log('W',"handleU", data)
		if settings.getValue('beammpAlternateModloading') then
			if data == "start" then-- starting modloading, disable automount
				log('W',"handleU", "starting mod dl process, disabling automount")
				core_modmanager.disableAutoMount()

			elseif string.match(data, "^Loading Resource") then
				log('W',"handleU", "mod downloaded, manually check for it")
				--core_modmanager.enableAutoMount()
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

		if data == "done" and status == "LoadingResources" then
			send('Mrequest')
			status = "LoadingMap"
		end
	elseif code == "p" and isMpSession then
		UI.setPing(data.."")
		positionGE.setPing(data)
	end
end

-- ============= EVENTS =============
local HandleNetwork = {
	['A'] = function(params) receiveLauncherHeartbeat() end, -- Launcher heartbeat
	['B'] = function(params) serverList = params; guihooks.trigger('onServersReceived', params); sendBeamMPInfo() end, -- Server list received
	['U'] = function(params) handleU(params) end, -- UI
	['M'] = function(params) loadLevel(params) end,
	['N'] = function(params) loginReceived(params) end,
	['V'] = function(params) MPVehicleGE.handle(params) end, -- Vehicle spawn/edit/reset/remove/coupler related event
	['L'] = function(params) setMods(params) end,
	['K'] = function(params) log('E','HandleNetwork','K packet - UNUSED') end, -- Player Kicked Event
	['Z'] = function(params) launcherVersion = params; end
}


local function onUpdate(dt)
	--====================================================== DATA RECEIVE ======================================================
	if launcherConnectionStatus then
		while(true) do
			local received, stat, partial = TCPLauncherSocket:receive()
			--print(stat) -- nil when receiving data, timeout when not
			if not received or received == "" then
				break
			end
			if settings.getValue("showDebugOutput") == true then
				if received ~= 'A' and received ~= 'Up-1' then print('[MPCoreNetwork] Receiving Data ('..string.len(received)..'): '..received) end
			end

			-- break it up into code + data
			local code = string.sub(received, 1, 1)
			local data = string.sub(received, 2)
			HandleNetwork[code](data)
		end
		--================================ SECONDS TIMER ================================
		launcherConnectionTimer = launcherConnectionTimer + dt -- Time in seconds
		if launcherConnectionTimer > 1 then
			send('A') -- Launcher heartbeat?
			if status == "LoadingResources" then send('Ul') -- Ask the launcher for a loading screen update
			else send('Up') end -- Server heartbeat?
			launcherConnectionTimer = 0
		end
		-- Check the launcher connection
		--[[
		if launcherConnectionTimer > 2 then
			--log('M', 'onUpdate', "it's been >2 seconds since the last ping so lua was probably frozen for a while")

			if not connectionIssuesShown then
				if scenetree.missionGroup then
					guihooks.trigger('showConnectionIssues', true)
				else
					guihooks.trigger('LauncherConnectionLost')
				end
			end

			connectionIssuesShown = true

			if launcherConnectionTimer > 15 then
				disconnectLauncher(true) -- reconnect to launcher (this breaks the launcher if the connection
				connectToServer(currentServer.ip, currentServer.port, currentServer.modsString, currentServer.name)
			end
		end
		]]--
	else
		--connectToLauncher()
	end
end


-- EVENTS
local function onExtensionLoaded()
	connectToLauncher()
	reloadUI() -- required to show modified mainmenu
	send('Z') -- request launcher version
	autoLogin()
end

local function onClientStartMission(mission)
	if status == "Playing" and getMissionFilename() ~= currentServer.map then
		log('W', 'onClientStartMission', 'The user has loaded another mission!')
		--Lua:requestReload()
	elseif getMissionFilename() == currentServer.map then
		status = "Playing"
	end
end

local function onClientPostStartMission()
	if MPCoreNetwork.isMPSession() then
		log('M', 'onClientPostStartMission', 'Setting game state to multiplayer.')
		core_gamestate.setGameState('multiplayer', 'multiplayer', 'multiplayer') -- Set UI elements
		MPGameNetwork.connectToLauncher()
	end
end

local function onClientEndMission(mission)
	log('W', 'onClientEndMission', mission)
	if not isGoingMpSession then
		--leaveServer(false)
	end
end

local function onUiChangedState (curUIState, prevUIState)
	if curUIState == 'menu' and getMissionFilename() == "" then -- required due to game bug that happens if UI is reloaded on the main menu
		guihooks.trigger('ChangeState', 'menu.mainmenu')
	end
end

local function onSerialize()
	return currentServer
end
local function onDeserialized(serverInfo)
	if getMissionFilename() == serverInfo.map then
		log('I', 'onDeserialized', 'Previous map matches current, reconnecting')
		connectToServer(serverInfo.ip, serverInfo.port, serverInfo.modsString, serverInfo.name)
	end
end


-- ================ UI ================
M.getLauncherVersion   = getLauncherVersion
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
M.getServers           = getServers
M.isMPSession          = isMPSession
M.leaveServer          = leaveServer
M.connectToServer      = connectToServer
M.getCurrentServer     = getCurrentServer
M.setCurrentServer     = setCurrentServer
M.isGoingMPSession     = isGoingMPSession
M.connectionStatus     = launcherConnectionStatus
M.connectToLauncher    = connectToLauncher
M.send = send

--M.onSerialize          = onSerialize
--M.onDeserialized       = onDeserialized

print("MPCoreNetwork loaded")

-- TODO: finish all this

return M
