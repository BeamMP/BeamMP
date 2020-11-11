--====================================================================================
-- All work by jojos38, Titch2000 & 20dka.
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
print("MPVehicleGE Initialising...")


-- ============= VARIABLES =============
local lastResetTime = {}
local oneSecCounter = 0
local ownMap = {}
local vehiclesMap = {}
local nicknameMap = {}
local latestVeh
local invertedVehiclesMap = {}
local onVehicleDestroyedAllowed = true
local onVehicleSpawnedAllowed = true
local syncTimer = 0
local localCounter = 0
local vehiclesToSync = {}
local activeVehicle = 0

local roleToInfo = {
	['USER'] = { backcolor = ColorI(0, 0, 0, 127), tag = "" },
	['EA'] = { backcolor = ColorI(69, 0, 150, 127), tag = "[Early Access]" },
	['YT'] = { backcolor = ColorI(200, 0, 0, 127), tag = "[YouTuber]" },
	['ET'] = { backcolor = ColorI(210, 214, 109, 127), tag = "[Events Team]" },
	['SUPPORT'] = { backcolor = ColorI(68, 109, 184, 127), tag = "[Support]" },
	['MOD'] = { backcolor = ColorI(68, 109, 184, 127), tag = "[Moderator]" },
	['ADM'] = { backcolor = ColorI(218, 0, 78, 127), tag = "[Admin]" },
	['GDEV'] = { backcolor = ColorI(252, 107, 3, 127), tag = "[BeamNG Staff]" },
	['MDEV'] = { backcolor = ColorI(194, 55, 55, 127), tag = "[MP DEV]" }
}

-- ============= VARIABLES =============



--============== SOME FUNCTIONS ==============
-- SERVER VEHICLE ID ----> GAME VEHICLE ID
local function getGameVehicleID(serverVehicleID)
	return invertedVehiclesMap[tostring(serverVehicleID)]
end

-- GAME VEHICLE ID ----> SERVER VEHICLE ID
local function getServerVehicleID(gameVehicleID)
	return vehiclesMap[tostring(gameVehicleID)]
end

-- INSERT A VEHICLE SPAWNED TO THE MAP
local function insertVehicleMap(gameVehicleID, serverVehicleID)
	vehiclesMap[tostring(gameVehicleID)] = tostring(serverVehicleID)
	invertedVehiclesMap[tostring(serverVehicleID)] = tostring(gameVehicleID)
end

-- CHECK IF A USER OWNS A VEHICLE
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



--============================ SEND ONE VEHICLE ==============================
local function sendVehicle(gameVehicleID)
	local veh = be:getObjectByID(gameVehicleID) -- Get spawned vehicle ID
	if veh then -- In case of bug
		local vehicleTable = {}
		local vehicleData  = extensions.core_vehicle_manager.getVehicleData(gameVehicleID)
		local veh          = be:getObjectByID(gameVehicleID)
		local c            = veh.color
		local p0           = veh.colorPalette0
		local p1           = veh.colorPalette1
		local pos          = veh:getPosition()
		local rot          = veh:getRotation()

		vehicleTable.pid = mpConfig.getPlayerServerID() -- Player Server ID
		vehicleTable.vid = tostring(gameVehicleID) -- Game Vehicle ID
		vehicleTable.jbm = veh:getJBeamFilename() -- JBeam
		vehicleTable.vcf = vehicleData.config -- Vehicle Config
		vehicleTable.col = {c.x, c.y, c.z, c.w} -- Color Palette
		vehicleTable.cpz = {p0.x, p0.y, p0.z, p0.w} -- Color Palette 0
		vehicleTable.cpo = {p1.x, p1.y, p1.z, p1.w} -- Color Palette 1
		vehicleTable.pos = {pos.x, pos.y, pos.z} -- Position
		vehicleTable.rot = {rot.x, rot.y, rot.z, rot.w} -- Rotation

		local stringToSend = jsonEncode(vehicleTable) -- Encode table to send it as json string
		MPGameNetwork.send('Os:0:'..stringToSend) -- Send table that contain all vehicle informations for each vehicle
		print("Vehicle "..gameVehicleID.." was sent")
	end
