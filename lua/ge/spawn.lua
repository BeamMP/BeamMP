-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M  = {}

local min = math.min
local max = math.max
local abs = math.abs

local logTag = 'spawn.lua'

local initialBB

-- safe teleport data
local shortestSideHalfLength
local sideHalfLengthX
local sideHalfLengthY
local vehicleNodes = {}
local boundingBoxCache = {}
local visibilityPoint
local smallVehicle = false
local checkOnlyStatics
local removeTraffic = true
local recursionLimitReached
local airSpawn = false
local vehiclesPositionedThisFrame = {}
local vehiclesWerePositionedThisFrame

local localVehForward = vec3(0, -1, 0)
local localVehUp = vec3(0, 0, 1)

local function clearCache()
  if vehiclesWerePositionedThisFrame then
    table.clear(vehiclesPositionedThisFrame)
    vehiclesWerePositionedThisFrame = false
  end
end

local function getNodesInCluster(veh, nodeId)
  local nodes = veh:getNodeClusters()
  local targetClusterId = nodes[nodeId + 1]
  local res = {}
  for index, clusterId in ipairs(nodes) do
    if clusterId == targetClusterId then
      table.insert(res, index - 1)
    end
  end
  return res
end

local function buildClusterBoundingBox(veh)
  local nodesInMainCluster = getNodesInCluster(veh, veh:getRefNodeId())
  local nodePositions = {}
  local vehRot = quat(veh:getClusterRotationSlow(veh:getRefNodeId()))

  for _, nodeId in ipairs(nodesInMainCluster) do
    if veh:getInitialNodeCollision(nodeId) == 3 then
      table.insert(nodePositions, veh:getNodePosition(nodeId))
    end
  end

  -- rotate all nodes by the inverse of the vehicle rot
  local localBB = Box3F()
  for i, nodePosition in ipairs(nodePositions) do
    nodePositions[i] = vehRot:inversed() * nodePosition
    localBB:extend(nodePositions[i])
  end

  local boundingBox = OrientedBox3F()
  local matFromRot = QuatF(vehRot.x, vehRot.y, vehRot.z, vehRot.w):getMatrix()
  matFromRot:setColumn(3, veh:getPosition() + (vehRot * localBB:getCenter()))
  boundingBox:set2(matFromRot, localBB:getExtents())

  return boundingBox
end

-- Invalid boxes might have very small or very big values. This is checking for that
local function boxValid(box)
  local extents = box:getExtents()
  return extents.x > 0.0001 and extents.y > 0.0001 and extents.z > 0.0001 and extents.x < 1e10 and extents.y < 1e10 and extents.z < 1e10
end

local function buildBoundingBox(veh)
  if not boxValid(veh.initialCollidableNodePosBB) then return end
  local cachedTransform = vehiclesPositionedThisFrame[veh:getId()]
  local pos = cachedTransform and cachedTransform.pos or veh:getPosition()
  local rot = cachedTransform and cachedTransform.rot or quat(veh:getRotation())
  local boundingBox = OrientedBox3F()
  local mat = MatrixF()

  local forward = -(rot * localVehForward)
  local up = rot * localVehUp

  local center = rot * veh.initialCollidableNodePosBB:getCenter()
  local refnode = rot * veh:getInitialNodePosition(veh:getRefNodeId())
  local centerToRefnode = refnode - center
  local right = forward:cross(up):normalized()
  mat:setColumn(0, right)
  mat:setColumn(1, forward)
  mat:setColumn(2, up)
  mat:setColumn(3, (pos - centerToRefnode))
  boundingBox:set2(mat, veh.initialCollidableNodePosBB:getExtents())
  return boundingBox, forward, right
end

