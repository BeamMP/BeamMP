--====================================================================================
-- All work by Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local M = {}
print("GameNetwork Initialising...")

-- ============= VARIABLES =============
--local socket = require('socket')
local TCPSocket
local launcherConnectionStatus = 0 -- Status: 0 not connected | 1 connecting | 2 connected
local oneSecondsTimer = 1
local flip = false
local playersMap = {}
local sysTime = 0
local timeoutMax = 60 --TODO: SET THE TIMER TO 30 SECONDS
local timeoutWarn = 10 --TODO: SET THE TIMER TO 5 SECONDS ONCE WE ARE MORE STREAMLINED
local status = ""
-- ============= VARIABLES =============


--================================ CONNECT TO SERVER ================================
local function connectToLauncher()
	print("Connecting to the Launcher for Session Data")
	if launcherConnectionStatus == 0 then
		local socket = require('socket')
		TCPSocket = socket.tcp() -- Set socket to TCP
		--TCPSocket:setoption("tcp-nodelay", true)
		keep = TCPSocket:setoption("keepalive",true)

		TCPSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
		TCPSocket:connect('127.0.0.1', 4445); -- Connecting
		launcherConnectionStatus = 1
		print("[GameNetwork] Status Changed: "..launcherConnectionStatus)
	end
end
--================================ CONNECT TO SERVER ================================

--====================== DISCONNECT FROM SERVER ======================
local function disconnectLauncher()
	if launcherConnectionStatus > 0 then -- If player were connected
		TCPSocket:close()-- Disconnect from server
		launcherConnectionStatus = 0
		oneSecondsTimer = 0
	end
end
--====================== DISCONNECT FROM SERVER ======================

local function sendData(data)
	--print('[GameNetwork] Sending Data: '..data)
	TCPSocket:send(data)
end

local function sendDataSplit(code, ID, data)
	--print('[GameNetwork] Sending Data: '..data)
	local counter = 1 -- 1, 2, 3, n, E
	local size = string.len(data)
	local maxSize = 5000
	while size > maxSize do
		local tdata = string.sub(data, 1, maxSize)
		TCPSocket:send(code..id..counter..":"..tdata)
		data = string.sub(data, 5001, size) --data:gsub(tdata, "")
		size = string.len(data)
		counter = counter + 1
	end
	TCPSocket:send(code..id.."E:"..data)
end

local HandleNetwork = {
	['V'] = function(params) inputsGE.handle(params) end,
	['W'] = function(params) electricsGE.handle(params) end,
	['X'] = function(params) nodesGE.handle(params) end,
	['Y'] = function(params) powertrainGE.handle(params) end,
	['Z'] = function(params) positionGE.handle(params) end,
	['O'] = function(params) vehicleGE.handle(params) end,
	['P'] = function(params) mpConfig.setPlayerServerID(params) end,
}

local oneSecondsTimer = 0
local dataArray = {}
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
				--print(code.." -> "..data)
				if code == "X" then
					--n:ID:part:data
					data = string.sub(data, 2, string.len(data))
					local vid = string.match(data,"(%w+)%:")
					data = data:gsub(vid..":", "")
					local part = string.match(data,"(%w+)%:")
					data = data:gsub(part..":", "")
					local nData = string.match(data,":(.*)")
					if part == "1"  or part == 1 then
						dataArray[vid] = ""
						dataArray[vid] = nData
					else
						dataArray[vid] = dataArray[vid] .. nData
					end
					if part == "E" then
						HandleNetwork[code]("n:"..dataArray[vid])
					end
				else
					HandleNetwork[code](data)
				end
			end
		end
		--================================ TWO SECONDS TIMER ================================
		oneSecondsTimer = oneSecondsTimer + dt -- Time in seconds
		if oneSecondsTimer > 1 and not flip then -- If oneSecondsTimer pass 1 seconds
			TCPSocket:send('TEST')
			print("ONE SEC TIMER REACHED, TIME OUT??")
			oneSecondsTimer = 0	-- Reset timer
			flip = true
		end
		if oneSecondsTimer > 2 and flip and dt > 5000 then -- If oneSecondsTimer pass 2 seconds
			print("TWO SEC TIMER REACHED, TIME OUT MOST LIKELY??")
			disconnectLauncher()
			connectToLauncher()
			flip = false
		end
	end
end

local function connectionStatus()
	return launcherConnectionStatus
end

M.onUpdate = onUpdate
M.connectToLauncher = connectToLauncher
M.disconnectLauncher = disconnectLauncher
M.send = sendData
M.sendSplit = sendDataSplit
M.connectionStatus = connectionStatus

print("GameNetwork Loaded.")
return M
