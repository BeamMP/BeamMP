--====================================================================================
-- All work by Titch2000, jojos38 and 20dka.
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
local nicknamePrefixMap = {}
local nicknameSuffixMap = {}
local distanceMap = {}
local nicknamesAllowed = true
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
-- GET A TABLE LENGTH
function tableLength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

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

-- RETURN THE MAP OF OWNED VEHICLES
local function getOwnMap()
    return ownMap
end

-- RETURN THE MAP OF ALL VEHICLES IDS
local function getVehicleMap()
    return vehiclesMap
end

-- RETURN THE MAP OF ALL VEHICLES DISTANCES FROM THE CURRENT ONE
local function getDistanceMap()
    return distanceMap
end

-- RETURN THE MAP OF ALL NICKNAMES
local function getNicknameMap() -- Returns a [localID] = "username" table of all vehicles, including own ones
	local nicknameSimple = {}
	for k,v in pairs(nicknameMap) do
		nicknameSimple[k] = v.nickname
	end
	local thisNick =  MPConfig.getNickname()
	for k,v in pairs(ownMap) do nicknameSimple[tonumber(k)] = thisNick end
    return nicknameSimple
end

local function setPlayerNickPrefix(name, prefix)
	nicknamePrefixMap[name] = prefix
end
local function setPlayerNickSuffix(name, suffix)
	nicknameSuffixMap[name] = suffix
end

-- SET WHETHER NICKNAMES ARE ALLOWED TO BE VISIBLE (can be used by mods in minigames)
local function hideNicknames(hide)
	nicknamesAllowed = not hide
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
		local rot          = quat(veh:getRotation())

		vehicleTable.pid = MPConfig.getPlayerServerID() -- Player Server ID
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

	vehicleTable.pid = MPConfig.getPlayerServerID()
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
	-- Clear all maps
	ownMap = {}
	vehiclesMap = {}
	invertedVehiclesMap = {}
	nicknameMap = {}
end

local function onServerVehicleCoupled(serverVehicleID, state)
	local gameVehicleID = getGameVehicleID(serverVehicleID) -- Get game ID
	if isOwn(gameVehicleID) ~= 1 then
		local veh = be:getObjectByID(gameVehicleID)
		veh:queueLuaCommand("couplerVE.toggleCouplerState('"..state.."')")
	end
end

local function sendBeamstate(state, gameVehicleID)
	MPGameNetwork.send('Ot:'..getServerVehicleID(gameVehicleID)..':'..state)
end

--================================= ON VEHICLE SPAWNED (SERVER) ===================================
local function onServerVehicleSpawned(playerRole, playerNickname, serverVehicleID, data)
	local currentVeh = be:getPlayerVehicle(0) -- Camera fix
	local decodedData     = jsonDecode(data)
	if not decodedData then --JSON decode failed
		log("E", "onServerVehicleSpawned", "Failed to spawn vehicle from "..playerNickname.."!")
		return
	end
	local playerServerID  = decodedData.pid -- Server ID of the player that sent the vehicle
	local gameVehicleID   = decodedData.vid -- gameVehicleID of the player that sent the vehicle
	local vehicleName     = decodedData.jbm -- Vehicle name
	local vehicleConfig   = decodedData.vcf -- Vehicle config
	local c               = decodedData.col -- Vehicle color
	local cP0             = decodedData.cpz -- Vehicle colorPalette0
	local cP1             = decodedData.cpo -- Vehicle colorPalette1
	local pos             = vec3(decodedData.pos)
	local rot             = decodedData.rot.w and quat(decodedData.rot) or quat(0,0,0,0) --ensure the rotation data is good

	print("Received a vehicle from server with serverVehicleID "..serverVehicleID)
	print("It is for "..playerNickname)
	if MPConfig.getPlayerServerID() == playerServerID then -- If player ID = received player ID seems it's his own vehicle then sync it
		insertVehicleMap(gameVehicleID, serverVehicleID) -- Insert new vehicle ID in map
		ownMap[tostring(gameVehicleID)] = true -- Insert vehicle in own map
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
				ownMap[tostring(gameVehicleID)] = nil
			end
		else
			onVehicleDestroyedAllowed = true
		end
	end
end
--================================= ON VEHICLE REMOVED (CLIENT) ===================================



--======================= ON VEHICLE SWITCHED (CLIENT) =======================
local function onVehicleSwitched(oldGameVehicleID, newGameVehicleID)
	--print("Vehicle switched from "..oldID.." to "..newID)
	if MPGameNetwork.connectionStatus() > 0 then -- If TCP connected
		local newServerVehicleID = getServerVehicleID(newGameVehicleID) -- Get new serverVehicleID of the new vehicle the player is driving
		if newServerVehicleID then -- If it's not null
			if not isOwn(newGameVehicleID) and settings.getValue("skipOtherPlayersVehicles") and tableLength(ownMap) > 0 then
				local curVehicle = be:getPlayerVehicle(0)
				local currGameVehicleID = curVehicle:getID()
				local vehicles = getAllVehicles()
				for index, vehicle in ipairs(vehicles) do
					local gameVehicleID = vehicle and vehicle:getID()
					if isOwn(gameVehicleID) and gameVehicleID ~= currGameVehicleID then
						be:enterVehicle(0, vehicles[index])
						break
					end
				end
			end
			MPGameNetwork.send('Om:'..newServerVehicleID)--Network.buildPacket(1, 2122, newID, ""))
		end
	end
	activeVehicle = newGameVehicleID
end
--======================= ON VEHICLE SWITCHED (CLIENT) =======================