end
--============================ SEND ONE VEHICLE ==============================



--=========================================== SEND MODIFIED VEHICLE DATA =============================================
local function sendCustomVehicleData(gameVehicleID)
	local vehicleTable = {} -- Vehicle table
	local vehicleData  = extensions.core_vehicle_manager.getVehicleData(gameVehicleID)
	local veh          = be:getObjectByID(gameVehicleID)
	local c            = veh.color
	local p0           = veh.colorPalette0
	local p1           = veh.colorPalette1

	vehicleTable.pid = mpConfig.getPlayerServerID()
	vehicleTable.jbm = veh:getJBeamFilename()
	vehicleTable.vcf = vehicleData.config
	vehicleTable.col = {c.x, c.y, c.z, c.w}
	vehicleTable.cpz = {p0.x, p0.y, p0.z, p0.w}
	vehicleTable.cpo = {p1.x, p1.y, p1.z, p1.w}

	local stringToSend = jsonEncode(vehicleTable) -- Encode table to send it as json string
	MPGameNetwork.send('Oc:'..getServerVehicleID(gameVehicleID)..':'..stringToSend) -- Send table that contain all vehicle informations for each vehicle
	print("Vehicle custom data "..gameVehicleID.." was sent")
end
--=========================================== SEND MODIFIED VEHICLE DATA =============================================

local function updateVehicle(serverID, data)
	local gameVehicleID = getGameVehicleID(serverID) -- Get the gameVehicleID
	if not gameVehicleID then print("gameVehicleID for "..serverID.." not found") return end

	local veh = be:getObjectByID(gameVehicleID) -- Get the vehicle
	if not veh then print("Vehicle "..gameVehicleID.." not found") return end

	local decodedData     = jsonDecode(data) -- Decode the data
	local vehicleName     = decodedData.jbm -- Vehicle name
	local vehicleConfig   = decodedData.vcf -- Vehicle config
	if vehicleName == veh:getJBeamFilename() and settings.getValue("showSyncConfigUpdates") then
		latestVeh = be:getPlayerVehicle(0) -- Camera fix
		print("Updating vehicle "..gameVehicleID.." config")
		local playerVehicle = extensions.core_vehicle_manager.getVehicleData(tonumber(gameVehicleID))
		tableMerge(playerVehicle.config, vehicleConfig)
		veh:respawn(serialize(playerVehicle.config))
	else
		print("The received data for "..vehicleName.." does not correspond with the vehicle "..veh:getJBeamFilename())
	end
end

local function onDisconnect()
	-- Clear ownMap and vehiclesMap
	ownMap = {}
	vehiclesMap = {}
	invertedVehiclesMap = {}
	nicknameMap = {}
end



