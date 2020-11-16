--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================


local M = {}
local lastCouplerState = false
local wantedCouplerState = false
local toggled = false

local function updateGFX(dt)
  if wantedCouplerState ~= toggled then
    print("Toggling couplers")
    if toggled then
        toggled = false
    else
        toggled = true
    end
    beamstate.toggleCouplers()
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

local function onReset()
    toggled = false
    wantedCouplerState = false
end

M.onReset            = onReset
M.toggleCouplerState = toggleCouplerState
M.updateGFX			     = updateGFX

return M
