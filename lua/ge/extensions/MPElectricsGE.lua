--====================================================================================
-- All work by Titch2000 and jojos38.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading MPElectricsGE...")



local lastElectrics = ""
local lastGear = ""



local function tick() -- Update electrics values of all vehicles
	local ownMap = MPVehicleGE.getOwnMap() -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("MPElectricsVE.check()") -- Check if any value changed
		end
	end
end



local function tickGears() -- Update gears of all vehicles
	for i = 0, be:getObjectCount() - 1 do -- For each vehicle
		local veh = be:getObject(i) --  Get vehicle
		if veh and not MPVehicleGE.isOwn(veh:getId()) then
			veh:queueLuaCommand("MPElectricsVE.checkGears()") -- Check if any value changed
		end
	end
end



local function sendElectrics(data, gameVehicleID) -- Called by vehicle lua
	if MPGameNetwork.connectionStatus() > 0 then -- If TCP connected
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) and data ~= lastElectrics then -- If serverVehicleID not null and player own vehicle
			MPGameNetwork.send('We:'..serverVehicleID..":"..data)
			lastElectrics = data
		end
	end
end



local function applyElectrics(data, serverVehicleID)
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		if not MPVehicleGE.isOwn(gameVehicleID) then
			veh:queueLuaCommand("MPElectricsVE.applyElectrics(\'"..data.."\')")
		end
	end
end



local function applyGear(data, serverVehicleID)
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		if not MPVehicleGE.isOwn(gameVehicleID) then
			veh:queueLuaCommand("MPElectricsVE.setGear(\'"..data.."\')")
		end
	end
end



local function handle(rawData)
	--print("MPElectricsGE.handle: "..rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")

	if code == "e" then -- Electrics (indicators, lights etc...)
		applyElectrics(data, serverVehicleID)
	elseif code == "g" then -- Gears
		applyGear(data, serverVehicleID)
	end
end



M.tick 			 = tick
M.tickGears		 = tickGears
M.handle     	 = handle
M.applyGear	 	 = applyGear
M.sendElectrics  = sendElectrics
M.applyElectrics = applyElectrics


print("MPElectricsGE loaded")
return M
