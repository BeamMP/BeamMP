--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}
print("Loading nodesGE...")


local function tick()
	local ownMap = MPVehicleGE.getOwnMap()
	for i,v in pairs(ownMap) do
		local veh = be:getObjectByID(i)
		if veh then
			veh:queueLuaCommand("nodesVE.getNodes()")
		end
	end
end

local function sendNodes(data, gameVehicleID)
	if MPGameNetwork.launcherConnected() then
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID)
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then
			MPGameNetwork.send('Xn:'..serverVehicleID..":"..data)
		end
	end
end

local function applyNodes(data, serverVehicleID)
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		veh:queueLuaCommand("nodesVE.applyNodes(\'"..data.."\')")
	end
end

local function handle(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")
	if code == "n" then
		applyNodes(data, serverVehicleID)
	else
		log('W', 'handle', "Received unknown packet '"..code.."'! ".. rawData)
	end
end



M.tick       = tick
M.handle     = handle
M.sendNodes  = sendNodes
M.applyNodes = applyNodes


print("nodesGE loaded")
return M
