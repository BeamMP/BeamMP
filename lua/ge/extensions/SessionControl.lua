--====================================================================================
-- All work by Jojos38 & Titch2000.
-- You have no permission to edit, redistrobute or upload. Contact us for more info!
--====================================================================================



local M = {}



--================================ DISABLE PAUSE ================================
local function onPhysicsPaused() -- If physics is paused
	if GameNetwork.connectionStatus() > 0 and mpConfig.getPauseDisabled() then
		UI.error("Pausing is not allowed when connected to this server", 5, "")
		bullettime.pause(false) -- Resume game
	end
end
--================================ DISABLE PAUSE ================================

-- TODO : DISABLE SLOW MOTION
-- TODO : Synchronize time and weather
-- TODO : Synchronize gravity and wind ????


M.onPhysicsPaused      = onPhysicsPaused



return M
