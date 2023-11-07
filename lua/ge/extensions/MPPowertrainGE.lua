--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================

--- MPPowertrainGE API.
--- Author of this documentation is Titch
--- @module MPPowertrainGE
--- @usage applyLivePowertrain(...) -- internal access
--- @usage MPPowertrainGE.handle(...) -- external access


local M = {}


--- Called on specified interval by MPUpdatesGE to simulate our own tick event to collect data.
local function tick()
	local ownMap = MPVehicleGE.getOwnMap() -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("MPPowertrainVE.check()") -- Send all devices values
		end
	end
end


--- Wraps up vehicle powertrain data and sends it to the server.
-- INTERNAL USE
-- @param data table The powertrain data from VE
-- @param gameVehicleID number The vehicle ID according to the local game
local function sendLivePowertrain(data, gameVehicleID)
	if MPGameNetwork.launcherConnected() then
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			MPGameNetwork.send('Yl:'..serverVehicleID..":"..data) -- Send powertrain to server
		end
	end
end


--- This function serves to send the powertrain data received for another players vehicle from GE to VE, where it is handled.
-- @param data table The data to be applied as powertrain
-- @param serverVehicleID string The VehicleID according to the server.
local function applyLivePowertrain(data, serverVehicleID)
	local gameVehicleID = MPVehicleGE.getGameVehicleID(serverVehicleID) or -1 -- get gameID
	local veh = be:getObjectByID(gameVehicleID)
	if veh then
		veh:queueLuaCommand("MPPowertrainVE.applyLivePowertrain(\'"..data.."\')")
	end
end


--- The raw message from the server. This is unpacked first and then sent to applyLivePowertrain()
-- @param rawData string The raw message data.
local function handle(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")
	if code == "l" then
		applyLivePowertrain(data, serverVehicleID)
	else
		log('W', 'handle', "Received unknown packet '"..tostring(code).."'! ".. rawData)
	end
end



M.tick                   = tick
M.handle                 = handle
M.sendLivePowertrain     = sendLivePowertrain



return M
