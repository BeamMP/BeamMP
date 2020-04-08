-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.wheels = {}
M.cumulativeGearRatio = 0
M.engineData = {}
M.stabilityCoef = 250

--we need to initialize this with {0} so that powertrain.torqueReactionCoefs[1] works, 1 in this case is the default torsionReactorID for all wheels/rotators,
--which we need to use in case that powertrain does not init at all/correctly (trailers, mods with old stuff, etc). The {0} is only used when powertrain does not init!
M.torqueReactionCoefs = {0}
local torqueReactionCoefs2 = {0}
local torsionReactorList = {}
local torsionReactorCount = 0
local torsionReactorIndexes = {}

local max = math.max
local tableSize = tableSize
local log = log
local pi = math.pi
local twoPi = pi * 2
local visualShaftAngleCoef = 180 / pi

--local warningState = {}
local vehiclePath = nil

local hasPowertrain = false
local canResetDevices = false

local deviceFactories = nil
local availableDeviceFactories = nil
local factoryBlackList = {combustionEngineThermals = true, supercharger = true, turbocharger = true, nitrousOxideInjection = true}
local powertrainDevices = {} --keeps track of all available powertrain devices, also used as LUT
local orderedDevices = {}
local deviceCount = 0
local beamBrokenEvents = {}
local beamBrokenEventCount = 0

local breakTriggerBeams = {} --shaft break beam cache
local previousDeviceModes = {}

local dummyShaftCounter = 0

local engineSoundIDCounter = -1
local deviceStream = {}
local streamData = {devices = deviceStream}
local outputTorqueStr = {}
local outputAVStr = {}

for i = 0, 10 do
  outputTorqueStr[i] = "outputTorque" .. tostring(i)
  outputAVStr[i] = "outputAV" .. tostring(i)
end

local function nop()
end

local function dumpsDeviceData(device)
  if device then
    local data = deepcopy(device)
    if data.children then
      data.children = {}
      for _, v in pairs(device.children) do
        table.insert(data.children, v.name or "unknown")
      end
    end
    if data.clutchChild then
      data.clutchChild = data.clutchChild.name
    end
    if data.parent then
      data.parent = data.parent.name or "unknown"
    end
    return dumps(data)
  else
    return "nil"
  end
end

