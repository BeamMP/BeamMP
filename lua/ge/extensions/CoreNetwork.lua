--====================================================================================
-- All work by Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local M = {}
print("CoreNetwork Initialising...")
local Servers = {}

-- ============= VARIABLES =============
--local socket = require('socket')
local TCPSocket
local Server = {};
local launcherConnectionStatus = 0 -- Status: 0 not connected | 1 connecting | 2 connected
local oneSecondsTimer = 1
local updateTimer = 0
local flip = false
local serverTimeoutTimer = 0
local playersMap = {}
local sysTime = 0
local timeoutMax = 60 --TODO: SET THE TIMER TO 30 SECONDS
local timeoutWarn = 10 --TODO: SET THE TIMER TO 5 SECONDS ONCE WE ARE MORE STREAMLINED
local status = ""
-- ============= VARIABLES =============

--================================ CONNECT TO SERVER ================================
local function connectToLauncher()
	if launcherConnectionStatus == 0 then
		local socket = require('socket')
		TCPSocket = socket.tcp() -- Set socket to TCP
		--TCPSocket:setoption("tcp-nodelay", true)
		keep = TCPSocket:setoption("keepalive",true)

		TCPSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
		TCPSocket:connect('127.0.0.1', 4444); -- Connecting
		launcherConnectionStatus = 1
		--send(buildPacket(1, 2000, 0, Network.nickname..":"..getMissionFilename())) -- Send connection packet
	end
end
--================================ CONNECT TO SERVER ================================

--====================== DISCONNECT FROM SERVER ======================
local function disconnectLauncher()
	if launcherConnectionStatus > 0 then -- If player were connected
		TCPSocket:close()-- Disconnect from server
		serverTimeoutTimer = 0 -- Reset timeout delay
		launcherConnectionStatus = 0
		oneSecondsTimer = 0
	end
end
--====================== DISCONNECT FROM SERVER ======================

connectToLauncher()
--TorqueScript.setVar("$CEF_UI::reload") Need to find a way to reload
reloadUI()

local function getServers()
	TCPSocket:send('B')
end

local function setServer(id, ip, port)
	Server.IP = ip;
	Server.PORT = port;
	Server.ID = id;
end

local function connectToServer(ip, port)
	if ip ~= undefined and port ~= undefined then
		TCPSocket:send('C'..ip..':'..port)
	else
		TCPSocket:send('C'..Server.IP..':'..Server.PORT)
	end
	status = "LoadingResources"
end

local function LoadLevel(map)
	print("MAP: "..map)
	status = "LoadingMapNow"
	if string.sub(map, 1, 1) == "/" then
		print("Searching For Map...")
		local levelName = string.gsub(map, '/info.json', '')
		levelName = string.gsub(levelName, '/levels/', '')
		for i, v in ipairs(core_levels.getList()) do
			print(v.levelName)
	    if v.levelName:lower() == levelName then
				print("Loading Multiplayer Map...")
				freeroam_freeroam.startFreeroamByName(v.levelName)
				break;
	    end
	  end
		-- we got this far?!?!?! Guess we dont have the level
		print("MAP NOT FOUND!!!!!... DID WE MISS SOMETHING??")
	else
		-- Level Not a set map, lets give them the choice to select
	end
end

local function onPlayerConnect() -- Function called when a player connect to the server
	updatesGE.onPlayerConnect()
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
	end
end

local HandleNetwork = {
	['A'] = function(params) oneSecondsTimer = 0; flip = false; end, -- Connection Alive Checking
	['B'] = function(params) Servers = params; be:executeJS('receiveServers('..params..')') end,
	['U'] = function(params) HandleU(params) end,
	['M'] = function(params) LoadLevel(params) end,
	['V'] = function(params) vehicleGE.handle(params) end,

	['K'] = function(params) quitMPWithMessage(params) end, -- Player Kicked Event
	['E'] = function(params)  end, -- Event For another Resource
	['C'] = function(params) UI.chatMessage(params) end, -- Chat Message Event
	['J'] = function(params) onPlayerConnect() end, -- A player Joined
	--[''] = function(params)  end, --
	--[''] = function(params)  end, --
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
		oneSecondsTimer = oneSecondsTimer + dt -- Time in seconds
		updateTimer = updateTimer + dt -- Time in seconds
		if updateTimer > 1 then
			TCPSocket:send('Up')
			if status == "LoadingResources" then
			  print("Sending 'Ul'")
			  TCPSocket:send('Ul')
			end
			updateTimer = 0
		end
		if oneSecondsTimer > 1 and not flip then -- If oneSecondsTimer pass 2 seconds
			TCPSocket:send('A')
			flip = true
			--oneSecondsTimer = 0	-- Reset timer
		end
		if oneSecondsTimer > 2 and flip and dt > 20000 then -- If oneSecondsTimer pass 2 seconds
			disconnectLauncher()
			connectToLauncher()
			flip = false
			--oneSecondsTimer = 0	-- Reset timer
		end
		--================================ TWO SECONDS TIMER ================================
	end
end

local function resetSession(x)
	print("[CoreNetwork] Reset Session Called!")
	TCPSocket:send('QS')
	disconnectLauncher()
	GameNetwork.disconnectLauncher()
	vehicleGE.onDisconnect()
	connectToLauncher()
	if x then
		returnToMainMenu()
	end
end

local function quitMP()
	print("[CoreNetwork] Reset Session Called!")
	TCPSocket:send('QG')
end

local function quitMPWithMessage()
	print("[CoreNetwork] Reset Session Called!")
	TCPSocket:send('QG')
end

M.onUpdate = onUpdate
M.getServers = getServers
M.setServer = setServer
M.resetSession = resetSession
M.quitMP = quitMP
M.connectToServer = connectToServer
M.connectionStatus = launcherConnectionStatus

print("CoreNetwork Loaded.")
return M
