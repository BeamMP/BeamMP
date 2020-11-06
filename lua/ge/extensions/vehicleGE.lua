--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

-- HOW DOES IT WORK :
-- When player connect to server for the first time, it send all his spawned vehicles to the server
-- The server add all vehicles create ID for them and then send them back to the client with client ID
-- If the received vehicle is the one that have been spawned by the client (check using client ID) then
	-- It sync the client in-game vehicle ID with the server ID
-- Else
	-- It spawn the received vehicle and then get the spawned vehicle ID and sync it with the received one



local M = {}
print("vehicleGE Initialising...")


-- ============= VARIABLES =============
local lastResetID = ""
local oneSecCounter = 0
local ownMap = {}
local first = true
local vehiclesMap = {}
local nicknameMap = {}
local invertedVehiclesMap = {}
local onVehicleDestroyedAllowed = true
local syncTimer = 0
local syncVehIDs = {}
local activeVehicle = 0

local roleToInfo = {
	['USER'] = { backcolor = ColorI(0, 0, 0, 127), tag = "" },
	['EA'] = { backcolor = ColorI(69, 0, 150, 127), tag = " [Early Access]" },
	['YT'] = { backcolor = ColorI(200, 0, 0, 127), tag = " [YouTuber]" },
	['ET'] = { backcolor = ColorI(210, 214, 109, 127), tag = " [Events Team]" },
	['SUPPORT'] = { backcolor = ColorI(68, 109, 184, 127), tag = " [Support]" },
	['MOD'] = { backcolor = ColorI(68, 109, 184, 127), tag = " [Moderator]" },
	['ADM'] = { backcolor = ColorI(218, 0, 78, 127), tag = " [Admin]" },
	['GDEV'] = { backcolor = ColorI(252, 107, 3, 127), tag = " [BeamNG Staff]" },
	['MDEV'] = { backcolor = ColorI(194, 55, 55, 127), tag = " [MP DEV]" }
}
--[[
	USER = Default
	EA = Early Access
	YT = YouTuber
	ET = Events Team
	SUPPORT = Support
	MOD = Moderator
	GDEV = BeamNG Staff
	MDEV = MP Dev
]]

-- ============= VARIABLES =============



--============== SOME FUNCTIONS ==============
local function println(stringToPrint)
	print("[BeamMP] | "..stringToPrint)
end

local function tableInvert(t)
   local s = {}
   for k,v in pairs(t) do
     s[v] = k
   end
   return s
end

local function getGameVehicleID(serverVehicleID)
	return invertedVehiclesMap[tostring(serverVehicleID)]
end

local function getServerVehicleID(gameVehicleID)
	return vehiclesMap[tostring(gameVehicleID)]
end

local function insertVehicleMap(gameVehicleID, serverVehicleID)
	vehiclesMap[tostring(gameVehicleID)] = tostring(serverVehicleID)
	invertedVehiclesMap[tostring(serverVehicleID)] = tostring(gameVehicleID)
end

local function isOwn(gameVehicleID)
    return ownMap[tostring(gameVehicleID)] ~= nil
end

local function getOwnMap()
    return ownMap
end

local function getVehicleMap()
    return vehiclesMap
end

local function getNicknameMap() -- Returns a ["localID"] = "username" table of all vehicles, including own ones
	local nicknameSimple = {}
	for k,v in pairs(nicknameMap) do
		nicknameSimple[k] = v.nickname
		--print("carID"..tostring(k).." is owned by "..nicknameSimple[k])
	end
	local thisNick =  mpConfig.getNickname()
	--dump(nicknameMap)
	--dump(nicknameSimple)
	for k,v in pairs(ownMap) do nicknameSimple[k] = thisNick end

    return nicknameSimple
end

--============== SOME FUNCTIONS ==============



