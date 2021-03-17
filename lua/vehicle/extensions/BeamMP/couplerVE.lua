--====================================================================================
-- All work by Anonymous.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
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