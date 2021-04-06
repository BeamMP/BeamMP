--====================================================================================
-- All work by Titch2000, jojos38 and 20dka.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading MPVehicleGE...")


-- ============= VARIABLES =============
local lastResetTime = {}
local oneSecCounter = 0
local ownMap = {}
local vehiclesMap = {}
local jbeamMap = {}
local nicknameMap = {}
local nickIDMap = {}
local nicknamePrefixMap = {}
local nicknameSuffixMap = {}
local distanceMap = {}
local nicknamesAllowed = true
local invertedVehiclesMap = {}
local onVehicleDestroyedAllowed = true
local onVehicleSpawnedAllowed = true
local syncTimer = 0
local localCounter = 0
local vehiclesToSync = {}

local vehicleSpawnQueue = {}
local vehicleEditQueue = {}

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

-- ============= VARIABLES =============



--============== SOME FUNCTIONS ==============

-- SERVER VEHICLE ID ----> GAME VEHICLE ID
local function getGameVehicleID(serverVehicleID)
	return invertedVehiclesMap[serverVehicleID]
end

-- GAME VEHICLE ID ----> SERVER VEHICLE ID
local function getServerVehicleID(gameVehicleID)
	if type(gameVehicleID) == "string" then
		print("getServerVehicleID received string ID, please use numbers")
		gameVehicleID = tonumber(gameVehicleID)
	end
	return vehiclesMap[gameVehicleID]
end

-- INSERT A VEHICLE SPAWNED TO THE MAP
local function insertVehicleMap(gameVehicleID, serverVehicleID)
	vehiclesMap[gameVehicleID] = serverVehicleID
	invertedVehiclesMap[serverVehicleID] = gameVehicleID
end

-- CHECK IF A USER OWNS A VEHICLE
local function isOwn(gameVehicleID)
	if type(gameVehicleID) == "string" then
		print("isOwn received string ID, please use numbers")
		gameVehicleID = tonumber(gameVehicleID)
	end
    return ownMap[gameVehicleID] ~= nil
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
	for k,v in pairs(ownMap) do nicknameSimple[k] = thisNick end
    return nicknameSimple
end

local function getNicknameFromID(id)
	return nickIDMap[id]
end

local function setPlayerNickPrefix(targetName, tagSource, text)
	if text == nil then text = tagSource; tagSource = "default" end
	nicknamePrefixMap[targetName] = { [tagSource] = text }
end
local function setPlayerNickSuffix(targetName, tagSource, text)
	if text == nil then text = tagSource; tagSource = "default" end
	nicknameSuffixMap[targetName] = { [tagSource] = text }
end

-- SET WHETHER NICKNAMES ARE ALLOWED TO BE VISIBLE (can be used by mods in minigames)
local function hideNicknames(hide)
	nicknamesAllowed = not hide
end
--============== SOME FUNCTIONS ==============



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
	vehiclesToSync[gameVehicleID] = nil
end
--=========================================== SEND MODIFIED VEHICLE DATA =============================================



