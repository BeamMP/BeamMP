-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

local abs = math.abs
local min = math.min
local max = math.max

local maxBeamLengthRatio = 2 -- If a beam becomes longer than its original length by this factor, it will be treated as broken
local damageThreshold = 100  -- Recalculate center of gravity if beamstate.damage changes by more than this amount
local damageDelay = 0.2      -- How long to wait before recalculating connected nodes or COG after the car was damaged

local connectedNodes = {}
local nodes = {}
local disconnectedNodes = {}
local parentNode = nil
local beamsChanged = false
local lastDamage = 0
local damageTimer = 0
local physicsFPS = 0
M.cogRel = vec3(0,0,0)

local refNode = v.data.refNodes[0].ref

-- Calculate center of gravity from connected nodes
local function calcCOG()
	
	--print("Calculating COG "..obj:getId())
	
	local totalMass = 0
	local cog = vec3(0,0,0)
	
	for i = 1, #nodes do
		local node = nodes[i]
		local nid = node[1]
		local nodeMass = node[2]
		local nodePos = obj:getNodePosition(nid)
		
		cog:setAdd(nodePos*nodeMass)
		
		totalMass = totalMass + nodeMass
	end
	
	cog:setScaled(1/totalMass)
	
	local rot = quatFromDir(-obj:getDirectionVector(), obj:getDirectionVectorUp())
	M.cogRel = cog:rotated(rot:inversed())
end

