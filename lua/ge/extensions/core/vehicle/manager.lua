-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local jbeamIO = require('jbeam/io')

local vehicles = {}

local materialsCache = {}

local function loadVehicleMaterialsDirectory(path)
  if materialsCache[path] then return end
  local files = FS:findFiles(path, '*materials.json\t*.cs', -1, true, false)
  for _, filename in ipairs(files) do
    if filename:find('.json') then
      loadJsonMaterialsFile(filename)
    else
      TorqueScript.exec(filename)
    end
  end
  materialsCache[path] = true
end

local function onClientEndMission()
  -- invalidate all materials
  materialsCache = {}
end

local function onFileChanged(filename, type)
  jbeamIO.onFileChanged(filename, type)
  local path = string.match(filename, "^(/vehicles/[^/]*/)[^%.]*%.materials%.json$")
  if path then
    log('D', 'vehicleLoader', 'Materials changed in vehicle path, invalidating cache: ' .. tostring(path))
    materialsCache[path] = nil
  end
end

local function spawnCCallback(objID, vehicleDir, configDataIn)
  Engine.Profiler.pushEvent('spawn')
  local vehicleObj = scenetree.findObject(objID)
  if not vehicleObj then
    log('E', 'loader', 'Spawning vehicle failed, missing vehicle obj: '..dumps(objID, vehicleDir, configDataIn))
    return
  end

  loadVehicleMaterialsDirectory(vehicleDir)
  loadVehicleMaterialsDirectory('/vehicles/common/')

  -- makes the object available for every call, etc
  be:addObject(vehicleObj, false)

  local timer = hptimer()
  local jbeamLoader = require("jbeam/loader")
  rawset(_G, 'log_jbeam', log)
  log('D', 'vehicleLoader', 'partConfigData [' .. type(configDataIn) .. '] = ' .. dumps(configDataIn))

  local vehicleConfig = extensions.core_vehicle_partmgmt.buildConfigFromString(configDataIn)

  local vehStage1Data = nil
  pcall(function () vehStage1Data = jbeamLoader.loadVehicleStage1(objID, vehicleDir, vehicleConfig) end)
  if not vehStage1Data then
    log('E', 'loader', 'Spawning vehicle failed, missing stage 1 data: '..dumps(objID, vehicleDir, configDataIn))
  end

  log('D', 'loader', "GE load time: " .. tostring(timer:stopAndReset() / 1000) .. ' s')

  vehicles[objID] = vehStage1Data

  if vehicleObj:getDynDataFieldbyName("autoEnterVehicle", 0) ~= "false" then
    be:enterVehicle(0, vehicleObj) -- will trigger onVehicleSwitched
  end

  vehicleSpawned(objID) -- callback to main function

  --jsonWriteFile('jbeam_loading_NEW_stage1.json', vehStage1Data, true)
  local spawnPhysics = true
  local dataString = ''

  if spawnPhysics and vehStage1Data then
    Engine.Profiler.pushEvent('serialize')
    -- do not send everything, filter some UI things that are not required
    dataString = lpack.encode({
      vdata  = vehStage1Data.vdata,
      config = vehStage1Data.config,
    })
    Engine.Profiler.popEvent() -- serialize
  end
  Engine.Profiler.pushEvent('continueSpawnObject')
  vehicleObj:continueSpawnObject(dataString, spawnPhysics)
  Engine.Profiler.popEvent() -- spawnObjectPhysics

  Engine.Profiler.popEvent()
end

local function onVehicleSwitched(oldID, newID, player)
  if vehicles[oldID] then
    vehicles[oldID].activePlayer = nil
  end
  if vehicles[newID] then
    vehicles[newID].activePlayer = player
  end
end

local function onDespawnObject(id, isReloading)
  if isReloading == false then
    vehicles[id] = nil
  end
end

local function getPlayerVehicleData()
  return vehicles[be:getPlayerVehicleID(0)]
end

local function getVehicleData(id)
  return vehicles[id]
end

local function setVehicleColorsNames(id, colors, optional)
  local vehicle = scenetree.findObjectById(id)
  local data = extensions.core_vehicles.getCurrentVehicleDetails()
  if not vehicle then return end

  if optional ~= nil and vehicle.color == vehicle.colorPalette0 == vehicle.colorPalette1 then return end
  local colortmp = {}
  if colors[1] and data.model.colors[colors[1]] then
    for v in data.model.colors[colors[1]]:gmatch( "([%d.]*)") do
      table.insert(colortmp, tonumber(v) )
    end
    vehicle.color = ColorF(colortmp[1], colortmp[2], colortmp[3], colortmp[4]):asLinear4F()
  end
  colortmp = {}
  if colors[2] and data.model.colors[colors[2]] then
    for v in data.model.colors[colors[2]]:gmatch( "([%d.]*)") do
      table.insert(colortmp, tonumber(v) )
    end
    vehicle.colorPalette0 = ColorF(colortmp[1], colortmp[2], colortmp[3], colortmp[4]):asLinear4F()
  end
  colortmp = {}
  if colors[3] and data.model.colors[colors[3]] then
    for v in data.model.colors[colors[3]]:gmatch( "([%d.]*)") do
      table.insert(colortmp, tonumber(v) )
    end
    vehicle.colorPalette1 = ColorF(colortmp[1], colortmp[2], colortmp[3], colortmp[4]):asLinear4F()
  end
end

local function liveUpdateVehicleColors(objID, _vehicleObj)
  local vehicleObj = _vehicleObj or scenetree.findObjectById(objID)
  if not vehicleObj or  not vehicles[objID] or not vehicles[objID].config or not vehicles[objID].config.colors then return end

  local col = vehicles[objID].config.colors
  if col then
    if col[1] then
      vehicleObj.color         = ColorF(col[1][1], col[1][2], col[1][3], col[1][4]):asLinear4F()
    end
    if col[2] then
      vehicleObj.colorPalette0 = ColorF(col[2][1], col[2][2], col[2][3], col[2][4]):asLinear4F()
    end
    if col[3] then
      vehicleObj.colorPalette1 = ColorF(col[3][1], col[3][2], col[3][3], col[3][4]):asLinear4F()
    end
  end
end

-- to support Lua reloads, we serialize the data
local function onDeserialized(data)
  vehicles = {}
  for k, v in pairs(data) do
    vehicles[k] = lpack.decode(v)
  end
end

local function onSerialize()
  local data = {}
  for k, v in pairs(vehicles) do
    data[k] = lpack.encode(v)
  end
  return data
end

local function toggleModifyKey()
  --extensions.core_vehicle_inplaceEdit.toggleShowWindow()
end

-- callbacks
M.onVehicleSwitched  = onVehicleSwitched
M.onDespawnObject    = onDespawnObject
M.onSerialize        = onSerialize
M.onDeserialized     = onDeserialized
M.onClientEndMission = onClientEndMission
M.onFileChanged      = onFileChanged

-- API
M.getPlayerVehicleData = getPlayerVehicleData
M.setVehicleColorsNames = setVehicleColorsNames
M.liveUpdateVehicleColors = liveUpdateVehicleColors
M.getVehicleData = getVehicleData

M.toggleModifyKey = toggleModifyKey

M._spawnCCallback = spawnCCallback

return M
