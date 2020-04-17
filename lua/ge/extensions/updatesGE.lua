--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}

local function onPlayerConnect()
	-- Update everything for the new connected player
	electricsGE.tick()
	nodesGE.tick()
	positionGE.tick()
	inputsGE.tick()
	powertrainGE.tick()
end



local function onUpdate(dt)
	if GameNetwork.connectionStatus() == 1 then -- If TCP connected
		mpConfig.nodesDelay = mpConfig.nodesDelay + dt
		if mpConfig.nodesDelay > mpConfig.nodesTickrate then
			mpConfig.nodesDelay = 0 -- Reset the delay
			--nodesGE.tick() -- Comment this line to disable nodes synchronization
		end

		mpConfig.positionDelay = mpConfig.positionDelay + dt
		if mpConfig.positionDelay > mpConfig.positionTickrate then
			mpConfig.positionDelay = 0 -- Reset the delay
			mpConfig.positionGE.tick() -- Comment this line to disable position synchronization
		end

		mpConfig.inputsDelay = mpConfig.inputsDelay + dt
		if mpConfig.inputsDelay > mpConfig.inputsTickrate then
			mpConfig.inputsDelay = 0 -- Reset the delay
			mpConfig.inputsGE.tick() -- Comment this line to disable inputs synchronization
		end

		mpConfig.electricsDelay = mpConfig.electricsDelay + dt
		if mpConfig.electricsDelay > mpConfig.electricsTickrate then
			mpConfig.electricsDelay = 0 -- Reset the delay
			mpConfig.electricsGE.tick() -- Comment this line to disable electrics synchronization
		end
	end
end


M.onPlayerConnect = onPlayerConnect
M.onUpdate        = onUpdate



return M
