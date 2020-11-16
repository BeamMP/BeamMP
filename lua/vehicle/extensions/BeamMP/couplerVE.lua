--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================


local M = {}

local function toggleCouplerState(state)
    if state == "true" then
        beamstate.activateAutoCoupling()
    else
        beamstate.disableAutoCoupling()
    end
end

M.toggleCouplerState = toggleCouplerState

return M
