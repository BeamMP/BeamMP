--====================================================================================
-- All work by Titch2000, jojos38 & 20dka.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading MPCoreSystem.lua...")
setmetatable(_G,{}) -- temporarily disable global notifications

--======================================================= VARIABLES ========================================================
local currentServer = {} -- Store the server we are on
local Servers -- Store all the servers
-- Status: 0 not connected | 
-- 1 connecting - Launcher
-- 2 connected - Launcher
-- 3 connecting - Session
-- 4 connected - Session
local launcherConnectionStatus = 0 
local launcherConnectionTimer = 0
local status = ""
local launcherVersion = ""
local loggedIn = false
local currentModHasLoaded = false
local isMpSession = false
local isGoingMpSession = false
local launcherTimeout = 0
local connectionIssuesShown = false
--[[
Z  -> The client asks the launcher its version
B  -> The client asks the launcher for the servers list
QG -> The client tells the launcher that it's is leaving
C  -> The client asks for the server's mods
--]]
--======================================================= VARIABLES ========================================================


--====================================================== DATA SENDING ======================================================

--
M.send = function(p, s) 
	local r = 'IPC'
	if not p then return end
	local s = s or ''
	if MP then
    if p == 'CORE' then
		  MP.Core(s)
			if MPDebug then MPDebug.packetSent(string.len(s)) end
    elseif p == 'GAME' then
      MP.Game(s)
			if MPDebug then MPDebug.packetSent(string.len(s)) end
    else
      log('M', 'send', "Message Protocol not specified: "..p.." "..s)
    end
	end

	--local r = TCPLauncherSocket:send(string.len(s)..'>'..s)
	if not settings.getValue("showDebugOutput") then return end
  log('M', 'send', 'Sending Data ('..r..'-'..p..'): '..s)
end

--====================================================== DATA SENDING ======================================================

--===================================================== COMMUNICATIONS =====================================================

-- TODO COMMENT HERE
M.connectToLauncher = function()
	if launcherConnectionStatus == 0 then -- If launcher is not connected yet
		log('M', 'connectToLauncher', "Connecting to launcher")
		if MP then
			launcherConnectionStatus = 1
		else
			log('E', 'connectToLauncher', "Failed to find BeamMP Launcher! Please start the BeamMP Launcher")
		end
	end
end

-- TODO COMMENT HERE
M.disconnectLauncher = function(reconnect)
	if launcherConnectionStatus > 0 then -- If player was connected
		log('M', 'disconnectLauncher', "Disconnecting from launcher")
		--TCPLauncherSocket:close()-- Disconnect from server
		launcherConnectionStatus = 0
		launcherConnectionTimer = 0
		isGoingMpSession = false
	end
	if reconnect then 
		M.connectToLauncher() 
	end
end

-- TODO COMMENT HERE
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

-- This is called everytime we receive a TCP message from the launcher. see XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
local function checkLauncherConnection()
	launcherConnectionTimer = 0
	if launcherConnectionStatus == 1 then
		launcherConnectionStatus = 2
		guihooks.trigger('launcherConnected', nil)
	end
	guihooks.trigger('showConnectionIssues', false)
	connectionIssuesShown = false
end

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

local cleanUpSessionMods = false
M.leaveServer = function(goBack)
	isMpSession = false
	isGoingMpSession = false
	print("Reset Session Called!")
	if goBack then
		print("Returning to main menu")
	end
	M.send('CORE', 'QS') -- Tell the launcher that we quit server / session
	M.disconnectLauncher()
	MPVehicleGE.onDisconnect()
	--UI.readyReset()
	status = "" -- Reset status
	--if goBack then endActiveGameMode() end
	if endActiveGameMode() == nil then
		print("ActiveGameMode Ended.")
		returnToMainMenu()
		print("Returned to Main Menu")
		M.connectToLauncher()
		print("Reconnected to Launcher")
		-- resets the instability function back to default
		onInstabilityDetected = function (jbeamFilename) bullettime.pause(true)  log('E', "", "Instability detected for vehicle " .. tostring(jbeamFilename)) ui_message({txt="vehicle.main.instability", context={vehicle=tostring(jbeamFilename)}}, 10, 'instability', "warning")end

		--cleanUpSessionMods = true
	  MPModManager.startCleanUpSessionMods()
	end
end

local function isMPSession()
	return isMpSession
end

local function isGoingMPSession()
	return isGoingMpSession
end

--===================================================== COMMUNICATIONS =====================================================