local function intersectingOtherVehicle(otherVeh, axis0, axis1, axis2, halfExtentsX, halfExtentsY, halfExtentsZ, bbCenter)
  if not otherVeh then return false end
  local otherVehAxis1, otherVehAxis2, otherVehAxis3
  local otherBBHalfExtents
  local otherBBCenter
  local otherNodeCount = otherVeh:getNodeCount()

  if otherNodeCount == 0 or vehiclesPositionedThisFrame[otherVeh:getId()] then -- if the other vehicle was also spawned in this frame, we need to build the BB ourselves
    boundingBoxCache[otherVeh:getId()] = boundingBoxCache[otherVeh:getId()] or buildBoundingBox(otherVeh)
    local oobb = boundingBoxCache[otherVeh:getId()]
    if not oobb then return false end -- this can be nil if the bounding box is invalid
    otherVehAxis1, otherVehAxis2, otherVehAxis3 = oobb:getAxis(0), oobb:getAxis(1), oobb:getAxis(2)
    otherBBHalfExtents = oobb:getHalfExtents()
    otherBBCenter = oobb:getCenter()
  else
    local otherBB = otherVeh:getWorldBox()
    otherVehAxis1, otherVehAxis2, otherVehAxis3 = vec3(1,0,0), vec3(0,1,0), vec3(0,0,1)
    otherBBHalfExtents = otherBB:getExtents() / 2
    otherBBCenter = otherBB:getCenter()
  end

  if overlapsOBB_OBB(bbCenter, axis0 * halfExtentsX, axis1 * halfExtentsY, axis2 * halfExtentsZ, otherBBCenter, otherVehAxis1 * otherBBHalfExtents.x, otherVehAxis2 * otherBBHalfExtents.y, otherVehAxis3 * otherBBHalfExtents.z) then
    local vehID = otherVeh:getId()

    if otherNodeCount == 0 or vehiclesPositionedThisFrame[vehID] then -- if the otherVeh doesnt have nodes, we only go by the BB
      return true
    end

    if not vehicleNodes[vehID] then
      vehicleNodes[vehID] = {}
      local vehPos = otherVeh:getPosition()
      for nodeId = 0, otherNodeCount - 1 do
        table.insert(vehicleNodes[vehID], otherVeh:getNodePosition(nodeId) + vehPos)
      end
    end
    local newVehicleBBMaxExtents = vec3(halfExtentsX, halfExtentsY, halfExtentsZ):length()

    for _, nodePos in ipairs(vehicleNodes[vehID]) do
      if smallVehicle then
        if nodePos:distance(bbCenter) < max(newVehicleBBMaxExtents, 0.5) then
          return true
        end
      else
        if containsOBB_point(bbCenter, axis0 * halfExtentsX, axis1 * halfExtentsY, axis2 * halfExtentsZ, nodePos) then
          return true
        end
      end
    end
  end
  return false
end

local function moveTrafficVehiclesAway(bb, vehID)
  local vehRadius = bb:getHalfExtents():len()
  local bbCenter = bb:getCenter()
  local axis0, axis1, axis2 = bb:getAxis(0), bb:getAxis(1), bb:getAxis(2)
  local halfExtentsX, halfExtentsY, halfExtentsZ = bb:getHalfExtents().x, bb:getHalfExtents().y, bb:getHalfExtents().z

  for _, otherId in ipairs(gameplay_traffic.getTrafficList()) do
    if otherId ~= vehID and (not map.isCrashAvoidable(otherId, bbCenter, vehRadius) or intersectingOtherVehicle(be:getObjectByID(otherId), axis0, axis1, axis2, halfExtentsX, halfExtentsY, halfExtentsZ, bbCenter)) then
      gameplay_traffic.forceTeleport(otherId, bbCenter)
    end
  end
end

local seed = vec3(math.random(), math.random(), math.random())
local function getVisibilityStatus(intendedPos, testBB)
  local visibleToDirection
  local visibleFromDirection
  local bbCenter = testBB:getCenter()
  for i = 1, 10 do
    local randPoint = seed:getBluePointInSphere(shortestSideHalfLength) + bbCenter
    local rayDir = randPoint - intendedPos
    local rayLength = rayDir:length()
    if castRayStatic(intendedPos, rayDir, rayLength) >= rayLength then
      visibleToDirection = true
    end
    if castRayStatic(randPoint, -rayDir, rayLength) >= rayLength then
      visibleFromDirection = true
    end
    if visibleToDirection and visibleFromDirection then
      break
    end
  end

  if visibleToDirection ~= visibleFromDirection then
    -- If it's only visible in one direction, one of the points is inside a wall
    return 0
  elseif visibleToDirection and visibleFromDirection then
    -- It is visible in both directions
    return 2
  else
    -- Both directions are not visible, so something is in the way
    return 1
  end
end

local function isIntersecting(newVehBB, newVehID)
  local axis0, axis1, axis2 = newVehBB:getAxis(0), newVehBB:getAxis(1), newVehBB:getAxis(2)
  local halfExtentsX, halfExtentsY, halfExtentsZ = newVehBB:getHalfExtents().x, newVehBB:getHalfExtents().y, newVehBB:getHalfExtents().z
  local newVehCenter = newVehBB:getCenter()

  -- Intersecting other vehicles?
  if not checkOnlyStatics then
    for vehId, veh in activeVehiclesIterator() do
      if vehId ~= newVehID and not (gameplay_traffic and removeTraffic and arrayFindValueIndex(gameplay_traffic.getTrafficList(), vehId)) then
        if intersectingOtherVehicle(veh, axis0, axis1, axis2, halfExtentsX, halfExtentsY, halfExtentsZ, newVehCenter) then
          return true
        end
      end
    end
  end
  -- Intersecting static objects?
  local startPosBase = newVehCenter - (axis2 * (abs(halfExtentsZ) * 0.5)) -- The height of the raycasts is half the height of the bb center
  for x = -1, 1 do
    for y = -1, 1 do
      if (y == 0 or x == 0) and not (y == 0 and x == 0) then -- (x == 0) xor (y == 0)
        local halfDist
        local startPosOffset
        if x ~= 0 then
          halfDist = abs(halfExtentsX)
          startPosOffset = axis1 * halfExtentsY
        else
          halfDist = abs(halfExtentsY)
          startPosOffset = axis0 * halfExtentsX
        end
        local startPos = startPosBase - ((axis0 * x + axis1 * y) * halfDist)
        for i = -1, 1, 0.2/startPosOffset:length() do -- this starts a ray every 20cm at each side of the vehicle
          if castRayStatic((startPos + startPosOffset * i), (axis0 * x + axis1 * y), halfDist * 2) < halfDist * 2 then
            return true
          end
        end
        -- One more raycast with i=1
        if castRayStatic((startPos + startPosOffset), (axis0 * x + axis1 * y), halfDist * 2) < halfDist * 2 then
          return true
        end
      end
    end
  end
  return false
