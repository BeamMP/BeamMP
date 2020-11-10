--====================================================================================
-- All work by Jojos38 & Titch2000.
-- You have no permission to edit, redistrobute or upload. Contact us for more info!
--====================================================================================



local M = {}
print("electricsGE Initialising...")


local lastElectrics = ""
local lastGear = ""

local function tick() -- Update electrics values of all vehicles - The server check if the player own the vehicle itself
	local ownMap = MPVehicleGE.getOwnMap() -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("electricsVE.getElectrics()") -- Send electrics values
			veh:queueLuaCommand("electricsVE.getGear()") -- Send gears values
		end
	end
end



local function sendElectrics(data, gameVehicleID) -- Called by vehicle lua
	if MPGameNetwork.connectionStatus() == 1 then -- If TCP connected
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			if data ~= lastElectrics then
				MPGameNetwork.send('We:'..serverVehicleID..":"..data)--Network.send(Network.buildPacket(0, 2131, serverVehicleID, data))
				lastElectrics = data
				--print("Electrics sent "..serverVehicleID)
			end
		end
	end
end



local function applyElectrics(data, serverVehicleID)
	--print("gameVehicleID: "..MPVehicleGE.getGameVehicleID(serverVehicleID))
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		if not MPVehicleGE.isOwn() then
			veh:queueLuaCommand("electricsVE.applyElectrics(\'"..data.."\')")
		end
	end
end



local function sendGear(data, gameVehicleID)
	if MPGameNetwork.connectionStatus() == 1 then -- If TCP connected
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			if data ~= lastGear then
				MPGameNetwork.send('Wg:'..serverVehicleID..":"..data)--Network.buildPacket(0, 2135, serverVehicleID, data))
				lastGear = data
				--print("Gear sent "..serverVehicleID)
			end
		end
	end
end

local function applyGear(data, serverVehicleID)
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		if not MPVehicleGE.isOwn() then
			veh:queueLuaCommand("electricsVE.applyGear(\'"..data.."\')")
		end
	end
end

local function handle(rawData)
	--print("electricsGE.handle: "..rawData)
	local code = string.sub(rawData, 1, 1)
	local rawData = string.sub(rawData, 3)
	if code == "e" then -- Electrics (indicators, lights etc...)
		local serverVehicleID = string.match(rawData,"^.-:")
		serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1)
		local data = string.match(rawData,":(.*)")
		applyElectrics(data, serverVehicleID)
	elseif code == "g" then -- Gears
		local serverVehicleID = string.match(rawData,"^.-:")
		serverVehicleID = serverVehicleID:sub(1, #serverVehicleID - 1)
		local data = string.match(rawData,":(.*)")
		applyGear(data, serverVehicleID)
	end
end



M.tick 			 = tick
M.handle     	 = handle
M.sendGear		 = sendGear
M.applyGear	 	 = applyGear
M.sendElectrics  = sendElectrics
M.applyElectrics = applyElectrics



print("electricsGE Loaded.")
return M
