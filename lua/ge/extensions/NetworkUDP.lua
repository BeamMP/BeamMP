print("[BeamNG-MP] | UDP Network loaded.")
--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local M = {}

local socket = require('socket')
local UDPSocket
local connectionStatus = 0 -- Status: 0 not connected | 1 connecting | 2 connected
local twoSecondsTimer = 2
local sysTime = 0
local pingStatus = "ready"
local pingTimer = 0
local firstConnect = true
local timeoutMax = 15 --TODO: SET THE TIMER TO 30 SECONDS
local timeoutWarn = 7 --TODO: SET THE TIMER TO 5 SECONDS ONCE WE ARE MORE STREAMLINED

local function println(stringToPrint)
	if stringToPrint ~= nil then
		print("[BeamNG-MP] [UDP] | "..stringToPrint or "")
	end
end

local function UDPSend(data)
	if connectionStatus > 0 then
		if data then
			return UDPSocket:send(data) -- Send data
		else
			return UDPSocket:send(data) -- Send data
		end
	end
end

local function onConnected()
	connectionStatus = 2
	println("Connected")
end

local function CreateClient(ip, port)
	if connectionStatus == 0 then -- If disconnected
		UDPSocket = socket.udp() -- Set socket to UDP
		UDPSocket:settimeout(0) -- Set timeout to 0 to avoid freezing
		UDPSocket:setpeername(ip, port); -- Connecting
		connectionStatus = 1
		println("Connecting...")
		--UDPSocket:send("test")
	end
end

--====================== DISCONNECT FROM SERVER ======================
local function disconnectFromUDPServer()
	if UDPSocket then
		UDPSocket:close()-- Disconnect from server
	end
	connectionStatus = 0
	firstConnect = true
end
--====================== DISCONNECT FROM SERVER ======================

local function onUpdate(dt)
	if connectionStatus > 0 then -- If player is connecting or connected
		local received, status, partial = UDPSocket:receive() -- Receive data
		if received ~= "" and received ~= nil then -- If data have been received then

			--println("Data received : "..received)
			local packetLength = string.len(received)
			local code = string.sub(received, 1, 4)

			local i = 0
			local processed = {}
			for w in received:gmatch("(.-)</>") do
				processed[i] = w
				i = i + 1
			end

			if processed[1] == nil then
				println(processed[0]) -- code
				println(processed[1]) -- number
				println(processed[2]) -- splitted
				println(processed[3]) -- length
				println(processed[4]) -- ack
				println(processed[5]) -- playerID
				println(processed[6]) -- vehicleID
				println(processed[7]) -- Data
				if processed[4] then -- Check for our "<ack>" string within our reconstructed data from the server using UDP.
					println("ACK packet received, sending back acknowledgement.") -- We have the ack string present. lets reply back to the server with our Client ID to say that we received it
					UDPSocket.send("<ack>"..getPlayerServerID)
				end
			else -- our received data is part of a split message
				println("We received some data that is part of a previous message. HANDLE THIS !!!")
			end

			if code == "new" then


			elseif code == "U-VI" then --

			elseif code == "PONG" then -- Ping request
				pingStatus = "received"
				if firstConnect then
					onConnected()
					firstConnect = false
				end
			else
				println("Data received : "..received)
			end
		end
	end

	if connectionStatus > 0 then -- If connected to the server
		--================================ TWO SECONDS TIMER ================================
				twoSecondsTimer = twoSecondsTimer + dt -- Time in seconds
				if twoSecondsTimer > 2 then -- If twoSecondsTimer pass 2 seconds
					UDPSend("PING") -- Still connected
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
			--UDPSend("PING")
			pingStatus = "wait" -- Wait for server answer
			sysTime = socket.gettime() -- Get send time
		elseif pingStatus == "received" then -- When server answered
			local ping = (socket.gettime() - sysTime)*1000 -- Calculate time between send and receive
			local roundedPing = ping + 0.5 - (ping + 0.5) % 1 -- Round
			UI.setUDPPing(roundedPing) -- Set the ping
			pingStatus = "ready" -- Ready for next ping
		end
		--================================ CHECK PING ================================
	end
end

local function GetUDPStatus()
	return connectionStatus
end

M.onUpdate = onUpdate
M.CreateClient = CreateClient
M.disconnectFromUDPServer = disconnectFromUDPServer
M.connectionStatus = connectionStatus
M.GetUDPStatus = GetUDPStatus
M.UDPSend = UDPSend

return M
