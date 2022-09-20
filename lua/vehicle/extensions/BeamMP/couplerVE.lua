--====================================================================================
-- All work by Anonymous and Olrosse.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================
-- Coupler (trailer) sync related functions
--====================================================================================

local M = {}



local function toggleCouplerState(data)
	local decodedData = jsonDecode(data)
	local ID = obj:getID()
	if decodedData._nodetag and ID == obj2id then
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

local function onCouplerAttached(nodeId, obj2id, obj2nodeId, attachSpeed, attachEnergy)
	local MPcouplers = {}
	MPcouplers.state = true
	MPcouplers._nodetag = nodeId
	MPcouplers.obj2id = obj2id
	if v.mpVehicleType == "L" then
		obj:queueGameEngineLua("MPVehicleGE.sendBeamstate(\'"..jsonEncode(MPcouplers).."\'," ..tostring(obj:getID())..")")
	end
end

local function onCouplerDetached(nodeId, obj2id, obj2nodeId)
	local MPcouplers = {}
	MPcouplers.state = false
	MPcouplers._nodetag = nodeId
	MPcouplers.obj2id = obj2id
	if v.mpVehicleType == "L" then
		obj:queueGameEngineLua("MPVehicleGE.sendBeamstate(\'"..jsonEncode(MPcouplers).."\'," ..tostring(obj:getID())..")")
	end
end



M.toggleCouplerState = toggleCouplerState
M.onCouplerAttached = onCouplerAttached
M.onCouplerDetached = onCouplerDetached

return M
