local M = {}

local max = math.max
local min = math.min
local abs = math.abs
local sqrt = math.sqrt
local sin = math.sin
local cos = math.cos

local smoothers = require("common/BeamMP/smoothers")

local function newVectorSmoothing(rate)
 return smoothers.newVectorSmoothing(rate)
end

-- Limit vector length
local function limitVecLength(vec, length)
  local vecLength = vec:squaredLength()
  if isnaninf(vecLength) then
    vec:set(0, 0, 0)
    return vec
  end
  length = length ^ 2
  if vecLength > length then
    vec:setScaled(sqrt(length / vecLength))
  end
  return vec
end

-- quite a few functions here are AI, they work as far as i can tell, but performance could be better

-- Calculate angular velocity from two direction vectors
local function calcAngularVelocity(d1, d2, dt)
  d1:normalize()
  d2:normalize()

  local cross = d1:cross(d2)
  local crossLen = cross:length()

  if crossLen < 1e-9 then return vec3(0, 0, 0) end

  local angle = math.asin(min(crossLen, 1.0))
  if d1:dot(d2) < 0 then
    angle = math.pi - angle
  end

  return (cross / crossLen) * (angle / dt)
end

local vecDirPredictor = {}
vecDirPredictor.__index = vecDirPredictor

function vecDirPredictor:new(
    bufferLen,
    AngularVelSmoothing,
    AngularAccSmoothing,
    DirectionSmoothing,
    totalVelSmoothing,
    maxBufferReadOffset
)
  self.timer = 0
  self.recTime = 0

  self.bufferData = {}
  self.bufferLen = bufferLen or 50

  for i = 1, self.bufferLen do
    self.bufferData[i] = {
      pos = vec3(),
      vel = vec3(),
      totalVel = 0,
      acc = vec3(),
      totalAcc = 0,
      dir = vec3(),
      dirAngularVel = vec3(),
      dirAngularAcc = vec3(),
      time = 0,
      multiplier = 1,   -- used for things like simulation speed to not overPredict
    }
  end

  self.bufferReadOffset = 0
  self.maxBufferReadOffset = maxBufferReadOffset or 0
  self.bufferOffsetSmoother = newTemporalSmoothingNonLinear(0.6, 5.6)

  self.currentBufferID = 1

  self.interPolated = {
    pos = vec3(),
    vel = vec3(),
    totalVel = 0,
    acc = vec3(),
    totalAcc = 0,
    dir = vec3(),
    dirAngularVel = vec3(),
    dirAngularAcc = vec3(),
    time = 0,
    multiplier = 1,     -- used for things like simulation speed to not overPredict
  }

  self.currentValues = {
    pos = vec3(),
    vel = vec3(),
    totalVel = 0,
    acc = vec3(),
    totalAcc = 0,
    dir = vec3(),
    dirAngularVel = vec3(),
    dirAngularAcc = vec3(),
    time = 0,
    multiplier = 1,     -- used for things like simulation speed to not overPredict
  }

  self.predictSmooth = newVectorSmoothing(50)

  self.AngularVelSmoother = newVectorSmoothing(AngularVelSmoothing or 3)
  self.AngularAccSmoother = newVectorSmoothing(AngularAccSmoothing or 4)
  self.dirSmoother = newVectorSmoothing(DirectionSmoothing or 20)
  self.totalVelSmoother = newTemporalSmoothingNonLinear(totalVelSmoothing or 20)
end

