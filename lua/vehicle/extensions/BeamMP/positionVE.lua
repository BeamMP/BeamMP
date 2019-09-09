--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}



local function getVehicleRotation()
	local tempTable = {}
	local pos = obj:getPosition()
	local rot = obj:getRotation()	
	--tempTable[1] = obj:getID()
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