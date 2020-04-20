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
	--local rot = obj:getRotation()
	local rot = {}
	rot.x = obj:getPitchAngularVelocity()
	rot.y = obj:getRollAngularVelocity()
	rot.z = obj:getYawAngularVelocity()
	tempTable[1] = pos.x
	tempTable[2] = pos.y
	tempTable[3] = pos.z
	tempTable[4] = vel.x
	tempTable[5] = vel.y
	tempTable[6] = vel.z
	tempTable[7] = rot.x
	tempTable[8] = rot.y
	tempTable[9] = rot.z
	print(dump(tempTable))
	obj:queueGameEngineLua("positionGE.sendVehiclePosRot(\'"..jsonEncode(tempTable).."\', \'"..obj:getID().."\')") -- Send it
end



M.getVehicleRotation = getVehicleRotation



return M
