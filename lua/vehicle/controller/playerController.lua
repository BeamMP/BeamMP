-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
--Mandatory controller parameters
M.type = "main"
M.relevantDevice = nil
M.defaultOrder = 500

M.fireEngineTemperature = 0
M.throttle = 0
M.brake = 0
M.clutchRatio = 0
-----

--local settings = require("simplesettings")

local min = math.min
local max = math.max
local abs = math.abs
local acos = math.acos
local atan2 = math.atan2

local pi = math.pi
local halfPi = pi * 0.5
local twoPi = pi * 2

local stabilizationMaxForce = 8000
local propulsionMaxForce = 2000
local positionHoldingMaxForce = 1500
local yawMaxForce = 100

local movementSpeedNormal = 1.8
local movementSpeedSprint = 5

local ballPressureNormal = 1
local ballPressureCrouch = 0.5
local ballPressurePreJump = 0.7
local ballPressureJump = 1.5
local ballPressurePreSprintJump = 1.0
local ballPressureSprintJump = 3.5

local propulsionNodes = {
  center = 0,
  front = 0,
  rear = 0,
  left = 0,
  right = 0
}

local stabilizationNodes = {
  center = 0,
  front = 0,
  rear = 0,
  left = 0,
  right = 0
}

local stabilizationBeams = {
  bottomTop = 0,
  centerFront = 0,
  centerRear = 0,
  centerLeft = 0,
  centerRight = 0,
  frontLeft = 0,
  frontRight = 0,
  rearLeft = 0,
  rearRight = 0
}

local ballNodes = {}

M.engineInfo = {
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  "manual",
  obj:getID(),
  0,
  0,
  1,
  0,
  0,
  0
}

local isFrozen = false

local debugVectors = {}
local cameraRotation = quat(0, 0, 0, 0)
local walkVector = vec3(0, 0, 0)
local movementDirectionVector = vec3(0, 0, 0)
local movementSpeedCoef = 0
local movementTargetVector

local targetPosition = nil
local lastPosition = nil

local hasGroundContactTimer = 0
local hasVehicleContactTimer = 0
local isFlyingTimer = 0
local isTouchingWater = false
local isTouchingGround = false
local isTouchingVehicle = false
local isFlying = false
local touchedVehicleVelocity = vec3(0, 0, 0)

local jumpTimer = 0
local jumpCooldown = 0
local isPreparingJump = false
local isCrouching = false
local isUnCrouching = false
local unCrouchingPressureRatio = 0

local isCommandingMoveTimer = 0
local isCommandingMoveTime = 4 / movementSpeedSprint -- a bit less than 1s at full speed

local stabilizationForcePIDs = {
  frontRear = newPIDParallel(1, 0.1, 0.3, -1, 1, 100, 50, -1, 1),
  leftRight = newPIDParallel(1, 0.1, 0.3, -1, 1, 100, 50, -1, 1),
  yaw = newPIDParallel(1, 0.5, 0.0, -1, 1)
}

local propulsionPID = newPIDParallel(0.5, 0.2, 0.0, -1, 1, 20, 20, -1, 1)
local positionHoldingPID = newPIDParallel(0.1, 0.5, 0.05, -1, 1, 2000, 2000, -1, 1)

--forces to be applied at physics step
--stabilization
local frontRearForce = 0
local leftRightForce = 0
--yaw
local yawLeftForce = 0
local yawRightForce = 0
--propulsion
local forceFront = 0
local forceRear = 0
local forceLeft = 0
local forceRight = 0

local function debugDraw(focusPos)
  for _, v in pairs(debugVectors) do
    obj.debugDrawProxy:drawNodeVector3d(v.thickness or 0.05, v.cid, (v.vector):toFloat3(), v.color)
  end

  if movementTargetVector then
    obj.debugDrawProxy:drawNodeVector3d(0.05, stabilizationNodes.center, (-movementTargetVector):toFloat3(), color(55, 114, 255, 255))
  end
end

local function applyForce(node1, node2, force)
  obj:applyForce(node1, node2, force)
end

