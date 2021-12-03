-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local max, min, floor = math.max, math.min, math.floor

M.damage = 0
M.damageExt = 0
M.lowpressure = false
M.deformGroupDamage = {}

M.activeParts = {}

M.monetaryDamage = 0
local partDamageData
local lastDisplayedDamage = 0

local delayedPrecompBeams = {}
local initTimer = 0

local collTriState = {}

local wheelBrokenBeams = {}

local beamDamageTracker = {}
local beamDamageTrackerDirty = false

local breakGroupCache = {}
local brokenBreakGroups = {}
local triangleBreakGroupCache = {}
local couplerBreakGroupCache = {}
local couplerBreakGroupCacheOrig = {}
local couplerCache = {}
local couplerTags = {}

local autoCouplingActive = false
local autoCouplingNodeTag = nil
local autoCouplingTimer = 0
local autoCouplingTimeoutTimer = 0

local attachedCouplers = {}
local transmitCouplers = {}
local recievedElectrics = {}
local hasActiveCoupler = false
local skeletonStateTimer = 0.25

local beamBodyPartLookup = nil
local partBeams = nil
local invBodyPartBeamCount = nil
local bodyPartDamageTracker = nil
local nonApplyableIntegrityValues = {}

local planets = {}
local planetTimers = {}

M.tagBeamMap = {}
M.linkTagBeamMap = {}

local function setPartCondition(partName, partTypeData, odometer, integrity, visual)
  if type(integrity) == "number" then
    local integrityValue = integrity
    integrity = {
      jbeam = {
        brokenBreakGroups = {},
        nonApplyableIntegrityValue = 0
      }
    }
    local partBreakGroups = {}
    for _, partType in ipairs(partTypeData) do
      local split = split(partType, ":")
      if split[1] == "jbeam" and split[2] == "breakGroup" then
        local breakGroupName = split[3]
        table.insert(partBreakGroups, breakGroupName)
      end
    end

    local breakGroupCount = #partBreakGroups
    local numberOfBrokenBreakGroups = breakGroupCount * (1 - integrityValue)
    local wholeNumberOfBrokenBreakGroups = floor(numberOfBrokenBreakGroups)
    local shuffledBreakGroups = arrayShuffle(partBreakGroups)
    for i = 1, wholeNumberOfBrokenBreakGroups do
      table.insert(integrity.jbeam.brokenBreakGroups, shuffledBreakGroups[i])
    end
    if breakGroupCount > 0 then
      integrity.jbeam.nonApplyableIntegrityValue = (numberOfBrokenBreakGroups / breakGroupCount) - (wholeNumberOfBrokenBreakGroups / breakGroupCount)
    end
  end

  for _, brokenBreakGroup in ipairs(integrity.jbeam.brokenBreakGroups or {}) do
    M.breakBreakGroup(brokenBreakGroup)
  end

  nonApplyableIntegrityValues[partName] = integrity.jbeam.nonApplyableIntegrityValue
end

local function getPartCondition(partName, partTypeData)
  local canProvideCondition = false
  local omitSpawn = false
  local partCondition = {integrityValue = 1, integrityState = {brokenBreakGroups = {}, nonApplyableIntegrityValue = nonApplyableIntegrityValues[partName]}, visualValue = 1, visualState = {}}

  if partTypeData then
    local breakGroupCount = 0
    local brokenBreakGroupCount = 0
    for _, partType in ipairs(partTypeData) do
      local split = split(partType, ":")
      if split[1] == "jbeam" and split[2] == "breakGroup" then
        local breakGroupName = split[3]
        breakGroupCount = breakGroupCount + 1
        if brokenBreakGroups[breakGroupName] then
          table.insert(partCondition.integrityState.brokenBreakGroups, breakGroupName)
          brokenBreakGroupCount = brokenBreakGroupCount + 1
        end
      end
    end
    if breakGroupCount > 0 then
      partCondition.integrityValue = 1 - (brokenBreakGroupCount / breakGroupCount)
    end

    canProvideCondition = true
    if brokenBreakGroupCount == breakGroupCount and breakGroupCount > 1 then
      omitSpawn = true
    end
  end

  partCondition.integrityValue = max(partCondition.integrityValue - (nonApplyableIntegrityValues[partName] or 0), 0)

  return partCondition, omitSpawn, canProvideCondition
end

local function luaBreakBeam(id)
  beamDamageTracker[id] = 1
  beamDamageTrackerDirty = true
end

local function breakBreakGroup(g)
  if g == nil then
    return
  end

  brokenBreakGroups[g] = true

  -- hide props if they use
  props.hidePropsInBreakGroup(g)

  -- break all beams in that group
  local bg = breakGroupCache[g]
  if bg then
    breakGroupCache[g] = nil
    for _, bcid in ipairs(bg) do
      obj:breakBeam(bcid)
      luaBreakBeam(bcid)
    end
  end

  -- break all couplers
  bg = couplerBreakGroupCache[g]
  if bg then
    couplerBreakGroupCache[g] = nil
    for _, ccid in ipairs(bg) do
      obj:detachCoupler(ccid)
    end
  end

  --break triangle breakgroups matching the beam breakgroup
  bg = triangleBreakGroupCache[g]
  if bg then
    for _, ctid in ipairs(bg) do
      obj:breakCollisionTriangle(ctid)
      collTriState[ctid] = nil
    end
    triangleBreakGroupCache[g] = nil
  end
end

local function breakMaterial(beam)
  material.switchBrokenMaterial(beam)
end

local function broadcastCouplerVisibility(visible)
  BeamEngine:queueAllObjectLua("beamstate.setCouplerVisiblityExternal(" .. tostring(obj:getId()) .. "," .. tostring(visible) .. ")")
end

