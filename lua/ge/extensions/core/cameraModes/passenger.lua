-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local function rotateEuler(x, y, z, q)
  q = q or quat()
  q = quatFromEuler(0, z, 0) * q
  q = quatFromEuler(0, 0, x) * q
  q = quatFromEuler(y, 0, 0) * q
  return q
end

local manualzoom = require('core/cameraModes/manualzoom')

local C = {}
C.__index = C

function C:init()
  self.saveTimeout = nil
  self.camLastRot = vec3()
  self.cameraResetted = 3
  self.camRot = vec3(0, 0, 0)
  self.relativeYaw = 0
  self.relativePitch = 0
  self.manualzoom = manualzoom()
  self:onVehicleCameraConfigChanged()
  self:onSettingsChanged()
end

function C:onVehicleCameraConfigChanged()
  --trigger reloading of new vehicle from settings
  self.passengerSeatPosition = nil
  self.seatRotation = 0
  --trigger gathering of new initial node position
  self.camPosInitialLocal = nil
  self.cameraResetted = 3
end
function C:onSettingsChanged()
  self.physicsFactor = settings.getValue('cameraDriverPhysics') / 100 -- 0..1 multiplier
  self.autocenter = settings.getValue('cameraDriverAutocenter')
  self.allowSeatAdjustments = settings.getValue('cameraDriverAllowSeatAdjustments')
  self.stableHorizonFactor = settings.getValue('cameraDriverStableHorizon') / 100 -- 0..1 multiplier
  self.manualzoom:init(settings.getValue('cameraDriverFov'), nil, nil, "ui.camera.fovDriver")
end

function C:resetSeat()
  self.passengerSeatPosition = vec3()
  self.seatRotation = 0
  self.saveTimeout = 0 -- trigger save instantaneously
end

function C:resetSeatAll()
  self.passengerSeatPosition = vec3()
  self.seatRotation = 0
  self.saveTimeout = nil -- disable any ongoing auto-save
  settings.setValue('cameraDriverVehicleConfigs', "{}")
end

function C:reset()
  self.relativeYaw = 0
  self.relativePitch = 0
end

local lookBack = false
function C:lookback(value)
  lookBack = value >= 0.5 and true or false
end

local dxSmoother = newTemporalSmoothing(3,1)
local dySmoother = newTemporalSmoothing(3,1)
local dzSmoother = newTemporalSmoothing(3,1)

