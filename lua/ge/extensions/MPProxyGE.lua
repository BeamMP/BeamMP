-- Copyright (C) 2026 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- MPProxyGE API - Proxy vehicles for remote players.
-- Remote vehicles that are far away are not spawned as real BeamNG vehicles (which costs a multi second
-- stutter to spawn and a full physics simulation to keep). Instead they are kept as "proxies": the Vehicle
-- table in MPVehicleGE without a game object, moved by dead reckoning from the position packets and drawn
-- as an oriented, paint coloured box with the debug drawer (no scene objects are created).
-- Only the closest remote vehicles are swapped for real vehicles, rate limited and with hysteresis.
-- Optionally (proxyCollision) proxies close to the local vehicle get a pooled, simplified collision vehicle.
-- @module MPProxyGE

local M = {}

local colliderPool = require("beammp.proxy.colliders")

setmetatable(_G,{}) -- temporarily disable global notifications

-- ============= SETTINGS =============
local cfg = {
	enabled = true,
	spawnDist = 200,      -- proxy -> real when closer than this
	despawnDist = 260,    -- real -> proxy when further than this
	maxReal = 12,         -- max remote real vehicles (spawned + waiting in the spawn queue)
	spawnInterval = 3,    -- seconds between two real spawns (global)
	cooldown = 10,        -- seconds a vehicle is not swapped again after a swap
	drawDist = 3000,      -- proxies beyond this are not drawn
	collision = false,
	collisionRadius = 60,
	poolSize = 4,
	colliderModel = "simple_traffic",
	smoothHandover = true,
	replayState = true,
	hybrid = false,
	hybridMaxPlayers = 16,
	hybridWakeDist = 80,
	hybridMaxAwake = 6,
	maxPredict = 0.3,
	farShape = true,
	queueByDistance = true,
	engineSound = false,
	engineSoundDist = 60,
	engineSoundMax = 6,
	lodShape = 600, -- low poly car shape below, a box in the paint colour above (LOD tiers after the mesh ones)
}

local DESPAWN_INTERVAL = 0.5   -- seconds between two real -> proxy swaps (despawns are cheap, but not free)
local DECISION_INTERVAL = 0.25 -- seconds between two swap decision passes
local CAP_SWAP_MARGIN = 50     -- a real vehicle is only evicted for the cap if a proxy is this much closer
local MAX_ACC = 100            -- m/s^2, cap of the acceleration worked out from two packets
local MAX_RACC = 50            -- rad/s^2
local OFFSET_SMOOTHING = 2     -- 1/s, how fast the sender clock offset follows new packets
local SNAP_DISTANCE = 25       -- render position snaps instead of blending above this error
local POS_BLEND = 12           -- 1/s, how fast the rendered pose converges to the prediction

local function readSettings()
	cfg.enabled = settings.getValue("enableProxyVehicles", true) ~= false
	cfg.autoReal = settings.getValue("proxyAutoReal", false) == true -- opt in: distance based real spawns
	cfg.spawnDist = tonumber(settings.getValue("proxyRealSpawnDistance", 200)) or 200
	cfg.despawnDist = math.max(tonumber(settings.getValue("proxyRealDespawnDistance", 260)) or 260, cfg.spawnDist + 20)
	cfg.maxReal = math.max(0, math.floor(tonumber(settings.getValue("proxyMaxRealVehicles", 12)) or 12))
	cfg.spawnInterval = math.max(0, tonumber(settings.getValue("proxyMinSpawnInterval", 3)) or 3)
	cfg.cooldown = math.max(0, tonumber(settings.getValue("proxySwapCooldown", 10)) or 10)
	cfg.drawDist = tonumber(settings.getValue("proxyDrawDistance", 3000)) or 3000
	cfg.collision = settings.getValue("proxyCollision", false) == true
	cfg.collisionRadius = tonumber(settings.getValue("proxyCollisionRadius", 60)) or 60
	cfg.poolSize = math.max(0, math.floor(tonumber(settings.getValue("proxyColliderPoolSize", 4)) or 4))
	cfg.colliderModel = settings.getValue("proxyColliderModel", "simple_traffic") or "simple_traffic"
	cfg.smoothHandover = settings.getValue("proxySmoothHandover", true) ~= false
	cfg.replayState = settings.getValue("proxyReplayState", true) ~= false
	cfg.hybrid = settings.getValue("proxyHybridMode", false) == true
	cfg.hybridMaxPlayers = math.max(1, math.floor(tonumber(settings.getValue("proxyHybridMaxPlayers", 16)) or 16))
	cfg.hybridWakeDist = math.max(10, tonumber(settings.getValue("proxyHybridWakeDistance", 80)) or 80)
	cfg.hybridMaxAwake = math.max(0, math.floor(tonumber(settings.getValue("proxyHybridMaxAwake", 6)) or 6))
	cfg.farShape = settings.getValue("proxyFarShape", true) ~= false
	cfg.queueByDistance = settings.getValue("proxyQueueByDistance", true) ~= false
	cfg.lodShape = math.max(0, tonumber(settings.getValue("proxyLodShapeDistance", 600)) or 600)
	cfg.engineSound = settings.getValue("proxyEngineSound", false) == true
	cfg.autoShift = settings.getValue("proxyEngineAutoShift", true) ~= false
	cfg.engineSoundDist = math.max(5, tonumber(settings.getValue("proxyEngineSoundDistance", 60)) or 60)
	cfg.engineSoundMax = math.min(16, math.max(0, math.floor(tonumber(settings.getValue("proxyEngineSoundMax", 6)) or 6)))
	cfg.tireScreech = settings.getValue("proxyTireScreech", false) == true
	cfg.screechDist = math.max(5, tonumber(settings.getValue("proxyTireScreechDistance", 50)) or 50)
	cfg.smoke = settings.getValue("proxySmoke", false) == true
	cfg.smokeDist = math.max(5, tonumber(settings.getValue("proxySmokeDistance", 80)) or 80)
	cfg.tabCycle = settings.getValue("proxyTabCycle", true) ~= false
	cfg.maxPredict = math.min(math.max(tonumber(settings.getValue("proxyMaxPrediction", 0.3)) or 0.3, 0.05), 2)
end

-- ============= DIMENSIONS =============
-- {length, width, height} in meters. Rough values, replaced by a jbeam derived cache in a later phase.
local CLASS_DIMS = {
	car = {4.5, 1.85, 1.45},
	truck = {7.5, 2.5, 3.2},
	trailer = {8.0, 2.5, 3.0},
	prop = {1.5, 1.5, 1.5},
	unicycle = {0.6, 0.6, 1.8},
}
local MODEL_DIMS = {
	unicycle = CLASS_DIMS.unicycle,
	pickup = {5.4, 2.0, 1.9}, fullsize = {5.3, 2.0, 1.5}, etk800 = {4.9, 1.85, 1.45}, etki = {4.6, 1.75, 1.4},
	etkc = {4.6, 1.85, 1.35}, vivace = {4.3, 1.8, 1.45}, covet = {3.9, 1.7, 1.45}, sunburst2 = {4.4, 1.8, 1.45},
	bastion = {5.0, 1.95, 1.4}, legran = {4.8, 1.8, 1.4}, moonhawk = {5.2, 1.95, 1.35}, barstow = {5.1, 1.9, 1.35},
	burnside = {5.3, 2.0, 1.45}, bluebuck = {5.6, 2.0, 1.4}, miramar = {4.3, 1.6, 1.4}, pessima = {4.5, 1.7, 1.4},
	midsize = {4.6, 1.8, 1.4}, sbr = {4.4, 1.9, 1.25}, scintilla = {4.6, 2.05, 1.15}, bolide = {4.0, 1.9, 1.1},
	nine = {4.6, 1.85, 1.45}, wendover = {5.0, 1.9, 1.4}, bx = {4.5, 1.75, 1.3}, autobello = {3.2, 1.4, 1.3},
	lansdale = {5.0, 1.85, 1.7}, hopper = {4.0, 1.7, 1.8}, roamer = {4.9, 1.95, 1.9}, van = {5.0, 2.0, 2.1},
	wigeon = {3.0, 1.4, 1.5}, pigeon = {2.8, 1.3, 1.6}, atv = {2.1, 1.2, 1.2}, utv = {3.2, 1.6, 1.9},
	rockbouncer = {4.0, 2.2, 2.0}, md_series = {6.0, 2.2, 2.6}, midtruck = {6.5, 2.3, 2.8}, us_semi = {7.0, 2.6, 3.6},
	citybus = {12.0, 2.6, 3.2}, dumptruck = {8.5, 2.6, 3.5}, wl40 = {6.0, 2.5, 3.0}, racetruck = {5.5, 2.4, 2.8},
	caravan = {6.0, 2.3, 2.7}, cargotrailer = {5.0, 2.0, 2.2}, dryvan = {14.0, 2.6, 4.0}, flatbed = {14.0, 2.6, 1.6},
	tanker = {13.0, 2.6, 3.6}, simple_traffic = CLASS_DIMS.car,
}
local TYPE_TO_CLASS = { Car = "car", Truck = "truck", Trailer = "trailer", Prop = "prop", Automation = "car" }

-- hard limits for every proxy size (box, prism, mesh fallback), whatever the source
local MIN_DIM, MAX_LEN, MAX_WIDTH, MAX_HEIGHT = 0.3, 25, 6, 6
local function clampDim(v, maxV, default)
	v = tonumber(v)
	if not v or v ~= v then return default end
	return math.max(MIN_DIM, math.min(maxV, v))
end
local function setDims(p, L, W, H)
	p.L, p.W, p.H = clampDim(L, MAX_LEN, 4.5), clampDim(W, MAX_WIDTH, 1.9), clampDim(H, MAX_HEIGHT, 1.5)
end

local modelInfoCache = {} -- [jbeam] = { valid = bool, dims = {} }

local function getModelInfo(jbeam)
	if not jbeam then return { valid = false, dims = CLASS_DIMS.car } end
	local info = modelInfoCache[jbeam]
	if info then return info end
	-- core_vehicles.getModel is cached by the game after the first call per model, getModelList() is not
	-- (it rebuilds all filters) and must not be called per proxy
	local ok, model = pcall(core_vehicles.getModel, jbeam)
	local modelData = ok and type(model) == "table" and model.model or nil
	local dims = MODEL_DIMS[jbeam]
	if not dims then
		local class = modelData and TYPE_TO_CLASS[modelData.Type] or "car"
		dims = CLASS_DIMS[class] or CLASS_DIMS.car
	end
	info = { valid = modelData ~= nil, dims = dims, class = modelData and TYPE_TO_CLASS[modelData.Type] or "car" }
	modelInfoCache[jbeam] = info
	return info
end

local function paintToColor(vcf)
	local paint = vcf and vcf.paints and vcf.paints[1]
	local c = paint and paint.baseColor
	if type(c) ~= "table" or not c[1] then -- older configs: colors = {{r, g, b, a}, ...}
		local old = vcf and type(vcf.colors) == "table" and vcf.colors[1]
		c = type(old) == "table" and old or nil
	end
	if type(c) == "table" and tonumber(c[1]) then
		return { r = (tonumber(c[1]) or 0.5) * 255, g = (tonumber(c[2]) or 0.5) * 255, b = (tonumber(c[3]) or 0.5) * 255 }
	end
	return { r = 140, g = 140, b = 150 }
end

-- ============= STATE =============
local clock = 0
local decisionTimer = 0
local nextSpawnAllowed = 0
local nextDespawnAllowed = 0
local refPos = vec3()       -- distance reference (camera or local vehicle)
local localVehPos = vec3()
local hasLocalVeh = false

local hybridActive = false  -- proxyHybridMode in effect (set by updateHybrid)
local nextColliderSpawnAllowed = 0

-- garbage free temporaries
local tmpQ = quat()
local tmpV = vec3()
local tmpPosSave, tmpRotSave = vec3(), quat()
local axX, axY, axZ = vec3(), vec3(), vec3()
local unitX, unitY, unitZ = vec3(1,0,0), vec3(0,1,0), vec3(0,0,1)
local center = vec3()
local corners = {}
for i = 1, 8 do corners[i] = vec3() end