--============================ DELETE ALL VEHICLES ==============================
local function deleteAllVehicles()
	if be:getObjectCount() == 0 then return end -- If no vehicle do nothing
	commands.setFreeCamera()
	for i = 0, be:getObjectCount() do -- For each vehicle
		local veh = be:getObject(0) --  Get vehicle
		if veh then -- For loop always return one empty vehicle ?
			onVehicleDestroyedAllowed = false
			veh:delete()
		end
	end
end
--============================ DELETE ALL VEHICLES ==============================



--============================ SEND ALL VEHICLES ==============================
local function sendAllVehicles()
	if be:getObjectCount() == 0 then return end -- If no vehicle do nothing
	for i = 0, be:getObjectCount() do -- For each vehicle
		local veh = be:getObject(i) --  Get vehicle
		if veh then -- For loop always return one empty vehicle ?
			veh:queueLuaCommand("obj:queueGameEngineLua(\"vehicleGE.sendVehicleData("..veh:getID()..", '\"..jsonEncode(v.config)..\"')\")") -- Get config
		end
	end
end
--============================ SEND ALL VEHICLES ==============================



--============================ SEND ONE VEHICLE ==============================
local function sendVehicle(gameVehicleID)
	local veh = be:getObjectByID(gameVehicleID) -- Get spawned vehicle ID
	if veh then -- In case of bug
		veh:queueLuaCommand("obj:queueGameEngineLua(\"vehicleGE.sendVehicleData("..gameVehicleID..", '\"..jsonEncode(v.config)..\"')\")") -- Get config
		print("VEHICLE SENT")
	end
end
--============================ SEND ONE VEHICLE ==============================



--=========================================== SEND VEHICLE DATA =============================================
local function sendVehicleData(gameVehicleID, vehicleConfig)
	local vehicleTable    = {} -- Vehicle table
	local veh             = be:getObjectByID(gameVehicleID)
	local c               = veh.color
	local p0              = veh.colorPalette0
	local p1              = veh.colorPalette1
	local pos             = veh:getPosition()
	local rot             = veh:getRotation()

	vehicleTable[1]  = mpConfig.getPlayerServerID()
	vehicleTable[2]  = tostring(gameVehicleID)
	vehicleTable[3]  = veh:getJBeamFilename()
	vehicleTable[4]  = vehicleConfig
	vehicleTable[5]  = jsonEncode({c.x, c.y, c.z, c.w})
	vehicleTable[6]  = jsonEncode({p0.x, p0.y, p0.z, p0.w})
	vehicleTable[7]  = jsonEncode({p1.x, p1.y, p1.z, p1.w})
	vehicleTable[8]  = getServerVehicleID(gameVehicleID) or ""
	vehicleTable[9]  = jsonEncode({pos.x, pos.y, pos.z})
	vehicleTable[10] = jsonEncode({rot.x, rot.y, rot.z, rot.w})

	local stringToSend = jsonEncode(vehicleTable) -- Encode table to send it as json string
	GameNetwork.send('Os:0:'..stringToSend)--Network.buildPacket(1, 2020, 0, stringToSend))	-- Send table that contain all vehicle informations for each vehicle
end
--=========================================== SEND VEHICLE DATA =============================================

--=========================================== SEND MODIFIED VEHICLE DATA =============================================
local function sendCustomVehicleData(gameVehicleID, vehicleConfig)
	local vehicleTable    = {} -- Vehicle table
	local veh             = be:getObjectByID(gameVehicleID)
	local c               = veh.color
	local p0              = veh.colorPalette0
	local p1              = veh.colorPalette1

	vehicleTable[1]  = mpConfig.getPlayerServerID()
	vehicleTable[3]  = veh:getJBeamFilename()
	vehicleTable[4]  = vehicleConfig
	vehicleTable[5]  = jsonEncode({c.x, c.y, c.z, c.w})
	vehicleTable[6]  = jsonEncode({p0.x, p0.y, p0.z, p0.w})
	vehicleTable[7]  = jsonEncode({p1.x, p1.y, p1.z, p1.w})

	local stringToSend = jsonEncode(vehicleTable) -- Encode table to send it as json string
	GameNetwork.send('Oc:'..getServerVehicleID(gameVehicleID)..':'..stringToSend)--Network.buildPacket(1, 2020, 0, stringToSend))	-- Send table that contain all vehicle informations for each vehicle

	syncTimer = 0
	syncVehIDs[gameVehicleID] = 0
	print("clearing id "..gameVehicleID.." from the sync table")
