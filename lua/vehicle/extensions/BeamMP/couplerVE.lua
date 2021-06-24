--====================================================================================
-- All work by Anonymous.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================
-- Coupler (trailer) sync related functions
--====================================================================================

local M = {}



local function toggleCouplerState(state)
    if state == "true" then
        beamstate.activateAutoCoupling()
    else
        beamstate.disableAutoCoupling()
	beamstate.detachCouplers() --added this line since disableAutoCoupling doesn't decouple
    end
end



M.toggleCouplerState = toggleCouplerState



return M
