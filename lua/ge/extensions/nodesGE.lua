--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}
print("Loading nodesGE...")



-- ============= VARIABLES =============
-- ============= VARIABLES =============



local function tick()
	local ownMap = MPVehicleGE.getOwnMap() -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("nodesVE.getNodes()")
		end
	end
end

local function sendNodes(data, gameVehicleID) -- Update electrics values of all vehicles - The server check if the player own the vehicle itself
	if MPGameNetwork.connectionStatus() == 1 then -- If TCP connected
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			MPGameNetwork.sendSplit('Xn:', serverVehicleID..":", data)
		end
	end
end

local function applyNodes(data, serverVehicleID)
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		--local pos = veh:getPosition()
		--veh:setPositionRotation(pos.x, pos.y, pos.z, 0, 0, 0.01, math.random())
		veh:queueLuaCommand("nodesVE.applyNodes(\'"..data.."\')") -- Send nodes values
	end
end

local function applyRot(data, serverVehicleID)
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		veh:queueLuaCommand("nodesVE.applyRotation(\'"..data.."\')") -- Send nodes values
	end
end

local function handle(rawData)
	--print("nodesGE.handle: "..rawData)
	local code = string.sub(rawData, 1, 1)
	if code == "p" then
		rawData = string.sub(rawData,3)
		local serverVehicleID = string.match(rawData,"(%w+)%:")
		local data = string.match(rawData,":(.*)")
		applyRot(data, serverVehicleID)
	else
		rawData = string.sub(rawData,3)
		local serverVehicleID = string.match(rawData,"(%w+)%:")
		local data = string.match(rawData,":(.*)")
		applyNodes(data, serverVehicleID)
	end
end



M.tick       = tick
M.handle     = handle
M.sendNodes  = sendNodes
M.applyNodes = applyNodes
M.applyRot   = applyRot



print("nodesGE loaded")
return M