function vecDirPredictor:add(pos, vel, time, mul, currentTime)
  local lastData = self.bufferData[self.currentBufferID]
  if lastData then
    self.currentBufferID = self.currentBufferID + 1
    if self.currentBufferID > self.bufferLen then
      self.currentBufferID = 1
    end
  end
  local nextData = self.bufferData[self.currentBufferID]

  time = time or os:clockhp()

  local dt = max(time - lastData.time, 0.001)
  local ping = (currentTime or time) - lastData.time   --time

  if lastData.time ~= 0 then                 -- TODO figure out if we should use the DT from last time for the smoother, this makes interpolation smooth, but adds one more tick of latency
    self.bufferReadOffset = self.bufferOffsetSmoother:get(max(0, min(1, max(ping))), dt)
  end
  nextData.pos:set(pos)
  nextData.vel:set(vel)
  nextData.totalVel = vel:length()

  nextData.acc:setSub2(vel, lastData.vel)
  nextData.acc:setScaled(1 / dt)
  --limitVecLength(nextData.acc, self.maxAcc)
  nextData.totalAcc = nextData.acc:length()

  nextData.dir:set(vel)
  nextData.dir:normalize()
  nextData.dirAngularVel = calcAngularVelocity(lastData.dir, nextData.dir, dt)
  nextData.dirAngularAcc:setSub2(nextData.dirAngularVel, lastData.dirAngularVel)
  nextData.dirAngularAcc:setScaled(1 / dt)
  --limitVecLength(nextData.dirAngularAcc, self.maxAcc)

  nextData.time = time
  nextData.multiplier = mul or 1
end

local d = vec3()
local add = vec3()
local sub = vec3()
local tempVec = vec3()

local vel = vec3()
local axCrossV = vec3()

local omega0 = vec3()
local omega1 = vec3()
local omegaT = vec3()

local omega = vec3()

local p1vel = vec3()
local p2vel = vec3()
local p1acc = vec3()
local p2acc = vec3()
local p1dirAngularVel = vec3()
local p2dirAngularVel = vec3()
local p1dirAngularAcc = vec3()
local p2dirAngularAcc = vec3()

