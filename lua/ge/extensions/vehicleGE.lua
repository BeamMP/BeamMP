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



-- ============= VARIABLES =============
ownMap = {}
vehiclesMap = {}
local onVehicleSpawnedAllowed = true
local onVehicleDestroyedAllowed = true
local tempServerVehicleID = ""
-- ============= VARIABLES =============



--============== SOME FUNCTIONS ==============
local function println(stringToPrint)
	print("[BeamNG-MP] [vehicleGE] | "..stringToPrint)
end

local function tableInvert(t)
   local s = {}
   for k,v in pairs(t) do
     s[v] = k
   end
   return s
end

local function getGameVehicleID(serverVehicleID)
	local invertedTable = tableInvert(vehiclesMap)
	--print("getGameVehicleID("..serverVehicleID..") = "..invertedTable[tostring(serverVehicleID)])
	return invertedTable[tostring(serverVehicleID)]
end

local function getServerVehicleID(gameVehicleID)
	return vehiclesMap[tostring(gameVehicleID)]
end

local function insertVehicleMap(gameVehicleID, serverVehicleID)
	vehiclesMap[tostring(gameVehicleID)] = tostring(serverVehicleID)
end

local function isOwn(gameVehicleID)
    return ownMap[tostring(gameVehicleID)] ~= nil
end

local function getOwnMap()
    return ownMap
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
			veh:queueLuaCommand("obj:queueGameEngineLua(\"vehicleGE.sendVehicleData("..veh:getID()..", '\"..jsonEncode(partmgmt.state.config)..\"')\")") -- Get config
		end
	end
end
--============================ SEND ALL VEHICLES ==============================



--============================ SEND ONE VEHICLE ==============================
local function sendVehicle(gameVehicleID)
	local veh = be:getObjectByID(gameVehicleID) -- Get spawned vehicle ID
	if veh then -- In case of bug
		veh:queueLuaCommand("obj:queueGameEngineLua(\"vehicleGE.sendVehicleData("..gameVehicleID..", '\"..jsonEncode(partmgmt.state.config)..\"')\")") -- Get config
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

	vehicleTable[1] = Settings.PlayerID
	vehicleTable[2] = tostring(gameVehicleID)
	vehicleTable[3] = veh:getJBeamFilename()
	vehicleTable[4] = vehicleConfig
	vehicleTable[5] = jsonEncode({c.x, c.y, c.z, c.w})
	vehicleTable[6] = jsonEncode({p0.x, p0.y, p0.z, p0.w})
	vehicleTable[7] = jsonEncode({p1.x, p1.y, p1.z, p1.w})
	vehicleTable[8] = getServerVehicleID(gameVehicleID) or ""

	local stringToSend = jsonEncode(vehicleTable) -- Encode table to send it as json string
	--                    "2020"
    NetworkHandler.send("U-VC", stringToSend) -- Send table that contain all vehicle informations for each vehicle
end
--=========================================== SEND VEHICLE DATA =============================================



local function onDisconnect()
	-- Clear ownMap and vehiclesMap
	ownMap = {}
	vehiclesMap = {}
end



--================================= ON VEHICLE SPAWNED (SERVER) ===================================
local function onServerVehicleSpawned(data)
	data:gsub("[\r\n]", "")
	data = string.gsub(data, '^%s*(.-)%s*$', '%1')
	data = string.gsub(data, "%s+", "")
	print(data)
	local decodedData     = jsonDecode(data)
  print(HelperFunctions.dump(decodedData))
	local playerServerID  = decodedData[1] -- Server ID of the player that sent the vehicle
	local gameVehicleID   = decodedData[2] -- gameVehicleID of the player that sended the vehicle
	local serverVehicleID = decodedData[1] .. decodedData[2] -- Server ID of the vehicle
	local vehicleName     = decodedData[3] -- Vehicle name
	local vehicleConfig   = jsonDecode(decodedData[4]) -- Vehicle config
	local c               = jsonDecode(decodedData[5]) -- Vehicle color
	local cP0             = jsonDecode(decodedData[6]) -- Vehicle colorPalette0
	local cP1             = jsonDecode(decodedData[7]) -- Vehicle colorPalette1
	print("onServerVehicleSpawned")
	if Settings.PlayerID == playerServerID then -- If player ID = received player ID seems it's his own vehicle then sync it
		insertVehicleMap(gameVehicleID, serverVehicleID) -- Insert new vehicle ID in map
		ownMap[tostring(gameVehicleID)] = 1 -- Insert vehicle in own map
		println("ID is same as received ID, syncing vehicle gameVehicleID: "..gameVehicleID.." with ServerID: "..serverVehicleID)
	else
		println("New vehicle : "..vehicleName)
		onVehicleSpawnedAllowed = false
		tempServerVehicleID = serverVehicleID
		spawn.spawnVehicle(vehicleName, serialize(vehicleConfig), vec3(0,0,0), quat(0,0,0,0), ColorF(c[1],c[2],c[3],c[4]), ColorF(cP0[1],cP0[2],cP0[3],cP0[4]), ColorF(cP1[1],cP1[2],cP1[3],cP1[4]))
	end