local ffiFound = ffi and ffi.C and true or false
local drawTriSolid = ffiFound and ffi.C.BNG_DBG_DRAW_TriSolid or nop
local drawSquarePrism = ffiFound and ffi.C.BNG_DBG_DRAW_SquarePrism or nop

--- Creates or refreshes the proxy data of a vehicle from its spawn/edit data.
-- @tparam table vehicle MPVehicleGE Vehicle
-- @tparam table spawnData decoded spawn packet (jbm, vcf, pos, rot)
local function initProxy(vehicle, spawnData)
	local p = vehicle.proxy
	if not p then
		p = {
			pos = vec3(), rot = quat(), vel = vec3(), rvel = vec3(), acc = vec3(), racc = vec3(), svel = vec3(),
			tim = nil, offset = nil,
			rpos = vec3(), rrot = quat(), t = clock, hasData = false, cooldownUntil = 0,
		}
		vehicle.proxy = p
		if spawnData and type(spawnData.pos) == "table" and spawnData.pos[1] then
			p.pos:set(spawnData.pos[1], spawnData.pos[2], spawnData.pos[3])
			p.rpos:set(p.pos)
			p.hasData = true
		end
		if spawnData and type(spawnData.rot) == "table" and spawnData.rot[4] then
			-- spawn packets carry veh:getRotation(), position packets carry quatFromDir(-dir, up), see applyVehSpawn
			p.rot:set(quat(0,0,1,0) * quat(spawnData.rot[1], spawnData.rot[2], spawnData.rot[3], spawnData.rot[4]))
			p.rrot:set(p.rot)
		end
	end
	local info = getModelInfo(spawnData and spawnData.jbm or vehicle.jbeam)
	setDims(p, info.dims[1], info.dims[2], info.dims[3])
	p.isPerson = (spawnData and spawnData.jbm or vehicle.jbeam) == "unicycle" -- walking player
	p.cogH = math.min(0.55, p.H * 0.4) -- position packets are at the center of gravity, not the ground
	local c = paintToColor(spawnData and spawnData.vcf)
	p.r, p.g, p.b = c.r, c.g, c.b
	p.vcfPaint = spawnData and spawnData.vcf and spawnData.vcf.paints and spawnData.vcf.paints[1] or nil
	p.validModel = info.valid
	p.dimsFromMesh = nil
	if spawnData and spawnData.vcf then
		p.vcf = spawnData.vcf
		if MPProxyMeshGE and not info.valid and not p.isPerson then
			log('W', 'MPProxyGE', "No proxy mesh for "..tostring(vehicle.serverVehicleString)..": model '"..tostring(spawnData.jbm or vehicle.jbeam).."' is not installed, drawing a box")
		end
		if MPProxyMeshGE and info.valid and not p.isPerson then
			local key = MPProxyMeshGE.request(spawnData.jbm or vehicle.jbeam, spawnData.vcf) -- async, box until ready
			if key ~= p.meshKey then MPProxyMeshGE.release(p) end
			p.meshKey = key
		end
	end
	return p
end

local ownPing = 0 -- seconds, our own round trip to the server (positionGE.setPing)
local tmpVel, tmpRvel = vec3(), vec3()

local function capLength(v, maxLen)
	local l = v:length()
	if l > maxLen then v:setScaled(maxLen / l) end
end

--- Called by positionGE for every decoded position packet of a vehicle without game object.
-- The pose is predicted like positionVE does for real remote vehicles: the sender's clock (tim) is mapped onto
-- ours with a smoothed offset (arrival time minus half of both pings), and the pose is moved on by velocity and
-- the acceleration worked out from the last two packets.
local function onPositionPacket(vehicle, decoded)
	if not decoded or type(decoded.pos) ~= "table" or type(decoded.rot) ~= "table" then return end
	local p = vehicle.proxy or initProxy(vehicle, nil)
	local tim = tonumber(decoded.tim)
	if tim and p.tim and tim < p.tim then
		if tim > p.tim - 1 then return end -- late packet, an older one than what we have
		p.tim, p.offset = nil, nil -- the sender's timer started over (vehicle reset)
		p.acc:set(0,0,0) p.racc:set(0,0,0)
	end
	if type(decoded.vel) == "table" then tmpVel:set(decoded.vel[1] or 0, decoded.vel[2] or 0, decoded.vel[3] or 0) else tmpVel:set(0,0,0) end
	if type(decoded.rvel) == "table" then tmpRvel:set(decoded.rvel[1] or 0, decoded.rvel[2] or 0, decoded.rvel[3] or 0) else tmpRvel:set(0,0,0) end
	if tim and p.tim and p.hasData then
		local remoteDt = math.max(tim - p.tim, 0.001)
		p.acc:set(tmpVel) p.acc:setSub(p.vel) p.acc:setScaled(1 / remoteDt) capLength(p.acc, MAX_ACC)
		p.racc:set(tmpRvel) p.racc:setSub(p.rvel) p.racc:setScaled(1 / remoteDt) capLength(p.racc, MAX_RACC)
	else
		p.acc:set(0,0,0) p.racc:set(0,0,0)
	end
	p.pos:set(decoded.pos[1], decoded.pos[2], decoded.pos[3])
	p.rot:set(decoded.rot[1], decoded.rot[2], decoded.rot[3], decoded.rot[4])
	p.vel:set(tmpVel)
	p.rvel:set(tmpRvel)
	if tim then
		local offset = clock - tim - ownPing * 0.5 - (tonumber(decoded.ping) or 0) * 0.5
		if not p.offset or math.abs(offset - p.offset) > 1 then p.offset = offset end
		p.rawOffset = offset
		p.tim = tim
	end
	p.t = clock
	if not p.hasData then
		p.rpos:set(p.pos)
		p.rrot:set(p.rot)
		p.hasData = true
	end
end

--- Seeds the proxy from a real vehicle that is about to be despawned, so it continues seamlessly.
local function seedFromVehicle(vehicle, veh)
	local p = vehicle.proxy or initProxy(vehicle, nil)
	local cx, cy, cz = be:getObjectOOBBCenterXYZ(veh:getID())
	p.pos:set(cx, cy, cz)
	tmpV:set(veh:getDirectionVectorXYZ())
	tmpV:setScaled(-1)
	axZ:set(veh:getDirectionVectorUpXYZ())
	p.rot:setFromDir(tmpV, axZ) -- same convention as the position packets (positionVE.getVehicleRotation)
	p.vel:set(veh:getVelocityXYZ())
	p.rvel:set(0,0,0)
	p.acc:set(0,0,0) p.racc:set(0,0,0)
	p.tim, p.offset = nil, nil
	p.t = clock
	p.rpos:set(p.pos)
	p.rrot:set(p.rot)
	p.hasData = true
end

--- Snaps a proxy to a pose (server side reset).
local function snapProxy(vehicle, pos, rot)
	local p = vehicle.proxy
	if not p or not pos then return end
	p.pos:set(pos.x or pos[1], pos.y or pos[2], pos.z or pos[3])
	if rot and (rot.w or rot[4]) then p.rot:set(rot.x or rot[1], rot.y or rot[2], rot.z or rot[3], rot.w or rot[4]) end
	p.vel:set(0,0,0)
	p.rvel:set(0,0,0)
	p.acc:set(0,0,0) p.racc:set(0,0,0)
	p.tim, p.offset = nil, nil
	p.t = clock
	p.rpos:set(p.pos)
	p.rrot:set(p.rot)
	p.hasData = true
end

-- in place normalized lerp of quaternions, garbage free
local function nlerpInto(out, a, b, t)
	local d = a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w
	local s = d < 0 and -t or t
	local t1 = 1 - t
	local x, y, z, w = a.x*t1 + b.x*s, a.y*t1 + b.y*s, a.z*t1 + b.z*s, a.w*t1 + b.w*s
	local len = math.sqrt(x*x + y*y + z*z + w*w)
	if len < 1e-9 then out:set(b.x, b.y, b.z, b.w) return end
	out:set(x/len, y/len, z/len, w/len)
end

--- Dead reckoning + smoothing for one proxy. Writes vehicle.position / vehicle.rotation.
local function predict(vehicle, p, dt)
	local maxPredict = cfg.maxPredict
	local age
	if p.tim and p.offset and p.rawOffset then
		-- follow the clock offset slowly, so jitter in packet arrival does not shake the proxy
		p.offset = p.offset + (p.rawOffset - p.offset) * math.min(1, dt * OFFSET_SMOOTHING)
		age = clock - (p.tim + p.offset)
	else
		age = clock - p.t
	end
	age = math.min(math.max(age, -maxPredict), maxPredict)
	local stale = clock - p.t > maxPredict -- no packets for a while: stand still where the prediction ended
	-- predicted position: pos + vel t + acc t^2 / 2
	tmpV:set(p.acc)
	tmpV:setScaled(0.5 * age)
	tmpV:setAdd(p.vel)
	tmpV:setScaled(age)
	tmpV:setAdd(p.pos)
	if stale then p.svel:set(0,0,0) else p.svel:set(p.acc) p.svel:setScaled(age) p.svel:setAdd(p.vel) end
	-- predicted rotation, same formula as positionVE (rot * quatFromEuler(rvel * t)); only the rotation velocity,
	-- a noisy rvel would shake the proxy through the worked out angular acceleration
	tmpQ:setFromEuler(p.rvel.x * age, p.rvel.y * age, p.rvel.z * age)
	tmpQ:setMul2(p.rot, tmpQ)

	if p.rpos:squaredDistance(tmpV) > SNAP_DISTANCE * SNAP_DISTANCE then
		p.rpos:set(tmpV)
		p.rrot:set(tmpQ)
	else
		local k = math.min(1, dt * POS_BLEND)
		p.rpos:setLerp(p.rpos, tmpV, k)
		nlerpInto(p.rrot, p.rrot, tmpQ, k)
	end
	vehicle.position:set(p.rpos)
	vehicle.rotation:set(p.rrot)
end

local function packColor(r, g, b, a)
	return color(r, g, b, a)
end

local function drawQuad(a, b, c, d, col)
	-- the debug drawer triangles are single sided, draw both windings so the winding order does not matter
	drawTriSolid(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, col, true)
	drawTriSolid(a.x, a.y, a.z, c.x, c.y, c.z, b.x, b.y, b.z, col, true)
	drawTriSolid(a.x, a.y, a.z, c.x, c.y, c.z, d.x, d.y, d.z, col, true)
	drawTriSolid(a.x, a.y, a.z, d.x, d.y, d.z, c.x, c.y, c.z, col, true)
end

local function shade(p, f, alpha)
	return packColor(p.r * f, p.g * f, p.b * f, alpha)
end

--- Draws an oriented box for the proxy. Only the up to 3 faces facing the camera are drawn.
local drawSphere = ffiFound and ffi.C.BNG_DBG_DRAW_Sphere or nop
local drawCylinder = ffiFound and ffi.C.BNG_DBG_DRAW_Cylinder or nop

-- ============= LOW POLY CAR SHAPE =============
-- Instead of a plain box, proxies without a mesh get a lofted outline of a vehicle: a few cross sections along
-- the length (front to back), each with a bottom, top and half width as fractions of the proxy size. Only the
-- faces looking at the camera are drawn. {t along the length from the front, bottom, top, width}
local LOFT_CAR = {
	{0.00, 0.20, 0.45, 0.88}, {0.10, 0.14, 0.58, 0.97}, {0.32, 0.14, 0.64, 1.00}, {0.46, 0.14, 0.98, 0.86},
	{0.76, 0.14, 0.96, 0.86}, {0.90, 0.14, 0.68, 0.98}, {1.00, 0.20, 0.58, 0.90},
}
local LOFT_TALL = { -- trucks, vans, buses: cab almost at the front, boxy body
	{0.00, 0.18, 0.55, 0.95}, {0.06, 0.14, 0.92, 1.00}, {0.14, 0.14, 1.00, 1.00}, {1.00, 0.14, 1.00, 1.00},
}
local loftL, loftR = {}, {} -- per section: bottom and top points, left and right
for i = 1, 8 do loftL[i] = { vec3(), vec3() } loftR[i] = { vec3(), vec3() } end
local loftN = vec3()