end

local function getAutoplaceRange(vehBB)
  local halfExtentsZ = vehBB:getHalfExtents().z
  local vehicleHeight = halfExtentsZ * 2
  local rayDist = clamp(10 * vehicleHeight, 10, 50)
  return rayDist
end

local rayCastStartPositionFactor = 0.4
local function moveBBToGround(vehBB, raycastDown)
  -- Turn it around if upside down
  if vehBB:getAxis(2):dot(vec3(0, 0, 1)) < 0 then
    local mat = vehBB:getMatrix()
    mat:setColumn(0, -mat:getColumn(0))
    mat:setColumn(2, -mat:getColumn(2))
    mat:setColumn(3, vehBB:getCenter())
    vehBB:set2(mat, vehBB:getHalfExtents() * 2)
  end

  local axis0, axis1, axis2 = vehBB:getAxis(0), vehBB:getAxis(1), vehBB:getAxis(2)
  local halfExtentsX, halfExtentsY, halfExtentsZ = abs(vehBB:getHalfExtents().x), abs(vehBB:getHalfExtents().y), abs(vehBB:getHalfExtents().z)
  local downVec = raycastDown and vec3(0,0,-1) or -axis2
  -- first raycast straight down
  local rayDist = getAutoplaceRange(vehBB) + vehBB:getHalfExtents().z/2
  local rayCastHits = {}
  local startPosBase = vehBB:getCenter() + axis2 * halfExtentsZ
  for x = -1, 1 do
    for y = -1, 1 do
      if (y ~= 0 and x ~= 0) and not (y == 1 and x == 1) then
        -- TODO do four raycasts in the future and take the three that hit first
        -- TODO maybe make the raycasts not right at the edge of the bb, so they are less likely to start underground
        local startPos = startPosBase + (axis0 * x * halfExtentsX * rayCastStartPositionFactor + axis1 * y * halfExtentsY * rayCastStartPositionFactor)
        local detectedDist = castRayStatic(startPos, downVec, rayDist)
        if detectedDist < rayDist then
          table.insert(rayCastHits, {dist = detectedDist, pos = startPos + downVec * detectedDist})
        end
      end
    end
  end


  if tableSize(rayCastHits) == 3 then
    -- 1: origin
    -- 2: forward
    -- 3: right
    local right = (rayCastHits[3].pos - rayCastHits[1].pos):normalized()
    local forward = (rayCastHits[2].pos - rayCastHits[1].pos):normalized()
    local up = right:cross(forward)
    right = (-up):cross(forward)
    local center = rayCastHits[1].pos + right * halfExtentsX * rayCastStartPositionFactor + forward * halfExtentsY * rayCastStartPositionFactor + up * halfExtentsZ
    local mat = MatrixF()
    mat:setColumn(0, right)
    mat:setColumn(1, forward)
    mat:setColumn(2, up)
    mat:setColumn(3, center)
    vehBB:set2(mat, vehBB:getHalfExtents() * 2)
    return false
  else
    return true
  end
end

-- replacement for autoplace, do a raycast from the actual wheel nodes down
-- the vehBB has a horizontal rotation and wheelPositions are relative positions
-- TODO maybe use wheelpositions in the future
local function getBBOnGround(vehBB, vehOrigin)
  local newBB = OrientedBox3F()
  local mat = vehBB:getMatrix()
  mat:setPosition(vehBB:getCenter())
  newBB:set2(mat, vehBB:getHalfExtents() * 2)

  moveBBToGround(newBB, true)
  -- TODO put some limit on the angle of the BB
  -- second raycast in direction of vehicle down
  local floating = moveBBToGround(newBB)

  return newBB, floating
end

local minimumStepSizeFactor = 0.1
local gridX = -1
local gridY = -1
local function getNextOffset(forward, right)
  local gridRadius = max(abs(gridX), abs(gridY))
  local stepSizeFactorX = minimumStepSizeFactor * sideHalfLengthX * 0.5
  local stepSizeFactorY = minimumStepSizeFactor * sideHalfLengthY * 0.5
  local result = (forward * -gridY) * stepSizeFactorY * gridRadius * 2 + (right * gridX) * stepSizeFactorX * gridRadius * 2
  if gridY == -gridRadius and gridX < gridRadius then gridX = gridX + 1
  elseif gridY < gridRadius and gridX == gridRadius then gridY = gridY + 1
  elseif gridY == gridRadius and gridX > -gridRadius then gridX = gridX - 1
  elseif gridY > -gridRadius + 1 and gridX == -gridRadius then gridY = gridY - 1
  else
    gridX = -(gridRadius + 1)
    gridY = -(gridRadius + 1)
  end
  return result
