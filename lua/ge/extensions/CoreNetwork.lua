--====================================================================================
-- All work by Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local M = {}

-- ============= VARIABLES =============
local socket = require('socket')
local TCPSocket
local launcherConnectionStatus = 0 -- Status: 0 not connected | 1 connecting | 2 connected
local twoSecondsTimer = 2
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
		TCPSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
		TCPSocket:connect('127.0.0.1', 4444); -- Connecting
		launcherConnectionStatus = 1
		--send(buildPacket(1, 2000, 0, Network.nickname..":"..getMissionFilename())) -- Send connection packet
	end
end
--================================ CONNECT TO SERVER ================================

connectToLauncher()
local function onUpdate(dt)
	if launcherConnectionStatus > 0 then
		local received, status, partial = TCPSocket:receive() -- Receive data
		print(received)
		print(status)
		print(partial)
		--if received == nil then break end  -- ???????????
		if received ~= "" and received ~= nil then -- If data have been received then
			print(received)
			-- break it up into code + data
			local code = string.sub(received, 1, 1)
			local data = string.sub(received, 2)
			print('Code: '..code)
			print('Data: '..data)
			HandleNetwork[code](data)
		end

		--================================ TWO SECONDS TIMER ================================
		twoSecondsTimer = twoSecondsTimer + dt -- Time in seconds
		if twoSecondsTimer > 2 then -- If twoSecondsTimer pass 2 seconds
			TCPSocket:send('A\n')
			twoSecondsTimer = 0	-- Reset timer
		end
		--================================ TWO SECONDS TIMER ================================
	end
end

local HandleNetwork = {
	['A'] = function(params) print(params) end,
}

M.onUpdate = onUpdate

return M
