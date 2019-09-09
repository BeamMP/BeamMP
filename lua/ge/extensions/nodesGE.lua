--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}



-- ============= VARIABLES =============
local msgpack = require('libs/lua-MessagePack/MessagePack')
local LibDeflate = require("LibDeflate")
local config = {level = 1}
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
			--local compressed = LibDeflate:CompressDeflate(data, config)		
			--local compressed_binary_data = msgpack.pack(compressed)
			--local binary_data = msgpack.pack(data)
			Network.send("2132"..serverVehicleID..data) -- Send data
			--print(TCP.send("21107"..compressed..serverVehicleID)) -- Send data
		end
	end
end



local function applyNodes(data, serverVehicleID)
	local gameVehicleID = vehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		--print("ok !")
		--local decompressed = LibDeflate:DecompressDeflate(data)
		veh:queueLuaCommand("nodesVE.applyNodes(\'"..data.."\')") -- Send electrics values
	end
end



M.tick   	 = tick
M.sendNodes  = sendNodes
M.applyNodes = applyNodes



return M