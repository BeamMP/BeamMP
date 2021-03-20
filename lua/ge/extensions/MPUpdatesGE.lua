--====================================================================================
-- All work by Titch2000 and jojos38.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading MPUpdatesGE...")



local nodesDelay = 0
local nodesTickrate = 1.0 -- in seconds

local positionDelay = 0
local positionTickrate = 0.020

local inputsDelay = 0
local inputsTickrate = 1/10 -- 10 times / second

local electricsDelay = 0
local electricsTickrate = 1/16 -- 16 times / second

local gearDelay = 0
local gearTickrate = 1/4

local powertrainDelay = 0
local powertrainTickrate = 1/10



local function onPlayerConnect()
	-- Update everything for the new connected player
	MPElectricsGE.tick()
	--nodesGE.tick()
	positionGE.tick()
	MPInputsGE.tick()
	MPPowertrainGE.tick()
end



local function onUpdate(dt)
	if MPGameNetwork.connectionStatus() == 1 then -- If TCP connected
		--nodesDelay = nodesDelay + dt
		--if nodesDelay > getNodesTickrate() then
		--	nodesDelay = 0 -- Reset the delay
		--	nodesGE.tick() -- Comment this line to disable nodes synchronization
		--end

		positionDelay = positionDelay + dt
		if positionDelay > positionTickrate then
			positionDelay = 0 -- Reset the delay
			positionGE.tick() -- Comment this line to disable position synchronization
		end

		inputsDelay = inputsDelay + dt
		if inputsDelay > inputsTickrate then
			inputsDelay = 0 -- Reset the delay
			MPInputsGE.tick() -- Comment this line to disable inputs synchronization
		end

		electricsDelay = electricsDelay + dt
		if electricsDelay > electricsTickrate then
			electricsDelay = 0 -- Reset the delay
			MPElectricsGE.tick() -- Comment this line to disable electrics synchronization
		end
		
		gearDelay = gearDelay + dt
		if gearDelay > gearTickrate then
			gearDelay = 0 -- Reset the delay
			MPElectricsGE.tickGears()
		end
		
		powertrainDelay = powertrainDelay + dt
		if powertrainDelay > powertrainTickrate then
			powertrainDelay = 0 -- Reset the delay
			MPPowertrainGE.tick() -- Comment this line to disable electrics synchronization
		end
	end
end



M.onPlayerConnect = onPlayerConnect
M.onUpdate        = onUpdate



print("MPUpdatesGE loaded")
return M