local function interpolateBuffer(p1, p2, renderTime, result)
  local dt = p2.time - p1.time
  if dt < 1e-9 then return p2 end

  local t = (renderTime - p1.time) / dt
  t = max(0, min(1, t))
  local t2 = t * t
  local t3 = t2 * t

  -- === TIME & MULTIPLIER ===
  result.time = renderTime
  result.multiplier = p1.multiplier + (p2.multiplier - p1.multiplier) * t

  local p1totalVel = p1.totalVel * result.multiplier
  local p2totalVel = p2.totalVel * result.multiplier

  local p1totalAcc = p1.totalAcc * result.multiplier
  local p2totalAcc = p2.totalAcc * result.multiplier

  p1vel:setScaled2(p1.vel, result.multiplier)
  p2vel:setScaled2(p2.vel, result.multiplier)

  p1acc:setScaled2(p1.acc, result.multiplier)
  p2acc:setScaled2(p2.acc, result.multiplier)

  p1dirAngularVel:setScaled2(p1.dirAngularVel, result.multiplier)
  p2dirAngularVel:setScaled2(p2.dirAngularVel, result.multiplier)

  p1dirAngularAcc:setScaled2(p1.dirAngularAcc, result.multiplier)
  p2dirAngularAcc:setScaled2(p2.dirAngularAcc, result.multiplier)

  -- === POSITION ===
  -- Hermite with velocity tangents
  local h00 = 2 * t3 - 3 * t2 + 1
  local h10 = t3 - 2 * t2 + t
  local h01 = -2 * t3 + 3 * t2
  local h11 = t3 - t2

  add:setScaled2(p1.pos, h00)        --    result.pos = p1.pos * h00
  result.pos:set(add)                --               + p1.vel * (h10 * dt)
  add:setScaled2(p1vel, (h10 * dt))  --               + p2.pos * h01
  result.pos:setAdd(add)             --               + p2vel * (h11 * dt)
  add:setScaled2(p2.pos, h01)
  result.pos:setAdd(add)
  add:setScaled2(p2vel, (h11 * dt))
  result.pos:setAdd(add)

  -- === VELOCITY ===
  -- hermite derivative, gives smooth vel through the segment
  local dh00 = (6 * t2 - 6 * t) / dt
  local dh10 = (3 * t2 - 4 * t + 1)
  local dh01 = (-6 * t2 + 6 * t) / dt
  local dh11 = (3 * t2 - 2 * t)


  add:setScaled2(p1.pos, dh00)  --    result.vel = p1.pos * dh00
  result.vel:set(add)           --               + p1vel * dh10
  add:setScaled2(p1vel, dh10)   --               + p2.pos * dh01
  result.vel:setAdd(add)        --               + p2vel * dh11
  add:setScaled2(p2.pos, dh01)
  result.vel:setAdd(add)
  add:setScaled2(p2vel, dh11)
  result.vel:setAdd(add)

  result.totalVel = p1totalVel + (p2totalVel - p1totalVel) * t

  -- === ACCELERATION ===
  -- lerp is fine, acc changes are noisy and cubic would amplify that
  --result.acc = p1.acc + (p2.acc - p1.acc) * t
  result.acc:setSub2(p2acc, p1acc)
  result.acc:setScaled(t)
  result.acc:setAdd(p1acc)

  result.totalAcc = p1totalAcc + (p2totalAcc - p1totalAcc) * t

  -- === DIRECTION ===
  -- slerp between the two direction vectors using angular velocity as tangent
  -- integrate angular velocity over time to get the rotation angle
  omega0:set(p1dirAngularVel)
  omega1:set(p2dirAngularVel)

  -- lerp omega at this t, then integrate to get total rotation
  --local omegaT = omega0 + (omega1 - omega0) * t
  omegaT:setSub2(omega1, omega0)
  omegaT:setScaled(t)
  omegaT:setAdd(omega0)

  local angle = omegaT:length() * dt * t
  if angle > 1e-9 then
    local axis = omegaT
    axis:normalize()
    local cos_a = cos(angle)
    local sin_a = sin(angle)
    d:set(p1.dir)

    --result.dir = (d * cos_a + axis:cross(d) * sin_a + axis * axis:dot(d) * (1 - cos_a)):normalized()
    add:setScaled2(d, cos_a)
    result.dir:set(add)

    local cross = axCrossV
    cross:setCross(axis, d)
    add:setScaled2(cross, sin_a)
    result.dir:setAdd(add)

    add:setScaled2(axis, axis:dot(d) * (1 - cos_a))
    result.dir:setAdd(add)
  else
    result.dir:set(p1.dir)
  end

  -- === ANGULAR VELOCITY ===
  -- hermite on the angular velocity vector using angular acc as tangent
  -- result.dirAngularVel = p1.dirAngularVel * h00
  --                      + p1.dirAngularAcc * (h10 * dt)
  --                      + p2.dirAngularVel * h01
  --                      + p2.dirAngularAcc * (h11 * dt)
  add:setScaled2(p1dirAngularVel, h00)
  result.dirAngularVel:set(add)
  add:setScaled2(p1dirAngularAcc, (h10 * dt))
  result.dirAngularVel:setAdd(add)
  add:setScaled2(p2dirAngularVel, h01)
  result.dirAngularVel:setAdd(add)
  add:setScaled2(p2dirAngularAcc, (h11 * dt))
  result.dirAngularVel:setAdd(add)

  -- === ANGULAR ACCELERATION ===
  --result.dirAngularAcc = p1.dirAngularAcc + (p2.dirAngularAcc - p1.dirAngularAcc) * t

  result.dirAngularAcc:setSub2(p2dirAngularAcc, p1dirAngularAcc)
  result.dirAngularAcc:setScaled(t)
  result.dirAngularAcc:setAdd(p1dirAngularAcc)
  result.dir:normalize()

  return result
end

local debugDrawer = obj and obj.debugDrawProxy or nil --TODO add support for GE debugDrawer
local pos = vec3()
local predictAdd = vec3()