local function sendDeviceData()
  if streams.willSend("powertrainDeviceData") then
    for _, v in pairs(powertrainDevices) do
      deviceStream[v.name] = deviceStream[v.name] or {outputTorque = {}, outputAV = {}}
      local di = 1
      for i, _ in pairs(v.outputPorts) do
        deviceStream[v.name].outputTorque[di] = v[outputTorqueStr[i]]
        deviceStream[v.name].outputAV[di] = v[outputAVStr[i]]
        di = di + 1
      end
      deviceStream[v.name].currentMode = (v.availableModes and #v.availableModes > 1) and v.mode or nil
    end
    -- dump(deviceStream)
    gui.send("powertrainDeviceData", streamData)
  end
end

local function updateGFX(dt)
  for i = 1, deviceCount, 1 do
    local device = orderedDevices[i]
    if device.updateGFX then
      device:updateGFX(dt)
    end
    if device.updateSounds then
      device:updateSounds(dt)
    end
    if device.electricsName and device.visualShaftAngle then --only take care of devices that are meant to have a public angle
      device.visualShaftAngle = (device.visualShaftAngle + device.inputAV * device.gearRatio * dt) % twoPi
      electrics.values[device.electricsName] = device.visualShaftAngle * visualShaftAngleCoef
    end
  end

  sendDeviceData()
end

local function update(dt)
  M.torqueReactionCoefs, torqueReactionCoefs2 = torqueReactionCoefs2, M.torqueReactionCoefs

  --performanceLogger.startMeasurement("speeds")
  for i = deviceCount, 1, -1 do
    orderedDevices[i]:velocityUpdate(dt)
  end
  --performanceLogger.measureAverage("speeds", 10000, false)

  --performanceLogger.startMeasurement("torques")
  for i = 1, deviceCount, 1 do
    orderedDevices[i]:torqueUpdate(dt)
  end
  --performanceLogger.measureAverage("torques", 10000, false)

  local trCoefs = M.torqueReactionCoefs
  for i = 1, torsionReactorCount do
    trCoefs[i] = torsionReactorList[i].outputTorque1 / (trCoefs[i] + 1e-30)
    torqueReactionCoefs2[i] = 0
  end
end

local function sendDeviceTree()
  if not playerInfo.firstPlayerSeated then return end

  local maxPower = 0
  local maxTorque = 0
  local devices = {}
  for _, d in pairs(powertrainDevices) do
    if d.parent.isFake then
      maxPower = max(maxPower, d.maxPower or 0)
      maxTorque = max(maxTorque, (d.maxTorque or 0) * (d.maxCumulativeGearRatio or 1))
    end
    local device = {
      type = d.visualType or d.type,
      modes = (d.availableModes and #d.availableModes > 1) and d.availableModes or nil,
      pos = d.visualPosition,
      children = {}
    }
    if d.children then
      local inverseMap = {}
      for _, d1 in pairs(d.children) do
        inverseMap[d1.inputIndex] = d1.name
      end
      for i, _ in pairs(d.outputPorts) do
        table.insert(device.children, inverseMap[i])
      end
    end
    device.currentMode = (v.availableModes and #v.availableModes > 1) and v.mode or nil
    devices[d.name] = device
  end

  --dump(devices)
  guihooks.trigger("PowertrainDeviceTreeChanged", {devices = devices, maxPower = maxPower, maxTorque = maxTorque})
end

local function calculateTreeInertia()
  --iterate starting at the wheels for various calculations throughout the tree(s)
  for i = deviceCount, 1, -1 do
    orderedDevices[i]:calculateInertia()
    --log("D", "powertrain.calculateTreeInertia", string.format("Cumulative downstream inertia for %s: %.3f", orderedDevices[i].name, orderedDevices[i].cumulativeInertia))
  end
end

local function validatePowertrain()
  for i = deviceCount, 1, -1 do
    if orderedDevices[i].validate and not orderedDevices[i]:validate() then
      log("E", "powertrain.init", "Failed to validate powertrain device. Look above for more information. Aborting powertrain init!")
      return
    end
  end
end

local function makeDummyShaft(name, inputName, inputIndex)
  local shaft = {
    name = name,
    inputName = inputName,
    inputIndex = inputIndex,
    type = "shaft",
    gearRatio = 1,
    cumulativeGearRatio = 1,
    friction = 1,
    isPhysicallyDisconnected = true
  }

  return shaft
end

local function buildDeviceTree(t)
  if t.parent then
    t.cumulativeGearRatio = t.gearRatio * t.parent.cumulativeGearRatio
  end
  M.cumulativeGearRatio = max(M.cumulativeGearRatio, t.cumulativeGearRatio)

  if t.requiredExternalInertiaOutputs then
    for _, index in pairs(t.requiredExternalInertiaOutputs) do
      local hasMatchingChild = false
      for _, child in pairs(t.children or {}) do
        if child.inputIndex == index then
          hasMatchingChild = true
          break
        end
      end

      if not hasMatchingChild then
        if not deviceFactories["shaft"] then
          deviceFactories["shaft"] = require(availableDeviceFactories["shaft"])
        end
        log("W", "powertrain.buildDeviceTree", string.format("Adding a dummy shaft to device '%s' on output '%d'", t.name, index))
        t.children = t.children or {}
        local dummyShaft = deviceFactories["shaft"].new(makeDummyShaft("dummyShaft" .. tostring(dummyShaftCounter), t.name, index))
        dummyShaftCounter = dummyShaftCounter + 1
        dummyShaft.parent = t
        table.insert(t.children, dummyShaft)
      end
    end
  end

  --check how many of our children ARE actually connected properly and adjust their parent if they aren't
  t.connectedChildrenCount = tableSize(t.children)
  if t.children then
    for _, v in pairs(t.children) do
      if not t.outputPorts[v.inputIndex] then
        v.parent = nil
        t.connectedChildrenCount = t.connectedChildrenCount - 1
      end
    end
  end

  --check if we actually have a parent and if we have (properly connected) cildren or a connected wheel
  if t.parent and (t.connectedChildrenCount > 0 or t.connectedWheel) then
    --only if the above are true our device is physically connected to something else
    t.isPhysicallyDisconnected = false
    --we have a proper parent, so send down the propulsion info
    t.isPropulsed = t.parent.isPropulsed or false
  end

  if t.connectedWheel and t.isPropulsed then
    M.wheels[t.connectedWheel].isPropulsed = true
  end

  powertrainDevices[t.name] = t
  table.insert(orderedDevices, t)

  if t.children then
    for _, v in pairs(t.children) do
      buildDeviceTree(v)
    end
  end
end

local function init()
  M.update = nop

  M.cumulativeGearRatio = 0
  M.engineData = {}
  --warningState = {}

  orderedDevices = {}
  powertrainDevices = {}
  breakTriggerBeams = {}

  deviceCount = 0
  dummyShaftCounter = 0
  engineSoundIDCounter = -1
  deviceFactories = {}

  if not availableDeviceFactories then
    availableDeviceFactories = {}
    local globalDirectory = "lua/vehicle/powertrain"
    local vehicleDirectory = vehiclePath .. "lua/powertrain"
    local globalFiles = FS:findFiles(globalDirectory, "*.lua", -1, true, false)
    local vehicleFiles = FS:findFiles(vehicleDirectory, "*.lua", -1, true, false)
    local files = arrayConcat(globalFiles, vehicleFiles)
    if files then
      for _, filePath in ipairs(files) do
        local _, file, _ = path.split(filePath)
        local fileName = file:sub(1, -5)
        if not factoryBlackList[fileName] then
          local deviceFactoryPath = "powertrain/" .. fileName
          availableDeviceFactories[fileName] = deviceFactoryPath
        end
      end
    else
      log("E", "powertrain.init", "Can't load powertrain device factories, looking for directory: " .. tostring(globalDirectory))
    end
  end

  --dump(availableDeviceFactories)

  M.wheels = {}
  for i = 0, wheels.wheelRotatorCount - 1 do
    local wheel = wheels.wheelRotators[i]
    M.wheels[wheel.name] = wheel
  end

  if not v.data.powertrain and (v.data.differentials or v.data.engine) then
    log("D", "powertrain.init", "Found old drivetrain data, creating compatibility powertrain")
    local result = backwardsCompatibility.createCompatibilityPowertrain()
    if not result then
      log("E", "powertrain.init", "Old drivetrain data can't be used to create compatibility powertrain, aborting init!")
      return
    end
  end

  if v.data.powertrain then
    local count = tableSize(v.data.powertrain)
    if count <= 0 then
      log("W", "powertrain.init", "Found empty powertrain section. Aborting powertrain init!")
      return
    end

    local deviceLookup = {}
    for _, jbeamData in pairs(deepcopy(v.data.powertrain)) do
      tableMergeRecursive(jbeamData, v.data[jbeamData.name] or {})

      --we need these during the tree building, so we need to init them right now
      jbeamData.gearRatio = jbeamData.gearRatio or 1
      jbeamData.cumulativeGearRatio = jbeamData.gearRatio
      --all devices start out as physically disconnected, when we walk through the tree later we can see which actually are connected
      jbeamData.isPhysicallyDisconnected = true

      if availableDeviceFactories[jbeamData.type] and not deviceFactories[jbeamData.type] then
        local deviceFactory = require(availableDeviceFactories[jbeamData.type])
        deviceFactories[jbeamData.type] = deviceFactory
      end

      --load our actual device via the device factory
      if deviceFactories[jbeamData.type] then
        local device = deviceFactories[jbeamData.type].new(jbeamData)
        device.uiName = jbeamData.uiName or device.name
        deviceLookup[device.name] = device
      else
        log("E", "powertrain.init", "Found unknown powertrain device type: " .. jbeamData.type)
        log("E", "powertrain.init", "Powertrain will not work!")
        return
      end
    end

    --dump(deviceFactories)

    for _, device in pairs(deviceLookup) do
      if device.name == device.inputName then
        log("E", "powertrain.init", "You can't link a device to itself. Device name: " .. device.name)
        log("E", "powertrain.init", "Powertrain will not work!")
        return
      end
      if deviceLookup[device.inputName] then
        deviceLookup[device.inputName].children = deviceLookup[device.inputName].children or {}
        device.parent = deviceLookup[device.inputName]
        table.insert(deviceLookup[device.inputName].children, device)
      end
    end

    for _, device in pairs(deviceLookup) do
      if not device.parent then
        buildDeviceTree(device)
      end
    end

    deviceCount = tableSize(powertrainDevices)

    local beamTriggers = {}
    beamBrokenEvents = {}
    for _, device in pairs(powertrainDevices) do
      device.parent = device.parent or {isFake = true, outputTorque0 = 0, outputTorque1 = 0, outputTorque2 = 0, deviceCategories = {}}
      device.parentOutputAVName = "outputAV" .. tostring(device.inputIndex)
      device.parentOutputTorqueName = "outputTorque" .. tostring(device.inputIndex)

      if device.breakTriggerBeam then
        if type(device.breakTriggerBeam) ~= "table" then
          device.breakTriggerBeam = {device.breakTriggerBeam}
        end
        for _, name in ipairs(device.breakTriggerBeam) do
          beamTriggers[name] = device.name
        end
      end

      if device.beamBroke then
        table.insert(beamBrokenEvents, device.name)
      end
    end

    --    for _,device in pairs(powertrainDevices) do
    --      print(device.name)
    --    end

    beamBrokenEventCount = #beamBrokenEvents

    validatePowertrain()
    calculateTreeInertia()

    --dump(beamTriggers)
    --dump(beamBrokenEvents)
    --    for k,v in pairs(powertrainDevices) do
    --      print(v.name)
    --      print(dumpsDeviceData(v))
    --    end
    --dump(speedOrderedDevices)

    for _, v in pairs(v.data.beams) do
      if v.name and v.name ~= "" and beamTriggers[v.name] then
        breakTriggerBeams[v.cid] = beamTriggers[v.name]
      end
    end

    --dump(breakTriggerBeams)

    hasPowertrain = true
    canResetDevices = true
    for _, device in pairs(powertrainDevices) do
      local hasReset = device.reset ~= nil
      local hasResetSounds = device.initSounds ~= nil and device.resetSounds ~= nil or true
      canResetDevices = canResetDevices and hasReset and hasResetSounds

      damageTracker.setDamage("powertrain", device.name, device.isBroken or false)
    end

    if tableSize(previousDeviceModes) > 0 then
      for k, v in pairs(previousDeviceModes) do
        powertrainDevices[k]:setMode(v)
      end
    end

    M.update = update

    --extensions.load("performanceLogger")

    sendDeviceTree()
  end

  M.torqueReactionCoefs = {}
  torqueReactionCoefs2 = {}
  torsionReactorCount = 0
  torsionReactorIndexes = {}
  for _, rotator in pairs(wheels.wheelRotators) do
    if rotator.torsionReactor then
      if not torsionReactorIndexes[rotator.torsionReactor.name] then
        torsionReactorCount = torsionReactorCount + 1
        torsionReactorIndexes[rotator.torsionReactor.name] = torsionReactorCount
      end

      local trIdx = torsionReactorIndexes[rotator.torsionReactor.name]
      rotator.torsionReactorIdx = trIdx
      torsionReactorList[trIdx] = rotator.torsionReactor
      M.torqueReactionCoefs[trIdx] = 0
      torqueReactionCoefs2[trIdx] = 0
    end
  end
end

local function initSounds()
  if not hasPowertrain then
    return
  end

  for _, device in pairs(powertrainDevices) do
    if device.initSounds then
      device:initSounds()
    end
  end
end

local function reset()
  if not hasPowertrain then
    return
  end

  if not canResetDevices then
    log("W", "powertrain.reset", "One or more powertrain devices do not support dedicated reset, using full init instead!")
    init()
    return
  end

  for _, device in pairs(powertrainDevices) do
    device:reset()
    damageTracker.setDamage("powertrain", device.name, device.isBroken or false)
  end

  calculateTreeInertia()
  sendDeviceTree()

  M.torqueReactionCoefs = {}
  torqueReactionCoefs2 = {}
  for _, rotator in pairs(wheels.wheelRotators) do
    if rotator.torsionReactor then
      local trIdx = torsionReactorIndexes[rotator.torsionReactor.name]
      M.torqueReactionCoefs[trIdx] = 0
      torqueReactionCoefs2[trIdx] = 0
    end
  end
end

local function resetSounds()
  if not hasPowertrain then
    return
  end

  if not canResetDevices then
    log("W", "powertrain.resetSounds", "One or more powertrain devices do not support dedicated reset, using full init instead!")
    initSounds()
    return
  end

  for _, device in pairs(powertrainDevices) do
    if device.resetSounds then
      device:resetSounds()
    end
  end
end

local function beamBroke(id)
  for i = 1, beamBrokenEventCount, 1 do
    powertrainDevices[beamBrokenEvents[i]]:beamBroke(id)
  end

  if not breakTriggerBeams[id] then
    return
  end

  local device = powertrainDevices[breakTriggerBeams[id]]
  device:onBreak()

  gui.message({txt = "vehicle.drivetrain.deviceBroken", context = {deviceName = device.uiName}}, 10, "vehicle.damage.device." .. device.uiName)
  damageTracker.setDamage("powertrain", device.name, true)
end

local function setDeviceMode(name, mode)
  local device = powertrainDevices[name]
  if not device then
    return
  end

  previousDeviceModes[name] = mode
  device:setMode(mode)
  if powertrainVE ~= nil then powertrainVE.sendPowertrain(name, mode) end --==================================================|
end

--===================================================================================================================\
local function setDeviceModeNoEvent(name, mode)
  local device = powertrainDevices[name]
  if not device then
    return
  end

  previousDeviceModes[name] = mode
  device:setMode(mode)
end
M.setDeviceModeNoEvent = setDeviceModeNoEvent
--===================================================================================================================/

local function toggleDeviceMode(name)
  local device = powertrainDevices[name]
  if not device then
    return
  end

  local found = false
  local newMode = device.mode
  for _, v in pairs(device.availableModes) do
    if found then
      newMode = v
      found = false
      break
    elseif device.mode == v then
      found = true
    end
  end

  if found then
    newMode = device.availableModes[next(device.availableModes)]
  end

  setDeviceMode(name, newMode)
  return newMode
end

local function toggleDefaultDiffs()
  local mode = nil
  for _, v in pairs(powertrainDevices) do
    if v.type == "differential" and v.defaultToggle then
      mode = toggleDeviceMode(v.name)
    end
  end
  if mode ~= nil then
    gui.message("Differential Mode: " .. mode, 10, "vehicle.powertrain.diffmode")
  end
end

local function getDevices()
  return powertrainDevices
end

local function getOrderedDevices()
  return orderedDevices
end

local function getDevice(name)
  return name and powertrainDevices[name] or nil
end

local function getDevicesByType(deviceType)
  local result = {}
  for _, v in pairs(powertrainDevices) do
    if v.type == deviceType then
      table.insert(result, v)
    end
  end
  return result
end

local function getDevicesByCategory(category)
  local result = {}
  for _, v in pairs(powertrainDevices) do
    if v.deviceCategories[category] then
      table.insert(result, v)
    end
  end
  return result
end

local function setVehiclePath(path)
  vehiclePath = path
end

local function getEngineSoundID()
  engineSoundIDCounter = engineSoundIDCounter + 1
  return engineSoundIDCounter
end

local function getPersistentDeviceState(deviceName)
  --WIP, API added for Bruno/Career work, not implemented yet
  local device = getDevice(deviceName)
  if device and device.getPersistentState then
    return device:getPersistentState()
  end
  return {}
end

local function setPersistentDeviceState(deviceName, persistentState)
  --WIP, API added for Bruno/Career work, not implemented yet
  local device = getDevice(deviceName)
  if persistentState and device and device.setPersistentState then
    device:setPersistentState(persistentState)
  end
end

local function getAllPersistentDeviceStates()
  --WIP, API added for Bruno/Career work, not implemented yet
  local damageStates = {}
  for k, _ in pairs(powertrainDevices) do
    damageStates[k] = getPersistentDeviceState(k)
  end
  return damageStates
end

local function setAllPersistentDeviceStates(persistentStates)
  --WIP, API added for Bruno/Career work, not implemented yet
  if not persistentStates then
    return
  end

  for k, _ in pairs(powertrainDevices) do
    setPersistentDeviceState(k, persistentStates[k])
  end
end

local function test()
  local state = getPersistentDeviceState("mainEngine")
  state.block.headGasketCondition = 0
  setPersistentDeviceState("mainEngine", state)
end

M.init = init
M.reset = reset
M.initSounds = initSounds
M.resetSounds = resetSounds
M.update = nop
M.updateGFX = updateGFX

M.beamBroke = beamBroke

M.calculateTreeInertia = calculateTreeInertia

M.toggleDefaultDiffs = toggleDefaultDiffs
M.toggleDeviceMode = toggleDeviceMode
M.setDeviceMode = setDeviceMode
M.getOrderedDevices = getOrderedDevices
M.getDevices = getDevices
M.getDevicesByType = getDevicesByType
M.getDevicesByCategory = getDevicesByCategory
M.getDevice = getDevice
M.dumpsDeviceData = dumpsDeviceData

M.sendDeviceTree = sendDeviceTree
M.setVehiclePath = setVehiclePath
M.getEngineSoundID = getEngineSoundID

M.getPersistentDeviceState = getPersistentDeviceState
M.setPersistentDeviceState = setPersistentDeviceState
M.getAllPersistentDeviceStates = getAllPersistentDeviceStates
M.setAllPersistentDeviceStates = setAllPersistentDeviceStates

M.test = test

--function startProfile()
--  require("extensions/p").start("Fplm0i0", "beam-profiler.log")
--end

--function endProfile()
--  require("extensions/p").stop(true)
--end

return M

-------------------------------------------------------------
------ Don't remove, left it here for future reference ------
-------------------------------------------------------------

--[[
deviceSpeedUpdateNameLookup = {
  [shaftUpdateSpeed] = "shaftUpdateSpeed",
  [shaftDisconnectedUpdateSpeed] = "shaftDisconnectedUpdateSpeed",
  [wheelShaftUpdateSpeed] = "wheelShaftUpdateSpeed",
  [wheelShaftDisconnectedUpdateSpeed] = "wheelShaftDisconnectedUpdateSpeed",
  [differentialUpdateSpeed] = "differentialUpdateSpeed",
  [diffConnectorUpdateSpeed] = "diffConnectorUpdateSpeed"
}
deviceTorqueUpdateNameLookup ={
  [shaftUpdateTorque] = "shaftUpdateTorque",
  [shaftDisconnectedUpdateTorque] = "shaftDisconnectedUpdateTorque",
  [wheelShaftUpdateTorque] = "wheelShaftUpdateTorque",
  [wheelShaftDisconnectedUpdateTorque] = "wheelShaftDisconnectedUpdateTorque",
  [differentialOpenUpdateTorque] = "differentialOpenUpdateTorque",
  [differentialLSDUpdateTorque] = "differentialLSDUpdateTorque",
  [differentialViscousLSDUpdateTorque] = "differentialViscousLSDUpdateTorque",
  [differentialLockedUpdateTorque] = "differentialLockedUpdateTorque",
  [diffConnectorLockedUpdateTorque] = "diffConnectorLockedUpdateTorque",
  [diffConnectorViscousUpdateTorque] = "diffConnectorViscousUpdateTorque",
  [diffConnectorDisconnectedUpdateTorque] = "diffConnectorDisconnectedUpdateTorque"
}

function createEnvironment()
  local variables = {}
  local idx = 1
  while true do
    local ln, lv = debug.getupvalue(M.init, idx)
    if ln ~= nil then
      variables[ln] = lv
    else
      break
    end
    idx = 1 + idx
  end
  tableMerge(variables, _G)
  return variables
end

--this works in theory but didn't give us any performance benefits, leaving it in here for future reference
local function compileUpdateMethods()
  local speedUpdateTable = {}
  for i = 1, deviceCount, 1 do
    table.insert(speedUpdateTable, string.format("%s(speedOrderedDevices[%i], dt)", deviceSpeedUpdateNameLookup[speedOrderedDevices[i].speedUpdate], i))
  end
  table.insert(speedUpdateTable, "drivetrain.wheelBasedEngAV = transmissionInputDevice.inputAV")

  local speedUpdateString = "return function(dt) " .. table.concat(speedUpdateTable, ";") .. " end"
  local env = createEnvironment()
  M.updateSpeeds = load(speedUpdateString, nil, "t", env)()


  local torqueUpdateTable = {}

  table.insert(torqueUpdateTable, "transmissionInputDevice.parent.outputTorque0 = drivetrain.torqueTransmission")
  for i = 1, deviceCount, 1 do
    table.insert(torqueUpdateTable, string.format("%s(torqueOrderedDevices[%i], dt)", deviceTorqueUpdateNameLookup[torqueOrderedDevices[i].torqueUpdate], i))
  end

  local torqueUpdateString = "return function(dt) " .. table.concat(torqueUpdateTable, "; ") .. " end"
  M.updateTorques = load(torqueUpdateString, nil, "t", env)()
end
--]]
