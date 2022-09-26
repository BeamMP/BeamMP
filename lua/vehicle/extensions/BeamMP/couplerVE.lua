--====================================================================================
-- All work by Anonymous and Olrosse.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================
-- Coupler (trailer) sync related functions
--====================================================================================

local M = {}

local timer = 0.1 -- timer to prevent doors from opening on spawn and reset
local MPcouplercache = {}
local lastNodeIDcoupled
local lastNodeID2coupled
local lastNodeIDdecoupled
local lastNodeID2decoupled

local function toggleCouplerState(data)
	local decodedData = jsonDecode(data)
	for k,v in pairs(decodedData) do
		if v.state == false or v.state == true then
			if v._nodetag and not v.trailer then
				if v.state then
					beamstate.attachCouplers(v._nodetag)
				else
					obj:detachCoupler(v._nodetag, 0)
				end
			elseif v.state == true then
				beamstate.activateAutoCoupling()
			elseif v.state == false then
				beamstate.disableAutoCoupling()
				beamstate.detachCouplers()
				obj:stopLatching()
			end
		elseif controller.getControllerSafe(v.name).getGroupState() ~= v.state then
			if v.state == "detached" or v.state == "autoCoupling" or v.state == "broken" then
				controller.getControllerSafe(v.name).detachGroup()
			elseif v.state == "attached" then
				controller.getControllerSafe(v.name).tryAttachGroupImpulse()
			end
		end
	end
end

local function onCouplerAttached(nodeId, obj2id, obj2nodeId, attachSpeed, attachEnergy)
	if nodeId == lastNodeID2coupled and obj2nodeId == lastNodeIDcoupled then return end -- stops it from sending a double packet
	if timer <= 0 and v.mpVehicleType == "L" then
		local ID = obj:getID()
		local Advanced = false
		-- Advanced couplers, doors etc
		local MPcouplerdata = {}
		if timer <= 0 and ID == obj2id then
			for k,v in pairs(MPcouplercache) do
				local state = controller.getControllerSafe(v.name).getGroupState()
				if v.state ~= state then
					Advanced = true
					local couplerstates = {}
					couplerstates.name = v.name
					couplerstates.state = state
					table.insert(MPcouplerdata,couplerstates)
				end
				v.state = state
			end
		end

		-- basic couplers
		if not Advanced then
			local MPcouplers = {}
			MPcouplers.state = true
			MPcouplers._nodetag = nodeId
			if ID == obj2id then -- checking if coupler is connecting to another vehicle
				MPcouplers.trailer = false
			else
				MPcouplers.trailer = true
			end
			MPcouplers.obj2id = obj2id
			table.insert(MPcouplerdata,MPcouplers)
		end

		obj:queueGameEngineLua("MPVehicleGE.sendBeamstate(\'"..jsonEncode(MPcouplerdata).."\'," ..tostring(obj:getID())..")")
	end
	
	lastNodeIDcoupled = nodeId
	lastNodeID2coupled = obj2nodeId
end

local function onCouplerDetached(nodeId, obj2id, obj2nodeId)
	if nodeId == lastNodeID2decoupled and obj2nodeId == lastNodeIDdecoupled then return end -- stops it from sending a double packet
	if timer <= 0 and v.mpVehicleType == "L" then
		local ID = obj:getID()
		local Advanced = false
		-- Advanced couplers, doors etc
		local MPcouplerdata = {}
		if timer <= 0 and ID == obj2id then
			for k,v in pairs(MPcouplercache) do
				local state = controller.getControllerSafe(v.name).getGroupState()
				if v.state ~= state then
					Advanced = true
					local couplerstates = {}
					couplerstates.name = v.name
					couplerstates.state = state
					table.insert(MPcouplerdata,couplerstates)
				end
				v.state = state
			end
		end

		-- basic couplers
		if not Advanced then
			local MPcouplers = {}
			MPcouplers.state = false
			MPcouplers._nodetag = nodeId
			if ID == obj2id then -- checking if coupler is connecting to another vehicle
				MPcouplers.trailer = false
			else
				MPcouplers.trailer = true
			end
			MPcouplers.obj2id = obj2id
			table.insert(MPcouplerdata,MPcouplers)
		end

		obj:queueGameEngineLua("MPVehicleGE.sendBeamstate(\'"..jsonEncode(MPcouplerdata).."\'," ..tostring(obj:getID())..")")
	end
	
	lastNodeIDdecoupled = nodeId
	lastNodeID2decoupled = obj2nodeId
end

local function updateGFX(dt)
	if timer >= 0 then
		timer = timer - dt
	end
end

local function onReset()
	timer = 0.1
	MPcouplercache = {}
	local AdvCouplers = controller.getControllersByType("advancedCouplerControl")
	if AdvCouplers == nil then return end
	for k,v in pairs(AdvCouplers) do
		local couplerstates = {}
		couplerstates.name = v.name
		couplerstates.state = "attached"
		table.insert(MPcouplercache,couplerstates)
	end
	
	lastNodeIDcoupled = nil
	lastNodeID2coupled = nil
	lastNodeIDdecoupled = nil
	lastNodeID2decoupled = nil
end

M.onReset            = onReset
M.onInit             = onReset
M.onExtensionLoaded  = onReset
M.toggleCouplerState = toggleCouplerState
M.onCouplerAttached  = onCouplerAttached
M.onCouplerDetached  = onCouplerDetached
M.updateGFX          = updateGFX

return M
