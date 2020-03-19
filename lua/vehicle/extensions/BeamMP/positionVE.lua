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
	
	if (distance < 0.10) then -- When vehicle doesn't move
		if timer < 50 then -- Send 50 times less packets
			timer = timer + 1
			return
		else
			timer = 0
		end
	end

	local tempTable = {}
	local pos = obj:getPosition()
	local rot = obj:getRotation()	
	tempTable[1] = pos.x
	tempTable[2] = pos.y
	tempTable[3] = pos.z
	tempTable[4] = rot.x
	tempTable[5] = rot.y
	tempTable[6] = rot.z
	tempTable[7] = rot.w	
	obj:queueGameEngineLua("positionGE.sendVehiclePosRot(\'"..jsonEncode(tempTable).."\', \'"..obj:getID().."\')") -- Send it
end



M.getVehicleRotation = getVehicleRotation



return M
