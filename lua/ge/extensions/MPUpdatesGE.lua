--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}
print("MPUpdatesGE Initialising...")



local nodesDelay = 0
local nodesTickrate = 1.0 -- in seconds

local positionDelay = 0
local positionTickrate = 0.020

local inputsDelay = 0
local inputsTickrate = 1/10 -- 10 times / second

local electricsDelay = 0
local electricsTickrate = 1/16 -- 16 times / second



local function onPlayerConnect()
	-- Update everything for the new connected player
	MPElectricsGE.tick()
	--nodesGE.tick()
	positionGE.tick()
	MPInputsGE.tick()
	powertrainGE.tick()
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
	end
end



M.onPlayerConnect = onPlayerConnect
M.onUpdate        = onUpdate



return M
