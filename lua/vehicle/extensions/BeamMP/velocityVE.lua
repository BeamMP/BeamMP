-- Setting lateral and angular velocity of vehicles
-- Author: stefan750

local M = {}

local connectedBeams = {}
local isConnectedNode = {}
local beamsChanged = false
local physicsFPS = 0

-- Recursively find nodes connected to parent node
local function findConnectedNodesRecursive(parentID)
	if isConnectedNode[parentID] then return end

	isConnectedNode[parentID] = true

	-- Apparently normal for loop is twice as fast as ipairs()
	local beams = connectedBeams[parentID] or {}

	if #beams == 0 then
	    print("No beams connected to node! Using all nodes.")
	    for _, n in pairs(v.data.nodes) do
	        isConnectedNode[n.cid] = true
	    end
	end

	for i=1, #beams do
		local bid = beams[i]
		if not obj:beamIsBroken(bid) then
			local b = v.data.beams[bid]

			if parentID == b.id1 then
				findConnectedNodesRecursive(b.id2)
			elseif parentID == b.id2 then
				findConnectedNodesRecursive(b.id1)
			end
		end
	end
end

local function findConnectedNodes()
	isConnectedNode = {}
	findConnectedNodesRecursive(v.data.refNodes[0].ref)

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

	-- TODO: find less hacky way to get beamBroke events
	local beamBroke = powertrain.beamBroke
	powertrain.beamBroke = function(id, ...)
		beamsChanged = true

		return beamBroke(id, ...)
	end

	findConnectedNodes()

	print("velocityVE init, physicsFPS: "..physicsFPS)
end

-- Add velocity to vehicle in m/s
-- How it works: Apply enough force to each node, so it accelerates to the target speed in 1 physics tick.
--               Because all nodes accelerate at the same rate, the vehicle will not get ripped apart
-- NOTE: - very high values can cause instability
local function addVelocity(x, y, z)
	if beamsChanged then
		findConnectedNodes()
	end

	local vel = vec3(x, y, z)
	--print("addVelocity: x: "..x..", y: "..y..", z: "..z)
	for nid, connected in pairs(isConnectedNode) do
		local nodeWeight = obj:getNodeMass(nid)
		local forceVec = vel*nodeWeight*physicsFPS -- calculate force for desired acceleration

		obj:applyForceVector(nid, forceVec:toFloat3())
	end
end

-- Instantly set vehicle velocity in m/s
local function setVelocity(x, y, z)
	local vel = vec3(x, y, z)
	local vvel = vec3(obj:getVelocity())
	local velDiff = vel - vvel

	addVelocity(velDiff.x, velDiff.y, velDiff.z)
end

-- pos yaw makes it go to the right
-- pos roll makes it roll from left to right
-- pos pitch makes the nose go up

-- Add angular velocity to vehicle in rad/s
-- How it works: Calculate node tangential velocity relative to car center point at the desired angular velocity
--               and apply enough force to reach the calculated speed in 1 physics tick.
-- NOTE: - will rotate around vehicle position, not center of gravity (calculated COG moves with detached parts)
--         so can cause slight linear movement in some cases
--       - very high values can destroy vehicles (above about 20-30 rad/s for most cars) or cause instability
local function addAngularVelocity(x, y, z, pitchAV, rollAV, yawAV)
	if beamsChanged then
		findConnectedNodes()
	end

	local vel = vec3(x, y, z)
	local toWorldAxisQuat = quat(obj:getRotation())
	local av = vec3(pitchAV, rollAV, yawAV):rotated(toWorldAxisQuat)
	--print("addAngularVelocity: pitchAV: "..pitchAV..", rollAV: "..rollAV..", yawAV: "..yawAV)
	for nid, connected in pairs(isConnectedNode) do
		local nodeWeight = obj:getNodeMass(nid)
		local nodePos = vec3(obj:getNodePosition(nid))
		local targetAcc = vel + nodePos:cross(av)
		local forceVec = targetAcc*nodeWeight*physicsFPS -- calculate force for desired acceleration

		obj:applyForceVector(nid, forceVec:toFloat3())
	end
end

-- Instantly set vehicle angular velocity in rad/s
local function setAngularVelocity(x, y, z, pitchAV, rollAV, yawAV)
	local vel = vec3(x, y, z)
	local vvel = vec3(obj:getVelocity())
	local velDiff = vel - vvel

	local pitchDiff = pitchAV - obj:getPitchAngularVelocity()
	local rollDiff = rollAV - obj:getRollAngularVelocity()
	local yawDiff = yawAV - obj:getYawAngularVelocity()

	addAngularVelocity(velDiff.x, velDiff.y, velDiff.z, pitchDiff, rollDiff, yawDiff)
end

v.mpVehicleType = "local"
local function setVehicleType(x)
  v.mpVehicleType = x
end

-- public interface
M.onInit             = onInit
M.onExtensionLoaded  = onInit
M.onReset            = findConnectedNodes
M.addVelocity        = addVelocity
M.setVelocity        = setVelocity
M.addAngularVelocity = addAngularVelocity
M.setAngularVelocity = setAngularVelocity
M.setVehicleType     = setVehicleType

return M
