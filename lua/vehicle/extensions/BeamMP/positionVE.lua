--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}



-- ============= VARIABLES =============
local timer = 0
local lastPos = vec3(0,0,0)
-- ============= VARIABLES =============



local function getVehicleRotation()
	local pos = obj:getPosition()
	local distance = nodesVE.distance(pos.x, pos.y, pos.z, lastPos.x, lastPos.y, lastPos.z)
	lastPos = pos

	if (distance < 0.02) then -- When vehicle doesn't move
		if timer < 40 then -- Send 40 times less packets
			timer = timer + 1
			return
		else
			timer = 0
		end
	end

	local tempTable = {}
	local pos = obj:getPosition()
	local vel = obj:getVelocity()
	local rot = obj:getRotation()
	local dirVector = obj:getDirectionVector()
	local dirVectorUp = obj:getDirectionVectorUp()
	local roll = dirVectorUp.x * -dirVector.y + dirVectorUp.y * dirVector.x
	local pitch = dirVector.z
	local yaw = dirVector.x
	--local rot = {}
	--rot.x = obj:getPitchAngularVelocity()
	--rot.y = obj:getRollAngularVelocity()
	--rot.z = obj:getYawAngularVelocity()
	tempTable['pos'] = {}
	tempTable['pos'].x = tonumber(pos.x)
	tempTable['pos'].y = tonumber(pos.y)
	tempTable['pos'].z = tonumber(pos.z)
	tempTable['vel'] = {}
	tempTable['vel'].x = tonumber(vel.x)
	tempTable['vel'].y = tonumber(vel.y)
	tempTable['vel'].z = tonumber(vel.z)
	tempTable['ang'] = {}
	tempTable['ang'].x = tonumber(pitch)
	tempTable['ang'].y = tonumber(roll)
	tempTable['ang'].z = tonumber(yaw)
	tempTable['ang'].w = tonumber(rot.w)
	--print(dump(tempTable))
	--print("tempTable ^ ")
	obj:queueGameEngineLua("positionGE.sendVehiclePosRot(\'"..jsonEncode(tempTable).."\', \'"..obj:getID().."\')") -- Send it
end



M.getVehicleRotation = getVehicleRotation



return M