end
--=========================================== SEND MODIFIED VEHICLE DATA =============================================

local function UpdateVehicle(sid, data)
	local currentVeh = be:getPlayerVehicle(0) -- Camera fix
	local gameVehicleID = getGameVehicleID(sid)
	local veh = be:getObjectByID(gameVehicleID)
	local decodedData     = jsonDecode(data)
	--dump(decodedData)
	local vehicleName     = decodedData[3] -- Vehicle name
	local vehicleConfig   = decodedData[4] -- Vehicle config
	local c               = jsonDecode(decodedData[5]) -- Vehicle color
	local cP0             = jsonDecode(decodedData[6]) -- Vehicle colorPalette0
	local cP1             = jsonDecode(decodedData[7]) -- Vehicle colorPalette1
	if vehicleName == veh:getJBeamFilename() then
		print("[BeamMP] Updating Vehicle Config Due to Edit!")
		--veh:queueLuaCommand("vehicleVE.applyPartConfig(\'"..vehicleConfig.."\')") -- Get config
		local decodedCfg = jsonDecode(vehicleConfig) -- Decode received data
		print(gameVehicleID)
		local playerVehicle = extensions.core_vehicle_manager.getVehicleData(tonumber(gameVehicleID))
		--dump(playerVehicle)
		tableMerge(playerVehicle.config, decodedCfg)
		veh:respawn(serialize(playerVehicle.config))
		if currentVeh then be:enterVehicle(0, currentVeh) end -- Camera fix
	else
		print("RECEIVE MODIFIED DATA FOR A VEHICLE THAT IS NOT OF THE SAME TYPE!!!")
	end
end

local function onDisconnect()
	-- Clear ownMap and vehiclesMap
	ownMap = {}
	vehiclesMap = {}
	invertedVehiclesMap = {}
	first = true
end



--================================= ON VEHICLE SPAWNED (SERVER) ===================================
local function onServerVehicleSpawned(playerRole, playerNickname, serverVehicleID, data)
	local currentVeh = be:getPlayerVehicle(0) -- Camera fix
	local decodedData     = jsonDecode(data)
	dump(decodedData)
	local playerServerID  = decodedData[1] -- Server ID of the player that sent the vehicle
	local gameVehicleID   = decodedData[2] -- gameVehicleID of the player that sent the vehicle
	--local serverVehicleID = decodedData[3] -- Server ID of the vehicle
	local vehicleName     = decodedData[3] -- Vehicle name
	local vehicleConfig   = jsonDecode(decodedData[4]) -- Vehicle config
	local c               = jsonDecode(decodedData[5]) -- Vehicle color
	local cP0             = jsonDecode(decodedData[6]) -- Vehicle colorPalette0
	local cP1             = jsonDecode(decodedData[7]) -- Vehicle colorPalette1
	local pos             = vec3(jsonDecode(decodedData[9]))
	local rot             = quat(jsonDecode(decodedData[10]))

	print("onServerVehicleSpawned ID's:  "..mpConfig.getPlayerServerID().." == "..playerServerID)
	if mpConfig.getPlayerServerID() == playerServerID then -- If player ID = received player ID seems it's his own vehicle then sync it
		insertVehicleMap(gameVehicleID, serverVehicleID) -- Insert new vehicle ID in map
		ownMap[tostring(gameVehicleID)] = 1 -- Insert vehicle in own map
		println("ID is same as received ID, syncing vehicle gameVehicleID: "..gameVehicleID.." with ServerID: "..serverVehicleID)
	else
		if not vehicleName then return end
		if getGameVehicleID(serverVehicleID) ~= nil then return end
		println("New vehicle : "..vehicleName)
		--if decodedData[9] == "null" then print("oh no meow 3:") return end

		local spawnedVeh = spawn.spawnVehicle(vehicleName, serialize(vehicleConfig), pos, rot, ColorF(c[1],c[2],c[3],c[4]), ColorF(cP0[1],cP0[2],cP0[3],cP0[4]), ColorF(cP1[1],cP1[2],cP1[3],cP1[4]), "multiplayerVeh", true)
		local spawnedVehID = spawnedVeh:getID()
		print("New Vehicles ID : "..spawnedVehID)
		insertVehicleMap(spawnedVehID, serverVehicleID) -- Insert new vehicle ID in map
		dump(vehiclesMap[spawnedVehID])
		nicknameMap[tostring(spawnedVehID)] = {}
		nicknameMap[tostring(spawnedVehID)].nickname = playerNickname
		nicknameMap[tostring(spawnedVehID)].role = playerRole
		core_vehicles.setPlateText(playerNickname, spawnedVehID)
	end

	if currentVeh then be:enterVehicle(0, currentVeh) end -- Camera fix
