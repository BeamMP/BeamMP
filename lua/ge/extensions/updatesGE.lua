--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}
print("updatesGE Initialising...")

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
		if mpConfig.nodesDelay > mpConfig.getNodesTickrate() then
			mpConfig.nodesDelay = 0 -- Reset the delay
			nodesGE.tick() -- Comment this line to disable nodes synchronization
		end

		mpConfig.positionDelay = mpConfig.positionDelay + dt
		if mpConfig.positionDelay > mpConfig.getPositionTickrate() then
			mpConfig.positionDelay = 0 -- Reset the delay
			positionGE.tick() -- Comment this line to disable position synchronization
		end

		mpConfig.inputsDelay = mpConfig.inputsDelay + dt
		if mpConfig.inputsDelay > mpConfig.getInputsTickrate() then
			mpConfig.inputsDelay = 0 -- Reset the delay
			inputsGE.tick() -- Comment this line to disable inputs synchronization
		end

		mpConfig.electricsDelay = mpConfig.electricsDelay + dt
		if mpConfig.electricsDelay > mpConfig.getElectricsTickrate() then
			mpConfig.electricsDelay = 0 -- Reset the delay
			electricsGE.tick() -- Comment this line to disable electrics synchronization
		end
	end
end


M.onPlayerConnect = onPlayerConnect
M.onUpdate        = onUpdate



print("updatesGE Loaded.")
return M
