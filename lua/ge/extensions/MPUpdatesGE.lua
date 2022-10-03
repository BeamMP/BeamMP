--====================================================================================
-- All work by Titch2000 and jojos38.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading MPUpdatesGE...")


-- Tickrate - how often data is being sent from the client, in seconds
local nodesDelay = 0
local nodesTickrate = 1.0

local positionDelay = 0
local positionTickrate = 0.020

local inputsDelay = 0
local inputsTickrate = 1/30

local electricsDelay = 0
local electricsTickrate = 1/15

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
	if MPGameNetwork and MPGameNetwork.connectionStatus() == 1 then -- If TCP connected
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
		
		powertrainDelay = powertrainDelay + dt
		if powertrainDelay > powertrainTickrate then
			powertrainDelay = 0 -- Reset the delay
			MPPowertrainGE.tick() -- Comment this line to disable powertrain synchronization
		end
	end
end



M.onPlayerConnect = onPlayerConnect
M.onUpdate        = onUpdate



print("MPUpdatesGE loaded")
return M