M.debugDraw = nop
local function debugDraw(focusPos)
  local hasManualCoupler = false
  for nid, c in pairs(couplerCache) do
    if not c.couplerWeld and not c.couplerLock and c.couplerTag then
      hasManualCoupler = true
      break
    end
  end

  -- highlight all coupling nodes
  if hasManualCoupler then
    for _, coupler in pairs(couplerCache) do
      if coupler.couplerLock == nil and coupler.couplerTag then
        obj.debugDrawProxy:drawNodeSphere(coupler.cid, 0.15, getContrastColor(stringHash(coupler.couplerTag or coupler.tag), 150))
      end
    end
  else
    for _, coupler in pairs(couplerCache) do
      obj.debugDrawProxy:drawNodeSphere(coupler.cid, 0.15, getContrastColor(stringHash(coupler.couplerTag or coupler.tag), 150))
    end
  end
end

local function setCouplerVisiblityExternal(sourceObjectID, visible)
  if visible then
    M.debugDraw = debugDraw
  else
    M.debugDraw = nop
  end
end

local function activateAutoCoupling(_nodetag)
  if not hasActiveCoupler then
    return
  end

  autoCouplingNodeTag = _nodetag
  autoCouplingActive = true
  autoCouplingTimeoutTimer = 0
  autoCouplingTimer = 0
  broadcastCouplerVisibility(true)
end

local function disableAutoCoupling()
  autoCouplingActive = false
  autoCouplingNodeTag = nil
  autoCouplingTimeoutTimer = 0
  autoCouplingTimer = 0
  broadcastCouplerVisibility(false)
end

local function sendObjectCouplingChange()
  obj:queueGameEngineLua(string.format("onObjectCouplingChange(%s,%s)", objectId, serialize(attachedCouplers)))
end

local function attachCouplers(_nodetag)
  local nodetag = _nodetag or ""
  for _, val in pairs(couplerCache) do
    if (val.couplerWeld ~= true and val.couplerTag and (_nodetag == nil or val.couplerTag == nodetag)) and val.cid then
      obj:attachCoupler(val.cid, val.couplerTag or "", val.couplerStrength or 1000000, val.couplerRadius or 0.2, val.couplerTargets or 0)
    end
  end
end

local function couplerExists(_nodetag)
  return couplerTags[_nodetag]
end

local function detachCouplers(_nodetag, forceLocked, forceWelded)
  local nodetag = _nodetag or ""
  for _, val in pairs(couplerCache) do
    if ((val.couplerLock ~= true or forceLocked) and (val.couplerWeld ~= true or forceWelded) and val.couplerTag and (_nodetag == nil or val.couplerTag == nodetag)) and val.cid then
      obj:detachCoupler(val.cid)
      obj:queueGameEngineLua(string.format("onCouplerDetach(%s,%s)", obj:getId(), val.cid))
    end
  end
end

local function isCouplerAttached()
  -- check for manual coupler
  for nid, c in pairs(couplerCache) do
    if not c.couplerWeld and not c.couplerLock and c.couplerTag then
      return attachedCouplers[nid] ~= nil
    end
  end

  -- relaxed check
  for nid, _ in pairs(attachedCouplers) do
    if couplerCache[nid] and not couplerCache[nid].couplerWeld then
      return true
    end
  end

  return false
end

-- this is called on keypress (L)
local function toggleCouplers()
  if autoCouplingActive then
    obj:stopLatching()
    disableAutoCoupling()
    if v.mpVehicleType == "L" then obj:queueGameEngineLua("MPVehicleGE.sendBeamstate(\'false\'," ..tostring(obj:getID())..")") end -- ////////////////////////////////////////////////// BEAMMP
  else
    if isCouplerAttached() then
      detachCouplers()
	  if v.mpVehicleType == "L" then obj:queueGameEngineLua("MPVehicleGE.sendBeamstate(\'false\'," ..tostring(obj:getID())..")") end -- ////////////////////////////////////////////////// BEAMMP
    else
      activateAutoCoupling()
	  if v.mpVehicleType == "L" then obj:queueGameEngineLua("MPVehicleGE.sendBeamstate(\'true\'," ..tostring(obj:getID())..")") end -- ////////////////////////////////////////////////// BEAMMP
    end
  end
end

local function couplerFound(nodeId, obj2id, obj2nodeId)
  --print(string.format("coupler found %s.%s->%s.%s", obj:getId(),nodeId,obj2id, obj2nodeId))
end

M.updateRemoteElectrics = nop
local function updateRemoteElectrics()
  for i = 1, #recievedElectrics do
    tableMerge(electrics.values, recievedElectrics[i])
  end
  recievedElectrics = {}
end

local function onCouplerAttached(nodeId, obj2id, obj2nodeId)
  disableAutoCoupling()
  attachedCouplers[nodeId] = {obj2id = obj2id, obj2nodeId = obj2nodeId}

  -- figure out the electrics state
  local n = v.data.nodes[nodeId]
  if n and (n.importElectrics or n.importInputs) then
    local data = {electrics = n.importElectrics, inputs = n.importInputs}
    --print("couplerAttached -> beamstate.exportCouplerData("..tostring(obj2nodeId)..", "..serialize(data)..")")
    obj:queueObjectLuaCommand(obj2id, "beamstate.exportCouplerData(" .. tostring(obj2nodeId) .. ", " .. serialize(data) .. ")")
    M.updateRemoteElectrics = updateRemoteElectrics
  end

  local breakGroups = type(n.breakGroup) == "table" and n.breakGroup or {n.breakGroup}
  for _, g in pairs(breakGroups) do
    couplerBreakGroupCache[g] = couplerBreakGroupCacheOrig[g]
  end

  --print(string.format("coupler attached %s.%s->%s.%s", obj:getId(),nodeId,obj2id, obj2nodeId))
  if objectId < obj2id then
    obj:queueGameEngineLua(string.format("onCouplerAttached(%s,%s,%s,%s)", objectId, obj2id, nodeId, obj2nodeId))
  end
