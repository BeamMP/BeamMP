-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
vmType = "vehicle"

package.path = "lua/vehicle/?.lua;?.lua;lua/common/?.lua;lua/common/libs/luasocket/?.lua;lua/?.lua;?.lua"
package.cpath = ""
require("luaCore")

log = function(...)
  Lua:log(...)
end
print = function(...)
  Lua:log("A", "print", tostring(...))
end

require("utils")
require("devUtils")
require("ve_utils")
require("mathlib")
require("controlSystems")
local STP = require "libs/StackTracePlus/StackTracePlus"
debug.traceback = STP.stacktrace
debug.tracesimple = STP.stacktraceSimple

Engine = Engine or {}
Engine.Profiler = Engine.Profiler or {}
Engine.Profiler.pushEvent = Engine.Profiler.pushEvent or nop
Engine.Profiler.popEvent = Engine.Profiler.popEvent or nop

extensions = require("extensions")
extensions.addModulePath("lua/vehicle/extensions/")
extensions.addModulePath("lua/common/extensions/")
extensions.load("core_performance")

core_performance.pushEvent("lua init")

math.randomseed(os.time())

settings = require("simplesettings")
backwardsCompatibility = require("backwardsCompatibility")
objectId = obj:getId()
vehiclePath = nil

playerInfo = {
  seatedPlayers = {}, -- list of players seated in this vehicle; players are indexed from 0 to N (e.g. { [1]=true, [4]=true } for 2nd and 5th players)
  firstPlayerSeated = false,
  anyPlayerSeated = false
}
lastDt = 1 / 20
physicsDt = obj:getPhysicsDt()

local initCalled = false
log_jbeam = nop -- intentionally global

--- if you want to debug vehicle loading, feel free to uncomment this line:
--startDebugger()

function updateCorePhysicsStepEnabled()
  obj:setPhysicsStepEnabled(controller.isPhysicsStepUsed() or powertrain.isPhysicsStepUsed() or wheels.isPhysicsStepUsed() or motionSim.isPhysicsStepUsed() or thrusters.isPhysicsStepUsed() or hydros.isPhysicsStepUsed() or beamstate.isPhysicsStepUsed())
end

local doFunkyBusiness = false
local lazydtSim = 0
local lazyPhysCount = 0
-- step functions
function onPhysicsStep(dtSim)

	lazydtSim = lazydtSim + dtSim
	lazyPhysCount = lazyPhysCount+1

	if doFunkyBusiness and v.mpVehicleType and v.mpVehicleType == 'R' then
		if lazyPhysCount == 100 then

			wheels.updateWheelVelocities(lazydtSim)
			controller.updateWheelsIntermediate(lazydtSim)
			wheels.updateWheelTorques(lazydtSim)

			controller.update(lazydtSim)
			thrusters.update()
			beamstate.update(lazydtSim)
			motionSim.update(lazydtSim)

			lazydtSim = 0
			lazyPhysCount = 0

		end
	else

		wheels.updateWheelVelocities(dtSim)
		controller.updateWheelsIntermediate(dtSim)
		wheels.updateWheelTorques(dtSim)

		controller.update(dtSim)
		thrusters.update()
		beamstate.update(dtSim)
		motionSim.update(dtSim)

	end

	powertrain.update(dtSim)
	hydros.update(dtSim)
end

-- This is called in the local scope, so it is NOT safe to do things that contact things outside the vehicle
function onGraphicsStep(dtSim)
  --debugPoll()
  
  doFunkyBusiness = settings.getValue('luaOptimisations')

  lastDt = dtSim
  sensors.updateGFX(dtSim) -- must be before input and ai
  mapmgr.sendTracking() -- must be before ai
  ai.updateGFX(dtSim) -- must be before input
  input.updateGFX(dtSim) -- must be as early as possible
  electrics.update(dtSim)
  material.updateGFX()
  controller.updateGFX(dtSim)
  extensions.hook("updateGFX", dtSim) -- must be before drivetrain, hydros and after electrics
  powertrain.updateGFX(dtSim)
  energyStorage.updateGFX(dtSim)
  drivetrain.updateGFX(dtSim)
  beamstate.updateGFX(dtSim) -- must be after drivetrain
  sounds.updateGFX(dtSim)
  hydros.updateGFX(dtSim) -- must be after (input, electrics) and before props
  thrusters.updateGFX() -- should be after extensions.hook

  gui.updateStreams = false
  if playerInfo.firstPlayerSeated then
    if obj:getUpdateUIflag() then
      gui.updateStreams = true
      gui.frameUpdated()
    end
    damageTracker.updateGFX(dtSim)
  end

  wheels.updateGFX(dtSim)
  props.update()
  fire.updateGFX(dtSim)
  recovery.updateGFX(dtSim)
  motionSim.updateGFX(dtSim)
