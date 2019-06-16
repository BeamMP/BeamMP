local M = {}

print("mainLevel.lua")

return M


local function onInit()
  print('[onInit] > Vehicle created!')
end

local function updateGFX(dt)
  print('[updateGFX] > New DT!')
end
