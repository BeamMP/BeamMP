--====================================================================================
-- All work by Titch2000, jojos38 & 20dka.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading MPCoreNetwork...")



-- ============= VARIABLES =============
local loggerPrefix = "CoreNetwork"
local TCPLauncherSocket -- Launcher socket
local currentServer = {} -- Store the server we are on
local Servers = {} -- Store all the servers
local launcherConnectionStatus = 0 -- Status: 0 not connected | 1 connecting or connected
local launcherConnectionTimer = 0
local status = ""
local launcherVersion = ""
local currentMap = ""
local loggedIn = false
local mapLoaded = false
local MapLoadingTimeout = 0
local isMpSession = false
local isGoingMpSession = false
local launcherTimeout = 0
local connectionFailed = false
local packetReceivedYet = false
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
	if settings.getValue("showDebugOutput") == true then
		print('[MPCoreNetwork] Sending Data ('..r..'): '..s)
	end
end

local function connectToLauncher()
	if launcherConnectionStatus == 0 then -- If launcher is not connected yet
		log('M', loggerPrefix, "Connecting to launcher")
		TCPLauncherSocket = socket.tcp()
		TCPLauncherSocket:setoption("keepalive", true) -- Keepalive to avoid connection closing too quickly
		TCPLauncherSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
		TCPLauncherSocket:connect('127.0.0.1', (settings.getValue("launcherPort") or 4444));
		launcherConnectionStatus = 1
	end
end

local function disconnectLauncher(reconnect)
	if launcherConnectionStatus > 0 then -- If player was connected
		log('M', loggerPrefix, "Disconnecting from launcher")
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
	log('M', loggerPrefix, 'Attempting login')
	send('N:'..identifiers)
end
local function autoLogin()
	send('Nc')
end
local function logout()
	log('M', loggerPrefix, 'Attempting logout')
	send('N:LO')
	loggedIn = false
end
local function getServers()
	print(launcherVersion)
	log('M', loggerPrefix, "Getting the servers list")
	send('B') -- Ask for the servers list
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
		modsstring = modsString,
		name	   = name
	}
	setMods(modString)
end

-- Tell the launcher to open the connection to the server so the MPMPGameNetwork can connect to the launcher once ready
local function connectToServer(ip, port, mods, name)
	-- Prevent the user from connecting to a server when already connected to one
	if getMissionFilename() ~= "" then Lua:requestReload() end
	local ipString
	if ip and port then -- Direct connect
		currentServer = nil
		setCurrentServer(ip, port, mods, name)
		ipString = ip..':'..port
		send('C'..ipString..'')
	else -- Server list connect
		ipString = currentServer.ip..':'..currentServer.port
		send('C'..ipString..'')
  end
	print("Connecting to server "..ipString)
	status = "LoadingResources"
end

local function loadLevel(map)
	-- Map loading has a 5 seconds timeout in case it doesn't work
	MPModManager.backupLoadedMods() -- Backup the current loaded mods before loading the map
	MapLoadingTimeout = 0
	mapLoaded = false
	status = "LoadingMapNow"
	if not core_levels.expandMissionFileName(map) then
		UI.updateLoading("lMap "..map.." not found")
		MPCoreNetwork.resetSession(false)
		return
	end
	currentMap = map
	multiplayer_multiplayer.startMultiplayer(map)
	isMpSession = true
end
-- ============= SERVER RELATED =============



-- ============= OTHERS =============
local function handleU(params)
	UI.updateLoading(params)
	local code = string.sub(params, 1, 1)
	local data = string.sub(params, 2)
	if code == "l" then
		if data == "done" and status == "LoadingResources" then
			send('Mrequest')
			status = "LoadingMap"
		end
	elseif code == "p" and isMpSession then
		UI.setPing(data.."")
		positionGE.setPing(data)
	end
end

local function loginReceived(params)
	log('M', loggerPrefix, 'Logging result received')
	local result = jsonDecode(params)
	if (result.success == true or result.Auth == 1) then
		log('M', loggerPrefix, 'Login successful')
		loggedIn = true
		guihooks.trigger('LoggedIn', result.message or '')
	else
		log('M', loggerPrefix, 'Login credentials incorrect')
		loggedIn = false
		guihooks.trigger('LoginError', result.message or '')
	end
end


local function modLoaded(modname)
	if modname ~= "beammp" then -- We don't want to check beammp mod
		send('R'..modname..'')
	end
end

local function resetSession(goBack)
	isMpSession = false
	isGoingMpSession = false
	print("Reset Session Called!")
	send('QS') -- Tell the launcher that we quit server / session
	disconnectLauncher()
	MPGameNetwork.disconnectLauncher()
	MPVehicleGE.onDisconnect()
	connectToLauncher()
	--UI.readyReset()
	status = "" -- Reset status
	if goBack then returnToMainMenu() end
	MPModManager.cleanUpSessionMods()
