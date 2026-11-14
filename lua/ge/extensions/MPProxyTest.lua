--====================================================================================
-- All work by the BeamMP contributors.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================
-- MPProxyTest: client-side load test for the proxy vehicle system. Fakes remote players
-- and their vehicles entirely locally, no packet is ever sent to the server.
--
-- Fake spawns go through MPVehicleGE.onServerVehicleSpawned (via injectTestSpawn) and fake
-- position packets through positionGE.handle, i.e. the same code paths as real remote
-- vehicles: proxy creation, prediction, real swap, mesh tier, colliders and nametags.
-- Fake player IDs start at 900000 (MPVehicleGE.PROXY_TEST_MIN_PLAYER_ID). MPVehicleGE refuses
-- to send 'Om' for them, remote vehicles never send 'Od'/'Oc'/'Or', so nothing leaks.
-- Works in freeroam / singleplayer and while connected to a server.
--
-- GE Lua console (~):
--   MPProxyTest.spawn()                            -- default: 20 random stock cars, circle R=300 m whose
--                                                  -- center is 150 m off you, so they cross the 200/260 m swap
--   MPProxyTest.spawn(40, {pattern="sweep"})       -- drive radially 50..600 m and back
--   MPProxyTest.spawn(10, {model="current"})       -- copies of your current vehicle (config + paint)
--   MPProxyTest.spawn(10, {model="pickup", pattern="line", radius=400, speed=30})
--   MPProxyTest.spawn(30, {pattern="wander", rate=10, jitter=150, loss=0.1})
--   MPProxyTest.status()                           -- counts per tier, colliders, mesh cache
--   MPProxyTest.perf()                             -- avg/max ms per frame since last perf() call
--   MPProxyTest.clear()                            -- remove all fake vehicles and players
--
-- spawn(n, opts) options (all optional):
--   model   = "random" (stock cars/trucks) | "current" | "<model key>"   default "random"
--   pattern = "circle" | "line" | "wander" | "sweep"                     default "circle"
--   radius  = meters (circle radius / line half length / wander radius / sweep max)   300
--   offset  = circle center offset from you in meters                    radius * 0.5
--   minDist = sweep minimum distance                                     50
--   speed   = m/s                                                        20
--   rate    = position packets per second per vehicle                    30
--   jitter  = max extra random delivery delay in ms (reorders packets)   0
--   loss    = packet loss probability 0..1                               0
-- Calling spawn again adds more vehicles (they keep their own pattern), clear() removes all.
--
-- Chat (BeamMP chat box, intercepted before sending, never reaches the server):
--   /proxytest                     -> spawn() defaults
--   /proxytest 40 sweep radius=500 model=current speed=25 rate=20 jitter=100 loss=0.05
--   /proxytest status | perf | clear | help
--
-- Every fake vehicle is drawn as its BeamNG body mesh, never as a box: spawn() first builds the
-- mesh cache for the chosen configs and only spawns once they are ready (a failed build falls back
-- to FALLBACK_MODEL), fake vehicles ignore the mesh distance/cap and are not drawn while no mesh is attached.
--   variety = number of distinct random models (each is one cache build)  default 4
-- Requires "Proxy vehicles" enabled in the BeamMP settings (else every fake vehicle would be a real spawn).
--====================================================================================

local M = {}

local FIRST_ID = 900000 -- keep in sync with MPVehicleGE.PROXY_TEST_MIN_PLAYER_ID
local HEIGHT_REFRESH = 0.5
local FALLBACK_MODEL = "covet"
local PREFERRED_RANDOM = { covet = true, sunburst2 = true, vivace = true, etk800 = true, bastion = true, legran = true,
	fullsize = true, midsize = true, bx = true, pessima = true, moonhawk = true, barstow = true, burnside = true, miramar = true,
	etki = true, sbr = true, pickup = true, bluebuck = true, autobello = true, wendover = true, lansdale = true, scintilla = true }
