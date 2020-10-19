--====================================================================================
-- All work by Titch2000 and jojos38.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}
print("CoreNetwork initialising...")



-- ============= VARIABLES =============
local TCPSocket
local Server = {} -- Store the server we are on
local Servers = {} -- Store all the servers
local launcherConnectionStatus = 0 -- Status: 0 not connected | 1 connecting | 2 connected
local secondsTimer = 1
local updateTimer = 0
local flip = false
local serverTimeoutTimer = 0
local MapLoadingTimeout = 0
local status = ""
local LauncherVersion = ""
-- ============= VARIABLES =============



--================================ CONNECT TO LAUNCHER ================================
local function connectToLauncher()
	if launcherConnectionStatus == 0 then -- If launcher is not connected yet
		local socket = require('socket')
		TCPSocket = socket.tcp()
		TCPSocket:setoption("keepalive",true) -- Keepalive to avoid connection closing too quickly
		TCPSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
		TCPSocket:connect('127.0.0.1', settings.getValue("launcherPort")); -- FIXME Better way to save settings and config
		launcherConnectionStatus = 1
	end
end
connectToLauncher()
reloadUI()
--================================ CONNECT TO LAUNCHER ================================



--====================== DISCONNECT FROM SERVER ======================
local function disconnectLauncher()
	if launcherConnectionStatus > 0 then -- If player was connected
		TCPSocket:close()-- Disconnect from server
		launcherConnectionStatus = 0
		serverTimeoutTimer = 0 -- Reset timeout delay
		oneSecondsTimer = 0
	end
end
--====================== DISCONNECT FROM SERVER ======================



local function getServers()
	print("Getting the servers list")
	TCPSocket:send('Z')
	TCPSocket:send('B')
end



local function cancelConnection()
	TCPSocket:send('QS')
end



local function setServer(id, ip, port, mods, name)
	Server.IP = ip;
	Server.PORT = port;
	Server.ID = id;
	Server.MODSTRING = mods
	Server.NAME = name
	local mods = {}
	for str in string.gmatch(Server.MODSTRING, "([^;]+)") do
		table.insert(mods, str)
	end
	for k,v in pairs(mods) do
		mods[k] = mods[k]:gsub("Resources/Client/",""):gsub(".zip",""):gsub(";","")
	end
	dump(mods)
	mpmodmanager.setServerMods(mods)
	for k,v in pairs(mods) do
		core_modmanager.activateMod(string.lower(v))--'/mods/'..string.lower(v)..'.zip')
	end
end



local function SetMods(s)
	local mods = {}
	for str in string.gmatch(s, "([^;]+)") do
		table.insert(mods, str)
	end
	for k,v in pairs(mods) do
		mods[k] = mods[k]:gsub("Resources/Client/","")
		mods[k] = mods[k]:gsub(".zip","")
		mods[k] = mods[k]:gsub(";","")
	end
	dump(mods)
	mpmodmanager.setServerMods(mods)
end

local function connectToServer(ip, port, modString)
	if ip ~= undefined and port ~= undefined then
		TCPSocket:send('C'..ip..':'..port)
	else
		TCPSocket:send('C'..Server.IP..':'..Server.PORT)
		local mods = {}
		for str in string.gmatch(Server.MODSTRING, "([^;]+)") do
      table.insert(mods, str)
    end
		for k,v in pairs(mods) do
			mods[k] = mods[k]:gsub("Resources/Client/","")
			mods[k] = mods[k]:gsub(".zip","")
			mods[k] = mods[k]:gsub(";","")
		end
		dump(mods)
		mpmodmanager.setServerMods(mods)
	end
	status = "LoadingResources"
end
local Found = false
local function LoadLevel(map)
	MapLoadingTimeout = 0
	Found = false
	status = "LoadingMapNow"
	local found = false
	print("MAP: "..map)
	freeroam_freeroam.startFreeroam(map)
end

local function HandleU(params)
	UI.updateLoading(params)
	--print(params)
	local code = string.sub(params, 1, 1)
	local data = string.sub(params, 2)
	if params == "ldone" and status == "LoadingResources" then
		TCPSocket:send('Mrequest')
		status = "LoadingMap"
	end
	if code == "p" then

		UI.setPing(data.."")
		positionGE.setPing(data)
	end