end
--================================= ON VEHICLE SPAWNED (SERVER) ===================================



--================================= ON VEHICLE SPAWNED (CLIENT) ===================================
local function onVehicleSpawned(gameVehicleID)
	local veh = be:getObjectByID(gameVehicleID)
	if isOwn(gameVehicleID) ~= 1 and getServerVehicleID(gameVehicleID) == nil then
		print("[BeamMP] Vehicle Spawned: "..gameVehicleID)
		local veh = be:getObjectByID(gameVehicleID)
		if first then  -- if first then
			--commands.setFreeCamera() -- Fix camera
			--veh:delete() -- Remove it  -- Temp Removed for 0.20 FIx
			--print("[BeamMP] First Session Vehicle Removed, Maybe now request the vehicles in the game?")
			--if commands.isFreeCamera(player) then commands.setGameCamera() end -- Fix camera
			--UI.ready("FIRSTVEH") -- Solve session setup without UI sending ready status
			--onMPSessionInit()
			first = false
		else
			veh:queueLuaCommand("extensions.addModulePath('lua/vehicle/extensions/BeamMP')") -- Load lua files
			veh:queueLuaCommand("extensions.loadModulesInDirectory('lua/vehicle/extensions/BeamMP')")
			--if Network.getStatus() > 0 and not getServerVehicleID(gameVehicleID) then -- If is connecting or connected
			if GameNetwork.connectionStatus() == 1 and not getServerVehicleID(gameVehicleID) and veh.isMP ~= "1"  then -- If TCP connected
				sendVehicle(gameVehicleID) -- Send it to the server
				if isOwn(gameVehicleID) then
					veh:queueLuaCommand("powertrainVE.sendAllPowertrain()")
				end
			end
		end
	else
		print("[BeamMP] Vehicle Edited: "..gameVehicleID)
		syncTimer=0
		syncVehIDs[gameVehicleID] = 1
	end
end
--================================= ON VEHICLE SPAWNED (CLIENT) ===================================



--================================= ON VEHICLE REMOVED (SERVER) ===================================

local function onServerVehicleRemoved(serverVehicleID)
	local gameVehicleID = getGameVehicleID(serverVehicleID) -- Get game ID
	if gameVehicleID then
		local veh = be:getObjectByID(gameVehicleID) -- Get associated vehicle
		if veh and gameVehicleID then
			onVehicleDestroyedAllowed = false
			commands.setFreeCamera() -- Fix camera
			veh:delete() -- Remove it
			if commands.isFreeCamera(player) then commands.setGameCamera() end -- Fix camera
			vehiclesMap[gameVehicleID] = nil
			invertedVehiclesMap[serverVehicleID] = nil
		end
	else
		println("gameVehicleID for serverVehicleID "..serverVehicleID.." not found. (onServerVehicleRemoved)")
		--data = Network.split(data, ":")                                                                   -- TODO Solve How this works
		--[[if playerServerID and gameVehicleID then -- 1:host playerID - 2:host gameVehicleID
			if CoreNetwork.getPlayerServerID() == playerServerID then
				be:getObjectByID(gameVehicleID):delete()
			end
		end]]
	end