end
--================================= ON VEHICLE SPAWNED (SERVER) ===================================



--================================= ON VEHICLE SPAWNED (CLIENT) ===================================
local function onVehicleSpawned(gameVehicleID)
	println("Vehicle spawned : "..gameVehicleID)
	local veh = be:getObjectByID(gameVehicleID)
	veh:queueLuaCommand("extensions.addModulePath('lua/vehicle/extensions/BeamMP')") -- Load lua files
	veh:queueLuaCommand("extensions.loadModulesInDirectory('lua/vehicle/extensions/BeamMP')")
	if Network.GetTCPStatus() > 0 then -- If TCP is connecting or connected
		if onVehicleSpawnedAllowed then -- If function is not coming from onServerVehicleSpawned then
			sendVehicle(gameVehicleID) -- Send it to the server without server ID so that we can get an ID set and also to send it to other players
		else
			insertVehicleMap(gameVehicleID, tempServerVehicleID) -- Insert new vehicle ID in map
			onVehicleSpawnedAllowed = true
		end
	end
	if Network.GetTCPStatus() == 2 then
		if isOwn(gameVehicleID) then
			veh:queueLuaCommand("powertrainVE.sendAllPowertrain()")
		end
	end
end
--================================= ON VEHICLE SPAWNED (CLIENT) ===================================



--================================= ON VEHICLE REMOVED (SERVER) ===================================
local function onServerVehicleRemoved(serverVehicleID)
	local gameVehicleID = getGameVehicleID(serverVehicleID) -- Get game ID
	if gameVehicleID then
		local veh = be:getObjectByID(gameVehicleID) -- Get associated vehicle
		if veh and gameVehicleID then
			commands.setFreeCamera()
			onVehicleDestroyedAllowed = false
			veh:delete() -- Remove it
		end
	else
		println("gameVehicleID for serverVehicleID "..serverVehicleID.." not found.")
	end
end
--================================= ON VEHICLE REMOVED (SERVER) ===================================



--================================= ON VEHICLE REMOVED (CLIENT) ===================================
local function onVehicleDestroyed(gameVehicleID)
	println("Vehicle destroyed : "..gameVehicleID)
	if Network.GetTCPStatus() > 0 then -- If TCP is connecting or connected
		if onVehicleDestroyedAllowed then -- If function is not coming from onServerVehicleDestroyed then
			local serverVehicleID = getServerVehicleID(tostring(gameVehicleID)) -- Get the serverVehicleID
			if serverVehicleID then
				           --"2121"
				NetworkHandler.send("U-VR"..serverVehicleID) -- Send it
			end
		else
			onVehicleDestroyedAllowed = true
		end
	end
end
--================================= ON VEHICLE REMOVED (CLIENT) ===================================



--======================= ON VEHICLE SWITCHED (CLIENT) =======================
local function onVehicleSwitched(oldID, newID)
	println("Vehicle switched : "..oldID.." - "..newID)
	if Network.GetTCPStatus() > 0 then -- If TCP is connecting or connected
		local newID = getServerVehicleID(newID) -- Get new serverVehicleID of the new vehicle the player is driving
		if newID then -- If it's not null
			NetworkHandler.send("C-VS"..newID) -- Send it to server
		end
	end
end
--======================= ON VEHICLE SWITCHED (CLIENT) =======================



M.onVehicleSwitched      = onVehicleSwitched
M.onDisconnect           = onDisconnect
M.isOwn                  = isOwn
M.getOwnMap              = getOwnMap
M.getGameVehicleID       = getGameVehicleID
M.getServerVehicleID     = getServerVehicleID
M.onVehicleDestroyed     = onVehicleDestroyed
M.onVehicleSpawned       = onVehicleSpawned
M.deleteAllVehicles      = deleteAllVehicles
M.sendAllVehicles        = sendAllVehicles
M.sendVehicle            = sendVehicle
M.sendVehicleData        = sendVehicleData
M.onServerVehicleSpawned = onServerVehicleSpawned
M.onServerVehicleRemoved = onServerVehicleRemoved



return M