end

local HandleNetwork = {
	['A'] = function(params) oneSecondsTimer = 0; flip = false; end, -- Connection Alive Checking
	['B'] = function(params) Servers = params; be:executeJS('receiveServers('..params..')'); print("Server List Received.") end,
	['U'] = function(params) HandleU(params) end,
	['M'] = function(params) LoadLevel(params) end,
	['V'] = function(params) vehicleGE.handle(params) end,
	['L'] = function(params) SetMods(params) end,
	['K'] = function(params) quitMPWithMessage(params) end, -- Player Kicked Event
	['Z'] = function(params) LauncherVersion = params; be:executeJS('setClientVersion('..params..')'); print("LauncherVersion: "..params..".") end, -- Tell the UI what the launcher version is.
	-- [''] = function(params)  end, --
}



local function onUpdate(dt)
	--====================================================== DATA RECEIVE ======================================================
	if launcherConnectionStatus > 0 then -- If player is connecting or connected
		while (true) do
			local received, status, partial = TCPSocket:receive() -- Receive data
			if received == nil then break end
			if received ~= "" and received ~= nil then -- If data have been received then
				--print(received)
				-- break it up into code + data
				local code = string.sub(received, 1, 1)
				local data = string.sub(received, 2)
				--print('Code: '..code)
				--print('Data: '..data)
				HandleNetwork[code](data)
			end
		end
		--================================ TWO SECONDS TIMER ================================
		secondsTimer = secondsTimer + dt -- Time in seconds
		updateTimer = updateTimer + dt -- Time in seconds
		if updateTimer > 1 then
			TCPSocket:send('Up') -- Update ping (keepalive)
			if status == "LoadingResources" then
			  --print("Sending 'Ul'")
			  TCPSocket:send('Ul') -- Ask the launcher for an loading screen update
			end
			updateTimer = 0
		end
		-- Called only once (using flip)
		if secondsTimer > 1 and not flip then
			TCPSocket:send('A')
			flip = true
		end
		-- If secondsTImer is more than 2 seconds and the game tick time is greater
		-- than 20000 then our game is running very slow and or has timed out / crashed.
		if secondsTimer > 2 and flip and dt > 20000 then
			disconnectLauncher()
			connectToLauncher()
			flip = false
		end
		--================================ FIVE SECONDS TIMER ================================
		if status == "LoadingMapNow" then
			if MapLoadingTimeout > 5 then
				if not Found then
					if scenetree.MissionGroup == nil then --if not found then
						print("Failed to load the map, did the mod get loaded? -> Going back")
						Lua:requestReload()
					else
						Found = true
					end
				end
			else
				MapLoadingTimeout = MapLoadingTimeout + dt
			end
		end
	end
end

local function resetSession(x)
	print("[CoreNetwork] Reset Session Called!")
	TCPSocket:send('QS') -- Tell the launcher that we quit server / session
	disconnectLauncher()
	GameNetwork.disconnectLauncher()
	vehicleGE.onDisconnect()
	connectToLauncher()
	UI.readyReset()
	status = "" -- Reset status
	if x then returnToMainMenu() end
	mpmodmanager.cleanUpSessionMods()
end

local function quitMP()
	print("[CoreNetwork] Reset Session Called!")
	TCPSocket:send('QG') -- Quit game
end

local function quitMPWithMessage()
	print("[CoreNetwork] Reset Session Called!")
	TCPSocket:send('QG') -- Quit game
end

local function modLoaded(modname)
	if modname ~= "beammp" then -- We don't want to check beammp mod
		TCPSocket:send('R'..modname)
	end
end

M.onUpdate = onUpdate
M.getServers = getServers
M.setServer = setServer
M.resetSession = resetSession
M.quitMP = quitMP
M.connectToServer = connectToServer
M.connectionStatus = launcherConnectionStatus
M.modLoaded = modLoaded
M.Server = Server

print("CoreNetwork Loaded.")
core_gamestate.requestExitLoadingScreen('MP')
returnToMainMenu()

return M
