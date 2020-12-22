--====================================================================================
-- All work by Titch2000 and jojos38.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}
print("Loading MPCoreNetwork")



-- ============= VARIABLES =============
local TCPLauncherSocket -- Launcher socket
local currentServer -- Store the server we are on
local Servers = {} -- Store all the servers
local launcherConnectionStatus = 0 -- Status: 0 not connected | 1 connecting | 2 connected
local secondsTimer = 0
local MapLoadingTimeout = 0
local status = ""
local launcherVersion = ""
local currentMap = ""
local mapLoaded = false
local isMpSession = false
local isGoingMpSession = false
--[[
Z -> The client ask to the launcher his version
B -> The client ask for the servers list to the launcher
QG -> The client tell the launcher that he is leaving
C -> The client ask for the mods to the server
--]]
-- ============= VARIABLES =============



local function connectToLauncher()
	if launcherConnectionStatus == 0 then -- If launcher is not connected yet
		print("Connecting to launcher")
		local socket = require('socket')
		TCPLauncherSocket = socket.tcp()
		TCPLauncherSocket:setoption("keepalive", true) -- Keepalive to avoid connection closing too quickly
		TCPLauncherSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
		TCPLauncherSocket:connect('127.0.0.1', (settings.getValue("launcherPort") or 4444));
		launcherConnectionStatus = 1
	end
end



local function disconnectLauncher()
	if launcherConnectionStatus > 0 then -- If player was connected
		print("Disconnecting from launcher")
		TCPLauncherSocket:close()-- Disconnect from server
		launcherConnectionStatus = 0
		serverTimeoutTimer = 0 -- Reset timeout delay
		secondsTimer = 0
		isGoingMpSession = false
	end
end



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



local function send(s)
	local r = TCPLauncherSocket:send(string.len(s)..'>'..s)
	if settings.getValue("showDebugOutput") == true then
		print('[MPCoreNetwork] Sending Data ('..r..'): '..s)
	end
end



local function getServers()
	print("Getting the servers list")
	send('Z')
	send('B')
	send('Nc')
end



local function getCurrentServer()
    return currentServer
end



local function setCurrentServer(id, ip, port, modsString, name)
	currentServer = {
		ip		   = ip,
		port	   = port,
		id		   = id,
		modsstring = modsString,
		name	   = name
	}
	setMods(modString)
end



-- Tell the launcher to open the connection to the server so the MPMPGameNetwork can connect to the launcher once ready
local function connectToServer(ip, port)
	-- Prevent the user from connecting to a server when already connected to one
	if getMissionFilename() ~= "" then Lua:requestReload() end
	local ipString
	if ip and port then -- Direct connect
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
	MapLoadingTimeout = 0
	mapLoaded = false
	status = "LoadingMapNow"
	currentMap = map
	multiplayer_multiplayer.startMultiplayer(map)
	isMpSession = true
end



local function handleU(params)
	UI.updateLoading(params)
	local code = string.sub(params, 1, 1)
	local data = string.sub(params, 2)
	if params == "ldone" and status == "LoadingResources" then
		send('Mrequest')
		status = "LoadingMap"
	end
	if code == "p" then
		UI.setPing(data.."")
		positionGE.setPing(data)
	end
end



local function HandleLogin(params)
	print('Logging in')
	local r = jsonDecode(params)
	if (r.success == true or r.Auth == 1) then
		print('Logged successfully')
		guihooks.trigger('LoginContainerController', {message = "success", hide = true})
	else
		local m = r.message or ''
		guihooks.trigger('LoginError', {message = m})
	end
end



local HandleNetwork = {
	['A'] = function(params) secondsTimer = 0; end, -- Connection Alive Checking
	['B'] = function(params) Servers = params; be:executeJS('receiveServers('..params..')'); end,
	['U'] = function(params) handleU(params) end, -- UI
	['M'] = function(params) loadLevel(params) end,
	['N'] = function(params) HandleLogin(params) end, -- Login system
	['V'] = function(params) MPVehicleGE.handle(params) end,
	['L'] = function(params) setMods(params) end,
	['K'] = function(params) quitMP(params) end, -- Player Kicked Event
	['Z'] = function(params) launcherVersion = params; be:executeJS('setClientVersion('..params..')'); end, -- Tell the UI what the launcher version is.
	-- [''] = function(params)  end, --
}



