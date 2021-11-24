--====================================================================================
-- All work by Titch2000, jojos38 and 20dka.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading MPVehicleGE...")


-- ============= VARIABLES =============
local lastResetTime = {}
local oneSecCounter = 0
--local ownMap = {}
--local vehiclesMap = {}
--local jbeamMap = {}
--local nicknameMap = {}
--local nickIDMap = {}
--local nicknamePrefixMap = {}
--local nicknameSuffixMap = {}
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
	['STAFF'] = { backcolor = ColorI(68, 109, 184, 127), tag = " [BeamMP Staff]" },
	['MOD'] = { backcolor = ColorI(68, 109, 184, 127), tag = " [Moderator]" },
	['ADM'] = { backcolor = ColorI(218, 0, 78, 127), tag = " [Admin]" },
	['GDEV'] = { backcolor = ColorI(252, 107, 3, 127), tag = " [BeamNG Staff]" },
	['MDEV'] = { backcolor = ColorI(194, 55, 55, 127), tag = " [BeamMP Dev]" }
}

-- ============= VARIABLES =============

local players = {}
local vehicles = {}


--============== SOME FUNCTIONS ==============

-- SERVER VEHICLE ID ----> GAME VEHICLE ID
local function getGameVehicleID(serverVehicleID)
	return invertedVehiclesMap[serverVehicleID]
	--for gameVehicleID,v in pairs(vehicles) do
	--	if v.serverVehicleString == serverVehicleID then return gameVehicleID end
	--end
	--return -1
end

-- GAME VEHICLE ID ----> SERVER VEHICLE ID
local function getServerVehicleID(gameVehicleID)
	if type(gameVehicleID) == "string" then
		log('W', "getServerVehicleID", "received string ID, please use numbers")
		gameVehicleID = tonumber(gameVehicleID)
	end

	if not vehicles[gameVehicleID].serverVehicleString then
		log('E', 'getServerVehicleID', 'cant get server id')
		print(debug.traceback())
	end

	return vehicles[gameVehicleID].serverVehicleString
end

local function localVehiclesExist()
	for k, v in pairs(vehicles) do
		if v.isLocal then return true end
	end
	return false
end

-- CHECK IF A USER OWNS A VEHICLE
local function isOwn(gameVehicleID)
	if type(gameVehicleID) == "string" then
		log('W', "isOwn", "received string ID, please use numbers")
		gameVehicleID = tonumber(gameVehicleID)
	end
	return vehicles[gameVehicleID] and vehicles[gameVehicleID].isLocal == true or false
end

-- SET IF A USER OWNS A VEHICLE
local function setOwn(vehID, own)
	vehicles[vehID].isLocal = own
end

-- RETURN THE MAP OF OWNED VEHICLES
local function getOwnMap()
	local own = {}

	for gameVehicleID, vehicle in pairs(vehicles) do
		if vehicle.isLocal then
			own[gameVehicleID] = vehicle
		end
	end
	return own
end

-- RETURN THE MAP OF ALL VEHICLES IDS
local function getVehicleMap()
	local t = {}

	for gameVehicleID,v in pairs(vehicles) do
		t[vehicles.serverVehicleString] = gameVehicleID
	end
	return t
end

-- RETURN THE MAP OF ALL VEHICLES DISTANCES FROM THE CURRENT ONE
local function getDistanceMap()
	return distanceMap
end

-- RETURN THE MAP OF ALL NICKNAMES
local function getNicknameMap() -- Returns a [localID] = "username" table of all vehicles, including own ones
	local nicknameSimple = {}

	for gameVehicleID, v in pairs(vehicles) do
		nicknameSimple[gameVehicleID] = v.ownerName
	end

	return nicknameSimple
end

local function setPlayerNickPrefix(targetName, tagSource, text)
	if targetName == nil then return end
	for k,player in pairs(players) do
		if player.name == targetName then
			player:setNickPrefix(tagSource, text)
			return
		end
	end
end
local function setPlayerNickSuffix(targetName, tagSource, text)
	if targetName == nil then return end
	for k,player in pairs(players) do
		if player.name == targetName then
			player:setNickSuffix(tagSource, text)
			return
		end
	end
end

-- SET WHETHER NICKNAMES ARE ALLOWED TO BE VISIBLE (can be used by mods in minigames)
local function hideNicknames(hide)
	nicknamesAllowed = not hide
end
--============== SOME FUNCTIONS ==============