local function applyVehEdit(serverID, data)

	local gameVehicleID = getGameVehicleID(serverID) -- Get the gameVehicleID
	if not gameVehicleID then log('W','beammp.applyEdit',"gameVehicleID for "..serverID.." not found") return end

	local veh = be:getObjectByID(gameVehicleID) -- Get the vehicle
	if not veh then log('W','beammp.applyEdit',"Vehicle "..gameVehicleID.." not found") return end

	local decodedData     = jsonDecode(data) -- Decode the data
	local vehicleName     = decodedData.jbm -- Vehicle name
	local vehicleConfig   = decodedData.vcf -- Vehicle config
	if vehicleName == veh:getJBeamFilename() then
		log('W','beammp.applyEdit',"Updating vehicle "..gameVehicleID.." config")
		local playerVehicle = extensions.core_vehicle_manager.getVehicleData(gameVehicleID)

		local partsDiff = MPHelpers.tableDiff(playerVehicle.config.parts, vehicleConfig.parts)
		local tuningDiff = MPHelpers.tableDiff(playerVehicle.config.vars, vehicleConfig.vars)

		local configChanged = tableSize(partsDiff) > 0 or tableSize(tuningDiff) > 0
		local colorChanged = not MPHelpers.colorMatch(playerVehicle.config.colors, vehicleConfig.colors)

		if configChanged or colorChanged then
			tableMerge(playerVehicle.config, vehicleConfig)

			--dump(configChanged)
			--dump(partsDiff)
			--dump(tuningDiff)

			if configChanged then
				veh:respawn(serialize(playerVehicle.config))
			else
				print("only color changed")
				extensions.core_vehicle_manager.liveUpdateVehicleColors(gameVehicleID)
			end
		else
			print("received edit matches local copy, ignoring")
		end
	else
		log('W','beammp.applyEdit',"The received data for "..vehicleName.." does not correspond with the vehicle "..veh:getJBeamFilename())


		local c   = decodedData.col and ColorF(decodedData.col[1],decodedData.col[2],decodedData.col[3],decodedData.col[4]) or nil
		local p0  = decodedData.cpz and ColorF(decodedData.cpz[1],decodedData.cpz[2],decodedData.cpz[3],decodedData.cpz[4]) or nil
		local p1  = decodedData.cpo and ColorF(decodedData.cpo[1],decodedData.cpo[2],decodedData.cpo[3],decodedData.cpo[4]) or nil
		local pos = veh:getPosition()
		local rot = quat(veh:getRotation())

		print("Updating vehicle from server "..vehicleName.." with id "..serverID)
		spawn.setVehicleObject(veh, vehicleName, serialize(vehicleConfig), pos, rot, c, p0, p1, true)

		--playerVehicle:setField('name', '', vehicleName or "")
	end
end

local function updateVehicle(serverID, data)
	if settings.getValue("enableSpawnQueue") then
		vehicleEditQueue[serverID] = data
		print('edit received and queued')
		local id = string.match(serverID,"^(.*)-")
		local playerNickname = nickIDMap[id] or "unknown"
		UI.updateQueue(vehicleSpawnQueue, vehicleEditQueue, true)
		UI.showNotification('Edit received and queued for '..playerNickname)
	else
		local currentVeh = be:getPlayerVehicle(0) -- Camera fix

		applyVehEdit(serverID, data)
		UI.updateQueue({}, {}, false)

		if currentVeh then be:enterVehicle(0, currentVeh) end -- Camera fix
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


local function applyVehSpawn(event)

	local decodedData     = jsonDecode(event.data)
	if not decodedData then --JSON decode failed
		log("E", "onServerVehicleSpawned", "Failed to spawn vehicle from "..event.playerNickname.."!")
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

	print("Received a vehicle from server with serverVehicleID "..event.serverVehicleID)
	print("It is for "..event.playerNickname)

	onVehicleSpawnedAllowed = false -- this flag is used to indicate whether the next spawn is remote or not

	local allowed = false
	local vehiclesList = extensions.core_vehicles.getModelNames()
	for index, value in ipairs(vehiclesList) do
		if vehicleName == value then allowed = true end
	end
	if not allowed then
		print("This received vehicle "..vehicleName.." is not currently installed on the game, cancelling the spawn")
		UI.showNotification("info", "Player "..event.playerNickname.." spawned an illegal vehicle ("..vehicleName.."), it was skipped")
		return
	end


	local spawnedVehID = getGameVehicleID(event.serverVehicleID)

	local spawnedVeh = spawnedVehID and be:getObjectByID(spawnedVehID) or nil

	if spawnedVeh then
		print("(spawn)Updating vehicle from server "..vehicleName.." with id "..spawnedVehID)
		spawn.setVehicleObject(spawnedVeh, vehicleName, serialize(vehicleConfig), pos, rot, ColorF(c[1],c[2],c[3],c[4]), ColorF(cP0[1],cP0[2],cP0[3],cP0[4]), ColorF(cP1[1],cP1[2],cP1[3],cP1[4]), true)
	else
		spawnedVeh = spawn.spawnVehicle(vehicleName, serialize(vehicleConfig), pos, rot, ColorF(c[1],c[2],c[3],c[4]), ColorF(cP0[1],cP0[2],cP0[3],cP0[4]), ColorF(cP1[1],cP1[2],cP1[3],cP1[4]), "multiplayerVeh", true, false)
		spawnedVehID = spawnedVeh:getID()
		print("New vehicle spawn from server "..vehicleName.." with id "..spawnedVehID)
		insertVehicleMap(spawnedVehID, event.serverVehicleID) -- Insert new vehicle ID in map
		nicknameMap[spawnedVehID] = {
			nickname = event.playerNickname,
			role = event.playerRole
		}
	end

	jbeamMap[spawnedVehID] = vehicleName

	core_vehicles.setPlateText(event.playerNickname, spawnedVehID)
	spawnedVeh:queueLuaCommand("hydros.onFFBConfigChanged(nil)")