local function onUpdate(dt)
	--print(secondsTimer)
	--====================================================== DATA RECEIVE ======================================================
	if launcherConnectionStatus > 0 then -- If player is connecting or connected
		while (true) do
			local received, status, partial = TCPLauncherSocket:receive() -- Receive data
			if received == nil or received == "" then break end
			-- break it up into code + data
			local code = string.sub(received, 1, 1)
			local data = string.sub(received, 2)
			HandleNetwork[code](data)
		end

		--================================ SECONDS TIMER ================================
		secondsTimer = secondsTimer + dt -- Time in seconds
		if secondsTimer > 0.5 then
			send('A') -- Launcher heartbeat
			if status == "LoadingResources" then send('Ul') -- Ask the launcher for a loading screen update
			else send('Up') end -- Server heartbeat
			secondsTimer = 0 -- this might break resource loading
		end
		-- If secondsTimer is more than 5 seconds has timed out / crashed.
		if secondsTimer > 5 then -- and dt > 20000
			print("Timed out")
			UI.setPing("-2")
			disconnectLauncher()
			connectToLauncher()
		end
		--================================ MAP LOADING TIMER ================================
		if status == "LoadingMapNow" then
			if MapLoadingTimeout > 5 then
				if not mapLoaded then -- If map is not loaded yet
					if not scenetree.MissionGroup then -- If not found then
						print("Failed to load the map, did the mod get loaded?")
						Lua:requestReload()
					else
						status = "Playing"
						mapLoaded = true
					end
				end
			else
				MapLoadingTimeout = MapLoadingTimeout + dt
			end
		end
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
	UI.readyReset()
	status = "" -- Reset status
	if goBack then returnToMainMenu() end
	MPModManager.cleanUpSessionMods()
end



local function quitMP()
	isMpSession = false
	isGoingMpSession = false
	print("Reset Session Called!")
	send('QG') -- Quit game
end



local function modLoaded(modname)
	if modname ~= "beammp" then -- We don't want to check beammp mod
		send('R'..modname..'')
	end
end



local function onInit()
	--Preston (Cobalt) Preload the UI profile for multiplayer
	local layouts = jsonReadFile("settings/uiapps-layouts.json")
	if not layouts then
		layouts = jsonReadFile("settings/uiapps-defaultLayout.json")
		jsonWriteFile("settings/uiapps-layouts.json", layouts)
		log("A","Print","default UI layout added")
	end
	if not layouts.multiplayer then
		layouts.multiplayer = jsonReadFile("settings/uiapps-defaultMultiplayerLayout.json")
		jsonWriteFile("settings/uiapps-layouts.json", layouts)
		log("A","Print","multiplayer UI layout added")
	end

	-- First we connected to the launcher
	connectToLauncher()
	-- Then we check that the game has loaded our mod manager, if not we reload lua
	if not core_modmanager.getModList then Lua:requestReload() end
	-- We reload the UI to load our custom UI
	reloadUI()
	-- We reset "serverConnection" because for some reasons singleplayer doesn't work without this
	local endCallback = function () if type(callback) == 'function' then callback() end end
	serverConnection.disconnect(endCallback)
	-- ???
	send('Nc')
end



local function isMPSession()
	return isMpSession
end



local function isGoingMPSession()
	return isGoingMpSession
end



local function login(d)
	print('Attempting login')
	send('N:'..d..'')
end



local function onClientStartMission(mission)
	if status == "Playing" and getMissionFilename() ~= currentMap then
		print("The user has loaded another mission!")
		Lua:requestReload()
	end
	if isMPSession() then
		MPModManager.backupLoadedMods() -- Backup the current loaded mods
		MPModManager.checkAllMods() -- Checking all the mods
	end
	-- Checking all the mods again because BeamNG.drive have a bug with mods not deactivating
end



local function onClientEndMission(mission)
	if isMPSession() then
		resetSession(1)
	end
end



local function addRecent()
	guihooks.trigger('addRecent', jsonEncode(currentServer))
end



M.onInit = onInit
M.login = login
M.onClientStartMission = onClientStartMission
M.onClientEndMission = onClientEndMission
M.onUpdate = onUpdate
M.getServers = getServers
M.getCurrentServer = getCurrentServer
M.setCurrentServer = setCurrentServer
M.resetSession = resetSession
M.quitMP = quitMP
M.connectToServer = connectToServer
M.connectionStatus = launcherConnectionStatus
M.modLoaded = modLoaded
M.onInit = onInit
M.isMPSession = isMPSession
M.isGoingMPSession = isGoingMPSession
M.addRecent = addRecent


return M