-- draws triangle a b c if its front side (counter clockwise) looks at the camera, shaded by its normal
local function loftTri(p, a, b, c, camPos, alpha)
	tmpV:set(b) tmpV:setSub(a)
	loftN:set(c) loftN:setSub(a)
	loftN:set(tmpV.y*loftN.z - tmpV.z*loftN.y, tmpV.z*loftN.x - tmpV.x*loftN.z, tmpV.x*loftN.y - tmpV.y*loftN.x)
	-- orient the normal away from the proxy center, skip faces turned away from the camera
	if loftN.x*(a.x - center.x) + loftN.y*(a.y - center.y) + loftN.z*(a.z - center.z) < 0 then loftN:setScaled(-1) end
	local dx, dy, dz = camPos.x - a.x, camPos.y - a.y, camPos.z - a.z
	local facing = loftN.x*dx + loftN.y*dy + loftN.z*dz
	if facing <= 0 then return end
	local len = loftN:length()
	if len < 1e-6 then return end
	local up = loftN.z / len -- -1 .. 1
	local f = 0.55 + 0.45 * math.max(up, 0) + 0.15 * math.min(up, 0)
	local col = shade(p, f, alpha)
	-- the debug drawer triangles are single sided and the winding of our list is not consistent: draw both
	drawTriSolid(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, col, true)
	drawTriSolid(a.x, a.y, a.z, c.x, c.y, c.z, b.x, b.y, b.z, col, true)
end

local function drawLoft(p, camPos)
	local profile = (p.H > 2.1 or p.L > 6.5) and LOFT_TALL or LOFT_CAR
	local hl, hw = p.L * 0.5, p.W * 0.5
	local bottomZ = -p.cogH -- packet position is the cog, the ground is cogH below
	local n = #profile
	for i = 1, n do
		local s = profile[i]
		local ly = -hl + s[1] * p.L -- -Y of the packet rotation is the driving direction
		local zb, zt, w = bottomZ + s[2] * p.H, bottomZ + s[3] * p.H, s[4] * hw
		local l, r = loftL[i], loftR[i]
		for k = 1, 2 do
			local z = k == 1 and zb or zt
			l[k]:set(p.rpos.x + axX.x*(-w) + axY.x*ly + axZ.x*z, p.rpos.y + axX.y*(-w) + axY.y*ly + axZ.y*z, p.rpos.z + axX.z*(-w) + axY.z*ly + axZ.z*z)
			r[k]:set(p.rpos.x + axX.x*w + axY.x*ly + axZ.x*z, p.rpos.y + axX.y*w + axY.y*ly + axZ.y*z, p.rpos.z + axX.z*w + axY.z*ly + axZ.z*z)
		end
	end
	for i = 1, n - 1 do
		local l1, r1, l2, r2 = loftL[i], loftR[i], loftL[i + 1], loftR[i + 1]
		loftTri(p, l1[2], r1[2], r2[2], camPos, 235) loftTri(p, l1[2], r2[2], l2[2], camPos, 235) -- top
		loftTri(p, l1[1], l1[2], l2[2], camPos, 235) loftTri(p, l1[1], l2[2], l2[1], camPos, 235) -- left side
		loftTri(p, r1[1], r2[2], r1[2], camPos, 235) loftTri(p, r1[1], r2[1], r2[2], camPos, 235) -- right side
	end
	local f, b = loftL[1], loftR[1]
	loftTri(p, f[1], b[2], f[2], camPos, 235) loftTri(p, f[1], b[1], b[2], camPos, 235) -- front cap
	f, b = loftL[n], loftR[n]
	loftTri(p, f[1], f[2], b[2], camPos, 235) loftTri(p, f[1], b[2], b[1], camPos, 235) -- rear cap
end

local function drawProxy(p, camPos, dist)
	if p.isPerson then -- walking player: body cylinder + head, about 1.8 m tall
		local x, y, z = p.rpos.x, p.rpos.y, p.rpos.z - p.cogH
		local col = shade(p, 1, 230)
		drawCylinder(x, y, z, x, y, z + 1.45, 0.22, col, true)
		drawSphere(x, y, z + 1.65, 0.15, col, true)
		return
	end
	axX:setRotate(p.rrot, unitX)
	axY:setRotate(p.rrot, unitY)
	axZ:setRotate(p.rrot, unitZ)
	local hl, hw, hh = p.L * 0.5, p.W * 0.5, p.H * 0.5
	-- box center: the packet position is the cog, which sits roughly cogH above the ground
	center:set(axZ)
	center:setScaled(hh - p.cogH)
	center:setAdd(p.rpos)

	-- small hysteresis so a proxy sitting on the boundary does not flicker between the two
	local farLimit = cfg.lodShape * (p.farBox and 0.95 or 1.05)
	p.farBox = dist > farLimit
	if p.farBox then
		-- far: one prism along the length axis, cheap
		tmpV:set(axY)
		tmpV:setScaled(hl)
		local x1, y1, z1 = center.x - tmpV.x, center.y - tmpV.y, center.z - tmpV.z
		local x2, y2, z2 = center.x + tmpV.x, center.y + tmpV.y, center.z + tmpV.z
		drawSquarePrism(x1, y1, z1, x2, y2, z2, p.W, p.H, p.W, p.H, shade(p, 1, 230), true)
		return
	end

	if cfg.farShape then drawLoft(p, camPos) return end

	-- corners: index bits (x, y, z) -> sign
	for i = 1, 8 do
		local sx = (i - 1) % 2 == 0 and -hw or hw
		local sy = math.floor((i - 1) / 2) % 2 == 0 and -hl or hl
		local sz = math.floor((i - 1) / 4) == 0 and -hh or hh
		local c = corners[i]
		c:set(center.x + axX.x*sx + axY.x*sy + axZ.x*sz, center.y + axX.y*sx + axY.y*sy + axZ.y*sz, center.z + axX.z*sx + axY.z*sy + axZ.z*sz)
	end
	tmpV:set(camPos)
	tmpV:setSub(center)
	local dx, dy, dz = tmpV:dot(axX), tmpV:dot(axY), tmpV:dot(axZ)
	local c = corners
	-- top / bottom (z)
	if dz > hh then drawQuad(c[5], c[6], c[8], c[7], shade(p, 1.0, 235))
	elseif dz < -hh then drawQuad(c[1], c[2], c[4], c[3], shade(p, 0.4, 235)) end
	-- sides (x)
	if dx > hw then drawQuad(c[2], c[4], c[8], c[6], shade(p, 0.75, 235))
	elseif dx < -hw then drawQuad(c[1], c[3], c[7], c[5], shade(p, 0.75, 235)) end
	-- front / back (y)
	if dy > hl then drawQuad(c[3], c[4], c[8], c[7], shade(p, 0.6, 235))
	elseif dy < -hl then drawQuad(c[1], c[2], c[6], c[5], shade(p, 0.6, 235)) end
end

-- ============= COLLIDER POOL (proxyCollision) =============
-- see beammp/proxy/colliders.lua: invisible size class collision vehicles for the closest proxies
local colliderCtx = { enabled = false, radius = 60, poolSize = 4, canSpawn = false, localVehPos = nil, model = nil }
local function updateColliders(vehicles)
	colliderCtx.enabled = cfg.enabled and cfg.collision
	colliderCtx.radius, colliderCtx.poolSize, colliderCtx.model = cfg.collisionRadius, cfg.poolSize, cfg.colliderModel
	colliderCtx.localVehPos = hasLocalVeh and localVehPos or nil
	colliderCtx.canSpawn = clock >= nextColliderSpawnAllowed and clock >= nextSpawnAllowed
	if colliderPool.update(vehicles, colliderCtx) then
		nextColliderSpawnAllowed = clock + math.max(cfg.spawnInterval, 1)
		nextSpawnAllowed = clock + cfg.spawnInterval
	end
end

-- ============= PROXY -> REAL HANDOVER =============
-- A freshly spawned real vehicle appears where the proxy was when the spawn was requested, which can be seconds
-- ago. So the proxy keeps being drawn (and predicted) while the real vehicle spawns hidden. Once its VE side is
-- ready it is moved onto the predicted pose (keeping its state, no reset), gets the proxy's velocity, and stays
-- hidden until a fresh position packet came in, then the proxy goes away.
local HANDOVER_SPAWN_TIMEOUT = 30 -- seconds from the spawn request until we give up and just show the vehicle
local HANDOVER_SYNC_TIMEOUT = 1.5 -- seconds after ready without a fresh packet
local HANDOVER_MIN_HIDDEN = 0.1   -- seconds the placed vehicle stays hidden at least (positionVE settles)

local handoverFwd, handoverUp, handoverCog = vec3(), vec3(), vec3()

local function startHandover(vehicle)
	if not cfg.smoothHandover or not vehicle.proxy or not vehicle.proxy.hasData then return end
	vehicle.proxyHandover = { state = "spawning", started = clock }
end

local function finishHandover(vehicle, reason)
	local h = vehicle.proxyHandover
	if not h then return end
	vehicle.proxyHandover = nil
	local veh = vehicle.gameVehicleID and vehicle.gameVehicleID > 0 and getObjectByID(vehicle.gameVehicleID) or nil
	if veh then veh:setMeshAlpha(1, "", false) end
	if vehicle.proxy and MPProxyMeshGE then MPProxyMeshGE.release(vehicle.proxy) end
	log('D', 'MPProxyGE', string.format("Handover of %s done (%s, %.2f s)", tostring(vehicle.serverVehicleString), reason, clock - h.started))
end

--- Moves a just spawned real vehicle onto its proxy's predicted pose, without resetting it.
local function placeOnProxy(veh, p)
	handoverFwd:set(veh:getDirectionVectorXYZ())
	handoverFwd:setScaled(-1)
	handoverUp:set(veh:getDirectionVectorUpXYZ())
	local vehRot = quatFromDir(handoverFwd, handoverUp) -- position packet convention (see seedFromVehicle)
	local diffRot = vehRot:inversed() * p.rrot
	local refPos = vec3(veh:getPositionXYZ())
	handoverCog:set(be:getObjectOOBBCenterXYZ(veh:getID()))
	-- ref node offset from the box center, carried over into the target orientation
	local offset = p.rrot * (vehRot:inversed() * (refPos - handoverCog))
	local target = p.rpos + offset
	local refNode = veh:getRefNodeId()
	veh:setClusterPosRelRot(refNode, target.x, target.y, target.z, diffRot.x, diffRot.y, diffRot.z, diffRot.w)
	veh:applyClusterVelocityScaleAdd(refNode, 0, p.svel.x, p.svel.y, p.svel.z) -- scale 0: replace the velocity
	local turned = math.deg(2 * math.acos(math.min(1, math.abs(diffRot.w))))
	return refPos:distance(target), turned
end

local flushReplayLater -- set in the STATE REPLAY section below (defined after this one)

--- Called by MPVehicleGE.onVehicleReady for every remote vehicle.
local function onRealVehicleReady(vehicle, veh)
	local h = vehicle and vehicle.proxyHandover
	if not h or h.state ~= "spawning" or not veh then
		if vehicle and veh and flushReplayLater then flushReplayLater(vehicle) end
		return
	end
	local p = vehicle.proxy
	if p and p.hasData then
		local ok, moved, turned = pcall(placeOnProxy, veh, p)
		if ok then
			log('D', 'MPProxyGE', string.format("Handover of %s: moved %.1f m, turned %.0f deg onto the proxy pose", tostring(vehicle.serverVehicleString), moved, turned))
		else
			log('W', 'MPProxyGE', "Placing the real vehicle onto its proxy failed: "..tostring(moved))
		end
	end
	veh:queueLuaCommand("if positionVE then positionVE.onReset() end") -- drop stale smoothing state
	veh:setMeshAlpha(0, "", false)
	h.state = "syncing"
	h.readyAt = clock
	h.packets = vehicle.proxyPktCount or 0
	if flushReplayLater then flushReplayLater(vehicle) end -- after the placement, so damage lands on the placed car