local function update(dt)
  --stabilization
  applyForce(stabilizationNodes.front, stabilizationNodes.center, -frontRearForce)
  applyForce(stabilizationNodes.left, stabilizationNodes.center, -leftRightForce)

  --yaw
  applyForce(stabilizationNodes.front, stabilizationNodes.left, yawLeftForce)
  applyForce(stabilizationNodes.rear, stabilizationNodes.right, yawLeftForce)
  applyForce(stabilizationNodes.front, stabilizationNodes.right, yawRightForce)
  applyForce(stabilizationNodes.rear, stabilizationNodes.left, yawRightForce)

  --propulsion
  applyForce(propulsionNodes.front, propulsionNodes.center, forceFront)
  applyForce(propulsionNodes.rear, propulsionNodes.center, forceRear)
  applyForce(propulsionNodes.left, propulsionNodes.center, forceLeft)
  applyForce(propulsionNodes.right, propulsionNodes.center, forceRight)
end

local function updateFixedStep(dt)
  --TODO: IF touching vehicle, calculate relative velocity by looking at node velocity of touching ball nodes, possibly acocunt for slippage by looking at node slip velocity
  --TODO IF in the air, switch to a torque based stabilization system

  local currentVelocityZ0 = vec3(obj:getVelocity()):z0()

  --local enableStabilizationCoef = (hasGroundContactTimer > 0) and 1 or 0
  --local enableStabilizationCoef = linearScale(currentVelocityZ0:length(), 30, 50, 1, 0)
  local enableStabilizationCoef = isFlyingTimer > 3 and 0 or 1
  local enableSpeedHoldingCoef = walkVector:length() == 0 and 0 or 1
  local enablePositionHoldingCoef = (hasGroundContactTimer > 0 and walkVector:length() == 0 and hasVehicleContactTimer <= 0) and 1 or 0

  local vectorUp = vec3(obj:getBeamVectorFromNode(stabilizationBeams.bottomTop, propulsionNodes.center)):normalized()

  local vectorTopFront = vec3(obj:getBeamVectorFromNode(stabilizationBeams.centerFront, stabilizationNodes.center)):normalized()
  local vectorTopLeft = vec3(obj:getBeamVectorFromNode(stabilizationBeams.centerLeft, stabilizationNodes.center)):normalized()

  --used for debug draw
  --local vectorTopFrontLeft = -vec3(obj:getBeamVectorFromNode(stabilizationBeams.frontLeft, stabilizationNodes.front)):normalized()
  --local vectorTopFrontRight = -vec3(obj:getBeamVectorFromNode(stabilizationBeams.frontRight, stabilizationNodes.front)):normalized()
  --local vectorTopRearLeft = -vec3(obj:getBeamVectorFromNode(stabilizationBeams.rearLeft, stabilizationNodes.rear)):normalized()
  --local vectorTopRearRight = -vec3(obj:getBeamVectorFromNode(stabilizationBeams.rearRight, stabilizationNodes.rear)):normalized()

  local normalLeft = vectorTopLeft:cross(-vectorUp):normalized()
  local normalRight = normalLeft:cross(vectorUp):normalized()
  local targetVector = vec3(0, 0, 1)

  local projectedVertical = (targetVector - targetVector:dot(normalLeft) * normalLeft):normalized()
  local projectedHorizontal = (targetVector - targetVector:dot(normalRight) * normalRight):normalized()

  local angleHorizontal = acos(min(max(vectorUp:dot(projectedVertical), -1), 1))
  local horizontalAngleSign = fsign(normalLeft:dot(vectorUp:cross(projectedVertical)))
  local angleVertical = acos(min(max(vectorUp:dot(projectedHorizontal), -1), 1))
  local verticalAngleSign = fsign(normalRight:dot(vectorUp:cross(projectedHorizontal)))

  local frontRearAngle = angleVertical * verticalAngleSign
  local leftRightAngle = angleHorizontal * horizontalAngleSign

  local forceMultiplier = stabilizationMaxForce * enableStabilizationCoef
  local frontRearForceCoef = stabilizationForcePIDs.frontRear:get(-frontRearAngle, 0, dt)
  local leftRightForceCoef = stabilizationForcePIDs.leftRight:get(-leftRightAngle, 0, dt)

  frontRearForce = frontRearForceCoef * forceMultiplier
  leftRightForce = leftRightForceCoef * forceMultiplier

  debugVectors = {}

  --table.insert(debugVectors, {cid = stabilizationNodes.center, vector = vectorTopFront * frontRearForce * 0.001, color = color(55, 114, 255, 255)})
  --table.insert(debugVectors, {cid = stabilizationNodes.center, vector = vectorTopLeft * leftRightForce * 0.001, color = color(253, 202, 64, 255)})

  -- table.insert(debugVectors, {cid = stabilizationNodes.center, vector = normalLeft, color = color(255, 0, 0, 255)})
  -- table.insert(debugVectors, {cid = stabilizationNodes.center, vector = normalRight, color = color(0, 255, 0, 255)})
  --table.insert(debugVectors, {cid = stabilizationNodes.center, vector = vectorUp * 5, color = color(128, 128, 0, 255)})
  -- table.insert(debugVectors, {cid = stabilizationNodes.center, vector = projectedVertical * 5, color = color(0, 128, 0, 255)})
  -- table.insert(debugVectors, {cid = stabilizationNodes.center, vector = projectedHorizontal * 5, color = color(128, 0, 0, 255)})
  --table.insert(debugVectors, {cid = stabilizationNodes.center, vector = targetVector, color = color(0, 0, 255, 255), thickness = 0.05})

  ----------------
  ---Propulsion---
  ----------------
  local currentPosition = vec3(obj:getPosition()):z0()
  local positionDifference = (targetPosition - currentPosition) * enablePositionHoldingCoef
  --dump(positionDifference)

  local desiredMovementSpeed = linearScale(movementSpeedCoef, 0, 1, movementSpeedNormal, movementSpeedSprint)
  local guardedWalkVector = walkVector:z0()
  if guardedWalkVector:length() > 1 then
    guardedWalkVector:normalize()
  end
  if cameraRotation then
    movementDirectionVector = (cameraRotation * guardedWalkVector)
  --:normalized()
  end
  local targetDirection = -movementDirectionVector * desiredMovementSpeed
  local velocityVectorZ0 = (-currentVelocityZ0 + touchedVehicleVelocity) * enableSpeedHoldingCoef
  targetDirection = targetDirection + -velocityVectorZ0 - positionDifference
  movementTargetVector = targetDirection --for debug renderer
  local topFrontZ0Normalized = vectorTopFront:z0():normalized()
  local propulsionAngle = atan2(targetDirection:normalized().y, targetDirection:normalized().x) - atan2(topFrontZ0Normalized.y, topFrontZ0Normalized.x)
  if propulsionAngle > twoPi then
    propulsionAngle = propulsionAngle - twoPi
  end
  if propulsionAngle < 0 then
    propulsionAngle = propulsionAngle + twoPi
  end
  propulsionAngle = propulsionAngle - pi

  forceFront = 0
  forceRear = 0
  forceLeft = 0
  forceRight = 0

  if (propulsionAngle <= -halfPi and propulsionAngle >= -pi) or (propulsionAngle <= pi and propulsionAngle >= halfPi) then
    forceFront = linearScale(abs(propulsionAngle), pi, halfPi, 1, 0)
  end

  if propulsionAngle <= halfPi and propulsionAngle >= -halfPi then
    forceRear = linearScale(abs(propulsionAngle), 0, halfPi, 1, 0)
  end

  if propulsionAngle <= 0 and propulsionAngle >= -halfPi then
    forceLeft = linearScale(propulsionAngle, -halfPi, 0, 1, 0)
  end

  if propulsionAngle <= -halfPi and propulsionAngle >= -pi then
    forceLeft = linearScale(propulsionAngle, -halfPi, -pi, 1, 0)
  end

  if propulsionAngle >= 0 and propulsionAngle <= halfPi then
    forceRight = linearScale(propulsionAngle, halfPi, 0, 1, 0)
  end

  if propulsionAngle >= halfPi and propulsionAngle <= pi then
    forceRight = linearScale(propulsionAngle, halfPi, pi, 1, 0)
  end

  local propulsionForceLimitCoef = 0
  if enableSpeedHoldingCoef > 0 or guardedWalkVector:length() > 0 then
    local speedError = ((-movementDirectionVector * desiredMovementSpeed) - -velocityVectorZ0):length()
    propulsionForceLimitCoef = -propulsionPID:get(speedError, 0, dt) * enableStabilizationCoef * propulsionMaxForce
  end

  if enablePositionHoldingCoef > 0 then
    local positionError = targetDirection:length()
    propulsionForceLimitCoef = -positionHoldingPID:get(positionError, 0, dt) * enableStabilizationCoef * positionHoldingMaxForce
  else
    positionHoldingPID:reset()
  end

  forceFront = forceFront * propulsionForceLimitCoef
  forceRear = forceRear * propulsionForceLimitCoef
  forceLeft = forceLeft * propulsionForceLimitCoef
  forceRight = forceRight * propulsionForceLimitCoef

  -- table.insert(debugVectors, {cid = stabilizationNodes.center, vector = vectorTopFront * forceFront * 0.001, color = color(55, 114, 255, 255)})
  -- table.insert(debugVectors, {cid = stabilizationNodes.center, vector = vectorTopLeft * forceLeft * 0.001, color = color(253, 202, 64, 255)})
  -- table.insert(debugVectors, {cid = stabilizationNodes.center, vector = -vectorTopFront * forceRear * 0.001, color = color(55, 114, 255, 255)})
  -- table.insert(debugVectors, {cid = stabilizationNodes.center, vector = -vectorTopLeft * forceRight * 0.001, color = color(253, 202, 64, 255)})

  local yaw = obj:getYawAngularVelocity()
  local yawForceCoef = stabilizationForcePIDs.yaw:get(yaw, 0, dt)
  local yawLeftForceCoef = abs(min(yawForceCoef, 0))
  local yawRightForceCoef = abs(max(yawForceCoef, 0))
  local yawForceMultiplier = yawMaxForce * enableStabilizationCoef
  yawLeftForce = (yawLeftForceCoef + linearScale(yawRightForceCoef, 0, 0.01, 0.1, 0)) * yawForceMultiplier
  yawRightForce = (yawRightForceCoef + linearScale(yawLeftForceCoef, 0, 0.01, 0.1, 0)) * yawForceMultiplier

  --table.insert(debugVectors, {cid = stabilizationNodes.left, vector = vectorTopFrontLeft * yawLeftForce * 0.001, color = color(244, 93, 1, 255)})
  --table.insert(debugVectors, {cid = stabilizationNodes.right, vector = vectorTopRearRight * yawLeftForce * 0.001, color = color(244, 93, 1, 255)})
  --table.insert(debugVectors, {cid = stabilizationNodes.right, vector = vectorTopFrontRight * yawRightForce * 0.001, color = color(175, 18, 90, 255)})
  --table.insert(debugVectors, {cid = stabilizationNodes.left, vector = vectorTopRearLeft * yawRightForce * 0.001, color = color(175, 18, 90, 255)})