end

--================================= ON VEHICLE SPAWNED (SERVER) ===================================
local function onServerVehicleSpawned(playerRole, playerNickname, serverVehicleID, data)

	local decodedData = jsonDecode(data)
	if not decodedData then --JSON decode failed
		log("E", "onServerVehicleSpawned", "Failed to spawn vehicle from "..playerNickname.."!")
		return
	end

	local playerServerID   = decodedData.pid -- Server ID of the player that sent the vehicle
	local gameVehicleIDstr = decodedData.vid -- gameVehicleID of the player that sent the vehicle
	local gameVehicleID    = tonumber(gameVehicleIDstr) -- gameVehicleID of the player that sent the vehicle

	local id = string.match(serverVehicleID,"^(.*)-")

	print('player '..playerNickname.." has id "..id)
	nickIDMap[id] = playerNickname

	print("Received a vehicle from server with serverVehicleID "..serverVehicleID)
	print("It is for "..playerNickname)
	if MPConfig.getPlayerServerID() == playerServerID then -- If player ID = received player ID seems it's his own vehicle then sync it
		if gameVehicleID then
			insertVehicleMap(gameVehicleID, serverVehicleID) -- Insert new vehicle ID in map
			ownMap[gameVehicleID] = true -- Insert vehicle in own map
			print("ID is same as received ID, syncing vehicle gameVehicleID: "..gameVehicleIDstr.." with ServerID: "..serverVehicleID)
		else
			print("bad data received, aborting")
			return;
		end
	else

		local eventdata = {}
		eventdata.playerRole = playerRole
		eventdata.playerNickname = playerNickname
		eventdata.serverVehicleID = serverVehicleID
		eventdata.data = data

		if settings.getValue("enableSpawnQueue") and not (settings.getValue("queueSkipUnicycle") and decodedData.jbm == "unicycle") then

			vehicleSpawnQueue[serverVehicleID] = eventdata
			print('queue enabled adding spawn for '..playerNickname)

			UI.updateQueue(vehicleSpawnQueue, vehicleEditQueue, true)

			UI.showNotification('Spawn received and queued for '..playerNickname)

		else

			print('queue disabled, spawning now')

			--local currentVeh = be:getPlayerVehicle(0) -- Camera fix

			applyVehSpawn(eventdata)
			UI.updateQueue({}, {}, false)

			--if currentVeh then be:enterVehicle(0, currentVeh) end -- Camera fix
		end
	end
end
--================================= ON VEHICLE SPAWNED (SERVER) ===================================