--=========================================================== UI ===========================================================
-- Called from multiplayer.js UI
M.getLauncherVersion = function()
	-- TODO #200 - Reset this back to using the launcher provided version
	return launcherVersion
end

M.isLoggedIn = function()
	return loggedIn
end

M.isLauncherConnected = function()
	return launcherConnectionStatus > 0
end

M.login = function(identifiers)
	log('M', 'login', 'Attempting login')
	M.send('CORE', 'N:'..identifiers)
end

M.autoLogin = function()
	M.send('CORE', 'Nc')
end

M.logout = function()
	log('M', 'logout', 'Attempting logout')
	M.send('CORE', 'N:LO')
	loggedIn = false
end

M.getServers = function()
	print(launcherVersion)
	-- Get the launcher version
	M.send('CORE', 'Z')
	log('M', 'getServers', "Getting the servers list")
	M.send('CORE', 'B') -- Ask for the servers list
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

M.requestPlayers = function()
	if not isMpSession then
		M.send('CORE', 'B')
	end
	sendBeamMPInfo()
end
--=========================================================== UI ===========================================================

--==================================================== SERVER RELATED  =====================================================

-- Tell the launcher to open the connection to the server so the MPMPCoreSystem can connect to the launcher once ready
M.connectToServer = function(ip, port, mods, name)
	--if getMissionFilename() ~= "" then leaveServer(false) end
	if ip and port then -- Direct connect
		currentServer = nil
		M.setCurrentServer(ip, port, mods, name)
	end

	local ipString = currentServer.ip..':'..currentServer.port
	M.send('CORE', 'C'..ipString..'')

	print("Connecting to server "..ipString)
	status = "LoadingResources"
	launcherConnectionStatus = 3
end

M.connectSessionNetwork = function()
	log('M','connectSessionNetwork',"Attempting to start Game network. Current Mission: "..getMissionFilename())
	if getMissionFilename() ~= "" then
		launcherConnectionStatus = 4
		M.send('CORE', 'A')
	else
		launcherConnectionStatus = 2
		returnToMainMenu()
	end
end

M.resetSession = function ()
	launcherConnectionStatus = 2
	currentServer = nil
	status = ""
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

M.getCurrentServer = function()
	--dump(currentServer)
  return currentServer
end

M.setCurrentServer = function(ip, port, modsString, name)
	currentServer = {
		ip		   = ip,
		port	   = port,
		modsString = modsString,
		name	   = name
	}
	setMods(modsString)
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
		core_gamestate.setGameState('multiplayer', 'multiplayer', 'multiplayer') -- This is added to set the UI elements
		UI.setNickname(data)
		MPConfig.setNickname(data)
	end
end

local function quitMP(reason)
	log('A', "connectionStatus", debug.traceback())
	text = reason~="" and ("Reason: ".. reason) or ""
	log('M','quitMP',"Quit MP Called! reason: "..tostring(reason))

	UI.showMdDialog({
		dialogtype="alert", title="You have been kicked from the server", text=text, okText="Return to menu",
		okLua="MPCoreSystem.leaveServer(true)" -- return to main menu when clicking OK
	})

	--send('CORE', 'QG') -- Quit game
end

local function loadLevel(map)
	if status ~= "LoadingMapNow" then
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
			--MPCoreSystem.disconnectLauncher()
			--MPCoreSystem.connectToLauncher()
		end
		isMpSession = true

		-- replaces the instability detected function with one that doesn't pause physics or sends messages to the UI
		-- but left logging in so you can still see what car it is -- credit to deerboi for showing me that this is possible
		-- it resets to default on leaving the server
		-- we should probably consider a system to detect if a vehicle is in a instability loop and then delete it or respawn it (rapid instabilities causes VE to break on reload so it would need to be respawned)
		onInstabilityDetected = function(jbeamFilename) if not settings.getValue("disableInstabilityPausing") then bullettime.pause(true) ui_message({txt="vehicle.main.instability", context={vehicle=tostring(jbeamFilename)}}, 10, 'instability', "warning") end log('E', "", "Instability detected for vehicle " .. tostring(jbeamFilename)) end
	else
		log('E', 'loadLevel', 'Launcher has Repeated the message to load the map. This shouldnt have happened....')
	end
end
--==================================================== SERVER RELATED  =====================================================

M.modLoaded = function(modname)
	if modname ~= "beammp" then -- We don't want to check beammp mod
		M.send('CORE', 'R'..modname..'')
	end
end

--==================================================== MESSAGE RELATED  ====================================================