end

local function isMPSession()
	return isMpSession
end

local function isGoingMPSession()
	return isGoingMpSession
end

local function quitMP(reason)
	isMpSession = false
	isGoingMpSession = false
	print("Quit MP Called!")
	print("reason: "..tostring(reason))
	send('QG') -- Quit game
end
-- ============= OTHERS =============



-- ============= EVENTS =============
local HandleNetwork = {
	['A'] = function(params) checkLauncherConnection() end, -- Connection Alive Checking
	['B'] = function(params) Servers = params; guihooks.trigger('onServersReceived', params) end, -- Serverlist received
	['U'] = function(params) handleU(params) end, -- UI
	['M'] = function(params) loadLevel(params) end,
	['N'] = function(params) loginReceived(params) end, -- Login system
	['V'] = function(params) MPVehicleGE.handle(params) end, -- Vehicle spawn/edit/reset/remove/coupler related event
	['L'] = function(params) setMods(params) end,
	['K'] = function(params) quitMP(params) end, -- Player Kicked Event
	['Z'] = function(params) launcherVersion = params; be:executeJS('setClientVersion('..params..')') end -- Tell the UI what the launcher version is
}



-- ============= Init =============
local function onInit()
	if not core_modmanager.getModList then Lua:requestReload() end
end


-- ====================================== ENTRY POINT ======================================
local function onExtensionLoaded()
	--Preston (Cobalt) insert the custom multiplayer layout inside the game's layout file
	-- First check that the game's layout file exists
	local layouts = jsonReadFile("settings/uiapps-layouts.json")
	if not layouts then
		layouts = jsonReadFile("settings/uiapps-defaultLayout.json")
		jsonWriteFile("settings/uiapps-layouts.json", layouts)
		log("M", loggerPrefix, "default UI layout added")
	end
	-- Then check that multiplayer layout is inside
	if not layouts.multiplayer then
		layouts.multiplayer = jsonReadFile("settings/uiapps-defaultMultiplayerLayout.json")
		jsonWriteFile("settings/uiapps-layouts.json", layouts)
		log("M", loggerPrefix, "multiplayer UI layout added")
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
	--print(launcherConnectionTimer)
	--====================================================== DATA RECEIVE ======================================================
	if launcherConnectionStatus > 0 then -- If player is connecting or connected
		while (true) do
			local received, stat, partial = TCPLauncherSocket:receive() -- Receive data

			-- Checking connection
			if launcherTimeout > 0.1 then onLauncherConnectionFailed() connectionFailed = true end
			if not received or received == "" then
				if not packetReceivedYet then launcherTimeout = launcherTimeout + dt end
				break
			end
			packetReceivedYet = true

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
			log('M', loggerPrefix, "Connection to launcher was lost")
			guihooks.trigger('LauncherConnectionLost')
			disconnectLauncher(true)
			launcherConnectionTimer = 0
		end
	end
end


local function onModManagerReady()
	if connectionFailed then onLauncherConnectionFailed() end
end

local function onClientStartMission(mission)
	if status == "Playing" and getMissionFilename() ~= currentMap then
		print("The user has loaded another mission!")
		Lua:requestReload()
	elseif getMissionFilename() == currentMap then
		status = "Playing"
	end
end

local function onClientEndMission(mission)
	if isMPSession() then
		resetSession(1)
	end
end
-- ============= EVENTS =============


-- ================ UI ================
M.getLauncherVersion   = getLauncherVersion
M.isLoggedIn 		       = isLoggedIn
M.isLauncherConnected  = isLauncherConnected
--M.onExtensionLoaded    = onExtensionLoaded
--M.onUpdate             = onUpdate
M.disconnectLauncher   = disconnectLauncher
M.autoLogin			       = autoLogin
--M.onUiChangedState	   = onUiChangedState

M.onInit = onInit
M.onExtensionLoaded    = onExtensionLoaded
M.onUpdate             = onUpdate
M.onModManagerReady    = onModManagerReady
M.onClientEndMission   = onClientEndMission
M.onClientStartMission = onClientStartMission
M.login                = login
M.logout               = logout
M.quitMP               = quitMP
M.modLoaded            = modLoaded
M.getServers           = getServers
M.isMPSession          = isMPSession
M.resetSession         = resetSession
M.connectToServer      = connectToServer
M.getCurrentServer     = getCurrentServer
M.setCurrentServer     = setCurrentServer
M.isGoingMPSession     = isGoingMPSession
M.connectionStatus     = launcherConnectionStatus

print("MPCoreNetwork loaded")

return M