end
--================================= ON VEHICLE REMOVED (SERVER) ===================================



--================================= ON VEHICLE REMOVED (CLIENT) ===================================
local function onVehicleDestroyed(gameVehicleID)
	print("Vehicle destroyed : "..gameVehicleID)
	if GameNetwork.connectionStatus() == 1 then -- If TCP connected
		if onVehicleDestroyedAllowed then -- If function is not coming from onServerVehicleRemoved then
			local serverVehicleID = getServerVehicleID(gameVehicleID) -- Get the serverVehicleID
			if serverVehicleID then
				GameNetwork.send('Od:'..serverVehicleID)--Network.buildPacket(1, 2121, serverVehicleID, ""))
			end
		else
			onVehicleDestroyedAllowed = true
		end
	end
end
--================================= ON VEHICLE REMOVED (CLIENT) ===================================



--======================= ON VEHICLE SWITCHED (CLIENT) =======================
local function onVehicleSwitched(oldID, newID)
	--print("Vehicle switched : "..oldID.." - "..newID)
	if GameNetwork.connectionStatus() == 1 then -- If TCP connected
		local newID = getServerVehicleID(newID) -- Get new serverVehicleID of the new vehicle the player is driving
		if newID then -- If it's not null
			GameNetwork.send('Om:'..newID)--Network.buildPacket(1, 2122, newID, ""))
		end
	end
end
--======================= ON VEHICLE SWITCHED (CLIENT) =======================



--======================= ON VEHICLE RESETTED (CLIENT) =======================
local function onVehicleResetted(gameVehicleID)
	--print("Vehicle resetted : "..gameVehicleID)
	if GameNetwork.connectionStatus() == 1 then -- If TCP connected
		local serverVehicleID = getServerVehicleID(gameVehicleID) -- Get new serverVehicleID of the new vehicle the player is driving
		if serverVehicleID and isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle -- If it's not null
			--Network.send(Network.buildPacket(1, 2123, serverVehicleID, ""))
			local veh = be:getObjectByID(gameVehicleID)
			local pos = veh:getPosition()
			local rot = veh:getRotation()

			local tempTable = {}
			tempTable['pos'] = {}
			tempTable['pos'].x = tonumber(pos.x)
			tempTable['pos'].y = tonumber(pos.y)
			tempTable['pos'].z = tonumber(pos.z)
			tempTable['ang'] = {}
			tempTable['ang'].x = tonumber(rot.x)
			tempTable['ang'].y = tonumber(rot.y)
			tempTable['ang'].z = tonumber(rot.z)
			tempTable['ang'].w = tonumber(rot.w)
			GameNetwork.send('Or:'..serverVehicleID..":"..jsonEncode(tempTable).."")
		end
	end
end
--======================= ON VEHICLE RESETTED (CLIENT) =======================



--======================= ON VEHICLE RESETTED (SERVER) =======================
local function onServerVehicleResetted(serverVehicleID, data)
	local gameVehicleID = getGameVehicleID(serverVehicleID) -- Get game ID
	if lastResetID ~= serverVehicleID then
		if gameVehicleID then
			local veh = be:getObjectByID(gameVehicleID) -- Get associated vehicle
			if veh and gameVehicleID then
				lastResetID = serverVehicleID
				local pr = jsonDecode(data) -- Decoded data
				veh:reset()
				println("Vehicle "..serverVehicleID.." Reset!")
				if pr ~= nil then
					veh:setPositionRotation(pr.pos.x, pr.pos.y, pr.pos.z, pr.ang.x, pr.ang.y, pr.ang.z, pr.ang.w) -- Apply position
				else
					if settings.getValue("showDebugOutput") == true then
				    print('[vehicleGE] pr == nil for onServerVehicleResetted()')
					end
				end
			end
		else
			println("gameVehicleID for serverVehicleID "..serverVehicleID.." not found. (onServerVehicleResetted)")
			--GameNetwork.send('On:'..serverVehicleID) -- Handled by server now.
		end
	else
		--println("Currently On Timeout before reset for this vehicle...")
	end
