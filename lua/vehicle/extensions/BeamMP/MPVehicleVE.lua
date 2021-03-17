--====================================================================================
-- All work by 20dka.
-- You have no permission to edit, redistrobute or upload. Contact BeamMP for more info!
--====================================================================================

local M = {}

v.mpVehicleType = "L" -- we assume vehicles are local (they're set to remove once we receive pos data from the server)
local callOnPhysUpdate = {}
local origPhysUpdateFunc = nop





local function setVehicleType(x)
  v.mpVehicleType = x
end

local function AddPhysUpdateHandler(n, f) -- n: name, string used as an ID, f: function
	--print("add phys for func "..n)
	callOnPhysUpdate[n] = f
end

local function DelPhysUpdateHandler(n)
	callOnPhysUpdate[n] = nil
end


local function update(dtSim)
	origPhysUpdateFunc(dtSim)
	for n,f in pairs(callOnPhysUpdate) do
		f(dtSim)
	end
end

local function updateGFX(dtReal)
	if motionSim.update ~= update then -- hook onto the unused phys update function
		print("Adding phys update handler hook")
		origPhysUpdateFunc = motionSim.update
		motionSim.update = update
	end

	if v.mpVehicleType == 'R' and hydros.enableFFB then -- disable ffb if it got enabled by a reset
		hydros.enableFFB = false 
	end
end


M.updateGFX = updateGFX

M.setVehicleType       = setVehicleType
M.AddPhysUpdateHandler = AddPhysUpdateHandler
M.DelPhysUpdateHandler = DelPhysUpdateHandler

return M
