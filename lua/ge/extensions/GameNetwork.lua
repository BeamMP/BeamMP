--====================================================================================
-- All work by Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local M = {}
print("GameNetwork Loaded.")

-- ============= VARIABLES =============
local socket = require('socket')
local TCPSocket
local launcherConnectionStatus = 0 -- Status: 0 not connected | 1 connecting | 2 connected
local oneSecondsTimer = 1
local flip = false
local serverTimeoutTimer = 0
local playersMap = {}
local serverPlayerID = ""
local sysTime = 0
local pingStatus = "ready"
local pingTimer = 0
local timeoutMax = 60 --TODO: SET THE TIMER TO 30 SECONDS
local timeoutWarn = 10 --TODO: SET THE TIMER TO 5 SECONDS ONCE WE ARE MORE STREAMLINED
local status = ""
-- ============= VARIABLES =============

--================================ CONNECT TO SERVER ================================
local function connectToLauncher()
	print("Connecting to the Launcher for Session Data")
	if launcherConnectionStatus == 0 then
		TCPSocket = socket.tcp() -- Set socket to TCP
		--TCPSocket:setoption("tcp-nodelay", true)
		keep = TCPSocket:setoption("keepalive",true)

		TCPSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
		TCPSocket:connect('127.0.0.1', 4445); -- Connecting
		launcherConnectionStatus = 1
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

local function sendData(data)
	TCPSocket:send(data)
end

local HandleNetwork = {
	['I'] = function(params) inputsGE.handle(params) end,
	['E'] = function(params) electricsGE.handle(params) end,
	['N'] = function(params) nodesGE.handle(params) end,
	['V'] = function(params) vehicleGE.handle(params) end,
	['P'] = function(params) powertrainGE.handle(params) end,
	['L'] = function(params) positionGE.handle(params) end,
}

local oneSecondsTimer = 0
local function onUpdate(dt)
	--====================================================== DATA RECEIVE ======================================================
	if launcherConnectionStatus > 0 then -- If player is connecting or connected
		while (true) do
			local received, status, partial = TCPSocket:receive() -- Receive data
			if received == nil then break end
			if received ~= "" and received ~= nil then -- If data have been received then
				-- break it up into code + data
				local code = string.sub(received, 1, 1)
				local data = string.sub(received, 2)
				print(code.." -> "..data)
				HandleNetwork[code](data)
			end
			oneSecondsTimer = oneSecondsTimer + dt -- Time in seconds
			if oneSecondsTimer > 1 then -- If oneSecondsTimer pass 2 seconds
				TCPSocket:send('TEST')
				oneSecondsTimer = 0	-- Reset timer
			end
		end
	end
end

M.onUpdate = onUpdate
M.connectToLauncher = connectToLauncher
M.send = sendData
M.connectionStatus = launcherConnectionStatus

return M