--================================= ON VEHICLE SPAWNED (CLIENT) ===================================
local function onVehicleSpawned(gameVehicleID)

	if not MPCoreNetwork.isMPSession() then return end -- do nothing if singleplayer

	local veh = be:getObjectByID(gameVehicleID)


	print("SPAWN")
	dump(veh.mpVehicleType)
	dump(isOwn(gameVehicleID) ~= 1)
	dump(getServerVehicleID(gameVehicleID) == nil)
	dump(jbeamMap[gameVehicleID])


	if not jbeamMap[gameVehicleID] then -- If it's not an edit
		print("New Vehicle Spawned "..gameVehicleID)

		veh:queueLuaCommand("extensions.addModulePath('lua/vehicle/extensions/BeamMP')") -- Load lua files
		veh:queueLuaCommand("extensions.loadModulesInDirectory('lua/vehicle/extensions/BeamMP')")


		if onVehicleSpawnedAllowed then -- if false then we spawned it (from server)
			sendVehicle(gameVehicleID) -- Send it to the server
		end

		onVehicleSpawnedAllowed = true


	else

		if jbeamMap[gameVehicleID] ~= veh:getJBeamFilename() then
			print("Vehicle Updated")

			veh:queueLuaCommand("extensions.addModulePath('lua/vehicle/extensions/BeamMP')") -- Load lua files
			veh:queueLuaCommand("extensions.loadModulesInDirectory('lua/vehicle/extensions/BeamMP')")

			if onVehicleSpawnedAllowed then -- if false then we spawned it (from server)
				sendCustomVehicleData(gameVehicleID) -- Send it to the server (as a sync)
			end

			onVehicleSpawnedAllowed = true
			
		else
			print("Vehicle "..gameVehicleID.." was edited")
			syncTimer = 0
			vehiclesToSync[gameVehicleID] = 1.
		end
	end
	
	jbeamMap[gameVehicleID] = veh:getJBeamFilename()
end
--================================= ON VEHICLE SPAWNED (CLIENT) ===================================



--================================= ON VEHICLE REMOVED (SERVER) ===================================
local function onServerVehicleRemoved(serverVehicleID)
	vehicleEditQueue[serverVehicleID] = nil
	UI.updateQueue(vehicleSpawnQueue or {}, vehicleEditQueue or {})

	if vehicleSpawnQueue[serverVehicleID] then
		print("Vehicle "..serverVehicleID.." is still in the queue, can't remove")
		print(vehicleSpawnQueue[serverVehicleID])
		vehicleSpawnQueue[serverVehicleID] = nil
		UI.updateQueue(vehicleSpawnQueue or {}, vehicleEditQueue or {})
		return
	end

	local gameVehicleID = getGameVehicleID(serverVehicleID) -- Get game ID
	if gameVehicleID then
		if nicknameMap[gameVehicleID] then nicknameMap[gameVehicleID] = nil end
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
	if nicknameMap[gameVehicleID] then nicknameMap[gameVehicleID] = nil end
	print("Vehicle destroyed by user "..gameVehicleID)
	if MPGameNetwork.connectionStatus() > 0 then -- If TCP connected
		if onVehicleDestroyedAllowed then -- If function is not coming from onServerVehicleRemoved then
			local serverVehicleID = getServerVehicleID(gameVehicleID) -- Get the serverVehicleID
			if serverVehicleID then
				MPGameNetwork.send('Od:'..serverVehicleID)
				ownMap[gameVehicleID] = nil
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
	if MPCoreNetwork.isMPSession() then -- If TCP connected
		local newServerVehicleID = getServerVehicleID(newGameVehicleID) -- Get new serverVehicleID of the new vehicle the player is driving
		if newServerVehicleID then -- If it's not null
			if not isOwn(newGameVehicleID) and (settings.getValue("skipOtherPlayersVehicles") or jbeamMap[newGameVehicleID] == "unicycle") and tableSize(ownMap) > 0 then
				be:enterNextVehicle(0, 1) extensions.hook('trackNewVeh')
			end

			-- enter a remote car as a passenger
			if not isOwn(newGameVehicleID) and jbeamMap[oldGameVehicleID] == "unicycle" then
				--core_camera.setByName(0,"onboard.rider") -- citybus
				core_camera.setByName(0,"passenger") -- auto generated
				core_camera.setByName(0,"onboard.passenger") -- custom
				print("enter passenger")
			end

			MPGameNetwork.send('Om:'..newServerVehicleID)--Network.buildPacket(1, 2122, newID, ""))
		end
	end
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
	['s'] = function(rawData) -- spawn
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
	['r'] = function(rawData) -- reset
		local serverVehicleID = string.match(rawData,"^.-:")
		serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1)
		local data = string.match(rawData,":(.*)")
		onServerVehicleResetted(serverVehicleID, data)
	end,
	['c'] = function(rawData) -- config sync
		local serverVehicleID = string.match(rawData,"^.-:")
		serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1)
		local data = string.match(rawData,":(.*)")
		updateVehicle(serverVehicleID, data)
	end,
	['d'] = function(rawData) -- remove
		onServerVehicleRemoved(rawData)
	end,
	['t'] = function(rawData) -- coupler
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


