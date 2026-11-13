local M = {}

local min = math.min

-- Smoothing for vectors, original temporalSmoothingNonLinear created by BeamNG, adapted to vectors by Stefan750
local vectorSmoothing = {}
vectorSmoothing.__index = vectorSmoothing

local function newVectorSmoothing(rate)
  local data = {rate = rate or 10, state = vec3(0,0,0), diff = vec3()}
  setmetatable(data, vectorSmoothing)
  return data
end

function vectorSmoothing:get(sample, dt)
  local state = self.state
  local diff = self.diff
  diff:setSub2(sample,state)
  diff:setScaled(min(self.rate * dt, 1))
  state:setAdd(diff)
  self.state:set(state)
  return state
end

function vectorSmoothing:getIndependent(sample, dtx,dty,dyz)
  local st = self.state
  local dif = self.diff
  dif:setSub2(sample,st)

  st.x = st.x + dif.x * min(self.rate * dtx, 1)
  st.y = st.y + dif.y * min(self.rate * dty, 1)
  st.z = st.z + dif.z * min(self.rate * dyz, 1)
  self.state:set(st)
  return st
end

function vectorSmoothing:set(...)
  self.state:set(...)
end

function vectorSmoothing:reset()
  self.state:set(0,0,0)
end

M.newVectorSmoothing = newVectorSmoothing

return M