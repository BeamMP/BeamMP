-- Setting lateral and angular velocity of vehicles
-- Author: stefan750

local M = {}

local localNodes = {}

local isMine = 1
local velocityForceMultiplyer = 1000 -- was 2000
local angularForceMultiplyer = 650

local useOldSystem = false

local function setVelocityMultiplyer(x)
  velocityForceMultiplyer = x
end

local function setAngularMultiplyer(x)
  angularForceMultiplyer = x
end

local function setUseOldSys(x)
  useOldSystem = x
end

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

local function valid(partName)
  local isValid = true
  if partName == nil then
    return false
  end
  local po = partName:lower()
  if string.find(po, "driveshaft") or string.find(po,"coilover") or string.find(po,"suspension") or string.find(po,"steering") or  string.find(po,"swaybar") or  string.find(po,"brake") or string.find(po,"spring") or string.find(po,"wheel") or string.find(po,"luggage") then
    isValid = false end
  return isValid
end

local function isMainBody(partName)
  local isValid = false
  if partName == nil then
    return false
  end
  local po = partName:lower()
  if string.find(po, "chassis") or string.find(po, "body") or string.find(po, "caravan_axle") or po == "flatbed" then
    isValid = true end
  return isValid
end

if useOldSystem then
  localNodes = v.data.nodes
else
  local weight = 0
  for _, node in pairs(v.data.nodes) do
    if node.wheelID == nil and valid(node.partOrigin) and isMainBody(node.partOrigin) then -- THis stops the application to wheels?????
      table.insert(localNodes, node)
      weight = weight + node.nodeWeight
    end
  end
  print("Weight: "..weight)
  angularForceMultiplyer = ((#v.data.nodes / #localNodes) /2)*1000
  velocityForceMultiplyer = angularForceMultiplyer
  angularForceMultiplyer = (weight * 10)/2
  print("Node Count for Application: "..#localNodes.." of "..#v.data.nodes.." Setting 'angularForceMultiplyer' to "..angularForceMultiplyer)
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


	for _, node in pairs(localNodes) do
    if (node.wheelID == nil and valid(node.partOrigin) and isMainBody(node.partOrigin)) or useOldSystem then -- THis stops the application to wheels?????
  		local nodeWeight = obj:getNodeMass(node.cid)
  		local forceVec = velDiff*nodeWeight*velocityForceMultiplyer -- calculate force for desired acceleration
  		--print(forceVec)
  		--print("Applying Force: ^")
  		obj:applyForceVector(node.cid, forceVec:toFloat3())
    end
	end
end

-- pos yaw makes it go to the right
-- pos roll makes it roll from left to right
-- pos pitch makes the nose go up


--pitch is pos or growing when the nose is going up
--roll is decreasing from left to right
--yaw goes negative from left to right

local function setIsMine(x)
	isMine = x
  v['isMyMpVeh'] = x
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
	--TODO: is this still needed?
	if isMine ~= 0 then return end

	local toWorldAxisQuat = quat(obj:getRotation())
	local pitchDiff = pitchAV - obj:getPitchAngularVelocity()
	local rollDiff = rollAV - obj:getRollAngularVelocity()
	local yawDiff = yawAV - obj:getYawAngularVelocity()
	--print("pitchDiff: "..pitchDiff..", rollDiff: "..rollDiff..", yawDiff: "..yawDiff)

	for _, node in pairs(localNodes) do
    if (node.wheelID == nil and valid(node.partOrigin) and isMainBody(node.partOrigin)) or useOldSystem then -- THis stops the application to wheels?????
  		local nodeWeight = obj:getNodeMass(node.cid)
  		local nodePos = vec3(node.pos)
  		local localTargetAcc = nodePos:cross(vec3(pitchDiff, rollDiff, yawDiff)) -- not sure why, but this works well
  		local targetAcc = localTargetAcc:rotated(toWorldAxisQuat) -- rotate force vector to world axis
  		local forceVec = targetAcc*nodeWeight*angularForceMultiplyer -- calculate force for desired acceleration
  		obj:applyForceVector(node.cid, forceVec:toFloat3())
    end
	end
end
print("New Version Loaded v3.5")

-- public interface
M.setVelocity = setVelocity
M.setAngularVelocity = setAngularVelocity
M.setIsMine = setIsMine

M.setVelocityMultiplyer = setVelocityMultiplyer
M.setAngularMultiplyer = setAngularMultiplyer
M.setUseOldSys = setUseOldSys

return M
