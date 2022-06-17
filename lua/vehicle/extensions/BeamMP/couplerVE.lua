--====================================================================================
-- All work by Anonymous and Olrosse.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================
-- Coupler (trailer) sync related functions
--====================================================================================

local M = {}



local function toggleCouplerState(data)
	local decodedData = jsonDecode(data)
	if decodedData._nodetag then
		if decodedData.state then
			beamstate.attachCouplers(decodedData._nodetag)
		else
			beamstate.detachCouplers(decodedData._nodetag, decodedData.forceLocked, decodedData.forceWelded)
		end
	elseif decodedData.state then
		beamstate.activateAutoCoupling()
	else
		beamstate.disableAutoCoupling()
		beamstate.detachCouplers()
		obj:stopLatching()
	end
end



M.toggleCouplerState = toggleCouplerState



return M
