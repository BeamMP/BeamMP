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
		log('W', "getServerVehicleID", "received string ID, please use numbers")
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
		log('W', "isOwn", "received string ID, please use numbers")
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


--called by onVehicleSpawned
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
		vehicleTable.vid = gameVehicleID -- Game Vehicle ID
		vehicleTable.jbm = veh:getJBeamFilename() -- JBeam
		vehicleTable.vcf = vehicleData.config -- Vehicle Config
		vehicleTable.col = {c.x, c.y, c.z, c.w} -- Color Palette
		vehicleTable.cpz = {p0.x, p0.y, p0.z, p0.w} -- Color Palette 0
		vehicleTable.cpo = {p1.x, p1.y, p1.z, p1.w} -- Color Palette 1
		vehicleTable.pos = {pos.x, pos.y, pos.z} -- Position
		vehicleTable.rot = {rot.x, rot.y, rot.z, rot.w} -- Rotation

		local stringToSend = jsonEncode(vehicleTable) -- Encode table to send it as json string
		MPGameNetwork.send('Os:0:'..stringToSend) -- Send table that contain all vehicle informations for each vehicle
		log('I', "sendVehicle", "Vehicle "..gameVehicleID.." was sent")
	end
end
--============================ SEND ONE VEHICLE ==============================


--called by autosync and the ui (sync button)
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
	log('I', "sendCustomVehicleData", "Vehicle custom data "..gameVehicleID.." was sent")
	vehiclesToSync[gameVehicleID] = nil
end
--=========================================== SEND MODIFIED VEHICLE DATA =============================================



