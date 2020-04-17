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
	if GameNetwork.connectionStatus == 1 then -- If TCP connected
		MPSettings.nodesDelay = MPSettings.nodesDelay + dt
		if MPSettings.nodesDelay > MPSettings.nodesTickrate then
			MPSettings.nodesDelay = 0 -- Reset the delay
			--nodesGE.tick() -- Comment this line to disable nodes synchronization
		end

		MPSettings.positionDelay = MPSettings.positionDelay + dt
		if MPSettings.positionDelay > MPSettings.positionTickrate then
			MPSettings.positionDelay = 0 -- Reset the delay
			MPSettings.positionGE.tick() -- Comment this line to disable position synchronization
		end

		MPSettings.inputsDelay = MPSettings.inputsDelay + dt
		if MPSettings.inputsDelay > MPSettings.inputsTickrate then
			MPSettings.inputsDelay = 0 -- Reset the delay
			MPSettings.inputsGE.tick() -- Comment this line to disable inputs synchronization
		end

		MPSettings.electricsDelay = MPSettings.electricsDelay + dt
		if MPSettings.electricsDelay > MPSettings.electricsTickrate then
			MPSettings.electricsDelay = 0 -- Reset the delay
			MPSettings.electricsGE.tick() -- Comment this line to disable electrics synchronization
		end
	end
end


M.onPlayerConnect = onPlayerConnect
M.onUpdate        = onUpdate



return M