local function handleU(params)
	UI.updateLoading(params)
	local code = string.sub(params, 1, 1)
	local data = string.sub(params, 2)
	if code == "l" and launcherConnectionStatus >= 2 then
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
					M.modLoaded(modName)
					currentModHasLoaded = false
				else
					core_modmanager.initDB() -- manually check for new mod
					currentModHasLoaded = true
				end
			end
		end
		
		if data == "done" and status == "LoadingResources" then
			log('W',"handleU", "Mod Loading Complete. Lets now load the map...")
			M.send('CORE', 'Mrequest')
			status = "LoadingMap"
		end
	elseif code == "p" and isMpSession and launcherConnectionStatus > 2 then
		UI.setPing(data.."")
		positionGE.setPing(data)
	end
end

--===================================================== EVENTS SYSTEM  =====================================================
-- Events System
-------------------------------------------------------------------------------

local eventTriggers = {};

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

TriggerServerEvent = function(n, d)
	sendData('E:'..n..':'..d)
end

TriggerClientEvent = function(n, d)
	handleEvents(':'..n..':'..d)
end

AddEventHandler = function(n, f)
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
addKeyEventListener = function(keyname, f, type)
	f = f or function() end
	log('W','AddKeyEventListener', "Adding a key event listener for key '"..keyname.."'")
	table.insert(keypressTriggers, {key = keyname, func = f, type = type or 'both'})
	table.insert(keysToPoll, keyname)

	be:queueAllObjectLua("if true then addKeyEventListener(".. serialize(keysToPoll) ..") end")
end

onKeyPressed = function(keyname, f)
	addKeyEventListener(keyname, f, 'down')
end

onKeyReleased = function(keyname, f)
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

M.getKeyState = function(key)
	return keyStates[key] or false
end

M.onVehicleReady = function(gameVehicleID)
	local veh = be:getObjectByID(gameVehicleID)
	if not veh then
		log('R', 'onVehicleReady', 'Vehicle does not exist!')
		return
	end
	veh:queueLuaCommand("addKeyEventListener(".. serialize(keysToPoll) ..")")
end

--===================================================== EVENTS SYSTEM  =====================================================


--====================================================== CORE HANDLE =======================================================
local HandleCoreNetwork = {
	['B'] = function(params) Servers = params; guihooks.trigger('onServersReceived', params); sendBeamMPInfo() end, -- Serverlist received
	['U'] = function(params) handleU(params) end, -- UI
	['M'] = function(params) loadLevel(params) end,
	['N'] = function(params) loginReceived(params) end, -- Login system
	['V'] = function(params) MPVehicleGE.handle(params) end, -- Vehicle spawn/edit/reset/remove/coupler related event
	['L'] = function(params) setMods(params) end,
	['K'] = function(params) log('E','HandleNetwork','K packet - UNUSED') end, -- Player Kicked Event
	['Z'] = function(params) launcherVersion = params end -- Tell the UI what the launcher version is
}

function handleCoreMsg(msg)
	-- break it up into code + data
	local code = string.sub(msg, 1, 1)
	local data = string.sub(msg, 2)
	if settings.getValue("showDebugOutput") then 
		if code == "B" then
			log('W','handleCoreMsg','Received: '..code..' -> <Server List Data>')
		else
			log('W','handleCoreMsg','Received: '..code..' -> '..data)
		end
	end
	checkLauncherConnection()
	HandleCoreNetwork[code](data)
	if MPDebug then MPDebug.packetReceived(string.len(msg)) end
end

--====================================================== GAME HANDLE =======================================================
local HandleGameNetwork = {
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
	if settings.getValue("showDebugOutput") then 
		log('W','handleGameMsg','Received: '..code..' -> '..data)
	end
	checkLauncherConnection()
	HandleGameNetwork[code](data)
	if MPDebug then MPDebug.packetReceived(string.len(msg)) end
end


--=================================================== MOD INITILISATION ====================================================

M.onInit = function()
	local function split(s, sep)
    local fields = {}
    
    local sep = sep or " "
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)
    
    return fields
	end

	local version = split(beamng_versiond, '.')
	-- Lets make sure that they are not in the middle of a game. This prevents them being presented the main menu when they reload lua while in game.
	if not scenetree.missionGroup and getMissionFilename() == "" then 
		-- Check the game version for if we expect it to be BeamMP compatable. This check adds the UI and Multiplayer Options so that they can then play.
		if version[1] == "0" and version[2] == "25" then
			print('Redirecting to the BeamMP UI for 0.25')
			-- Lets now load the BeamMP Specific UI
			be:executeJS('if (!location.href.includes("local://local/ui/entrypoints/main_0.25/index.html")) {location.replace("local://local/ui/entrypoints/main_0.25/index.html")}')

			if not core_modmanager.getModList then
				Lua:requestReload() 
			end
		elseif version[1] == "0" and version[2] == "23" then
			print('Redirecting to the BeamMP UI for 0.23')
			-- TODO #199 - Add the 0.23 UI here as I did above for 0.24
			if not core_modmanager.getModList then
				Lua:requestReload() 
			end
		else
			print('BeamMP is not compatible with BeamNG.drive v'..beamng_versiond)
			guihooks.trigger('modmanagerError', 'BeamMP is not compatible with BeamNG.drive v'..beamng_versiond)
		end
	end
