-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

local timer = 0.1 -- timer to prevent doors from opening on spawn and reset
local MPcouplercache = {}
local lastNodeIDcoupled
local lastNodeID2coupled
local lastNodeIDdecoupled
local lastNodeID2decoupled

local originalActivateAutoCoupling = beamstate.activateAutoCoupling

local function activateAutoCoupling(...)
	if v.mpVehicleType and v.mpVehicleType == "R" then return end
	originalActivateAutoCoupling(...)
end

beamstate.activateAutoCoupling = activateAutoCoupling

local function toggleCouplerState(data)
	local decodedData = jsonDecode(data)
	for k,v in pairs(decodedData) do
		if v.state == false or v.state == true then
			if v._nodetag then
				local coupler = beamstate.couplerCache[v._nodetag]
				if coupler then
					if v.state then
						obj:attachCoupler(coupler.cid, coupler.couplerTag or "", coupler.couplerStrength or 1000000, 10, coupler.couplerLockRadius or 0.025, 0.3, coupler.couplerTargets or 0)
					else
						obj:detachCoupler(v._nodetag, 0)
						obj:queueGameEngineLua(string.format("onCouplerDetach(%s,%s)", obj:getId(), coupler.cid))
						extensions.couplings.onBeamstateDetachCouplers()
					end
				else
					log("D", "couplerVE", "no cached coupler found with tag"..v._nodetag)
				end
			end
		elseif controller.getControllerSafe(v.name).getGroupState() ~= v.state then
			local couplerController = {}
			if controllerSyncVE.OGcontrollerFunctionsTable and controllerSyncVE.OGcontrollerFunctionsTable[v.name] then -- for controller sync compatibility,
				couplerController = controllerSyncVE.OGcontrollerFunctionsTable[v.name]	-- the controller sync disables the functions for remote vehicles to prevent ghost controlling, so we need to call the original function instead
			elseif controller.getControllerSafe(v.name) then
				couplerController = controller.getControllerSafe(v.name)
			end

			if v.state == "detached" or v.state == "autoCoupling" or v.state == "broken" then
				couplerController.detachGroup()
			elseif v.state == "attached" then
				couplerController.tryAttachGroupImpulse()
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
		if ID == obj2id then
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
		if ID == obj2id then
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
