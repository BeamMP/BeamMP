--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}



-- ============= VARIABLES =============
local socket = require('socket')
local TCPSocket
local connectionStatus = 0 -- Status: 0 not connected | 1 connecting | 2 connected
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



--================================================ SOME FUNCTIONS ================================================
local function println(stringToPrint)
	print("[BeamNG-MP] | "..stringToPrint)
end

--[[
Header:
[00 - 99] Packet header length
[0 - 1] Is packet reliable or not
[0000 - 9999] Packet Code
[-10000 - -99999] Vehicle ID
Example: [15][1]:[2000]:[-10845][SomeData] without the []
--]]
local function buildPacket(reliable, code, vehicleID, data)
	if not data then data = "" end
	if not vehicleID then vehicleID = 0 end
	if reliable and code and vehicleID and data then
		local header = reliable..":"..code..":"..vehicleID
		local length = string.len(header) + 2
		return (length..header..data.."\n") -- Send new connection
	end
	return ""
end

function split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t={}
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		table.insert(t, str)
	end
	return t
end

function isint(n)
  return n == math.floor(n)
end

local function process(rawData)
	local data = {}
	local headerLength = string.sub(rawData, 0, 2)
	data[1] = string.sub(rawData, 3, headerLength)
	data[2] = string.sub(rawData, headerLength+1, string.len(rawData))
	return data
end

local function processHeader(header)
	local finalData = {}
	local splittedHeader = split(header, ":")
	return splittedHeader
end

local function send(packet)
	if connectionStatus > 0 then
		if packet then
			--print("Sent packet of "..string.len(packet).." size")
			TCPSocket:send(packet)
		end
	end
end

local function getStatus()
	return connectionStatus
end

local function setPing(ping)
	be:executeJS('document.getElementById("PING").innerHTML = "'..ping..'ms"') -- Set status
end

local function getPlayerServerID()
	return serverPlayerID
end
--================================================ SOME FUNCTIONS ================================================



--================================ CONNECT TO SERVER ================================
local function connectToServer(ip, port)
	if connectionStatus == 0 then
		UI.setStatus("Connecting...")
		TCPSocket = socket.tcp() -- Set socket to TCP
		--TCPSocket:setoption("tcp-nodelay", true)
		TCPSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
		TCPSocket:connect(ip, port); -- Connecting
		connectionStatus = 1
		send(buildPacket(1, 2000, 0, Network.nickname..":"..getMissionFilename())) -- Send connection packet
	end
end
--================================ CONNECT TO SERVER ================================



--====================== DISCONNECT FROM SERVER ======================
local function disconnectFromServer()
	if connectionStatus > 0 then -- If player were connected
		--vehicleGE.onDisconnect() -- Clear vehicles list...
		send(buildPacket(1, 2001)) -- Send clientClose to server
		--playersList.onDisconnect() -- Clear players list...
		TCPSocket:close()-- Disconnect from server
		serverTimeoutTimer = 0 -- Reset timeout delay
		connectionStatus = 0
		pingStatus = "ready"
		UI.disconnectMsgToChat()
	end
	UI.setStatus("Disconnected")
end
--====================== DISCONNECT FROM SERVER ======================



--============================================= ON CONNECTED ===============================================
local function onConnected() -- Function called only 1 time when client successfully connect to server
	UI.setStatus("Connected") -- TCP connected
	connectionStatus = 2
end
--============================================= ON CONNECTED ===============================================



--======================================================================== ON PLAYER CONNECT ==========================================================================
local function onPlayerConnect() -- Function called when a player connect to the server
	updatesGE.onPlayerConnect()
end
--======================================================================== ON PLAYER CONNECT ==========================================================================