end

-- debug rendering
local focusPos = float3(0, 0, 0)
function onDebugDraw(x, y, z)
  focusPos.x, focusPos.y, focusPos.z = x, y, z
  bdebug.debugDraw(focusPos)
  ai.debugDraw(focusPos)
  beamstate.debugDraw(focusPos)
  controller.debugDraw(focusPos)
  extensions.hook("onDebugDraw", focusPos)

  if playerInfo.anyPlayerSeated then
    extensions.hook("onDebugDrawActive", focusPos)
  end
end

function initSystems()
  core_performance.pushEvent("3.1 init - compat")
  backwardsCompatibility.init()
  core_performance.popEvent() -- 3.1 init - compat

  core_performance.pushEvent("3.2.X init - materials (sum)")
  material.init()
  core_performance.popEvent() -- 3.2.X init - materials (sum)

  core_performance.pushEvent("3.2 init - first stage")
  damageTracker.init()
  wheels.init()
  powertrain.init()
  energyStorage.init()
  input.init()
  controller.init() -- needs to go after input first stage
  core_performance.popEvent() -- 3.2 init - first stage

  core_performance.pushEvent("3.3 init - second stage")
  wheels.initSecondStage()
  controller.initSecondStage()
  drivetrain.init()
  core_performance.popEvent() -- 3.3 init - second stage

  core_performance.pushEvent("3.4 init - groupA")
  sensors.reset()
  beamstate.init()
  thrusters.init()
  hydros.init()
  core_performance.popEvent() -- 3.4 init - groupA

  core_performance.pushEvent("3.5 init - audio")
  sounds.init()
  core_performance.popEvent() -- 3.5 init - audio

  core_performance.pushEvent("3.6 init - groupB")
  props.init()
  electrics.init()
  input.initSecondStage() -- needs to go after sounds & electrics
  recovery.init()
  bdebug.init()
  sensors.init()
  fire.init()
  wheels.initSounds()
  powertrain.initSounds()
  controller.initSounds()
  gui.message("", 0, "^vehicle\\.") -- clear damage messages on vehicle restart
  core_performance.popEvent() -- 3.6 init - groupB

  core_performance.pushEvent("3.7 init - extensions")
  extensions.hook("onInit")
  core_performance.popEvent() -- 3.7 init - extensions

  core_performance.pushEvent("3.8 init - last stage")
  mapmgr.init()
  motionSim.init()
  partCondition.init()
  vehicleCertifications.init()

  controller.initLastStage() --meant to be last in init

  -- be sensitive about global writes from now on
  detectGlobalWrites()
  updateCorePhysicsStepEnabled()
  initCalled = true
  core_performance.popEvent() -- 3.8 init - last stage
end

