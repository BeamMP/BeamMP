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

local function UDPSend(code, data)
	if connectionStatus > 0 then
		if data then
			--local compressed = LibDeflate:CompressDeflate(data, compression_Level)
			--println(compressed)
			--local decompressed = LibDeflate:DecompressDeflate(compressed)
			--println(decompressed)
			-- Packet Slplitting (Max size 8192b)
			--Get data size
			--local size = string.len(compressed)
			--println("Byte Size (Compressed): "..size)
			local size = string.len(data)
			--println("Byte Size: "..size)

			local DataToSend = HelperFunctions.LengthSplit(data, 500)
			for i,v in ipairs(DataToSend) do
				--print(i, v)
				if i == 1 then
					UDPSocket:send(code.."("..size.."-"..i.."/"..#DataToSend..")"..v.."\n") -- Send data
				else
					UDPSocket:send("("..size.."-"..i.."/"..#DataToSend..")"..v.."\n") -- Send data
				end
			end


			local tmp = tostring(code.."("..size.."-1/"..#DataToSend..")"..data.."\n")
			local size2 = string.len(tmp)
			--println("Total Message Size: "..size2.." Total Packets: "..#DataToSend)
			return
		else
			return UDPSocket:send(code.."\n") -- Send data
		end
	end
end

local function onConnected()
	connectionStatus = 2
	println("Connected")
end

local function CreateClient(ip, port)
	if connectionStatus == 0 then -- If disconnected
		UDPSocket = assert(socket.udp()) -- Set socket to UDP
		UDPSocket:settimeout(0) -- Set timeout to 1 to avoid freezing or lockup
		--print(assert(UDPSocket:setsockname("*",0))) -- Server Use Only??
		print(assert(UDPSocket:setpeername(ip, port))); -- Connecting
		connectionStatus = 1
		print(UDPSocket:getpeername())
		println("Connecting...")
		print(assert(UDPSocket:send("PING\n")))
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
	local bufferedMessage = false
	if connectionStatus > 0 then -- If player is connecting or connected
		local received, status, partial = UDPSocket:receive() -- Receive data
		if received ~= "" and received ~= nil then -- If data have been received then

			local packetLength = string.len(received)
			local code = string.sub(received, 1, 4)
			local containVehicleID = string.sub(code, 2, 2)
			local serverVehicleID = ""
			local data = ""

			--if containVehicleID == "-" then
				--serverVehicleID = string.sub(received, 5, 8)
				--data = string.sub(received, 9, packetLength)
			--else
				data = string.sub(received, 5, packetLength)
			--end
			if code ~= "PONG" then
				println("-----------------------------------------------------")
				--println("code :"..code)
				--println("serverVehicleID :"..serverVehicleID)
				--println("data :"..data)
				--println("raw: "..received)
				println("whole :"..received)

				--println("Data received! > Code: "..code.." > Data: "..tostring(data))
				println("^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
			end

			if data and received:match("%((.-)%)") ~= nil and not HelperFunctions.CheckGameCode(code) then
				println("Not a game code: "..code.."")
				--println(HelperFunctions.CheckGameCode(code))
				-- Okay So the code is not a network message code, Lets move onto game codes, this will require LibDeflate and decompression
				--println(socketbuffer)

				-- ADD SYSTEM TO CHECK IF THIS PACKET IS PART OF ONE WE ALREADY HAVE ELSE ADD IT TO A NEW ONE IF THIS IS THE BEGINNING
				-- THIS WAY WE CAN HANDLE MULTIPLE SPLIT PACKETS AT ONCE RATHER THAN ONE AT A TIME AND ALL IN ORDER

				local packetData = received:match("%((.-)%)")
				local ps = packetData:match("(.+)-")

				if socketbuffer[ps] == nil then
					println("Packet Data: "..packetData)

					data = data:gsub('%(.-%)','')--gsub('%b()', '')
					--data = LibDeflate:DecompressDeflate(data)
					local strdatalen = string.len(data)
					println("Remaining Data: "..data)
					local md = ps - strdatalen
					println("Data Missing: "..md)
					if md > 0 then
						socketbuffer[ps] = {}
						socketbuffer[ps].packetSize = ps
						socketbuffer[ps].data = "" .. data
						socketbuffer[ps].code = code
						bufferedMessage = true
				  elseif md == 0 then
						socketbuffer[ps] = ""
					end
					println(strdatalen)
					println("-----------------------------------------------------")
					code = ""
				else
					if not HelperFunctions.CheckUpdateCode(code) and not HelperFunctions.CheckGameCode(code) then
						println("Packet Data: "..packetData)
						print("Is This packet part of the last? ["..ps.." = "..socketbuffer[ps].packetSize.."]")
						if ps == socketbuffer[ps].packetSize then
							println(received)
							data = received:gsub('%(.-%)','')--gsub('%b()', '')
							println(data)
							println(socketbuffer[ps].data .. data)
							local strdatalen = string.len(socketbuffer[ps].data .. data)
							local md = socketbuffer[ps].packetSize - strdatalen
							println("Data Missing: "..md)
							if md > 0 then
								println("We are still missing data...")
								socketbuffer[ps].data = socketbuffer[ps].data .. data
								bufferedMessage = true
								code = ""
						  else --if md == 0 then
								println("We have all the data! Onwards!")
								data = socketbuffer[ps].data .. data
								code = socketbuffer[ps].code
							  socketbuffer[ps] = nil
								println("Code: "..code.." Data: "..data)
							end
						end
						println("-----------------------------------------------------")
					end
				end
			else
				if code ~= "PONG" then
				  --print("IS NETWORK CODE")
				end
			end

			--==============================================================================
			if not bufferedMessage then
				if code == "U-VC" then -- Spawn vehicle and sync vehicle id or only sync vehicle ID
					vehicleGE.onServerVehicleSpawned(data)

				elseif code == "U-VR" then -- Server vehicle removed
					vehicleGE.onServerVehicleRemoved(serverVehicleID)

					--==============================================================================

				elseif code == "U-VI" then -- Update - Vehicle Inputs
					serverVehicleID, data = data:match("(.+)%[(.+)")
					if data and serverVehicleID then
						inputsGE.applyInputs(data, serverVehicleID)
					end

				elseif code == "U-VE" then -- Update - Vehicle Electrics
					serverVehicleID, data = data:match("(.+)%[(.+)")
					if data and serverVehicleID then
						electricsGE.applyElectrics(data, serverVehicleID)
					end

				elseif code == "U-VN" then -- Update - Vehicle Nodes
					serverVehicleID, data = data:match("(.+)%[(.+)")
					if data and serverVehicleID then
						nodesGE.applyNodes(data, serverVehicleID)
					end

				elseif code == "U-VP" then -- Update - Vehicle Powertrain
					serverVehicleID, data = data:match("(.+)%[(.+)")
					if data and serverVehicleID then
						powertrainGE.applyPowertrain(data, serverVehicleID)
					end

				elseif code == "U-VL" then -- Update - Vehicle Position / Location
					serverVehicleID, data = data:match("(.+)%[(.+)")
					if data and serverVehicleID then
						positionGE.applyPos(data, serverVehicleID)
					end

				elseif code == "PONG" then -- Ping request
					pingStatus = "received"
					if firstConnect then
						onConnected()
						firstConnect = false
					end

				else
					println("Data received! > Code: "..code.." > Data: "..tostring(data))
				end
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