end

local intendedBB
local recDepth = 0

local factor = 2
local bestCandidate = {}

local function placeVehRec(vehBB, newVehID, vehDir, vehRight, isBBFloating)
  --[[if candidates then
    table.insert(candidates, {center = vehBB:getCenter(), dir = -vehBB:getAxis(1), up = vehBB:getAxis(2)})
  end]]

  recDepth = recDepth + 1
  if recDepth > 400 then
    recDepth = 0
    gridX = -1
    gridY = -1
    recursionLimitReached = true
    if bestCandidate.bb then
      log('I', logTag, "Using best found spawn position")
      return bestCandidate.bb
    else
      log('W', logTag, "Couldnt find suitable spawning position. Putting the vehicle a little higher.")
      return initialBB
    end
  end

  visibilityPoint = visibilityPoint or intendedBB:getCenter()

  -- Test different attributes of the candidate position
  local foundIntersection = isIntersecting(vehBB, newVehID)
  local pointVisibilityStatus = getVisibilityStatus(visibilityPoint, vehBB)
  local wrongFloatingStatus = false
  if not airSpawn or isBBFloating == nil then
    -- vehicle should be on the ground. Test if it is on the ground
    wrongFloatingStatus = isBBFloating
  end

  -- TODO test also for vehicle angle (the tipping angle, but also the yaw)
  -- TODO could also check for distance to intended position

  -- Check whether the candidate position is valid
  if not wrongFloatingStatus and not foundIntersection and pointVisibilityStatus > 0 then
    if not bestCandidate.pointVisibilityStatus or pointVisibilityStatus > bestCandidate.pointVisibilityStatus then
      bestCandidate.pointVisibilityStatus = pointVisibilityStatus
      bestCandidate.bb = vehBB
    end
  end

  -- If the candidate is not perfect, then keep searching
  if wrongFloatingStatus or foundIntersection or pointVisibilityStatus < 2 then
    local mat = vehBB:getMatrix()
    local offset = getNextOffset(vehDir, vehRight) -- TODO this doesnt take terrain into account
    mat:setPosition(intendedBB:getCenter() + offset)
    local newVehBB = OrientedBox3F()
    newVehBB:set2(mat, vehBB:getHalfExtents() * factor)
    local newVehBB, isBBFloating_ = getBBOnGround(newVehBB)
    return placeVehRec(newVehBB, newVehID, vehDir, vehRight, isBBFloating_)
  end
  return vehBB
end

local function placeVehicle(vehBB, newVehID)
  -- Reset variables
  gridX = -1
  gridY = -1
  vehicleNodes = {}
  boundingBoxCache = {}
  intendedBB = vehBB

  sideHalfLengthX = vehBB:getHalfExtents().x
  sideHalfLengthY = vehBB:getHalfExtents().y
  shortestSideHalfLength = min(sideHalfLengthX, sideHalfLengthY)

  local averageSideHalfLength = (sideHalfLengthX + sideHalfLengthY) / 2
  smallVehicle = averageSideHalfLength < 0.5
  if isIntersecting(vehBB, newVehID) or (visibilityPoint and getVisibilityStatus(visibilityPoint, vehBB) < 2) then
    local vehDir = -vehBB:getAxis(1)
    local vehRight = -vehBB:getAxis(0)
    vehBB = placeVehRec(vehBB, newVehID, vehDir, vehRight)
  end

  intendedBB = nil
  return vehBB
end

local function setSafePositionRec(veh, pos, rot, centeredPosition, useInitialNodePositions)
  bestCandidate = {}

  -- Copy the initialBB
  if not initialBB then return end

  local boundingBox = OrientedBox3F()
  local mat
  if rot then
    mat = QuatF(rot.x, rot.y, rot.z, rot.w):getMatrix()
  else
    mat = initialBB:getMatrix()
  end
  if pos and not centeredPosition then
    pos = pos + (initialBB:getCenter() - veh:getPosition())
  end
  mat:setColumn(3, pos or initialBB:getCenter())
  boundingBox:set2(mat, initialBB:getHalfExtents() * 2)

  -- Turn it around if upside down
  if boundingBox:getAxis(2):dot(vec3(0, 0, 1)) < 0 then
    local mat = boundingBox:getMatrix()
    mat:setColumn(0, -mat:getColumn(0))
    mat:setColumn(2, -mat:getColumn(2))
    mat:setColumn(3, boundingBox:getCenter())
    boundingBox:set2(mat, boundingBox:getHalfExtents() * 2)
  end

  boundingBox, airSpawn = getBBOnGround(boundingBox)

  if not boundingBox then return end
  local newBB = placeVehicle(boundingBox, veh:getId())
  local actuallyRemoveTraffic = false
  if newBB and not checkOnlyStatics and gameplay_traffic and removeTraffic then
    actuallyRemoveTraffic = true
  end
  visibilityPoint = nil
  checkOnlyStatics = nil

  -- Find out the new position and rotation
  local originalRot = quat(initialBB:getMatrix():toQuatF())
  local newRot = quat(newBB:getMatrix():toQuatF())
  local diffRot = originalRot:inversed() * newRot

  -- Rotate refnode and move it to the new bb
  local localRefNode = veh:getPosition() - initialBB:getCenter()
  localRefNode = diffRot * localRefNode
  localRefNode = newBB:getCenter() + localRefNode

  if actuallyRemoveTraffic then
    moveTrafficVehiclesAway(newBB, veh:getId())
  end
  if useInitialNodePositions then
    vehiclesPositionedThisFrame[veh:getId()] = {pos = localRefNode, rot = newRot}
    vehiclesWerePositionedThisFrame = true
  end
  --veh:setPositionRotation(localRefNode.x, localRefNode.y, localRefNode.z, newRot.x, newRot.y, newRot.z, newRot.w)
  veh:setClusterPosRelRot(veh:getRefNodeId(), localRefNode.x, localRefNode.y, localRefNode.z, diffRot.x, diffRot.y, diffRot.z, diffRot.w)
  veh:applyClusterVelocityScaleAdd(veh:getRefNodeId(), 0, 0, 0, 0)
  veh:setOriginalTransform(localRefNode.x, localRefNode.y, localRefNode.z, newRot.x, newRot.y, newRot.z, newRot.w)