local function applyVehEdit(serverID, data)
	local gameVehicleID = getGameVehicleID(serverID) -- Get the gameVehicleID
	if not gameVehicleID then log('E','applyVehEdit',"gameVehicleID for "..serverID.." not found") return end

	local veh = be:getObjectByID(gameVehicleID) -- Get the vehicle
	if not veh then log('E','applyVehEdit',"Vehicle "..gameVehicleID.." not found") return end

	local decodedData     = jsonDecode(data) -- Decode the data
	local vehicleName     = decodedData.jbm -- Vehicle name
	local vehicleConfig   = decodedData.vcf -- Vehicle config
	if vehicleName == veh:getJBeamFilename() then
		log('I','applyVehEdit',"Updating vehicle "..gameVehicleID.." config")
		local playerVehicle = extensions.core_vehicle_manager.getVehicleData(gameVehicleID)

		local partsDiff = MPHelpers.tableDiff(playerVehicle.config.parts, vehicleConfig.parts)
		local tuningDiff = MPHelpers.tableDiff(playerVehicle.config.vars, vehicleConfig.vars)

		local configChanged = tableSize(partsDiff) > 0 or tableSize(tuningDiff) > 0
		local colorChanged = not MPHelpers.colorMatch(playerVehicle.config.colors, vehicleConfig.colors)

		if configChanged or colorChanged then
			tableMerge(playerVehicle.config, vehicleConfig)

			if configChanged then
				--veh:setDynDataFieldbyName("autoEnterVehicle", 0, (be:getPlayerVehicle(0) and be:getPlayerVehicle(0):getID() == gameVehicleID) or false) -- this only works one way :(
				veh:respawn(serialize(playerVehicle.config))
			else
				log('I','applyVehEdit', "only color changed")
				extensions.core_vehicle_manager.liveUpdateVehicleColors(gameVehicleID)
			end
		else
			log('I','applyVehEdit', "received edit matches local copy, ignoring message")
		end
	else
		log('W','applyVehEdit', "The received data for "..vehicleName.." does not correspond with the vehicle "..veh:getJBeamFilename())


		local c   = decodedData.col and ColorF(decodedData.col[1],decodedData.col[2],decodedData.col[3],decodedData.col[4]) or nil
		local p0  = decodedData.cpz and ColorF(decodedData.cpz[1],decodedData.cpz[2],decodedData.cpz[3],decodedData.cpz[4]) or nil
		local p1  = decodedData.cpo and ColorF(decodedData.cpo[1],decodedData.cpo[2],decodedData.cpo[3],decodedData.cpo[4]) or nil
		local pos = veh:getPosition()
		local rot = quat(veh:getRotation())

		log('I', 'applyVehEdit', "Updating vehicle from server "..vehicleName.." with id "..serverID)
		spawn.setVehicleObject(veh, vehicleName, serialize(vehicleConfig), pos, rot, c, p0, p1, true)

		--playerVehicle:setField('name', '', vehicleName or "")
	end
end

local function updateVehicle(serverID, data)
	if settings.getValue("enableSpawnQueue") then
		vehicleEditQueue[serverID] = data
		log('I', 'updateVehicle', "edit received and queued")
		local id = string.match(serverID,"^(%d*)-")
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
		log("E", "applyVehSpawn", "Failed to spawn vehicle from "..event.playerNickname.."!")
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

	log('I', 'applyVehSpawn', "Spawning a vehicle from server with serverVehicleID "..event.serverVehicleID)
	log('I', 'applyVehSpawn', "It is for "..event.playerNickname)

	onVehicleSpawnedAllowed = false -- this flag is used to indicate whether the next spawn is remote or not

	local allowed = false
	local vehiclesList = extensions.core_vehicles.getModelNames()
	for index, value in ipairs(vehiclesList) do
		if vehicleName == value then allowed = true end
	end
	if not allowed then
		log('W', 'applyVehSpawn', "The received vehicle "..vehicleName.." is not valid, cancelling the spawn (likely a missing mod)")
		UI.showNotification("info", "Player "..event.playerNickname.." spawned an illegal vehicle ("..vehicleName.."), it was skipped")
		return
	end


	local spawnedVehID = getGameVehicleID(event.serverVehicleID)

	local spawnedVeh = spawnedVehID and be:getObjectByID(spawnedVehID) or nil

	if spawnedVeh then -- if a vehicle with this ID was found update the obj
		log('W', 'applyVehSpawn', "(spawn)Updating vehicle from server "..vehicleName.." with id "..spawnedVehID)
		spawn.setVehicleObject(spawnedVeh, vehicleName, serialize(vehicleConfig), pos, rot, ColorF(c[1],c[2],c[3],c[4]), ColorF(cP0[1],cP0[2],cP0[3],cP0[4]), ColorF(cP1[1],cP1[2],cP1[3],cP1[4]), true)
	else
		spawnedVeh = spawn.spawnVehicle(vehicleName, serialize(vehicleConfig), pos, rot, ColorF(c[1],c[2],c[3],c[4]), ColorF(cP0[1],cP0[2],cP0[3],cP0[4]), ColorF(cP1[1],cP1[2],cP1[3],cP1[4]), "multiplayerVeh", true, false)
		spawnedVehID = spawnedVeh:getID()
		log('W', 'applyVehSpawn', "New vehicle spawned from server "..vehicleName.." with id "..spawnedVehID)
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
		log("E", "onServerVehicleSpawned", "Failed to spawn vehicle from "..playerNickname.."! (Invalid JSON data)")
		return
	end

	local playerServerID   = decodedData.pid -- Server ID of the player that sent the vehicle
	local gameVehicleID    = tonumber(decodedData.vid) -- gameVehicleID of the player that sent the vehicle

	nickIDMap[playerServerID] = playerNickname

	log("I", "onServerVehicleSpawned", "Received a vehicle spawn for player " .. playerNickname .. " with ID " .. serverVehicleID)

	if MPConfig.getPlayerServerID() == playerServerID then -- If player ID = received player ID seems it's his own vehicle then sync it
		insertVehicleMap(gameVehicleID, serverVehicleID) -- Insert new vehicle ID in map
		ownMap[gameVehicleID] = true -- Insert vehicle in own map
		log("I", "onServerVehicleSpawned", "ID is same as received ID, syncing vehicle gameVehicleID: "..gameVehicleID.." with ServerID: "..serverVehicleID)
	else

		local eventdata = {
			playerRole = playerRole,
			playerNickname = playerNickname,
			serverVehicleID = serverVehicleID,
			data = data
		}

		if settings.getValue("enableSpawnQueue") and not (settings.getValue("queueSkipUnicycle") and decodedData.jbm == "unicycle") then
			vehicleSpawnQueue[serverVehicleID] = eventdata
			log("I", "onServerVehicleSpawned", "Adding spawn for " .. playerNickname .. " to queue")

			UI.updateQueue(vehicleSpawnQueue, vehicleEditQueue, true)

			UI.showNotification('Spawn received and queued for '..playerNickname)
		else
			log("I", "onServerVehicleSpawned", "Queue disabled, spawning vehicle now")

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
	local newJbeamName = veh:getJBeamFilename()


	--print("SPAWN")
	--dump(veh.mpVehicleType)
	--dump(isOwn(gameVehicleID) ~= 1)
	--dump(getServerVehicleID(gameVehicleID) == nil)
	--dump(jbeamMap[gameVehicleID])


	if not jbeamMap[gameVehicleID] then -- If it's not an edit
		log("I", "onVehicleSpawned", "New Vehicle Spawned "..gameVehicleID)

		veh:queueLuaCommand("extensions.addModulePath('lua/vehicle/extensions/BeamMP')") -- Load lua files
		veh:queueLuaCommand("extensions.loadModulesInDirectory('lua/vehicle/extensions/BeamMP')")


		if onVehicleSpawnedAllowed then -- if false then we spawned it (from server)
			sendVehicle(gameVehicleID) -- Send it to the server
		end

		onVehicleSpawnedAllowed = true


	else
		if jbeamMap[gameVehicleID] ~= newJbeamName then
			log("I", "onVehicleSpawned", string.format("Vehicle %i updated from %s to %s", gameVehicleID, jbeamMap[gameVehicleID], newJbeamName))

			veh:queueLuaCommand("extensions.addModulePath('lua/vehicle/extensions/BeamMP')") -- Load lua files
			veh:queueLuaCommand("extensions.loadModulesInDirectory('lua/vehicle/extensions/BeamMP')")

			if onVehicleSpawnedAllowed then -- if false then the server spawned it
				sendCustomVehicleData(gameVehicleID) -- Send it to the server (as a sync)
			end

			onVehicleSpawnedAllowed = true

		else
			log("I", "onVehicleSpawned", "Vehicle " .. gameVehicleID .. " edited")
			syncTimer = 0
			vehiclesToSync[gameVehicleID] = 1.
		end
	end

	jbeamMap[gameVehicleID] = newJbeamName
end
--================================= ON VEHICLE SPAWNED (CLIENT) ===================================



--================================= ON VEHICLE REMOVED (SERVER) ===================================
local function onServerVehicleRemoved(serverVehicleID)
	vehicleEditQueue[serverVehicleID] = nil
	UI.updateQueue(vehicleSpawnQueue or {}, vehicleEditQueue or {})

	if vehicleSpawnQueue[serverVehicleID] then
		log('W', "onServerVehicleRemoved", "Vehicle "..serverVehicleID.." is still in the queue, removing from there")
		vehicleSpawnQueue[serverVehicleID] = nil
		UI.updateQueue(vehicleSpawnQueue or {}, vehicleEditQueue or {})
		return
	end

	local gameVehicleID = getGameVehicleID(serverVehicleID) -- Get game ID
	if gameVehicleID then
		if nicknameMap[gameVehicleID] then nicknameMap[gameVehicleID] = nil end
		log('I', "onServerVehicleRemoved", string.format("Vehicle %i (%s) removed by server ", gameVehicleID, serverVehicleID))
		local veh = be:getObjectByID(gameVehicleID) -- Get associated vehicle
		if veh then
			onVehicleDestroyedAllowed = false
			local currveh = be:getPlayerVehicle(0)
			local isCurrent = (currveh and currveh:getID() == gameVehicleID) or false
			veh:delete() -- Remove it
			if isCurrent then be:enterNextVehicle(0,1) end-- Fix camera
			vehiclesMap[gameVehicleID] = nil
			invertedVehiclesMap[serverVehicleID] = nil
		end
	else
		log('W', "onServerVehicleRemoved", "Failed removing vehicle "..serverVehicleID..", ID is unknown")
	end
end
--================================= ON VEHICLE REMOVED (SERVER) ===================================



--================================= ON VEHICLE REMOVED (CLIENT) ===================================
local function onVehicleDestroyed(gameVehicleID)
	if MPGameNetwork.connectionStatus() > 0 then -- If TCP connected
		nicknameMap[gameVehicleID] = nil
		if onVehicleDestroyedAllowed then -- If function is not coming from onServerVehicleRemoved then
			local serverVehicleID = getServerVehicleID(gameVehicleID) -- Get the serverVehicleID
			log('I', "onVehicleDestroyed", string.format("Vehicle %i (%s) removed by local player", gameVehicleID, serverVehicleID or "?"))
			if serverVehicleID then
				MPGameNetwork.send('Od:'..serverVehicleID)
				ownMap[gameVehicleID] = nil
			end
		else
			log('I', "onVehicleDestroyed", string.format("Vehicle %i (%s) removed by server", gameVehicleID, serverVehicleID or "?"))
			onVehicleDestroyedAllowed = true
		end
	end
end
--================================= ON VEHICLE REMOVED (CLIENT) ===================================



--======================= ON VEHICLE SWITCHED (CLIENT) =======================
local function onVehicleSwitched(oldGameVehicleID, newGameVehicleID)
	if MPCoreNetwork.isMPSession() then -- If TCP connected
		log('I', "onVehicleSwitched", "Vehicle switched from "..oldGameVehicleID or "unknown".." to "..newGameVehicleID or "unknown")

		if newGameVehicleID and newGameVehicleID > -1 then
			local skipOthers = settings.getValue("skipOtherPlayersVehicles") or false
			local oldVehicle = be:getObjectByID(oldGameVehicleID or -1)
			local newVehicle = be:getObjectByID(newGameVehicleID or -1)

			-- enter a remote car as a passenger
			if not isOwn(newGameVehicleID) and oldVehicle and oldVehicle:getJBeamFilename() == "unicycle" then
				--core_camera.setByName(0,"onboard.rider") -- citybus
				core_camera.setByName(0,"passenger") -- auto generated
				core_camera.setByName(0,"onboard.passenger") -- custom
			elseif not isOwn(newGameVehicleID) and ((skipOthers and tableSize(ownMap) > 0) or newVehicle:getJBeamFilename() == "unicycle") then
				-- switch away from this vehicle if it shouldn't be accessible

				local vehicles = getAllVehicles()
				--local oldIndex = nil -- the old vehicle's index
				local curIndex = nil -- the current (new) vehicle's index
				for index,vehicle in ipairs(vehicles) do
					local id = vehicle and vehicle:getID()
					--if id == oldGameVehicleID then
					--	oldIndex = index
					--end
					if id == newGameVehicleID then
						curIndex = index
					end
					if --[[(oldGameVehicleID == -1 or oldIndex) and]] curIndex then break end
				end
				curIndex = curIndex or #vehicles
				--print("current vehicle index is " .. curIndex)

				local findFunc = function(from, to)
					for i = from, to do
						local id = vehicles[i] and vehicles[i]:getID()
						local jbeamName = vehicles[i]:getJBeamFilename()
						if isOwn(id) or not skipOthers and jbeamName ~= "unicycle" then
							log('I', "onVehicleSwitched", "Found suitable vehicle " .. jbeamName)
							return i
						end
					end
					return nil
				end

				--print("direction:")
				--print(oldIndex or -1 < curIndex)

				local nextIndex = findFunc(curIndex+1, #vehicles) or findFunc(1, curIndex) -- could flip these if we knew the direction

				if vehicles[nextIndex] then -- found a good vehicle, swtich to it
					be:enterVehicle(0, vehicles[nextIndex])
				else -- no suitable vehicle found, go to freecam
					be:exitVehicle(0)
					log('E', "onVehicleSwitched", "Could not find a suitable vehicle to switch to, exiting current veh")
				end
			else
				local newServerVehicleID = getServerVehicleID(newGameVehicleID) -- Get new serverVehicleID of the new vehicle the player switched to
				if newServerVehicleID then -- If it's not null
					MPGameNetwork.send('Om:'..newServerVehicleID)--Network.buildPacket(1, 2122, newID, ""))
				end
			end
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
				    log('E', "onServerVehicleResetted", "Could not parse posrot JSON")
				end
			end
		else
			log('E', "onServerVehicleResetted", "gameVehicleID for "..serverVehicleID.." not found")
		end
	end
	lastResetTime[serverVehicleID] = localCounter
end
--======================= ON VEHICLE RESETTED (SERVER) =======================



local HandleNetwork = {
	['s'] = function(rawData) -- spawn
		local playerRole, playerNickname, serverVehicleID, data = string.match(rawData, "^(%w+)%:([%g%s]+)%:(%d+%-%d+)%:({.+})") -- 'ROLE:name:0-0:{jsonstring}'

		if playerRole ~= nil then
			onServerVehicleSpawned(playerRole, playerNickname, serverVehicleID, data)
		else
			log('E', "HandleNetwork", "Spawn pattern match failed")
			print(rawData)
		end
	end,
	['r'] = function(rawData) -- reset
		local serverVehicleID, data = string.match(rawData,"^(%d+%-%d+)%:({.+})") -- '0-0:{jsonstring}'

		if serverVehicleID ~= nil then
			onServerVehicleResetted(serverVehicleID, data)
		else
			log('E', "HandleNetwork", "Reset pattern match failed")
		end
	end,
	['c'] = function(rawData) -- config sync
		local serverVehicleID, data = string.match(rawData,"^(%d+%-%d+)%:({.+})") -- '0-0:{jsonstring}'

		if serverVehicleID ~= nil then
			updateVehicle(serverVehicleID, data)
		else
			log('E', "HandleNetwork", "Config pattern match failed")
		end
	end,
	['d'] = function(rawData) -- remove
		onServerVehicleRemoved(rawData)
	end,
	['t'] = function(rawData) -- coupler
		local serverVehicleID, data = string.match(rawData,"^(%d+%-%d+)%:(%w+)") -- '0-0:true'

		if serverVehicleID ~= nil then
			onServerVehicleCoupled(serverVehicleID, data)
		else
			log('E', "HandleNetwork", "Coupler pattern match failed")
		end
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
		log('I', "saveDefaultRequest", "Request to save vehicle accepted")
	else
		guihooks.trigger('Message', {ttl = 5, msg = "Cant't set another player's vehicle as default", icon = 'error'})
		log('W', "saveDefaultRequest", "Request to save vehicle denied")
	end
end

local function spawnDefaultRequest()
	if not MPCoreNetwork.isMPSession() then core_vehicles.spawnDefault(); extensions.hook("trackNewVeh"); return end


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
		log('I', "saveConfigRequest", "Saved config")
	else
		guihooks.trigger("saveLocalScreenshot_stage3", {})
		guihooks.trigger('Message', {ttl = 10, msg = "Saving another player's vehicle is disabled on this server", icon = 'error'})
		log('W', "saveConfigRequest", "Saving configs is not allowed on this server")
		print("didnt save config")
	end
end


local function syncVehicles()
	for k,v in pairs(vehiclesToSync) do
		local veh = be:getObjectByID(k) --  Get vehicle
		if veh then -- For loop always return one empty vehicle ?
			local gameVehicleID = veh:getID()
			log('I', "syncVehicles", "Autosyncing vehicle "..gameVehicleID)
			sendCustomVehicleData(gameVehicleID)
		end
	end
	vehiclesToSync = {}
end



local lastGmQuery = -1 --get player pos on first run
local groundmarkerRoads = {}
local gmTargetPlayer = nil

local function queryRoadNodeToPosition(targetPosition, owner)
	if not owner then owner = "target" end
	targetPosition = vec3(targetPosition)
	local first, second, distance = map.findClosestRoad(targetPosition)
	if not first and not second then return false end

	groundmarkerRoads[owner] = {position=targetPosition}
	if first ~= 'nil' and second ~= 'nil' then
		groundmarkerRoads[owner].first = first
		groundmarkerRoads[owner].next = second

		local mapData = map.getMap()
		local node1 = mapData.nodes[first]
		local node2 = mapData.nodes[second]
		if node1 and node2 then
			-- find which node is closest to the owner
			local sqrDist1 = (targetPosition - node1.pos):squaredLength()
			local sqrDist2 = (targetPosition - node2.pos):squaredLength()

			if sqrDist1 < sqrDist2 then groundmarkerRoads[owner].best = first
			else groundmarkerRoads[owner].best = second end
			return true
		end
	end
	return false
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
		log('W', "teleportVehToPlayer", "no active vehicle found, teleporting camera instead")
		focusCameraOnPlayer(targetName)
	end
end

local function focusCameraOnPlayer(targetName)
	local activeVehicle = be:getPlayerVehicle(0)
	local activeVehicleID = activeVehicle and activeVehicle:getID() or nil
	log('I', "focusCameraOnPlayer", "Teleporting camera to: "..targetName)
	local nickmap = getNicknameMap()
	for gameVehicleID, ownerNick in pairs(nickmap) do
		if ownerNick == targetName then
			log('I', "focusCameraOnPlayer", "Found vehicle: "..gameVehicleID)
			local targetVeh = be:getObjectByID(gameVehicleID)

			if gameVehicleID ~= activeVehicleID and targetVeh then
				log('I', "focusCameraOnPlayer", "Entering vehicle "..gameVehicleID)
				be:enterVehicle(0,targetVeh)
				return
			end
		end
	end
end

local function applyQueuedEvents()
	UI.updateQueue(vehicleSpawnQueue or {}, vehicleEditQueue or {})

	--local currentVeh = be:getPlayerVehicle(0) -- Camera fix
	--dump(vehicleSpawnQueue)
	for vehicleID, spawn in pairs(vehicleSpawnQueue) do
		log('I', "applyQueuedEvents", "Applying queued spawn")
		applyVehSpawn(spawn)
		vehicleSpawnQueue[vehicleID] = nil
		UI.updateQueue(vehicleSpawnQueue or {}, vehicleEditQueue or {})
	end

	--if not vehicleEditQueue then return end
	--dump(vehicleEditQueue)
	for vehicleID, edit in pairs(vehicleEditQueue) do
		log('I', "applyQueuedEvents", "Applying queued edit")
		applyVehEdit(vehicleID, edit)
		vehicleEditQueue[vehicleID] = nil
		UI.updateQueue(vehicleSpawnQueue or {}, vehicleEditQueue or {})
	end

	--if currentVeh then be:enterVehicle(0, currentVeh) print("entered "..currentVeh:getJBeamFilename()) end -- Camera fix
end


local function onUpdate(dt)
	if MPGameNetwork.connectionStatus() == 1 then -- If TCP connected
		localCounter = localCounter + dt
	end
end

local function onPreRender(dt)
	if MPGameNetwork.connectionStatus() > 0 then -- If TCP connected

		local activeVeh = be:getPlayerVehicle(0)
		local activeVehPos = activeVeh and vec3(activeVeh:getPosition()) or nil
		local activeVehID = activeVeh and activeVeh:getID() or nil

		if activeVehPos then
			lastGmQuery = lastGmQuery - dt
			if lastGmQuery <= 0 then
				lastGmQuery = 0.2
				queryRoadNodeToPosition(activeVehPos, 'player')
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


		local cameraPos = vec3(getCameraPosition())
		if activeVeh then
			local vel = vec3()
			vel:set(activeVeh:getVelocity())
			if (not isOwn(activeVehID) and settings.getValue("queueAutoSkipRemote")) or (settings.getValue("enableQueueAuto") and math.abs(vel:length() or 0) < 0.5) then applyQueuedEvents() end
			if not commands.isFreeCamera() then cameraPos = activeVehPos end
		else
			applyQueuedEvents()
			if not commands.isFreeCamera() then
				commands.setFreeCamera()		 -- Fix camera
			end
		end


		if not activeVeh and be:getObjectCount() == 0 then return end -- If no vehicle do nothing
		-- Vehicles syncing timer
		syncTimer = syncTimer + dt
		if syncTimer > 10 then
			if settings.getValue("autoSyncVehicles") then syncVehicles() end
			syncTimer = 0
		end

		for i = 0, be:getObjectCount()-1 do -- For each vehicle
			local veh = be:getObject(i) --	Get vehicle
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

					if distanceMap[gameVehicleID] > 10 and settings.getValue("nameTagShowDistance") then
						local unit
						local mapEntry = distanceMap[gameVehicleID]
						if settings.getValue("uiUnitLength") == "imperial" then
							mapEntry = mapEntry * 3.28084
							if mapEntry > 5280 then
								mapEntry = math.floor((mapEntry / 5280 * 100) + 0.5) / 100
								unit = "mi"
							else
								mapEntry = math.floor(mapEntry)
								unit = "ft"
							end
						else
							if mapEntry >= 1000 then
								mapEntry = math.floor((mapEntry / 10) + 0.5) / 100
								unit = "km"
							else
								mapEntry = math.floor(mapEntry)
								unit = "m"
							end
						end

						dist = string.format(" %s %s", tostring(mapEntry), unit)
					end

					if settings.getValue("fadeVehicles") then
						if activeVehID == gameVehicleID then veh:setMeshAlpha(1, "", false)
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
	end
end

--DEBUG


-- EVENTS
M.onUpdate                 = onUpdate
M.onPreRender              = onPreRender
M.onDisconnect             = onDisconnect
M.handle                   = handle
M.onVehicleSpawned         = onVehicleSpawned
M.onVehicleDestroyed       = onVehicleDestroyed
M.onVehicleSwitched        = onVehicleSwitched
M.onVehicleResetted        = onVehicleResetted
--M.onServerVehicleSpawned   = onServerVehicleSpawned
--M.onServerVehicleRemoved   = onServerVehicleRemoved
--M.onServerVehicleResetted  = onServerVehicleResetted
--M.onServerVehicleCoupled   = onServerVehicleCoupled


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
M.sendBeamstate            = sendBeamstate            -- takes: string state, number gameVehicleID
M.applyQueuedEvents        = applyQueuedEvents        -- takes: -      returns: -
M.teleportVehToPlayer      = teleportVehToPlayer      -- takes: string targetName
M.teleportCameraToPlayer   = focusCameraOnPlayer      -- takes: string targetName NOTE: DEPRECATED
M.focusCameraOnPlayer      = focusCameraOnPlayer      -- takes: string targetName
M.groundmarkerToPlayer     = groundmarkerToPlayer     -- takes: string targetName
M.groundmarkerFollowPlayer = groundmarkerFollowPlayer -- takes: string targetName
M.queryRoadNodeToPosition  = queryRoadNodeToPosition  -- takes: vec3 target position, optional string targetname
M.sendCustomVehicleData    = sendCustomVehicleData    -- UI sync button
--M.sendVehicle            = sendVehicle              -- this shouldnt be public?

print("MPVehicleGE loaded")
return M
