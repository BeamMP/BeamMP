--====================================================================================
-- All work by Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local M = {}

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
-- ============= VARIABLES =============

--================================ CONNECT TO SERVER ================================
local function connectToLauncher()
	if launcherConnectionStatus == 0 then
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

local function getServers()
	TCPSocket:send('B')
end


local HandleNetwork = {
	['A'] = function(params) oneSecondsTimer = 0; flip = false; end, -- Connection Alive Checking
	['B'] = function(params) be:executeJS('receiveServers('..params..')') end
}

local function onUpdate(dt)
	--====================================================== DATA RECEIVE ======================================================
	if launcherConnectionStatus > 0 then -- If player is connecting or connected
		while (true) do
			local received, status, partial = TCPSocket:receive() -- Receive data
			if received == nil then break end
			if received ~= "" and received ~= nil then -- If data have been received then
				print(status)
				print(received)
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
		if oneSecondsTimer > 1 and not flip then -- If oneSecondsTimer pass 2 seconds
			TCPSocket:send('A')
			flip = true
			--oneSecondsTimer = 0	-- Reset timer
		end
		if oneSecondsTimer > 2 and flip then -- If oneSecondsTimer pass 2 seconds
			disconnectLauncher()
			connectToLauncher()
			flip = false
			--oneSecondsTimer = 0	-- Reset timer
		end
		--================================ TWO SECONDS TIMER ================================
	end
end

M.onUpdate = onUpdate
M.getServers = getServers

return M