end

local function updateHandovers(vehicles)
	for _, v in pairs(vehicles) do
		local h = v.proxyHandover
		if h then
			local veh = v.isSpawned and v.gameVehicleID and v.gameVehicleID > 0 and getObjectByID(v.gameVehicleID) or nil
			if not v.isSpawned and not v.spawnQueue and not v.isProxy then
				v.proxyHandover = nil
			elseif h.state == "spawning" then
				if veh then veh:setMeshAlpha(0, "", false) end -- hidden until ready
				if clock - h.started > HANDOVER_SPAWN_TIMEOUT then finishHandover(v, "spawn timeout") end
			elseif h.state == "syncing" then
				if not veh then finishHandover(v, "vehicle gone")
				else
					local age = clock - h.readyAt
					if (v.proxyPktCount or 0) > h.packets and age >= HANDOVER_MIN_HIDDEN then finishHandover(v, "synced")
					elseif age > HANDOVER_SYNC_TIMEOUT then finishHandover(v, "no fresh packet")
					else veh:setMeshAlpha(0, "", false) end
				end
			end
		end
	end
end

local function isInHandover(vehicle)
	return vehicle ~= nil and vehicle.proxyHandover ~= nil
end

-- ============= STATE REPLAY =============
-- Inputs, electrics, powertrain and damage packets go to the vehicle's VE side, which a proxy does not have (and a
-- spawning vehicle does not have yet). They are kept per vehicle, merged where packets only carry changes, and
-- replayed through the regular handlers once the real vehicle is ready, so lights, gear, engine state and broken
-- parts are right from the start instead of after the next change.
local REPLAY_MERGED = { electrics = { e = true }, powertrain = { l = true, e = true } }
local REPLAY_ORDER = { { "nodes", "n" }, { "nodes", "g" }, { "powertrain", "e" }, { "powertrain", "l" }, { "powertrain", "h" },
	{ "electrics", "e" }, { "inputs", "i" } }
local REPLAY_HANDLERS = { nodes = "nodesGE", powertrain = "MPPowertrainGE", electrics = "MPElectricsGE", inputs = "MPInputsGE" }

local function deepMerge(into, from)
	for k, v in pairs(from) do
		if type(v) == "table" and type(into[k]) == "table" then deepMerge(into[k], v) else into[k] = v end
	end
end

-- true while packets for this vehicle would be lost: no game object, or it is still spawning, or paused
local function isHeld(vehicle)
	if not vehicle or vehicle.isLocal then return false end
	if vehicle.hybridPaused then return true end
	if vehicle.proxyHandover and vehicle.proxyHandover.state == "spawning" then return true end
	return vehicle.isProxy == true and not vehicle.isSpawned
end

--- Called by the packet handlers before they apply a packet. Returns true if the packet was kept for later.
-- @tparam string kind "inputs", "electrics", "powertrain" or "nodes"
local function captureState(kind, vehicle, code, data)
	if kind == "inputs" and vehicle and vehicle.proxy and type(data) == "string" and isHeld(vehicle) then
		local p = vehicle.proxy
		p.steer = tonumber(string.match(data, '"s"%s*:%s*([^,}%s]+)')) or p.steer -- drawn wheels
		p.sndThrottle = tonumber(string.match(data, '"t"%s*:%s*([^,}%s]+)')) or p.sndThrottle -- engine sound
		p.sndGear = string.match(data, '"g"%s*:%s*"?([^,}"]+)') or p.sndGear
		p.sndInputT = clock
	elseif kind == "powertrain" and code == "e" and vehicle and vehicle.proxy and type(data) == "string" and isHeld(vehicle) then
		-- engine data: ignLvl (0 off .. 3 starting) and per engine ign / isStalled, only sent on change
		local d = jsonDecode(data)
		if type(d) == "table" then
			local p = vehicle.proxy
			if d.ignLvl ~= nil then p.sndIgnLvl = tonumber(d.ignLvl) end
			if type(d.ICE) == "table" then
				for _, e in pairs(d.ICE) do
					if type(e) == "table" then
						if e.isStalled ~= nil then p.sndStalled = e.isStalled == true end
						if e.ign ~= nil then p.sndIgn = tonumber(e.ign) end
					end
				end
			end
		end
	end
	if not cfg.replayState or not isHeld(vehicle) or type(data) ~= "string" then return false end
	if kind == "nodes" and code ~= "n" and code ~= "g" then return false end
	local store = vehicle.proxyReplay or {}
	vehicle.proxyReplay = store
	local key = kind .. ":" .. tostring(code)
	if kind == "nodes" and code == "g" then
		local groups = jsonDecode(data)
		if type(groups) == "table" then
			local set = store[key] or {}
			for _, name in pairs(groups) do set[tostring(name)] = true end
			store[key] = set
		end
	elseif REPLAY_MERGED[kind] and REPLAY_MERGED[kind][code] then
		local decoded = jsonDecode(data)
		if type(decoded) == "table" then
			local merged = store[key] or {}
			deepMerge(merged, decoded)
			store[key] = merged
		end
	else
		store[key] = data -- only the latest one matters
	end
	return true
end

--- The owner reset the vehicle: kept damage no longer applies.
local function onVehicleResetWhileHeld(vehicle)
	local store = vehicle and vehicle.proxyReplay
	if store then store["nodes:n"], store["nodes:g"] = nil, nil end
end