--================================= ON VEHICLE SPAWNED (SERVER) ===================================
local function onServerVehicleSpawned(playerRole, playerNickname, serverVehicleID, data)
	local currentVeh = be:getPlayerVehicle(0) -- Camera fix
	local decodedData     = jsonDecode(data)
	local playerServerID  = decodedData.pid -- Server ID of the player that sent the vehicle
	local gameVehicleID   = decodedData.vid -- gameVehicleID of the player that sent the vehicle
	local vehicleName     = decodedData.jbm -- Vehicle name
	local vehicleConfig   = decodedData.vcf -- Vehicle config
	local c               = decodedData.col -- Vehicle color
	local cP0             = decodedData.cpz -- Vehicle colorPalette0
	local cP1             = decodedData.cpo -- Vehicle colorPalette1
	local pos             = vec3(decodedData.pos)
	local rot             = quat(decodedData.rot)

	print("Received a vehicle from server "..playerServerID)
	if mpConfig.getPlayerServerID() == playerServerID then -- If player ID = received player ID seems it's his own vehicle then sync it
		insertVehicleMap(gameVehicleID, serverVehicleID) -- Insert new vehicle ID in map
		ownMap[tostring(gameVehicleID)] = 1 -- Insert vehicle in own map
		print("ID is same as received ID, syncing vehicle gameVehicleID: "..gameVehicleID.." with ServerID: "..serverVehicleID)
	else
		onVehicleSpawnedAllowed = false
		local spawnedVeh = spawn.spawnVehicle(vehicleName, serialize(vehicleConfig), pos, rot, ColorF(c[1],c[2],c[3],c[4]), ColorF(cP0[1],cP0[2],cP0[3],cP0[4]), ColorF(cP1[1],cP1[2],cP1[3],cP1[4]), "multiplayerVeh", true)
		local spawnedVehID = spawnedVeh:getID()
		print("New vehicle spawn from server "..vehicleName.." with id "..spawnedVehID)
		insertVehicleMap(spawnedVehID, serverVehicleID) -- Insert new vehicle ID in map
		nicknameMap[spawnedVehID] = {
			nickname = playerNickname,
			role = playerRole
		}
		core_vehicles.setPlateText(playerNickname, spawnedVehID)
	end
	if currentVeh then be:enterVehicle(0, currentVeh) end -- Camera fix
end
--================================= ON VEHICLE SPAWNED (SERVER) ===================================



--================================= ON VEHICLE SPAWNED (CLIENT) ===================================
local function onVehicleSpawned(gameVehicleID)
	local veh = be:getObjectByID(gameVehicleID)
	if isOwn(gameVehicleID) ~= 1 and getServerVehicleID(gameVehicleID) == nil then -- If it's not an edit
		print("Vehicle Spawned "..gameVehicleID)
		local veh = be:getObjectByID(gameVehicleID)
		veh:queueLuaCommand("extensions.addModulePath('lua/vehicle/extensions/BeamMP')") -- Load lua files
		veh:queueLuaCommand("extensions.loadModulesInDirectory('lua/vehicle/extensions/BeamMP')")
		if MPGameNetwork.connectionStatus() > 0 then -- If TCP connected
			if onVehicleSpawnedAllowed then
				sendVehicle(gameVehicleID) -- Send it to the server
			else
				onVehicleSpawnedAllowed = true
			end
		end
	else
		print("Vehicle "..gameVehicleID.." was edited")
		syncTimer = 0
		vehiclesToSync[gameVehicleID] = 1.
		if latestVeh then
			be:enterVehicle(0, latestVeh)
			latestVeh = nil
		end -- Camera fix
	end
end
--================================= ON VEHICLE SPAWNED (CLIENT) ===================================



--================================= ON VEHICLE REMOVED (SERVER) ===================================
local function onServerVehicleRemoved(serverVehicleID)
	local gameVehicleID = getGameVehicleID(serverVehicleID) -- Get game ID
	if gameVehicleID then
		print("Vehicle destroyed by server "..serverVehicleID)
		local veh = be:getObjectByID(gameVehicleID) -- Get associated vehicle
		if veh then
			onVehicleDestroyedAllowed = false
			commands.setFreeCamera() -- Fix camera
			veh:delete() -- Remove it
			if commands.isFreeCamera(player) then commands.setGameCamera() end -- Fix camera
			vehiclesMap[gameVehicleID] = nil
			invertedVehiclesMap[serverVehicleID] = nil
		end
	else
		print("Removing vehicle "..serverVehicleID.." failed")
	end
end
--================================= ON VEHICLE REMOVED (SERVER) ===================================



