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
local nickname = ""
local serverPlayerID = ""
local sysTime = 0
local pingStatus = "ready"
local pingTimer = 0
local timeoutMax = 15 --TODO: SET THE TIMER TO 30 SECONDS
local timeoutWarn = 7 --TODO: SET THE TIMER TO 5 SECONDS ONCE WE ARE MORE STREAMLINED
-- ============= VARIABLES =============

--====================== DISCONNECT FROM SERVER ======================
local function disconnectFromServer()
	if connectionStatus > 0 then -- If player were connected
		--vehicleGE.onDisconnect() -- Clear vehicles list...
		playersList.onDisconnect() -- Clear players list...
		send("2001") -- Send clientClose to server
		TCPSocket:close()-- Disconnect from server
		serverTimeoutTimer = 0 -- Reset timeout delay
		connectionStatus = 0
		UI.setStatus("Disconnected")
	end
end
--====================== DISCONNECT FROM SERVER ======================



--============================================= ON CONNECTED ===============================================
local function onConnected() -- Function called only 1 time when client successfully connect to server
	UI.setStatus("Connected") -- TCP connected
	connectionStatus = 2
	send("2003"..nickname) -- Send nickname to server
end
--============================================= ON CONNECTED ===============================================



--======================================================================== ON PLAYER CONNECT ==========================================================================
local function onPlayerConnect() -- Function called when a player connect to the server
	--updatesGE.onPlayerConnect()
end

local function JoinSession(ip, port)
  -- start onUpdate to allow pickup of data
  connectionStatus = 1
  UI.setStatus("Connecting...")
  TCPSocket = socket.tcp() -- Set socket to TCP
  TCPSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
  -- establish connection
  TCPSocket:connect(ip, port); -- Connecting


  -- run prechecks (Map)

  --
end

local function HostSession()

end

local function onUpdate(dt)
  if connectionStatus > 0 then -- If player is connecting or connected
		local received, status, partial = TCPSocket:receive() -- Receive data
		if received ~= "" and received ~= nil then -- If data have been received then

			local packetLength = string.len(received)
			local code = string.sub(received, 1, 4)
			local containVehicleID = string.sub(code, 2, 2)
			local serverVehicleID = ""
			local data = ""

			if containVehicleID == "1" then
				serverVehicleID = string.sub(received, 5, 10)
				data = string.sub(received, 11, packetLength)
			else
				data = string.sub(received, 5, packetLength)
			end

			--print("-----------------------------------------------------")
			--print("data :"..data)
			--print("veid :"..serverVehicleID)
			--print("code :"..code)
			--print("wole :"..received)

			--println("Data received : "..received)


			--==============================================================================

			if     code == "1001" then -- If server ready
				onConnected()

			elseif code == "1002" then -- If the server send 10002 then it still opened
				serverTimeoutTimer = 0 -- Reset timeout timer
				setStatus("Connected")

			elseif code == "1003" then -- Send server id to client
				serverPlayerID = data -- Define player server ID
				if serverPlayerID == nil then -- If ID is null then problem occured
					setStatus("Wrong ID received")
					disconnectFromServer()
				end

			elseif code == "1004" then -- Ping request
				pingStatus = "received"

			elseif code == "1005" then -- Server kicked the player for any reason
				disconnectFromServer()
				setStatus("Kicked ("..data..")")

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
				playersList.setConnectedPlayers(jsonDecode(data)) -- Set connected players list

			--==============================================================================

			elseif code == "1020" then -- Spawn vehicle and sync vehicle id or only sync vehicle ID
				vehicleGE.onServerVehicleSpawned(data)

			elseif code == "1121" then -- Server vehicle removed
				vehicleGE.onServerVehicleRemoved(serverVehicleID)

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
			end
			--==============================================================================
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
			setStatus("No answer...", 0) -- Warning message
		end
--===================================================== CHECK SERVER TIMEOUT =====================================================



--================================ TWO SECONDS TIMER ================================
		twoSecondsTimer = twoSecondsTimer + dt -- Time in seconds
		if twoSecondsTimer > 2 then -- If twoSecondsTimer pass 2 seconds
			send("2002") -- Still connected
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
			send("2004")
			pingStatus = "wait" -- Wait for server answer
			sysTime = socket.gettime() -- Get send time
		elseif pingStatus == "received" then -- When server answered
			local ping = (socket.gettime() - sysTime)*1000 -- Calculate time between send and receive
			local roundedPing = ping + 0.5 - (ping + 0.5) % 1 -- Round
			UI.setPing(roundedPing) -- Set the ping
			pingStatus = "ready" -- Ready for next ping
		end
--================================ CHECK PING ================================
	end
end

--================================ Function return + Handling ================================

M.onUpdate = onUpdate
M.JoinSession = JoinSession
M.HostSession = HostSession
--M. =

return M
