--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}



-- ============= VARIABLES =============
-- ============= VARIABLES =============



local function tick()			
	local ownMap = vehicleGE.getOwnMap() -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("nodesVE.getNodes()")
		end
	end
end

local function sendNodes(data, gameVehicleID) -- Update electrics values of all vehicles - The server check if the player own the vehicle itself
	if Network.getStatus() == 2 then -- If UDP is connected
		local serverVehicleID = vehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and vehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle		
			--Network.send(Network.buildPacket(0, 2132, serverVehicleID, data))
		end
	end
end

local function applyNodes(data, serverVehicleID)
	local gameVehicleID = vehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		local pos = veh:getPosition()
		--veh:setPositionRotation(pos.x, pos.y, pos.z, 0, 0, 0.01, math.random())
		--veh:queueLuaCommand("nodesVE.applyNodes(\'"..data.."\')") -- Send nodes values
	end
end



M.tick   	 = tick
M.sendNodes  = sendNodes
M.applyNodes = applyNodes



return M