local pending = {}      -- spawn batches waiting for their mesh cache builds

local fakes = {}        -- [serverVehicleID] = state
local fakeOrder = {}    -- serverVehicleIDs in spawn order
local inFlight = {}     -- delayed packets { due, sid, json }
local nextPlayerID = FIRST_ID
local clock = 0
local randomModels = nil

local function msg(text)
	log('I', 'MPProxyTest', text)
	print("[MPProxyTest] "..text)
end

local function isActive() return next(fakes) ~= nil or #pending > 0 end

local function getRefPos()
	local veh = getPlayerVehicle(0)
	if veh then return vec3(veh:getPositionXYZ()) end
	return vec3(core_camera.getPositionXYZ())
end

local function groundZ(x, y, refZ)
	local z = be:getSurfaceHeightBelow(vec3(x, y, refZ + 100))
	if not z or z < -1e6 then return refZ end
	return z
end

-- config tables ----------------------------------------------------------------------

local function getRandomModels()
	if randomModels then return randomModels end
	randomModels = {}
	for key, model in pairs(core_vehicles.getModelList().models or {}) do
		local official = model.aggregates and model.aggregates.Source and model.aggregates.Source['BeamNG - Official']
		if official and model.Type == "Car" and PREFERRED_RANDOM[key] then table.insert(randomModels, key) end
	end
	if #randomModels == 0 then -- unknown game version: any official car
		for key, model in pairs(core_vehicles.getModelList().models or {}) do
			local official = model.aggregates and model.aggregates.Source and model.aggregates.Source['BeamNG - Official']
			if official and model.Type == "Car" then table.insert(randomModels, key) end
		end
	end
	table.sort(randomModels)
	return randomModels
end

local function defaultConfig(modelKey)
	local m = core_vehicles.getModel(modelKey)
	if not m or not m.model then return nil end
	local pcName = m.model.default_pc
	local pc = pcName and jsonReadFile("/vehicles/"..modelKey.."/"..pcName..".pc")
	local vcf = { parts = {}, vars = {} }
	if type(pc) == "table" then
		vcf.parts = type(pc.parts) == "table" and pc.parts or {}
		if next(vcf.parts) == nil and type(pc.partsTree) == "table" then -- newer tree format: flatten slot -> part
			local function walk(node)
				for slot, child in pairs(node.children or {}) do
					if type(child) == "table" then
						if child.chosenPartName then vcf.parts[slot] = child.chosenPartName end
						walk(child)
					end
				end
			end
			walk(pc.partsTree)
		end
		vcf.vars = type(pc.vars) == "table" and pc.vars or {}
		vcf.paints = pc.paints
	end
	vcf.mainPartName = (type(pc) == "table" and pc.mainPartName) or modelKey -- the root part is named after the model
	vcf.partConfigFilename = pcName and ("vehicles/"..modelKey.."/"..pcName..".pc") or nil
	if type(vcf.paints) ~= "table" or not vcf.paints[1] then
		local c = { math.random(), math.random(), math.random(), 1.2 }
		vcf.paints = { { baseColor = c, metallic = 0.5, roughness = 0.5, clearcoat = 0.8, clearcoatRoughness = 0.1 } }
		vcf.paints[2], vcf.paints[3] = vcf.paints[1], vcf.paints[1]
	end
	return vcf
end

local function currentConfig()
	local veh = getPlayerVehicle(0)
	if not veh then return nil end
	local data = core_vehicle_manager.getVehicleData(veh:getID())
	if not data or not data.config then return nil end
	local vcf = MPHelpers.simplifyVehConfig(deepcopy(data.config))
	vcf.paints = MPHelpers.getColorsFromVehObj(veh)
	return veh:getJBeamFilename(), vcf
end

-- motion -------------------------------------------------------------------------------

local up = vec3(0, 0, 1)

