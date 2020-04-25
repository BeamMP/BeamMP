-- Setting lateral and angular velocity of vehicles
-- Author: stefan750

local M = {}

local RemoteYaw = 0
local RemotePitch = 0
local RemoteRoll = 0
local RemoteRotation = quat(0, 0, 0, 0)
local PitchApply = 0
local RollApply = 0
local YawApply = 0
local isMine = 1
local AdjustmentMultiplyer = 10

local function typeof(var)
    local _type = type(var);
    if(_type ~= "table" and _type ~= "userdata") then
        return _type;
    end
    local _meta = getmetatable(var);
    if(_meta ~= nil and _meta._NAME ~= nil) then
        return _meta._NAME;
    else
        return _type;
    end
end

-- Set vehicle velocity in m/s
-- How it works: Apply enough force to each node, so it accelerates to the target speed in 1 physics tick.
--               Because all nodes accelerate at the same rate, the vehicle will not get ripped apart
-- NOTE: - also affects parts that are detached from the car
--       - very high values can cause instability
local function setVelocity(x, y, z)
	-- could also use velocity difference for each node, but that would stop all moving parts like wheels
	local vel = vec3(x, y, z)
	local vvel = vec3(obj:getVelocity())
	local velDiff = vel - vvel
	--print(velDiff)
	--print("velDiff: ^, VEL: {"..x..", "..y..", "..z..",".."}, CVEL: {"..vvel.x..", "..vvel.y..", "..vvel.z..",".."}")

	for _, node in pairs(v.data.nodes) do
		local nodeWeight = obj:getNodeMass(node.cid)
		local forceVec = velDiff*nodeWeight*2000 -- calculate force for desired acceleration
		--print(forceVec)
		--print("Applying Force: ^")
		obj:applyForceVector(node.cid, forceVec:toFloat3())
	end
end

local function ApplyVelocity(pitchDiff, rollDiff, yawDiff)
	--[[if typeof(pitchAV) == "table" then
		print("TABLE - setAV: "..dump(pitchAV))
	else
		print("pitchAV: "..pitchAV..", rollAV: "..rollAV..", yawAV: "..yawAV)
	end]]
	local toWorldAxisQuat = quat(obj:getRotation())
	pitchDiff = pitchDiff - obj:getPitchAngularVelocity()
	rollDiff = rollDiff - obj:getRollAngularVelocity()
	yawDiff = yawDiff - obj:getYawAngularVelocity()
	--print("pitchDiff: "..pitchDiff..", rollDiff: "..rollDiff..", yawDiff: "..yawDiff)
	for _, node in pairs(v.data.nodes) do
		local nodeWeight = obj:getNodeMass(node.cid)
		local nodePos = vec3(node.pos)
		local localTargetAcc = nodePos:cross(vec3(pitchDiff, rollDiff, yawDiff)) -- not sure why, but this works well
		local targetAcc = localTargetAcc:rotated(toWorldAxisQuat) -- rotate force vector to world axis
		local forceVec = targetAcc*nodeWeight*2000 -- calculate force for desired acceleration
		obj:applyForceVector(node.cid, forceVec:toFloat3())
	end

end

-- pos yaw makes it go to the right
-- pos roll makes it roll from left to right
-- pos pitch makes the nose go up


--pitch is pos or growing when the nose is going up
--roll is decreasing from left to right
--yaw goes negative from left to right

local function UGFX()
	if isMine == 0 then
		--[[local dirVector = obj:getDirectionVector()
		local dirVectorUp = obj:getDirectionVectorUp()
		local roll = dirVectorUp.x * -dirVector.y + dirVectorUp.y * dirVector.x
		local pitch = dirVector.z
		local yaw = dirVector.x
		if RemoteYaw ~=0 then
			if RemoteYaw - yaw > 0 then
				YawApply = -(RemoteYaw - yaw)
			else
				YawApply = (RemoteYaw - yaw)
			end
		end
		if RemoteRoll ~=0 then
			if RemoteRoll - roll > 0 then
				RollApply = -(RemoteRoll - roll)
			else
				RollApply = (RemoteRoll - roll)
			end
		end
		if RemotePitch ~=0 then
			if RemotePitch - pitch > 0 then
				PitchApply = (pitch - RemotePitch)
			else
				PitchApply = (pitch - RemotePitch)
			end
		end]]
		local LocalRotation = quat(obj:getRotation())
		if RemoteRotation and LocalRotation then
			local t = RemoteRotation/LocalRotation
			t = t:toEulerYXZ()--*AdjustmentMultiplyer
			ApplyVelocity(t.y, t.z, t.x)
		end
	end
end

local function setIsMine(x)
	isMine = x
end


-- Set vehicle angular velocity in rad/s
-- How it works: Calculate node tangential velocity relative to car center point at the desired angular velocity
--               and apply enough force to reach the calculated speed in 1 physics tick.
-- NOTE: - will rotate around vehicle position, not center of gravity (calculated COG moves with detached parts)
--         so can cause slight linear movement in some cases
--       - also affects parts that are detached from the car
--       - very high values can destroy vehicles (above about 20-30 rad/s for most cars) or cause instability
--       - can become inaccurate if vehicles are very deformed

local function setAngularVelocity(x,y,z,w)--(pitchAV, rollAV, yawAV)
	--RemotePitch = pitchAV
	--RemoteRoll = rollAV
	--RemoteYaw = yawAV
	RemoteRotation = quat(x,y,z,w)
end

-- public interface
M.updateGFX = UGFX
M.setVelocity = setVelocity
M.setAngularVelocity = setAngularVelocity
M.setIsMine = setIsMine

return M