local Player = {}
Player.__index = Player
function Player:new(data)
	local o = {}
	data = data or {}
	setmetatable(o, self)

	o.name = data.name
	o.playerID = tonumber(data.playerID)
	o.roleName = data.role or 'USER'
	o.role = roleToInfo[o.roleName] or {}
	o.role.name = o.roleName
	o.isLocal = data.isLocal or false

	o.nickPrefixes = {}
	o.nickSuffixes = {}

	o.vehicles = {}
	o.ping = -1

	o.activeVehicleID = nil

	log('W', 'Player:new', "player "..o.name.." created!")

	return o
end

function Player:addVehicle(v)
	self.vehicles[v.serverVehicleID] = v
	print('added vehicle ID '..tostring(v.serverVehicleID)..' to player '..self.name)
end

function Player:setNickPrefix(tagSource, text)
	--setPlayerNickPrefix(self.name, tagSource, text)
	if text == nil then text = tagSource; tagSource = "default" end
	self.nickPrefixes[tagSource] = text
end
function Player:setNickSuffix(tagSource, text)
	--setPlayerNickSuffix(self.name, tagSource, text)
	if text == nil then text = tagSource; tagSource = "default" end
	self.nickSuffixes[tagSource] = text
end

local Vehicle = {}
Vehicle.__index = Vehicle
function Vehicle:new(data)
	local o = {}
	data = data or {}
	setmetatable(o, self)

	o.jbeam = data.jbeam

	o.gameVehicleID = tonumber(data.gameVehicleID) or -1

	if data.serverVehicleString then -- combined string
		o.serverVehicleString = data.serverVehicleString
		o.ownerID, o.serverVehicleID = string.match(data.serverVehicleString, "(%d+)%-(%d+)")
		o.ownerID, o.serverVehicleID = tonumber(o.ownerID), tonumber(o.serverVehicleID)
	else
		if data.ownerID then o.ownerID = tonumber(data.ownerID) end
		if data.serverVehicleID then o.serverVehicleID = tonumber(data.serverVehicleID) end
		if o.ownerID and o.serverVehicleID then o.serverVehicleString = tostring(o.ownerID)..'-'..tostring(o.serverVehicleID) end
	end

	if o.serverVehicleString then
		invertedVehiclesMap[o.serverVehicleString] = o.gameVehicleID
	end

	o.ownerName = data.ownerName
	o.isLocal = data.isLocal or false
	o.isSpawned = data.isSpawned or true

	o.position = nil
	o.rotation = nil

	o.spectators = {}

	log('W', 'Vehicle:new', 'vehicle ' .. (data.ownerName or '') .. ' created!')
	return o
end

function Vehicle:getOwner()
	for k,v in pairs(players) do
		if self.ownerID == v.playerID then
			return players[k], k
		end
	end
end

