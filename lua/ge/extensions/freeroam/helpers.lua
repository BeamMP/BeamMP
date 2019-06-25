print("BeamNG-MP helpers loaded.")
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

local function togglePause()
  bullettime.togglePause()
end

local function getPause()
  bullettime.getPause()
end

local function setPauseState(paused)
  bullettime.pause(paused)
end

M.split = split
M.dump = dump
M.togglePause = togglePause
M.getPause = getPause
M.setPauseState = setPauseState

return M