local function saveDefaultRequest()
	local currentVehicle = be:getPlayerVehicle(0)
	if not MPCoreNetwork.isMPSession() or currentVehicle and isOwn(currentVehicle:getID()) then
		extensions.core_vehicle_partmgmt.savedefault()
		print("Request to save car DONE")
	else
		guihooks.trigger('Message', {ttl = 5, msg = "Cant't set another player's vehicle as default", icon = 'error'})
		print("Request to save car id DENIED")
	end
end

local function spawnDefaultRequest()
	if not MPCoreNetwork.isMPSession() then core_vehicles.spawnDefault(); extensions.hook("trackNewVeh"); return; end


	local currentVehicle = be:getPlayerVehicle(0)
	local defaultConfig = jsonReadFile('settings/default.pc')

	if currentVehicle then
		local gameVehicleID = currentVehicle:getID()
		jbeamMap[gameVehicleID] = '-'
		if isOwn(gameVehicleID) then
			core_vehicles.replaceVehicle(defaultConfig and defaultConfig.model or core_vehicles.defaultVehicleModel, defaultConfig and {config = 'settings/default.pc', licenseText = defaultConfig.licenseName} or {})
		else
			core_vehicles.spawnNewVehicle(defaultConfig and defaultConfig.model or core_vehicles.defaultVehicleModel, defaultConfig and {config = 'settings/default.pc', licenseText = defaultConfig.licenseName} or {})
		end
	else

		core_vehicles.spawnNewVehicle(defaultConfig and defaultConfig.model or core_vehicles.defaultVehicleModel, defaultConfig and {config = 'settings/default.pc', licenseText = defaultConfig.licenseName} or {})

	end
	extensions.hook("trackNewVeh")
end


local function spawnRequest(model, config, colors)

	dump(model)
	dump(config)
	if colors then
		local colors = core_vehicle_colors.colorStringToColorTable(colors)
		colors[4] = colors[4]*2
	end

	dump(colors)

	local currentVehicle = be:getPlayerVehicle(0)

	if currentVehicle and isOwn(currentVehicle:getID()) and not config.spawnNew then
		jbeamMap[currentVehicle:getID()] = '-'
		return core_vehicles.replaceVehicle(model, config or {})
		--core_vehicles.replaceVehicle(model, config and {config = config, color = colors or nil, licenseText = config.licenseName} or {})
	else
		return core_vehicles.spawnNewVehicle(model, config or {})
		--core_vehicles.spawnNewVehicle(model, config and {config = config, color = colors or nil, licenseText = config.licenseName} or {})
	end
	--extensions.hook("trackNewVeh")
end

local function saveConfigRequest(configfilename)
	if not MPCoreNetwork.isMPSession() then extensions.core_vehicle_partmgmt.saveLocal(configfilename); return; end

	local currentVehicle = be:getPlayerVehicle(0)

	if currentVehicle and isOwn(currentVehicle:getID()) then
		extensions.core_vehicle_partmgmt.saveLocal(configfilename)
		print("saved config")
	else
		guihooks.trigger("saveLocalScreenshot_stage3", {})
		guihooks.trigger('Message', {ttl = 10, msg = "Saving another player's vehicle is disabled", icon = 'error'})
		--extensions.core_vehicle_partmgmt.saveLocal(configfilename)
		print("didnt save config")
	end
end


local function syncVehicles()
	for k,v in pairs(vehiclesToSync) do
		local veh = be:getObjectByID(k) --  Get vehicle
		if veh then -- For loop always return one empty vehicle ?
			local gameVehicleID = veh:getID()
			print("Autosyncing vehicle "..gameVehicleID)
			sendCustomVehicleData(gameVehicleID)
		end
	end
	vehiclesToSync = {}
end



local lastQuery = -1 --get player pos on first run
local groundmarkerRoads = {}
local gmTargetPlayer = nil