end

local function updateGFX(dt)
  isCommandingMoveTimer = max(isCommandingMoveTimer - dt, 0)

  if jumpTimer > 0 then
    jumpTimer = max(jumpTimer - dt, 0)
    if jumpTimer <= 0 then
      obj:setGroupPressureRel(v.data.pressureGroups["ball"], ballPressureNormal)
    end
  end

  if isUnCrouching then
    unCrouchingPressureRatio = min(unCrouchingPressureRatio + dt * 2, ballPressureNormal)
    obj:setGroupPressureRel(v.data.pressureGroups["ball"], unCrouchingPressureRatio)
    if unCrouchingPressureRatio >= 1 then
      isUnCrouching = false
      isCrouching = false
    end
  end

  isTouchingWater = false
  isTouchingGround = false
  for nodeCid, _ in pairs(ballNodes) do
    isTouchingWater = isTouchingWater or obj:inWater(nodeCid)
    isTouchingGround = isTouchingGround or obj:isNodeColliding(nodeCid)
  end
  isTouchingVehicle = #mapmgr.objectCollisionIds > 0

  if isTouchingGround or isTouchingWater then
    hasGroundContactTimer = 0.5
  end

  touchedVehicleVelocity = vec3(0, 0, 0)
  if isTouchingVehicle then
    hasVehicleContactTimer = 1
    for _, id in ipairs(mapmgr.objectCollisionIds) do
      if mapmgr.objects[id] and mapmgr.objects[id].vel then
        local velocity = mapmgr.objects[id].vel
        if velocity:length() > touchedVehicleVelocity:length() then
          touchedVehicleVelocity = velocity
        end
      end
    end
  end

  local positionBasedSpeed = 0
  local currentPosition = vec3(obj:getPosition()):z0()
  if lastPosition then
    positionBasedSpeed = (lastPosition - currentPosition):length() / dt
  end

  isFlying = not isTouchingGround and not isTouchingWater and not isTouchingVehicle

  if walkVector:length() > 0 or hasVehicleContactTimer > 0 or isCommandingMoveTimer > 0 or isFlying or positionBasedSpeed > movementSpeedSprint * 10 or not targetPosition then
    targetPosition = vec3(obj:getPosition()):z0()
  end

  local bodyRotation = -cameraRotation:toEulerYXZ().x
  local vectorTopFront = vec3(obj:getBeamVectorFromNode(stabilizationBeams.centerFront, stabilizationNodes.center)):z0():normalized()
  local bodyQuat = quatFromDir(vectorTopFront, vec3(0,0,1))
  local bodyAngle = -bodyQuat:toEulerYXZ().x
  --local test = (atan2(vectorTopFront:cross(vec3(0, 1, 0)):dot(vec3(0, 0, 1)), vectorTopFront:dot(vec3(0, 1, 0))))
  --dump(test)
  if v.mpVehicleType == "L" then
    electrics.values.unicycle_body = math.deg(bodyRotation - bodyAngle)+45
    electrics.values.unicycle_camera = bodyRotation
  else
    electrics.values.unicycle_body = math.deg((electrics.values.unicycle_camera or 0) - bodyAngle)+45
  end
  --dump(cameraRotation)

  --local currentBallPressure = obj:getGroupPressure(v.data.pressureGroups["ball"])
  --local currentEnvPressure = obj:getEnvPressure()
  --local overPressure = currentBallPressure - currentEnvPressure

  hasGroundContactTimer = max(0, hasGroundContactTimer - dt)
  hasVehicleContactTimer = max(0, hasVehicleContactTimer - dt)
  if isFlying then
    isFlyingTimer = isFlyingTimer + dt
  else
    isFlyingTimer = 0
    jumpCooldown = max(jumpCooldown - dt, 0)
  end
  lastPosition = currentPosition
