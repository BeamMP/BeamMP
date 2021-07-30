--====================================================================================
-- All work by stefan750, Titch2000, Anonymous.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================
-- Setting lateral and angular velocity of vehicles
--====================================================================================

local M = {}

local maxBeamLengthRatio = 2 -- If a beam becomes longer than its original length by this factor, it will be treated as broken

local connectedBeams = {}
local isConnectedNode = {}
local nodes = {}
local parentNode = nil
local beamsChanged = false
local physicsFPS = 0
M.cogRel = vec3(0,0,0)

-- Calculate center of gravity from connected nodes
local function calcCOG()
	local rot = quatFromDir(-vec3(obj:getDirectionVector()), vec3(obj:getDirectionVectorUp()))
	
	local totalMass = 0
	local cog = vec3(0,0,0)
	for nid, connected in pairs(isConnectedNode) do
		local nodeWeight = obj:getNodeMass(nid)
		local nodePos = vec3(obj:getNodePosition(nid))
		
		cog = cog + nodePos*nodeWeight
		
		totalMass = totalMass + nodeWeight
	end
	cog = cog/totalMass
	
	M.cogRel = vec3(cog:rotated(rot:inversed()))
end

-- Recursively find nodes connected to parent node
local function findConnectedNodesRecursive(parentID)
	if isConnectedNode[parentID] then return end

	isConnectedNode[parentID] = true
	nodes[#nodes+1] = {parentID, obj:getNodeMass(parentID)*physicsFPS}

	-- Apparently normal for loop is twice as fast as ipairs()
	local beams = connectedBeams[parentID] or {}

	for i=1, #beams do
		local bid = beams[i]
		if not obj:beamIsBroken(bid) and (obj:getBeamCurLengthRefRatio(bid) < maxBeamLengthRatio) then
			local b = v.data.beams[bid]

			if parentID == b.id1 then
				findConnectedNodesRecursive(b.id2)
			elseif parentID == b.id2 then
				findConnectedNodesRecursive(b.id1)
			end
		end
	end
end

-- Trigger finding of connected nodes
local function findConnectedNodes()
	isConnectedNode = {}
	nodes = {}
	findConnectedNodesRecursive(parentNode)
	
	calcCOG()
	
	beamsChanged = false
end

local function onInit()
	physicsFPS = obj:getPhysicsFPS() or 2000

	-- Store connected beams for each node
	connectedBeams = {}
	for _, b in pairs(v.data.beams) do
		-- exclude types BEAM_PRESSURED, BEAM_LBEAM, and BEAM_SUPPORT
		if b.beamType ~= 3 and b.beamType ~= 4 and b.beamType ~= 7 then
			if connectedBeams[b.id1] == nil then
				connectedBeams[b.id1] = {}
			end
			if connectedBeams[b.id2] == nil then
				connectedBeams[b.id2] = {}
			end
			table.insert(connectedBeams[b.id1], b.cid)
			table.insert(connectedBeams[b.id2], b.cid)
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
		print("Misaligned refNodes detected in vehicle "..obj:getId().."! This might cause wrong rotations or instability.")
	end
	
	if connectedBeams[refNodes.ref] then
		parentNode = refNodes.ref
	elseif connectedBeams[refNodes.back] then
		parentNode = refNodes.back
	elseif connectedBeams[refNodes.left] then
		parentNode = refNodes.left
	elseif connectedBeams[refNodes.up] then
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
		print("Vehicle has no connections to ref nodes! Using all nodes.")
	    for _, n in pairs(v.data.nodes) do
	        isConnectedNode[n.cid] = true
			nodes[#nodes+1] = {n.cid, obj:getNodeMass(n.cid)*physicsFPS}
	    end
		calcCOG()
	end

	print("velocityVE init, physicsFPS: "..physicsFPS..", parentNode: "..parentNode)
end

local function onReset()
	if parentNode then findConnectedNodes() end
end

-- Add velocity to vehicle in m/s
-- How it works: Apply enough force to each node, so it accelerates to the target speed in 1 physics tick.
--               Because all nodes accelerate at the same rate, the vehicle will not get ripped apart
-- NOTE: - very high values can cause instability
local function addVelocity(x, y, z)
	if beamsChanged then
		findConnectedNodes()
	end

	for i=1, #nodes do
		local node = nodes[i]
		
		obj:applyForceVector(node[1], float3(x*node[2], y*node[2], z*node[2]))
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
local function addAngularVelocity(x, y, z, pitchAV, rollAV, yawAV)
	if beamsChanged then
		findConnectedNodes()
	end
	
	local rot = quatFromDir(-vec3(obj:getDirectionVector()), vec3(obj:getDirectionVectorUp()))
	local cog = M.cogRel:rotated(rot)
	
	--print("addAngularVelocity: pitchAV: "..pitchAV..", rollAV: "..rollAV..", yawAV: "..yawAV)
	for i=1, #nodes do
		local node = nodes[i]
		local cid = node[1]
		local mul = node[2]
		local nodePos = obj:getNodePosition(cid)
		local posX = nodePos.x - cog.x
		local posY = nodePos.y - cog.y
		local posZ = nodePos.z - cog.z
		
		-- Calculate linear force from torque axis and node position using vector cross product
		local forceX = (x + posY * yawAV - posZ * rollAV)*mul
		local forceY = (y + posZ * pitchAV - posX * yawAV)*mul
		local forceZ = (z + posX * rollAV - posY * pitchAV)*mul
		
		obj:applyForceVector(cid, float3(forceX, forceY, forceZ))
	end
end

-- Instantly set vehicle angular velocity in rad/s
local function setAngularVelocity(x, y, z, pitchAV, rollAV, yawAV)
	local rot = quatFromDir(-vec3(obj:getDirectionVector()), vec3(obj:getDirectionVectorUp()))
	local cog = M.cogRel:rotated(rot)
	
	local rvel = vec3(pitchAV, rollAV, yawAV)
	local vrvel = vec3(obj:getPitchAngularVelocity(), obj:getRollAngularVelocity(), obj:getYawAngularVelocity()):rotated(rot)
	local rvelDiff = rvel - vrvel
	
	local vel = vec3(x, y, z)
	local vvel = vec3(obj:getVelocity()) + cog:cross(vrvel)
	local velDiff = vel - vvel
	
	addAngularVelocity(velDiff.x, velDiff.y, velDiff.z, rvelDiff.x, rvelDiff.y, rvelDiff.z)
end

-- public interface
M.onInit             = onInit
M.onExtensionLoaded  = onInit
M.onReset            = onReset
M.addVelocity        = addVelocity
M.setVelocity        = setVelocity
M.addAngularVelocity = addAngularVelocity
M.setAngularVelocity = setAngularVelocity

return M