end
--======================= ON VEHICLE RESETTED (SERVER) =======================

local function handle(rawData)
	-- the code will be the first opt then the data followed
	--print('vehicleGE:'..rawData)
	local code = string.sub(rawData, 1, 1)
	local rawData = string.sub(rawData, 3)
	if code == "s" then -- On server vehicle spawn
		-- Get the player role from the data
		local playerRole = string.match(rawData,"(%w+)%:")

		-- Get the player nickname from the data
		rawData = rawData:gsub(playerRole..":", "")
		local playerNickname = string.match(rawData,"^.-:")
		playerNickname = playerNickname:sub(1, #playerNickname - 1)

		-- Get the serverVehicleID from the data
		rawData = rawData:sub((#playerNickname + 2), #rawData)
		local serverVehicleID = string.match(rawData,"^.-:")
		serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1)

		-- Get the vehicle data from the data
		local data = string.match(rawData,":(.*)")

		-- Print data and send it
		print("Player Name: "..playerNickname..", PlayerRole: "..playerRole..", serverVehicleID: "..serverVehicleID..", Data: "..data)
		onServerVehicleSpawned(playerRole, playerNickname, serverVehicleID, data)

	elseif code == "c" then -- This is for the customisation of a vehicle event
		local serverVehicleID = string.match(rawData,"^.-:")
		serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1)
		print(serverVehicleID)
		print(rawData)
		local data = string.match(rawData,":(.*)")
		UpdateVehicle(serverVehicleID, data)

	elseif code == "r" then -- This is for vehicle reset event
		local serverVehicleID = string.match(rawData,"^.-:")
		serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1)
		local data = string.match(rawData,":(.*)")
		--local data = string.match(rawData,":(.*)")
		--print("serverVehicleID: "..serverVehicleID..", Data: "..data)
		onServerVehicleResetted(serverVehicleID, data)

	elseif code == "d" then -- Server vehicle removed
		local serverVehicleID = rawData -- TODO Finish this code to remove all for player ID if we do not get a -XXX id for the specific car (in the case it was not handled by the server)
		--if serverVehicleID:match("-") then
			print("serverVehicleID: "..serverVehicleID.." was removed on owners end.")
			onServerVehicleRemoved(serverVehicleID)
		--else
			--print("serverVehicleID: "..serverVehicleID.." was removed on owners end.")
			--onServerVehicleRemoved(serverVehicleID)
		--end
	end
end

local function removeRequest(gameVehicleID)
	if isOwn(gameVehicleID) then
		core_vehicles.removeCurrent(); extensions.hook("trackNewVeh")
		print("[BeamMP] request to remove car id "..gameVehicleID.." DONE")
	else
		print("[BeamMP] request to remove car id "..gameVehicleID.." DENIED")
	end
end

local function setCurrentVehicle(gameVehicleID)
	if activeVehicle ~= gameVehicleID then
		println("Current vehicle: "..gameVehicleID)
	end
	activeVehicle = gameVehicleID
end