--================================= ON VEHICLE REMOVED (CLIENT) ===================================
local function onVehicleDestroyed(gameVehicleID)
	print("Vehicle destroyed by user "..gameVehicleID)
	if MPGameNetwork.connectionStatus() > 0 then -- If TCP connected
		if onVehicleDestroyedAllowed then -- If function is not coming from onServerVehicleRemoved then
			local serverVehicleID = getServerVehicleID(gameVehicleID) -- Get the serverVehicleID
			if serverVehicleID then
				MPGameNetwork.send('Od:'..serverVehicleID)
			end
		else
			onVehicleDestroyedAllowed = true
		end
	end
end
--================================= ON VEHICLE REMOVED (CLIENT) ===================================



--======================= ON VEHICLE SWITCHED (CLIENT) =======================
local function onVehicleSwitched(oldID, newID)
	print("Vehicle switched from "..oldID.." to "..newID)
	if MPGameNetwork.connectionStatus() > 0 then -- If TCP connected
		local newID = getServerVehicleID(newID) -- Get new serverVehicleID of the new vehicle the player is driving
		if newID then -- If it's not null
			MPGameNetwork.send('Om:'..newID)--Network.buildPacket(1, 2122, newID, ""))
		end
	end
	activeVehicle = newID
end
--======================= ON VEHICLE SWITCHED (CLIENT) =======================



--======================= ON VEHICLE RESETTED (CLIENT) =======================
local function onVehicleResetted(gameVehicleID)
	if MPGameNetwork.connectionStatus() > 0 then -- If TCP connected
		local serverVehicleID = getServerVehicleID(gameVehicleID) -- Get new serverVehicleID of the new vehicle the player is driving
		if serverVehicleID and isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle -- If it's not null
			print("Vehicle "..gameVehicleID.." resetted by client")
			local veh = be:getObjectByID(gameVehicleID)
			local pos = veh:getPosition()
			local rot = veh:getRotation()
			local tempTable = {
				pos = {
					x = pos.x,
					y = pos.y,
					z = pos.z
				},
				rot = {
					x = rot.x,
					y = rot.y,
					z = rot.z,
					w = rot.w
				}
			}
			MPGameNetwork.send('Or:'..serverVehicleID..":"..jsonEncode(tempTable).."")
		end
	end
end
--======================= ON VEHICLE RESETTED (CLIENT) =======================



--======================= ON VEHICLE RESETTED (SERVER) =======================
local function onServerVehicleResetted(serverVehicleID, data)
	--print("Reset Event Received for a player")
	local gameVehicleID = getGameVehicleID(serverVehicleID) -- Get game ID
	if localCounter - (lastResetTime[serverVehicleID] or 0) > 0.2 then
		if gameVehicleID then
			local veh = be:getObjectByID(gameVehicleID) -- Get associated vehicle
			if veh then
				local pr = jsonDecode(data) -- Decoded data
				veh:reset()
				if pr then
					veh:setPositionRotation(pr.pos.x, pr.pos.y, pr.pos.z, pr.rot.x, pr.rot.y, pr.rot.z, pr.rot.w) -- Apply position
				else
				    print('onServerVehicleResetted data corrupted')
				end
			end
		else
			print("gameVehicleID for serverVehicleID "..serverVehicleID.." not found")
		end
	end
	lastResetTime[serverVehicleID] = localCounter
end
--======================= ON VEHICLE RESETTED (SERVER) =======================



local HandleNetwork = {
	['s'] = function(rawData)
		local playerRole = string.match(rawData,"(%w+)%:") -- Get the player role
		rawData = rawData:gsub(playerRole..":", "")
		local playerNickname = string.match(rawData,"^.-:")
		playerNickname = playerNickname:sub(1, #playerNickname - 1) -- Get the player nickname
		rawData = rawData:sub((#playerNickname + 2), #rawData)
		local serverVehicleID = string.match(rawData,"^.-:")
		serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1) -- Get the serverVehicleID
		local data = string.match(rawData,":(.*)") -- Get the vehicle data
		onServerVehicleSpawned(playerRole, playerNickname, serverVehicleID, data)
	end,
	['r'] = function(rawData)
		local serverVehicleID = string.match(rawData,"^.-:")
		serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1)
		local data = string.match(rawData,":(.*)")
		onServerVehicleResetted(serverVehicleID, data)
	end,
	['c'] = function(rawData)
		local serverVehicleID = string.match(rawData,"^.-:")
		serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1)
		local data = string.match(rawData,":(.*)")
		updateVehicle(serverVehicleID, data)
	end,
	['d'] = function(rawData)
		onServerVehicleRemoved(rawData)
	end
}



