-- Setting lateral and angular velocity of vehicles
-- Author: stefan750

local M = {}

-- Set vehicle velocity in m/s
-- How it works: Apply enough force to each node, so it accelerates to the target speed in 1 physics tick.
--               Because all nodes accelerate at the same rate, the vehicle will not get ripped apart
-- NOTE: - also affects parts that are detached from the car
--       - very high values can cause instability
local function setVelocity(vel)
	-- could also use velocity difference for each node, but that would stop all moving parts like wheels
	local velDiff = vel - vec3(obj:getVelocity())

	for _, node in pairs(v.data.nodes) do
		local nodeWeight = obj:getNodeMass(node.cid)
		local forceVec = velDiff*nodeWeight*2000 -- calculate force for desired acceleration

		obj:applyForceVector(node.cid, forceVec:toFloat3())
	end
end

-- Set vehicle angular velocity in rad/s
-- How it works: Calculate node tangential velocity relative to car center point at the desired angular velocity
--               and apply enough force to reach the calculated speed in 1 physics tick.
-- NOTE: - will rotate around vehicle position, not center of gravity (calculated COG moves with detached parts)
--         so can cause slight linear movement in some cases
--       - also affects parts that are detached from the car
--       - very high values can destroy vehicles (above about 20-30 rad/s for most cars) or cause instability
--       - can become inaccurate if vehicles are very deformed
local function setAngularVelocity(pitchAV, rollAV, yawAV)
	local toWorldAxisQuat = quat(obj:getRotation())

	local pitchDiff = pitchAV - obj:getPitchAngularVelocity()
	local rollDiff = rollAV - obj:getRollAngularVelocity()
	local yawDiff = yawAV - obj:getYawAngularVelocity()

	for _, node in pairs(v.data.nodes) do
		local nodeWeight = obj:getNodeMass(node.cid)
		local nodePos = vec3(node.pos)
		local localTargetAcc = nodePos:cross(vec3(pitchDiff, rollDiff, yawDiff)) -- not sure why, but this works well
		local targetAcc = localTargetAcc:rotated(toWorldAxisQuat) -- rotate force vector to world axis
		local forceVec = targetAcc*nodeWeight*2000 -- calculate force for desired acceleration

		obj:applyForceVector(node.cid, forceVec:toFloat3())
	end
end

-- public interface
M.setVelocity = setVelocity
M.setAngularVelocity = setAngularVelocity

return M