--- Sends what was kept to the now ready vehicle, through the regular handlers.
local function flushReplay(vehicle)
	local store = vehicle and vehicle.proxyReplay
	if not store then return end
	vehicle.proxyReplay = nil
	local sid = vehicle.serverVehicleString
	local sent = 0
	for _, item in ipairs(REPLAY_ORDER) do
		local kind, code = item[1], item[2]
		local value = store[kind .. ":" .. code]
		local handler = _G[REPLAY_HANDLERS[kind]]
		if value ~= nil and handler and handler.handle then
			local data
			if kind == "nodes" and code == "g" then
				local list = {}
				for name in pairs(value) do list[#list + 1] = name end
				data = jsonEncode(list)
			elseif type(value) == "table" then
				data = jsonEncode(value)
			else
				data = value
			end
			local ok, err = pcall(handler.handle, code .. ":" .. sid .. ":" .. data)
			if ok then sent = sent + 1 else log('W', 'MPProxyGE', "Replaying "..kind.." "..code.." for "..sid.." failed: "..tostring(err)) end
		end
	end
	if sent > 0 then log('D', 'MPProxyGE', string.format("Replayed %d kept state packets to %s", sent, sid)) end
end
flushReplayLater = flushReplay

-- ============= HYBRID MODE (proxyHybridMode) =============
-- On servers with few players, remote vehicles are spawned for real (rate limited) but the ones that are not
-- near get paused with setActive(0) and drawn as their proxy, following the position packets. The game object
-- stays, so be:getObjectByID keeps working for mods (CaRP and others) and switching to a vehicle is instant.
-- A paused vehicle wakes when it comes near (nearest first, up to proxyHybridMaxAwake) or when a simulated
-- vehicle of ours runs into its box, and goes back to sleep after the contact settled.
-- Packets for its VE side are kept while paused (STATE REPLAY) and replayed on wake. Commands other mods queue
-- to a paused vehicle are dropped by the game, there is no way to buffer those from here.
local HYBRID_CONTACT_RANGE = 40   -- m, paused vehicles closer than this to one of ours are contact checked per frame
local HYBRID_WAKE_MARGIN = 0.25   -- m, the box is grown by this, so it wakes just before touching
local HYBRID_MIN_WAKE_SPEED = 0.2 -- m/s relative speed for a contact to count
local HYBRID_SETTLE_TIME = 1.0    -- s without contact before a contact-woken vehicle may sleep again
local HYBRID_MAX_HOLD = 20        -- s a contact keeps a vehicle awake at most
local HYBRID_DIST_MARGIN = 20     -- m of hysteresis on the wake distance

local hybC, hybX, hybY, hybZ = vec3(), vec3(), vec3(), vec3()
local othC, othX, othY, othZ, othVel = vec3(), vec3(), vec3(), vec3(), vec3()
local ownIDs = {}

local function countPlayers()
	local n = 0
	for _ in pairs(MPVehicleGE.getPlayers and MPVehicleGE.getPlayers() or {}) do n = n + 1 end
	return n
end

local function hybridPause(v, veh)
	seedFromVehicle(v, veh)
	v.hybridPaused = true
	v.hybridHoldUntil = nil
	veh:setActive(0)
	log('D', 'MPProxyGE', "Hybrid: paused "..tostring(v.serverVehicleString))
end

local function hybridWake(v, reason)
	if not v.hybridPaused then return end
	local veh = v.gameVehicleID and v.gameVehicleID > 0 and getObjectByID(v.gameVehicleID) or nil
	v.hybridPaused = nil
	if not veh then return end
	veh:setActive(1)
	local p = v.proxy
	if p and p.hasData then pcall(placeOnProxy, veh, p) end
	veh:queueLuaCommand("if positionVE then positionVE.onReset() end")
	veh:setMeshAlpha(0, "", false)
	-- shown once a fresh packet came in, the proxy is drawn until then (handover machinery)
	v.proxyHandover = { state = "syncing", started = clock, readyAt = clock, packets = v.proxyPktCount or 0 }
	flushReplay(v)
	log('D', 'MPProxyGE', "Hybrid: woke "..tostring(v.serverVehicleString).." ("..tostring(reason)..")")
end

-- per frame: paused vehicles near one of ours, woken when one of our simulated vehicles runs into their box
local function hybridContacts(vehicles)
	if not hybridActive then return end
	table.clear(ownIDs)
	for id in pairs(MPVehicleGE.getOwnMap and MPVehicleGE.getOwnMap() or {}) do ownIDs[#ownIDs + 1] = tonumber(id) or id end
	if #ownIDs == 0 then return end
	local range2 = HYBRID_CONTACT_RANGE * HYBRID_CONTACT_RANGE
	for _, v in pairs(vehicles) do
		local p = v.proxy
		if v.hybridPaused and p and p.hasData then
			for _, id in ipairs(ownIDs) do
				local own = getObjectByID(id)
				if own and be:getObjectActive(id) then
					othC:set(be:getObjectOOBBCenterXYZ(id))
					if othC:squaredDistance(p.rpos) < range2 then
						axX:setRotate(p.rrot, unitX) axY:setRotate(p.rrot, unitY) axZ:setRotate(p.rrot, unitZ)
						hybC:set(axZ) hybC:setScaled(p.H * 0.5 - p.cogH) hybC:setAdd(p.rpos)
						hybX:set(axX) hybX:setScaled(p.W * 0.5 + HYBRID_WAKE_MARGIN)
						hybY:set(axY) hybY:setScaled(p.L * 0.5 + HYBRID_WAKE_MARGIN)
						hybZ:set(axZ) hybZ:setScaled(p.H * 0.5 + HYBRID_WAKE_MARGIN)
						othX:set(be:getObjectOOBBHalfAxisXYZ(id, 0))
						othY:set(be:getObjectOOBBHalfAxisXYZ(id, 1))
						othZ:set(be:getObjectOOBBHalfAxisXYZ(id, 2))
						othVel:set(own:getVelocityXYZ())
						othVel:setSub(p.svel)
						if othVel:length() > HYBRID_MIN_WAKE_SPEED and overlapsOBB_OBB(hybC, hybX, hybY, hybZ, othC, othX, othY, othZ) then
							hybridWake(v, "contact")
							v.hybridContactAt = clock
							v.hybridHoldUntil = clock + HYBRID_MAX_HOLD
							break
						end
					end
				end
			end
		end
	end
end

-- true while one of our vehicles is still touching (and moving against) this awake vehicle
local function hybridStillInContact(v, veh)
	local gid = v.gameVehicleID
	othC:set(be:getObjectOOBBCenterXYZ(gid))
	hybX:set(be:getObjectOOBBHalfAxisXYZ(gid, 0)) hybY:set(be:getObjectOOBBHalfAxisXYZ(gid, 1)) hybZ:set(be:getObjectOOBBHalfAxisXYZ(gid, 2))
	for _, id in ipairs(ownIDs) do
		if be:getObjectActive(id) then
			hybC:set(be:getObjectOOBBCenterXYZ(id))
			othX:set(be:getObjectOOBBHalfAxisXYZ(id, 0)) othY:set(be:getObjectOOBBHalfAxisXYZ(id, 1)) othZ:set(be:getObjectOOBBHalfAxisXYZ(id, 2))
			local own = getObjectByID(id)
			othVel:set(own:getVelocityXYZ())
			tmpV:set(veh:getVelocityXYZ())
			othVel:setSub(tmpV)
			if othVel:length() > 1 and overlapsOBB_OBB(othC, hybX, hybY, hybZ, hybC, othX, othY, othZ) then return true end
		end
	end
	return false
end

-- decision pass: which real remote vehicles are awake, at most one pause and one wake per pass
local hybridList = {}
local function updateHybrid(vehicles, activeVehID)
	local wasActive = hybridActive
	hybridActive = cfg.enabled and cfg.hybrid and countPlayers() <= cfg.hybridMaxPlayers
	if wasActive ~= hybridActive then log('I', 'MPProxyGE', "Hybrid mode "..(hybridActive and "on" or "off")) end
	table.clear(hybridList)
	for _, v in pairs(vehicles) do
		if not v.isLocal and v.isSpawned and v.gameVehicleID and v.gameVehicleID > 0 and not v.proxyHandover then
			hybridList[#hybridList + 1] = v
			v.hybridDist = refPos:distance(v.hybridPaused and v.proxy and v.proxy.rpos or v.position)
		end
	end
	if not hybridActive then -- wake whatever is still paused, one per pass
		for _, v in ipairs(hybridList) do if v.hybridPaused then hybridWake(v, "hybrid mode off") return end end
		return
	end
	table.sort(hybridList, function(a, b) return a.hybridDist < b.hybridDist end)
	local woke, paused, rank = false, false, 0
	for _, v in ipairs(hybridList) do
		local veh = getObjectByID(v.gameVehicleID)
		if veh then
			local inContact = v.hybridHoldUntil and clock < v.hybridHoldUntil
			if inContact and not v.hybridPaused then
				if hybridStillInContact(v, veh) then v.hybridContactAt = clock
				elseif clock - (v.hybridContactAt or 0) > HYBRID_SETTLE_TIME then inContact = false v.hybridHoldUntil = nil end
			end
			local near = v.hybridDist < cfg.hybridWakeDist + (v.hybridPaused and 0 or HYBRID_DIST_MARGIN)
			if near then rank = rank + 1 end
			local wantAwake = v.gameVehicleID == activeVehID or inContact or v.proxyForceReal
				or (near and rank <= cfg.hybridMaxAwake)
			if wantAwake and v.hybridPaused and not woke then
				hybridWake(v, v.gameVehicleID == activeVehID and "camera" or "near")
				woke = true
			elseif not wantAwake and not v.hybridPaused and not paused and v.proxy then
				hybridPause(v, veh)
				paused = true
			end
		end
	end
end

local function isHybridPaused(vehicle)
	return vehicle ~= nil and vehicle.hybridPaused == true
end

-- ============= DISTANCE AWARE SPAWN QUEUE =============
-- A real spawn waiting in BeamMP's spawn queue (enableSpawnQueue) for a vehicle that drove out of range is
-- dropped again, the vehicle stays a proxy (its latest config stays in players_vehicle_configs, so the proxy mesh
-- follows edits). When it comes back into range the spawn is queued again from that latest config, or spawned
-- right away if the player does not use the queue (MPVehicleGE.promoteToReal decides that).
local QUEUE_DROP_MARGIN = 60 -- m beyond the spawn range before a queued spawn is dropped

local function queueRanges()
	local spawnRange = cfg.spawnDist
	if hybridActive then spawnRange = math.max(spawnRange, cfg.hybridWakeDist) end
	return spawnRange, math.max(cfg.despawnDist, spawnRange + QUEUE_DROP_MARGIN)
end

local function updateQueuedSpawns(vehicles)
	if not cfg.enabled or not cfg.queueByDistance then return end
	local spawnRange, dropRange = queueRanges()
	for sid, v in pairs(vehicles) do
		if not v.isLocal and v.isProxy and not v.isSpawned and v.proxy and v.proxy.hasData then
			local d = refPos:distance(v.proxy.rpos)
			if v.spawnQueue and not v.proxyForceReal and d > dropRange then
				if MPVehicleGE.demoteToProxy(sid) then -- drops the queued event and updates the queue counter
					v.proxyQueueDropped = true
					v.proxyHandover = nil
					if MPProxyMeshGE then MPProxyMeshGE.release(v.proxy) end -- re-attached by the mesh LOD pass
					log('I', 'MPProxyGE', string.format("Dropped queued spawn of %s, it is %.0f m away", sid, d))
				end
			elseif v.proxyQueueDropped and not v.spawnQueue and d < spawnRange and MPVehicleGE.hasSpawnData(sid) then
				local queued = settings.getValue("enableSpawnQueue")
				if queued or clock >= nextSpawnAllowed then -- direct spawns stutter: same rate limit as the others
					if not queued then nextSpawnAllowed = clock + cfg.spawnInterval end
					v.proxyQueueDropped = nil
					startHandover(v)
					if MPVehicleGE.promoteToReal(sid) then
						log('I', 'MPProxyGE', string.format("%s is back in range (%.0f m), spawn %s again", sid, d, queued and "queued" or "started"))
					else
						finishHandover(v, "spawn not started")
					end
				end
			end
		end
	end
end


-- ============= ENGINE SOUND (proxyEngineSound) =============
-- Proxies have no vehicle object, so the game's own engine sound (bound to vehicle nodes) cannot run for them.
-- A few looping FMOD sources (Engine.Audio.createSource) are placed on the nearest running proxies instead and
-- driven with the RPM / Load parameters of the engine events. RPM is not in the synced data, it is estimated from
-- the synced throttle and gear (inputs packet) and the proxy speed.
local ENGINE_BY_CLASS = { car = "I4_2", truck = "V8", bus = "I6D_bus", semi = "I6D_semi" }
local ENGINE_BY_MODEL = { citybus = "bus", us_semi = "semi" }
local DIESEL = { bus = true, semi = true }
local FALLBACK_EVENT = "event:>Engine>Bands>Synth>i4_01_eng"
local SOUND_FADE = 2           -- volume per second
local SOUND_INPUT_STALE = 5    -- s without inputs packets: throttle is no longer trusted
local soundEvents = {}         -- [sample name] = event name
local soundPool = {}           -- { id, event, owner (vehicle), vol, rpm, playing }
local soundMat = nil

local function typeSoundFor(jbeam)
	local class = ENGINE_BY_MODEL[jbeam] or getModelInfo(jbeam).class
	local sample = ENGINE_BY_CLASS[class]
	if not sample then return nil end
	local ev = soundEvents[sample]
	if ev == nil then
		local base = "art/sound/blends/" .. sample .. "_engine.sfxBlend"
		local data = jsonReadFile(base .. "2D.json") or jsonReadFile(base .. "2d.json")
		ev = type(data) == "table" and type(data.eventName) == "string" and data.eventName or FALLBACK_EVENT
		soundEvents[sample] = ev
	end
	return ev, DIESEL[class]
end

--- false when the synced engine state says the engine is off or stalled, true when unknown
local function proxyEngineRunning(p)
	if p.sndIgnLvl and p.sndIgnLvl < 2 then return false end
	if p.sndStalled or (p.sndIgn and p.sndIgn <= 0) then return false end
	return true
end

-- the config's own jbeam engine sound (MPProxyMeshGE reads it with the part index), else the type mapping
local function soundFor(v)
	local snd = MPProxyMeshGE and MPProxyMeshGE.getSound and v.proxy and MPProxyMeshGE.getSound(v.proxy.meshKey)
	if snd and snd.event then return snd.event, snd.diesel, snd end
	local ev, diesel = typeSoundFor(v.jbeam)
	return ev, (snd and snd.diesel) or diesel, snd
end

local SHIFT_TIME = 0.5 -- s, fake automatic gearbox (proxyEngineAutoShift)
local RAD_TO_RPM = 60 / (2 * math.pi)
-- engine rpm in a gear: from the config's gear ratios, final drive and wheel radius when the mesh builder found them
-- (snd.gear, see MPProxyMeshGE addGearing), otherwise a generic m/s per gear. No closure: runs every frame per sound.
local function rpmIn(gear, speed, idle, redline, perGear, gr, reverse)
	if gr then
		local ratio = reverse and gr.r or gr.f[math.min(math.max(gear, 1), #gr.f)]
		return math.max(idle, speed / gr.rad * ratio * gr.fd * RAD_TO_RPM)
	end
	return idle + speed / (perGear * math.max(gear, 1)) * (redline - idle)
end

local function estimateRpm(p, diesel, speed, snd)
	local idle, redline = diesel and 650 or 850, diesel and 2400 or 6200
	if snd and snd.idleRPM and snd.maxRPM and snd.maxRPM > snd.idleRPM + 500 then idle, redline = snd.idleRPM, snd.maxRPM end
	local fresh = p.sndInputT and clock - p.sndInputT < SOUND_INPUT_STALE
	local thr = fresh and math.min(math.max(p.sndThrottle or 0, 0), 1) or (speed > 1 and 0.3 or 0)
	local g = p.sndGear and tostring(p.sndGear) or nil
	if g == "N" or g == "P" or (speed < 0.5 and not fresh) then
		return idle + thr * (redline - idle) * 0.7, thr
	end
	local n = tonumber(g and string.match(g, "%d+"))
	local perGear = diesel and 4 or 9 -- m/s per gear at redline in first, grows with the gear (no gearing data)
	local gr = snd and snd.gear or nil
	local reverse = g == "R"
	if reverse then n = 1 end
	local maxGear = gr and #gr.f or 8
	if not n and cfg.autoShift then
		-- automatic (D): a remembered gear that shifts up past a throttle dependent rpm, down below a lower one
		-- (hysteresis), kicks down on full throttle, and blends the rpm over SHIFT_TIME while shifting
		local cur = p.sndAutoGear or 1
		local up = idle + (redline - idle) * (0.55 + 0.4 * thr)
		local down = idle + (redline - idle) * (0.18 + 0.35 * thr)
		local want = cur
		if clock >= (p.sndShiftEnd or 0) then
			if want < maxGear and rpmIn(want, speed, idle, redline, perGear, gr) > up then want = want + 1
			elseif want > 1 and rpmIn(want, speed, idle, redline, perGear, gr) < down then want = want - 1
			elseif thr > 0.85 and want > 1 and rpmIn(want - 1, speed, idle, redline, perGear, gr) < redline * 0.92 and rpmIn(want, speed, idle, redline, perGear, gr) < idle + (redline - idle) * 0.6 then
				want = want - 1 -- kickdown
			end
		end
		if want ~= cur then
			p.sndShiftFrom, p.sndShiftStart, p.sndShiftEnd = rpmIn(cur, speed, idle, redline, perGear, gr), clock, clock + SHIFT_TIME
			p.sndAutoGear = want
		end
		local rpm = rpmIn(p.sndAutoGear or 1, speed, idle, redline, perGear, gr)
		if p.sndShiftEnd and clock < p.sndShiftEnd then
			local f = (clock - p.sndShiftStart) / SHIFT_TIME
			rpm = p.sndShiftFrom + (rpm - p.sndShiftFrom) * f
			thr = thr * 0.3 -- the engine is off load while the gearbox shifts
		end
		return math.min(math.max(rpm, idle), redline), thr
	end
	if not n then -- automatic: shift up once past a throttle dependent point
		local shiftAt = redline * (0.45 + 0.4 * thr)
		n = 1
		while n < maxGear and rpmIn(n, speed, idle, redline, perGear, gr) > shiftAt do n = n + 1 end
	end
	p.sndAutoGear = math.max(n, 1)
	local rpm = rpmIn(n, speed, idle, redline, perGear, gr, reverse)
	return math.min(math.max(rpm, idle), redline), thr
end

local soundCounter = 0
local function soundSource(entry)
	return entry.id and scenetree.findObjectById(entry.id) or nil
end

local function releaseSound(entry)
	local src = soundSource(entry)
	if src then pcall(src.stop, src, -1) pcall(src.delete, src) end
	entry.id, entry.event, entry.owner, entry.playing = nil, nil, nil, false
end

local function stopAllSounds()
	for _, entry in ipairs(soundPool) do releaseSound(entry) end
	table.clear(soundPool)
end

local function soundEligible(v)
	local p = v.proxy
	if v.isLocal or v.isDeleted or not p or not p.hasData or p.isPerson then return false end
	if v.proxyHandover then return v.proxyHandover.state == "spawning" end -- real car hidden, not playing yet
	return (v.isProxy and not v.isSpawned) or v.hybridPaused == true
end

--- every decision pass: nearest running proxies get a source, the others fade out
local function assignSounds(vehicles)
	if not cfg.engineSound or cfg.engineSoundMax == 0 or not (Engine and Engine.Audio and Engine.Audio.createSource) then
		if #soundPool > 0 then stopAllSounds() end
		return
	end
	local maxD2 = cfg.engineSoundDist * cfg.engineSoundDist
	local wanted = {}
	for _, v in pairs(vehicles) do
		if soundEligible(v) and proxyEngineRunning(v.proxy) then
			local d2 = refPos:squaredDistance(v.proxy.rpos)
			if d2 < maxD2 then wanted[#wanted + 1] = { v = v, d2 = d2 } end
		end
	end
	table.sort(wanted, function(a, b) return a.d2 < b.d2 end)
	local keep = {}
	for i = 1, math.min(#wanted, cfg.engineSoundMax) do keep[wanted[i].v] = true end
	for _, entry in ipairs(soundPool) do -- owners that lost their slot fade out (owner kept until silent)
		if entry.owner and not keep[entry.owner] then entry.leaving = true end
		if entry.owner and keep[entry.owner] then entry.leaving = false keep[entry.owner] = entry end
	end
	for v, slot in pairs(keep) do
		if slot == true then
			local event, diesel, snd = soundFor(v)
			if event then
				local entry
				for _, e in ipairs(soundPool) do if not e.owner and e.event == event then entry = e break end end
				if not entry then for _, e in ipairs(soundPool) do if not e.owner then entry = e break end end end
				if not entry and #soundPool < cfg.engineSoundMax then entry = {} soundPool[#soundPool + 1] = entry end
				if entry then
					if entry.event ~= event then
						releaseSound(entry)
						local ok, id = pcall(Engine.Audio.createSource, "AudioDefaultLoop3D", event)
						entry.id = ok and id or nil
						local src = entry.id and scenetree.findObjectById(entry.id)
						soundCounter = soundCounter + 1
						if src then pcall(src.setName, src, "beammpProxySound_" .. soundCounter) end -- found again after a Lua reload
						entry.event = event
					end
					entry.owner, entry.diesel, entry.leaving, entry.vol, entry.snd = v, diesel, false, 0, snd
					local src = soundSource(entry)
					if src and snd and snd.event then -- same base parameters combustionEngine.lua sets (eq bands left out)
						pcall(src.setParameter, src, "base_gain", math.min(0, tonumber(snd.mainGain) or 0))
						pcall(src.setParameter, src, "main_gain", 0)
						pcall(src.setParameter, src, "onLoadGain", tonumber(snd.onLoadGain) or 1)
						pcall(src.setParameter, src, "offLoadGain", tonumber(snd.offLoadGain) or 1)
						pcall(src.setParameter, src, "base_muffled", tonumber(snd.muffling) or (snd.kind == "exhaust" and 0 or 1))
					end
				end
			end
		end
	end
	for i = #soundPool, cfg.engineSoundMax + 1, -1 do releaseSound(soundPool[i]) table.remove(soundPool, i) end
end

--- every frame, only for the few sources in use: position, RPM, load and fades
local function updateSounds(dt)
	if #soundPool == 0 then return end
	soundMat = soundMat or MatrixF(true)
	for _, entry in ipairs(soundPool) do
		local v = entry.owner
		if v then
			local src = soundSource(entry)
			local p = v.proxy
			local alive = src and p and soundEligible(v) and proxyEngineRunning(p)
			local target = (alive and not entry.leaving) and 1 or 0
			entry.vol = entry.vol + math.max(-SOUND_FADE * dt, math.min(SOUND_FADE * dt, target - entry.vol))
			if not src or not p or (entry.vol <= 0 and target == 0) then
				if src and entry.playing then pcall(src.stop, src, -1) end
				entry.owner, entry.playing, entry.leaving = nil, false, false
			else
				local rpm, load = estimateRpm(p, entry.diesel, p.svel:length(), entry.snd)
				entry.rpm = entry.rpm and entry.rpm + (rpm - entry.rpm) * math.min(1, dt * 6) or rpm
				soundMat:setPosition(p.rpos)
				src:setTransform(soundMat)
				src:setParameter("RPM", entry.rpm)
				src:setParameter("Load", load)
				src:setParameter("volume", entry.vol)
				if not entry.playing then src:play(-1) entry.playing = true end
			end
		end
	end
end


-- ============= TIRE SCREECH =============
-- a few looping skid sources (the event lua/vehicle/sounds.lua uses on rigid ground) for the nearest proxies
-- whose motion says the tires slide: sideways speed (drifting) or hard braking, from the predicted kinematics
local skid = { pool = {}, fwd = vec3(), right = vec3(), mat = nil, EVENT = "event:>Surfaces>skid_rigid_v2", MAX = 3 }

function skid.slip(p)
	local speed = p.svel:length()
	if speed < 3 then return 0 end
	skid.fwd:setRotate(p.rrot, vec3(0, -1, 0)) -- vehicles face -Y
	skid.right:setRotate(p.rrot, vec3(1, 0, 0))
	local lat = math.abs(p.svel:dot(skid.right))
	local vf = p.svel:dot(skid.fwd)
	local brake = -p.acc:dot(skid.fwd) * (vf >= 0 and 1 or -1) -- deceleration along the travel direction
	return math.max(clamp((lat - 1.2) / 4, 0, 1), clamp((brake - 6) / 6, 0, 1))
end

function skid.release(e)
	local src = e.id and scenetree.findObjectById(e.id)
	if src then pcall(src.stop, src, -1) pcall(src.delete, src) end
	e.id, e.owner, e.playing = nil, nil, false
end

function skid.stopAll()
	for _, e in ipairs(skid.pool) do skid.release(e) end
	table.clear(skid.pool)
end

function skid.assign(vehicles)
	if not cfg.tireScreech or not (Engine and Engine.Audio and Engine.Audio.createSource) then
		if #skid.pool > 0 then skid.stopAll() end
		return
	end
	local maxD2 = cfg.screechDist * cfg.screechDist
	local wanted = {}
	for _, v in pairs(vehicles) do
		local p = v.proxy
		if soundEligible(v) and p.hasData then
			local d2 = refPos:squaredDistance(p.rpos)
			if d2 < maxD2 and skid.slip(p) > 0.05 then wanted[#wanted + 1] = { v = v, d2 = d2 } end
		end
	end
	table.sort(wanted, function(a, b) return a.d2 < b.d2 end)
	local keep = {}
	for i = 1, math.min(#wanted, skid.MAX) do keep[wanted[i].v] = true end
	for _, e in ipairs(skid.pool) do if e.owner and keep[e.owner] then keep[e.owner] = e end end
	for v, slot in pairs(keep) do
		if slot == true then
			local entry
			for _, e in ipairs(skid.pool) do if not e.owner then entry = e break end end
			if not entry and #skid.pool < skid.MAX then entry = { vol = 0 } skid.pool[#skid.pool + 1] = entry end
			if entry then
				if not entry.id then
					local ok, id = pcall(Engine.Audio.createSource, "AudioDefaultLoop3D", skid.EVENT)
					entry.id = ok and id or nil
					local src = entry.id and scenetree.findObjectById(entry.id)
					soundCounter = soundCounter + 1
					if src then
						pcall(src.setName, src, "beammpProxySound_" .. soundCounter)
						-- tire property parameters as sounds.lua sets them, neutral values
						pcall(src.setParameter, src, "c_tirPrpVolSkd", 1)
						pcall(src.setParameter, src, "c_tirPrpPitch", 1)
						pcall(src.setParameter, src, "c_tirPrpSoft", 0.5)
					end
				end
				entry.owner, entry.vol = v, 0
			end
		end
	end
end

function skid.update(dt)
	if #skid.pool == 0 then return end
	skid.mat = skid.mat or MatrixF(true)
	for _, e in ipairs(skid.pool) do
		local v = e.owner
		if v then
			local src = e.id and scenetree.findObjectById(e.id)
			local p = v.proxy
			local target = (src and p and soundEligible(v)) and skid.slip(p) or 0
			e.vol = e.vol + (target - e.vol) * math.min(1, dt * 8)
			if not src or (e.vol < 0.02 and target == 0) then
				if src and e.playing then pcall(src.stop, src, -1) end
				e.owner, e.playing = nil, false
			else
				skid.mat:setPosition(p.rpos)
				src:setTransform(skid.mat)
				if src.setVolumePitch then pcall(src.setVolumePitch, src, e.vol, 1, e.vol + 0.5, 0)
				else pcall(src.setParameter, src, "volume", e.vol) end
				if not e.playing then src:play(-1) e.playing = true end
			end
		end
	end
end


-- ============= TIRE / EXHAUST SMOKE =============
-- a small pool of ParticleEmitterNode objects (created like editor/createObjectTool.lua buildParticleEmitter does)
-- moved to the nearest sliding proxies (tire smoke, BNGP_6 = rubber on asphalt in lua/common/particles.json) or
-- hard accelerating ones (exhaust puff)
local smoke = { pool = {}, MAX = 4, TIRE = "BNGP_6", EXHAUST = "BNGP_44", counter = 0, pos = vec3(), fwd = vec3(), up = vec3(), warned = {} }

function smoke.kindFor(p)
	if not p or not p.hasData then return nil end
	if skid.slip(p) > 0.4 then return "tire" end
	smoke.fwd:setRotate(p.rrot, vec3(0, -1, 0))
	local speed = p.svel:length()
	if speed < 15 and p.acc:dot(smoke.fwd) > 2.5 and proxyEngineRunning(p) then return "exhaust" end
	return nil
end

function smoke.emitterFor(kind)
	local name = kind == "tire" and smoke.TIRE or smoke.EXHAUST
	local db = scenetree.findObject(name)
	if not db and not smoke.warned[name] then
		smoke.warned[name] = true
		log('W', 'MPProxyGE', "Proxy smoke: particle emitter " .. name .. " not found, " .. kind .. " smoke off")
	end
	return db, name
end

function smoke.release(e)
	local o = e.id and scenetree.findObjectById(e.id)
	if o then o:delete() end
	e.id, e.owner, e.kind = nil, nil, nil
end

function smoke.stopAll()
	for _, e in ipairs(smoke.pool) do smoke.release(e) end
	table.clear(smoke.pool)
end

function smoke.assign(vehicles)
	if not cfg.smoke then
		if #smoke.pool > 0 then smoke.stopAll() end
		return
	end
	local maxD2 = cfg.smokeDist * cfg.smokeDist
	local wanted = {}
	for _, v in pairs(vehicles) do
		if soundEligible(v) then
			local d2 = refPos:squaredDistance(v.proxy.rpos)
			local kind = d2 < maxD2 and smoke.kindFor(v.proxy)
			if kind then wanted[#wanted + 1] = { v = v, d2 = d2, kind = kind } end
		end
	end
	table.sort(wanted, function(a, b) return a.d2 < b.d2 end)
	for _, e in ipairs(smoke.pool) do e.keep = false end
	for i = 1, math.min(#wanted, smoke.MAX) do
		local w = wanted[i]
		local entry
		for _, e in ipairs(smoke.pool) do if e.owner == w.v and e.kind == w.kind then entry = e end end
		if not entry then
			for _, e in ipairs(smoke.pool) do if not e.keep and (not e.owner or e.owner ~= w.v) then entry = e break end end
			if not entry and #smoke.pool < smoke.MAX then entry = {} smoke.pool[#smoke.pool + 1] = entry end
			if entry and entry.kind ~= w.kind then
				smoke.release(entry)
				local db, name = smoke.emitterFor(w.kind)
				if db then
					local o = createObject("ParticleEmitterNode")
					if o then
						o:setField("dataBlock", 0, "lightExampleEmitterNodeData1")
						o:setField("emitter", 0, name)
						o.canSave = false
						smoke.counter = smoke.counter + 1
						o:registerObject("beammpProxySmoke_" .. smoke.counter)
						if o.setEmitterDataBlock then o:setEmitterDataBlock(db) end
						entry.id, entry.kind = o:getId(), w.kind
					end
				end
			end
			if entry then entry.owner = w.v end
		end
		if entry then entry.keep = true end
	end
	for _, e in ipairs(smoke.pool) do
		if not e.keep and e.owner then
			e.owner = nil
			local o = e.id and scenetree.findObjectById(e.id)
			if o then o:setField("active", 0, "0") end
		end
	end
end

function smoke.update()
	for _, e in ipairs(smoke.pool) do
		local v = e.owner
		local o = v and e.id and scenetree.findObjectById(e.id)
		if o then
			local p = v.proxy
			local on = soundEligible(v) and smoke.kindFor(p) == e.kind
			o:setField("active", 0, on and "1" or "0")
			if on then
				smoke.fwd:setRotate(p.rrot, vec3(0, -1, 0))
				smoke.up:setRotate(p.rrot, vec3(0, 0, 1))
				local back = (p.L or 4) * (e.kind == "tire" and 0.3 or 0.5)
				local down = e.kind == "tire" and (p.cogH or 0.5) or math.max(0, (p.cogH or 0.5) - 0.3)
				smoke.pos:set(p.rpos.x - smoke.fwd.x * back - smoke.up.x * down, p.rpos.y - smoke.fwd.y * back - smoke.up.y * down,
					p.rpos.z - smoke.fwd.z * back - smoke.up.z * down)
				o:setPosition(smoke.pos)
			end
		end
	end
end

-- ============= SWAP MANAGER =============
local function isEligibleForReal(v)
	return v.isProxy and not v.isSpawned and not v.isDeleted and not v.isIllegal and not v.spawnQueue
		and (not v.proxyUserUnloaded or v.proxyForceReal) -- removed by the user: only when asked for again
		and v.proxy and v.proxy.validModel ~= false and MPVehicleGE.hasSpawnData(v.serverVehicleString)
end

local function decide(vehicles, activeVehID)
	local realCount = 0
	local nearestCand, nearestCandD = nil, math.huge
	local farthestReal, farthestRealD = nil, -1
	local despawnCand, despawnCandD = nil, -1
	local despawn2 = cfg.despawnDist

	for serverVehicleID, v in pairs(vehicles) do
		if not v.isLocal and v:getOwner() then
			local d = refPos:distance(v.position)
			local p = v.proxy
			local cooled = not p or clock >= (p.cooldownUntil or 0)
			local isReal = v.isSpawned and v.gameVehicleID and v.gameVehicleID > 0
			local isPending = v.spawnQueue ~= nil and v.isProxy

			if isReal or isPending then
				realCount = realCount + 1
				local isActive = isReal and v.gameVehicleID == activeVehID
				if cooled and not isActive and not v.proxyForceReal then
					if not cfg.enabled or hybridActive or v.hybridPaused then
						-- proxy mode off / hybrid mode (far vehicles are paused instead): nothing gets demoted
					elseif d > despawn2 and d > despawnCandD then -- demotion stays on, it never spawns anything
						despawnCand, despawnCandD = v, d
					end
					if d > farthestRealD then farthestReal, farthestRealD = v, d end
				end
			elseif isEligibleForReal(v) and cooled then
				-- only explicit requests (spectate / requestRealVehicle) unless distance based real spawns are enabled
				-- hybrid mode spawns everything in range (paused when not near), dropped queue entries come back by distance
				local wanted = (not cfg.enabled) or v.proxyForceReal or (hybridActive and d < queueRanges())
					or (cfg.autoReal and d < cfg.spawnDist)
				local dd = v.proxyForceReal and -1 or d
				if wanted and dd < nearestCandD then nearestCand, nearestCandD = v, dd end
			end
		end
	end

	-- real -> proxy: out of range
	if despawnCand and clock >= nextDespawnAllowed then
		nextDespawnAllowed = clock + DESPAWN_INTERVAL
		if MPVehicleGE.demoteToProxy(despawnCand.serverVehicleString) then
			if despawnCand.proxy then despawnCand.proxy.cooldownUntil = clock + cfg.cooldown end
			realCount = realCount - 1
		end
	end

	if not nearestCand then return end
	local limit = (cfg.enabled and not hybridActive) and cfg.maxReal or math.huge -- paused vehicles cost no physics

	-- real -> proxy: make room for a much closer proxy (cap reached)
	if realCount >= limit and cfg.enabled and cfg.autoReal and farthestReal and farthestReal ~= despawnCand
		and farthestRealD > nearestCandD + CAP_SWAP_MARGIN and clock >= nextDespawnAllowed then
		nextDespawnAllowed = clock + DESPAWN_INTERVAL
		if MPVehicleGE.demoteToProxy(farthestReal.serverVehicleString) then
			if farthestReal.proxy then farthestReal.proxy.cooldownUntil = clock + cfg.cooldown end
			realCount = realCount - 1
		end
	end

	-- proxy -> real, at most one per spawnInterval (forced ones, e.g. spectate, skip the interval)
	if (realCount < limit or nearestCand.proxyForceReal) and (clock >= nextSpawnAllowed or nearestCand.proxyForceReal) then
		nextSpawnAllowed = clock + cfg.spawnInterval
		if nearestCand.proxyColliderID then colliderPool.release(nearestCand.proxyColliderID) end
		nearestCand.proxyForceReal = nil
		startHandover(nearestCand) -- keeps the proxy drawn until the real vehicle is placed and synced
		if not nearestCand.proxyHandover and MPProxyMeshGE then MPProxyMeshGE.release(nearestCand.proxy) end
		if MPVehicleGE.promoteToReal(nearestCand.serverVehicleString) then
			nearestCand.proxy.cooldownUntil = clock + cfg.cooldown
		else
			finishHandover(nearestCand, "spawn not started")
		end
	end
end

--- Per frame update, called by MPVehicleGE.onPreRender before nametags are drawn.
-- @tparam number dt
-- @tparam vec3 cameraPos distance reference (active vehicle, or camera in free cam)
-- @tparam number activeVehID game id of the vehicle the local player is in, or nil
-- perf / tier statistics for MPProxyTest (cheap counters, no allocations)
local perfTimer = nil -- created lazily, hptimer is not defined yet when extensions load
local function getPerfTimer()
	if perfTimer == nil then
		local ok, t = pcall(function() return (hptimer and hptimer()) or (HighPerfTimer and HighPerfTimer()) end)
		perfTimer = ok and t or false
	end
	return perfTimer or nil
end
local stats = { frames = 0, totalMs = 0, maxMs = 0, decideMs = 0, decides = 0, mesh = 0, box = 0, prism = 0, hidden = 0 }
local function resetPerf()
	stats.frames, stats.totalMs, stats.maxMs, stats.decideMs, stats.decides = 0, 0, 0, 0, 0
end

local tabUpdate -- Tab cycling onto proxies, defined below requestReal

local function update(dt, cameraPos, activeVehID)
	local perfTimer = getPerfTimer()
	if perfTimer then perfTimer:stopAndReset() end
	clock = clock + dt
	refPos:set(cameraPos)
	local activeVeh = activeVehID and getObjectByID(activeVehID)
	hasLocalVeh = activeVeh ~= nil
	if activeVeh then localVehPos:set(activeVeh:getPositionXYZ()) end

	local vehicles = MPVehicleGE.getVehicles()
	local camX, camY, camZ = core_camera.getPositionXYZ()
	tmpV:set(camX, camY, camZ)
	local camPos = vec3(tmpV) -- one allocation per frame, not per proxy
	local drawDist2 = cfg.drawDist * cfg.drawDist
	local nMesh, nBox, nPrism, nHidden = 0, 0, 0, 0

	for _, v in pairs(vehicles) do
		local p = v.proxy
		if ((v.isProxy and not v.isSpawned) or v.proxyHandover or v.hybridPaused) and not v.isLocal and p and p.hasData then
			if v.proxyHandover then
				-- the vehicle table position belongs to the real vehicle now, only move the proxy itself
				tmpPosSave:set(v.position) tmpRotSave:set(v.rotation)
				predict(v, p, dt)
				v.position:set(tmpPosSave) v.rotation:set(tmpRotSave)
			else
				predict(v, p, dt)
			end
			if not v.isDeleted then -- a collider is invisible, the proxy stays what is drawn
				local d2 = camPos:squaredDistance(p.rpos)
				if d2 < drawDist2 then
					local dist = math.sqrt(d2)
					-- tier 1: real body meshes (MPProxyMeshGE), tier 2: box, tier 3 (beyond drawDist): nametag only
					if p.meshObjects and MPProxyMeshGE and MPProxyMeshGE.drawProxy(p, dist) then
						nMesh = nMesh + 1
					elseif v.isFakeTest then
						nHidden = nHidden + 1 -- MPProxyTest vehicles are only ever shown as meshes
					else
						drawProxy(p, camPos, dist)
						if p.farBox then nPrism = nPrism + 1 else nBox = nBox + 1 end
					end
				else
					nHidden = nHidden + 1
				end
			end
		end
	end

	stats.mesh, stats.box, stats.prism, stats.hidden = nMesh, nBox, nPrism, nHidden
	updateSounds(dt)
	skid.update(dt)
	if #smoke.pool > 0 then smoke.update() end

	updateHandovers(vehicles)
	hybridContacts(vehicles)

	decisionTimer = decisionTimer - dt
	local decideStart = perfTimer and perfTimer:stop() or 0
	local didDecide = decisionTimer <= 0
	if didDecide then
		decisionTimer = DECISION_INTERVAL
		updateHybrid(vehicles, activeVehID)
		updateQueuedSpawns(vehicles)
		decide(vehicles, activeVehID)
		updateColliders(vehicles)
		assignSounds(vehicles)
		skid.assign(vehicles)
		smoke.assign(vehicles)
		if MPProxyMeshGE then
			MPProxyMeshGE.decide(vehicles, refPos)
			for _, v in pairs(vehicles) do -- use the real mesh bounds for the box fallback once known
				local p = v.proxy
				if p and p.meshKey and not p.dimsFromMesh then
					local shape = MPProxyMeshGE.getShape(p.meshKey)
					if shape and shape.state == "ready" and shape.minX then
						setDims(p, shape.maxY - shape.minY, shape.maxX - shape.minX, shape.maxZ - (shape.groundZ or shape.minZ))
						p.dimsFromMesh = true
					end
				end
			end
		end
	end
	tabUpdate(dt)
	if perfTimer then
		local ms = perfTimer:stop()
		stats.frames = stats.frames + 1
		stats.totalMs = stats.totalMs + ms
		if ms > stats.maxMs then stats.maxMs = ms end
		if didDecide then
			stats.decides = stats.decides + 1
			stats.decideMs = stats.decideMs + (ms - decideStart)
		end
	end
end

--- Returns tier counts, collider usage and per frame cost of update(). Resets the perf window if resetWindow is set.
local function getStats(resetWindow)
	local out = { mesh = stats.mesh, box = stats.box, prism = stats.prism, hidden = stats.hidden,
		real = 0, realQueued = 0, proxies = 0, collidersUsed = 0, collidersPool = 0, timerAvailable = getPerfTimer() ~= nil,
		frames = stats.frames, avgMs = stats.frames > 0 and stats.totalMs / stats.frames or 0, maxMs = stats.maxMs,
		avgDecideMs = stats.decides > 0 and stats.decideMs / stats.decides or 0 }
	for _, v in pairs(MPVehicleGE.getVehicles()) do
		if not v.isLocal then
			if v.isSpawned then
				out.real = out.real + 1
				if v.hybridPaused then out.paused = (out.paused or 0) + 1 end
			elseif v.isProxy then
				out.proxies = out.proxies + 1
				if v.proxyForceReal then out.realQueued = out.realQueued + 1 end
			end
		end
	end
	out.collidersPool, out.collidersUsed = colliderPool.getCount()
	if resetWindow then resetPerf() end
	return out
end
M.getStats = getStats

--- Asks the manager to swap a proxy for a real vehicle as soon as possible (ignores distance, cap and interval).
local function requestReal(vehicle)
	if vehicle and vehicle.hybridPaused then
		hybridWake(vehicle, "requested")
		return true
	end
	if vehicle and vehicle.isProxy and not vehicle.isSpawned then
		vehicle.proxyUserUnloaded = nil -- asked for (Tab, spectate, restore): normal rules again
		vehicle.proxyForceReal = true
		decisionTimer = 0
		return true
	end
	return false
end


-- Tab cycling: after the real vehicles, Tab walks through the proxies. The camera orbits the proxy (free camera
-- placed every frame, driven by the same MoveManager yaw/pitch/zoom values the orbit camera mode reads). Camera only,
-- Tab never spawns anything.
local tab = { v = nil, home = nil, yaw = 0, pitch = 12, dist = 8, target = vec3(), seeded = false }
local origSwitchCycle = nil

local function tabProxyList(vehicles)
	local list = {}
	for _, v in pairs(vehicles) do
		local p = v.proxy
		if ((v.isProxy and not v.isSpawned) or v.hybridPaused) and not v.isLocal and not v.isDeleted and p and p.hasData then
			list[#list + 1] = v
		end
	end
	table.sort(list, function(a, b) return (tonumber(a.serverVehicleID) or 0) < (tonumber(b.serverVehicleID) or 0) end)
	return list
end

local function tabRealList()
	local order = {}
	for i = 0, be:getObjectCount() - 1 do
		local veh = be:getObject(i)
		if veh and veh:getJBeamFilename() ~= "unicycle" and veh.playerUsable ~= false and veh:getActive()
			and not colliderPool.isCollider(veh:getId()) then
			order[#order + 1] = veh:getId()
		end
	end
	return order
end

local function tabStop(enterId)
	local hadFocus = tab.v ~= nil
	tab.v = nil
	if not hadFocus then return end
	if tab.speed and core_camera.setSpeed then core_camera.setSpeed(tab.speed) end
	tab.speed = nil
	if commands and commands.setGameCamera then commands.setGameCamera(0) end
	local veh = enterId and getObjectByID(enterId)
	if veh then
		be:enterVehicle(0, veh)
		extensions.hook('trackNewVeh')
		extensions.hook("onVehicleSwitchPerformendByUser")
	end
end

local function tabFocus(v)
	if not tab.v then tab.home = be:getPlayerVehicleID(0) end
	tab.v = v
	tab.seeded = false
	tab.target:set(v.proxy.rpos)
	local fwd = v.proxy.rrot * vec3(0, -1, 0) -- BeamNG vehicles face -Y
	tab.yaw = math.deg(math.atan2(fwd.x, fwd.y))
	if commands and commands.setFreeCamera and not commands.isFreeCamera(0) then commands.setFreeCamera(0) end
	-- the free camera would also fly on WASD; fly speed 0 while we place it (restored in tabStop)
	if not tab.speed and core_camera.getSpeed and core_camera.setSpeed then
		tab.speed = core_camera.getSpeed() or 30
		core_camera.setSpeed(0)
	end
	log('I', 'MPProxyGE', "Tab: camera on proxy " .. tostring(v.serverVehicleID))
end

local function switchCycle(player, dir)
	if not (cfg.enabled and cfg.tabCycle) or (player or 0) ~= 0 or not MPVehicleGE then
		return origSwitchCycle(player, dir)
	end
	local reals, proxies = tabRealList(), tabProxyList(MPVehicleGE.getVehicles())
	if #proxies == 0 then tabStop(nil) return origSwitchCycle(player, dir) end
	local n = #reals + #proxies
	local cur
	if tab.v then
		for i, v in ipairs(proxies) do if v == tab.v then cur = #reals + i end end
	else
		local id = be:getPlayerVehicleID(0)
		for i, rid in ipairs(reals) do if rid == id then cur = i end end
	end
	cur = cur or (dir > 0 and 0 or 1)
	local nextI = ((cur - 1 + dir) % n) + 1
	if nextI <= #reals then
		if tab.v then tabStop(reals[nextI]) else return origSwitchCycle(player, dir) end
	else
		tabFocus(proxies[nextI - #reals])
	end
end

local function installTabHook()
	local vs = extensions.core_input_vehicleSwitching
	if not vs then
		extensions.load("core_input_vehicleSwitching")
		vs = extensions.core_input_vehicleSwitching
	end
	if vs and vs.switchCycleVehicle ~= switchCycle then
		origSwitchCycle = vs.switchCycleVehicle
		vs.switchCycleVehicle = switchCycle
	end
end

local function removeTabHook()
	local vs = extensions.core_input_vehicleSwitching
	if vs and origSwitchCycle and vs.switchCycleVehicle == switchCycle then vs.switchCycleVehicle = origSwitchCycle end
	tabStop(nil)
end

local camOff, camLook = vec3(), quat()
tabUpdate = function(dt)
	local v = tab.v
	if not v then return end
	if v.isDeleted or not v.proxy then
		log('I', 'MPProxyGE', "Tab: focused proxy went away, back to own vehicle")
		return tabStop(tab.home)
	end
	if v.isSpawned and not v.proxyHandover and not v.hybridPaused and v.gameVehicleID and getObjectByID(v.gameVehicleID) then
		-- spawned for real by the normal rules (distance, auto real) while watched: the proxy is gone, enter the car
		log('I', 'MPProxyGE', "Tab: watched proxy became a real vehicle, entering " .. tostring(v.serverVehicleID))
		return tabStop(v.gameVehicleID)
	end
	if tab.seeded and not commands.isFreeCamera(0) then -- user changed camera, let go
		if tab.speed and core_camera.setSpeed then core_camera.setSpeed(tab.speed) end
		tab.v, tab.speed = nil, nil
		return
	end
	tab.seeded = true
	-- same inputs as cameraModes/orbit.lua (MoveManager yaw/pitch relative and axis values, zoomIn/zoomOut)
	local mm = MoveManager
	if mm then
		local dtf = dt * 1000
		local maxRotDt = 1000 * dt
		tab.yaw = tab.yaw - (clamp(mm.yawRelative * 10, -maxRotDt, maxRotDt) + 0.1 * (mm.yawRight - mm.yawLeft) * dtf)
		tab.pitch = clamp(tab.pitch - (clamp(mm.pitchRelative * -10, -maxRotDt, maxRotDt) + 0.1 * (mm.pitchDown - mm.pitchUp) * dtf), -85, 85)
		tab.dist = clamp(tab.dist + (mm.zoomIn - mm.zoomOut) * dtf * 0.01, 2.5, 60)
	end
	local k = 1 - math.exp(-dt * 12)
	tab.target:setLerp(tab.target, v.proxy.rpos, k)
	local yr, pr = math.rad(tab.yaw), math.rad(tab.pitch)
	camOff:set(-math.sin(yr) * math.cos(pr), -math.cos(yr) * math.cos(pr), math.sin(pr))
	local h = (v.proxy.H or 1.5) * 0.5
	local tx, ty, tz = tab.target.x, tab.target.y, tab.target.z + h
	camOff:setScaled(tab.dist)
	camLook:setFromDir(vec3(-camOff.x, -camOff.y, -camOff.z), vec3(0, 0, 1))
	core_camera.setPosRot(0, tx + camOff.x, ty + camOff.y, tz + camOff.z, camLook.x, camLook.y, camLook.z, camLook.w)
end

--- Our own ping in milliseconds (positionGE.setPing), used to map the senders' clocks onto ours.
local function setOwnPing(ping)
	local s = (tonumber(ping) or 0) / 1000
	if s > 0 and s < 5 then ownPing = s end
end

local function isEnabled()
	return cfg.enabled
end

local function getSettings()
	return cfg
end

local function reset()
	colliderPool.removeAll()
	stopAllSounds()
	skid.stopAll()
	smoke.stopAll()
	if MPProxyMeshGE then MPProxyMeshGE.reset() end
	nextSpawnAllowed, nextDespawnAllowed, nextColliderSpawnAllowed = 0, 0, 0
end

local function onSettingsChanged()
	readSettings()
	if not cfg.collision then
		colliderPool.releaseAll()
	end
end

-- objects of an earlier load of these extensions (Lua reload): engine sound sources keep playing and collider
-- vehicles stay in the level when the tables that knew them are gone. Found by their name prefix.
local function removeLeftovers()
	local sounds, cars = 0, 0
	for _, name in ipairs(scenetree.findClassObjects("SFXFMODEventSource") or {}) do
		if string.find(name, "^beammpProxySound_") then
			local src = scenetree.findObject(name)
			if src then pcall(src.stop, src, -1) src:delete() sounds = sounds + 1 end
		end
	end
	for _, name in ipairs(scenetree.findClassObjects("ParticleEmitterNode") or {}) do
		if string.find(name, "^beammpProxySmoke_") then
			local o = scenetree.findObject(name)
			if o then o:delete() sounds = sounds + 1 end
		end
	end
	for _, name in ipairs(scenetree.findClassObjects("BeamNGVehicle") or {}) do
		if string.find(name, "^beammpProxyCollider") then
			local veh = scenetree.findObject(name)
			if veh then veh:delete() cars = cars + 1 end
		end
	end
	if sounds + cars > 0 then log('I', 'MPProxyGE', string.format("Removed leftovers of an earlier load: %d sound sources / smoke emitters, %d collider vehicles", sounds, cars)) end
end

local function onExtensionLoaded()
	readSettings()
	local okHook, errHook = pcall(installTabHook)
	if not okHook then log('W', 'MPProxyGE', "Tab cycle hook failed: " .. tostring(errHook)) end
	if settings.getValue("proxyCleanupOnReload", true) ~= false then
		local ok, err = pcall(removeLeftovers)
		if not ok then log('W', 'MPProxyGE', "Leftover cleanup failed: " .. tostring(err)) end
	end
end

detectGlobalWrites() -- reenable global write notifications

M.update              = update
M.initProxy           = initProxy
M.onPositionPacket    = onPositionPacket
M.seedFromVehicle     = seedFromVehicle
M.snapProxy           = snapProxy
M.requestReal         = requestReal
M.isEnabled           = isEnabled
M.getSettings         = getSettings
M.getModelInfo        = getModelInfo
M.reset               = reset
M.isCollider          = colliderPool.isCollider
M.onColliderReady     = colliderPool.onReady
M.onColliderDestroyed = colliderPool.onDestroyed
M.onSettingsChanged   = onSettingsChanged
M.onRealVehicleReady  = onRealVehicleReady
M.isInHandover        = isInHandover
M.setOwnPing          = setOwnPing
M.captureState        = captureState
M.isHybridPaused      = isHybridPaused
M.hybridWake          = function(vehicle, reason) if vehicle then hybridWake(vehicle, reason or "request") end end
M.isHybridActive      = function() return hybridActive end
M.flushReplay         = flushReplay
M.onVehicleResetWhileHeld = onVehicleResetWhileHeld
M.finishHandover      = finishHandover
M.onExtensionLoaded   = onExtensionLoaded
M.onExtensionUnloaded = function() stopAllSounds() skid.stopAll() smoke.stopAll() pcall(removeTabHook) end
M.isTabFocused        = function() return tab.v ~= nil end
M.getSoundPool        = function() return soundPool end
M.onInit = function() setExtensionUnloadMode(M, "manual") end

return M