local function onUpdate(dt)
	if GameNetwork.connectionStatus() == 1 then -- If TCP connected
		if be:getObjectCount() == 0 then return end -- If no vehicle do nothing
		local shouldSync = false

		local localPos = nil
		for i = 0, be:getObjectCount() do -- Find at least one local player car
			local veh = be:getObject(i)
			if veh and isOwn(veh:getID()) then
				localPos = veh:getPosition()
			end
		end

		if activeVehicle ~= nil then
			--print("currveh:")
			--print(tostring(currentVehicle))
			local veh = be:getObjectByID(tonumber(activeVehicle))
			if veh ~= nil then
				--print("veh:")
				localPos = veh:getPosition()
				--print(tostring(localPos.x).." "..tostring(localPos.y).." "..tostring(localPos.z))
			end
		end

		for i = 0, be:getObjectCount() do -- For each vehicle
			local veh = be:getObject(i) --  Get vehicle
			if veh then -- For loop always return one empty vehicle ?
				local gameVehicleID = veh:getID()
				local vehIDstr = tostring(gameVehicleID)
				if not isOwn(gameVehicleID) and nicknameMap[vehIDstr] ~= nil and settings.getValue("showNameTags") then
					local pos = veh:getPosition()
					pos.z = pos.z + 2.0
					local dist = ""
					local roleInfo = roleToInfo[nicknameMap[vehIDstr].role] or roleToInfo['USER']

					if localPos ~= nil and activeVehicle ~= vehIDstr and settings.getValue("nameTagShowDistance") then
						local distfloat = math.sqrt(math.pow(localPos.x-pos.x, 2) + math.pow(localPos.y-pos.y, 2) + math.pow(localPos.z-pos.z-2.0, 2))
						if distfloat > 10 then
							if settings.getValue("uiUnitLength") == "imperial" then
								distfloat = distfloat * 3.28084
								dist = " "..tostring(math.floor(distfloat)).." ft"
							else
								dist = " "..tostring(math.floor(distfloat)).." m"
							end
						end
					end

					debugDrawer:drawTextAdvanced(
						pos, -- Position in 3D
						String(" "..tostring(nicknameMap[vehIDstr].nickname)..roleInfo.tag..dist.." "), -- Text
						ColorF(1, 1, 1, 1), true, false, -- Foreground Color / Background / Wtf
						roleInfo.backcolor -- Background Color
					)
				end


				if syncVehIDs[gameVehicleID] ~= nil and syncVehIDs[gameVehicleID] ~= 0 then

					--print("veh id "..gameVehicleID.." has value "..syncVehIDs[gameVehicleID].." in the sync table")

					syncTimer = syncTimer+dt
					if syncTimer > 10 then
						shouldSync = true
						syncTimer = 0
					end
					if shouldSync then
						print("[BeamMP] Autosyncing car ID "..gameVehicleID)
						veh:queueLuaCommand("obj:queueGameEngineLua(\"vehicleGE.sendCustomVehicleData("..gameVehicleID..", '\"..jsonEncode(v.config)..\"')\")")
						syncVehIDs[gameVehicleID] = nil
					end
				end
			end
		end
	end
end

M.setCurrentVehicle		  = setCurrentVehicle
M.removeRequest			  = removeRequest
M.onUpdate                = onUpdate
M.handle                  = handle
M.onVehicleSwitched       = onVehicleSwitched
M.onDisconnect            = onDisconnect
M.isOwn                   = isOwn
M.getOwnMap               = getOwnMap
M.getVehicleMap           = getVehicleMap
M.getNicknameMap          = getNicknameMap
M.getGameVehicleID        = getGameVehicleID
M.getServerVehicleID      = getServerVehicleID
M.onVehicleDestroyed      = onVehicleDestroyed
M.onVehicleSpawned        = onVehicleSpawned
M.deleteAllVehicles       = deleteAllVehicles
M.sendAllVehicles         = sendAllVehicles
M.sendVehicle             = sendVehicle
M.sendVehicleData         = sendVehicleData
M.sendCustomVehicleData   = sendCustomVehicleData
M.onServerVehicleSpawned  = onServerVehicleSpawned
M.onServerVehicleRemoved  = onServerVehicleRemoved
M.onVehicleResetted       = onVehicleResetted
M.onServerVehicleResetted = onServerVehicleResetted


print("vehicleGE Loaded.")
return M