function init(path, initData)
  core_performance.pushEvent("4.X.X.X total (sum)")

  core_performance.pushEvent("0 startup")

  if not obj then
    log("W", "default.init", "Error getting main object: unable to spawn")
    return
  end
  log("D", "default.init", "spawning vehicle " .. tostring(path))

  -- we change the lookup path here, so it prefers the vehicle lua
  package.path = path .. "/lua/?.lua;" .. package.path
  vehiclePath = path
  extensions.loadModulesInDirectory(path .. "/lua", {"controller", "powertrain", "energyStorage"})

  extensions.load("core_quickAccess")
  --extensions.load("motionSim")

  damageTracker = require("damageTracker")
  drivetrain = require("drivetrain")
  powertrain = require("powertrain")
  powertrain.setVehiclePath(path)
  energyStorage = require("energyStorage")
  controller = require("controller")

  wheels = require("wheels")
  sounds = require("sounds")
  -- vehedit = require('vehicleeditor/veMain')
  bdebug = require("bdebug")
  input = require("input")
  props = require("props")

  particles = require("particles")
  particlefilter = require("particlefilter")
  material = require("material")
  v = require("jbeam/stage2")
  electrics = require("electrics")
  beamstate = require("beamstate")
  sensors = require("sensors")
  bullettime = require("bullettime") -- to be deprecated
  thrusters = require("thrusters")
  hydros = require("hydros")
  gui = require("guihooks") -- do not change its name, the GUI callback will break otherwise
  streams = require("guistreams")
  guihooks = gui -- legacy
  ai = require("ai")
  recovery = require("recovery")
  mapmgr = require("mapmgr")
  fire = require("fire")
  partCondition = require("partCondition")
  vehicleCertifications = require("vehicleCertifications")

  local isMotionSimEnabled = settings.getValue("motionSimEnabled") or false
  if isMotionSimEnabled then
    motionSim = require("motionSim")
  else
    motionSim = {
      init = nop,
      reset = nop,
      update = nop,
      updateGFX = nop,
      settingsChanged = nop,
      isPhysicsStepUsed = function()
        return false
      end
    }
  end

  core_performance.popEvent() -- 0 startup

  core_performance.pushEvent("loadVehicleStage2 (sum)")

  -- this filters the Debug messages out
  log_jbeam = log -- logExceptD

  -- care about the config before pushing to the physics
  local vehicle
  if type(initData) == "string" and string.len(initData) > 0 then
    core_performance.pushEvent("deserialize")
    local state, initData = pcall(lpack.decode, initData)
    core_performance.popEvent() -- deserialize
    if state and type(initData) == "table" then
      if initData.vdata then
        vehicle = v.loadVehicleStage2(initData)
      else
        log("E", "vehicle", "unable to load vehicle: invalid spawn data")
      end
    end
  else
    log("E", "vehicle", "invalid initData: " .. tostring(type(initData)) .. ": " .. tostring(initData))
  end

  if not vehicle then
    log("E", "loader", "vehicle loading failed fatally")
    return false -- return false = unload lua
  end
  core_performance.popEvent()

  -- you can change the data in here before it gets submitted to the physics

  if v.data == nil then
    v.data = {}
  end

  -- disable lua for simple vehicles
  if v.data.information and v.data.information.simpleObject == true then
    log("I", "", "lua disabled!")
    return false -- return false = unload lua
  end

  core_performance.pushEvent("3.X init systems (sum)")
  initSystems()
  core_performance.popEvent() -- 3.X init systems (sum)

  -- temporary tire mark setting
  obj.slipTireMarkThreshold = 10

  if settings.getValue("outgaugeEnabled") == true then
    extensions.load("outgauge")
  end
  if settings.getValue("creatorMode") == true then
    extensions.load("creatorMode")
  end

  if settings.getValue("externalUi") == true then
    extensions.load("externalUI")
  end

  core_performance.pushEvent("5 postspawn")

  -- load the extensions at this point in time, so the whole jbeam is parsed already
  extensions.loadModulesInDirectory("lua/vehicle/extensions/auto")

  -- extensions that always load

  extensions.hook("onVehicleLoaded", retainDebug)

  --extensions.load('vehicleeditor_veMain')

  core_performance.popEvent() -- 5 postspawn
  core_performance.popEvent() -- 4.X.X.X total (sum)

  --core_performance.printReport()

  return true -- false = unload Lua
end

-- various callbacks
function onBeamBroke(id, energy)
  beamstate.beamBroken(id, energy)
  wheels.beamBroke(id)
  powertrain.beamBroke(id)
  energyStorage.beamBroke(id)
  controller.beamBroke(id, energy)
  bdebug.beamBroke(id, energy)
end

-- only being called if the beam has deform triggers
function onBeamDeformed(id, ratio)
  beamstate.beamDeformed(id, ratio)
  controller.beamDeformed(id, ratio)
  bdebug.beamDeformed(id, ratio)
end

function onTorsionbarBroken(id, energy)
end

