--====================================================================================
-- All work by Titch2000 and jojos38.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading MPUpdatesGE...")


-- Tickrate - how often data is being sent from the client, in seconds
local nodesTimer = 0
local nodesTickrate = 1.0

local positionTimer = 0
local positionTickrate = 0.020

local inputsTimer = 0
local inputsTickrate = 1/30

local electricsTimer = 0
local electricsTickrate = 1/15

local powertrainTimer = 0
local powertrainTickrate = 1/10


 -- This doesn't do anything because the data isn't queued on the receiving end
local function onPlayerConnect()
	MPElectricsGE.tick()
	--nodesGE.tick()
	positionGE.tick()
	MPInputsGE.tick()
	MPPowertrainGE.tick()
end



local function onUpdate(dt)
	if MPGameNetwork and MPGameNetwork.launcherConnected() then
		--nodesTimer = nodesTimer + dt
		--if nodesTimer >= getNodesTickrate() then
		--	nodesTimer = 0
		--	nodesGE.tick() -- Comment this line to disable nodes synchronization
		--end

		positionTimer = positionTimer + dt
		if positionTimer >= positionTickrate then
			positionTimer = 0
			positionGE.tick() -- Comment this line to disable position synchronization
		end

		inputsTimer = inputsTimer + dt
		if inputsTimer >= inputsTickrate then
			inputsTimer = 0
			MPInputsGE.tick() -- Comment this line to disable inputs synchronization
		end

		electricsTimer = electricsTimer + dt
		if electricsTimer >= electricsTickrate then
			electricsTimer = 0
			MPElectricsGE.tick() -- Comment this line to disable electrics synchronization
		end
		
		powertrainTimer = powertrainTimer + dt
		if powertrainTimer >= powertrainTickrate then
			powertrainTimer = 0
			MPPowertrainGE.tick() -- Comment this line to disable powertrain synchronization
		end
	end
end



M.onPlayerConnect = onPlayerConnect
M.onUpdate        = onUpdate



print("MPUpdatesGE loaded")
return M