function vecDirPredictor:get(timeStamp, dt, offset, multiplier, set)
  local bufferData = self.bufferData
  local currentBuffLen = self.bufferLen
  local bufferID = (self.currentBufferID)
  local lastBufferID = (self.currentBufferID)
  local count = 0
  local buffTime = timeStamp - max(self.bufferReadOffset, offset)

  -- backtrack into the buffer
  if bufferID == 0 then bufferID = currentBuffLen end
  while true do
    if bufferData[bufferID].time == 0 and lastBufferID ~= bufferID then
      bufferID = lastBufferID
      break
    end
    if buffTime >= bufferData[bufferID].time then
      break
    end

    count = count + 1
    if count > currentBuffLen then break end

    lastBufferID = bufferID
    bufferID = bufferID - 1
    if bufferID == 0 then bufferID = currentBuffLen end
  end
  local lastPosData = bufferData[bufferID]
  local remoteVehData = bufferData[self.currentBufferID]

  local rawLatency = timeStamp - remoteVehData.time

  --interpolate
  local isCurrentIndex = bufferID == self.currentBufferID
  local isTeleport
  if not isCurrentIndex then
    local nextBufferID = bufferID + 1
    if nextBufferID > currentBuffLen then nextBufferID = 1 end
    local nextPosData = bufferData[nextBufferID]
    local dt = max(nextPosData.time - lastPosData.time, 0.001)
    vel:setSub2(nextPosData.pos, lastPosData.pos)
    vel:setScaled(1 / dt)
    local velDiff = abs((nextPosData.totalVel ^ 2) - vel:squaredLength())
    if nextPosData.totalVel < 5 and velDiff > 5 ^ 2 or velDiff > 50 ^ 2 then
      isTeleport = true
    end
    if not isTeleport then
      remoteVehData = interpolateBuffer(lastPosData, nextPosData, buffTime, self.interPolated)
    end
  end

  if self.enableDebug and debugDrawer then
    debugDrawer:drawSphere(0.2, lastPosData.pos, color(255,0,255,200))
    debugDrawer:drawSphere(0.3, remoteVehData.pos, color(0,0,255,200))
    debugDrawer:drawSphere(0.2, bufferData[self.currentBufferID].pos, color(255,0,0,200))

  	local lastPos = vec3()
  	local lastTime2 = 0
  	local first = true
  	for k,v in pairs(bufferData) do
  		if not first and v.time > lastTime2 then
  			debugDrawer:drawCylinder(lastPos, v.pos,0.01, color(255,255,255,200))
  		end
  		lastPos:set(v.pos)
  		lastTime2 = v.time
  		first = false
  	end
  end

  local predictTime = (timeStamp - remoteVehData.time) * remoteVehData.multiplier
  local smootherDT = dt / guardZero(abs(predictTime))

  --update smoothers
  local current = self.currentValues
  if set or isTeleport then
    self.AngularVelSmoother:set(remoteVehData.dirAngularVel)
    self.dirSmoother:set(remoteVehData.dir)
    self.AngularAccSmoother:set(remoteVehData.acc)
    self.totalVelSmoother:set(remoteVehData.totalVel)
    current.pos:set(remoteVehData.pos)
  end
  current.dirAngularVel:set(self.AngularVelSmoother:get(remoteVehData.dirAngularVel, smootherDT))
  current.dir:set(self.dirSmoother:get(remoteVehData.dir, smootherDT))
  current.dir:normalize()
  current.acc:set(self.AngularAccSmoother:get(remoteVehData.acc, smootherDT))
  current.totalVel = self.totalVelSmoother:get(remoteVehData.totalVel, smootherDT)

  -- direction vector prediction
  local velMul = clamp(-0.1 + remoteVehData.totalVel / 3, 0, 1)
  if not set and velMul > 0 then
    omega:set(current.dirAngularVel) -- angular velocity vector
    local omegaLen = omega:length()
    if omegaLen < 1e-9 then
      local accAlongDir = current.dir:dot(current.acc)
      local totalDist = current.totalVel * predictTime + 0.5 * accAlongDir * predictTime * predictTime
      predictAdd:setScaled2(current.dir, totalDist)
    else
      vel:setScaled2(current.dir, current.totalVel)
      local accAlongDir = current.dir:dot(current.acc)

      local axis = omega
      axis:normalize()
      local angle = omegaLen * predictTime
      local cos_a = cos(angle)
      local sin_a = sin(angle)
      local invOmega = 1.0 / omegaLen

      local axDotV = axis:dot(vel)
      axCrossV:setCross(axis, vel)

      -- original arc terms (constant velocity)
      local ax = vel.x * sin_a * invOmega + axCrossV.x * (1 - cos_a) * invOmega +
      axis.x * axDotV * (predictTime - sin_a * invOmega)
      local ay = vel.y * sin_a * invOmega + axCrossV.y * (1 - cos_a) * invOmega +
      axis.y * axDotV * (predictTime - sin_a * invOmega)
      local az = vel.z * sin_a * invOmega + axCrossV.z * (1 - cos_a) * invOmega +
      axis.z * axDotV * (predictTime - sin_a * invOmega)

      local pt2 = predictTime * predictTime
      local accTerm = 0.5 * accAlongDir * pt2

      predictAdd:set(
        ax + current.dir.x * accTerm,
        ay + current.dir.y * accTerm,
        az + current.dir.z * accTerm
      )
    end
  end
  if set then
    self.predictSmooth:set(predictAdd)
  end
  -- xyz prediction, used when moving very slowly to fix direction vector from spinning around
  local predictAddXYZ = vel
  predictAddXYZ:setScaled2(remoteVehData.vel, predictTime)
  predictAddXYZ:set(self.predictSmooth:get(predictAddXYZ, smootherDT))

  -- scale direction vector prediction and XYZ prediction to overlap between slow and higher speeds
  predictAddXYZ:setScaled(1 - velMul)
  predictAdd:setScaled(velMul)
  pos:set(remoteVehData.pos)
  pos:setAdd(predictAdd)
  pos:setAdd(predictAddXYZ)

  if self.enableDebug and debugDrawer then
    debugDrawer:drawText(pos:toFloat3(), color(0,0,0,255), string.format("Prediction: %.0f ms", predictTime*1000))
    debugDrawer:drawText(pos:toFloat3() + vec3(0,0,1), color(0,0,0,255), string.format("rawLatency: %.0f ms", rawLatency*1000))
    debugDrawer:drawSphere(0.2, pos, color(0,255,0,200))
    debugDrawer:drawSphere(0.1, bufferData[self.currentBufferID].pos, color(255,0,0,200))
    debugDrawer:drawSphere(0.2, remoteVehData.pos+predictAdd, color(0,255,0,200))
  end

  return pos, remoteVehData.vel, remoteVehData.acc, isTeleport, predictTime
