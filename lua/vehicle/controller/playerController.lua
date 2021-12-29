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

local min = math.min
local max = math.max
local abs = math.abs
local acos = math.acos
local deg = math.deg --BeamMP
local rad = math.rad --BeamMP

local stabilizationMaxForce = 8000

--local stabilizationMaxTorque = 1500
local yawMaxForce = 100

local movementSpeedNormal = 1.8
local movementSpeedSprint = 5

local maxAllowedBallAV = 14
local maxBallTorque = 500

local ballPressureNormal = 1.0
local ballPressureCrouch = 0.5

local stabilizationNodes = {
  topCenter = 0,
  topFront = 0,
  topRear = 0,
  topLeft = 0,
  topRight = 0,
  bottomCenter = 0,
  bottomFront = 0,
  bottomRear = 0,
  bottomLeft = 0,
  bottomRight = 0
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

local ballCenterNode = -1

local ballNodes = {}
local ballGroundContactNodesNew = {}
local ballGroundContactNodesPast = {}
local ballCenterVelocity = vec3(0, 0, 0)
local ballBasedPlayerVelocity = vec3(0, 0, 0)
local ballTorqueSmoother = newTemporalSmoothing(10, 1)

local jumpForce = 50000
local jumpForceTimer = 0
local jumpForceTime = 0.01

local lockBeams = {}
local isBallLocked = false

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
  obj:getId(),
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
local cameraRotationStandardVector = vec3(0, 1, 0)
local walkVector = vec3(0, 0, 0)
local movementSpeedCoef = 0

local isTouchingWater = false
local isTouchingGround = false

local jumpCooldown = 0
local isCrouching = false
local isUnCrouching = false
local unCrouchingPressureRatio = 0

local stabilizationPIDs = {
  frontRear = newPIDParallel(2, 0.1, 0.3, -1, 1, 100, 50, -1, 1),
  leftRight = newPIDParallel(2, 0.1, 0.3, -1, 1, 100, 50, -1, 1),
  --upright = newPIDParallel(0.5, 0.1, 0.3, -1, 1, 100, 50, -1, 1),
  yaw = newPIDParallel(1, 0.5, 0.0, -1, 1)
}

--local stabilizationTorqueNodes = {}
--local stabilizationTorqueAxis = vec3(0, 0, 0)
--local stabilizationDesiredTorque = 0

local ballTorqueNodes = {}
local ballTorqueAxis = vec3(0, 0, 0)
local ballDesiredTorque = 0
local ballAVSmoother = newExponentialSmoothing(25)

--forces to be applied at physics step
--stabilization
local forceVectorFront = vec3()
local forceVectorLeft = vec3()
--yaw
local yawLeftForce = 0
local yawRightForce = 0

local function debugDraw(focusPos)
  for _, v in pairs(debugVectors) do
    obj.debugDrawProxy:drawNodeVector3d(v.thickness or 0.05, v.cid, v.vector, v.color)
  end
end

local slipUsageCoef = 1 --coef for testing different amounts of node slip compensation, we might want to not automatically compensate for slip (gameplay decision)

local function nodeCollision(p)
  --take a look at physics particles and use the node and slip velocities to estimate a ball center velocity that is local to the unicycle
  local slipVelocity = vec3(p.slipVec)
  local nodeVelocity = vec3(p.nodeVel)
  ballBasedPlayerVelocity = ballCenterVelocity - nodeVelocity + (slipVelocity * slipUsageCoef)
  table.insert(ballGroundContactNodesNew, p.id1)
end

local function applyTorque(axis, node1, node2, node3, torque)
  obj:apply3nodeTorque(axis, torque, node1, node2, node3)
end

local function applyTorque2Nodes(axis, node1, node2, torque)
  obj:apply2nodeTorque(axis, torque, node1, node2)
end

local function applyForceVector(node, forceVec)
  obj:applyForceVector(node, forceVec)
end

local function applyForce(node1, node2, force)
  obj:applyForce(node1, node2, force)
end

local function update(dt)
  --stabilization
  --applyTorque2Nodes(stabilizationTorqueAxis, stabilizationTorqueNodes[0], stabilizationTorqueNodes[1], -stabilizationDesiredTorque)

  applyForceVector(stabilizationNodes.topCenter, forceVectorFront)
  applyForceVector(stabilizationNodes.bottomCenter, -forceVectorFront)

  applyForceVector(stabilizationNodes.topCenter, forceVectorLeft)
  applyForceVector(stabilizationNodes.bottomCenter, -forceVectorLeft)

  --yaw
  applyForce(stabilizationNodes.topFront, stabilizationNodes.topLeft, yawLeftForce)
  applyForce(stabilizationNodes.topRear, stabilizationNodes.topRight, yawLeftForce)
  applyForce(stabilizationNodes.topFront, stabilizationNodes.topRight, yawRightForce)
  applyForce(stabilizationNodes.topRear, stabilizationNodes.topLeft, yawRightForce)

  --propulsion
  applyTorque(ballTorqueAxis, ballTorqueNodes[0], ballTorqueNodes[1], ballTorqueNodes[2], ballDesiredTorque)

  --jumping
  if jumpForceTimer > 0 then
    jumpForceTimer = jumpForceTimer - dt

    --local isSprinting = movementSpeedCoef > 0 and walkVector:length() > 0

    local vectorUp = obj:getBeamVectorFromNode(stabilizationBeams.bottomTop, stabilizationNodes.bottomCenter):normalized()
    obj:applyForceVector(stabilizationNodes.topCenter, (vectorUp * jumpForce))
    local ballNodeForce = jumpForce / #ballGroundContactNodesPast
    local ballNodeForceVector = (-vectorUp * ballNodeForce)
    for _, cid in ipairs(ballGroundContactNodesPast) do
      obj:applyForceVector(cid, ballNodeForceVector)
    end
  else
    jumpForceTimer = 0
  end
end

local function setBallLock(locked)
  if locked == isBallLocked then
    return
  end

  for _, cid in ipairs(lockBeams) do
    obj:setBeamLength(cid, obj:getBeamLength(cid))
    obj:setBeamSpringDamp(cid, locked and 100000 or 0, locked and 50 or 0, -1, -1)
  end

  isBallLocked = locked
end

local function updateFixedStep(dt)
  ballCenterVelocity = obj:getNodeVelocityVector(ballCenterNode)
  local enableStabilizationCoef = 1

  --actual up vector of the unicycle
  local vectorUp = obj:getBeamVectorFromNode(stabilizationBeams.bottomTop, stabilizationNodes.bottomCenter):normalized()

  -- local accVector = -vec3(obj:getNodeForceVectorNonInertialXYZ(stabilizationNodes.bottomCenter)):normalized()
  -- local forceBias = 0.0
  -- --desired up vector of the unicycle
  -- local targetVector = (vec3(0, 0, 1) * (1 - forceBias) + forceBias * accVector)

  -- stabilizationTorqueAxis = targetVector:cross(vectorUp)
  -- local stabilizationError = (targetVector - vectorUp):length()
  -- local uprightStabilizationTorqueCoef = stabilizationPIDs.upright:get(-stabilizationError, 0, dt)
  -- stabilizationDesiredTorque = uprightStabilizationTorqueCoef * stabilizationMaxTorque

  local vectorTopLeft = obj:getBeamVectorFromNode(stabilizationBeams.centerLeft, stabilizationNodes.topCenter):normalized()
  local normalLeft = vectorTopLeft:cross(-vectorUp):normalized()
  local normalRight = normalLeft:cross(vectorUp):normalized()
  local targetVector = vec3(0, 0, 1)

  local projectedVertical = (targetVector - targetVector:dot(normalLeft) * normalLeft):normalized()
  local projectedHorizontal = (targetVector - targetVector:dot(normalRight) * normalRight):normalized()

  local angleHorizontal = acos(min(max(vectorUp:dot(projectedVertical), -1), 1))
  local horizontalAngleSign = sign(normalLeft:dot(vectorUp:cross(projectedVertical)))
  local angleVertical = acos(min(max(vectorUp:dot(projectedHorizontal), -1), 1))
  local verticalAngleSign = sign(normalRight:dot(vectorUp:cross(projectedHorizontal)))

  local frontRearAngle = angleVertical * verticalAngleSign
  local leftRightAngle = angleHorizontal * horizontalAngleSign

  local forceMultiplier = stabilizationMaxForce * enableStabilizationCoef
  local frontRearForceCoef = stabilizationPIDs.frontRear:get(-frontRearAngle, 0, dt)
  local leftRightForceCoef = stabilizationPIDs.leftRight:get(-leftRightAngle, 0, dt)

  forceVectorFront = obj:getNodesVector(stabilizationNodes.topCenter, stabilizationNodes.topFront):normalized() * frontRearForceCoef * forceMultiplier
  forceVectorLeft = obj:getNodesVector(stabilizationNodes.topCenter, stabilizationNodes.topLeft):normalized() * leftRightForceCoef * forceMultiplier

  ----------------
  ---Propulsion---
  ----------------
  local frozenCoef = isFrozen and 0 or 1
  local desiredMovementSpeed = linearScale(movementSpeedCoef, 0, 1, movementSpeedNormal, movementSpeedSprint) * frozenCoef --0 movement speed when locked
  local guardedWalkVector = walkVector:z0() * frozenCoef --set this to zero if frozen to keep the ball locked
  if guardedWalkVector:length() > 1 then
    guardedWalkVector:normalize()
  end

  local desiredMovementVector = cameraRotation * guardedWalkVector * desiredMovementSpeed

  --local actualMovementVector = obj:getVelocity():z0() --used to very ball based velocity
  local actualMovementVector = ballBasedPlayerVelocity:z0()
  local movementVectorDifference = desiredMovementVector - actualMovementVector
  local actualSpeed = actualMovementVector:length()
  local speedError = max(desiredMovementSpeed - actualSpeed, 0)
  speedError = ballTorqueSmoother:getUncapped(speedError, dt)

  if guardedWalkVector:length() > 0 then
    ballTorqueAxis = (desiredMovementVector + movementVectorDifference):z0():cross(vectorUp)
    ballDesiredTorque = speedError * maxBallTorque
    setBallLock(false)
  else
    ballTorqueAxis = (cameraRotation * cameraRotationStandardVector):z0():cross(vectorUp)
    ballDesiredTorque = 0
    setBallLock(true)
  end

  local ballAV = obj:get3nodeAngularVelocity(ballTorqueAxis, ballTorqueNodes[0], ballTorqueNodes[1], ballTorqueNodes[2])
  if isnan(ballAV) then
    ballAV = 0
    ballAVSmoother:set(0)
  else
    ballAV = ballAVSmoother:get(ballAV)
  end

  local ballAVTorqueCoef = linearScale(abs(ballAV), maxAllowedBallAV, maxAllowedBallAV + 1, 1, 0)
  ballDesiredTorque = ballDesiredTorque * ballAVTorqueCoef

  local yaw = obj:getYawAngularVelocity()
  local yawForceCoef = stabilizationPIDs.yaw:get(yaw, 0, dt)
  local yawLeftForceCoef = abs(min(yawForceCoef, 0))
  local yawRightForceCoef = abs(max(yawForceCoef, 0))
  local yawForceMultiplier = yawMaxForce * enableStabilizationCoef
  yawLeftForce = (yawLeftForceCoef + linearScale(yawRightForceCoef, 0, 0.01, 0.1, 0)) * yawForceMultiplier
  yawRightForce = (yawRightForceCoef + linearScale(yawLeftForceCoef, 0, 0.01, 0.1, 0)) * yawForceMultiplier

  --table.insert(debugVectors, {cid = stabilizationNodes.topLeft, vector = vectorTopFrontLeft * yawLeftForce * 0.001, color = color(244, 93, 1, 255)})
  --table.insert(debugVectors, {cid = stabilizationNodes.topRight, vector = vectorTopRearRight * yawLeftForce * 0.001, color = color(244, 93, 1, 255)})
  --table.insert(debugVectors, {cid = stabilizationNodes.topRight, vector = vectorTopFrontRight * yawRightForce * 0.001, color = color(175, 18, 90, 255)})
  --table.insert(debugVectors, {cid = stabilizationNodes.topLeft, vector = vectorTopRearLeft * yawRightForce * 0.001, color = color(175, 18, 90, 255)})

  ----BeamMP----
  local bodyRotation = quat(obj:getRotation()):toEulerYXZ().x

  if playerInfo.anyPlayerSeated then
	  electrics.values.unicycle_camera = -cameraRotation:toEulerYXZ().x
	  electrics.values.unicycle_walk_x = guardedWalkVector.x
	  electrics.values.unicycle_walk_y = guardedWalkVector.y
	  electrics.values.unicycle_jump = jumpCooldown > 0.1
	  electrics.values.unicycle_crouch = (isCrouching and -1 or 1)
	  electrics.values.unicycle_speed = movementSpeedCoef
  end

  if bodyrotationServo and electrics.values.unicycle_camera ~= nil then -- the camera check prevents rotation errors before it recieves rotation data
    local rotatorError = bodyrotationServo.currentAngle + bodyRotation
    bodyrotationServo:setTargetAngle(((electrics.values.unicycle_camera or 0) + rotatorError) % rad(360) -rad(180))
  end

  electrics.values.unicycle_body = (deg((electrics.values.unicycle_camera or 0) + bodyRotation)+180) % 360

end

local function updateGFX(dt)
  ballGroundContactNodesPast, ballGroundContactNodesNew = ballGroundContactNodesNew, ballGroundContactNodesPast
  table.clear(ballGroundContactNodesNew)

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

  if isTouchingWater then
    ballBasedPlayerVelocity = vec3(0, 0, 0) --ball based AV doesn't work in water, make sure to reset the measured value to 0
  end

  jumpCooldown = max(jumpCooldown - dt, 0)

  electrics.values.gearboxMode = "none"
  electrics.values.freezeState = isFrozen
end

local function walkLeftRightRaw(value)
  walkVector.x = value
end

local function walkLeftRight(value)
  walkVector.x = walkVector.x + value
end

local function walkUpDownRaw(value)
  walkVector.y = value
end

local function walkUpDown(value)
  walkVector.y = walkVector.y + value
end

local function setSpeed(value)
  movementSpeedCoef = value
end

local function toggleSpeed()
  movementSpeedCoef = 1 - movementSpeedCoef
end

local function jump(value)
  if jumpCooldown > 0 or isFrozen then
    return
  end

  if #ballGroundContactNodesPast > 0 then
    jumpForceTimer = jumpForceTime
    jumpCooldown = 0.5
  end
end

local function crouch(value)
  if isFrozen then
    return
  end

  if value < 0 then
    obj:setGroupPressureRel(v.data.pressureGroups["ball"], ballPressureCrouch)
    isCrouching = true
  elseif value > 0 then
    isUnCrouching = true
    unCrouchingPressureRatio = 0.5
  end
end

local function toggleCrouch()
  if isFrozen then
    return
  end

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

  yawLeftForce = 0
  yawRightForce = 0

  stabilizationNodes.topCenter = jbeamData.stabilizationTopCenter
  stabilizationNodes.topFront = jbeamData.stabilizationTopFront
  stabilizationNodes.topRear = jbeamData.stabilizationTopRear
  stabilizationNodes.topLeft = jbeamData.stabilizationTopLeft
  stabilizationNodes.topRight = jbeamData.stabilizationTopRight

  stabilizationNodes.bottomCenter = jbeamData.stabilizationBottomCenter
  stabilizationNodes.bottomFront = jbeamData.stabilizationBottomFront
  stabilizationNodes.bottomRear = jbeamData.stabilizationBottomRear
  stabilizationNodes.bottomLeft = jbeamData.stabilizationBottomLeft
  stabilizationNodes.bottomRight = jbeamData.stabilizationBottomRight

  ballCenterNode = jbeamData.ballCenter

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
    elseif beam.tag == "lockBeam" then
      table.insert(lockBeams, beam.cid)
    end
  end

  for _, node in pairs(v.data.nodes) do
    if node.tag == "ball" then
      ballNodes[node.cid] = true
    end
    if node.name == "ib7" then
      ballTorqueNodes[0] = node.cid
    end
    if node.name == "ib2" then
      ballTorqueNodes[1] = node.cid
    end
    if node.name == "ib8" then
      ballTorqueNodes[2] = node.cid
    end

    -- if node.name == "r2" then
    --   stabilizationTorqueNodes[0] = node.cid
    -- end
    -- if node.name == "r1" then
    --   stabilizationTorqueNodes[1] = node.cid
    -- end
    -- if node.name == "bc8" then
    --   stabilizationTorqueNodes[2] = node.cid
    -- end
  end

  mapmgr.enableTracking()
  obj:setSleepingEnabled(false)

  ----beamMP----
  if powertrain.getDevice("bodyrotationServo") ~= nil then
    bodyrotationServo = powertrain.getDevice("bodyrotationServo")
  end
end

local function initLastStage()
end

local function reset()
  isFrozen = false
  isBallLocked = false
  isTouchingGround = false
  isTouchingWater = false
  isCrouching = false
  isUnCrouching = false
  jumpCooldown = 0

  forceVectorFront = vec3()
  forceVectorLeft = vec3()

  yawLeftForce = 0
  yawRightForce = 0

  walkVector = vec3(0, 0, 0)
  ballTorqueAxis = vec3(0, 0, 0)
  stabilizationPIDs.frontRear:reset()
  stabilizationPIDs.leftRight:reset()
  --stabilizationPIDs.upright:reset()
  stabilizationPIDs.yaw:reset()

  ----beamMP----
  if powertrain.getDevice("bodyrotationServo") ~= nil then
    bodyrotationServo = powertrain.getDevice("bodyrotationServo")
  end
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

M.nodeCollision = nodeCollision

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

M.debugDraw = debugDraw

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
