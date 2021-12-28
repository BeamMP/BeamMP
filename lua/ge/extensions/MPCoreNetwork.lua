--====================================================================================
-- All work by Titch2000, jojos38 & 20dka.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading MPCoreNetwork...")



-- ============= VARIABLES =============
local TCPLauncherSocket -- Launcher socket
local currentServer = {} -- Store the server we are on
local Servers -- Store all the servers
local launcherConnectionStatus = 0 -- Status: 0 not connected | 1 connecting or connected
local launcherConnectionTimer = 0
local status = ""
local launcherVersion = ""
local loggedIn = false
local currentModHasLoaded = false
local isMpSession = false
local isGoingMpSession = false
local launcherTimeout = 0
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
	if not settings.getValue("showDebugOutput") then return end

	if s == 'A' or s == 'Up' then
		print(s)
	else
		print('[MPCoreNetwork] Sending Data ('..r..'): '..s)
	end
end

local function connectToLauncher()
	if launcherConnectionStatus == 0 then -- If launcher is not connected yet
		log('M', 'connectToLauncher', "Connecting to launcher")
		TCPLauncherSocket = socket.tcp()
		TCPLauncherSocket:setoption("keepalive", true) -- Keepalive to avoid connection closing too quickly
		TCPLauncherSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
		TCPLauncherSocket:connect('127.0.0.1', (settings.getValue("launcherPort") or 4444));
		launcherConnectionStatus = 1
	end
end

local function disconnectLauncher(reconnect)
	if launcherConnectionStatus > 0 then -- If player was connected
		log('M', 'disconnectLauncher', "Disconnecting from launcher")
		TCPLauncherSocket:close()-- Disconnect from server
		launcherConnectionStatus = 0
		launcherConnectionTimer = 0
		isGoingMpSession = false
	end
	if reconnect then connectToLauncher() end
end

local function onLauncherConnectionFailed()
	disconnectLauncher()
	MPModManager.restoreLoadedMods() -- Attempt to restore the mods before deleting BeamMP
	local modsList = core_modmanager.getModList()
	local beammpMod = modsList["beammp"] or modsList["multiplayerbeammp"]
	if (beammpMod) then
		if beammpMod.active and not beammpMod.unpackedPath then
			core_modmanager.deleteMod(beammpMod.modname)
			Lua:requestReload()
		end
	end
end

-- This is called everytime we receive a heartbeat from the launcher
local function checkLauncherConnection()
	launcherConnectionTimer = 0
	if launcherConnectionStatus ~= 2 then
		launcherConnectionStatus = 2
		guihooks.trigger('launcherConnected', nil)
	end
	guihooks.trigger('showConnectionIssues', false)
	connectionIssuesShown = false
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
	return launcherConnectionStatus == 2
end
local function login(identifiers)
	log('M', 'login', 'Attempting login')
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
	print(launcherVersion)
	log('M', 'getServers', "Getting the servers list")
	send('B') -- Ask for the servers list
end

-- sends the current player and server count.
local function sendBeamMPInfo()
	if not Servers then return end
	local servers = jsonDecode(Servers)
	if tableIsEmpty(servers) then return end
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
	if not isMpSession then
		send('B')
	end
	sendBeamMPInfo()
end
-- ================ UI ================



-- ============= SERVER RELATED =============
local function setMods(modsString)
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
		modsString = modsString,
		name	   = name
	}
	setMods(modsString)
end

-- Tell the launcher to open the connection to the server so the MPMPGameNetwork can connect to the launcher once ready
local function connectToServer(ip, port, mods, name)
	--if getMissionFilename() ~= "" then leaveServer(false) end
	if ip and port then -- Direct connect
		currentServer = nil
		setCurrentServer(ip, port, mods, name)
	end

	local ipString = currentServer.ip..':'..currentServer.port
	send('C'..ipString..'')

	print("Connecting to server "..ipString)
	status = "LoadingResources"
