print("BEAMNG-MP Loaded")

--[[
Firstly we need to get all statistics about the car, be this gearbox info, turn signals so on so forth.
]]
local myGearManual = (electrics.values.gear_M or 0)
local myGearAuto = (electrics.values.gear_A or 0)

function UpdateVehPos(data)
  local vehObj = be:getObjectByID(data.subjectID)
  local vehiclePos = vehObj:getPosition()
  vehiclePos.y = vehiclePos.y + 50
  vehObj:setPosition(vehiclePos)
end
