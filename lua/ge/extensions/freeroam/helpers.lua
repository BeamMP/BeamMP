print("BeamNG-MP helpers loaded.")
local M = {}

local function split(inputstr, sep)
  --print()
  sep = sep or '%s'
  print('Attempting to Split: '..inputstr)
  print('Where there is a '..sep)
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

local function GetMap()
  print(map.getMap())
  return map.getMap()
end

local function GetPlayer()
  player.obj = be:getPlayerVehicle(0)

end

M.split = split
M.dump = dump

return M
