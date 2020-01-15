print("[BeamNG-MP] | Steam Rich Presence loaded.")
--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local M = {}

-- How to use: print(extensions.util_richPresence.set('yolo'))
M.state = { levelName = "", vehicleName = "" }

local function msgFormat()
  local msg = "Playing "

  if Network.GetTCPStatus() > 0 then
    msg = msg.."Multiplayer "
  else
    if extensions.core_gamestate.state.state then
      msg = msg.. tostring((core_gamestate.state.state:gsub("^%l", string.upper)) .. " ")
    end
  end

  if M.state.levelName ~= "" then
    msg = msg .. "on " .. M.state.levelName .. " "
  end

  if M.state.vehicleName ~= "" then
    msg = msg .. "with " .. M.state.vehicleName
  end

  M.set(msg)
end

local function onVehicleSwitched(oldId, newId, player)
  local currentVehicle = core_vehicles.getCurrentVehicleDetails()
  if currentVehicle.model.Name then
    if currentVehicle.model.Brand then
      M.state.vehicleName = currentVehicle.model.Brand .. " " .. currentVehicle.model.Name
    else
      M.state.vehicleName = currentVehicle.model.Name
    end
  end
  msgFormat()
end

local function onClientPostStartMission(mission)
  local currentLevel = string.match(mission, "/?levels/(.-)/") or ''
  if currentLevel ~= "" then
    M.state.levelName = currentLevel:gsub("^%l", string.upper)
    M.state.levelName = M.state.levelName:gsub("_", " ")
    M.state.levelName = string.gsub(" "..M.state.levelName, "%W%l", string.upper):sub(2)
    msgFormat()
  end
end

-- returns true on success
local function set(v)
  print("Setting/Updating Steam Rich Presence!")
  Steam.setRichPresence('status', 'BeamNG.drive - Multiplayer')
  return Steam.setRichPresence('b', tostring(v))
end

M.set = set
M.onVehicleSwitched = onVehicleSwitched
M.onClientPostStartMission = onClientPostStartMission

return M