end

local function walkLeftRightRaw(value)
  walkVector.x = value
  isCommandingMoveTimer = isCommandingMoveTime
end

local function walkLeftRight(value)
  walkVector.x = walkVector.x + value
  isCommandingMoveTimer = isCommandingMoveTime
end

local function walkUpDownRaw(value)
  walkVector.y = value
  isCommandingMoveTimer = isCommandingMoveTime
end

local function walkUpDown(value)
  walkVector.y = walkVector.y + value
  isCommandingMoveTimer = isCommandingMoveTime
end

local function setSpeed(value)
  movementSpeedCoef = value
end

local function toggleSpeed()
  movementSpeedCoef = 1 - movementSpeedCoef
end

local function jump(value)
  if jumpCooldown > 0 then
    return
  end

  local isSprinting = movementSpeedCoef > 0 and walkVector:length() > 0
  if value < 0 then
    obj:setGroupPressureRel(v.data.pressureGroups["ball"], isSprinting and ballPressurePreSprintJump or ballPressurePreJump)
    isPreparingJump = true
  elseif value > 0 and isPreparingJump then
    obj:setGroupPressureRel(v.data.pressureGroups["ball"], isSprinting and ballPressureSprintJump or ballPressureJump)
    jumpTimer = 0.15
    jumpCooldown = 0.5
    isCommandingMoveTimer = isCommandingMoveTime
    isPreparingJump = false
  end