function getPlayers() return players end
function getVehicles() return vehicles end






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

		local vehObj = Vehicle:new({ isLocal=true, ownerName=MPConfig.getNickname(), gameVehicleID=gameVehicleID, jbeam=vehicleTable.jbm, ownerID=vehicleTable.pid })

		if not players[vehObj.ownerID] then
			players[vehObj.ownerID] = Player:new({name=vehObj.ownerName, playerID=vehObj.ownerID, isLocal=true })
		end

		vehicles[gameVehicleID] = vehObj
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
		local colorChanged = not MPHelpers.colorMatch(playerVehicle.config.paints, vehicleConfig.paints)
		--print("colorchanged: " .. tostring(colorChanged))
		if configChanged or colorChanged then
			tableMerge(playerVehicle.config, vehicleConfig) -- add new parts to the existing config

			if configChanged then
				--veh:setDynDataFieldbyName("autoEnterVehicle", 0, (be:getPlayerVehicle(0) and be:getPlayerVehicle(0):getID() == gameVehicleID) or false) -- this only works one way :(
				veh:respawn(serialize(playerVehicle.config))
			elseif vehicleConfig.paints then
				log('I','applyVehEdit', "only color changed")
				for k, v in pairs(vehicleConfig.paints) do
					extensions.core_vehicle_manager.liveUpdateVehicleColors(gameVehicleID, veh, k, v)
				end
			end
		else
			log('I','applyVehEdit', "received edit matches local copy, ignoring message")
		end
	else
		log('W','applyVehEdit', "The received data for '"..vehicleName.."' does not correspond with the vehicle '"..veh:getJBeamFilename().."'")

		--fresh spawns dont contain paint data?
		if not vehicleConfig.paints then
			vehicleConfig.paints = {}
			if decodedData.col then vehicleConfig.paints[1] = {baseColor=decodedData.col} end
			if decodedData.cpz then vehicleConfig.paints[2] = {baseColor=decodedData.cpz} end
			if decodedData.cpo then vehicleConfig.paints[3] = {baseColor=decodedData.cpo} end
		end

		local options = {
			model = vehicleName,
			config = serialize(vehicleConfig),
			pos = veh:getPosition(), rot = quat(veh:getRotation()), cling = true,
			paint = vehicleConfig.paints[1], paint2 = vehicleConfig.paints[2], paint3 = vehicleConfig.paints[3]
		}

		log('I', 'applyVehEdit', "Updating vehicle from server "..vehicleName.." with id "..serverID)
		spawn.setVehicleObject(veh, options)
	end
end

local function updateVehicle(serverID, data)
	if settings.getValue("enableSpawnQueue") then
		vehicleEditQueue[serverID] = data
		log('I', 'updateVehicle', "edit received and queued")
		local id = tonumber(string.match(serverID,"^(%d*)%-") or -1)
		local playerNickname = players[id] and players[id].name or "unknown"
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
	--ownMap = {}
	--vehiclesMap = {}
	--invertedVehiclesMap = {}
	--nicknameMap = {}
end

local function onServerVehicleCoupled(serverVehicleID, state)
	local gameVehicleID = getGameVehicleID(serverVehicleID) -- Get game ID
	if not isOwn(gameVehicleID) then
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

	--fresh spawns dont contain paint data?
	if not vehicleConfig.paints then
		vehicleConfig.paints = {}
		if c   then vehicleConfig.paints[1] = {baseColor=c} end
		if cP0 then vehicleConfig.paints[2] = {baseColor=cP0} end
		if cP1 then vehicleConfig.paints[3] = {baseColor=cP1} end
	end

	local spawnedVehID = getGameVehicleID(event.serverVehicleID)
	local spawnedVeh = spawnedVehID and be:getObjectByID(spawnedVehID) or nil

	if spawnedVeh then -- if a vehicle with this ID was found update the obj
		log('W', 'applyVehSpawn', "(spawn)Updating vehicle from server "..vehicleName.." with id "..spawnedVehID)
		spawn.setVehicleObject(spawnedVeh, {model=vehicleName, config=serialize(vehicleConfig), pos=pos, rot=rot, cling=true, paint=vehicleConfig.paints[1], paint2=vehicleConfig.paints[2], paint3=vehicleConfig.paints[3]})
	else
		log('W', 'applyVehSpawn', "Spawning new vehicle "..vehicleName.." from server")
		spawnedVeh = spawn.spawnVehicle(vehicleName, serialize(vehicleConfig), pos, rot, { autoEnterVehicle=false, vehicleName="multiplayerVehicle", cling=true, paint=vehicleConfig.paints[1], paint2=vehicleConfig.paints[2], paint3=vehicleConfig.paints[3]})
		spawnedVehID = spawnedVeh:getID()
		log('W', 'applyVehSpawn', "Spawned new vehicle "..vehicleName.." from server with id "..spawnedVehID)
		--insertVehicleMap(spawnedVehID, event.serverVehicleID) -- Insert new vehicle ID in map
		--nicknameMap[spawnedVehID] = {
		--	nickname = event.playerNickname,
		--	role = event.playerRole
		--}

		local vehObject =
			Vehicle:new({gameVehicleID=spawnedVehID, serverVehicleString=event.serverVehicleID, ownerName=event.playerNickname, jbeam=vehicleName})

		if not players[vehObject.ownerID] then
			players[vehObject.ownerID] =
				Player:new({name=event.playerNickname, playerID=vehObject.ownerID, role=event.playerRole})
		end

		vehicles[spawnedVehID] = vehObject
		players[vehObject.ownerID]:addVehicle(vehObject)
	end

	--jbeamMap[spawnedVehID] = vehicleName

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

	local playerServerID   = tonumber(decodedData.pid) -- Server ID of the player that sent the vehicle
	local gameVehicleID    = tonumber(decodedData.vid) -- gameVehicleID of the player that sent the vehicle

	--nickIDMap[playerServerID] = playerNickname


	players[playerServerID] =
		Player:new({name=playerNickname, playerID=playerServerID, role=playerRole, isSpawned=false})


	log("I", "onServerVehicleSpawned", "Received a vehicle spawn for player " .. playerNickname .. " with ID " .. serverVehicleID)

	if MPConfig.getPlayerServerID() == decodedData.pid then -- If player ID = received player ID seems it's his own vehicle then sync it
		--insertVehicleMap(gameVehicleID, serverVehicleID) -- Insert new vehicle ID in map
		local _, vehID = string.match(serverVehicleID,"^(%d*)%-(%d*)")
		vehicles[gameVehicleID].serverVehicleID = tonumber(vehID)
		vehicles[gameVehicleID].serverVehicleString = serverVehicleID

		players[playerServerID].isLocal = true
		players[playerServerID]:addVehicle(vehicles[gameVehicleID])

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


	if not vehicles[gameVehicleID] or not vehicles[gameVehicleID].jbeam then -- If it's not an edit
		log("I", "onVehicleSpawned", "New Vehicle Spawned "..gameVehicleID)

		veh:queueLuaCommand("extensions.addModulePath('lua/vehicle/extensions/BeamMP')") -- Load lua files
		veh:queueLuaCommand("extensions.loadModulesInDirectory('lua/vehicle/extensions/BeamMP')")


		if onVehicleSpawnedAllowed then -- if false then we spawned it (from server)
			sendVehicle(gameVehicleID) -- Send it to the server
			setOwn(gameVehicleID, true) -- Insert vehicle in own map
		end

		onVehicleSpawnedAllowed = true


	else
		if vehicles[gameVehicleID].jbeam ~= newJbeamName then
			log("I", "onVehicleSpawned", string.format("Vehicle %i updated from %s to %s", gameVehicleID, vehicles[gameVehicleID].jbeam, newJbeamName))

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

	if vehicles[gameVehicleID] then vehicles[gameVehicleID].jbeam = newJbeamName end
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
		--if nicknameMap[gameVehicleID] then nicknameMap[gameVehicleID] = nil end
		log('I', "onServerVehicleRemoved", string.format("Vehicle %i (%s) removed by server ", gameVehicleID, serverVehicleID))
		local veh = be:getObjectByID(gameVehicleID) -- Get associated vehicle
		if veh then
			onVehicleDestroyedAllowed = false
			local currveh = be:getPlayerVehicle(0)
			local isCurrent = (currveh and currveh:getID() == gameVehicleID) or false
			veh:delete() -- Remove it
			if isCurrent then be:enterNextVehicle(0,1) end-- Fix camera
			--vehiclesMap[gameVehicleID] = nil
			--invertedVehiclesMap[serverVehicleID] = nil
		else
			log('W', "onServerVehicleRemoved", "Failed removing vehicle "..serverVehicleID..", Vehicle can't be found")
		end
	else
		log('W', "onServerVehicleRemoved", "Failed removing vehicle "..serverVehicleID..", ID is unknown")
	end
end
--================================= ON VEHICLE REMOVED (SERVER) ===================================



--================================= ON VEHICLE REMOVED (CLIENT) ===================================
local function onVehicleDestroyed(gameVehicleID)
	if MPGameNetwork.connectionStatus() > 0 then -- If TCP connected
		--nicknameMap[gameVehicleID] = nil

		if onVehicleDestroyedAllowed then -- If function is not coming from onServerVehicleRemoved then
			local serverVehicleID = getServerVehicleID(gameVehicleID) -- Get the serverVehicleID
			log('I', "onVehicleDestroyed", string.format("Vehicle %i (%s) removed by local player", gameVehicleID, serverVehicleID or "?"))
			if serverVehicleID then
				MPGameNetwork.send('Od:'..serverVehicleID)
				setOwn(gameVehicleID, false)
			end
		else
			log('I', "onVehicleDestroyed", string.format("Vehicle %i (%s) removed by server", gameVehicleID, serverVehicleID or "?"))
			onVehicleDestroyedAllowed = true
		end

		vehicles[gameVehicleID] = nil
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

			local newVehObj = vehicles[newGameVehicleID] or {}

			-- enter a remote car as a passenger
			if not newVehObj.isLocal and oldVehicle and oldVehicle:getJBeamFilename() == "unicycle" then
				--core_camera.setByName(0,"onboard.rider") -- citybus
				core_camera.setByName(0,"passenger") -- auto generated
				core_camera.setByName(0,"onboard.passenger") -- custom
			elseif not newVehObj.isLocal and ((skipOthers and localVehiclesExist()) or vehicles[newGameVehicleID].jbeam == "unicycle") then
				-- switch away from this vehicle if it shouldn't be accessible

				local allVehicles = getAllVehicles()
				--local oldIndex = nil -- the old vehicle's index
				local curIndex = nil -- the current (new) vehicle's index
				for index,vehicle in ipairs(allVehicles) do
					local id = vehicle and vehicle:getID()
					--if id == oldGameVehicleID then
					--	oldIndex = index
					--end
					if id == newGameVehicleID then
						curIndex = index
						break
					end
					if --[[(oldGameVehicleID == -1 or oldIndex) and]] curIndex then break end
				end
				curIndex = curIndex or #allVehicles
				--print("current vehicle index is " .. curIndex)

				local findFunc = function(from, to)
					for i = from, to do
						local id = allVehicles[i] and allVehicles[i]:getID()
						local jbeamName = allVehicles[i]:getJBeamFilename()
						if isOwn(id) or not skipOthers and jbeamName ~= "unicycle" then
							log('I', "onVehicleSwitched", "Found suitable vehicle " .. jbeamName)
							return i
						end
					end
					return nil
				end

				--print("direction:")
				--print(oldIndex or -1 < curIndex)

				local nextIndex = findFunc(curIndex+1, #allVehicles) or findFunc(1, curIndex) -- could flip these if we knew the direction

				if allVehicles[nextIndex] then -- found a good vehicle, swtich to it
					be:enterVehicle(0, allVehicles[nextIndex])
				else -- no suitable vehicle found, go to freecam
					be:exitVehicle(0)
					log('E', "onVehicleSwitched", "Could not find a suitable vehicle to switch to, exiting current veh")
				end
			else
				local newServerVehicleID = getServerVehicleID(newGameVehicleID) -- Get serverVehicleID of the vehicle the player switched to
				if newServerVehicleID then
					local playerID, serverVehicleID = MPConfig.getPlayerServerID(), newServerVehicleID
					local s = tostring(playerID) .. ':' .. newServerVehicleID

					MPGameNetwork.send('Om:'.. s)
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
	end,
	['m'] = function(rawData) -- camera switched
		local playerID, serverVehicleID = string.match(rawData,"^(%d+)%:(%d+%-%d+)") -- '0:0-0'
		playerID = tonumber(playerID)
		local gameVehicleID = getGameVehicleID(serverVehicleID)
		if players[playerID] and players[playerID].activeVehicleID and vehicles[players[playerID].activeVehicleID] then vehicles[players[playerID].activeVehicleID].spectators[playerID] = nil end -- clear prev spectator field
		players[playerID].activeVehicleID = gameVehicleID
		vehicles[gameVehicleID].spectators[playerID] = true
	end
}

local function handle(rawData)
	local code = string.sub(rawData, 1, 1)
	local rawData = string.sub(rawData, 3)
	if HandleNetwork[code] then
		HandleNetwork[code](rawData)
	else
		log('W', 'handle', "Received unknown packet '"..code.."'! ".. rawData)
	end
end

local function onVehicleReady(gameVehicleID)
	log('M', 'onVehicleReady', 'Vehicle '..tostring(gameVehicleID)..' signaled that it is ready')
	local veh = be:getObjectByID(gameVehicleID)
	if not veh then
		log('R', 'onVehicleReady', 'Vehicle does not exist!')
		return
	end

	if veh.mpVehicleType then
		veh:queueLuaCommand("MPVehicleVE.setVehicleType('".. veh.mpVehicleType .."')")
	end
	MPGameNetwork.onVehicleReady(gameVehicleID)
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
		vehicles[gameVehicleID].jbeam = '-'
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
	--dump(model)
	--dump(config)
	--dump(colors)
	local currentVehicle = be:getPlayerVehicle(0)
	if currentVehicle and isOwn(currentVehicle:getID()) and not config.spawnNew then
		vehicles[gameVehicleID].jbeam = '-'
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
local lastGmFocus = nil

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

			return true, groundmarkerRoads[owner].best
		end
	end
	return false, nil
end

local function groundmarkerToPlayer(targetName)
	if not targetName then
		groundmarkerRoads["targetVeh"] = nil
		lastGmFocus = nil
		core_groundMarkers.setFocus(nil)
	end
	for gameVehicleID, vehicle in pairs(vehicles) do
		if vehicle.ownerName == targetName then
			local targetVeh = be:getObjectByID(gameVehicleID)
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
			lastGmFocus = nil
			core_groundMarkers.setFocus(nil)
		end
	end
end

local function teleportVehToPlayer(targetName)
	local activeVehicle = be:getPlayerVehicle(0)

	if activeVehicle then
		for gameVehicleID, vehicle in pairs(vehicles) do
			if vehicle.ownerName == targetName then
				--print("teleporting to "..tostring(i))
				local targetVeh = be:getObjectByID(gameVehicleID)
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

	for gameVehicleID, vehicle in pairs(vehicles) do
		if vehicle.ownerName == targetName then
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
		vehicleSpawnQueue[vehicleID] = nil
		applyVehSpawn(spawn)
		UI.updateQueue(vehicleSpawnQueue or {}, vehicleEditQueue or {})
	end

	--if not vehicleEditQueue then return end
	--dump(vehicleEditQueue)
	for vehicleID, edit in pairs(vehicleEditQueue) do
		log('I', "applyQueuedEvents", "Applying queued edit")
		vehicleEditQueue[vehicleID] = nil
		applyVehEdit(vehicleID, edit)
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
				for target, data in pairs(groundmarkerRoads) do
					if target ~= 'player' then
						if data.best and data.best ~= lastGmFocus then
							if (activeVehPos - data.position):squaredLength() > 200 then
								core_groundMarkers.setFocus(data.best)
								print("setting focus to") print(data.best)
								lastGmFocus = data.best
							else
								core_groundMarkers.setFocus(nil)
								groundmarkerRoads[target] = nil
							end
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

		for gameVehicleID, v in pairs(vehicles) do
			local owner = v:getOwner()
			if v.isLocal or not owner then break end

			if v.isSpawned then -- update position
				local veh = be:getObjectByID(gameVehicleID)
				v.position = veh:getPosition()
			end

			local pos = v.position
			if not pos then break end -- return if no position has been received yet

			local nametagAlpha = 1
			local nametagFadeoutDistance = settings.getValue("nameTagFadeDistance") or 40

			local distfloat = (cameraPos or vec3()):distance(pos)
			distanceMap[gameVehicleID] = distfloat
			nametagAlpha = clamp(linearScale(distfloat, nametagFadeoutDistance, 0, 0, 1), 0, 1)

			if not settings.getValue("hideNameTags") and nicknamesAllowed then

				local dist = ""
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

				local roleInfo = owner.role
				local backColor = roleInfo.backcolor

				backColor = ColorI(backColor.r, backColor.g, backColor.b, math.floor(nametagAlpha*127))

				local prefix = ""
				for source, tag in pairs(owner.nickPrefixes)
					do prefix = prefix..tag.." " end

				local suffix = ""
				for source, tag in pairs(owner.nickSuffixes)
					do suffix = suffix..tag.." " end

				pos.z = pos.z + 2.0 -- Offset nametag so it appears above the vehicle, not inside

				local spectators = ""

				-- draw spectators
				for spectatorID in pairs(v.spectators) do
					local spectator = players[spectatorID]
					spectators = spectators .. spectator.name .. (next(v.spectators, spectatorID) and ', ' or '')
				end
				if spectators ~= "" then
					debugDrawer:drawTextAdvanced(
						pos, -- Location
						String(" ".. spectators .." "), -- Text
						ColorF(1, 1, 1, nametagAlpha), true, false, -- Foreground Color / Draw background / Wtf
						backColor -- Background Color
					)
					pos.z = pos.z + 0.01
				end

				-- draw main nametag
				debugDrawer:drawTextAdvanced(
					pos, -- Location
					String(" "..prefix..tostring(owner.name)..suffix..roleInfo.tag..dist.." "), -- Text
					ColorF(1, 1, 1, nametagAlpha), true, false, -- Foreground Color / Draw background / Wtf
					backColor -- Background Color
				)
			end
		end
	end
end



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
M.setOwn                   = setOwn                   -- takes: number vehID, bool own
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
M.sendCustomVehicleData    = sendCustomVehicleData    -- UI 'Sync' button
M.onVehicleReady           = onVehicleReady           -- Called when our VE files load and the vehicle is ready

print("MPVehicleGE loaded")
return M