end


local function setSafePosition(veh, pos, rot, centeredPosition, useInitialNodePositions)
  vehiclesPositionedThisFrame[veh:getID()] = nil
  if useInitialNodePositions then
    initialBB = buildBoundingBox(veh)
  else
    initialBB = buildClusterBoundingBox(veh)
  end

  recursionLimitReached = false
  recDepth = 0
  setSafePositionRec(veh, pos, rot, centeredPosition, useInitialNodePositions)
  removeTraffic = true
end

local function centerVehicle(veh, pos, rot)
  if veh.initialNodePosBB then
    local center = rot * veh.initialNodePosBB:getCenter()
    local refnode = rot * veh:getInitialNodePosition(veh:getRefNodeId())
    local centerToRefnode = refnode - center
    local centeredPos = pos + centerToRefnode
    veh:setPosRot(centeredPos.x, centeredPos.y, centeredPos.z, rot.x, rot.y, rot.z, rot.w)
  end
end

local function setVehicleObject(veh, options)
  --dump{'setVehicleObject: ', veh, options}
  if not veh then
    log('E', logTag, 'setVehicleObject Failed, no vehicle provided.')
    return
  end

  if options.protectedConf then
    veh:setDynDataFieldbyName("protectedConf", 0, options.protectedConf)
  end

  veh.JBeam = options.model

  local pc = ''
  if type(options.config) == 'string' then
    pc = options.config
  elseif type(options.config) == 'table' then
    pc = serialize(options.config)
  end
  veh.partConfig = pc

  local paint = options.paint
  if paint then
    veh.color = ColorF(paint.baseColor[1], paint.baseColor[2], paint.baseColor[3], paint.baseColor[4]):asLinear4F()
  end

  local paint2 = options.paint2
  if paint2 then
    veh.colorPalette0 = ColorF(paint2.baseColor[1], paint2.baseColor[2], paint2.baseColor[3], paint2.baseColor[4]):asLinear4F()
  end

  local paint3 = options.paint3
  if paint3 then
    veh.colorPalette1 = ColorF(paint3.baseColor[1], paint3.baseColor[2], paint3.baseColor[3], paint3.baseColor[4]):asLinear4F()
  end
  local paints = {paint, paint2, paint3}
  veh:setMetallicPaintData(paints)
  veh.paints = serialize(paints)

  local pos = options.pos
  local rot = options.rot

  -- TODO the rotation by 180 degrees needs to happen before the other rotation. The order might still be wrong in some places
  rot = quat(0,0,1,0) * rot -- rotate 180 degrees
  local activeVehicle = true
  veh:spawnObjectWithPosRot(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w, activeVehicle)
  if options.centeredPosition then
    centerVehicle(veh, pos, rot)
  end
  local missionGroup = scenetree.MissionGroup
  if not missionGroup then
    log('E', logTag, 'MissionGroup does not exist')
    return
  end
  missionGroup:addObject(veh.obj)

  -- do not save vehicles that are spawned via this function with the level
  veh.canSave = false

  -- add it to the group 'SpawnedVehicles'
  local vehGroup = scenetree.SpawnedVehicles
  if not vehGroup then
    vehGroup = createObject('SimGroup')
    if vehGroup then
      vehGroup:registerObject('SpawnedVehicles')
      vehGroup.canSave = false
      missionGroup:addObject(vehGroup.obj)
    end
  else
    vehGroup:addObject(veh.obj)
  end
  setSafePosition(veh, nil, nil, nil, true)
end