end

function vecDirPredictor:reset()
  self.timer = 0
  self.recTime = 0

  self.bufferReadOffset = 0
  self.bufferOffsetSmoother:reset()
  self.currentBufferID = 1

  self.interPolated.pos:set(0, 0, 0)
  self.interPolated.vel:set(0, 0, 0)
  self.interPolated.totalVel = 0
  self.interPolated.acc:set(0, 0, 0)
  self.interPolated.totalAcc = 0
  self.interPolated.dir:set(0, 0, 0)
  self.interPolated.dirAngularVel:set(0, 0, 0)
  self.interPolated.dirAngularAcc:set(0, 0, 0)
  self.interPolated.time = 0
  self.interPolated.multiplier = 1

  self.currentValues.pos:set(0, 0, 0)
  self.currentValues.vel:set(0, 0, 0)
  self.currentValues.totalVel = 0
  self.currentValues.acc:set(0, 0, 0)
  self.currentValues.totalAcc = 0
  self.currentValues.dir:set(0, 0, 0)
  self.currentValues.dirAngularVel:set(0, 0, 0)
  self.currentValues.dirAngularAcc:set(0, 0, 0)
  self.currentValues.time = 0
  self.currentValues.multiplier = 1

  self.predictSmooth:reset()

  self.AngularVelSmoother:reset()
  self.AngularAccSmoother:reset()
  self.dirSmoother:reset()

  for i = 1, self.bufferLen do
    local data = self.bufferData[i]
    data.pos:set(0, 0, 0)
    data.vel:set(0, 0, 0)
    data.totalVel = 0
    data.acc:set(0, 0, 0)
    data.totalAcc = 0
    data.dir:set(0, 0, 0)
    data.dirAngularVel:set(0, 0, 0)
    data.dirAngularAcc:set(0, 0, 0)
    data.time = 0
    data.multiplier = 1
    self.bufferData[i] = data
  end