end

local function crouch(value)
  if value < 0 then
    obj:setGroupPressureRel(v.data.pressureGroups["ball"], ballPressureCrouch)
    isCrouching = true
  elseif value > 0 then
    isUnCrouching = true
    unCrouchingPressureRatio = 0.5
  end
end

local function toggleCrouch()
  electrics.values.isCrouching = isCrouching
  isCrouching = not isCrouching
  crouch(isCrouching and -1 or 1)
end

local function setFreeze(mode)
  isFrozen = mode == 1
end

local function settingsChanged(noRefresh)
end

local function init(jbeamData)
  isCrouching = false
  isUnCrouching = false
  jumpTimer = 0

  frontRearForce = 0
  leftRightForce = 0
  yawLeftForce = 0
  yawRightForce = 0
  forceFront = 0
  forceRear = 0
  forceLeft = 0
  forceRight = 0

  propulsionNodes.center = jbeamData.propulsionCenter
  propulsionNodes.front = jbeamData.propulsionFront
  propulsionNodes.rear = jbeamData.propulsionRear
  propulsionNodes.left = jbeamData.propulsionLeft
  propulsionNodes.right = jbeamData.propulsionRight

  stabilizationNodes.center = jbeamData.stabilizationCenter
  stabilizationNodes.front = jbeamData.stabilizationFront
  stabilizationNodes.rear = jbeamData.stabilizationRear
  stabilizationNodes.left = jbeamData.stabilizationLeft
  stabilizationNodes.right = jbeamData.stabilizationRight

  for _, beam in pairs(v.data.beams) do
    if beam.tag == jbeamData.stabilizationBeamFront then
      stabilizationBeams.centerFront = beam.cid
    elseif beam.tag == jbeamData.stabilizationBeamRear then
      stabilizationBeams.centerRear = beam.cid
    elseif beam.tag == jbeamData.stabilizationBeamLeft then
      stabilizationBeams.centerLeft = beam.cid
    elseif beam.tag == jbeamData.stabilizationBeamRight then
      stabilizationBeams.centerRight = beam.cid
    elseif beam.tag == jbeamData.stabilizationBeamFrontLeft then
      stabilizationBeams.frontLeft = beam.cid
    elseif beam.tag == jbeamData.stabilizationBeamFrontRight then
      stabilizationBeams.frontRight = beam.cid
    elseif beam.tag == jbeamData.stabilizationBeamRearLeft then
      stabilizationBeams.rearLeft = beam.cid
    elseif beam.tag == jbeamData.stabilizationBeamRearRight then
      stabilizationBeams.rearRight = beam.cid
    elseif beam.tag == jbeamData.stabilizationBeamBottomTop then
      stabilizationBeams.bottomTop = beam.cid
    end
  end

  for _, node in pairs(v.data.nodes) do
    if node.tag == "ball" then
      ballNodes[node.cid] = true
    end
  end

  targetPosition = nil

  mapmgr.enableTracking()
  obj:setSleepingEnabled(false)
