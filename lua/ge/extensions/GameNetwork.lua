--====================================================================================
-- All work by Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local M = {}
print("GameNetwork Initialising...")

-- ============= VARIABLES =============
--local socket = require('socket')
local TCPSocket
local BigDataSocket
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
		BigDataSocket = socket.tcp() -- Set socket to TCP
		--TCPSocket:setoption("tcp-nodelay", true)
		keep = TCPSocket:setoption("keepalive",true)
		keep2 = BigDataSocket:setoption("keepalive",true)

		TCPSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
		TCPSocket:connect('127.0.0.1', 4445); -- Connecting
		BigDataSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
		BigDataSocket:connect('127.0.0.1', 4446); -- Connecting
		launcherConnectionStatus = 1
		print("[GameNetwork] Status Changed: "..launcherConnectionStatus)
	end
end
--================================ CONNECT TO SERVER ================================

--====================== DISCONNECT FROM SERVER ======================
local function disconnectLauncher()
	if launcherConnectionStatus > 0 then -- If player were connected
		TCPSocket:close()-- Disconnect from server
		BigDataSocket:close()-- Disconnect from server
		launcherConnectionStatus = 0
		oneSecondsTimer = 0
		flip = false
	end
end
--====================== DISCONNECT FROM SERVER ======================

local function sendData(data)
	local r = TCPSocket:send(data..'')
	if settings.getValue("showDebugOutput") == true then
    print('[GameNetwork] Sending Data ('..r..'): '..data)
	end
end

local function sendDataSplit(code, ID, data)
	--print('[GameNetwork] Sending Data: '..data)
	local counter = 97 -- 1, 2, 3, n, E
	local size = string.len(data)
	local maxSize = 6500
	while size > maxSize do
		--print("Running: "..size)
		local tdata = string.sub(data, 1, maxSize)
		BigDataSocket:send(code..ID..string.char(counter)..":"..tdata..'')
		data = string.sub(data, 6501, size) --data:gsub(tdata, "")
		size = string.len(data)
		counter = counter + 1
	end
	--print("Done: "..size)
	BigDataSocket:send(code..ID.."E:"..data..'')
end

local function onPlayerConnect() -- Function called when a player connect to the server
	updatesGE.onPlayerConnect()
end

local function sessionData(data)
	local code = string.sub(data, 1, 1)
	local data = string.sub(data, 2)
	if code == "s" then
		--print(data)
		local players = string.match(data,"(.*)%:")
		data = string.match(data, ":(.*)")
		--print(players)
		--print(data)
		UI.updatePlayersList(data)
		UI.setPlayerCount(players)
	end
	if code == "n" then
		UI.setNickName(data)
		mpConfig.setNickname(data)
	end
end

local eventTriggers = {}

function AddEventHandler(n, f)
	print("Adding Event Handler: Name = "..tostring(n))
	table.insert(eventTriggers, {name = n, func = f})
	dump(eventTriggers)
end

local function handleEvents(p)  --- E:<NAME>:data
	local eventName = string.match(p,"(%w+)%:")
	local data = p:gsub(eventName..":", "")
	for i=1,#eventTriggers do
		if eventTriggers[i].name == eventName then
			eventTriggers[i].func(data)
		end
	end
end

local HandleNetwork = {
	['V'] = function(params) inputsGE.handle(params) end,
	['W'] = function(params) electricsGE.handle(params) end,
	['X'] = function(params) nodesGE.handle(params) end,
	['Y'] = function(params) powertrainGE.handle(params) end,
	['Z'] = function(params) positionGE.handle(params) end,
	['O'] = function(params) vehicleGE.handle(params) end,
	['P'] = function(params) mpConfig.setPlayerServerID(params) end,
	['J'] = function(params) onPlayerConnect() UI.showNotification(params) end, -- A player Joined
	['L'] = function(params) UI.showNotification(params) end, -- A player Joined
	['S'] = function(params) sessionData(params) end, -- Update Session Data
	['E'] = function(params) handleEvents(params) end, -- Event For another Resource
	['T'] = function(params) CoreNetwork.resetSession('true') end, -- Event For another Resource
	['C'] = function(params) UI.chatMessage(params) end, -- Chat Message Event
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
					--print("Data: "..data)
					local vid = string.match(data,"(%w+)%:")
					--print("VID: "..vid.."")
					data = string.sub(data, string.len(vid..":")+1, string.len(data))
					--print("Data: "..data)
					local part = string.byte(string.match(data,"(%w+)%:")) - 96
					--print("Part: "..part)
					data = string.sub(data, string.len(part..":"), string.len(data))
					--print("Data: "..data)
					local nData = string.match(data, ":(.*)")
					--print("Node Data: "..nData..'\n')
					if part == 1 then
						dataArray[vid] = ""
						--print("1: "..dataArray[vid])
						dataArray[vid] = tostring(nData)
						--print("1 (W Data): "..dataArray[vid])
					else
						--print("Append Nodes: "..dataArray[vid])
						dataArray[vid] = tostring(dataArray[vid]..nData)
					end
					if part == "E" then
						--print("Complete Node Data: "..dataArray[vid])
						HandleNetwork[code]("n:"..vid..":"..dataArray[vid])
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
			CoreNetwork.resetSession(true)
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
M.CallEvent = handleEvents

print("GameNetwork Loaded.")
return M