local function handle(rawData)
	local code = string.sub(rawData, 1, 1)
	local rawData = string.sub(rawData, 3)
	HandleNetwork[code](rawData)
end



local function removeRequest(gameVehicleID)
	if isOwn(gameVehicleID) then
		core_vehicles.removeCurrent(); commands.setFreeCamera() --extensions.hook("trackNewVeh")
		print("Request to remove car id "..gameVehicleID.." DONE")
	else
		print("Request to remove car id "..gameVehicleID.." DENIED")
	end
end

local function syncVehicles()
	for k,v in pairs(vehiclesToSync) do
		local veh = be:getObject(k) --  Get vehicle
		if veh then -- For loop always return one empty vehicle ?
			local gameVehicleID = veh:getID()
			print("Autosyncing vehicle "..gameVehicleID)
			sendCustomVehicleData(gameVehicleID)
		end
	end
	vehiclesToSync = {}
end



local function onUpdate(dt)
	if MPGameNetwork.connectionStatus() == 1 then -- If TCP connected
		if be:getObjectCount() == 0 then return end -- If no vehicle do nothing

		-- Vehicles syncing timer
		syncTimer = syncTimer + dt
		if syncTimer > 10 then
			syncVehicles()
			syncTimer = 0
		end

		local localPos = nil
		if activeVehicle then
			local veh = be:getObjectByID(tonumber(activeVehicle))
			if veh then
				localPos = veh:getPosition()
			end
		end

		for i = 0, be:getObjectCount() do -- For each vehicle
			local veh = be:getObject(i) --  Get vehicle
			if veh then -- For loop always return one empty vehicle ?
				local gameVehicleID = veh:getID()
				if not isOwn(gameVehicleID) and nicknameMap[gameVehicleID] and settings.getValue("showNameTags") then
					local pos = veh:getPosition()
					local dist = ""
					local roleInfo = roleToInfo[nicknameMap[gameVehicleID].role] or roleToInfo['USER']

					if localPos and settings.getValue("nameTagShowDistance") then
						local distfloat = math.sqrt(math.pow(localPos.x-pos.x, 2) + math.pow(localPos.y-pos.y, 2) + math.pow(localPos.z-pos.z, 2))
						if distfloat > 10 then
							dist = " "
							if settings.getValue("uiUnitLength") == "imperial" then
								distfloat = distfloat * 3.28084
								dist = tostring(math.floor(distfloat)).." ft"
							else
								dist = tostring(math.floor(distfloat)).." m"
							end
						end
					end

					pos.z = pos.z + 2.0 -- So it appears above the vehicle, not inside
					debugDrawer:drawTextAdvanced(
						pos, -- Position in 3D
						String(" "..tostring(nicknameMap[gameVehicleID].nickname).." "..roleInfo.tag..dist.." "), -- Text
						ColorF(1, 1, 1, 1), true, false, -- Foreground Color / Background / Wtf
						roleInfo.backcolor -- Background Color
					)
				end
			end
		end
		localCounter = localCounter + dt
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
M.sendVehicle             = sendVehicle
M.sendVehicleData         = sendVehicleData
M.sendCustomVehicleData   = sendCustomVehicleData
M.onServerVehicleSpawned  = onServerVehicleSpawned
M.onServerVehicleRemoved  = onServerVehicleRemoved
M.onVehicleResetted       = onVehicleResetted
M.onServerVehicleResetted = onServerVehicleResetted


print("MPVehicleGE Loaded.")
return M