local function queryRoadNodeToPosition(position, owner)
	if not owner then owner = "target" end
	--log('I',logTag, 'queryRoadNodeToPosition called...')
	local pos = vec3(position)
	local first, second, distance = map.findClosestRoad(pos)
	if not first and not second then return false end
	local state = M.state
	--log('D', logTag, 'queryRoadNodeToPosition '..owner..': '..first..','..second..','..distance)
	groundmarkerRoads[owner] = {position=position}
	if first ~= 'nil' and second ~= 'nil' then
		groundmarkerRoads[owner].first = first
		groundmarkerRoads[owner].next = second

		local mapData = map.getMap()
		local node1 = mapData.nodes[first]
		local node2 = mapData.nodes[second]
		if node1 and node2 then
			-- find which node is closest to the owner
			local sqrDist1 = (pos - node1.pos):squaredLength()
			local sqrDist2 = (pos - node2.pos):squaredLength()

			if sqrDist1 < sqrDist2 then groundmarkerRoads[owner].best = first
			else groundmarkerRoads[owner].best = second end
		end
	end
	return true
end


local function groundmarkerToPlayer(targetName)
	for i,n in pairs(nicknameMap) do
		if n.nickname == targetName then
			local targetVeh = be:getObjectByID(i)
			local targetVehPos = targetVeh:getPosition()
			local vec3Pos = vec3(targetVehPos.x, targetVehPos.y, targetVehPos.z)

			queryRoadNodeToPosition(vec3Pos, "targetVeh")
			return
		end
	end
end

local function groundmarkerFollowPlayer(targetName, dontfollow)
	if dontfollow then --static
		groundmarkerToPlayer(targetName)
	else
		if targetName then gmTargetPlayer = targetName
		else
			gmTargetPlayer = nil
			groundmarkerRoads["targetVeh"] = nil
		end
	end
end

local function onPreRender(dt)
	local vehicle = be:getPlayerVehicle(0)
	if not vehicle then return end

	lastQuery = lastQuery - dt
	if lastQuery <= 0 then
		lastQuery = 0.2
		local vehiclePos = vehicle:getPosition()
		queryRoadNodeToPosition(vehiclePos, 'player')
		if gmTargetPlayer then groundmarkerToPlayer(gmTargetPlayer) end
	end

	local playerRoadData = groundmarkerRoads['player']
	if playerRoadData and playerRoadData.first and playerRoadData.first ~= 'nil' then
		for target,data in pairs(groundmarkerRoads) do
			if target ~= 'player' then
				if data.best then
					core_groundMarkers.setFocus(data.best)
				end
			end
		end
	end
end





local function teleportVehToPlayer(targetName)
	local activeVehicle = be:getPlayerVehicle(0)

	if activeVehicle then
		for i,n in pairs(nicknameMap) do
			if n.nickname == targetName then
				--print("teleporting to "..tostring(i))
				local targetVeh = be:getObjectByID(i)
				local targetVehPos = targetVeh:getPosition()
				local targetVehRot = quatFromDir(vec3(targetVeh:getDirectionVector()), vec3(targetVeh:getDirectionVectorUp()))

				local vec3Pos = vec3(targetVehPos.x, targetVehPos.y, targetVehPos.z)

				spawn.safeTeleport(activeVehicle, vec3Pos, targetVehRot, false)
				return
			end
		end
	else
		print("no active vehicle, teleporting camera instead")
		focusCameraOnPlayer(targetName)
	end
end

local function focusCameraOnPlayer(targetName)
	local activeVehicle = be:getPlayerVehicle(0)
	local activeVehicleID = activeVehicle and activeVehicle:getID() or nil
	print("tp camera to: "..targetName)
	local nickmap = getNicknameMap()
	for i,n in pairs(nickmap) do
		if n == targetName then
			print("found vehicle ",i, "active ", activeVehicleID)
			local targetVeh = be:getObjectByID(i)

			if i ~= activeVehicleID and targetVeh then
				print("entering vehicle ",i)
				be:enterVehicle(0,targetVeh)
				return
			end
		end
	end
end