local function safeTeleport(veh, pos, rot, checkOnlyStatics_, visibilityPoint_, removeTraffic_, centeredPosition, resetVehicle)
  --candidates = {}
  --TODO Make a simplified version for traffic
  if resetVehicle == nil then resetVehicle = true end
  rot = rot or quat(0,0,0,-1)
  rot = quat(0,0,1,0) * rot

  checkOnlyStatics = checkOnlyStatics_
  visibilityPoint = visibilityPoint_
  if removeTraffic_ ~= nil then
    removeTraffic = removeTraffic_
  end

  if resetVehicle then
    veh:setPosRot(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
    veh:resetBrokenFlexMesh()
  end
  setSafePosition(veh, pos, rot, centeredPosition, resetVehicle)
end

local function teleportToLastRoadCallback(data, resetVeh)
  local mapData = map.getMap()
  local legalSide = map.getRoadRules().rightHandDrive and -1 or 1
  local veh = be:getPlayerVehicle(0)
  local pos, rot
  if tableIsEmpty(mapData.nodes) then
    pos = veh:getPosition()
    rot = quatFromDir(veh:getDirectionVector(), veh:getDirectionVectorUp())
  end

  if not pos and data then
    -- Find the last recovery position on a road and teleport to that road
    for i = data.tail, data.head, -1 do
      local recoveryPoint = data[i]
      if not recoveryPoint then break end
      local n1Id, n2Id, dist = map.findClosestRoad(recoveryPoint.pos)
      if n1Id then
        local n1 = mapData.nodes[n1Id]
        local n2 = mapData.nodes[n2Id]
        if dist <= (n1.radius+n2.radius)/2 then
          local oneWay = mapData.nodes[n1Id].links[n2Id].oneWay
          local roadDir = (n2.pos - n1.pos)

          -- if the road is oneWay, flip the roadDir if it is incorrect
          if oneWay and (mapData.nodes[n1Id].links[n2Id].inNode ~= n1Id) then
            roadDir = -roadDir
          end

          local perpendicular = roadDir:cross(n1.normal)

          -- In a oneWay road, always put the vehicle on the legal driving side, otherwise check which side is closer
          local roadSide
          if oneWay then
            roadSide = legalSide
          else

            -- if there are groundmarkers active then choose the side in the direction of the route
            if core_groundMarkers.currentlyHasTarget() then
              core_groundMarkers.routePlanner:trackPosition(recoveryPoint.pos)
              if core_groundMarkers.routePlanner.path[2] then
                local routeDir = core_groundMarkers.routePlanner.path[2].pos - be:getPlayerVehicle(0):getPosition()
                roadSide = roadDir:dot(routeDir) > 0 and legalSide or -legalSide
              end
            end

            if not roadSide then
              roadSide = perpendicular:dot(recoveryPoint.pos - n1.pos) > 0 and 1 or -1
            end
          end

          -- Project the recovery position on the road
          local scalarProjection = clamp(roadDir:dot((recoveryPoint.pos - n1.pos)) / (roadDir:length()^2), 0, 1)
          local projectedPosition = n1.pos + roadDir * scalarProjection
          pos = projectedPosition + perpendicular:normalized() * roadSide * ((n1.radius+n2.radius)/2 - veh.initialNodePosBB:getExtents().x/2)

          -- Find the rotation that puts the vehicle correctly in the driving direction
          rot = quatFromDir(roadDir * legalSide * roadSide, n1.normal)
          break
        end
      end
    end
  end

  -- If none of the recovery points are on a road, try to find the closest road to the current position
  -- TODO this puts the player in the middle of the road
  if not pos then
    local n1Id, n2Id, dist = map.findClosestRoad(veh:getPosition())
    local n1 = mapData.nodes[n1Id]
    local n2 = mapData.nodes[n2Id]
    if dist < 50 then
      pos = n1.pos
      rot = quatFromDir(n1.pos - n2.pos, n1.normal)
    end
  end

  if not pos then
    pos = veh:getPosition()
    rot = quatFromDir(veh:getDirectionVector(), veh:getDirectionVectorUp())
  end

  safeTeleport(veh, pos, rot, nil, nil, nil, nil, resetVeh)
end

local function teleportToLastRoad(veh, resetVeh)
  veh = veh or be:getPlayerVehicle(0)
  if not veh then return end
  queueCallbackInVehicle(veh, "spawn.teleportToLastRoadCallback", "recovery.recoveryPoints", resetVeh)
end

local function spawnVehicle(model, partConfig, pos, rot, options)
  local veh = createObject("BeamNGVehicle")
  if not veh then
    log('E', logTag, 'Failed to create vehicle')
    return
  end

  options = options or {}
  visibilityPoint = options.visibilityPoint
  if options.removeTraffic ~= nil then
    removeTraffic = options.removeTraffic
  end

  local autoEnterVehicle = tostring(options.autoEnterVehicle ~= false) -- nil defaults to 'true'
  veh:setDynDataFieldbyName("autoEnterVehicle", 0, autoEnterVehicle)

  local spawnDatablock = "default_vehicle"
  local dataBlock = scenetree.findObject(spawnDatablock)

  if not datablock then
    veh.dataBlock = dataBlock
  else
    log('E', logTag, 'Failed to find dataBlock')
    return
  end

  local vehicleName = options.vehicleName or "clone"
  local i = 0
  while scenetree.findObject(vehicleName) do
    vehicleName = "clone" .. tostring(i)
    i = i + 1
  end
  veh:registerObject(vehicleName)
  options.vehicleName = vehicleName

  --veh.licenseText = TorqueScriptLua.getVar( "$beamngVehicleLicenseName","") -- core_vehicles will manage license text
  options.model = model
  options.config = partConfig
  options.pos = pos
  options.rot = rot
  options.cling = options.cling ~= false
  setVehicleObject(veh, options)
  return veh
end

--[[
pickSpawnPoint s responsible for finding a valid spawn point for a player and camera
@param spawnName string represent player or camera spawn point
]]
local function pickSpawnPoint(spawnName)
  local playerSP,spawnPointName
  local defaultSpawnPoint = setSpawnpoint.loadDefaultSpawnpoint()
  local spawnDefaultGroups = {"CameraSpawnPoints", "PlayerSpawnPoints", "PlayerDropPoints"}
  if defaultSpawnPoint then
    local spawnPoint = scenetree.findObject(defaultSpawnPoint)
    if spawnPoint then
      return spawnPoint
    else
      log('W', logTag, 'No SpawnPointName in mission file vehicle spawn in the default position')
    end
  end
  --Walk through the groups until we find a valid object
  for i,v in pairs(spawnDefaultGroups) do
    if scenetree.findObject(spawnDefaultGroups[i]) then
      local spawngroupPoint = scenetree.findObject(spawnDefaultGroups[i]):getRandom()
      if not spawngroupPoint then
        break
      end
      local sgPpointID = scenetree.findObjectById(spawngroupPoint:getId())
      if not sgPpointID then
        break
      end
      return sgPpointID
    end
  end

  --[[ ensuring backward compability with mods
  ]]
  local dps = scenetree.findObject("DefaultPlayerSpawnSphere")
  if dps then
    return scenetree.findObjectById(dps.obj:getId())
  end

  --[[Didn't find a spawn point by looking for the groups so let's return the
   "default" SpawnSphere First create it if it doesn't already exist
  ]]
  playerSP = createObject('SpawnSphere')
  if not playerSP then
    log('E', logTag, 'could not create playerSP')
    return
  end
  playerSP.dataBlock = scenetree.findObject('SpawnSphereMarker')
  if spawnName == "player" then
    playerSP.spawnClass = "BeamNGVehicle"
    playerSP.spawnDatablock = "default_vehicle"
    spawnPointName = "DefaultPlayerSpawnSphere"
    playerSP:registerObject(spawnPointName)
  elseif spawnName == 'camera' then
    playerSP.spawnClass = "Camera"
    playerSP.spawnDatablock = "Observer"
    spawnPointName = "DefaultCameraSpawnSphere"
    playerSP:registerObject(spawnPointName)
  end
  local missionCleanup = scenetree.MissionCleanup
  if not missionCleanup then
    log('E', logTag, 'MissionCleanup does not exist')
    return
  end
  --[[ Add it to the MissionCleanup group so that it doesn't get saved
    to the Mission (and gets cleaned up of course)
  ]]
  missionCleanup:addObject(playerSP.obj)
  return playerSP
end

local function spawnCamera()
  local missionCleanup = scenetree.MissionCleanup
  if not missionCleanup then
    log('E', logTag, 'missionCleanup does not exist')
    return
  end
  -- Set the control object to the default camera
  local cam = scenetree.findObject("gameCamera")
  if not cam then
    cam = createObject('Camera')
    cam.dataBlock = scenetree.findObject("Observer")
    cam:registerObject("gameCamera")
  end

  --If we have a camera then set up some properties
  missionCleanup:addObject(cam.obj)
  RenderViewManagerInstance:getOrCreateView('main'):setCameraObject(cam.obj)
end

local function spawnPlayer()
  local spawnClass, spawnDatablock, spawnProperties, spawnScript, player
  local spawnPoint = pickSpawnPoint('player')

  if M.preventPlayerSpawning then
    M.preventPlayerSpawning = nil
    log('D',logTag,'not spawning player upon request')
    return
  end
  local vehicleModel = TorqueScriptLua.getVar("$beamngVehicle")
  if vehicleModel == "" then
    log("D", "", "A vehicle has not been provided, not spawning it by default ")
    return
  end
  if gameConnection and gameConnection.player and scenetree.findObjectById(gameConnection.player) then
    log('E', logTag, 'Attempting to create a player for a client that already has one!')
  end
  if spawnPoint then
    spawnClass      = "BeamNGVehicle"
    spawnDatablock  = "default_vehicle"
    if spawnPoint.spawnClass ~=""  then
      spawnClass = spawnPoint.spawnClass
    end
    --[[
    This may seem redundant given the above but it allows
    the SpawnSphere to override the datablock without
    overriding the default player class
    ]]
    if spawnPoint.spawnDatablock and scenetree.findObject(spawnPoint.spawnDatablock) then
      spawnDatablock = spawnPoint.spawnDatablock
    end

    local config = TorqueScriptLua.getVar("$beamngVehicleConfig")
    local color = stringToTable(TorqueScriptLua.getVar("$beamngVehicleColor"))
    local paintData = stringToTable(TorqueScriptLua.getVar("$beamngVehicleMetallicPaintData"))
    color = color or {}
    color[1] = color[1] or 1
    color[2] = color[2] or 1
    color[3] = color[3] or 1
    color[4] = color[4] or 1
    local options = {}
    options.paint = createVehiclePaint({x = color[1], y = color[2], z = color[3], w = color[4]}, paintData)
    options.paint2 = options.paint
    options.paint3 = options.paint
    options.vehicleName = "thePlayer"
    player = spawnVehicle(vehicleModel, config, spawnPoint:getPosition(), quat(spawnPoint:getRotation()) * quat(0,0,1,0), options)
  end

  -- Update the default camera to start with the player
  if gameConnection and gameConnection.freeCamera then
    local freeCamera = scenetree.findObjectById(tonumber(gameConnection.freeCamera))
    if freeCamera then
      if spawnClass== "Player" then
        freeCamera:setTransform(player:getEyeTransform())
      else
        freeCamera:setTransform(player:getTransform())
      end
    else
      log('E', logTag, 'freeCamera not in scenetree')
    end
  end
  --[[Add the player object to MissionCleanup so that it
  won't get saved into the level files and will get
  cleaned up properly--]]
  local missionCleanup = scenetree.MissionCleanup
  if not missionCleanup then
    log('E', logTag, 'missionCleanup does not exist')
    return
  end
  missionCleanup:addObject(player.obj)
  local missionGroup = scenetree.MissionGroup
  if not missionGroup then
    log('E', logTag, 'MissionGroup does not exist')
    return
  end
  missionGroup:addObject(player.obj)
  player.canSave = false
  gameConnection.player = player
end


----------------
local function calculateRelativeVehiclePlacement(transform0, coupler0_offset, transform1, coupler1_offset)
  local coupler0_ws
  do
    local coupler0_os = MatrixF(true)
    coupler0_os:setColumn(3, coupler0_offset)
    coupler0_ws = transform0 * coupler0_os
  end

  local res
  do
    local coupler1_os = MatrixF(true)
    coupler1_os:setColumn(3, coupler1_offset)
    local coupler1_ws = transform1 * coupler1_os

    res = coupler0_ws * (coupler1_ws:inverse() * transform1)
  end
  return res
end

local function placeTrailer(vehId, couplerOffsetVeh, trailerId, couplerOffsetTrailer, couplerTag)

  local veh = be:getObjectByID(vehId)
  if not veh then return end

  local veh2 = be:getObjectByID(trailerId)
  if not veh2 then return end

  local transform0 = veh:getRefNodeMatrix()
  local coupler0_offset = couplerOffsetVeh--vec3(0, 3, 0.2)
  local transform1 = veh2:getRefNodeMatrix()
  local coupler1_offset = couplerOffsetTrailer--vec3(0.3, -3.3, 0)

  local mat = calculateRelativeVehiclePlacement(transform0, coupler0_offset, transform1, coupler1_offset)

  veh2:setTransform(mat)
  veh2:queueLuaCommand('obj:requestReset(RESET_PHYSICS)')
  veh2:resetBrokenFlexMesh()

  if core_trailerRespawn.getCouplerTagsOptions()[couplerTag] == "autoCouple" then
    veh:queueLuaCommand(string.format('beamstate.activateAutoCoupling("%s")', couplerTag))
  end
end

local function spawnTrailerBehindVehicle(carID, trailerID)
  -- Spawn the trailer behind the vehicle
  local car = scenetree.findObjectById(carID)
  local carBB = car:getSpawnWorldOOBB()
  local halfCarLength = carBB:getHalfExtents().y

  local trailer = scenetree.findObjectById(trailerID)
  local trailerBB = trailer:getSpawnWorldOOBB()
  local halfTrailerLength = trailerBB:getHalfExtents().y

  -- Position on the bottom of the cars BB under the center
  local position = carBB:getCenter()
  position = position - car:getDirectionVectorUp() * carBB:getHalfExtents().z

  -- Difference of the bottom center of the trailer to trailer position
  local diffCenterPos = trailer:getPosition() - (trailerBB:getCenter() - trailer:getDirectionVectorUp() * trailerBB:getHalfExtents().z)

  -- Translate the trailer back so that the trailers BB touches the cars BB
  local direction = car:getDirectionVector()
  direction:normalize()
  position = position - (direction * (halfCarLength + halfTrailerLength))
  position = position + diffCenterPos
  trailer:setPosition(position.x, position.y, position.z)
end

M.clearCache                        = clearCache
M.spawnVehicle                      = spawnVehicle
M.setVehicleObject                  = setVehicleObject
M.spawnCamera                       = spawnCamera
M.spawnPlayer                       = spawnPlayer
M.calculateRelativeVehiclePlacement = calculateRelativeVehiclePlacement
M.placeTrailer                      = placeTrailer
M.safeTeleport                      = safeTeleport
M.teleportToLastRoad                = teleportToLastRoad
M.teleportToLastRoadCallback        = teleportToLastRoadCallback

return M