function onCouplerFound(nodeId, obj2id, obj2nodeId)
  -- print('couplerFound'..','..nodeId..','..obj2nodeId..','..obj2id)
  beamstate.couplerFound(nodeId, obj2id, obj2nodeId)
  controller.onCouplerFound(nodeId, obj2id, obj2nodeId)
  extensions.hook("onCouplerFound", nodeId, obj2id, obj2nodeId)
end

function onCouplerAttached(nodeId, obj2id, obj2nodeId)
  -- print('couplerAttached'..','..nodeId..','..obj2nodeId..','..obj2id)
  beamstate.couplerAttached(nodeId, obj2id, obj2nodeId)
  controller.onCouplerAttached(nodeId, obj2id, obj2nodeId)
  extensions.hook("onCouplerAttached", nodeId, obj2id, obj2nodeId)
end

function onCouplerDetached(nodeId, obj2id, obj2nodeId)
  -- print('couplerDetached'..','..nodeId..','..obj2nodeId..','..obj2id)
  beamstate.couplerDetached(nodeId, obj2id, obj2nodeId)
  controller.onCouplerDetached(nodeId, obj2id, obj2nodeId)
  extensions.hook("onCouplerDetached", nodeId, obj2id, obj2nodeId)
end

-- called when vehicle is removed
function onDespawnObject()
  --log('D', "default.vehicleDestroy", "vehicleDestroy()")
  hydros.destroy()
end

-- called when the user pressed I
function onVehicleReset(retainDebug)
  guihooks.reset()
  extensions.hook("onReset", retainDebug)
  ai.reset()
  mapmgr.reset()

  if not initCalled then
    --log('D', "default.vehicleResetted", "vehicleResetted()")
    damageTracker.reset()
    wheels.reset()
    electrics.reset()
    powertrain.reset()
    energyStorage.reset()
    controller.reset()
    wheels.resetSecondStage()
    controller.resetSecondStage()
    drivetrain.reset()
    props.reset()
    sensors.reset()
    if not retainDebug then
      bdebug.reset()
    end
    beamstate.reset()
    thrusters.reset()
    input.reset()
    hydros.reset()
    material.reset()
    fire.reset()
    motionSim.reset()
    powertrain.resetSounds()
    controller.resetSounds()
    sounds.reset()
    partCondition.reset()
    vehicleCertifications.reset()

    controller.resetLastStage() --meant to be last in reset
  end
  initCalled = false

  gui.message("", 0, "^vehicle\\.") -- clear damage messages on vehicle restart
end

function onNodeCollision(p)
  wheels.nodeCollision(p)
  fire.nodeCollision(p)
  controller.nodeCollision(p)
  particlefilter.nodeCollision(p)
  bdebug.nodeCollision(p)
end

function setControllingPlayers(players)
  playerInfo.seatedPlayers = players
  playerInfo.anyPlayerSeated = not (tableIsEmpty(players))
  playerInfo.firstPlayerSeated = players[0] ~= nil

  if playerInfo.anyPlayerSeated then
    if controller and controller.mainController then
      if controller.mainController.vehicleActivated then --TBD, only vehicleActivated should be there
        controller.mainController.vehicleActivated()
      else
        controller.mainController.sendTorqueData()
      end
    end

    damageTracker.sendNow() --send over damage data of (now) active vehicle
  end

  bdebug.activated(playerInfo.anyPlayerSeated)
  ai.stateChanged()
  extensions.hook("activated", playerInfo.anyPlayerSeated) -- backward compatibility
  guihooks.trigger("VehicleFocusChanged", {id = obj:getID(), mode = playerInfo.anyPlayerSeated})
  -- TODO: clean below up ...
  obj:queueGameEngineLua("extensions.hook('onVehicleFocusChanged'," .. serialize({id = obj:getID(), mode = playerInfo.anyPlayerSeated}) .. ")")
end

function exportPersistentData()
  local d = serializePackages("reload")
  --log('D', "default.exportPersistentData", d)
  obj:setPersistentData(serialize(d))
end

function importPersistentData(s)
  --log('D', "default.importPersistentData", s)
  -- deserialize extensions first, so the extensions are loaded before they are trying to get deserialized
  deserializePackages(deserialize(s))
end

function onSettingsChanged()
  extensions.hook("onSettingsChanged")
  controller.settingsChanged()
  input.settingsChanged()
  motionSim.settingsChanged()
end

core_performance.popEvent() -- lua init
