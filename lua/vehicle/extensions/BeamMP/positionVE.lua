--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}



-- ============= VARIABLES =============
local timer = 0
-- ============= VARIABLES =============

local function updateGFX(dt)
	timer = timer + dt
end

local function getVehicleRotation()
	local tempTable = {}
	local pos = obj:getPosition()
	local vel = obj:getVelocity()
	local rot = obj:getRotation()
	local dirVector = obj:getDirectionVector()
	local dirVectorUp = obj:getDirectionVectorUp()
	local roll = dirVectorUp.x * -dirVector.y + dirVectorUp.y * dirVector.x
	local pitch = dirVector.z
	local yaw = dirVector.x
	local rvel = {}
	rvel.x = obj:getPitchAngularVelocity()
	rvel.y = obj:getRollAngularVelocity()
	rvel.z = obj:getYawAngularVelocity()
	tempTable['pos'] = {}
	tempTable['pos'].x = tonumber(pos.x)
	tempTable['pos'].y = tonumber(pos.y)
	tempTable['pos'].z = tonumber(pos.z)
	tempTable['vel'] = {}
	tempTable['vel'].x = tonumber(vel.x)
	tempTable['vel'].y = tonumber(vel.y)
	tempTable['vel'].z = tonumber(vel.z)
	tempTable['ang'] = {}
	tempTable['ang'].x = tonumber(rot.x)
	tempTable['ang'].y = tonumber(rot.y)
	tempTable['ang'].z = tonumber(rot.z)
	tempTable['ang'].w = tonumber(rot.w)
	tempTable['rvel'] = {}
	tempTable['rvel'].x = tonumber(rvel.x)
	tempTable['rvel'].y = tonumber(rvel.y)
	tempTable['rvel'].z = tonumber(rvel.z)
	tempTable['tim'] = timer
	--print(dump(tempTable))
	--print("tempTable ^ ")
	obj:queueGameEngineLua("positionGE.sendVehiclePosRot(\'"..jsonEncode(tempTable).."\', \'"..obj:getID().."\')") -- Send it
end


M.updateGFX = updateGFX
M.getVehicleRotation = getVehicleRotation



return M