local function applyQueuedEvents()
	UI.updateQueue(vehicleSpawnQueue or {}, vehicleEditQueue or {})
	--if not vehicleSpawnQueue then return end

	local currentVeh = be:getPlayerVehicle(0) -- Camera fix
	--dump(vehicleSpawnQueue)
	for vehicleID, spawn in pairs(vehicleSpawnQueue) do
		print("spawn")
		applyVehSpawn(spawn)
		vehicleSpawnQueue[vehicleID] = nil
		UI.updateQueue(vehicleSpawnQueue or {}, vehicleEditQueue or {})
	end

	--if not vehicleEditQueue then return end
	--dump(vehicleEditQueue)
	for vehicleID, edit in pairs(vehicleEditQueue) do
		print("edit")
		applyVehEdit(vehicleID, edit)
		vehicleEditQueue[vehicleID] = nil
		UI.updateQueue(vehicleSpawnQueue or {}, vehicleEditQueue or {})
	end

	if currentVeh then be:enterVehicle(0, currentVeh) end -- Camera fix
end

local function onUpdate(dt)
	if MPGameNetwork.connectionStatus() == 1 then -- If TCP connected

		local cameraPos = vec3(getCameraPosition())
		local currveh = be:getPlayerVehicle(0)
		if currveh then
			local vel = vec3()
			vel:set(currveh:getVelocity())
			if (not isOwn(currveh:getID()) and settings.getValue("queueAutoSkipRemote")) or (settings.getValue("enableQueueAuto") and math.abs(vel:length() or 0) < 0.5) then applyQueuedEvents() end
			if not commands.isFreeCamera() then cameraPos = vec3(currveh:getPosition()) end
		else applyQueuedEvents() end

		if not be:getPlayerVehicle(0) and not commands.isFreeCamera() then
			commands.setFreeCamera()         -- Fix camera
		end

		if be:getObjectCount() == 0 then return end -- If no vehicle do nothing
		-- Vehicles syncing timer
		syncTimer = syncTimer + dt
		if syncTimer > 10 then
			if settings.getValue("autoSyncVehicles") then syncVehicles() end
			syncTimer = 0
		end

		for i = 0, be:getObjectCount()-1 do -- For each vehicle
			local veh = be:getObject(i) --  Get vehicle
			local gameVehicleID = veh:getID()
			if not isOwn(gameVehicleID) and nicknameMap[gameVehicleID] then
				local pos = veh:getPosition()
				local nametagAlpha = 1
				local nametagFadeoutDistance = settings.getValue("nameTagFadeDistance") or 40

				local distfloat = (cameraPos or vec3()):distance(pos)
				nametagAlpha = clamp(linearScale(distfloat, nametagFadeoutDistance, 0, 0, 1), 0, 1)
				distanceMap[gameVehicleID] = distfloat

				if not settings.getValue("hideNameTags") and nicknamesAllowed then
					local dist = ""
					local roleInfo = roleToInfo[nicknameMap[gameVehicleID].role] or roleToInfo['USER']
					local backColor = roleInfo.backcolor

					if distanceMap[gameVehicleID] > 10 then
						local d
						if settings.getValue("uiUnitLength") == "imperial" then
							local ft = distanceMap[gameVehicleID]*3.28084
							if ft > 5280 then
								local mi = math.floor( (ft / 5280 * 100) + 0.5) / 100
								d = tostring(mi).." mi"
							else
								d = tostring(math.floor(ft)).." ft"
							end
						else
							if distanceMap[gameVehicleID] > 1000 then
								local km = math.floor((distanceMap[gameVehicleID] / 10) + 0.5) / 100
								d = tostring(km).." km"
							else
								d = tostring(math.floor(distanceMap[gameVehicleID])).." m"
							end
						end
						dist = " "..d
					end

					if not settings.getValue("nameTagShowDistance") then dist = "" end

					if settings.getValue("fadeVehicles") then
						if currveh:getID() == gameVehicleID then veh:setMeshAlpha(1, "", false)
						else veh:setMeshAlpha(1-nametagAlpha, "", false) end
					end

					if settings.getValue("nameTagFadeEnabled") and not commands.isFreeCamera() then
						if settings.getValue("nameTagFadeInvert") then
							nametagAlpha = 1 - nametagAlpha
						else
							dist = ""
						end
					end

					if not settings.getValue("nameTagFadeEnabled") then nametagAlpha = 1 end
					backColor = ColorI(roleInfo.backcolor.r, roleInfo.backcolor.g, roleInfo.backcolor.b, math.floor(nametagAlpha*127))

					local prefix = ""
					for source, tag in pairs(nicknamePrefixMap[nicknameMap[gameVehicleID].nickname] or {}) 
						do prefix = prefix..tag.." " end
					
					local suffix = ""
					for source, tag in pairs(nicknameSuffixMap[nicknameMap[gameVehicleID].nickname] or {}) 
						do suffix = suffix..tag.." " end

					pos.z = pos.z + 2.0 -- Offset nametag so it appears above the vehicle, not inside
					debugDrawer:drawTextAdvanced(
						pos, -- Location
						String(" "..prefix..tostring(nicknameMap[gameVehicleID].nickname)..suffix..roleInfo.tag..dist.." "), -- Text
						ColorF(1, 1, 1, nametagAlpha), true, false, -- Foreground Color / Draw background / Wtf
						backColor -- Background Color
					)
				end
			end
		end
		localCounter = localCounter + dt
	end