-- advances f by dt, sets f.pos (z excluded), f.fwd and f.yawRate
local function move(f, dt)
	local o = f.opts
	if f.pattern == "circle" then
		f.angle = f.angle + o.speed / o.radius * dt
		f.pos.x = f.center.x + math.cos(f.angle) * o.radius
		f.pos.y = f.center.y + math.sin(f.angle) * o.radius
		f.fwd:set(-math.sin(f.angle), math.cos(f.angle), 0)
		f.yawRate = o.speed / o.radius
	elseif f.pattern == "line" then
		f.s = f.s + f.dir * o.speed * dt
		if f.s > o.radius then f.s, f.dir = o.radius, -1 elseif f.s < -o.radius then f.s, f.dir = -o.radius, 1 end
		f.pos.x = f.center.x + f.axis.x * f.s + f.side.x * f.lane
		f.pos.y = f.center.y + f.axis.y * f.s + f.side.y * f.lane
		f.fwd:set(f.axis.x * f.dir, f.axis.y * f.dir, 0)
		f.yawRate = 0
	elseif f.pattern == "wander" then
		local dx, dy = f.pos.x - f.center.x, f.pos.y - f.center.y
		local turn = (math.random() - 0.5) * 0.8
		if dx * dx + dy * dy > o.radius * o.radius then -- steer back towards the center
			local want = math.atan2(-dy, -dx)
			local diff = (want - f.heading + math.pi) % (2 * math.pi) - math.pi
			turn = diff > 0 and 0.6 or -0.6
		end
		f.yawRate = f.yawRate * 0.9 + turn * 0.1
		f.heading = f.heading + f.yawRate * dt
		f.fwd:set(math.cos(f.heading), math.sin(f.heading), 0)
		f.pos.x = f.pos.x + f.fwd.x * o.speed * dt
		f.pos.y = f.pos.y + f.fwd.y * o.speed * dt
	else -- sweep
		f.s = f.s + f.dir * o.speed * dt
		if f.s > o.radius then f.s, f.dir = o.radius, -1 elseif f.s < o.minDist then f.s, f.dir = o.minDist, 1 end
		f.pos.x = f.center.x + f.axis.x * f.s
		f.pos.y = f.center.y + f.axis.y * f.s
		f.fwd:set(f.axis.x * f.dir, f.axis.y * f.dir, 0)
		f.yawRate = 0
	end
end

local function makePacket(f)
	local o = f.opts
	local rot = quatFromDir(-f.fwd, up)
	return jsonEncode({
		pos = { f.pos.x, f.pos.y, f.pos.z },
		vel = { f.fwd.x * o.speed, f.fwd.y * o.speed, 0 },
		rot = { rot.x, rot.y, rot.z, rot.w },
		rvel = { 0, 0, f.yawRate },
		tim = f.t,
		ping = 0.05 + (o.jitter or 0) * 0.0005,
	})
end

local function deliver(sid, json)
	if fakes[sid] then positionGE.handle("p:"..sid..":"..json) end
end

-- api ------------------------------------------------------------------------------------

local spawnPlanned