end

local quaternionPredictor = {}
quaternionPredictor.__index = quaternionPredictor

function quaternionPredictor:new(
    bufferLen,
    rotVelSmooth,
    rotAccSmooth,
    maxBufferReadOffset
)

  self.timer = 0
  self.maxRotAcc = 1000

  self.recordingBuffer = {}
  self.record = false
  self.startTime = nil
  self.bufferData = {}
  self.bufferLen = bufferLen or 100

  for i = 1, self.bufferLen do
    self.bufferData[i] = {
      rot = quat(),
      rotVel = vec3(),
      rotAcc = vec3(),
      time = 0,
      multiplier = 1,   -- used for things like simulation speed to not overPredict
    }
  end

  self.bufferReadOffset = 0
  self.maxBufferReadOffset = maxBufferReadOffset or 0
  self.bufferOffsetSmoother = newTemporalSmoothingNonLinear(0.3, 5.6)
  self.bufferOffsetSmoother:set(0.2)
  self.currentBufferID = 1

  self.currentValues = {
    rot = quat(),
    rotVel = vec3(),
    rotAcc = vec3(),
    time = 0,
    multiplier = 1,     -- used for things like simulation speed to not overPredict
  }

  self.rot = quat()
  self.rotVel = vec3()
  self.rotAcc = vec3()
  self.rotVelSmoother = newVectorSmoothing(rotVelSmooth or 1.3)
  self.rotAccSmoother = newVectorSmoothing(rotAccSmooth or 0.2)

  self.interPolated = {
    rot = quat(),
    rotVel = vec3(),
    rotAcc = vec3(),
    time = 0,
    multiplier = 1,     -- used for things like simulation speed to not overPredict
  }
end

function quaternionPredictor:add(rot, rotVel, time, mul, currentTime)
  local lastData = self.bufferData[self.currentBufferID]
  if lastData then
    self.currentBufferID = self.currentBufferID + 1
    if self.currentBufferID > self.bufferLen then
      self.currentBufferID = 1
    end
  end
  local nextData = self.bufferData[self.currentBufferID]

  time = time or os:clockhp()

  local dt = max(time - lastData.time, 0.001)
  local ping = max(currentTime - lastData.time, 0.001)
  --local ping = max(currentTime - time, 0.001)
  if lastData.time ~= 0 then
    self.bufferReadOffset = self.bufferOffsetSmoother:get(min(1, max(ping, abs(dt))), dt)
  end

  nextData.rot:set(rot)
  nextData.rotVel:set(rotVel)
  nextData.rotAcc:set(limitVecLength((nextData.rotVel - lastData.rotVel) / dt, self.maxRotAcc))


  nextData.time = time
  nextData.multiplier = mul

  if self.record then
    if not self.startTime then
      self.startTime = time
    end
    local index = math.floor(time - self.startTime)
    if not self.recordingBuffer[index] then
      self.recordingBuffer[index] = {}
    end
    table.insert(self.recordingBuffer[index], nextData)
  end
end

local function slerpQuat(a, b, t) -- AI function since i was getting flips with the mathlib slerp function
  local dot = a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w

  -- Take shortest path
  local bx, by, bz, bw = b.x, b.y, b.z, b.w
  if dot < 0 then
    dot = -dot
    bx, by, bz, bw = -bx, -by, -bz, -bw
  end

  local sx, sy, sz, sw
  if dot > 0.9995 then
    -- Nearly identical, linear interpolate to avoid divide-by-zero in sin
    sx = a.x + (bx - a.x) * t
    sy = a.y + (by - a.y) * t
    sz = a.z + (bz - a.z) * t
    sw = a.w + (bw - a.w) * t
  else
    local angle    = math.acos(dot)
    local sinAngle = math.sqrt(1.0 - dot * dot)   -- == sin(angle), avoids second trig call
    local fa       = math.sin((1 - t) * angle) / sinAngle
    local fb       = math.sin(t * angle) / sinAngle
    sx             = a.x * fa + bx * fb
    sy             = a.y * fa + by * fb
    sz             = a.z * fa + bz * fb
    sw             = a.w * fa + bw * fb
  end

  -- Normalize output (guards against accumulated float error)
  local inv = 1.0 / math.sqrt(sx * sx + sy * sy + sz * sz + sw * sw)
  return sx * inv, sy * inv, sz * inv, sw * inv
