--====================================================================================
-- All work by Jojos38 & Titch2000.
-- You have no permission to edit, redistrobute or upload. Contact us for more info!
--====================================================================================



local M = {}



--================================ DISABLE PAUSE ================================
local function onPhysicsPaused() -- If physics is paused
	if Network.getStatus() > 0 then -- If connected to a server
		ui_message("Pausing is not allowed when connected to a server", 5, "")
		bullettime.pause(false) -- If user pause the game then resume it
	end
end
--================================ DISABLE PAUSE ================================

-- TODO : DISABLE SLOW MOTION
-- TODO : Synchronize time and weather
-- TODO : Synchronize gravity and wind ????


M.onPhysicsPaused      = onPhysicsPaused



return M
