print("[BeamNG-MP] | Helper Functions loaded.")
require('bullettime')
local M = {}

local function split(inputstr, sep)
  --print()
  sep = sep or '%s'
  --print('Attempting to Split: '..inputstr)
  --print('Where there is a '..sep)
  local t = {}
  for field, s in string.gmatch(inputstr, "([^"..sep.."]*)("..sep.."?)") do
    table.insert(t, field)
    if s == "" then
      --print(dump(t))
      return t
    end
  end
end

local function dump(o)
  if type(o) == 'table' then
    local s = '{ '
    for k,v in pairs(o) do
      if type(k) ~= 'number' then k = '"'..k..'"' end
      s = s .. '['..k..'] = ' .. dump(v) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end

local charset = {}  do -- [0-9a-zA-Z]
  for c = 48, 57  do table.insert(charset, string.char(c)) end
  for c = 65, 90  do table.insert(charset, string.char(c)) end
  for c = 97, 122 do table.insert(charset, string.char(c)) end
end

local function randomString(length)
  if not length or length <= 0 then return '' end
  math.randomseed(os.clock()^5)
  return randomString(length - 1) .. charset[math.random(1, #charset)]
end

local function togglePause()
  bullettime.togglePause()
end

local function getPause()
  bullettime.getPause()
end

local function setPauseState(paused)
  bullettime.pause(paused)
end

local function GetDistanceBetweenCoords(x1, y1, z1, x2, y2, z2, useZ)
  local x3 = 0
  local y3 = 0
  local z3 = 0
  x3 = x1 - x2
  y3 = y1 - y2
  if not useZ then
    z3 = z1 - z2
  end
  if x3 < 0 then
    x3 = x3*-1
  elseif y3 < 0 then
    y3 = y3*-1
  elseif z3 < 0 then
    z3 = z3*-1
  end
  local dist = x3 + y3 + z3
  return dist
end

local function deleteAllVehicles()
  if be:getObjectCount() == 0 then
    return
  end -- If no vehicle do nothing
  commands.setFreeCamera()
  for i = 0, be:getObjectCount() do -- For each vehicle
    local veh = be:getObject(0) --  Get vehicle
    if veh then -- For loop always return one empty vehicle ?
      --onVehicleDestroyedAllowed = false
      veh:delete()
    end
  end
end

local codes = {
  ["game"] = {
    "PING",
    "HOLA",
    "PONG",
    "PING",
    "CHAT",
    "MAPC",
    "MAPS",
    "JOIN",
    "PLST"
  },
  ["update"] = {
    "U-VI",
    "U-VD",
    "U-VR",
    "U-VS",
    "U-VC",
    "C-VS"
  }
}

local function CheckGameCode(c)
  for _,v in pairs(codes.game) do
    if v == c then
      return true
    end
  end
  return false
end

local function CheckUpdateCode(c)
  for _,v in pairs(codes.update) do
    if v == c then
      return true
    end
  end
  return false
end

local function LengthSplit (text, chunkSize)
  local s = {}
  for i=1, #text, chunkSize do
    s[#s+1] = text:sub(i,i+chunkSize - 1)
  end
  return s
end

M.split = split
M.dump = dump
M.randomString = randomString
M.togglePause = togglePause
M.getPause = getPause
M.setPauseState = setPauseState
M.GetDistanceBetweenCoords = GetDistanceBetweenCoords
M.deleteAllVehicles = deleteAllVehicles
M.CheckGameCode = CheckGameCode
M.CheckUpdateCode = CheckUpdateCode
M.LengthSplit = LengthSplit

return M
