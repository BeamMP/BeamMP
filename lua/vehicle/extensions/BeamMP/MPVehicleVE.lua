--====================================================================================
-- All work by 20dka.
-- You have no permission to edit, redistrobute or upload. Contact BeamMP for more info!
--====================================================================================

local M = {}

local callOnPhysUpdate = {}
v.mpVehicleType = "L"

local origPhysUpdateFunc = nop


local function setVehicleType(x)
  v.mpVehicleType = x
end

local function AddPhysUpdateHandler(n, f)
	print("add phys for func "..n)
	dump(f)
	callOnPhysUpdate[n] = f
end

local function DelPhysUpdateHandler(n)
	callOnPhysUpdate[n] = nil
end


local function update(dtSim)
	origPhysUpdateFunc(dtSim)
	--print("dtsim")
	for n,f in pairs(callOnPhysUpdate) do
		--print(n)
		f(dtSim)
	end
end

local function updateGFX(dtReal)
	if motionSim.update ~= update then -- hook onto the unused phys update function
		print("its not our func, doing funky business")
		origPhysUpdateFunc = motionSim.update
		motionSim.update = update
	end
	
	if v.mpVehicleType == 'R' and hydros.enableFFB then --disable ffb if it got enabled by a reset
		hydros.enableFFB = false 
	end
end




M.setVehicleType       = setVehicleType
M.AddPhysUpdateHandler = AddPhysUpdateHandler
M.DelPhysUpdateHandler = DelPhysUpdateHandler


M.updateGFX = updateGFX

return M