end

local function onCouplerDetached(nodeId, obj2id, obj2nodeId)
  --print(string.format("coupler detached %s.%s->%s.%s", obj:getId(),nodeId,obj2id, obj2nodeId))
  attachedCouplers[nodeId] = nil
  transmitCouplers[nodeId] = nil

  local n = v.data.nodes[nodeId]
  if n.breakGroup and (n.breakGroupType == 0 or n.breakGroupType == nil) then
    if type(n.breakGroup) ~= "table" and couplerBreakGroupCache[n.breakGroup] == nil then
      -- shortcircuit in case of broken single breakGroup
    else
      local breakGroups = type(n.breakGroup) == "table" and n.breakGroup or {n.breakGroup}
      for _, g in pairs(breakGroups) do
        breakBreakGroup(g)
      end
    end
  end

  if objectId < obj2id then
    obj:queueGameEngineLua(string.format("onCouplerDetached(%s,%s)", objectId, obj2id))
  end
end

local function getCouplerOffset(couplerTag)
  local refPos = v.data.nodes[v.data.refNodes[0].ref].pos
  local couplerOffset = {}
  for _, c in pairs(couplerCache) do
    if c.couplerTag == couplerTag or c.tag == couplerTag or couplerTag == "" or not couplerTag then
      local pos = v.data.nodes[c.cid].pos
      couplerOffset[c.cid] = {x = pos.x - refPos.x, y = pos.y - refPos.y, z = pos.z - refPos.z}
    end
  end
  return couplerOffset
end

-- called from the vehicle that wants to import electrics
local function exportCouplerData(nodeid, dataList)
  --print(obj:getId().."<-exportCouplerData("..nodeid..','..dumps(dataList)..')')
  if attachedCouplers[nodeid] == nil then
    log("E", "beamstate.exportCouplerElectrics", "unable to export electrics: known coupled node: " .. tostring(nodeid))
    return
  end
  transmitCouplers[nodeid] = attachedCouplers[nodeid]
  transmitCouplers[nodeid].exportElectrics = dataList.electrics
  transmitCouplers[nodeid].exportInputs = dataList.inputs
end

-- called by the host that provides the electrics
local function importCouplerData(nodeId, data)
  --print(obj:getId().."<-importCouplerData("..nodeId..','..dumps(data)..')')
  if data.electrics then
    table.insert(recievedElectrics, data.electrics)
  end
  if data.inputs then
    for k, v in pairs(data.inputs) do
      input.event(k, v, 2)
    end
  end
end

local function sendUISkeletonState()
  if not playerInfo.firstPlayerSeated then
    return
  end
  guihooks.trigger("VehicleSkeletonState", beamDamageTracker)
end

local function deflateTire(wheelid)
  local wheel = v.data.wheels[wheelid]
  M.lowpressure = true

  local brokenBeams = wheelBrokenBeams[wheelid] or 1
  if wheel.pressureGroup ~= nil then
    if v.data.pressureGroups[wheel.pressureGroup] ~= nil then
      if brokenBeams > 4 then
        obj:deflatePressureGroup(v.data.pressureGroups[wheel.pressureGroup])
        obj:changePressureGroupDrag(v.data.pressureGroups[wheel.pressureGroup], 0)
      elseif brokenBeams == 1 then
        obj:setGroupPressure(v.data.pressureGroups[wheel.pressureGroup], (0.2 * 6894.757 + 101325))
      end
    end
  end

  if brokenBeams == 1 then
    if wheels.wheels[wheelid] then
      wheels.wheels[wheelid].isTireDeflated = true
    end
    guihooks.message({txt = "vehicle.beamstate.tireDeflated", context = {wheelName = wheel.name}}, 5, "vehicle.damage.deflated." .. wheel.name)
    damageTracker.setDamage("wheels", "tire" .. wheel.name, true)

    sounds.playSoundOnceFollowNode("event:>Vehicle>Tire_Burst", wheel.node1, 1)
    M.damageExt = M.damageExt + 1000
    if wheel.treadNodes ~= nil and wheel.treadBeams ~= nil then
      for _, nodecid in pairs(wheel.treadNodes) do
        obj:setNodeFrictionSlidingCoefs(nodecid, v.data.nodes[nodecid].frictionCoef * 0.5, v.data.nodes[nodecid].slidingFrictionCoef * 0.5)
      end

      for _, beamcid in pairs(wheel.treadBeams) do
        obj:setBeamSpringDamp(beamcid, v.data.beams[beamcid].beamSpring * 0.1, 2, -1, -1)
      end
    end

    if wheel.sideBeams ~= nil then
      for _, beamcid in pairs(wheel.sideBeams) do
        obj:setBeamSpringDamp(beamcid, 0, 10, -1, -1)
      end
    end

    if wheel.peripheryBeams ~= nil then
      for _, beamcid in pairs(wheel.peripheryBeams) do
        obj:setBeamSpringDamp(beamcid, v.data.beams[beamcid].beamSpring * 0.1, 2, -1, -1)
      end
    end

    if wheel.reinfBeams ~= nil then
      for _, beamcid in pairs(wheel.reinfBeams) do
        obj:setBeamSpringDamp(beamcid, 0, 0.7, 0, 0)
      end
    end

    if wheel.pressuredBeams ~= nil then
      for _, beamcid in pairs(wheel.pressuredBeams) do
        obj:setBeamPressureRel(beamcid, 0, math.huge, -1, -1)
      end
    end
  end

  wheelBrokenBeams[wheelid] = brokenBeams + 1
end

