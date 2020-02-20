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
local ownMap = {}
local vehiclesMap = {}
local nicknameMap = {}
local invertedVehiclesMap = {}
local onVehicleSpawnedAllowed = true
local onVehicleDestroyedAllowed = true
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
	local serverVehicleID = getServerVehicleID(gameVehicleID)
	
	vehicleTable[1] = Network.getPlayerServerID()
	vehicleTable[2] = tostring(gameVehicleID)
	vehicleTable[3] = veh:getJBeamFilename()
	vehicleTable[4] = vehicleConfig
	vehicleTable[5] = jsonEncode({c.x, c.y, c.z, c.w})
	vehicleTable[6] = jsonEncode({p0.x, p0.y, p0.z, p0.w})
	vehicleTable[7] = jsonEncode({p1.x, p1.y, p1.z, p1.w})
	vehicleTable[8] = getServerVehicleID(gameVehicleID) or ""
	
	local stringToSend = jsonEncode(vehicleTable) -- Encode table to send it as json string
	Network.send(Network.buildPacket(1, 2020, 0, stringToSend))	-- Send table that contain all vehicle informations for each vehicle
end
--=========================================== SEND VEHICLE DATA =============================================	



local function onDisconnect()
	-- Clear ownMap and vehiclesMap
	ownMap = {}
	vehiclesMap = {}
	invertedVehiclesMap = {}
end



--================================= ON VEHICLE SPAWNED (SERVER) ===================================	
local function onServerVehicleSpawned(data)
	local currentVeh = be:getPlayerVehicle(0) -- Camera fix
	local decodedData     = jsonDecode(data)
	local playerServerID  = decodedData[1] -- Server ID of the player that sended the vehicle
	local gameVehicleID   = decodedData[2] -- gameVehicleID of the player that sended the vehicle
	local serverVehicleID = decodedData[3] -- Server ID of the vehicle
	local vehicleName     = decodedData[4] -- Vehicle name
	local vehicleConfig   = jsonDecode(decodedData[5]) -- Vehicle config
	local c               = jsonDecode(decodedData[6]) -- Vehicle color
	local cP0             = jsonDecode(decodedData[7]) -- Vehicle colorPalette0
	local cP1             = jsonDecode(decodedData[8]) -- Vehicle colorPalette1
	local playerNickname  = decodedData[9]

	if Network.getPlayerServerID() == playerServerID then -- If player ID = received player ID seems it's his own vehicle then sync it
		insertVehicleMap(gameVehicleID, serverVehicleID) -- Insert new vehicle ID in map
		ownMap[tostring(gameVehicleID)] = 1 -- Insert vehicle in own map
		println("ID is same as received ID, syncing vehicle gameVehicleID: "..gameVehicleID.." with ServerID: "..serverVehicleID)
	else 
		if not vehicleName then return end
		println("New vehicle : "..vehicleName)
		tempServerVehicleID = serverVehicleID
		local spawnedVeh = spawn.spawnVehicle(vehicleName, serialize(vehicleConfig), vec3(0,0,0), quat(0,0,0,0), ColorF(c[1],c[2],c[3],c[4]), ColorF(cP0[1],cP0[2],cP0[3],cP0[4]), ColorF(cP1[1],cP1[2],cP1[3],cP1[4]))
		nicknameMap[tostring(spawnedVeh:getID())] = playerNickname
		insertVehicleMap(spawnedVeh:getID(), serverVehicleID) -- Insert new vehicle ID in map
	end
	
	if currentVeh then be:enterVehicle(0, currentVeh) end -- Camera fix
end
--================================= ON VEHICLE SPAWNED (SERVER) ===================================	



--================================= ON VEHICLE SPAWNED (CLIENT) ===================================	
local function onVehicleSpawned(gameVehicleID)
	print("Vehicle spawned : "..gameVehicleID)
	local veh = be:getObjectByID(gameVehicleID)
	veh:queueLuaCommand("extensions.addModulePath('lua/vehicle/extensions/BeamMP')") -- Load lua files
	veh:queueLuaCommand("extensions.loadModulesInDirectory('lua/vehicle/extensions/BeamMP')")
	--if Network.getStatus() > 0 and not getServerVehicleID(gameVehicleID) then -- If is connecting or connected
	if Network.getStatus() > 0 then
		sendVehicle(gameVehicleID) -- Send it to the server
	end
	if Network.getStatus() == 2 then
		if isOwn(gameVehicleID) then
			veh:queueLuaCommand("powertrainVE.sendAllPowertrain()")
		end
	end
end
--================================= ON VEHICLE SPAWNED (CLIENT) ===================================	