end

-- Integrate angular velocity into quaternion (exact rotation)
local function quat_integrate_exact(lastPosData, nextPosData, buffTime, interpolated)
  local dt = nextPosData.time - lastPosData.time
  if dt < 1e-9 then return nextPosData end

  local t = (buffTime - lastPosData.time) / dt
  t = max(0, min(1, t))

  -- Slerp between integrated and b.rot for smoothness
  interpolated.rot:set(slerpQuat(lastPosData.rot, nextPosData.rot, t))

  -- Lerp velocity and acceleration
  interpolated.rotVel     = lastPosData.rotVel + (nextPosData.rotVel - lastPosData.rotVel) * t
  interpolated.rotAcc     = lastPosData.rotAcc + (nextPosData.rotAcc - lastPosData.rotAcc) * t

  interpolated.time       = buffTime
  interpolated.multiplier = lastPosData.multiplier + (nextPosData.multiplier - lastPosData.multiplier) * t
  return interpolated
end

local tempQuat = quat()

local function predict_quaternion(rot, rvel, q, angular_velocity, angular_acceleration, predictTime)
  -- Update angular velocity
  angular_acceleration:setScaled(predictTime)
  angular_velocity:setAdd(angular_acceleration)

  local x, y, z = angular_velocity.x, angular_velocity.y, angular_velocity.z
  local theta = sqrt(x * x + y * y + z * z) * predictTime

  if theta < 1e-6 then
    -- Small angle: use first-order approximation
    local half_theta = 0.5 * theta
    local dw = -half_theta * (q.x * x + q.y * y + q.z * z) * predictTime
    local dx = half_theta * (q.w * x + q.y * z - q.z * y) * predictTime
    local dy = half_theta * (q.w * y - q.x * z + q.z * x) * predictTime
    local dz = half_theta * (q.w * z + q.x * y - q.y * x) * predictTime
    q.w, q.x, q.y, q.z = q.w + dw, q.x + dx, q.y + dy, q.z + dz
  else
    -- Exponential map: q_new = exp(0.5 * ω * dt) * q_old
    local half_theta = 0.5 * theta
    local s = sin(half_theta) / (theta / predictTime)
    local c = cos(half_theta)

    local qw, qx, qy, qz = q.w, q.x, q.y, q.z
    q.w = c * qw - s * (x * qx + y * qy + z * qz)
    q.x = c * qx + s * (x * qw + z * qy - y * qz)
    q.y = c * qy + s * (y * qw - z * qx + x * qz)
    q.z = c * qz + s * (z * qw + y * qx - x * qy)
  end

  -- Normalize (should be very close to 1 now)
  local norm2 = q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z
  local inv_norm = 1.0 / sqrt(norm2)
  q.w, q.x, q.y, q.z = q.w * inv_norm, q.x * inv_norm, q.y * inv_norm, q.z * inv_norm

  rot:set(q)
  rvel:set(angular_velocity)
end