end

local function loadLevel(map)
	log("W","loadLevel", "loading map " ..map)
	if getMissionFilename() == map then
		log('W', 'loadLevel', 'Requested map matches current map, rejoining')
		--set modlist to current mods
	else
		if not core_levels.expandMissionFileName(map) then
			UI.updateLoading("lMap "..map.." not found")
			status = ""
			M.leaveServer(false)
			return
		end
	end

	status = "LoadingMapNow"


	MPModManager.backupLoadedMods() -- Backup the current loaded mods before loading the map

	currentServer.map = map

	if getMissionFilename() == '' then
		multiplayer_multiplayer.startMultiplayer(map)
	else
		MPGameNetwork.disconnectLauncher()
		MPGameNetwork.connectToLauncher()
	end
	isMpSession = true

	-- replaces the instability detected function with one that doesn't pause physics or sends messages to the UI
	-- but left logging in so you can still see what car it is -- credit to deerboi for showing me that this is possible
	-- it resets to default on leaving the server
	-- we should probably consider a system to detect if a vehicle is in a instability loop and then delete it or respawn it (rapid instabilities causes VE to break on reload so it would need to be respawned)
	onInstabilityDetected = function(jbeamFilename) if not settings.getValue("disableInstabilityPausing") then bullettime.pause(true) ui_message({txt="vehicle.main.instability", context={vehicle=tostring(jbeamFilename)}}, 10, 'instability', "warning") end log('E', "", "Instability detected for vehicle " .. tostring(jbeamFilename)) end
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
		log('M', 'loginReceived', 'Login successful')
		loggedIn = true
		guihooks.trigger('LoggedIn', result.message or '')
	else
		log('M', 'loginReceived', 'Login credentials incorrect')
		loggedIn = false
		guihooks.trigger('LoginError', result.message or '')
	end
end


local function leaveServer(goBack)
	isMpSession = false
	isGoingMpSession = false
	print("Reset Session Called! " .. tostring(goBack))
	send('QS') -- Tell the launcher that we quit server / session
	disconnectLauncher()
	MPGameNetwork.disconnectLauncher()
	MPVehicleGE.onDisconnect()
	connectToLauncher()
	--UI.readyReset()
	status = "" -- Reset status
	if goBack then endActiveGameMode() end
	-- resets the instability function back to default
	onInstabilityDetected = function (jbeamFilename)  bullettime.pause(true)  log('E', "", "Instability detected for vehicle " .. tostring(jbeamFilename))  ui_message({txt="vehicle.main.instability", context={vehicle=tostring(jbeamFilename)}}, 10, 'instability', "warning")end

	MPModManager.cleanUpSessionMods()
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
				local modName = string.match(data, "^Loading Resource %d+/%d+: %/(%g+)%.zip")

				if currentModHasLoaded then
					modLoaded(modName)
					currentModHasLoaded = false
				else
					core_modmanager.initDB() -- manually check for new mod
					currentModHasLoaded = true
				end
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
	['A'] = function(params) checkLauncherConnection() end, -- Connection Alive Checking
	['B'] = function(params) Servers = params; guihooks.trigger('onServersReceived', params); sendBeamMPInfo() end, -- Serverlist received
	['U'] = function(params) handleU(params) end, -- UI
	['M'] = function(params) loadLevel(params) end,
	['N'] = function(params) loginReceived(params) end, -- Login system
	['V'] = function(params) MPVehicleGE.handle(params) end, -- Vehicle spawn/edit/reset/remove/coupler related event
	['L'] = function(params) setMods(params) end,
	['K'] = function(params) log('E','HandleNetwork','K packet - UNUSED') end, -- Player Kicked Event
	['Z'] = function(params) launcherVersion = params; be:executeJS('setClientVersion('..params..')') end -- Tell the UI what the launcher version is
}



-- ============= Init =============
local function onInit()
	if not core_modmanager.getModList then Lua:requestReload() end