end

--=================================================== MOD INITILISATION ====================================================

--====================================================== ENTRY POINT =======================================================
M.onExtensionLoaded = function()
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
	M.connectToLauncher()
	-- We reload the UI to load our custom layout
	reloadUI()
	-- Get the launcher version
	M.send('CORE', 'Z')
	-- Log-in
	M.send('CORE', 'Nc')

	local cmdArgs = Engine.getStartingArgs()

	if tableFindKey(cmdArgs, '-networkGraph') then
		if MPDebug then
			MP_Console(1)
		end
	end
end
--====================================================== ENTRY POINT =======================================================


M.onUpdate = function(dt)
	if MP then
		--while (true) do
			local msg = MP:try_pop()
			if msg then
				local code = string.sub(msg, 1, 1)
				local data = string.sub(msg, 2)
				if code == 'C' then
						handleCoreMsg(data)
				else
						handleGameMsg(data)
				end    
			else
				--break
			end
		--end
	end

	if cleanUpSessionMods then
		cleanUpSessionMods = false
		MPModManager.cleanUpSessionMods()
	end

	--====================================================== DATA RECEIVE ======================================================
	if launcherConnectionStatus > 0 then -- If player is connecting or connected
		--================================ SECONDS TIMER ================================
		launcherConnectionTimer = launcherConnectionTimer + dt -- Time in seconds
		--print(launcherConnectionTimer)
		if launcherConnectionTimer > 1 then
			M.send('CORE', 'U') -- Server heartbeat - New and improved to get ping AND ui message ANDDDD The launcher heartbeat!!!!
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
				M.disconnectLauncher(true) -- reconnect to launcher (this breaks the launcher if the connection
				-- TODO #202 Reconnect this back to the active session in case of network loss.
				--connectToServer(currentServer.ip, currentServer.port, currentServer.modsString, currentServer.name)
			end
		end
	end
end

M.onClientStartMission = function(mission)
	if status == "Playing" and getMissionFilename() ~= currentServer.map then
		print("The user has loaded another mission!")
		--Lua:requestReload()
	elseif getMissionFilename() == currentServer.map then
		status = "Playing"
		if settings.getValue('richPresence') then
			if Steam then
				Steam.setRichPresence('status', "BeamMP | On "..currentServer.map)
			end
			if Discord then
				local dActivity = {state="Playing BeamMP",details="In-Game on "..currentServer.map,asset_largeimg="",asset_largetxt="",asset_smallimg="",asset_smalltxt=""}
				Discord.setActivity(dActivity)
			end
		end
	end
end

M.onClientEndMission = function(mission)
	if isMPSession() then
		M.leaveServer(true)
	end
end

M.onUiReady = function()
	if getMissionFilename() == "" then
		M.onInit()
		guihooks.trigger('ChangeState', 'menu.mainmenu')
		if settings.getValue('richPresence') then
			if Steam then
				Steam.setRichPresence('status', beamng_windowtitle)
			end
			if Discord then
				local dActivity = {state="Playing BeamMP",details="In the menus",asset_largeimg="",asset_largetxt="",asset_smallimg="",asset_smalltxt=""}
				Discord.setActivity(dActivity)
			end
		end
	end
end
-- ============= EVENTS =============


M.onSerialize = function()
	return currentServer
end

M.onDeserialized = function(serverInfo)
	if getMissionFilename() == serverInfo.map then
		log('I', 'onDeserialized', 'Previous map matches current, reconnecting')
		M.connectToServer(serverInfo.ip, serverInfo.port, serverInfo.modsString, serverInfo.name)
	end
end

detectGlobalWrites() -- reenable global write notifications


-- Variable Returns:
M.isMPSession          = isMPSession
M.isGoingMPSession     = isGoingMPSession
M.connectionStatus     = function() return launcherConnectionStatus end

print("MPCoreSystem loaded")

return M