function quaternionPredictor:get(timeStamp, dt, offset, multiplier, set)
  local bufferData = self.bufferData
  local currentBuffLen = self.bufferLen
  local bufferID = (self.currentBufferID)
  local lastBufferID = (self.currentBufferID)
  local count = 0
  local buffTime = (timeStamp - max(self.bufferReadOffset, offset))

  -- backtrack into the buffer
  if bufferID == 0 then bufferID = currentBuffLen end
  while true do
    count = count + 1
    if count > currentBuffLen then break end

    if bufferData[bufferID].time == 0 and lastBufferID ~= bufferID then
      bufferID = lastBufferID
      break
    end
    if buffTime >= bufferData[bufferID].time then
      break
    end

    lastBufferID = bufferID
    bufferID = bufferID - 1
    if bufferID == 0 then bufferID = currentBuffLen end
  end
  local lastPosData = bufferData[bufferID]
  local remoteVehData = lastPosData

  --interpolate
  local isCurrentIndex = bufferID == self.currentBufferID
  local isTeleport -- TODO implement this
  if not isCurrentIndex then
    local nextBufferID = bufferID + 1
    if nextBufferID > currentBuffLen then nextBufferID = 1 end
    local nextPosData = bufferData[nextBufferID]

    local nextTime, lastTime = nextPosData.time , lastPosData.time

    if not isTeleport and nextTime ~= 0 then
      remoteVehData = quat_integrate_exact(lastPosData, nextPosData, buffTime, self.interPolated)
      end
  end
  local predictTime = (timeStamp - remoteVehData.time) * remoteVehData.multiplier --* (1/(multiplier or 1))
  local smootherDT = dt / guardZero(abs(predictTime))

  --update smoothers
  local current = self.currentValues
  if isTeleport then
    self.rotVelSmoother:set(remoteVehData.rotVel)
    self.rotAccSmoother:set(remoteVehData.rotAcc)
  end

  current.rotVel:set(self.rotVelSmoother:get(remoteVehData.rotVel,smootherDT))
  current.rotAcc:set(self.rotAccSmoother:get(remoteVehData.rotAcc,smootherDT))

  tempQuat:set(remoteVehData.rot)
  predict_quaternion(self.rot, self.rotVel, tempQuat, current.rotVel, current.rotAcc, predictTime)

  if self.enableDebug and debugDrawer then
    debugDrawer:drawCylinder(pos, (pos + vec3(0,-5,0):rotated(self.rot)):toFloat3(),0.1, color(0,255,0,200))
    debugDrawer:drawCylinder(pos, (pos + vec3(0,-5,0):rotated(self.bufferData[self.currentBufferID].rot):toFloat3()),0.1, color(255,0,0,200))
  end

  return isTeleport and remoteVehData.rot or self.rot, isTeleport and remoteVehData.rotVel or self.rotVel, isTeleport, predictTime
end

function quaternionPredictor:reset()
  self.timer = 0

  self.bufferReadOffset = 0
  self.bufferOffsetSmoother:reset()
  self.currentBufferID = 1


  self.currentValues.rot:set(0, 0, 0, 0)
  self.currentValues.rotVel:set(0, 0, 0)
  self.currentValues.rotAcc:set(0, 0, 0)
  self.currentValues.time = 0
  self.currentValues.multiplier = 1

  self.interPolated.rot:set(0, 0, 0, 0)
  self.interPolated.rotVel:set(0, 0, 0)
  self.interPolated.rotAcc:set(0, 0, 0)
  self.interPolated.time = 0
  self.interPolated.multiplier = 1

  self.rot:set(0,0,0,0)
  self.rotVel:set(0,0,0)
  self.rotAcc:set(0,0,0)

  self.rotVelSmoother:reset()
  self.rotAccSmoother:reset()

  for i = 1, self.bufferLen do
    local data = self.bufferData[i]
    data.rot:set(0, 0, 0, 0)
    data.rotVel:set(0, 0, 0)
    data.rotAcc:set(0, 0, 0)
    data.time = 0
    data.multiplier = 1
    self.bufferData[i] = data
  end
end

M.newDirectionVectorPredictor = function(...)
  local o = {}
  setmetatable(o, vecDirPredictor)
  vecDirPredictor.__index = vecDirPredictor
  o:new(...)
  return o
end

M.newQuaternionPredictor = function(...)
  local o = {}
  setmetatable(o, quaternionPredictor)
  quaternionPredictor.__index = quaternionPredictor
  o:new(...)
  return o
end

return M