--======================= ON VEHICLE RESETTED (CLIENT) =======================
local function onVehicleResetted(gameVehicleID)
	if MPGameNetwork.connectionStatus() > 0 then -- If TCP connected
		local serverVehicleID = getServerVehicleID(gameVehicleID) -- Get new serverVehicleID of the new vehicle the player is driving
		if serverVehicleID and isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle -- If it's not null
			--print("Vehicle "..gameVehicleID.." resetted by client")
			local veh = be:getObjectByID(gameVehicleID)
			local pos = veh:getPosition()
			local rot = quat(veh:getRotation())
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
		--dump(rawData)
		--print(playerRole, playerNickname, serverVehicleID)
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
	end,
	['t'] = function(rawData)
		local serverVehicleID = string.match(rawData,"^.-:")
		serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1)
		local data = string.match(rawData,":(.*)")
		onServerVehicleCoupled(serverVehicleID, data)
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

local function teleportVehToPlayer(targetName)
	print("tp vehicle to: "..targetName)
	if activeVehicle then
		local veh = be:getObjectByID(tonumber(activeVehicle))
		if veh then
			for i,n in pairs(nicknameMap) do
				if n.nickname == targetName then
					print("teleporting to ",i)

					local targetVeh = be:getObjectByID(i)
					local targetVehPos = targetVeh:getPosition()
					local targetVehRot = quat(targetVeh:getRotation()) -- vehicles forward are inverted

					targetVehPos.x = targetVehPos.x + 2.5
					targetVehPos.y = targetVehPos.y + 2.5

					--local up = vec3(0, 0, 1)
					--local yDir = vec3(0, 1, 0)
					--local rot = quatFromDir(yDir:rotated(quatFromDir(-vec3(targetVeh:getDirectionVector()), up)), up)
					--veh:setPositionRotation(targetVehPos.x, targetVehPos.y, targetVehPos.z, rot.x, rot.y, rot.z, rot.w) -- this reset the vehicle :()

					veh:setPosition(targetVehPos)
					--veh:autoplace(false)
					print("donesies")
					return
				end
			end
		else
			print("no veh, teleporting camera instead")
			teleportCameraToPlayer(targetName)
		end
	else
		print("no active vehicle, teleporting camera instead")
		teleportCameraToPlayer(targetName)
	end
end

local function teleportCameraToPlayer(targetName)
	print("tp camera to: "..targetName)
	local nickmap = getNicknameMap()
	for i,n in pairs(nickmap) do
		if n == targetName then
			print("found vehicle ",i, "active ",activeVehicle)
			local targetVeh = be:getObjectByID(i)

			if i ~= tonumber(activeVehicle) and targetVeh then
				print("entering vehicle ",i)
				be:enterVehicle(0,targetVeh)
				return
			end
		end
	end
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
				if not isOwn(gameVehicleID) and nicknameMap[gameVehicleID] then
					local pos = veh:getPosition()
					local nametagAlpha = 1
					local nametagFadeoutDistance = settings.getValue("nameTagFadeDistance") or 40

					if localPos then
						local distfloat = math.sqrt(math.pow(localPos.x-pos.x, 2) + math.pow(localPos.y-pos.y, 2) + math.pow(localPos.z-pos.z, 2))
						nametagAlpha = clamp(linearScale(distfloat, nametagFadeoutDistance, 0, 0, 1), 0, 1)
						distanceMap[gameVehicleID] = distfloat
					end

					if settings.getValue("showNameTags") and nicknamesAllowed then
						local dist = ""
						local roleInfo = roleToInfo[nicknameMap[gameVehicleID].role] or roleToInfo['USER']
						local backColor = roleInfo.backcolor

						if distanceMap[gameVehicleID] > 10 then
							if settings.getValue("uiUnitLength") == "imperial" then
								dist = " "..tostring(math.floor(distanceMap[gameVehicleID]*3.28084)).." ft"
							else
								dist = " "..tostring(math.floor(distanceMap[gameVehicleID])).." m"
							end
						end

						if not settings.getValue("nameTagShowDistance") then dist = "" end

						if settings.getValue("nameTagFadeEnabled") and not commands.isFreeCamera() then
							if settings.getValue("nameTagFadeInvert") then
								nametagAlpha = 1 - nametagAlpha
							else
								dist = ""
							end
						end

						if not settings.getValue("nameTagFadeEnabled") then nametagAlpha = 1 end
						backColor = ColorI(roleInfo.backcolor.r, roleInfo.backcolor.g, roleInfo.backcolor.b, math.floor(nametagAlpha*127))

						local prefix = nicknamePrefixMap[nicknameMap[gameVehicleID].nickname] or " "
						local suffix = nicknameSuffixMap[nicknameMap[gameVehicleID].nickname] and nicknameSuffixMap[nicknameMap[gameVehicleID].nickname].." " or ""

						pos.z = pos.z + 2.0 -- Offset nametag so it appears above the vehicle, not inside
						debugDrawer:drawTextAdvanced(
							pos, -- Location
							String(prefix..tostring(nicknameMap[gameVehicleID].nickname).." "..suffix..roleInfo.tag..dist.." "), -- Text
							ColorF(1, 1, 1, nametagAlpha), true, false, -- Foreground Color / Draw background / Wtf
							backColor -- Background Color
						)

						--"██▓▓▒▒░░"
					end
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
M.getDistanceMap          = getDistanceMap
M.getVehicleMap           = getVehicleMap
M.getNicknameMap          = getNicknameMap
M.setPlayerNickPrefix     = setPlayerNickPrefix
M.setPlayerNickSuffix     = setPlayerNickSuffix
M.hideNicknames           = hideNicknames
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
M.sendBeamstate           = sendBeamstate
M.onServerVehicleCoupled  = onServerVehicleCoupled

M.teleportVehToPlayer     = teleportVehToPlayer
M.teleportCameraToPlayer  = teleportCameraToPlayer

print("MPVehicleGE Loaded.")
return M