local function delPlanetI(i)
  local pe = #planets - 4
  for j = 0, 4 do
    planets[i + j] = planets[pe + j]
  end
  for j = 1, 5 do
    table.remove(planets)
  end

  for j = 1, #planetTimers do
    if planetTimers[j][1] == i then
      if planetTimers[#planetTimers][1] == pe then
        planetTimers[j][2] = planetTimers[#planetTimers][2]
        table.remove(planetTimers)
      else
        table.remove(planetTimers, j)
      end
      break
    end
  end
end

local function delPlanet(center, radius, mass)
  for i = 1, #planets - 4, 5 do
    if planets[i] == center.x and planets[i + 1] == center.y and planets[i + 2] == center.z and planets[i + 3] == radius and planets[i + 4] == mass then
      delPlanetI(i)
      obj:setPlanets(planets)
      break
    end
  end
end

local function addPlanet(center, radius, mass, dt)
  if dt ~= nil then
    for pt = 1, #planetTimers do
      local i = planetTimers[pt][1]
      if planets[i] == center.x and planets[i + 1] == center.y and planets[i + 2] == center.z and planets[i + 3] == radius and planets[i + 4] == mass then
        if dt == 0 then
          delPlanetI(i)
          obj:setPlanets(planets)
        else
          planetTimers[pt][2] = dt
        end
        return
      end
    end

    if dt == 0 then
      return
    end
    table.insert(planetTimers, {#planets + 1, dt})
  end
  table.insert(planets, center.x)
  table.insert(planets, center.y)
  table.insert(planets, center.z)
  table.insert(planets, radius)
  table.insert(planets, mass)
  obj:setPlanets(planets)
end

local function setPlanets(p)
  table.clear(planets)
  table.clear(planetTimers)
  for i = 1, #p - 2, 3 do
    table.insert(planets, p[i].x)
    table.insert(planets, p[i].y)
    table.insert(planets, p[i].z)
    table.insert(planets, p[i + 1])
    table.insert(planets, p[i + 2])
  end
end

local function updateGFX(dt)
  -- Planet timers
  local pEnd = #planetTimers
  local i = 1
  while i <= pEnd do
    local t = planetTimers[i][2]
    t = t - dt
    if t <= 0 then
      delPlanetI(i)
      pEnd = pEnd - 1
      obj:setPlanets(planets)
    else
      planetTimers[i][2] = t
      i = i + 1
    end
  end

  -- Damage
  M.damage = obj:getDissipatedEnergy() + M.damageExt

  local damageSum = 0
  for k, partData in pairs(partDamageData) do
    local partValue = partData.value
    local brokenCoef = clamp(partData.beamsBroken / partData.brokenBeamsThreshold, 0, 1)
    local deformedCoef = (clamp(partData.beamsDeformed / partData.deformedBeamsThreshold, 0, 1))
    local damageCoef = max(brokenCoef, deformedCoef)
    damageSum = damageSum + partValue * damageCoef
  end
  if damageSum > lastDisplayedDamage * 1.05 then
    --guihooks.message(string.format("Car Damage: $%.2f", damageSum), 5, "vehicle.damageSum")
    lastDisplayedDamage = damageSum
  end

  if beamDamageTrackerDirty then
    skeletonStateTimer = skeletonStateTimer - dt
    if skeletonStateTimer < 0 then
      sendUISkeletonState()
      skeletonStateTimer = 0.25
      beamDamageTrackerDirty = false
    end
  end

  if autoCouplingActive then
    autoCouplingTimeoutTimer = autoCouplingTimeoutTimer + dt
    if autoCouplingTimeoutTimer > 60 then
      disableAutoCoupling()
    end
    autoCouplingTimer = (autoCouplingActive and autoCouplingTimer <= 0.5) and autoCouplingTimer + dt or 0
    if autoCouplingTimer > 0.5 then
      attachCouplers(autoCouplingNodeTag)
    end
  end

  -- transmit data
  for _, coupler in pairs(transmitCouplers) do
    local data = {}
    if coupler.exportElectrics then
      data.electrics = {}
      for _, v in pairs(coupler.exportElectrics) do
        data.electrics[v] = electrics.values[v]
      end
    end
    if coupler.exportInputs then
      data.inputs = {}
      for _, v in pairs(coupler.exportInputs) do
        data.inputs[v] = electrics.values[v] or input[v]
      end
    end
    obj:queueObjectLuaCommand(coupler.obj2id, string.format("beamstate.importCouplerData(%s, %s)", coupler.obj2nodeId, serialize(data)))
  end
end

M.update = nop
local function update(dtSim)
  local finished_precomp = true
  initTimer = initTimer + dtSim
  for _, b in ipairs(delayedPrecompBeams) do
    local tratio = initTimer / b.beamPrecompressionTime
    finished_precomp = finished_precomp and tratio >= 1
    obj:setPrecompressionRatio(b.cid, 1 + (b.beamPrecompression - 1) * min(tratio, 1))
  end

  if finished_precomp then
    M.update = nop
    delayedPrecompBeams = {}
    updateCorePhysicsStepEnabled()
  end
end

local function beamBroken(id, energy)
  beamDamageTracker[id] = 0
  beamDamageTrackerDirty = true

  local bodyPart = beamBodyPartLookup[id]
  if bodyPart then
    bodyPartDamageTracker[bodyPart] = bodyPartDamageTracker[bodyPart] + 1
    local damage = bodyPartDamageTracker[bodyPart] * invBodyPartBeamCount[bodyPart]
    if damage > 0.001 then
      damageTracker.setDamage("body", bodyPart, damage)
    end
  end

  luaBreakBeam(id)
  if v.data.beams[id] ~= nil then
    local beam = v.data.beams[id]
    if beam.partOrigin and partDamageData[beam.partOrigin] then
      partDamageData[beam.partOrigin].beamsBroken = partDamageData[beam.partOrigin].beamsBroken + 1
    end

    -- Break coll tris
    if beam.collTris and not beam.disableTriangleBreaking then --allow beams to disable triangle breaking
      for _, ctid in ipairs(beam.collTris) do
        if collTriState[ctid] then
          collTriState[ctid] = collTriState[ctid] - 1
          if collTriState[ctid] <= 1 or beam.wheelID then
            obj:breakCollisionTriangle(ctid)
          end
        end
      end
    end

    -- Break the meshes
    if beam.disableMeshBreaking == nil or not beam.disableMeshBreaking then
      obj:breakMeshes(id)
    end

    -- Break rails
    obj:breakRails(id)

    -- Check for punctured tire
    if beam.wheelID ~= nil then
      deflateTire(beam.wheelID)
    elseif beam.pressureGroupId then
      obj:deflatePressureGroup(v.data.pressureGroups[beam.pressureGroupId])
    end

    -- breakgroup handling
    if beam.breakGroup then
      if type(beam.breakGroup) ~= "table" and breakGroupCache[beam.breakGroup] == nil then
        -- shortcircuit in case of broken single breakGroup
      else
        local breakGroups = type(beam.breakGroup) == "table" and beam.breakGroup or {beam.breakGroup}
        for _, g in ipairs(breakGroups) do
          if breakGroupCache[g] then
            props.hidePropsInBreakGroup(g)

            -- breakGroupType = 0 breaks the group
            -- breakGroupType = 1 does not break the group but will be broken by the group
            if beam.breakGroupType == 0 or beam.breakGroupType == nil then
              breakBreakGroup(g)
            end
          end
        end
      end
    end

    if beam.deformSwitches then
      breakMaterial(beam)
    end

    --experimental particle code: spawn plastic chunk particles when a beam connecting to plastic nodes breaks
    local breakNode1 = v.data.nodes[beam.id1].cid
    local breakNode2 = v.data.nodes[beam.id2].cid
    local particleType = 55 + math.floor(math.random(3)) --choose random particle number between 56 and 58 for plastic chunks
    local particleType_deformGroup1 = 68
    local particleType_deformGroup2 = 69
    local particleCount_deformGroup1 = 15
    local particleCount_deformGroup2 = 15
    if v.data.nodes[beam.id1].nodeMaterial == 3 or v.data.nodes[beam.id2].nodeMaterial == 3 then --check for plastic nodes connected to the beam
      obj:addParticleByNodesRelative(breakNode1, breakNode2, math.random(1), particleType, 0, 1)
    end
    if v.data.nodes[beam.id1].nodeMaterial == 6 or v.data.nodes[beam.id2].nodeMaterial == 6 then --check if it's a wooden prop, like the piano
      particleType_deformGroup1 = 12
      particleType_deformGroup2 = 12
      particleCount_deformGroup1 = 2
      particleCount_deformGroup2 = 2
    end
    if beam.deformGroup and beam.breakGroup then --check if beam is part of a breakgroup and a deformgroup, indicating that it's glass or wood
      obj:addParticleByNodesRelative(breakNode1, breakNode2, math.random(1), particleType_deformGroup1, (math.random(1) / 5), particleCount_deformGroup1) --spawn glass or wood particles
      obj:addParticleByNodesRelative(breakNode1, breakNode2, math.random(1), particleType_deformGroup2, (math.random(1) / 5), particleCount_deformGroup2)
    end
  else
    --print ("beam "..id.." just broke")
  end
end

local function searchForActiveParts(part, activeParts)
  if part.active then
    table.insert(activeParts, part.partName)
  end
  if part.parts then
    for _, subSlot in pairs(part.parts) do
      for _, subPart in pairs(subSlot) do
        searchForActiveParts(subPart, activeParts)
      end
    end
  end
end

local function updateCollTris()
  local vehicle = v.data
  if vehicle.beams and vehicle.triangles then
    local beamIndex = table.new(0, #vehicle.beams)

    for _, beam in pairs(vehicle.beams) do
      local b1, b2 = beam.id1, beam.id2
      if type(b1) == "number" and type(b2) == "number" then
        beamIndex[min(b1, b2) + max(b1, b2) * 1e+8] = beam
      end
    end

    for _, tri in pairs(vehicle.triangles) do
      local t1, t2, t3 = tri.id1, tri.id2, tri.id3
      if type(t1) == "number" and type(t2) == "number" and type(t3) == "number" then
        local beamCount = 0
        local bi = beamIndex[min(t1, t2) + max(t1, t2) * 1e+8]
        local tcid = tri.cid
        if bi then
          local coltris = bi.collTris or table.new(2, 0)
          if not tableContains(coltris, tcid) then
            table.insert(coltris, tcid)
            bi.collTris = coltris
            beamCount = beamCount + 1
          end
        end
        bi = beamIndex[min(t1, t3) + max(t1, t3) * 1e+8]
        if bi then
          local coltris = bi.collTris or table.new(2, 0)
          if not tableContains(coltris, tcid) then
            table.insert(coltris, tcid)
            bi.collTris = coltris
            beamCount = beamCount + 1
          end
        end
        bi = beamIndex[min(t2, t3) + max(t2, t3) * 1e+8]
        if bi then
          local coltris = bi.collTris or table.new(2, 0)
          if not tableContains(coltris, tcid) then
            table.insert(coltris, tcid)
            bi.collTris = coltris
            beamCount = beamCount + 1
          end
        end
        tri.beamCount = beamCount
      end
    end
  end
end

local function init()
  M.damage = 0
  M.damageExt = 0
  wheelBrokenBeams = {}

  beamDamageTracker = {}
  skeletonStateTimer = 0.25
  beamDamageTrackerDirty = false

  updateCollTris()

  triangleBreakGroupCache = {}
  local pressureBeams = {}

  -- Reset colltris
  if v.data.triangles then
    collTriState = {}
    for _, t in pairs(v.data.triangles) do
      if t.cid and t.beamCount then
        collTriState[t.cid] = t.beamCount
        --handle triangle breakgroups
        if t.breakGroup then
          local breakGroups = type(t.breakGroup) == "table" and t.breakGroup or {t.breakGroup}
          for _, g in pairs(breakGroups) do
            if not triangleBreakGroupCache[g] then
              triangleBreakGroupCache[g] = {}
            end
            table.insert(triangleBreakGroupCache[g], t.cid)
          end
        end
        if t.pressureGroup then
          pressureBeams[min(t.id1, t.id2) + max(t.id1, t.id2) * 1e+8] = t.pressureGroup
          pressureBeams[min(t.id1, t.id3) + max(t.id1, t.id3) * 1e+8] = t.pressureGroup
          pressureBeams[min(t.id2, t.id3) + max(t.id2, t.id3) * 1e+8] = t.pressureGroup
        end
      end
    end
  end

  breakGroupCache = {}
  brokenBreakGroups = {}
  M.deformGroupDamage = {}
  delayedPrecompBeams = {}
  initTimer = 0
  M.update = update

  autoCouplingActive = false
  autoCouplingNodeTag = nil
  autoCouplingTimer = 0
  autoCouplingTimeoutTimer = 0

  attachedCouplers = {}
  transmitCouplers = {}
  recievedElectrics = {}
  M.updateRemoteElectrics = nop

  couplerCache = {}
  couplerTags = {}
  hasActiveCoupler = false

  local xMin, xMax, yMin, yMax = math.huge, -math.huge, math.huge, -math.huge

  for _, n in pairs(v.data.nodes or {}) do
    local posx, posy = n.pos.x, n.pos.y
    xMin = min(posx, xMin)
    xMax = max(posx, xMax)
    yMin = min(posy, yMin)
    yMax = max(posy, yMax)

    if n.couplerTag or n.tag then
      couplerTags[n.couplerTag or n.tag] = true

      if n.cid then
        local data = shallowcopy(n)
        couplerCache[n.cid] = data
        hasActiveCoupler = n.couplerTag ~= nil or hasActiveCoupler

        if n.breakGroup then
          local breakGroups = type(n.breakGroup) == "table" and n.breakGroup or {n.breakGroup}
          for _, g in pairs(breakGroups) do
            if not couplerBreakGroupCache[g] then
              couplerBreakGroupCache[g] = {}
            end
            table.insert(couplerBreakGroupCache[g], n.cid)
          end
        end
      end
    end
  end

  couplerBreakGroupCacheOrig = shallowcopy(couplerBreakGroupCache)

  for _, c in pairs(couplerCache) do
    if c.couplerStartRadius and c.cid then
      obj:attachCoupler(c.cid, c.couplerTag or "", c.couplerStrength or 1000000, c.couplerStartRadius, c.couplerTargets or 0)
    end
  end

  M.monetaryDamage = 0
  lastDisplayedDamage = 0
  partDamageData = {}

  M.activeParts = {}
  for _, slot in pairs(v.data.slotMap or {}) do
    for _, part in pairs(slot) do
      searchForActiveParts(part, M.activeParts)
    end
  end

  local partValueSum = 0

  for partName, part in pairs(v.data.activeParts) do
    if part then
      local beamCount = tableSize(part.beams)
      local partValue = 0
      local name = "Unknown"
      if part.information then
        partValue = part.information.value or partValue
        name = part.information.name or name
      end
      partDamageData[partName] = {
        beamsBroken = 0,
        beamsDeformed = 0,
        beamCount = beamCount,
        currentDamage = 0,
        brokenBeamsThreshold = max(beamCount * 0.01, 1),
        deformedBeamsThreshold = max(beamCount * 0.75, 1),
        value = partValue,
        name = name
      }
      partValueSum = partValueSum + partValue
    else
      --log('E', 'beamstate', 'unable to get part: ' .. tostring(partName))
    end
  end

  partBeams = {}
  beamBodyPartLookup = {}
  bodyPartDamageTracker = {FL = 0, FR = 0, ML = 0, MR = 0, RL = 0, RR = 0}
  invBodyPartBeamCount = {FL = 0, FR = 0, ML = 0, MR = 0, RL = 0, RR = 0}
  table.clear(M.tagBeamMap)
  table.clear(M.linkTagBeamMap)

  local xRange = xMax - xMin
  local yRange = yMax - yMin
  local yRangeThird = yRange / 3
  local xRangeHalf = xRange * 0.5
  local yGroup1 = yMin + yRangeThird
  local yGroup2 = yGroup1 + yRangeThird
  local xGroup1 = xMin + xRangeHalf
  local nodes = v.data.nodes

  if v.data.beams then
    for bid, b in pairs(v.data.beams) do
      if b.tag then
        if type(b.tag) == "string" then
          M.tagBeamMap[b.tag] = M.tagBeamMap[b.tag] or {}
          table.insert(M.tagBeamMap[b.tag], bid)
        elseif type(b.tag) == "table" then
          for _, tag in b.tag do
            M.tagBeamMap[tag] = M.tagBeamMap[tag] or {}
            table.insert(M.tagBeamMap[tag], bid)
          end
        end
      end

      if b.linkTag then
        if type(b.linkTag) == "string" then
          M.linkTagBeamMap[b.linkTag] = M.linkTagBeamMap[b.linkTag] or {}
          table.insert(M.linkTagBeamMap[b.linkTag], bid)
        elseif type(b.tag) == "table" then
          for _, tag in b.linkTag do
            M.linkTagBeamMap[tag] = M.linkTagBeamMap[tag] or {}
            table.insert(M.linkTagBeamMap[tag], bid)
          end
        end
      end

      local pbId = pressureBeams[min(b.id1, b.id2) + max(b.id1, b.id2) * 1e+8]
      if pbId and v.data.pressureGroups[pbId] then
        b.pressureGroupId = pbId
      end

      if b.breakGroup then
        local breakGroups = type(b.breakGroup) == "table" and b.breakGroup or {b.breakGroup}
        for _, g in pairs(breakGroups) do
          if not breakGroupCache[g] then
            breakGroupCache[g] = table.new(2, 0)
          end
          table.insert(breakGroupCache[g], b.cid)
        end
      end

      if b.deformGroup then
        local deformGroups = type(b.deformGroup) == "table" and b.deformGroup or {b.deformGroup}
        for _, g in pairs(deformGroups) do
          local group = M.deformGroupDamage[g] or {eventCount = 0, damage = 0, maxEvents = 0, invMaxEvents = 0}
          group.maxEvents = group.maxEvents + 1 / max(b.deformationTriggerRatio or 1, 0.01)
          group.invMaxEvents = 1 / group.maxEvents
          M.deformGroupDamage[g] = group
        end
      end

      if type(b.beamPrecompressionTime) == "number" and b.beamPrecompressionTime > 0 then
        table.insert(delayedPrecompBeams, b)
      end

      if not b.wheelID then
        local beamNode1Pos = nodes[b.id1].pos
        local beamNode2Pos = nodes[b.id2].pos
        local beamPosX = (beamNode1Pos.x + beamNode2Pos.x) * 0.5
        local beamPosY = (beamNode1Pos.y + beamNode2Pos.y) * 0.5
        local yChar = beamPosY <= yGroup1 and "F" or (beamPosY <= yGroup2 and "M" or "R")
        local xChar = beamPosX <= xGroup1 and "R" or "L"
        local bodyPart = yChar .. xChar
        beamBodyPartLookup[b.cid] = bodyPart
        invBodyPartBeamCount[bodyPart] = invBodyPartBeamCount[bodyPart] + 1
      end

      local bpo = b.partOrigin
      if bpo and partDamageData[bpo] then
        partDamageData[bpo].beamCount = partDamageData[bpo].beamCount + 1
        partBeams[bpo] = partBeams[bpo] or table.new(2, 0)
        table.insert(partBeams[bpo], b.cid)
      end
    end
  end

  for k, v in pairs(invBodyPartBeamCount) do
    invBodyPartBeamCount[k] = 1 / v
    damageTracker.setDamage("body", k, 0)
  end
end

-- only being called if the beam has deform triggers
local function beamDeformed(id, ratio)
  --log('D', "beamstate.beamDeformed","beam "..id.." deformed with ratio "..ratio)
  beamDamageTracker[id] = ratio
  beamDamageTrackerDirty = true

  local bodyPart = beamBodyPartLookup[id]
  if bodyPart then
    bodyPartDamageTracker[bodyPart] = bodyPartDamageTracker[bodyPart] + ratio
    local damage = bodyPartDamageTracker[bodyPart] * invBodyPartBeamCount[bodyPart]
    if damage > 0.001 then
      damageTracker.setDamage("body", bodyPart, damage)
    end
  end

  if v.data.beams[id] then
    local b = v.data.beams[id]
    if b.partOrigin and partDamageData[b.partOrigin] then
      partDamageData[b.partOrigin].beamsDeformed = partDamageData[b.partOrigin].beamsDeformed + 1
    end

    if b.deformSwitches then
      breakMaterial(b)
    end

    if b.deformGroup then
      if type(b.deformGroup) == "table" then
        for _, g in ipairs(b.deformGroup) do
          local group = M.deformGroupDamage[g]
          group.eventCount = group.eventCount + 1
          group.damage = group.eventCount * group.invMaxEvents
        end
      else
        local group = M.deformGroupDamage[b.deformGroup]
        group.eventCount = group.eventCount + 1
        group.damage = group.eventCount * group.invMaxEvents
      end
    end
  end
end

local function reset()
  init()
  M.lowpressure = false
end

local function breakAllBreakgroups()
  for _, b in pairs(v.data.beams) do
    if b.breakGroup ~= nil then
      obj:breakBeam(b.cid)
    end
  end
end

local function breakHinges()
  for _, b in pairs(v.data.beams) do
    if b.breakGroup ~= nil then
      local breakGroups = type(b.breakGroup) == "table" and b.breakGroup or {b.breakGroup}
      -- multiple break groups
      for _, g in pairs(breakGroups) do
        if type(g) == "string" and (string.find(g, "hinge") ~= nil or string.find(g, "latch") ~= nil) then
          --log('D', "beamstate.breakHinges","  breaking hinge beam "..k.. " as in breakgroup ".. b.breakGroup)
          obj:breakBeam(b.cid)
          break
        end
      end
    end
  end
end

local function deflateTires()
  for i, _ in pairs(wheels.wheels) do
    deflateTire(i)
  end
end

local function triggerDeformGroup(group)
  if group == nil then
    return
  end
  for _, b in pairs(v.data.beams) do
    if b.deformSwitches ~= nil then
      local deformSwitchesT = type(b.deformSwitches) == "table" and b.deformSwitches or {b.deformSwitches}
      for _, g in pairs(deformSwitchesT) do
        if g.deformGroup == group then
          breakMaterial(b)
          return
        end
      end
    end
  end
end

local function addDamage(damage)
  M.damageExt = M.damageExt + damage
end

local function sendUISkeleton()
  local data = {}
  for _, beam in pairs(v.data.beams) do
    local n1 = v.data.nodes[beam.id1]
    local n2 = v.data.nodes[beam.id2]
    -- only beams with deformationTriggerRatio will actually change ...
    --if beam.deformationTriggerRatio then
    data[beam.cid + 1] = {n1.pos, n2.pos}
    --end
  end
  if not playerInfo.firstPlayerSeated then
    return
  end
  guihooks.trigger("VehicleSkeleton", data)
  sendUISkeletonState()
end

local function hasCouplers()
  for _, val in pairs(couplerCache) do
    if (val.couplerWeld ~= true and val.couplerTag) and val.cid then
      return true
    end
  end

  return false
end

local function save(filename)
  if filename == nil then
    filename = v.data.vehicleDirectory .. "/vehicle.save.json"
  end
  -- TODO: color
  local save = {}
  save.format = "v2"
  save.model = v.data.model --.vehicleDirectory:gsub("vehicles/", ""):gsub("/", "")
  save.parts = v.userPartConfig
  save.vars = v.userVars
  save.vehicleDirectory = v.data.vehicleDirectory
  save.nodeCount = tableSizeC(v.data.nodes)
  save.beamCount = tableSizeC(v.data.beams)
  save.luaState = serialize(serializePackages("save"))
  save.hydros = {}
  for _, h in pairs(hydros.hydros) do
    table.insert(save.hydros, h.state)
  end

  save.nodes = {}
  for _, node in pairs(v.data.nodes) do
    local d = {
      obj:getNodePosition(node.cid):toTable()
    }
    if math.abs(obj:getOriginalNodeMass(node.cid) - obj:getNodeMass(node.cid)) > 0.1 then
      table.insert(d, obj:getNodeMass(node.cid))
    end
    save.nodes[node.cid + 1] = d
  end
  save.beams = {}
  for _, beam in pairs(v.data.beams) do
    local d = {
      obj:getBeamRestLength(beam.cid),
      obj:beamIsBroken(beam.cid),
      obj:getBeamDeformation(beam.cid)
    }
    save.beams[beam.cid + 1] = d
  end
  jsonWriteFile(filename, save, true)
end

local function load(filename)
  if filename == nil then
    filename = v.data.vehicleDirectory .. "/vehicle.save.json"
  end

  local save = jsonReadFile(filename)

  -- satefy checks
  if not save or save.nodeCount ~= tableSizeC(v.data.nodes) or save.beamCount ~= tableSizeC(v.data.beams) or save.vehicleDirectory ~= v.data.vehicleDirectory or save.format ~= "v2" then
    log("E", "save", "unable to load vehicle: invalid vehicle loaded?")
    return
  end

  importPersistentData(save.luaState)

  for k, h in pairs(save.hydros) do
    hydros.hydros[k].state = h
  end

  for cid, node in pairs(save.nodes) do
    cid = tonumber(cid) - 1
    obj:setNodePosition(cid, vec3(node[1]))
    if #node > 1 then
      obj:setNodeMass(cid, node[2])
    end
  end

  for cid, beam in pairs(save.beams) do
    cid = tonumber(cid) - 1
    obj:setBeamLength(cid, beam[1])
    if beam[2] == true then
      obj:breakBeam(cid)
    end
    if beam[3] > 0 then
      -- deformation: do not call c++ at all, its just used on the lua side anyways
      --print('deformed: ' .. tostring(cid) .. ' = ' .. tostring(beam[3]))
      beamDeformed(cid, beam[3])
    end
  end

  obj:commitLoad()
end

local function getVehicleState(...)
  -- fake delay, to be used only during development, to emulate possible framerate issues in slower computers and prevent abuse this API
  log("W", "", "getVehicleState delay")
  local timer, fakeDelay = HighPerfTimer(), 1
  while fakeDelay > 0 do
    fakeDelay = fakeDelay - timer:stopAndReset() / 1000
  end

  local pos = obj:getPosition()
  local front = obj:getDirectionVector()
  local up = obj:getDirectionVectorUp()
  local vehicleState = {objId = obj:getId(), partsCondition = partCondition.getConditions(), itemId = v.config.itemId, pos = pos, front = front, up = up}
  return vehicleState, ...
end

local function getPartDamageData()
  local damageData = {}
  for partName, partData in pairs(partDamageData) do
    local brokenCoef = clamp(partData.beamsBroken / partData.brokenBeamsThreshold, 0, 1)
    local deformedCoef = (clamp(partData.beamsDeformed / partData.deformedBeamsThreshold, 0, 1))
    local damageScore = max(brokenCoef, deformedCoef)
    if damageScore > 0 then
      damageData[partName] = {name = partData.name, damage = damageScore}
    end
  end
  return damageData
end

local function exportPartDamageData()
  local damageData = getPartDamageData()
  dumpToFile("partDamage.json", damageData)
end

local function isPhysicsStepUsed()
  return M.update == update
end

-- public interface
M.beamBroken = beamBroken
M.reset = reset
M.init = init
M.deflateTire = deflateTire
M.updateGFX = updateGFX
M.beamDeformed = beamDeformed
M.breakAllBreakgroups = breakAllBreakgroups
M.breakHinges = breakHinges
M.deflateTires = deflateTires
M.breakBreakGroup = breakBreakGroup
M.triggerDeformGroup = triggerDeformGroup
M.addDamage = addDamage
M.activateAutoCoupling = activateAutoCoupling
M.disableAutoCoupling = disableAutoCoupling
M.couplerFound = couplerFound
M.onCouplerAttached = onCouplerAttached
M.onCouplerDetached = onCouplerDetached
M.getCouplerOffset = getCouplerOffset
M.setCouplerVisiblityExternal = setCouplerVisiblityExternal
M.exportCouplerData = exportCouplerData
M.importCouplerData = importCouplerData
M.hasCouplers = hasCouplers

M.load = load
M.save = save

-- Input
M.toggleCouplers = toggleCouplers
M.attachCouplers = attachCouplers
M.detachCouplers = detachCouplers
M.couplerExists = couplerExists

-- for the UI
M.requestSkeletonState = sendUISkeletonState
M.requestSkeleton = sendUISkeleton

M.addPlanet = addPlanet
M.delPlanet = delPlanet
M.setPlanets = setPlanets

M.getVehicleState = getVehicleState
M.getPartDamageData = getPartDamageData
M.exportPartDamageData = exportPartDamageData
M.isPhysicsStepUsed = isPhysicsStepUsed

M.setPartCondition = setPartCondition
M.getPartCondition = getPartCondition

return M