end


-- ====================================== ENTRY POINT ======================================
local function onExtensionLoaded()
	-- removing the radial menu from the Multiplayer UI layout if it's present
	local currentMpLayout = jsonReadFile("settings/ui_apps/layouts/default/multiplayer.uilayout.json")
	local ui_info = jsonReadFile("settings/BeamMP/ui_info.json")
	local info = {}
	local wasUiReset = false
	local foundRadialMenu = false
	if ui_info then wasUiReset = ui_info.wasUiReset end

	if not wasUiReset then
		
		-- checking if the radial menu is found in the Multiplayer UI layout
		if currentMpLayout then
			for k,v in pairs(currentMpLayout.apps) do
				if v.appName == "radialmenu" then
					--print("Found radial menu present in Multiplayer UI Layout!")
					foundRadialMenu = true
					break
				end
			end
		end
		if foundRadialMenu == true then
			--print("Multiplayer UI has been reset to default!")
			os.remove("settings/ui_apps/layouts/default/multiplayer.uilayout.json")
		end
		info.wasUiReset = true
		jsonWriteFile("settings/BeamMP/ui_info.json",info)
	end
	-- First we connect to the launcher
	connectToLauncher()
	-- We reload the UI to load our custom layout
	reloadUI()
	-- Get the launcher version
	send('Z')
	-- Log-in
	send('Nc')
end
-- ====================================== ENTRY POINT ======================================


local function onUpdate(dt)
	--====================================================== DATA RECEIVE ======================================================
	if launcherConnectionStatus > 0 then -- If player is connecting or connected
		while (true) do
			local received, stat, partial = TCPLauncherSocket:receive() -- Receive data

			if not received or received == "" then
				break
			end

			if settings.getValue("showDebugOutput") == true then
				print('[MPCoreNetwork] Receiving Data: '..received)
			end

			-- break it up into code + data
			local code = string.sub(received, 1, 1)
			local data = string.sub(received, 2)
			HandleNetwork[code](data)

		end

		--================================ SECONDS TIMER ================================
		launcherConnectionTimer = launcherConnectionTimer + dt -- Time in seconds
		if launcherConnectionTimer > 0.5 then
			send('A') -- Launcher heartbeat
			if status == "LoadingResources" then send('Ul') -- Ask the launcher for a loading screen update
			else send('Up') end -- Server heartbeat
		end

		-- Check the launcher connection
		if launcherConnectionTimer > 2 then
			log('M', 'onUpdate', "it's been >2 seconds since the last ping so lua was probably frozen for a while")

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
	end
end

local function onClientStartMission(mission)
	if status == "Playing" and getMissionFilename() ~= currentServer.map then
		print("The user has loaded another mission!")
		--Lua:requestReload()
	elseif getMissionFilename() == currentServer.map then
		status = "Playing"
	end
end

local function onClientEndMission(mission)
	if isMPSession() then
		leaveServer(true)
	end
end

local function onUiReady()
	if getMissionFilename() == "" then
		guihooks.trigger('ChangeState', 'menu.mainmenu')
	end
end
-- ============= EVENTS =============


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
M.isLoggedIn 		       = isLoggedIn
M.isLauncherConnected  = isLauncherConnected
--M.onExtensionLoaded    = onExtensionLoaded
--M.onUpdate             = onUpdate
M.disconnectLauncher   = disconnectLauncher
M.autoLogin			       = autoLogin
--M.onUiChangedState	   = onUiChangedState

M.onInit               = onInit
M.onUiReady            = onUiReady
M.requestPlayers       = requestPlayers
M.onExtensionLoaded    = onExtensionLoaded
M.onUpdate             = onUpdate
M.onClientEndMission   = onClientEndMission
M.onClientStartMission = onClientStartMission
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

M.onSerialize          = onSerialize
M.onDeserialized       = onDeserialized

print("MPCoreNetwork loaded")

return M