--================================= ON VEHICLE REMOVED (SERVER) ===================================	
local function onServerVehicleRemoved(serverVehicleID, data)
	local gameVehicleID = getGameVehicleID(serverVehicleID) -- Get game ID
	if gameVehicleID then
		local veh = be:getObjectByID(gameVehicleID) -- Get associated vehicle
		if veh and gameVehicleID then
			onVehicleDestroyedAllowed = false
			commands.setFreeCamera() -- Fix camera
			veh:delete() -- Remove it
			if commands.isFreeCamera(player) then commands.setGameCamera() end -- Fix camera
		end
	else
		println("gameVehicleID for serverVehicleID "..serverVehicleID.." not found. (onServerVehicleRemoved)")
		data = Network.split(data, ":")
		if data[1] and data[2] then -- 1:host playerID - 2:host gameVehicleID
			if Network.getPlayerServerID() == data[1] then
				be:getObjectByID(data[2]):delete()
			end
		end
	end
end
--================================= ON VEHICLE REMOVED (SERVER) ===================================	



--================================= ON VEHICLE REMOVED (CLIENT) ===================================	
local function onVehicleDestroyed(gameVehicleID)
	print("Vehicle destroyed : "..gameVehicleID)
	if Network.getStatus() > 0 then -- If TCP is connecting or connected
		if onVehicleDestroyedAllowed then -- If function is not coming from onServerVehicleDestroyed then
			local serverVehicleID = getServerVehicleID(tostring(gameVehicleID)) -- Get the serverVehicleID
			if serverVehicleID then
				Network.send(Network.buildPacket(1, 2121, serverVehicleID, ""))
			end
		else 
			onVehicleDestroyedAllowed = true
		end
	end
end
--================================= ON VEHICLE REMOVED (CLIENT) ===================================	



--======================= ON VEHICLE SWITCHED (CLIENT) =======================	
local function onVehicleSwitched(oldID, newID)
	print("Vehicle switched : "..oldID.." - "..newID)
	if Network.getStatus() > 0 then -- If TCP is connecting or connected
		local newID = getServerVehicleID(newID) -- Get new serverVehicleID of the new vehicle the player is driving
		if newID then -- If it's not null
			Network.send(Network.buildPacket(1, 2122, newID, ""))
		end
	end
end
--======================= ON VEHICLE SWITCHED (CLIENT) =======================



--======================= ON VEHICLE RESETTED (CLIENT) =======================	
local function onVehicleResetted(gameVehicleID)
	print("Vehicle resetted : "..gameVehicleID)
	if Network.getStatus() > 0 then -- If TCP is connecting or connected
		local serverVehicleID = getServerVehicleID(gameVehicleID) -- Get new serverVehicleID of the new vehicle the player is driving
		if serverVehicleID and isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle -- If it's not null
			--Network.send(Network.buildPacket(1, 2123, serverVehicleID, ""))
		end
	end
end
--======================= ON VEHICLE RESETTED (CLIENT) =======================



--======================= ON VEHICLE RESETTED (SERVER) =======================	
local function onServerVehicleResetted(serverVehicleID)
	local gameVehicleID = getGameVehicleID(serverVehicleID) -- Get game ID
	if gameVehicleID then
		local veh = be:getObjectByID(gameVehicleID) -- Get associated vehicle
		if veh and gameVehicleID then
			veh:reset()
		end
	else
		println("gameVehicleID for serverVehicleID "..serverVehicleID.." not found. (onServerVehicleResetted)")
	end
end
--======================= ON VEHICLE RESETTED (SERVER) =======================



local function onUpdate(dt)
	if Network.getStatus() == 2 then
		print(serialize(nicknameMap))
		if be:getObjectCount() == 0 then return end -- If no vehicle do nothing	
		for i = 0, be:getObjectCount() do -- For each vehicle		
			local veh = be:getObject(i) --  Get vehicle			
			if veh then -- For loop always return one empty vehicle ?	
				if not isOwn(veh:getID()) then
					local pos = veh:getPosition()
					pos.z = pos.z + 2.0
					debugDrawer:drawTextAdvanced(
						pos,
						String(" "..nicknameMap[tostring(veh:getID())]),
						ColorF(1,1,1,1), true, false, -- Color / Background / Wtf
						ColorI(0,0,0,255)
					)
				end
			end
		end
	end
end



M.onUpdate             = onUpdate
M.onVehicleSwitched       = onVehicleSwitched
M.onDisconnect            = onDisconnect
M.isOwn                   = isOwn
M.getOwnMap               = getOwnMap
M.getGameVehicleID        = getGameVehicleID
M.getServerVehicleID      = getServerVehicleID
M.onVehicleDestroyed      = onVehicleDestroyed
M.onVehicleSpawned        = onVehicleSpawned
M.deleteAllVehicles       = deleteAllVehicles
M.sendAllVehicles         = sendAllVehicles
M.sendVehicle             = sendVehicle
M.sendVehicleData         = sendVehicleData
M.onServerVehicleSpawned  = onServerVehicleSpawned
M.onServerVehicleRemoved  = onServerVehicleRemoved
M.onVehicleResetted       = onVehicleResetted
M.onServerVehicleResetted = onServerVehicleResetted



return M