-- Find all nodes that are connected to the parent node
local function findConnectedNodes()
	if not parentNode then return end
	
	--print("Find connected nodes "..obj:getId())
	
	nodes = {}
	disconnectedNodes = {}
	
	local nodeStack = {}
	local visited = {}
	local connected = {}
	local stackIdx = 1
	
	nodeStack[1] = parentNode
	visited[parentNode] = true
	
	local cog = vec3(0,0,0)
	local totalMass = 0
	
	while stackIdx > 0 do
		local node = nodeStack[stackIdx]
		local nodeMass = obj:getNodeMass(node)
		local nodePos = obj:getNodePosition(node)
		
		nodes[#nodes+1] = {node, nodeMass*physicsFPS}
		connected[node] = 1
		
		cog:setAdd(nodePos*nodeMass)
		totalMass = totalMass + nodeMass
		
		nodeStack[stackIdx] = nil
		stackIdx = stackIdx - 1
		
		local conNodes = connectedNodes[node] or {}
		
		for i = 1, #conNodes do
			local nid = conNodes[i][1]
			
			if not visited[nid] then
				local bid = conNodes[i][2]
				
				if not obj:beamIsBroken(bid) and (obj:getBeamCurLengthRefRatio(bid) < maxBeamLengthRatio) then
					stackIdx = stackIdx + 1
					nodeStack[stackIdx] = nid
					
					visited[nid] = true
				end
			end
		end
	end

	local refClusterID = obj:getNodeCluster(refNode)
	for cid,_ in pairs(v.data.nodes) do
		if not connected[cid] then
			if obj:getNodeCluster(cid) == refClusterID then
				local nodeMass = obj:getNodeMass(cid)
				disconnectedNodes[#disconnectedNodes+1] = {cid, nodeMass*physicsFPS}
			end
		end
	end
	cog:setScaled(1/totalMass)
	
	local rot = quatFromDir(-obj:getDirectionVector(), obj:getDirectionVectorUp())
	M.cogRel = cog:rotated(rot:inversed())
end

local function onInit()
	physicsFPS = obj:getPhysicsFPS() or 2000

	-- For each node, store all other nodes that are directly connected to it
	connectedNodes = {}
	for _, b in pairs(v.data.beams) do
		-- exclude types BEAM_PRESSURED, BEAM_LBEAM, and BEAM_SUPPORT
		if b.beamType ~= 3 and b.beamType ~= 4 and b.beamType ~= 7 then
			if connectedNodes[b.id1] == nil then
				connectedNodes[b.id1] = {}
			end
			if connectedNodes[b.id2] == nil then
				connectedNodes[b.id2] = {}
			end
			table.insert(connectedNodes[b.id1], {b.id2, b.cid})
			table.insert(connectedNodes[b.id2], {b.id1, b.cid})
		end
	end
	
	-- Choose ref node with connected beams as parent node
	local refNodes = v.data.refNodes[0]
	
	local refPos = vec3(v.data.nodes[refNodes.ref].pos)
	local backPos = vec3(v.data.nodes[refNodes.back].pos) - refPos
	local upPos = vec3(v.data.nodes[refNodes.up].pos) - refPos
	local leftPos = vec3(v.data.nodes[refNodes.left].pos) - refPos
	
	local cosAng = leftPos:cosAngle(backPos:cross(upPos))
	
	if cosAng < 0 then
		log('M', 'onInit', "Misaligned refNodes detected in vehicle "..obj:getId().."! This might cause wrong rotations or instability.")
	end
	
	if connectedNodes[refNodes.ref] then
		parentNode = refNodes.ref
	elseif connectedNodes[refNodes.back] then
		parentNode = refNodes.back
	elseif connectedNodes[refNodes.left] then
		parentNode = refNodes.left
	elseif connectedNodes[refNodes.up] then
		parentNode = refNodes.up
	end
	
	if parentNode then
		-- TODO: find less hacky way to get beamBroke events
		local beamBroke = powertrain.beamBroke
		powertrain.beamBroke = function(id, ...)
			local beamType = v.data.beams[id].beamType
			if beamType ~= 3 and beamType ~= 4 and beamType ~= 7 then
				beamsChanged = true
			end

			return beamBroke(id, ...)
		end
		
		findConnectedNodes()
	else
		log('M', 'onInit', "Vehicle has no connections to ref nodes! Using all nodes.")
	    for _, n in pairs(v.data.nodes) do
			nodes[#nodes+1] = {n.cid, obj:getNodeMass(n.cid)*physicsFPS}
	    end
		calcCOG()
	end

	log('M', 'onInit', "velocityVE init, physicsFPS: "..physicsFPS..", parentNode: "..parentNode)
end

local function onReset()
	findConnectedNodes()
end

-- Add velocity to vehicle in m/s
-- How it works: Apply enough force to each node, so it accelerates to the target speed in 1 physics tick.
--               Because all nodes accelerate at the same rate, the vehicle will not get ripped apart
-- NOTE: - very high values can cause instability
local function addForce(nodes, x, y, z, isCounterVel)
	local mainClusterID = obj:getNodeCluster(refNode)
	for i=1, #nodes do
		local node = nodes[i]
		if node then
			if not isCounterVel or obj:getNodeCluster(node[1]) == mainClusterID then
				obj:applyForceVector(node[1], float3(x*node[2], y*node[2], z*node[2]))
			elseif isCounterVel then
				table.remove(disconnectedNodes,i)
			end
		end
	end
end

local function addVelocity(x, y, z)

	local connectedNodeCount = #nodes
	local disconnectedNodeCount = #disconnectedNodes

	if connectedNodeCount < disconnectedNodeCount then
		addForce(nodes, x, y, z)
	else
		obj:applyClusterLinearAngularAccel(refNode,vec3(x, y, z)*physicsFPS, vec3())
		addForce(disconnectedNodes, -x, -y, -z, true)
	end
end

-- Instantly set vehicle velocity in m/s
local function setVelocity(x, y, z)
	local vvel = obj:getVelocity()
	
	addVelocity(x - vvel.x, y - vvel.y, z - vvel.z)
end

-- Add angular velocity to vehicle in rad/s
-- How it works: Calculate node tangential velocity relative to car center of gravity at the desired angular velocity
--               and apply enough force to reach the calculated speed in 1 physics tick.
-- NOTE: - very high values can destroy vehicles (above about 20-30 rad/s for most cars) or cause instability
local function addAngularForce(nodes, x, y, z, pitchAV, rollAV, yawAV, isCounterVel)
	local rot = quatFromDir(-vec3(obj:getDirectionVector()), vec3(obj:getDirectionVectorUp()))
	local cog = M.cogRel:rotated(rot)
	local mainClusterID = obj:getNodeCluster(refNode)
	--print("addAngularVelocity: pitchAV: "..pitchAV..", rollAV: "..rollAV..", yawAV: "..yawAV)
	for i=1, #nodes do
		local node = nodes[i]
		if node then
			local cid = node[1]
			if not isCounterVel or obj:getNodeCluster(cid) == mainClusterID then
				local mul = node[2]
				local nodePos = obj:getNodePosition(cid)
				local posX = nodePos.x - cog.x
				local posY = nodePos.y - cog.y
				local posZ = nodePos.z - cog.z
				
				-- Calculate linear force from torque axis and node position using vector cross product
				-- doing this manually is ~3 times faster than vec3:cross(vec3)
				local forceX = (x + posY * yawAV - posZ * rollAV)*mul
				local forceY = (y + posZ * pitchAV - posX * yawAV)*mul
				local forceZ = (z + posX * rollAV - posY * pitchAV)*mul
				
				obj:applyForceVector(cid, float3(forceX, forceY, forceZ))
			elseif isCounterVel then
				table.remove(disconnectedNodes,i)
			end
		end
	end
end

local function addAngularVelocity(x, y, z, pitchAV, rollAV, yawAV, onlyAngularVelocity, noCounterVelocity)
	local rot = quatFromDir(-vec3(obj:getDirectionVector()), vec3(obj:getDirectionVectorUp()))
	local cog = M.cogRel:rotated(rot)
	local vel = vec3(x, y, z) - cog:cross(vec3(pitchAV, rollAV, yawAV))
	local velMulti = 1

	if onlyAngularVelocity then
		velMulti = 0
	end

	local connectedNodeCount = #nodes
	local disconnectedNodeCount = #disconnectedNodes

	if connectedNodeCount < disconnectedNodeCount then
		addAngularForce(nodes, x, y, z, pitchAV, rollAV, yawAV)

		local mainClusterID = obj:getNodeCluster(refNode)
		for i=1, disconnectedNodeCount do
			local node = disconnectedNodes[i]
			if node then
				if obj:getNodeCluster(node[1]) ~= mainClusterID then
					table.remove(disconnectedNodes,i)
				end
			end
		end
	else
		obj:applyClusterLinearAngularAccel(refNode,vel*physicsFPS*velMulti, -vec3(pitchAV, rollAV, yawAV)*physicsFPS)
		if noCounterVelocity then return end -- used on spawn and reset to wait with the counter velocity for a bit so things like logs on the T-series don't slide off
		addAngularForce(disconnectedNodes, -x, -y, -z, -pitchAV, -rollAV, -yawAV, true)
	end
end

-- Instantly set vehicle angular velocity in rad/s
local function setAngularVelocity(x, y, z, pitchAV, rollAV, yawAV, onlyAngularVelocity, noCounterVelocity)
	local rot = quatFromDir(-vec3(obj:getDirectionVector()), vec3(obj:getDirectionVectorUp()))
	local cog = M.cogRel:rotated(rot)
	
	local rvel = vec3(pitchAV, rollAV, yawAV)
	local vrvel = vec3(obj:getPitchAngularVelocity(), obj:getRollAngularVelocity(), obj:getYawAngularVelocity()):rotated(rot)
	local rvelDiff = rvel - vrvel
	
	local vel = vec3(x, y, z)
	local vvel = vec3(obj:getVelocity()) + cog:cross(vrvel)
	local velDiff = vel - vvel
	
	addAngularVelocity(velDiff.x, velDiff.y, velDiff.z, rvelDiff.x, rvelDiff.y, rvelDiff.z, onlyAngularVelocity, noCounterVelocity)
end

local function updateGFX(dt)
	if beamsChanged or abs(beamstate.damage - lastDamage) >= damageThreshold then
		damageTimer = damageTimer + dt
		
		if damageTimer >= damageDelay then
			if beamsChanged then
				findConnectedNodes()
				beamsChanged = false
			else
				calcCOG()
			end
			
			lastDamage = beamstate.damage
			damageTimer = 0
		end
	else
		damageTimer = 0
	end
	
	
	-- Connected nodes and COG debug
	--[[
	local vehRot = quatFromDir(-obj:getDirectionVector(), obj:getDirectionVectorUp())
	
	for i = 1, #nodes do
		obj.debugDrawProxy:drawNodeSphere(nodes[i][1], 0.03, color(255, 0, 0, 200))
	end
	
	obj.debugDrawProxy:drawSphere(0.3, obj:getPosition()+M.cogRel:rotated(vehRot), color(0, 0, 255, 200))
	--]]
end

-- public interface
M.onInit             = onInit
M.onExtensionLoaded  = onInit
M.onReset            = onReset
M.updateGFX          = updateGFX
M.addVelocity        = addVelocity
M.setVelocity        = setVelocity
M.addAngularVelocity = addAngularVelocity
M.setAngularVelocity = setAngularVelocity

return M