local function spawn(n, opts)
	if type(n) == "table" then opts, n = n, nil end
	n = math.max(1, math.floor(tonumber(n) or 20))
	opts = opts or {}
	if not (MPProxyGE and MPProxyGE.isEnabled()) then
		msg("Proxy vehicles are disabled in the BeamMP settings, enable them first (every fake vehicle would be a real spawn)")
		return false
	end
	if not (MPProxyMeshGE and MPProxyMeshGE.isEnabled and MPProxyMeshGE.isEnabled()) then
		msg("Proxy meshes are disabled in the BeamMP settings, enable them first (test vehicles are only drawn as meshes)")
		return false
	end
	local o = {
		model = opts.model or "random",
		pattern = opts.pattern or "circle",
		radius = tonumber(opts.radius) or 300,
		minDist = tonumber(opts.minDist) or 50,
		speed = tonumber(opts.speed) or 20,
		rate = math.max(0.5, tonumber(opts.rate) or 30),
		jitter = math.max(0, tonumber(opts.jitter) or 0),
		loss = math.min(1, math.max(0, tonumber(opts.loss) or 0)),
	}
	o.offset = tonumber(opts.offset) or o.radius * 0.5
	if o.pattern ~= "circle" and o.pattern ~= "line" and o.pattern ~= "wander" and o.pattern ~= "sweep" then
		msg("unknown pattern '"..tostring(o.pattern).."', use circle|line|wander|sweep") return false
	end

	local curModel, curVcf
	if o.model == "current" then
		curModel, curVcf = currentConfig()
		if not curModel then msg("model='current' needs you to be in a vehicle") return false end
	elseif o.model ~= "random" and not (core_vehicles.getModel(o.model) or {}).model then
		msg("unknown model '"..tostring(o.model).."'") return false
	end
	local models = o.model == "random" and getRandomModels() or nil
	if models and #models == 0 then msg("no stock models found") return false end

	if models then -- a few distinct models, each one is a cache build
		local variety = math.max(1, math.floor(tonumber(opts.variety) or 4))
		local pool, copy = {}, deepcopy(models)
		while #pool < variety and #copy > 0 do table.insert(pool, table.remove(copy, math.random(#copy))) end
		models = pool
	end

	local plan = {}
	for i = 1, n do
		local modelKey, vcf
		if curModel then modelKey, vcf = curModel, deepcopy(curVcf)
		elseif models then modelKey = models[(i - 1) % #models + 1]; vcf = defaultConfig(modelKey)
		else modelKey = o.model; vcf = defaultConfig(modelKey) end
		if not vcf or not next(vcf.parts or {}) then modelKey, vcf = FALLBACK_MODEL, defaultConfig(FALLBACK_MODEL) end
		plan[i] = { model = modelKey, vcf = vcf }
	end
	MPVehicleGE.setProxyTestActive(true)
	for _, e in ipairs(plan) do e.key = MPProxyMeshGE.request(e.model, e.vcf) end
	table.insert(pending, { plan = plan, o = o, started = clock })
	msg("building mesh cache for "..n.." fake vehicles, they spawn once ready (MPProxyTest.status() shows progress)")
	return true
end

-- second half of spawn(): all mesh shapes are ready (or the mesh tier is off)
spawnPlanned = function(plan, o)
	local n = #plan
	local ref = getRefPos()
	local lineAngle = math.random() * 2 * math.pi
	local circleCenter = vec3(ref.x + o.offset, ref.y, ref.z)

	for i = 1, n do
		local playerID = nextPlayerID
		nextPlayerID = nextPlayerID + 1
		local sid = playerID.."-0"
		local modelKey, vcf = plan[i].model, plan[i].vcf

		local f = { sid = sid, playerID = playerID, opts = o, pattern = o.pattern, pos = vec3(), fwd = vec3(0, 1, 0),
			yawRate = 0, t = 0, sendAcc = math.random() / o.rate, heightAcc = 0, refZ = ref.z, model = modelKey }
		if o.pattern == "circle" then
			f.center = circleCenter
			f.angle = (i - 1) / n * 2 * math.pi
		elseif o.pattern == "line" then
			f.center = vec3(ref)
			f.axis = vec3(math.cos(lineAngle), math.sin(lineAngle), 0)
			f.side = vec3(-f.axis.y, f.axis.x, 0)
			f.lane = ((i - 1) % 4 - 1.5) * 4
			f.s = -o.radius + (i - 1) / n * 2 * o.radius
			f.dir = i % 2 == 0 and 1 or -1
		elseif o.pattern == "wander" then
			f.center = vec3(ref)
			local a, r = math.random() * 2 * math.pi, math.sqrt(math.random()) * o.radius
			f.pos:set(ref.x + math.cos(a) * r, ref.y + math.sin(a) * r, ref.z)
			f.heading = math.random() * 2 * math.pi
		else
			f.center = vec3(ref)
			local a = (i - 1) / n * 2 * math.pi
			f.axis = vec3(math.cos(a), math.sin(a), 0)
			f.s = o.minDist + (i - 1) / n * (o.radius - o.minDist)
			f.dir = 1
		end
		move(f, 0)
		f.pos.z = groundZ(f.pos.x, f.pos.y, ref.z) + 0.6
		local rot = quatFromDir(-f.fwd, up)
		local data = { pid = playerID, vid = 0, jbm = modelKey, vcf = vcf or { parts = {} },
			pos = { f.pos.x, f.pos.y, f.pos.z }, rot = { rot.x, rot.y, rot.z, rot.w }, ign = 3, pro = "0", abs = 0 }

		fakes[sid] = f
		table.insert(fakeOrder, sid)
		MPVehicleGE.injectTestSpawn("USER", "ProxyTest "..(playerID - FIRST_ID), sid, jsonEncode(data))
		local v = MPVehicleGE.getVehicleByServerID(sid)
		if v then v.isFakeTest = true end
		deliver(sid, makePacket(f)) -- first packet right away so the proxy has data
	end
	msg(string.format("spawned %d fake vehicles (%s, %s, radius %d m, %d m/s, %d Hz, jitter %d ms, loss %d%%), total %d",
		n, o.model, o.pattern, o.radius, o.speed, o.rate, o.jitter, o.loss * 100, #fakeOrder))
	return true
end

local function clear()
	local count = #fakeOrder
	for _, sid in ipairs(fakeOrder) do
		local f = fakes[sid]
		fakes[sid] = nil
		if MPVehicleGE.getVehicleByServerID(sid) then MPVehicleGE.handle("d:"..sid) end -- local remove, no packet sent
		if f then MPVehicleGE.onPlayerLeft("ProxyTest "..(f.playerID - FIRST_ID)) end
	end
	table.clear(fakeOrder)
	table.clear(fakes)
	table.clear(inFlight)
	table.clear(pending)
	MPVehicleGE.setProxyTestActive(false)
	msg("cleared "..count.." fake vehicles")
end

local function status()
	local s = MPProxyGE.getStats(false)
	local m = MPProxyMeshGE and MPProxyMeshGE.getStats(false) or {}
	local cfg = MPProxyGE.getSettings()
	msg(string.format("fakes %d | real %d (max %d, queued %d) | proxies %d: mesh %d, box %d, prism %d, beyond draw dist %d",
		#fakeOrder, s.real, cfg.maxReal, s.realQueued, s.proxies, s.mesh, s.box, s.prism, s.hidden))
	msg(string.format("colliders %d/%d used (collision %s) | mesh cache: %d ready, %d failed, %d pending%s, %d live TSStatics",
		s.collidersUsed, s.collidersPool, tostring(cfg.collision), m.ready or 0, m.failed or 0, m.queued or 0,
		m.building and (" (building "..m.building..")") or "", m.liveObjects or 0))
	local waiting = 0
	for _, b in ipairs(pending) do waiting = waiting + #b.plan end
	if waiting > 0 then msg(waiting.." fake vehicles waiting for their mesh build") end
	return { proxy = s, mesh = m, fakes = #fakeOrder, waiting = waiting }
end

local function perf()
	local s = MPProxyGE.getStats(true)
	local m = MPProxyMeshGE and MPProxyMeshGE.getStats(true) or {}
	if not s.timerAvailable then msg("hptimer not available, no timings") end
	msg(string.format("MPProxyGE.update: avg %.3f ms, max %.3f ms over %d frames (decision frames avg %.3f ms) | mesh builds: avg %.3f ms, max %.3f ms over %d frames",
		s.avgMs, s.maxMs, s.frames, s.avgDecideMs, m.avgBuildMs or 0, m.maxBuildMs or 0, m.buildFrames or 0))
	return { proxy = s, mesh = m }
end

local HELP = "/proxytest [n] [circle|line|wander|sweep] [model=random|current|<key>] [radius=] [speed=] [rate=] [jitter=] [loss=] [offset=] | status | perf | clear"

--- Chat command entry, called by UI.chatSend. Returns true if the message was a test command.
local function chatCommand(text)
	local args = {}
	for w in tostring(text):gmatch("%S+") do table.insert(args, w) end
	if args[1] ~= "/proxytest" then return false end
	local sub = args[2]
	if sub == "clear" then clear()
	elseif sub == "status" then status()
	elseif sub == "perf" then perf()
	elseif sub == "help" then msg(HELP)
	else
		local n, opts = nil, {}
		for i = 2, #args do
			local k, v = args[i]:match("^(%w+)=(%S+)$")
			if k then opts[k] = tonumber(v) or v
			elseif tonumber(args[i]) then n = tonumber(args[i])
			else opts.pattern = args[i] end
		end
		spawn(n, opts)
	end
	return true
end

-- spawns pending batches whose mesh builds are done, swaps failed builds for the fallback model
local function updatePending()
	local i = 1
	while i <= #pending do
		local b = pending[i]
		local done = true
		for _, e in ipairs(b.plan) do
			local shape = e.key and MPProxyMeshGE.getShape(e.key)
			local state = shape and shape.state or "failed"
			if state == "failed" then
				if e.model ~= FALLBACK_MODEL then
					log('W', 'MPProxyTest', "mesh build failed for "..tostring(e.model)..", using "..FALLBACK_MODEL)
					e.model, e.vcf = FALLBACK_MODEL, defaultConfig(FALLBACK_MODEL)
					e.key = MPProxyMeshGE.request(e.model, e.vcf)
					done = false
				else
					e.skip = true
				end
			elseif state ~= "ready" then
				done = false
			end
		end
		if done then
			table.remove(pending, i)
			local plan = {}
			for _, e in ipairs(b.plan) do if not e.skip then plan[#plan + 1] = e end end
			if #plan < #b.plan then msg((#b.plan - #plan).." fake vehicles skipped, even the fallback mesh failed to build") end
			if #plan > 0 then spawnPlanned(plan, b.o) end
			msg(string.format("mesh cache ready after %.1f s", clock - b.started))
		else
			i = i + 1
		end
	end
end

local function onUpdate(dtReal)
	local dt = math.min(dtReal or 0, 0.1)
	clock = clock + dt
	if #pending > 0 then updatePending() end
	if not next(fakes) then return end
	for _, f in pairs(fakes) do
		f.t = f.t + dt
		move(f, dt)
		f.heightAcc = f.heightAcc - dt
		if f.heightAcc <= 0 then
			f.heightAcc = HEIGHT_REFRESH
			f.groundZ = groundZ(f.pos.x, f.pos.y, f.refZ)
		end
		f.pos.z = (f.groundZ or f.refZ) + 0.6
		f.sendAcc = f.sendAcc - dt
		if f.sendAcc <= 0 then
			f.sendAcc = f.sendAcc + 1 / f.opts.rate
			if math.random() >= f.opts.loss then
				local json = makePacket(f)
				if f.opts.jitter > 0 then
					table.insert(inFlight, { due = clock + math.random() * f.opts.jitter / 1000, sid = f.sid, json = json })
				else
					deliver(f.sid, json)
				end
			end
		end
	end
	local i = 1
	while i <= #inFlight do
		local p = inFlight[i]
		if p.due <= clock then
			deliver(p.sid, p.json)
			inFlight[i] = inFlight[#inFlight]
			inFlight[#inFlight] = nil
		else
			i = i + 1
		end
	end
end

local function onClientEndMission()
	if next(fakes) then clear() end
end

M.spawn = spawn
M.clear = clear
M.status = status
M.perf = perf
M.isActive = isActive
M.chatCommand = chatCommand
M.onUpdate = onUpdate
M.onClientEndMission = onClientEndMission
M.onInit = function() setExtensionUnloadMode(M, "manual") end

return M