end

local function initLastStage()
end

local function reset()
  isFlying = false
  isTouchingVehicle = false
  isTouchingGround = false
  isTouchingWater = false
  isCrouching = false
  isUnCrouching = false
  jumpTimer = 0
  isCommandingMoveTimer = 0
  lastPosition = nil
  jumpCooldown = 0
  isPreparingJump = false

  frontRearForce = 0
  leftRightForce = 0
  yawLeftForce = 0
  yawRightForce = 0
  forceFront = 0
  forceRear = 0
  forceLeft = 0
  forceRight = 0

  targetPosition = nil

  walkVector = vec3(0, 0, 0)
  stabilizationForcePIDs.frontRear:reset()
  stabilizationForcePIDs.leftRight:reset()
  stabilizationForcePIDs.yaw:reset()
  propulsionPID:reset()
  positionHoldingPID:reset()
end

local function vehicleActivated()
  if not playerInfo.firstPlayerSeated then
    return
  end
end

local function onDeserialize(data)
end

local function onSerialize()
end

local function setCameraControlData(controlData)
  cameraRotation = controlData.cameraRotation
end

M.init = init
M.initLastStage = initLastStage
M.reset = reset
M.updateFixedStep = updateFixedStep
M.updateGFX = updateGFX
M.update = update
M.settingsChanged = settingsChanged

M.onDeserialize = onDeserialize
M.onSerialize = onSerialize

M.setAggressionOverride = nop
M.setDefaultForwardMode = nop

--M.nodeCollision = nodeCollision

--Mandatory main controller API
M.shiftUp = nop
M.shiftDown = nop
M.shiftToGearIndex = nop
M.cycleGearboxModes = nop
M.setGearboxMode = nop
M.smartParkingBrake = nop
M.setStarter = nop
M.setEngineIgnition = nop
M.setFreeze = setFreeze
M.sendTorqueData = nop
M.vehicleActivated = vehicleActivated
-------------------------------

--M.debugDraw = debugDraw

M.setCameraControlData = setCameraControlData
M.jump = jump
M.walkLeftRightRaw = walkLeftRightRaw
M.walkLeftRight = walkLeftRight
M.walkUpDownRaw = walkUpDownRaw
M.walkUpDown = walkUpDown
M.setSpeedCoef = setSpeed
M.toggleSpeedCoef = toggleSpeed
M.crouch = crouch
M.toggleCrouch = toggleCrouch

return M