function C:update(data)

  if not data.veh.mpVehicleType or data.veh.mpVehicleType == 'L' then
    core_camera.setVehicleCameraByIndexOffset(0, 1) extensions.hook('trackCamMode')
    return
  end

  local carPos = data.pos
  -- retrieve camera node (except when resetting, because data is not reliable then)
  self.cameraResetted = math.max(self.cameraResetted - 1, 0)
  if self.cameraResetted > 0 then
    data.res.pos = carPos
    data.res.rot = quatFromDir(vec3(0,1,0), vec3(0, 0, 1))
    return
  end
  local camNodeID, rightHandDrive = core_camera.getDriverData(data.veh)
  if not camNodeID then core_camera.setVehicleCameraByIndexOffset(0, 1) extensions.hook('trackCamMode') end
  local carwidth = data.veh:getInitialWidth()

  local passengerOffset = vec3((carwidth*0.4)*(rightHandDrive and 1 or -1),0,0)

  -- read seat adjustment settings
  if self.passengerSeatPosition == nil then
    local vehicleName = data.veh:getJBeamFilename()
    local vehConfigs = settings.getValue('cameraDriverVehicleConfigs')
    if type(vehConfigs) ~= "string" then vehConfigs = "{}" end
    vehConfigs = vehConfigs:gsub("'",'"') -- fix INI values that passed through javascript (e.g. when opening Options menu)
    vehConfigs = jsonDecode(vehConfigs) -- and then deserialize, so we can follow the user settings
    local vehConfig = vehConfigs[vehicleName] or {0,0,0,0}
    self.passengerSeatPosition = vec3(vehConfig[4] or 0, vehConfig[2], vehConfig[3])
    self.seatRotation = vehConfig[1]
  end

  -- process mouse rotation input
  self.relativeYaw   = clamp(self.relativeYaw   + 0.1*MoveManager.yawRelative  , -1, 1)
  self.relativePitch = clamp(self.relativePitch - 0.3*MoveManager.pitchRelative, -1, 1)

  -- process kbd/pad rotation input
  local absYaw = 0
  local absPitch = 0
  local filter = core_camera.getLastFilter()
  if self.autocenter then
    -- camera will go back to center as soon as the controller is released
    absPitch = MoveManager.pitchDown - MoveManager.pitchUp
    absYaw   = MoveManager.yawRight  - MoveManager.yawLeft
    if filter == FILTER_KBD or filter == FILTER_KBD2 then
      -- keyboard look-to-rear key combo (press both left+right to look back)
      absYaw = 0.5*(MoveManager.yawRight - MoveManager.yawLeft)
      if MoveManager.yawLeft > 0 and MoveManager.yawRight > 0 then
        absYaw = absYaw + sign(self.camRot.x)
      end
    end
  else
    -- camera will stay where it is when the controller is released
    self.relativeYaw   = self.relativeYaw   + (MoveManager.yawRight  - MoveManager.yawLeft) * 0.01
    self.relativePitch = self.relativePitch + (MoveManager.pitchDown - MoveManager.pitchUp) * 0.04
  end

  local sideInput = self.relativeYaw   + absYaw
  local vertInput = self.relativePitch + absPitch

  -- convert input into angles
  local maxAngle = 160 -- max degrees the head will be looking back
  self.camRot.x = sideInput * maxAngle
  if lookBack then self.camRot.x = rightHandDrive and maxAngle or -maxAngle end
  self.camRot.y = vertInput * 20
  if vertInput > 0 then self.camRot.y = self.camRot.y * 2 end

  -- orientation
  local rot = vec3(math.rad(self.camRot.x), math.rad(self.camRot.y), math.rad(self.camRot.z))
  local ratiox = 1 / (data.dt * 50)
  local ratioy = 1 / (data.dt * 10)
  if not self.autocenter then ratioy = 1 / (data.dt * 50) end
  rot.x = 1 / (ratiox + 1) * rot.x + (ratiox / (ratiox + 1)) * self.camLastRot.x
  rot.y = 1 / (ratioy + 1) * rot.y + (ratioy / (ratioy + 1)) * self.camLastRot.y
  self.camLastRot = vec3(rot)
  self.camRot = vec3(math.deg(rot.x), math.deg(rot.y) - self.seatRotation, math.deg(rot.z))
  local left = vec3(data.veh:getNodePosition(self.refNodes.left))
  local ref  = vec3(data.veh:getNodePosition(self.refNodes.ref))
  local back = vec3(data.veh:getNodePosition(self.refNodes.back))

  local carLeft = (left-ref):normalized()
  local carFwd = (back-ref):normalized()
  local carUp = carLeft:cross(back):normalized()
  local carDir = quatFromDir(carFwd, carUp)

  local nodePos = vec3(data.veh:getNodePosition(camNodeID))
  local carUp = -(carFwd:cross(carLeft):normalized())
  local camDir = quatFromDir(-carFwd)
  local camUp = camDir * vec3(0, 0, 1)
  local carRoll = math.atan2(camUp:dot(-carLeft), camUp:dot(carUp))
  local carRollFactor = 1 - self.stableHorizonFactor * smootheststep(clamp(1.42*carUp.z, 0, 1))
  local camRoll = carRoll * carRollFactor
  camDir = rotateEuler(math.rad(self.camRot.x), math.rad(self.camRot.y), camRoll, camDir) -- stable hood line

  local rotHorizontal = rotateEuler(-math.rad(self.camRot.x), -math.rad(180), math.rad(self.camRot.z))
  --print(math.deg(rotHorizontal:toEulerYXZ().x))

  local notifiedFov = self.manualzoom:update(data)
  if notifiedFov then
    self.saveTimeout = 1
  end

  -- physics-based position
  local camPosLocal = carDir:inversed() * nodePos

  -- static position
  if self.camPosInitialLocal == nil then ---- FIXME this can happen at any point, e.g. when vehicle is damaged
    self.camPosInitialLocal = camPosLocal
  end

  -- physics+static position combination
  local combinedPos = camPosLocal*(0+self.physicsFactor) + self.camPosInitialLocal*(1-self.physicsFactor)

  -- left/right head sticking out position
  local minAngle = 90 -- starting angle when driver will start looking back
  local headOut = clamp(math.abs(self.camRot.x) - minAngle, 0, maxAngle) / (maxAngle - minAngle) -- how much the head is looking back, from 0 to 1
  local lateralFactor = headOut
  local forwardFactor = headOut
  local verticalFactor = headOut
  local origSpawnAABB = data.veh:getSpawnLocalAABB()
  local lateralOffset = 0.1
  local forwardOffset = -0.05
  local verticalOffset = -0.02
  local lookingThroughWindow = rightHandDrive ~= (self.camRot.x > 0)
  if lookingThroughWindow then
    forwardFactor = clamp(forwardFactor * 1.75, 0, 1)
    verticalFactor = clamp(verticalFactor * 1.00, 0, 1)
    forwardOffset = -0.3
    lateralOffset = 0.5
    local min = vec3(origSpawnAABB.minExtents)
    local max = vec3(origSpawnAABB.maxExtents)
    local margin = (max.x - min.x)/2 - math.abs(self.camPosInitialLocal.x-(max.x + min.x)/2) -- distance to boundingbox lateral
    lateralOffset = math.min(0.6, margin)
    verticalOffset = -0.1
  end
  local rotationOffset = vec3(
    lateralOffset * lateralFactor * sign(-self.camRot.x), -- stick head out (or towards center)
    forwardOffset * forwardFactor,                       -- dodge the B-pillar (or bucket seat/head rest)
    verticalOffset * verticalFactor -- dodge the roof
  )

  -- apply seat adjustment
  local dx, dy, dz = 0, 0 ,0
  --if self.allowSeatAdjustments then
    dx = dxSmoother:get(MoveManager.left     - MoveManager.right  , data.dt)
    dy = dySmoother:get(MoveManager.backward - MoveManager.forward, data.dt)
    dz = dzSmoother:get(MoveManager.up       - MoveManager.down   , data.dt)
    local pdx = dx * data.dt * data.speed / 50
    local pdy = dy * data.dt * data.speed / 50
    local pdz = dz * data.dt * data.speed / 50
    local posLimit = 0.4
    self.passengerSeatPosition.x   = clamp(self.passengerSeatPosition.x + pdx, -posLimit, posLimit) --only allow left/right adjustment
    --self.passengerSeatPosition.y = clamp(self.passengerSeatPosition.y + pdy, -posLimit, posLimit)
    --self.passengerSeatPosition.z = clamp(self.passengerSeatPosition.z + pdz, -posLimit, posLimit)
  --end
  if self.saveTimeout ~= nil then
    self.saveTimeout = self.saveTimeout - data.dt
  end

  if dx ~= 0 then
    ui_message({txt='ui.camera.driverPositionAdjusted', context={vehicleName = data.veh:getJBeamFilename(), y=self.passengerSeatPosition.y, z=self.passengerSeatPosition.z}}, 2, 'cameramode')
    self.saveTimeout = 1
  end

  -- application
  data.res.pos = carPos + carDir * (combinedPos + self.passengerSeatPosition + passengerOffset + rotationOffset)
  data.res.rot = camDir

  -- save fov/seat settings on timeout
  if self.saveTimeout and self.saveTimeout <= 0 then
    local vehConfig = { self.seatRotation, self.passengerSeatPosition.y, self.passengerSeatPosition.z, self.passengerSeatPosition.x, }
    if vehConfig[1] == 0 and vehConfig[2] == 0 and vehConfig[3] == 0 and vehConfig[4] == 0 then vehConfig = nil end
    local vehicleName = data.veh:getJBeamFilename()
    local vehConfigs = settings.getValue('cameraDriverVehicleConfigs')
    if type(vehConfigs) ~= "string" then vehConfigs = "{}" end
    vehConfigs = vehConfigs:gsub("'",'"') -- fix INI values that passed through javascript (e.g. when opening Options menu)
    vehConfigs = jsonDecode(vehConfigs) -- and then deserialize, so we can follow the user settings
    vehConfigs[vehicleName] = vehConfig
    settings.setValue('cameraDriverVehicleConfigs', jsonEncode(vehConfigs))
    settings.setValue('cameraDriverFov', data.res.fov)
    self.saveTimeout = nil
  end
end

function C:setRefNodes(centerNodeID, leftNodeID, backNodeID)
  self.refNodes = self.refNodes or {}
  self.refNodes.ref = centerNodeID
  self.refNodes.left = leftNodeID
  self.refNodes.back = backNodeID
end

function C:mouseLocked(locked)
  if locked then return end
  if not self.autocenter then return end
  self.relativeYaw = 0
  self.relativePitch = 0
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
