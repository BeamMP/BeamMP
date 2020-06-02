-- Setting lateral and angular velocity of vehicles
-- Author: stefan750

local M = {}

-- Add velocity to vehicle in m/s
-- How it works: Apply enough force to each node, so it accelerates to the target speed in 1 physics tick.
--               Because all nodes accelerate at the same rate, the vehicle will not get ripped apart
-- NOTE: - also affects parts that are detached from the car
--       - very high values can cause instability
local function addVelocity(x, y, z)
	local vel = vec3(x, y, z)
	--print("addVelocity: x: "..x..", y: "..y..", z: "..z)
	for _, node in pairs(v.data.nodes) do
		local nodeWeight = obj:getNodeMass(node.cid)
		local forceVec = vel*nodeWeight*2000 -- calculate force for desired acceleration
		
		obj:applyForceVector(node.cid, forceVec:toFloat3())
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

--pitch is pos or growing when the nose is going up
--roll is decreasing from left to right
--yaw goes negative from left to right

-- Add angular velocity to vehicle in rad/s
-- How it works: Calculate node tangential velocity relative to car center point at the desired angular velocity
--               and apply enough force to reach the calculated speed in 1 physics tick.
-- NOTE: - will rotate around vehicle position, not center of gravity (calculated COG moves with detached parts)
--         so can cause slight linear movement in some cases
--       - also affects parts that are detached from the car
--       - very high values can destroy vehicles (above about 20-30 rad/s for most cars) or cause instability
--       - can become inaccurate if vehicles are very deformed
local function addAngularVelocity(pitchAV, rollAV, yawAV)
	local toWorldAxisQuat = quat(obj:getRotation())
	--print("addAngularVelocity: pitchAV: "..pitchAV..", rollAV: "..rollAV..", yawAV: "..yawAV)
	for _, node in pairs(v.data.nodes) do
		local nodeWeight = obj:getNodeMass(node.cid)
		local nodePos = vec3(node.pos)
		local localTargetAcc = nodePos:cross(vec3(pitchAV, rollAV, yawAV)) -- TODO: this way of calculating tangential velocity might be inaccurate for large vehicles
		local targetAcc = localTargetAcc:rotated(toWorldAxisQuat) -- rotate force vector to world axis
		local forceVec = targetAcc*nodeWeight*2000 -- calculate force for desired acceleration
		obj:applyForceVector(node.cid, forceVec:toFloat3())
	end
end

-- Instantly set vehicle angular velocity in rad/s
local function setAngularVelocity(pitchAV, rollAV, yawAV)
	local toWorldAxisQuat = quat(obj:getRotation())
	local pitchDiff = pitchAV - obj:getPitchAngularVelocity()
	local rollDiff = rollAV - obj:getRollAngularVelocity()
	local yawDiff = yawAV - obj:getYawAngularVelocity()
	
	addAngularVelocity(pitchDiff, rollDiff, yawDiff)
end

-- public interface
M.setVelocity = setVelocity
M.setAngularVelocity = setAngularVelocity

return M