local function onUpdate(dt)
--====================================================== DATA RECEIVE ======================================================
	if connectionStatus > 0 then -- If player is connecting or connected	
		while (true) do		
			local received, status, partial = TCPSocket:receive() -- Receive data	
			if received == nil then break end
			if received ~= "" and received ~= nil then -- If data have been received then
				local tempData = process(received)
				local header = processHeader(tempData[1])
				
				local code = header[2] or ""
				local serverVehicleID = header[3] or ""
				local data = tempData[2] or ""

				--print("--------------- Received ---------------")
				--print(received)
				--print("Reliable: "..header[1])
				--print("Code: "..code)
				--print("Vehicle ID: "..serverVehicleID)
				--print("Data: "..data)
				--==============================================================================
				
				if         code == "1001" then -- If server ready
					onConnected()

				elseif     code == "1002" then -- If the server send 10002 then it still opened
					serverTimeoutTimer = 0 -- Reset timeout timer
					UI.setStatus("Connected")
				
				elseif code == "1003" then -- Send server id to client
					serverPlayerID = data -- Define player server ID
					if serverPlayerID == nil then -- If ID is null then problem occured
						UI.setStatus("Wrong ID received")
						disconnectFromServer()
					end
				
				elseif code == "1004" then -- Ping request
					pingStatus = "received"
				
				elseif code == "1005" then -- Server kicked the player for any reason
					disconnectFromServer()
					UI.setStatus("Kicked ("..data..")")
				elseif code == "1106" then
					UI.updateChatLog(data)
				
				--==============================================================================		

				elseif code == "1010" then -- Is he the first player to connect ?
					println("First player : "..data)
					if data == "true" then -- If he is the first player to connect
						vehicleGE.sendAllVehicles() -- Send all his vehicles to the server
					else -- If he is not the first player to connect
						vehicleGE.deleteAllVehicles() -- Delete all his vehicles to sync the one of existing players
					end
					
				elseif code == "1011" then -- If a player connected to the server
					onPlayerConnect() -- Call onPlayerConnect function
					
				elseif code == "1012" then -- Update connected players list
					local fix = string.sub(data, 2, string.len(data) - 1)
					UI.sendPlayerList(fix) -- Set connected players list
							
				--==============================================================================			
					
				elseif code == "1020" then -- Spawn vehicle and sync vehicle id or only sync vehicle ID
					vehicleGE.onServerVehicleSpawned(data)
				
				elseif code == "1121" then -- Server vehicle removed
					vehicleGE.onServerVehicleRemoved(serverVehicleID, data)
				
				elseif code == "1123" then -- Server vehicle resetted
					vehicleGE.onServerVehicleResetted(serverVehicleID)
						
				--==============================================================================
		
				elseif code == "1130" then -- Inputs
					if data and serverVehicleID then
						inputsGE.applyInputs(data, serverVehicleID)
					end
					
				elseif code == "1131" then -- Electrics
					if data and serverVehicleID then
						electricsGE.applyElectrics(data, serverVehicleID)
					end
				
				elseif code == "1132" then -- Nodes
					if data and serverVehicleID then
						nodesGE.applyNodes(data, serverVehicleID)
					end
				
				elseif code == "1133" then -- Powertrain
					if data and serverVehicleID then
						powertrainGE.applyPowertrain(data, serverVehicleID)
					end
					
				elseif code == "1134" then -- Position
					if data and serverVehicleID then
						positionGE.applyPos(data, serverVehicleID)
					end
				elseif code == "1135" then -- Position
					if data and serverVehicleID then
						electricsGE.applyGear(data, serverVehicleID)
					end
				end	
				--==============================================================================
			end	
		end	
	end
--====================================================== DATA RECEIVE ======================================================



--===================================================== CHECK SERVER TIMEOUT =====================================================
	if connectionStatus > 0 then -- If connected to the server
		serverTimeoutTimer = serverTimeoutTimer + dt -- Time in seconds
		if serverTimeoutTimer > timeoutMax then -- If serverTimeoutTimer haven't been set to 0 for 15 seconds it mean the server is not answering
			if connectionStatus == 2 then -- If was connected to server then
				disconnectFromServer() -- Disconnect from server since it doesn't answer
				UI.setStatus("Connection lost") -- Connection have been lost
				println("Connection to server timed out after "..timeoutMax.." seconds")
			elseif connectionStatus == 1 then -- If was never connected to server
				disconnectFromServer() -- Cancel connection attempt to server since it doesn't answer
				UI.setStatus("Connection to server failed") -- Connection is impossible
				println("Connection to server failed. (Wrong IP / port / server closed on the target computer / server ?)")
			end
		end
		if serverTimeoutTimer > timeoutWarn and connectionStatus == 2 then -- If serverTimeoutTimer pass 7 seconds
			UI.setStatus("No answer...", 0) -- Warning message
		end
--===================================================== CHECK SERVER TIMEOUT =====================================================



--================================ TWO SECONDS TIMER ================================
		twoSecondsTimer = twoSecondsTimer + dt -- Time in seconds
		if twoSecondsTimer > 2 then -- If twoSecondsTimer pass 2 seconds
			send(buildPacket(0, 2002)) -- Still connected
			twoSecondsTimer = 0	-- Reset timer
		end
--================================ TWO SECONDS TIMER ================================



--================================ CHECK PING ================================
		pingTimer = pingTimer + dt
		if pingTimer > 2 and pingStatus == "ready" then -- Ping every 2 seconds
			pingStatus = "send" -- Set status to send
			pingTimer = 0
		end

		if pingStatus == "send" then -- Send the ping request
			send(buildPacket(1, 2004))
			pingStatus = "wait" -- Wait for server answer
			sysTime = socket.gettime() -- Get send time
		elseif pingStatus == "received" then -- When server answered
			local ping = (socket.gettime() - sysTime)*1000 -- Calculate time between send and receive
			local roundedPing = ping + 0.5 - (ping + 0.5) % 1 -- Round
			setPing(roundedPing) -- Set the ping
			pingStatus = "ready" -- Ready for next ping
		end
--================================ CHECK PING ================================
	end
end



M.nickname			   = nickname
M.buildPacket          = buildPacket
M.getStatus            = getStatus
M.getPlayerServerID    = getPlayerServerID
M.send                 = send
M.setNickname          = setNickname
M.connectToServer      = connectToServer
M.disconnectFromServer = disconnectFromServer
M.onUpdate             = onUpdate
M.split                = split



return M