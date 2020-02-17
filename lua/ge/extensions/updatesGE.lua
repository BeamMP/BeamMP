--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}



-- ============= VARIABLES =============
local nodesDelay = 0
local nodesTickrate = 4 -- in seconds

local positionDelay = 0
local positionTickrate = 0.05

local inputsDelay = 0
local inputsTickrate = 0.20

local electricsDelay = 0
local electricsTickrate = 6
-- TODO: use common tickrate to increase performances this is just for debugging
-- ============= VARIABLES =============



local function onPlayerConnect()
	-- Update everything for the new connected player
	electricsGE.tick() 
	nodesGE.tick()
	positionGE.tick()
	inputsGE.tick()
	powertrainGE.tick()
end



local function onUpdate(dt)
	if Network.getStatus() == 2 then -- If connected
		--nodesDelay = nodesDelay + dt
		--if nodesDelay > nodesTickrate then
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
			inputsGE.tick() -- Comment this line to disable inputs synchronization
		end
	
		electricsDelay = electricsDelay + dt
		if electricsDelay > electricsTickrate then
			electricsDelay = 0 -- Reset the delay
			electricsGE.tick() -- Comment this line to disable electrics synchronization
		end	
	end	
end



local function setPositionTR(tickRate)
	positionTickrate = tickRate
end



local function setNodeTR(tickRate)
	nodesTickrate = tickRate
end



local function setInputsTR(tickRate)
	inputsTickrate = tickRate
end



M.setInputsTR     = setInputsTR
M.setNodeTR       = setNodeTR
M.setPositionTR   = setPositionTR
M.onPlayerConnect = onPlayerConnect
M.onUpdate        = onUpdate



return M