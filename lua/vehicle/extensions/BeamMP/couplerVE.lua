--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================


local M = {}
local lastCouplerState = false
local wantedCouplerState = false
local toggled = false

local function updateGFX(dt)
  --[[local couplerState = beamstate.isCouplerAttached()
--print(couplerState)
  if couplerState ~= lastCouplerState then
    obj:queueGameEngineLua("MPVehicleGE.sendBeamstate(\'"..tostring(couplerState).."\', \'"..obj:getID().."\')")
  end

  if couplerState ~= wantedCouplerState and not toggled then
    beamstate.toggleCouplers()
    toggled = true
  end

  if couplerState == wantedCouplerState and toggled then
    toggled = false
  end]]

  if wantedCouplerState ~= beamstate.autoCouplingActive then
    breamstate.toggleCouplers()
  end
end

local function toggleCouplerState(state)
  print("RECEIVED A COUPLER STATE!!! "..state)
  if state == "true" then
    wantedCouplerState = true
  else
    wantedCouplerState = false
  end
end


M.toggleCouplerState = toggleCouplerState
M.updateGFX			     = updateGFX

return M