end



--DEBUG
M.queryRoadNodeToPosition = queryRoadNodeToPosition


-- EVENTS
M.onUpdate                 = onUpdate
M.onPreRender              = onPreRender
M.onVehicleSwitched        = onVehicleSwitched
M.onDisconnect             = onDisconnect
M.handle                   = handle
M.onVehicleDestroyed       = onVehicleDestroyed
M.onVehicleSpawned         = onVehicleSpawned
M.onServerVehicleSpawned   = onServerVehicleSpawned
M.onServerVehicleRemoved   = onServerVehicleRemoved
M.onVehicleResetted        = onVehicleResetted
M.onServerVehicleResetted  = onServerVehicleResetted
M.onServerVehicleCoupled   = onServerVehicleCoupled


-- FUNCTIONS
M.isOwn                    = isOwn                    -- takes: vehID  returns: bool
M.getOwnMap                = getOwnMap                -- takes: -      returns: { 'vehid' : true, '23456' : true }
M.getDistanceMap           = getDistanceMap           -- takes: -      returns: { vehid : distanceinmeters, 123: 56 }
M.getVehicleMap            = getVehicleMap            -- takes: -
M.getNicknameMap           = getNicknameMap           -- takes: -
M.hideNicknames            = hideNicknames            -- takes: bool   returns: -
M.setPlayerNickPrefix      = setPlayerNickPrefix      -- takes: string targetName, string tagSource, string text
M.setPlayerNickSuffix      = setPlayerNickSuffix      -- takes: string targetName, string tagSource, string text
M.getGameVehicleID         = getGameVehicleID         -- takes: -      returns: { 'gamevehid' : 'servervehid', '23456' : '1-2' }
M.getServerVehicleID       = getServerVehicleID       -- takes: -      returns: { 'servervehid' : 'gamevehid', '1-2' : '23456' }
M.saveConfigRequest        = saveConfigRequest        -- takes: string configFilename
M.saveDefaultRequest       = saveDefaultRequest       -- takes: -
M.spawnDefaultRequest      = spawnDefaultRequest      -- takes: -
M.spawnRequest             = spawnRequest             -- takes: jbeamName, options table containing 'spawnNew' key
M.sendBeamstate            = sendBeamstate            -- 
M.applyQueuedEvents        = applyQueuedEvents        -- takes: -      returns: -
M.teleportVehToPlayer      = teleportVehToPlayer      -- takes: string targetName
M.teleportCameraToPlayer   = focusCameraOnPlayer      -- takes: string targetName NOTE: DEPRECATED
M.focusCameraOnPlayer      = focusCameraOnPlayer      -- takes: string targetName
M.groundmarkerToPlayer     = groundmarkerToPlayer     -- takes: string targetName
M.groundmarkerFollowPlayer = groundmarkerFollowPlayer -- takes: string targetName
M.sendCustomVehicleData    = sendCustomVehicleData    -- UI sync button
--M.sendVehicle            = sendVehicle              -- this shouldnt be public?

print("MPVehicleGE loaded")
return M
