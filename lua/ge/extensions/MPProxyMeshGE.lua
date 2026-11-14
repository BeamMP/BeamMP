-- Copyright (C) 2026 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- MPProxyMeshGE API - real body meshes for proxy vehicles (see MPProxyGE).
-- A TSStatic renders every mesh of its shape file and has no per mesh visibility (engine fields: shapeName, skin,
-- dynamic, meshCulling, useInstanceRenderData, instanceColor0-2, forceDetail ...), and vehicle .dae files contain
-- every part variant of the model, without LODs. So per model + config we build a small filtered .dae:
--   1. part -> flexbody mesh index of the model (jbeam files of /vehicles/<model>/ only, one file per step)
--   2. wanted meshes = flexbodies of the parts in the config, minus interior/small/mechanical parts,
--      minus anything from /vehicles/common (wheels and tires are drawn as cylinders instead)
--   3. the model's .dae files are streamed in chunks and only the wanted <geometry>/<node> blocks are kept
--   4. per LOD tier the kept meshes are written to /temp/beammp/proxymeshes/ as shared pieces (one file per source
--      .dae + jbeam part with enough geometry, the small rest in one file), named by their content, so configs and
--      tiers with the same meshes share files (also across sessions); a proxy draws one TSStatic per piece.
--      Vehicle meshes are modelled in place in vehicle space, so no transforms are needed.
-- All of that runs in a coroutine with a per frame time budget. The only blocking step left is the engine
-- importing a generated shape on its first use, which is rate limited (one new file per interval).
-- Until a shape is ready the proxy stays a box.
-- @module MPProxyMeshGE

local M = {}

local D = require("beammp.proxy.dae")       -- .dae streaming, filtering, merging (pure, budget checks via setBudgetCheck)
local J = require("beammp.proxy.jbeamText")  -- jbeam text scanning and value expressions (pure)
local MM = require("beammp.proxy.matMerge")  -- one mesh per material in each body piece (fewer draw calls)

setmetatable(_G,{}) -- temporarily disable global notifications

local TIMER = (HighPerfTimer or hptimer)
local CACHE_DIR = "/temp/beammp/proxymeshes/"
local CACHE_VERSION = "v6" -- v6: shared pieces per (source .dae, jbeam part) instead of one file per mesh set and tier; v5: three LOD tier mesh sets per config, v4: triangle budget (smallest parts dropped), v3: one merged .dae per mesh set, signatures
local FRAME_BUDGET_MS = 2         -- coroutine work per frame in game (proxyMeshFrameBudgetMs)
local PRELOAD_BUDGET_MS = 40      -- while the join loading screen hides the stutter
local frameBudget = FRAME_BUDGET_MS
local MAX_NEW_OBJECTS_PER_PASS = 4
local SUSP_MAX_PROXIES = 8       -- nearest proxies with visual suspension (proxySuspension)
local MAX_DETACHES_PER_PASS = 6   -- mesh -> box changes per pass, farthest first, so a group leaving range spreads out
local NEW_SHAPE_INTERVAL = 2      -- seconds between first uses of not yet loaded shapes (engine import hitch)
local CACHED_SHAPE_INTERVAL = 0.5 -- same, when the engine already has a compiled .cdae of every file (cheaper load)

local cfg = { enabled = true, distance = 500, maxProxies = 48, wheels = true, targetFps = 0, triBudget = 60000, prebuild = false,
	lodFull = 20, lodParts = 60, lodShell = 150, frameBudget = FRAME_BUDGET_MS }

-- ============= LOD TIERS =============
-- Every config is built into three mesh sets: 1 = full (every mesh of the config), 2 = parts (interior, mechanical
-- and small trim left out, within the triangle budget), 3 = shell (only the biggest body panels). Further out
-- MPProxyGE draws a low poly car shape and, at the far end, a box in the paint colour.
local TIER_FULL, TIER_PARTS, TIER_SHELL = 1, 2, 3
local MIN_FAR_PART = 0.12 -- m, largest bounds dimension a part needs to be kept in the parts and shell tiers
local LOD_HYSTERESIS = 0.1 -- a tier boundary is moved out by this fraction (plus 3 m) for proxies already inside

local function readSettings()
	cfg.enabled = settings.getValue("proxyMeshEnabled", true) ~= false
	cfg.distance = tonumber(settings.getValue("proxyMeshDistance", 500)) or 500
	cfg.maxProxies = math.max(0, math.floor(tonumber(settings.getValue("proxyMaxMeshProxies", 48)) or 48))
	cfg.wheels = settings.getValue("proxyMeshWheels", true) ~= false
	cfg.realWheels = settings.getValue("proxyMeshRealWheels", true) ~= false
	cfg.wheelDetails = settings.getValue("proxyWheelDetails", false) == true
	cfg.liveries = settings.getValue("proxyLiveries", true) ~= false
	cfg.comRide = settings.getValue("proxyComRideHeight", true) ~= false
	cfg.metallicPaint = settings.getValue("proxyMetallicPaint", true) ~= false
	cfg.skipStatic = settings.getValue("proxySkipStaticUpdates", true) ~= false
	cfg.suspension = settings.getValue("proxySuspension", false) == true
	cfg.suspDist = math.max(0, tonumber(settings.getValue("proxySuspensionDistance", 40)) or 40)
	cfg.realWheelsMax = math.max(0, math.floor(tonumber(settings.getValue("proxyMeshRealWheelsMax", 12)) or 12))
	cfg.targetFps = math.max(0, tonumber(settings.getValue("proxyTargetFps", 0)) or 0)
	cfg.triBudget = math.max(0, math.floor(tonumber(settings.getValue("proxyMeshTriangleBudget", 60000)) or 60000))
	cfg.prebuild = settings.getValue("proxyPrebuildModels", false) == true
	cfg.lodFull = math.max(0, tonumber(settings.getValue("proxyLodFullDistance", 20)) or 20)
	cfg.lodParts = math.max(cfg.lodFull, tonumber(settings.getValue("proxyLodPartsDistance", 60)) or 60)
	cfg.lodShell = math.max(cfg.lodParts, tonumber(settings.getValue("proxyLodShellDistance", 150)) or 150)
	cfg.frameBudget = math.min(math.max(tonumber(settings.getValue("proxyMeshFrameBudgetMs", FRAME_BUDGET_MS)) or FRAME_BUDGET_MS, 0.25), 20)
end

-- the mesh tier for a distance, nil beyond the mesh tiers; cur is the tier the proxy has now (hysteresis)
local function tierForDistance(d, cur)
	local bounds = { cfg.lodFull, cfg.lodParts, math.min(cfg.lodShell, cfg.distance) }
	for t = 1, 3 do
		local b = bounds[t]
		if cur and cur <= t then b = b * (1 + LOD_HYSTERESIS) + 3 end
		if d < b then return t end
	end
	return nil
end

-- ============= FRAME RATE TARGET =============
-- With proxyTargetFps set, the number of proxies drawn with meshes is lowered while the frame rate is under the
-- target and raised again when there is headroom. If several reductions in a row did not make frames faster,
-- the meshes are not what limits the frame rate: the old count comes back and we wait before trying again.
local FPS_WINDOW = 0.5
local fps = { sum = 0, frames = 0, cap = math.huge, reductions = 0, baseMs = 0, restore = math.huge, holdUntil = 0, inRange = 0 }

local function updateFpsCap(dtReal, now)
	if cfg.targetFps <= 0 then fps.cap = math.huge return end
	fps.sum, fps.frames = fps.sum + dtReal, fps.frames + 1
	if fps.sum < FPS_WINDOW then return end
	local ms = fps.sum / fps.frames * 1000
	fps.sum, fps.frames = 0, 0
	local target = 1000 / cfg.targetFps
	local current = math.min(fps.cap, fps.inRange)
	if ms > target * 1.05 then
		if now < fps.holdUntil or current <= 4 then fps.reductions = 0 return end
		if fps.reductions == 0 then fps.restore, fps.baseMs = fps.cap, ms end
		fps.reductions = fps.reductions + 1
		if fps.reductions > 3 and ms > fps.baseMs * 0.97 then -- did not help
			fps.cap, fps.holdUntil, fps.reductions = fps.restore, now + 15, 0
			return
		end
		fps.cap = math.max(4, math.floor(current * 0.85))
	else
		fps.reductions = 0
		if ms < target * 0.9 and fps.cap ~= math.huge then
			fps.cap = math.ceil(fps.cap * 1.1) + 1
			if fps.cap >= fps.inRange then fps.cap = math.huge end
		end
	end
end

-- mesh names containing any of these are skipped (interior, mechanical, small or hidden parts)
local SKIP = {
	"_int", "interior", "dash", "gauge", "needle", "pedal", "seat", "steer", "shifter", "handbrake", "switch",
	"engine", "header", "intake", "radhose", "radiator", "exhaust", "muffler", "heatshield", "subframe", "suspension",
	"strut", "coilover", "spring", "shock", "brake", "rotor", "caliper", "hub", "axle", "driveshaft", "halfshaft",
	"diff", "transmission", "gearbox", "transfercase", "battery", "rollcage", "cage", "belt", "pulley", "fan",
	"alternator", "turbo", "supercharger", "intercooler", "fuel", "tank", "pipe", "hose", "wire", "bolt", "screw",
	"mount", "bracket", "carpet", "headliner", "doorpanel", "crap", "skidplate", "underbody", "tie", "lowerarm",
	"upperarm", "controlarm", "leaf", "linkage", "rack", "pump", "filter", "airbox", "wiper", "antenna", "decal",
	"license", "plate", "badge", "emblem", "mudflap", "net", "speaker", "radio", "cluster", "glovebox", "console",
}

local function isWantedMesh(name)
	local n = string.lower(name)
	for i = 1, #SKIP do
		if string.find(n, SKIP[i], 1, true) then return false end
	end
	return true
end

-- ============= STATE =============
local partIndex = {}      -- [model] = { [partName] = {meshName, ...} } | "building"
local shapes = {}         -- [key] = { state = "queued"|"building"|"ready"|"failed", paths = {}, bbox = {}, loaded = false }
local materialsLoaded = {} -- [model] = true
local jobs = {}           -- FIFO of { key, model, parts }
local currentJob = nil
local fallbackOf = {}     -- [config key] = key of the model's default config (shown while the config builds)
local defaultKeys = {}    -- [model] = key | false
local prebuildJobs = {}   -- background builds of default configs (proxyPrebuildModels), only when jobs is empty
-- prebuild progress: compile = paths to import once (.dae -> .cdae), counts for the summary, overlay text state
local pb = { started = false, compile = {}, queued = 0, built = 0, compiled = 0, skipped = 0, done = 0, summary = false,
	current = nil, verb = nil, showUntil = 0 }
local cdaeCache = {} -- [dae path] = true/false: compiled .cdae seen on disk
local importedPaths = {}  -- [dae path] = true once a TSStatic used it this session (engine keeps the shape loaded)
local waitingLoad = {}    -- models with a ready shape waiting for the first-use interval (overlay)
local clock = 0
local nextNewShapeAllowed = 0

local pools = {}          -- [path] = { objectID, ... } free TSStatics
local liveCount = 0
local allObjects = {}  -- [objectID] = true, every TSStatic we created

local function hashString(s)
	if hashStringSHA256 then return string.sub(hashStringSHA256(s), 1, 16) end
	local h = 5381
	for i = 1, #s do h = (h * 33 + string.byte(s, i)) % 4294967296 end
	return string.format("%08x%d", h, #s)
end

-- shared mesh pieces: minBytes = geometry a jbeam part needs for a file of its own (smaller ones share a rest file),
-- info[model] = mesh facts (loadMeshInfo), owner[model] = { [mesh] = jbeam part }, used = { [path] = os.time() of
-- the last session that imported it } for the cache size cap
local PC = { minBytes = 512 * 1024, info = {}, owner = {}, used = nil, usedDirty = false }

local budgetTimer = nil
local jobPhase = "start" -- what the running job does now, for the per step timings in the job log
local function setPhase(name) jobPhase = name end
local function checkBudget()
	if budgetTimer and budgetTimer:stop() > frameBudget then coroutine.yield() end
end
D.setBudgetCheck(checkBudget)
MM.setBudgetCheck(checkBudget)
J.setBudgetCheck(checkBudget)

-- ============= BUILD STEPS (inside the coroutine) =============

-- ============= CACHE VALIDATION =============
-- game version + count and total size of the model's jbeam/dae/json files (works for zips and mods alike)
local modelSigs = {}
local function modelSignature(model)
	if modelSigs[model] then return modelSigs[model] end
	local files = FS:findFiles("/vehicles/" .. model .. "/", "*", -1, false, false) or {}
	local n, total = 0, 0
	for i, f in ipairs(files) do
		local ext = string.match(f, "%.(%w+)$")
		if ext == "jbeam" or ext == "dae" or ext == "json" then
			local st = FS:stat(f)
			n, total = n + 1, total + (st and tonumber(st.filesize) or 0)
		end
		checkBudget()
	end
	local sig = tostring(beamng_version or "?") .. "|" .. n .. "|" .. total
	modelSigs[model] = sig
	return sig
end

local ENGINE_INDEX_VERSION = 8 -- 8: gearbox / differential ratios; 7: hub / brake disc flexbodies; 6: livery fields; part index files without this are rebuilt once (2: wheel sections, 3: wheel flexbodies, 4: no wheel meshes in the body lists, 5: node mass buckets)
local BODY_VERSION = 4 -- per config meta, mesh set meta and piece names (4: meshes merged by material; 3: parts under MIN_FAR_PART left out of the far tiers; 2: wheel / tire / brake meshes left out of the body)

local engineIndex = {} -- [model] = engine sections by part (see addEngineSections)

-- ============= WHEEL SECTIONS (compact, for the wheel placement) =============
local wheelIndex = {}         -- [model] = { [partName] = compact wheel data } (model and /vehicles/common/<model>/)
local commonWheelIndex = nil  -- same for the shared tire / wheel / hubcap folders of /vehicles/common/
local COMMON_WHEEL_DIRS = { "tires", "wheels", "wheels_square", "hubcaps" }

-- the shared tire / wheel folders, once (disk cached, rebuilt when the game version or file count changes)
local function buildCommonWheelIndex()
	local files = {}
	for _, dir in ipairs(COMMON_WHEEL_DIRS) do
		for _, f in ipairs(FS:findFiles("/vehicles/common/" .. dir .. "/", "*.jbeam", -1, false, false) or {}) do files[#files + 1] = f end
		checkBudget()
	end
	local sig = tostring(beamng_version or "?") .. "|" .. #files .. "|" .. ENGINE_INDEX_VERSION
	local diskFile = CACHE_DIR .. "common_" .. CACHE_VERSION .. "_wheels.json"
	local cached = FS:fileExists(diskFile) and jsonReadFile(diskFile) or nil
	if cached and cached.sig == sig and type(cached.parts) == "table" then return cached.parts end
	local parts, flexTexts, wheelSecs = {}, {}, {}
	for _, filename in ipairs(files) do
		local text = readFile(filename)
		checkBudget()
		if text then
			table.clear(flexTexts) table.clear(wheelSecs)
			if J.extractFlexbodies(text, flexTexts, nil, wheelSecs) then J.addWheelParts(parts, wheelSecs, filename, flexTexts) end
		end
		text = nil
		checkBudget()
	end
	FS:directoryCreate(CACHE_DIR, true)
	jsonWriteFile(diskFile, { sig = sig, parts = parts }, false)
	log('I', 'MPProxyMeshGE', string.format("Indexed wheel and tire parts of %d shared jbeam files", #files))
	return parts
end

local function buildPartIndex(model)
	local diskFile = CACHE_DIR .. model .. "_parts_" .. CACHE_VERSION .. ".json"
	local files = FS:findFiles("/vehicles/" .. model .. "/", "*.jbeam", -1, false, false) or {}
	local sig = modelSignature(model)
	local cached = FS:fileExists(diskFile) and jsonReadFile(diskFile) or nil
	if cached and cached.sig == sig and type(cached.parts) == "table" and cached.engineV == ENGINE_INDEX_VERSION then
		engineIndex[model] = type(cached.engine) == "table" and cached.engine or {}
		wheelIndex[model] = type(cached.wheels) == "table" and cached.wheels or {}
		return cached.parts
	end

	local parts = {}
	local engine = {}
	local wheels = {}
	local flexTexts, sectionTexts, wheelSecs = {}, {}, {}
	-- engines and their sound sections often live in /vehicles/common/<model>/ (only those sections are read there)
	local commonFiles = FS:findFiles("/vehicles/common/" .. model .. "/", "*.jbeam", -1, false, false) or {}
	for _, filename in ipairs(commonFiles) do
		local text = readFile(filename)
		checkBudget()
		if text then -- engine / sound sections and the hubs, suspensions and their slots
			table.clear(flexTexts) table.clear(sectionTexts) table.clear(wheelSecs)
			if J.extractFlexbodies(text, flexTexts, sectionTexts, wheelSecs) then
				J.addEngineSections(engine, sectionTexts, filename)
				J.addWheelParts(wheels, wheelSecs, filename, flexTexts)
			end
		end
		text = nil
		checkBudget()
	end
	for _, filename in ipairs(files) do
		table.clear(flexTexts)
		table.clear(sectionTexts)
		table.clear(wheelSecs)
		local data = nil
		local text = readFile(filename)
		checkBudget()
		local hasSound = text and (string.find(text, "soundConfig", 1, true) or string.find(text, "gearRatio", 1, true))
		if text then
			if J.extractFlexbodies(text, flexTexts, hasSound and sectionTexts or nil, wheelSecs) then
				J.addEngineSections(engine, sectionTexts, filename)
				J.addWheelParts(wheels, wheelSecs, filename, flexTexts)
				data = {}
				for partName, arr in pairs(flexTexts) do
					local ok, rows = pcall(jsonDecode, arr, filename)
					if ok and type(rows) == "table" then data[partName] = { flexbodies = rows } end
					checkBudget()
				end
			else
				local ok, decoded = pcall(jsonDecode, text, filename) -- unusual file: whole decode (one step)
				data = ok and decoded or nil
			end
		end
		text = nil
		if type(data) == "table" then
			for partName, part in pairs(data) do
				if type(part) == "table" and type(part.flexbodies) == "table" then
					local list, offset = {}, false
					for _, row in ipairs(part.flexbodies) do
						if type(row) == "table" then
							if row[1] ~= nil then
								local mesh = row[1]
								if type(mesh) == "string" and mesh ~= "mesh" and not offset and not J.isWheelFlexRow(row) then list[#list + 1] = mesh end
							else
								offset = J.isOffsetModifier(row) -- positioned meshes (mirrored/moved) would be misplaced
							end
						end
					end
					if #list > 0 then parts[partName] = list end
				end
			end
		end
		checkBudget()
	end
	FS:directoryCreate(CACHE_DIR, true)
	jsonWriteFile(diskFile, { sig = sig, fileCount = #files, parts = parts, engine = engine, wheels = wheels, engineV = ENGINE_INDEX_VERSION }, false)
	engineIndex[model] = engine
	wheelIndex[model] = wheels
	return parts
end

-- ============= WHEEL PLACEMENT OF A CONFIG =============
-- Follows the jbeam loader: the part tree of the config is walked in slot order (child sections come after the
-- parent's), later node definitions replace earlier ones, a slot's nodeOffset moves the nodes of its subtree
-- (x away from the center line: posX + sign(posX) * x, lua/common/jbeam/utils.lua), pressureWheels options apply
-- to the wheel rows after them, and each wheel is placed like lua/common/jbeam/sections/wheelTypes/pressureWheels.lua:
-- midpoint of node1/node2 (or offsetFromNode), moved by wheelOffset along the axis, tireWidth wide, radius.
local WHEEL_VERSION = 6 -- 6: every skin slot; 5: livery (skin) name; 4: 4: centre of mass estimate; 3: tire flag per mesh; 2: named fields (mixed tables did not survive the json round trip), rim / tire meshes

local function resolveWheels(job)
	local vcf = job.vcf
	if type(vcf) ~= "table" or type(vcf.parts) ~= "table" then return nil, "no config data" end
	if commonWheelIndex == nil then
		setPhase("wheel index")
		commonWheelIndex = buildCommonWheelIndex()
	end
	setPhase("wheels")
	local idx, cidx = wheelIndex[job.model] or {}, commonWheelIndex or {}
	local function get(name) return idx[name] or cidx[name] end
	local vars = {}
	for _, partName in ipairs(job.parts) do
		local d = get(partName)
		if d and d.vars then for k, v in pairs(d.vars) do vars[k] = v end end
	end
	if type(vcf.vars) == "table" then for k, v in pairs(vcf.vars) do vars[k] = v end end
	local nodes, items, visited, flex, mass = {}, {}, {}, {}, {}
	local function visit(name, off, path, depth)
		if depth > 30 or visited[name] then return end
		visited[name] = true
		local d = get(name)
		if not d then return end
		if d.nodes then
			local cur = off
			for _, r in ipairs(d.nodes) do
				if r.off ~= nil then cur = r.off or off
				else nodes[r[1]] = { r[2], r[3], r[4], cur } end
			end
		end
		if d.skin then
			-- same rule as lua/common/jbeam/sections/licenseplatesSkins.lua: a skin_* or paint_design slot part sets
			-- the vehicle skin "<skinType or slotType>.<skinName or globalSkin>", paint_design maps to ""
			local st = d.skin.slotType or ""
			if string.find(st, "skin_", 1, true) or st == "paint_design" then
				local slot = (d.skin.skinType and d.skin.skinType ~= "") and d.skin.skinType or st
				if slot == "paint_design" then slot = "" end
				local nm = d.skin.skinName or d.skin.globalSkin
				if nm and nm ~= "" and string.sub(nm, 1, 1) ~= "$" then -- several skin slots: "a.x;b.y"
					job.skin = (job.skin and (job.skin .. ";") or "") .. slot .. "." .. nm
				end
			end
		end
		if d.mass then for _, g in ipairs(d.mass) do mass[#mass + 1] = { g, off } end end
		if d.pw then for _, it in ipairs(d.pw) do items[#items + 1] = it end end
		if d.fb then for _, fb in ipairs(d.fb) do flex[#flex + 1] = { fb, off } end end
		if d.slots then
			for _, sl in ipairs(d.slots) do
				local p = path .. sl.n .. "/"
				local child = vcf.parts[p] or vcf.parts[sl.n] or vcf.parts[sl.t]
				if type(child) == "string" and child ~= "" then visit(child, sl.o or off, p, depth + 1) end
			end
		end
		checkBudget()
	end
	visit(vcf.mainPartName or job.model, nil, "/", 0)
	local function moved(x, y, z, o)
		if o then
			local ox, oy, oz = J.evalVal(o[1], vars) or 0, J.evalVal(o[2], vars) or 0, J.evalVal(o[3], vars) or 0
			x = x + (x > 0 and 1 or (x < 0 and -1 or 0)) * ox
			y, z = y + oy, z + oz
		end
		return x, y, z
	end
	local function nodePos(name)
		local n = nodes[name]
		if not n then return nil end
		local x, y, z = J.evalVal(n[1], vars), J.evalVal(n[2], vars), J.evalVal(n[3], vars)
		if not (x and y and z) then return nil end
		return moved(x, y, z, n[4])
	end
	local opts, wheels, wheelAt = {}, {}, {}
	for _, it in ipairs(items) do
		if it.o then for k, v in pairs(it.o) do opts[k] = v end
		elseif it.w then
			local x1, y1, z1 = nodePos(it.a)
			local x2, y2, z2 = nodePos(it.b)
			if x1 and x2 then
				local ax, ay, az = x2 - x1, y2 - y1, z2 - z1
				local len = math.sqrt(ax * ax + ay * ay + az * az)
				if len > 1e-4 then
					ax, ay, az = ax / len, ay / len, az / len
					local hubWidth = J.evalVal(opts.hubWidth, vars) or len
					local mx, my, mz = (x1 + x2) * 0.5, (y1 + y2) * 0.5, (z1 + z2) * 0.5
					local ofn = J.evalVal(opts.offsetFromNode, vars)
					if ofn == 1 then mx, my, mz = x1 + ax * hubWidth * 0.5, y1 + ay * hubWidth * 0.5, z1 + az * hubWidth * 0.5
					elseif ofn == 2 then mx, my, mz = x2 - ax * hubWidth * 0.5, y2 - ay * hubWidth * 0.5, z2 - az * hubWidth * 0.5 end
					local wo = J.evalVal(opts.wheelOffset, vars)
					if wo then mx, my, mz = mx + ax * wo, my + ay * wo, mz + az * wo end
					local radius = J.evalVal(opts.radius, vars) or J.evalVal(opts.hubRadius, vars) or 0.5
					local width = J.evalVal(opts.tireWidth, vars) or hubWidth
					-- steered: rows with a steering axis, else the front wheels by name (FR, FL, F2R...)
					local steered = it.s or (type(it.w) == "string" and string.sub(it.w, 1, 1) == "F")
					local at = wheelAt[it.w] or (#wheels + 1) -- a later row of the same wheel replaces it (like the loader)
					wheelAt[it.w] = at
					wheels[at] = { x = mx, y = my, z = mz, ax = ax, ay = ay, az = az, r = radius, wd = width, s = steered or nil, n = it.w }
				end
			end
		end
	end
	-- centre of mass from the node weights (offsets like the loader: x away from the centre line), plus the wheels
	local mw, mx, my, mz = 0, 0, 0, 0
	for _, it in ipairs(mass) do
		local g, off = it[1], it[2]
		local o = off
		if g.mod then o = g.o or off end
		local ox, oy, oz = 0, 0, 0
		if type(o) == "table" then ox, oy, oz = J.evalVal(o[1], vars) or 0, J.evalVal(o[2], vars) or 0, J.evalVal(o[3], vars) or 0 end
		mw = mw + g.w
		mx, my, mz = mx + g.x + ox * (g.p - g.n), my + g.y + oy * g.w, mz + g.z + oz * g.w
	end
	for _, w in ipairs(wheels) do
		mw, mx, my, mz = mw + J.MASS.wheel, mx + J.MASS.wheel * w.x, my + J.MASS.wheel * w.y, mz + J.MASS.wheel * w.z
	end
	job.com = mw > 0 and { mx / mw, my / mw, mz / mw, mw } or nil
	if job.com then
		if job.skin then log('I', 'MPProxyMeshGE', string.format("Proxy livery for %s: skin %s", tostring(job.model), job.skin)) end
		log('I', 'MPProxyMeshGE', string.format("Proxy centre of mass for %s: %.2f %.2f %.2f m, %.0f kg node mass", tostring(job.model), job.com[1], job.com[2], job.com[3], mw))
	end
	-- rim / tire / hubcap meshes: flexbody pos moved like the part's nodes (same slot nodeOffset), stored relative
	-- to the wheel center, so a wheel object turns and rolls around its own origin
	local byName = {}
	for _, w in ipairs(wheels) do if type(w.n) == "string" then byName[w.n] = w end end
	for _, it in ipairs(flex) do
		local fb, off = it[1], it[2]
		local w = nil
		for _, side in ipairs(fb.w or {}) do w = w or byName[side] end
		local p = fb.p
		local lm = type(fb.m) == "string" and string.lower(fb.m) or ""
		-- calipers do not turn with the wheel, never; brake discs / hubs only with the wheel details setting
		local hidden = string.find(lm, "caliper", 1, true)
			or (not cfg.wheelDetails and (fb.d or string.find(lm, "brake", 1, true) or string.find(lm, "disc", 1, true)))
		if w and type(fb.m) == "string" and p and not hidden then -- brake parts sit behind the rim
			local x, y, z = J.evalVal(p[1], vars), J.evalVal(p[2], vars), J.evalVal(p[3], vars)
			if x and y and z then
				x, y, z = moved(x, y, z, off)
				local r, sc = fb.r or {}, fb.s or {}
				w.m = w.m or {}
				local dup = false
				for _, e in ipairs(w.m) do if e[1] == fb.m then dup = true end end
				if not dup and #w.m < 6 then -- meshes per wheel
					w.m[#w.m + 1] = { fb.m, x - w.x, y - w.y, z - w.z, J.evalVal(r[1], vars) or 0, J.evalVal(r[2], vars) or 0, J.evalVal(r[3], vars) or 0,
						J.evalVal(sc[1], vars) or 1, J.evalVal(sc[2], vars) or 1, J.evalVal(sc[3], vars) or 1, fb.t and 1 or 0 }
				end
			end
		end
	end
	return wheels
end

-- keeps the wheels that make sense next to the body bounds; nil if none left
local function checkWheels(wheels, shape)
	if type(wheels) ~= "table" then return nil end
	local out = {}
	for _, w in ipairs(wheels) do
		local ok = w.r >= 0.1 and w.r <= 1.6 and w.wd >= 0.04 and w.wd <= 1.5
		if ok and shape.minX then
			ok = w.x > shape.minX - 1 and w.x < shape.maxX + 1 and w.y > shape.minY - 1 and w.y < shape.maxY + 1
				and w.z > shape.minZ - 1 and w.z < shape.maxZ + 1
		end
		if ok then out[#out + 1] = w end
	end
	return #out > 0 and out or nil
end

local function logWheels(job, wheels, note)
	if wheels then
		local rmin, rmax, wmin, wmax, meshes, names = math.huge, 0, math.huge, 0, 0, {}
		for _, w in ipairs(wheels) do
			rmin, rmax = math.min(rmin, w.r), math.max(rmax, w.r)
			wmin, wmax = math.min(wmin, w.wd), math.max(wmax, w.wd)
			for _, e in ipairs(w.m or {}) do meshes = meshes + 1 if not names[e[1]] then names[e[1]] = true names[#names + 1] = e[1] end end
		end
		log('I', 'MPProxyMeshGE', string.format("Proxy wheels for %s/%s: %d wheels, radius %.2f-%.2f m, width %.2f-%.2f m, %d rim/tire meshes (%s) (source: jbeam%s)",
			job.model, string.sub(job.key, -16), #wheels, rmin, rmax, wmin, wmax, meshes, table.concat(names, ", ", 1, math.min(#names, 6)), note or ""))
	else
		log('I', 'MPProxyMeshGE', string.format("Proxy wheels for %s/%s: estimated from the body bounds (source: estimate, %s)",
			job.model, string.sub(job.key, -16), note or "no wheel rows resolved"))
	end
end

-- ============= ENGINE SOUND OF A CONFIG =============
-- Same lookup as combustionEngine.lua init: the mainEngine device names its sound sections (soundConfig = intake,
-- soundConfigExhaust = exhaust), a section gives sampleFolder (default art/sound/blends/) .. sampleName ..
-- ".sfxBlend2D.json", whose eventName is the FMOD event. The exhaust is used when it resolves, else the intake.
local function blendEvent(folder, name)
	if type(name) ~= "string" then return nil end
	folder = folder or "art/sound/blends/"
	if string.sub(folder, 1, 1) ~= "/" then folder = "/" .. folder end
	local base = folder .. name .. ".sfxBlend"
	local data = jsonReadFile(base .. "2D.json") or jsonReadFile(base .. "2d.json")
	local ev = type(data) == "table" and data.eventName
	return type(ev) == "string" and ev ~= "" and ev or nil
end

-- gearing of a config for the proxy engine rpm (MPProxyGE.estimateRpm): forward ratios, reverse, final drive
-- (largest differential ratio of the config, a transfer case low range is ignored) and the median wheel radius.
-- sound.gear stays nil when anything is missing (electric drive, no wheels...), the rpm then uses the generic model.
local GEAR_VERSION = 1
local function addGearing(job, sound, wheels)
	sound.gearV = GEAR_VERSION
	sound.gear = nil
	local index = engineIndex[job.model] or {}
	local vars = {}
	local widx = wheelIndex[job.model] or {}
	for _, partName in ipairs(job.parts) do
		local d = widx[partName] or (commonWheelIndex and commonWheelIndex[partName])
		if d and d.vars then for k, v in pairs(d.vars) do vars[k] = v end end
	end
	if type(job.vcf) == "table" and type(job.vcf.vars) == "table" then for k, v in pairs(job.vcf.vars) do vars[k] = v end end
	local ratios, final = nil, 0
	for _, partName in ipairs(job.parts) do
		local e = index[partName]
		if e then
			for key, sec in pairs(e) do
				if key == "gearbox" and sec.gearRatios then ratios = sec.gearRatios
				elseif string.sub(key, 1, 12) == "differential" and sec.gearRatio then
					local r = J.evalVal(sec.gearRatio, vars)
					if r and r > final then final = r end
				end
			end
		end
	end
	local radii = {}
	for _, w in ipairs(type(wheels) == "table" and wheels or {}) do if tonumber(w.r) and w.r > 0.1 then radii[#radii + 1] = w.r end end
	table.sort(radii)
	local rad = radii[math.max(1, math.ceil(#radii / 2))]
	if not ratios or final <= 0 or not rad then return end
	-- gearRatios: { reverse, 0 (neutral), first, second, ... } like the game's gearboxes
	local fwd, rev = {}, nil
	for i, v in ipairs(ratios) do
		local r = J.evalVal(v, vars)
		if not r then return end
		if r < 0 then rev = rev or -r elseif r > 0 and i > 1 then fwd[#fwd + 1] = r end
	end
	if #fwd == 0 then return end
	sound.gear = { f = fwd, r = rev or fwd[1], fd = final, rad = rad }
	log('I', 'MPProxyMeshGE', string.format("Proxy gearing for %s/%s: %d gears %s, final drive %.2f, wheel radius %.2f m", job.model, string.sub(job.key, -16),
		#fwd, table.concat(fwd, "/"), final, rad))
end

local function resolveSound(job, cachedNote)
	if type(partIndex[job.model]) ~= "table" then
		setPhase("part index")
		partIndex[job.model] = buildPartIndex(job.model)
	end
	setPhase("engine sound")
	local index = engineIndex[job.model] or {}
	local me, sections = {}, {}
	for _, partName in ipairs(job.parts) do
		local e = index[partName]
		if e then
			for key, sec in pairs(e) do
				if key == "mainEngine" then for k, v in pairs(sec) do me[k] = v end
				else sections[key] = sections[key] or {} for k, v in pairs(sec) do sections[key][k] = v end end
			end
		end
	end
	local sound = { source = "fallback" }
	for _, which in ipairs({ { "soundConfigExhaust", "exhaust" }, { "soundConfig", "intake" } }) do
		local sec = sections[me[which[1]] or ""]
		local ev = sec and blendEvent(sec.sampleFolder, sec.sampleName)
		if ev then
			sound = { source = "jbeam", event = ev, kind = which[2], sample = sec.sampleName,
				mainGain = sec.mainGain, onLoadGain = sec.onLoadGain, offLoadGain = sec.offLoadGain,
				muffling = which[2] == "exhaust" and sec.exhaustAudioMufflingBaseCoef or sec.intakeMuffling }
			break
		end
	end
	sound.idleRPM, sound.maxRPM = tonumber(me.idleRPM), tonumber(me.revLimiterRPM) or tonumber(me.maxRPM)
	sound.diesel = me.requiredEnergyType == "diesel" or nil
	log('I', 'MPProxyMeshGE', string.format("Proxy engine sound for %s/%s: %s (source: %s%s%s)", job.model, string.sub(job.key, -16),
		sound.event or "type mapping", sound.source, sound.sample and (", " .. sound.kind .. " " .. sound.sample) or "", cachedNote or ""))
	return sound
end

local function loadModelMaterials(model)
	if materialsLoaded[model] then return end
	local files = FS:findFiles("/vehicles/" .. model .. "/", "*materials.json", -1, true, false) or {}
	for _, filename in ipairs(files) do
		loadJsonMaterialsFile(filename) -- same as core_vehicle_manager.loadVehicleMaterialsDirectory
		coroutine.yield()
	end
	materialsLoaded[model] = true
end

-- ============= MERGING =============

local function finishBBox(shape, bbox, model)
	shape.minX = nil
	if not D.validBBox(bbox) then
		if bbox and bbox[1] and bbox[1] <= (bbox[4] or -math.huge) then
			log('W', 'MPProxyMeshGE', string.format("Ignoring implausible mesh bounds for %s: %s", tostring(model), table.concat(bbox, ", ")))
		end
		return
	end
	shape.minX, shape.minY, shape.minZ, shape.maxX, shape.maxY, shape.maxZ = bbox[1], bbox[2], bbox[3], bbox[4], bbox[5], bbox[6]
	-- jbeam vehicles stand on z = 0, use the mesh bottom only if that does not look like it
	shape.groundZ = (bbox[3] > -0.3 and bbox[3] < 0.7) and 0 or bbox[3]
end

-- ============= REAL WHEEL MESHES =============
-- Each wheel of a config (rim, tire, hubcap flexbodies from resolveWheels) becomes a small .dae of its own: the
-- meshes are copied from the shared /vehicles/common/ (or the model's) .dae files with the jbeam flexbody
-- transform baked into their node matrix, relative to the wheel center. Wheels with the same meshes and
-- transform share the file (left and right differ by the flexbody rotation), so the engine imports each once.
-- They are built after the body meshes, when no body job waits.
local wheelFiles = {}     -- [wheel .dae path] = "queued" | "ready" | "failed"
local wheelJobs = {}      -- FIFO of wheel mesh builds
local wheelInfo = {}      -- [wheel .dae path] = { tire = bool, rim = bool } (what the file has, sidecar .json)
local meshIndexes = {}    -- ["common"] / [model] = { [scene node name] = source .dae } (disk cached)
-- wheel files are named with this: v2 = found through the scene node index (v1 guessed files by name and missed many)

local function wheelPath(w)
	if w.path ~= nil then return w.path end
	if type(w.m) ~= "table" or #w.m == 0 then w.path = false return false end
	local list = {}
	for _, e in ipairs(w.m) do
		list[#list + 1] = string.format("%s|%.3f|%.3f|%.3f|%.1f|%.1f|%.1f|%.3f|%.3f|%.3f", tostring(e[1]), e[2], e[3], e[4], e[5], e[6], e[7], e[8], e[9], e[10])
	end
	table.sort(list)
	w.path = CACHE_DIR .. "wheel2_" .. CACHE_VERSION .. "_" .. hashString(table.concat(list, ";")) .. ".dae"
	return w.path
end

local function queueWheelMeshes(shape, model)
	if not cfg.realWheels or type(shape.wheels) ~= "table" then return end
	for _, w in ipairs(shape.wheels) do
		local path = wheelPath(w)
		if path and wheelFiles[path] == nil then
			local info = FS:fileExists(path) and jsonReadFile((string.gsub(path, "%.dae$", ".json"))) or nil
			if type(info) == "table" then wheelFiles[path] = "ready" wheelInfo[path] = info
			else
				wheelFiles[path] = "queued"
				wheelJobs[#wheelJobs + 1] = { wheelJob = true, key = path, model = model, m = w.m }
			end
		end
	end
end

-- [scene node name] = .dae for the shared wheel / tire / hubcap folders ("common") or one model's folders
local function meshIndex(which)
	local idx = meshIndexes[which]
	if idx then return idx end
	local dirs = which == "common" and { "/vehicles/common/wheels/", "/vehicles/common/tires/", "/vehicles/common/hubcaps/", "/vehicles/common/wheels_square/" }
		or { "/vehicles/common/" .. which .. "/", "/vehicles/" .. which .. "/" }
	local files = {}
	for _, d in ipairs(dirs) do
		for _, fl in ipairs(FS:findFiles(d, "*.dae", -1, false, false) or {}) do files[#files + 1] = fl end
		checkBudget()
	end
	table.sort(files)
	local sig = tostring(beamng_version or "?") .. "|" .. #files .. "|" .. (which ~= "common" and modelSignature(which) or "")
	local diskFile = CACHE_DIR .. "meshindex_" .. CACHE_VERSION .. "_" .. which .. ".json"
	local cached = FS:fileExists(diskFile) and jsonReadFile(diskFile) or nil
	if type(cached) == "table" and cached.sig == sig and type(cached.names) == "table" then
		meshIndexes[which] = cached.names
		return cached.names
	end
	setPhase("mesh index")
	local t0 = os.clock()
	idx = {}
	for _, fl in ipairs(files) do D.sceneNodeNames(fl, idx) end
	local count = 0
	for _ in pairs(idx) do count = count + 1 end
	FS:directoryCreate(CACHE_DIR, true)
	jsonWriteFile(diskFile, { sig = sig, names = idx }, false)
	log('I', 'MPProxyMeshGE', string.format("Indexed %d scene nodes in %d .dae files (%s)", count, #files, which))
	meshIndexes[which] = idx
	return idx
end

local function loadMaterialsNear(file)
	local dir = string.match(file, "^(.*/)") or "/"
	if materialsLoaded["dir:" .. dir] then return end
	materialsLoaded["dir:" .. dir] = true
	for _, mf in ipairs(FS:findFiles(dir, "*materials.json", 0, true, false) or {}) do
		loadJsonMaterialsFile(mf)
		coroutine.yield()
	end
end

local function runWheelJob(job)
	setPhase("wheel meshes")
	local need = {}
	for _, e in ipairs(job.m) do need[e[1]] = true end
	-- the model's own folders first (model specific hubs / wheels), then the shared ones
	local own, common = meshIndex(job.model), meshIndex("common")
	setPhase("wheel meshes")
	local byFile, missing = {}, {}
	for name in pairs(need) do
		local fl = own[name] or common[name]
		if fl then byFile[fl] = byFile[fl] or {} byFile[fl][name] = true else missing[#missing + 1] = name end
	end
	local found = {}
	for fl, names in pairs(byFile) do
		local part = D.filterDae(fl, names, {math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge}, nil)
		coroutine.yield()
		if part then
			for _, n in ipairs(part.nodes) do
				if need[n.name] and not found[n.name] then found[n.name] = { part = part, node = n, file = fl } end
			end
		end
		for name in pairs(names) do
			if not found[name] then missing[#missing + 1] = name .. " (nested or unusable in " .. (string.match(fl, "([^/]+)$") or fl) .. ")" end
		end
	end
	local groups, order, sig0, mats, used, names = {}, {}, nil, {}, 0, {}
	local hasTire, hasRim = false, false
	for _, e in ipairs(job.m) do
		local fnd = found[e[1]]
		local part = fnd and fnd.part
		local gsig = part and D.daeSignature(part.header)
		local up = part and (string.match(part.header, "<up_axis>(.-)</up_axis>") or "Z_UP")
		local unit = part and tonumber(string.match(part.header, '<unit[^>]-meter="([^"]+)"') or "1") or 1
		if unit <= 0 then unit = 1 end
		sig0 = sig0 or gsig
		local baked = part and up == "Z_UP" and gsig == sig0 and D.bakeNode(fnd.node.block, e, unit)
		if baked then
			local g = groups[part]
			if not g then g = { header = part.header, nodes = {}, geoms = {}, used = {}, file = fnd.file } groups[part] = g order[#order + 1] = g end
			g.nodes[#g.nodes + 1] = baked
			D.collectMaterials(baked, mats)
			local url = fnd.node.url
			if not g.used[url] and part.geomById[url] then g.used[url] = true g.geoms[#g.geoms + 1] = part.geomById[url] end
			used = used + 1
			names[#names + 1] = e[1]
			if e[11] == 1 then hasTire = true else hasRim = true end
		end
	end
	if used == 0 then
		wheelFiles[job.key] = "failed"
		log('W', 'MPProxyMeshGE', string.format("Proxy wheel mesh for %s: none of %d meshes found or usable (missing: %s), drawn wheels stay", job.model, #job.m, table.concat(missing, ", ")))
		return
	end
	setPhase("wheel merge")
	FS:directoryCreate(CACHE_DIR, true)
	local text = D.mergeDae(order)
	coroutine.yield()
	if not D.writePieces(job.key, text) then wheelFiles[job.key] = "failed" return end
	text = nil
	setPhase("materials")
	for _, g in ipairs(order) do loadMaterialsNear(g.file) end
	local matList = {}
	for name in pairs(mats) do matList[#matList + 1] = name end
	D.ensureMaterials(matList)
	table.sort(matList)
	wheelInfo[job.key] = { tire = hasTire, rim = hasRim, mats = matList }
	jsonWriteFile((string.gsub(job.key, "%.dae$", ".json")), wheelInfo[job.key], false)
	wheelFiles[job.key] = "ready"
	log(#missing > 0 and 'W' or 'I', 'MPProxyMeshGE', string.format("Proxy wheel mesh %s for %s: %d of %d meshes (%s) from %d files, tire %s, rim %s%s",
		string.match(job.key, "([^/]+)$"), job.model, used, #job.m, table.concat(names, ", "), #order, hasTire and "yes" or "drawn",
		hasRim and "yes" or "drawn", #missing > 0 and (", missing: " .. table.concat(missing, ", ")) or ""))
end

-- mesh facts of a model from earlier scans (file per model and CACHE_VERSION), dropped when the model signature changes
local function loadMeshInfo(model, sig)
	local d = PC.info[model]
	if d and d.sig == sig then return d end
	local file = CACHE_DIR .. model .. "_" .. CACHE_VERSION .. "_meshinfo.json"
	d = FS:fileExists(file) and jsonReadFile(file) or nil
	if type(d) ~= "table" or d.sig ~= sig or type(d.m) ~= "table" then d = { m = {} } end
	d.nf, d.gs, d.sig, d.file = type(d.nf) == "table" and d.nf or {}, type(d.gs) == "table" and d.gs or {}, sig, file
	PC.info[model] = d
	return d
end

local function runJob(job)
	local shape = shapes[job.key]
	shape.state = "building"
	setPhase("cache check")
	local metaFile = CACHE_DIR .. job.key .. ".json"
	local sig = modelSignature(job.model)
	local meta = FS:fileExists(metaFile) and jsonReadFile(metaFile) or nil
	if meta and meta.sig == sig and meta.bodyV == BODY_VERSION and type(meta.paths) == "table" and #meta.paths > 0 and type(meta.tiers) == "table" then
		local allExist = true
		for _, p in ipairs(meta.paths) do if not FS:fileExists(p) then allExist = false end end
		if allExist then
			if type(meta.sound) ~= "table" or meta.sound.gearV ~= GEAR_VERSION then
				meta.sound = resolveSound(job)
				addGearing(job, meta.sound, meta.wheels)
				jsonWriteFile(metaFile, meta, false)
			else
				log('I', 'MPProxyMeshGE', string.format("Proxy engine sound for %s/%s: %s (source: %s, cached)", job.model, string.sub(job.key, -16), meta.sound.event or "type mapping", tostring(meta.sound.source)))
			end
			shape.sound = meta.sound
			finishBBox(shape, meta.bbox, job.model)
			if meta.wheelV ~= WHEEL_VERSION or (meta.wheelDet == true) ~= cfg.wheelDetails then
				local w, why = resolveWheels(job)
				meta.wheels = checkWheels(w, shape) or false
				meta.com = job.com or false
				meta.skin = job.skin or false
				meta.wheelV, meta.wheelDet = WHEEL_VERSION, cfg.wheelDetails
				logWheels(job, meta.wheels or nil, why)
				addGearing(job, meta.sound, meta.wheels)
				jsonWriteFile(metaFile, meta, false)
			elseif meta.wheels then
				logWheels(job, meta.wheels, ", cached")
			end
			shape.wheels = meta.wheels or nil
			shape.com = meta.com or nil
			shape.skin = meta.skin or nil
			setPhase("materials")
			loadModelMaterials(job.model)
			D.ensureMaterials(meta.materials)
			shape.materials = meta.materials
			shape.paths = meta.paths
			shape.tiers = meta.tiers
			shape.fromCache = true -- built in an earlier session
			finishBBox(shape, meta.bbox, job.model)
			shape.state = "ready"
			return
		end
	end

	shape.sound = resolveSound(job)
	setPhase("cache check")
	local index = partIndex[job.model]
	local wanted, count = {}, 0
	for _, partName in ipairs(job.parts) do
		for _, mesh in ipairs(index[partName] or {}) do
			if count < 250 and not wanted[mesh] then -- the full tier keeps all, the others filter
				wanted[mesh] = true
				count = count + 1
			end
		end
	end
	-- configs that differ only in non visual parts (tuning, engine, paint...) resolve to the same mesh set:
	-- share one set of files, so the engine imports (and caches as .cdae) each mesh set only once
	local meshList = {}
	for mesh in pairs(wanted) do meshList[#meshList + 1] = mesh end
	table.sort(meshList)
	local meshKey = job.model .. "_" .. CACHE_VERSION .. "_m" .. hashString(job.model .. "|" .. cfg.triBudget .. "|" .. BODY_VERSION .. "|" .. table.concat(meshList, ","))
	local meshMetaFile = CACHE_DIR .. meshKey .. ".json"
	if count > 0 and FS:fileExists(meshMetaFile) then
		local mm = jsonReadFile(meshMetaFile)
		local ok = mm and mm.sig == sig and type(mm.paths) == "table" and #mm.paths > 0 and type(mm.tiers) == "table"
		if ok then for _, p in ipairs(mm.paths) do if not FS:fileExists(p) then ok = false end end end
		if ok then
			setPhase("materials")
			loadModelMaterials(job.model)
			D.ensureMaterials(mm.materials)
			shape.materials = mm.materials
			mm.sound = shape.sound -- per config, the mesh set is shared by configs with other engines
			finishBBox(shape, mm.bbox, job.model)
			local w, why = resolveWheels(job)
			shape.wheels = checkWheels(w, shape)
			logWheels(job, shape.wheels, why)
			addGearing(job, shape.sound, shape.wheels)
			shape.com, shape.skin = job.com, job.skin
			mm.wheels, mm.wheelV, mm.bodyV, mm.com, mm.skin = shape.wheels or false, WHEEL_VERSION, BODY_VERSION, job.com or false, job.skin or false
			mm.wheelDet = cfg.wheelDetails
			jsonWriteFile(metaFile, mm, false)
			mm.sound, mm.wheels, mm.wheelV, mm.bodyV, mm.com, mm.skin, mm.wheelDet = nil, nil, nil, nil, nil, nil, nil
			shape.paths = mm.paths
			shape.tiers = mm.tiers
			shape.fromCache = true
			finishBBox(shape, mm.bbox, job.model)
			shape.state = "ready"
			return
		end
	end
	if count == 0 then
		log('W', 'MPProxyMeshGE', string.format("No proxy mesh for %s: none of its %d config parts has a usable flexbody mesh in /vehicles/%s/", job.model, #job.parts, job.model))
		shape.state = "failed" shape.reason = "no flexbody meshes for the config parts"
		return
	end

	-- per mesh facts (source file, triangles, size, bounds, materials) from earlier scans of this model: the tier
	-- selection needs no .dae scan when every wanted mesh is known already
	setPhase("mesh info")
	local info = loadMeshInfo(job.model, sig)
	local unknown, nUnknown = {}, 0
	for mesh in pairs(wanted) do if not info.m[mesh] and not info.nf[mesh] then unknown[mesh] = true nUnknown = nUnknown + 1 end end
	local daes = FS:findFiles("/vehicles/" .. job.model .. "/", "*.dae", -1, false, false) or {}
	table.sort(daes)
	local parsed = {} -- [file] = filterDae result of this job, node blocks in memory
	FS:directoryCreate(CACHE_DIR, true)
	if nUnknown > 0 then
		setPhase("dae scan")
		local scratch = {math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge}
		for _, dae in ipairs(daes) do
			local part = D.filterDae(dae, unknown, scratch, nil)
			if part then
				parsed[dae] = part
				info.gs[dae] = D.daeSignature(part.header)
				for _, n in ipairs(part.nodes) do
					if unknown[n.name] then -- first file with the name wins (all its nodes of that name are used)
						unknown[n.name] = nil
						local g, ml = part.geomById[n.url], {}
						for m in pairs(n.mats) do ml[#ml + 1] = m end
						table.sort(ml)
						info.m[n.name] = { f = dae, t = n.tris, s = n.size, g = g and #g or 0, b = n.bb, m = table.concat(ml, ",") }
					end
				end
			end
			coroutine.yield()
		end
		for mesh in pairs(unknown) do info.nf[mesh] = true end
		jsonWriteFile(info.file, { sig = sig, m = info.m, nf = info.nf, gs = info.gs }, false)
		coroutine.yield()
	end
	-- the jbeam part a mesh belongs to, the same for every config (alphabetically first part listing it)
	local own = PC.owner[job.model]
	if not own then
		own = {}
		for pn, ms in pairs(index) do for _, m in ipairs(ms) do if not own[m] or pn < own[m] then own[m] = pn end end end
		PC.owner[job.model] = own
	end
	local bbox = {math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge}
	local all = {}
	for mesh in pairs(wanted) do
		local e = info.m[mesh]
		if e then
			all[#all + 1] = { name = mesh, tris = e.t or 0, size = e.s or 0, e = e }
			local nb = e.b
			if type(nb) == "table" and nb[1] and nb[1] <= nb[4] then
				for k = 1, 3 do
					if nb[k] < bbox[k] then bbox[k] = nb[k] end
					if nb[k + 3] > bbox[k + 3] then bbox[k + 3] = nb[k + 3] end
				end
			end
		end
	end
	if #all == 0 then
		log('W', 'MPProxyMeshGE', string.format("No proxy mesh for %s: %d wanted meshes not found in %d .dae files of /vehicles/%s/", job.model, count, #daes, job.model))
		shape.state = "failed" shape.reason = "meshes not found in the .dae files"
		return
	end
	local maxSize = 0
	for _, n in ipairs(all) do if n.size > maxSize then maxSize = n.size end end
	-- the far tiers (parts from lodFull, shell from lodParts, 20 / 60 m by default) also leave out parts whose largest
	-- bounds dimension is under MIN_FAR_PART m: a few pixels at that range, but each one is a mesh (draw call) of its
	-- own. The full tier keeps them, so mirrors, lights and badges are there up close. Parts without bounds stay.
	local function farVisible(n)
		local b = n.e.b
		if type(b) == "table" and b[1] and b[1] <= b[4] and math.max(b[4] - b[1], b[5] - b[2], b[6] - b[3]) < MIN_FAR_PART then return false end
		return isWantedMesh(n.name or "")
	end
	local selections = {
		[TIER_FULL] = function() return D.selectNodes(all, nil, 0, 0) end,
		[TIER_PARTS] = function() return D.selectNodes(all, farVisible, cfg.triBudget, 0) end,
		[TIER_SHELL] = function() return D.selectNodes(all, farVisible, math.max(3000, math.floor(cfg.triBudget / 6)), maxSize * 0.25) end,
	}
	-- the kept meshes of a tier become shared pieces: one file per (source .dae, jbeam part) when that part holds at
	-- least PC.minBytes of geometry, the small rest of the tier in one file per .dae unit / up axis. File names hash
	-- the content (source files + mesh names), so configs and tiers keeping the same meshes use the same file.
	local pieces, paths, mats, tierInfo = {}, {}, {}, {}
	local function plan()
		local byPart, list, rest = {}, {}, {}
		for _, n in ipairs(all) do
			if n.keep then
				local k = n.e.f .. "|" .. (own[n.name] or "?")
				local g = byPart[k]
				if not g then g = { bytes = 0, nodes = {} } byPart[k] = g end
				g.nodes[#g.nodes + 1] = n
				g.bytes = g.bytes + (n.e.g or 0)
				for m in string.gmatch(n.e.m or "", "[^,]+") do mats[m] = true end
			end
		end
		local function add(nodes)
			local files, fl = {}, {}
			for _, n in ipairs(nodes) do
				if not files[n.e.f] then files[n.e.f] = {} fl[#fl + 1] = n.e.f end
				table.insert(files[n.e.f], n.name)
			end
			table.sort(fl)
			local desc = {}
			for _, f in ipairs(fl) do table.sort(files[f]) desc[#desc + 1] = f .. ":" .. table.concat(files[f], ",") end
			local path = CACHE_DIR .. job.model .. "_" .. CACHE_VERSION .. "_p" .. hashString(BODY_VERSION .. ";" .. table.concat(desc, ";")) .. ".dae"
			if not pieces[path] then pieces[path] = { files = files, order = fl } paths[#paths + 1] = path end
			list[#list + 1] = path
		end
		local keys = {}
		for k in pairs(byPart) do keys[#keys + 1] = k end
		table.sort(keys)
		for _, k in ipairs(keys) do
			local g = byPart[k]
			if g.bytes >= PC.minBytes then add(g.nodes)
			else
				local gs = info.gs[g.nodes[1].e.f] or ""
				rest[gs] = rest[gs] or {}
				for _, n in ipairs(g.nodes) do table.insert(rest[gs], n) end
			end
		end
		local gl = {}
		for gs in pairs(rest) do gl[#gl + 1] = gs end
		table.sort(gl)
		for _, gs in ipairs(gl) do add(rest[gs]) end
		return list
	end
	local tiers, prevKept = {}, nil
	for t = 1, 3 do
		local kept, tris = selections[t]()
		if kept == 0 and t > 1 then tiers[t] = tiers[t - 1] -- nothing left for this tier, reuse the one before
		elseif kept == prevKept and t > 1 then tiers[t] = tiers[t - 1] -- same selection, same files
		else tiers[t] = plan() end
		prevKept = kept
		tierInfo[#tierInfo + 1] = string.format("%d parts/%d tris/%d pieces", kept, tris, #tiers[t])
		coroutine.yield()
	end
	-- build the pieces not on disk yet; their source files are scanned once (again, when the info came from disk)
	local need, built, reused = {}, 0, 0
	local meshesBefore, meshesAfter = 0, 0 -- meshes of the pieces built now, before / after the material merge
	for _, path in ipairs(paths) do
		if FS:fileExists(path) then reused = reused + 1
		else for f, names in pairs(pieces[path].files) do need[f] = need[f] or {} for _, nm in ipairs(names) do need[f][nm] = true end end end
	end
	for f, names in pairs(need) do
		local part = parsed[f]
		local have = {}
		if part then for _, n in ipairs(part.nodes) do have[n.name] = true end end
		for nm in pairs(names) do if not have[nm] then part = nil break end end
		if not part then
			setPhase("dae scan")
			parsed[f] = D.filterDae(f, names, {math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge}, nil)
			coroutine.yield()
		end
	end
	for _, path in ipairs(paths) do
		local pc = pieces[path]
		if not FS:fileExists(path) then
			local lists, ok = {}, true
			for _, f in ipairs(pc.order) do
				local part = parsed[f]
				if not part then ok = false break end
				local want = {}
				for _, nm in ipairs(pc.files[f]) do want[nm] = true end
				local nodes, geoms, used = {}, {}, {}
				local sel = {}
				for _, n in ipairs(part.nodes) do if want[n.name] then sel[#sel + 1] = n end end
				table.sort(sel, function(x, y) if x.name ~= y.name then return x.name < y.name end return x.url < y.url end)
				for _, n in ipairs(sel) do
					nodes[#nodes + 1] = n.block
					if not used[n.url] and part.geomById[n.url] then used[n.url] = true geoms[#geoms + 1] = part.geomById[n.url] end
				end
				lists[#lists + 1] = { header = part.header, nodes = nodes, geoms = geoms }
			end
			if ok and #lists > 0 then
				setPhase("merge")
				local merged, nb, na = MM.mergeByMaterial(lists)
				meshesBefore, meshesAfter = meshesBefore + nb, meshesAfter + na
				lists = nil
				local text = D.mergeDae(merged)
				merged = nil
				coroutine.yield()
				setPhase("write") -- streamed in slices, budget checks between them
				if D.writePieces(path, text) then built = built + 1 else ok = false end
				text = nil
				coroutine.yield()
			end
			if not ok then
				log('W', 'MPProxyMeshGE', string.format("Proxy mesh piece %s for %s could not be built", string.match(path, "([^/]+)$"), job.model))
				shape.state = "failed" shape.reason = "a mesh piece could not be written"
				return
			end
		end
	end
	parsed = nil
	log('I', 'MPProxyMeshGE', string.format("Proxy mesh tiers for %s: full %s, parts %s, shell %s; %d pieces, %d built (%d meshes merged into %d by material), %d shared from disk, %d of %d mesh facts scanned now",
		job.model, tierInfo[1], tierInfo[2], tierInfo[3], #paths, built, meshesBefore, meshesAfter, reused, nUnknown, count))
	setPhase("materials")
	loadModelMaterials(job.model)
	local matList = {}
	for name in pairs(mats) do matList[#matList + 1] = name end
	table.sort(matList)
	D.ensureMaterials(matList)
	shape.materials = matList
	local metaData = { sig = sig, paths = paths, tiers = tiers, bbox = D.validBBox(bbox) and bbox or nil, materials = matList }
	jsonWriteFile(meshMetaFile, metaData, false)
	finishBBox(shape, bbox, job.model)
	local wl, why = resolveWheels(job)
	shape.wheels = checkWheels(wl, shape)
	addGearing(job, shape.sound, shape.wheels)
	shape.com, shape.skin = job.com, job.skin
	logWheels(job, shape.wheels, why)
	metaData.com, metaData.skin, metaData.wheelDet = job.com or false, job.skin or false, cfg.wheelDetails
	metaData.sound, metaData.wheels, metaData.wheelV, metaData.bodyV = shape.sound, shape.wheels or false, WHEEL_VERSION, BODY_VERSION
	jsonWriteFile(metaFile, metaData, false)
	shape.paths = paths
	shape.tiers = tiers
	shape.state = "ready"
end

local function hasCdae(path)
	local v = cdaeCache[path]
	if v == nil then
		local c = string.gsub(path, "%.dae$", ".cdae")
		v = FS:fileExists("/temp" .. c) or FS:fileExists(c)
		cdaeCache[path] = v
	end
	return v
end

local function stepJobs()
	if not currentJob then
		local job = table.remove(jobs, 1)
		if not job and #wheelJobs > 0 then job = table.remove(wheelJobs, 1) end
		if not job and cfg.prebuild then
			job = table.remove(prebuildJobs, 1)
			while job and shapes[job.key] and shapes[job.key].state ~= "queued" do job = table.remove(prebuildJobs, 1) end
			if job then pb.current, pb.verb, pb.showUntil = job.model, "Prebuilding", clock + 0.5 end
		end
		if not job then return end
		currentJob = { job = job, co = coroutine.create(job.wheelJob and runWheelJob or runJob), started = clock, maxStepMs = 0, maxStepPhase = "", frames = 0,
			totalMs = 0, worstFrameMs = 0, phaseMs = {} }
		jobPhase = "start"
	end
	budgetTimer = TIMER()
	currentJob.frames = currentJob.frames + 1
	local cj = currentJob
	local frameMs = 0
	while currentJob and budgetTimer:stop() < frameBudget do
		local before = budgetTimer:stop()
		local phase = jobPhase
		local ok, err = coroutine.resume(currentJob.co, currentJob.job)
		local stepMs = budgetTimer:stop() - before
		frameMs = frameMs + stepMs
		cj.totalMs = cj.totalMs + stepMs
		cj.phaseMs[phase] = (cj.phaseMs[phase] or 0) + stepMs
		if stepMs > cj.maxStepMs then cj.maxStepMs, cj.maxStepPhase = stepMs, phase end
		if frameMs > cj.worstFrameMs then cj.worstFrameMs = frameMs end
		if not ok then
			log('E', 'MPProxyMeshGE', "Building proxy mesh for "..tostring(currentJob.job.model)..(currentJob.job.wheelJob and " (wheels)" or "").." failed: "..tostring(err))
			if currentJob.job.wheelJob then wheelFiles[currentJob.job.key] = "failed"
			elseif shapes[currentJob.job.key] then shapes[currentJob.job.key].state = "failed" end
			currentJob = nil
		elseif coroutine.status(currentJob.co) == "dead" then
			local sh = not cj.job.wheelJob and shapes[cj.job.key] or nil
			if sh and sh.state == "ready" then queueWheelMeshes(sh, cj.job.model) end
			if cj.job.prebuild then
				pb.done = pb.done + 1
				if sh and sh.state == "ready" then
					if not sh.fromCache then pb.built = pb.built + 1 end
					for _, path in ipairs(sh.paths or {}) do
						if not hasCdae(path) then pb.compile[#pb.compile + 1] = { path = path, model = cj.job.model } end
					end
				end
				log('I', 'MPProxyMeshGE', string.format("Prebuild %d/%d %s: %s in %.1f ms over %d frames", pb.done, pb.queued, cj.job.model,
					(sh and sh.state == "ready") and (sh.fromCache and "from disk cache" or "built") or "failed", cj.totalMs, cj.frames))
			end
			local phases = {}
			for name, ms in pairs(cj.phaseMs) do if ms >= 0.05 then phases[#phases + 1] = string.format("%s %.1f", name, ms) end end
			table.sort(phases)
			log(cj.worstFrameMs > frameBudget * 3 and 'W' or 'I', 'MPProxyMeshGE', string.format(
				"Mesh job %s%s: total %.1f ms over %d frames (%.1f s), worst frame %.1f ms, longest step %.1f ms (%s); ms per step: %s",
				cj.job.model, cj.job.wheelJob and " (wheel meshes)" or ((sh and sh.fromCache) and " (from disk cache)" or ""), cj.totalMs, cj.frames, clock - cj.started,
				cj.worstFrameMs, cj.maxStepMs, cj.maxStepPhase, table.concat(phases, ", ")))
			currentJob = nil
		end
	end
	budgetTimer = nil
end

--- Returns the mesh key for a model + config and queues the build if needed.
-- @tparam string model jbeam name
-- @tparam table vcf vehicle config from the spawn packet (vcf.parts = { slot = partName })

local function configKey(model, vcf)
	local parts = {}
	for _, partName in pairs(vcf.parts) do
		if type(partName) == "string" and partName ~= "" then parts[#parts + 1] = partName end
	end
	if vcf.mainPartName then parts[#parts + 1] = vcf.mainPartName end
	table.sort(parts)
	return model .. "_" .. CACHE_VERSION .. "_" .. hashString(model .. "|" .. table.concat(parts, ",")), parts
end

-- the parts of a model's default configuration (its default .pc), or nil
local function defaultConfig(model)
	local ok, info = pcall(core_vehicles.getModel, model)
	local m = ok and type(info) == "table" and info.model or nil
	local pcName = m and m.default_pc
	if not pcName then return nil end
	local pc = jsonReadFile("/vehicles/" .. model .. "/" .. pcName .. ".pc")
	if type(pc) ~= "table" or type(pc.parts) ~= "table" then return nil end
	return { parts = pc.parts, mainPartName = pc.mainPartName or model, vars = type(pc.vars) == "table" and pc.vars or nil }
end

-- queues (or finds) the default config build of a model; cached ones go first, they resolve from disk at once
local function requestDefault(model, toBackground)
	if defaultKeys[model] ~= nil then return defaultKeys[model] or nil end
	local vcf = defaultConfig(model)
	if not vcf then defaultKeys[model] = false return nil end
	local key, parts = configKey(model, vcf)
	if toBackground and not shapes[key] then
		-- already built and compiled: nothing to do now (left out of defaultKeys so a later real request still queues it)
		local meta = FS:fileExists(CACHE_DIR .. key .. ".json") and jsonReadFile(CACHE_DIR .. key .. ".json") or nil
		local all = type(meta) == "table" and type(meta.paths) == "table" and #meta.paths > 0
		for _, path in ipairs(all and meta.paths or {}) do if not hasCdae(path) then all = false end end
		if all then pb.skipped = pb.skipped + 1 return nil end
	end
	defaultKeys[model] = key
	if not shapes[key] then
		shapes[key] = { state = "queued" }
		local job = { key = key, model = model, parts = parts, vcf = vcf }
		if toBackground then job.prebuild = true pb.queued = pb.queued + 1 prebuildJobs[#prebuildJobs + 1] = job
		elseif FS:fileExists(CACHE_DIR .. key .. ".json") then table.insert(jobs, 1, job)
		else jobs[#jobs + 1] = job end
	end
	return key
end

local function request(model, vcf)
	if not model or type(vcf) ~= "table" or type(vcf.parts) ~= "table" then return nil end
	local parts = {}
	for _, partName in pairs(vcf.parts) do
		if type(partName) == "string" and partName ~= "" then parts[#parts + 1] = partName end
	end
	if vcf.mainPartName then parts[#parts + 1] = vcf.mainPartName end
	table.sort(parts)
	local key = model .. "_" .. CACHE_VERSION .. "_" .. hashString(model .. "|" .. table.concat(parts, ","))
	if M._onRequest then M._onRequest() end
	if not shapes[key] then
		shapes[key] = { state = "queued" }
		jobs[#jobs + 1] = { key = key, model = model, parts = parts, vcf = vcf }
	end
	if fallbackOf[key] == nil then
		local dkey = requestDefault(model, false)
		fallbackOf[key] = (dkey and dkey ~= key) and dkey or false
	end
	return key
end

local function getShape(key)
	return key and shapes[key]
end

-- engine sound info of a config (or of the model's default config while the exact one builds), nil if unknown
local function getSound(key)
	local sh = key and shapes[key]
	if sh and sh.sound then return sh.sound end
	local fb = key and fallbackOf[key] and shapes[fallbackOf[key]]
	return fb and fb.sound or nil
end

-- ============= ENGINE IMPORTS =============
-- The first TSStatic of a .dae makes the engine load the shape synchronously (compiling a .cdae next to a /temp
-- copy the first time, loading that .cdae later). That cannot be sliced from Lua, so new imports are spread out.
local function tierPaths(shape, tier)
	return shape.tiers and (shape.tiers[tier] or shape.tiers[tostring(tier)]) or shape.paths
end

-- nil when every file of the tier is loaded this session, else the wait between two such first uses
local function importInterval(shape, tier)
	local cached, any = true, false
	for _, path in ipairs(tierPaths(shape, tier)) do
		if not importedPaths[path] then any = true if not hasCdae(path) then cached = false end end
	end
	if not any then return nil end
	return cached and CACHED_SHAPE_INTERVAL or NEW_SHAPE_INTERVAL
end

-- ============= TSSTATIC POOL =============
local function createStatic(path, plain)
	local obj = createObject('TSStatic')
	if not obj then return nil end
	obj:setField('shapeName', 0, path)
	obj:setField('dynamic', 0, 'true')       -- moved every frame (same as trafficSignals)
	obj:setField('collisionType', 0, 'None')
	obj:setField('decalType', 0, 'None')
	obj.useInstanceRenderData = not plain    -- per instance paint (instanceColor*), not for wheels
	obj.canSave = false
	obj:registerObject(Sim.getUniqueName("beammpProxyMesh"))
	importedPaths[path] = true -- the engine has the shape now
	PC.used = PC.used or {}
	PC.used[path] = os.time() PC.usedDirty = true -- cache size cap: least recently used files go first
	liveCount = liveCount + 1
	allObjects[obj:getId()] = true
	return obj:getId()
end

local function takeStatic(path, plain)
	local pool = pools[path]
	if pool and #pool > 0 then return table.remove(pool) end
	return createStatic(path, plain)
end

local function returnStatic(path, id)
	local obj = scenetree.findObjectById(id)
	if not obj then liveCount = liveCount - 1 return end
	obj.hidden = true
	pools[path] = pools[path] or {}
	table.insert(pools[path], id)
end

-- engine import of the first not yet loaded file of a tier through a hidden pooled TSStatic; returns the wait
-- before the next first use (shorter when its .cdae existed), nil when every file of the tier is loaded
local function warmOne(shape, tier, key)
	for _, path in ipairs(tierPaths(shape, tier)) do
		if not importedPaths[path] then
			local t, cdae = TIMER(), hasCdae(path)
			local id = takeStatic(path)
			if id then returnStatic(path, id) end
			log(t:stop() > 20 and 'W' or 'I', 'MPProxyMeshGE', string.format("Engine import of %s tier %d (%s): %.1f ms, compiled .cdae was %s",
				tostring(string.match(key or "", "^(.-)_v%d")), tier, string.match(path, "([^/]+)$") or path, t:stop(),
				cdae and "on disk" or "not on disk (compiled now)"))
			return cdae and CACHED_SHAPE_INTERVAL or NEW_SHAPE_INTERVAL
		end
	end
end

local function paintString(paint)
	local c = paint and paint.baseColor
	if type(c) ~= "table" then return "0.6 0.6 0.6 1" end
	return string.format("%.3f %.3f %.3f %.3f", c[1] or 0.6, c[2] or 0.6, c[3] or 0.6, c[4] or 1)
end

-- "metallic roughness clearcoat clearcoatRoughness" of one vcf paint
local function metallicString(paint)
	if type(paint) ~= "table" then return "0 0.5 0 0" end
	return string.format("%.3f %.3f %.3f %.3f", tonumber(paint.metallic) or 0, tonumber(paint.roughness) or 0.5,
		tonumber(paint.clearcoat) or 0, tonumber(paint.clearcoatRoughness) or 0)
end

local function attach(p, shape, tier)
	p.meshObjects = {}
	p.meshLast = nil -- new objects: place them on the next draw
	p.meshTier = tier
	local list = tierPaths(shape, tier)
	for _, path in ipairs(list) do
		local newImport = not importedPaths[path]
		local importTimer = newImport and TIMER() or nil
		importedPaths[path] = true
		local id = takeStatic(path)
		if importTimer then -- engine side shape import (synchronous); .cdae compiled the first time, then reused
			local ms = importTimer:stop()
			log(ms > 20 and 'W' or 'I', 'MPProxyMeshGE', string.format("Engine import of %s tier %d (%s): %.1f ms, compiled .cdae was %s",
				tostring(string.match(p.meshKey or "", "^(.-)_v%d")), tier, string.match(path, "([^/]+)$") or path, ms,
				cdaeCache[path] and "on disk" or "not on disk (compiled now)"))
		end
		if id then
			local obj = scenetree.findObjectById(id)
			if obj then
				local paints = p.vcf and p.vcf.paints or {}
				obj:setField('instanceColor', 0, paintString(paints[1]))
				obj:setField('instanceColor1', 0, paintString(paints[2] or paints[1]))
				obj:setField('instanceColor2', 0, paintString(paints[3] or paints[1]))
				if cfg.metallicPaint then -- same field and format the game sets on vehicles (core/vehicle/partmgmt.lua)
					for i = 1, 3 do obj:setField('metallicPaintData', i - 1, metallicString(paints[i] or paints[1])) end
				end
				-- livery: "material=material.<slot>.<skin>" pairs (skinField); always set, pooled objects may carry an
				-- earlier proxy's skin
				obj:setField('skin', 0, cfg.liveries and D.skinField(shape.skin, shape.materials, string.match(p.meshKey or "", "^(.-)_v%d")) or "")
				obj.hidden = false
				p.meshObjects[#p.meshObjects + 1] = { path = path, id = id, obj = obj }
			end
		end
	end
	p.meshShape = shape
end

local function detachWheels(p)
	if not p.wheelObjects then return end
	for _, o in pairs(p.wheelObjects) do returnStatic(o.path, o.id) end
	p.wheelObjects = nil
	p.wheelShape = nil
end

-- real wheel objects for a proxy with body meshes, once every wheel file of its config is built; first imports
-- share the engine import interval with the body meshes
local function attachWheels(p, shape)
	local paths, newCount, allCdae = {}, 0, true
	for i, w in ipairs(shape.wheels) do
		local path = wheelPath(w)
		if path then
			if wheelFiles[path] == nil then queueWheelMeshes(shape, string.match(p.meshKey or "", "^(.-)_v%d") or "?") end
			if wheelFiles[path] == "queued" then return false end
			if wheelFiles[path] == "ready" then
				paths[i] = path
				if not importedPaths[path] then
					newCount = newCount + 1
					if not hasCdae(path) then allCdae = false end
				end
			end
		end
	end
	if next(paths) == nil then return false end
	if newCount > 0 then
		if clock < nextNewShapeAllowed then return false end
		nextNewShapeAllowed = clock + (allCdae and CACHED_SHAPE_INTERVAL or NEW_SHAPE_INTERVAL)
	end
	p.wheelObjects, p.wheelShape = {}, shape
	for i, path in pairs(paths) do
		local importTimer = not importedPaths[path] and TIMER() or nil
		importedPaths[path] = true
		local id = takeStatic(path, true)
		if importTimer then
			local ms = importTimer:stop()
			log(ms > 20 and 'W' or 'I', 'MPProxyMeshGE', string.format("Engine import of wheel %s (%s): %.1f ms, compiled .cdae was %s",
				string.match(path, "([^/]+)$") or path, tostring(shape.wheels[i].n), ms, cdaeCache[path] and "on disk" or "not on disk (compiled now)"))
		end
		local obj = id and scenetree.findObjectById(id)
		if obj then
			local info = wheelInfo[path]
			obj:setField('skin', 0, cfg.liveries and info and D.skinField(shape.skin, info.mats, "wheel " .. tostring(shape.wheels[i].n)) or "")
			obj.hidden = false
			p.wheelObjects[i] = { path = path, id = id, obj = obj, roll = 0, info = wheelInfo[path] }
		end
	end
	return true
end

local function detach(p)
	detachWheels(p)
	if not p.meshObjects then return end
	for _, o in ipairs(p.meshObjects) do returnStatic(o.path, o.id) end
	p.meshObjects = nil
	p.meshShape = nil
	p.meshFallback = nil
	p.meshTier = nil
end

--- Decision pass (4 Hz, called by MPProxyGE): picks the nearest proxies with a ready shape.
local candidates = {}
local function decide(vehicles, refPos)
	table.clear(candidates)
	table.clear(waitingLoad)
	local meshMax = math.min(cfg.distance, cfg.lodShell)
	local release = meshMax * (1 + LOD_HYSTERESIS) + 3
	local leaving = {}
	for _, v in pairs(vehicles) do
		local p = v.proxy
		if p then
			local usable = cfg.enabled and ((v.isProxy and not v.isSpawned) or v.proxyHandover ~= nil or v.hybridPaused) and not v.isDeleted and p.hasData
			local d = usable and refPos:distance(p.rpos) or math.huge
			if p.meshObjects and not usable then detach(p) -- gone, real or collider: right away
			elseif p.meshObjects and d > release and not v.isFakeTest then leaving[#leaving + 1] = { p = p, d = d } end
			-- MPProxyTest vehicles ignore the mesh distance (they are never drawn as boxes)
			if usable and (d < release or v.isFakeTest) and p.meshKey then
				candidates[#candidates + 1] = { v = v, d = d }
			end
		end
	end
	-- out of range: farthest first, a few per pass
	table.sort(leaving, function(a, b) return a.d > b.d end)
	local detached = 0
	for _, l in ipairs(leaving) do
		if detached >= MAX_DETACHES_PER_PASS then break end
		detach(l.p)
		detached = detached + 1
	end
	table.sort(candidates, function(a, b) return a.d < b.d end)
	fps.inRange = #candidates
	local limit = math.min(cfg.maxProxies, fps.cap)
	local created = 0
	for i, c in ipairs(candidates) do
		local p = c.v.proxy
		if i > limit and not c.v.isFakeTest then
			if p.meshObjects and detached < MAX_DETACHES_PER_PASS then detach(p) detached = detached + 1 end
		elseif p.meshObjects and p.meshFallback and shapes[p.meshKey] and shapes[p.meshKey].state == "ready" and created < MAX_NEW_OBJECTS_PER_PASS then
			detach(p) -- the exact config is ready now, swap the default config mesh out (attached again below)
		end
		-- LOD tier: nearest first (candidates are sorted), switches share the per pass budget with new meshes
		local want = tierForDistance(c.d, p.meshTier) or (c.v.isFakeTest and TIER_SHELL) or nil
		if p.meshObjects and want ~= p.meshTier and created < MAX_NEW_OBJECTS_PER_PASS then
			if want then detach(p) -- attached again below with the new tier
			elseif detached < MAX_DETACHES_PER_PASS then detach(p) detached = detached + 1 end
		end
		if want and not p.meshObjects and not (i > limit and not c.v.isFakeTest) then
			local shape = shapes[p.meshKey]
			p.meshFallback = nil
			if not (shape and shape.state == "ready") then
				local fb = fallbackOf[p.meshKey] and shapes[fallbackOf[p.meshKey]]
				if fb and fb.state == "ready" then shape = fb p.meshFallback = true end
			end
			if shape and shape.state == "ready" and created < MAX_NEW_OBJECTS_PER_PASS then
				-- first use of a file this session (disk cached shapes too): the engine imports it synchronously,
				-- so only one such attach per interval (shorter when the compiled .cdae already exists)
				-- a tier of several pieces imports them one per interval (hidden, pooled), the proxy attaches once all are in
				local interval = not c.v.isFakeTest and importInterval(shape, want) or nil
				if interval then
					if clock >= nextNewShapeAllowed then
						nextNewShapeAllowed = clock + (warmOne(shape, want, p.meshKey) or interval)
						if not importInterval(shape, want) then
							attach(p, shape, want)
							created = created + 1
						end
					else
						waitingLoad[#waitingLoad + 1] = c.v.jbeam or string.match(p.meshKey, "^(.-)_v%d") or "?"
					end
				else
					attach(p, shape, want)
					created = created + 1
				end
			end
		end
	end
	-- visual suspension: nearest proxies with meshes inside proxySuspensionDistance
	local suspLeft = cfg.suspension and SUSP_MAX_PROXIES or 0
	for _, c in ipairs(candidates) do
		local p = c.v.proxy
		p.suspOn = suspLeft > 0 and p.meshObjects ~= nil and c.d < cfg.suspDist or nil
		if p.suspOn then suspLeft = suspLeft - 1 end
	end
	-- real wheels: nearest proxies in the full / parts tiers
	local wheelsLeft = cfg.realWheels and cfg.realWheelsMax or 0
	for _, c in ipairs(candidates) do
		local p = c.v.proxy
		local want = wheelsLeft > 0 and p.meshObjects and p.meshShape and p.meshShape.wheels and p.meshTier and p.meshTier <= TIER_PARTS and true or false
		if want then wheelsLeft = wheelsLeft - 1 end
		if p.wheelObjects and (not want or p.wheelShape ~= p.meshShape) then detachWheels(p) end
		if want and not p.wheelObjects then attachWheels(p, p.meshShape) end
	end
end

local org = vec3()
local axX, axY, axZ = vec3(), vec3(), vec3()
local unitX, unitY, unitZ = vec3(1,0,0), vec3(0,1,0), vec3(0,0,1)
local ffiFound = ffi and ffi.C and true or false
local drawCylinder = ffiFound and ffi.C.BNG_DBG_DRAW_Cylinder or nop
local wheelColor = color(25, 25, 25, 255)
local rimColor = color(150, 150, 155, 255)
local MAX_STEER = math.rad(30) -- drawn front wheel angle at full steering
local wheelDir, wheelUp, wheelQuat = vec3(), vec3(), quat()
local TWO_PI = 2 * math.pi

local function toWorld(lx, ly, lz)
	return org.x + axX.x*lx + axY.x*ly + axZ.x*lz, org.y + axX.y*lx + axY.y*ly + axZ.y*lz, org.z + axX.z*lx + axY.z*ly + axZ.z*lz
end

-- ============= VISUAL SUSPENSION =============
-- Nearest proxies only (proxySuspension): each wheel follows the ground under it within a small travel (a ray
-- down along the body's up axis, every few frames per wheel, staggered), spring-damped. The body mesh leans
-- with the acceleration of the proxy (braking dives, cornering rolls outward) and with the wheel offsets, also
-- spring-damped and clamped to a few degrees. The wheels stay where the ground is, only the body tilts.
local SUSP_TRAVEL = 0.12      -- m up / down from the jbeam wheel position
local SUSP_RAY_EVERY = 4      -- frames between two rays of the same wheel
local SUSP_RAY_ABOVE = 0.6    -- ray start above the wheel center
local SUSP_K, SUSP_C = 160, 18           -- wheel spring / damper (per unit mass)
local LEAN_K, LEAN_C = 45, 9             -- body lean spring / damper
local LEAN_MAX = math.rad(3.5)
local LEAN_PER_ACC = 0.0045              -- rad per m/s^2
local rayOrigin, rayDir = vec3(), vec3()
local suspFrame = 0

local function clampAbs(v, m) return v > m and m or (v < -m and -m or v) end

local function updateSuspension(p, shape, dt)
	local st = p.susp
	if not st then
		st = { off = {}, vel = {}, target = {}, seed = math.random(0, SUSP_RAY_EVERY - 1),
			pitch = 0, pitchV = 0, roll = 0, rollV = 0, heave = 0, ax = 0, ay = 0 }
		p.susp = st
	end
	if dt <= 0 then return st end
	-- body acceleration in jbeam axes (forward = -Y, left = +X), lightly filtered
	local v = p.svel
	if v then
		if st.lvx then
			local axw, ayw, azw = (v.x - st.lvx) / dt, (v.y - st.lvy) / dt, (v.z - st.lvz) / dt
			local fwd = -(axw * axY.x + ayw * axY.y + azw * axY.z)
			local left = axw * axX.x + ayw * axX.y + azw * axX.z
			local a = math.min(1, dt * 6)
			st.ax = st.ax + (clampAbs(fwd, 15) - st.ax) * a
			st.ay = st.ay + (clampAbs(left, 15) - st.ay) * a
		end
		st.lvx, st.lvy, st.lvz = v.x, v.y, v.z
	end
	-- wheels: ground under each, staggered rays
	local wheels = shape.wheels
	local sumF, nF, sumR, nR, sumL, nL, sumRt, nRt, sum, n = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	local cy = shape.minY and (shape.minY + shape.maxY) * 0.5 or 0
	local yF, yR, xL, xR = 0, 0, 0, 0
	if wheels then
		rayDir:set(-axZ.x, -axZ.y, -axZ.z)
		for i, w in ipairs(wheels) do
			if (suspFrame + st.seed + i) % SUSP_RAY_EVERY == 0 then
				local px, py, pz = toWorld(w.x, w.y, w.z + SUSP_RAY_ABOVE)
				rayOrigin:set(px, py, pz)
				local maxD = SUSP_RAY_ABOVE + w.r + SUSP_TRAVEL + 0.3
				local d = castRayStatic(rayOrigin, rayDir, maxD)
				-- ground at d below the start: the wheel bottom should touch it
				st.target[i] = (d and d < maxD) and clampAbs(SUSP_RAY_ABOVE + w.r - d, SUSP_TRAVEL) or 0
			end
			local o, ov, t = st.off[i] or 0, st.vel[i] or 0, st.target[i] or 0
			ov = ov + (SUSP_K * (t - o) - SUSP_C * ov) * dt
			o = clampAbs(o + ov * dt, SUSP_TRAVEL)
			st.off[i], st.vel[i] = o, ov
			sum, n = sum + o, n + 1
			if w.y < cy then sumF, nF, yF = sumF + o, nF + 1, yF + w.y else sumR, nR, yR = sumR + o, nR + 1, yR + w.y end
			if w.x > 0 then sumL, nL, xL = sumL + o, nL + 1, xL + w.x else sumRt, nRt, xR = sumRt + o, nRt + 1, xR + w.x end
		end
	end
	-- lean targets: pitch > 0 is nose down (braking), roll > 0 lowers the left (+X) side
	local pitchT = st.ax * -LEAN_PER_ACC
	local rollT = -st.ay * LEAN_PER_ACC -- accelerating to the left (turning left): the right side goes down
	if nF > 0 and nR > 0 then
		local L = (yR / nR) - (yF / nF)
		if L > 0.5 then pitchT = pitchT + (sumR / nR - sumF / nF) / L end
	end
	if nL > 0 and nRt > 0 then
		local T = (xL / nL) - (xR / nRt)
		if T > 0.5 then rollT = rollT - (sumL / nL - sumRt / nRt) / T end
	end
	pitchT, rollT = clampAbs(pitchT, LEAN_MAX), clampAbs(rollT, LEAN_MAX)
	st.pitchV = st.pitchV + (LEAN_K * (pitchT - st.pitch) - LEAN_C * st.pitchV) * dt
	st.rollV = st.rollV + (LEAN_K * (rollT - st.roll) - LEAN_C * st.rollV) * dt
	st.pitch = clampAbs(st.pitch + st.pitchV * dt, LEAN_MAX)
	st.roll = clampAbs(st.roll + st.rollV * dt, LEAN_MAX)
	st.heave = n > 0 and (sum / n) * 0.5 or 0
	return st
end

--- Per frame, for a proxy that has mesh objects: moves them and draws the wheels. Returns true if drawn.
local function drawProxy(p, dist)
	local shape = p.meshShape
	if not p.meshObjects or not shape then return false end
	axX:setRotate(p.rrot, unitX)
	axY:setRotate(p.rrot, unitY)
	axZ:setRotate(p.rrot, unitZ)
	-- the packet position is the center of gravity, the mesh origin is the jbeam origin
	local cx = shape.minX and (shape.minX + shape.maxX) * 0.5 or 0
	local cy = shape.minY and (shape.minY + shape.maxY) * 0.5 or 0
	local com = cfg.comRide and type(shape.com) == "table" and shape.com or nil
	local cz
	if com then
		-- jbeam node mass centre (the packet position is the node mass weighted COG, velocityVE calcCOG)
		local h = com[3] - (shape.groundZ or 0)
		if h > 0.1 and h < 2.5 and math.abs(com[1]) < 3 and math.abs(com[2]) < 6 then
			cx, cy, cz = com[1], com[2], com[3]
			p.cogH = h -- box / far shape and the hybrid contact use the same height
		end
	end
	cz = cz or (shape.groundZ or 0) + (p.cogH or 0.5)
	org:set(p.rpos.x - (axX.x*cx + axY.x*cy + axZ.x*cz), p.rpos.y - (axX.y*cx + axY.y*cy + axZ.y*cz), p.rpos.z - (axX.z*cx + axY.z*cy + axZ.z*cz))
	local r = p.rrot
	local bx, by, bz, qx, qy, qz, qw = org.x, org.y, org.z, r.x, r.y, r.z, r.w
	local susp = nil
	if p.suspOn and shape.wheels then
		local sdt = math.min(math.max(clock - (p.suspT or clock), 0), 0.1)
		p.suspT = clock
		susp = updateSuspension(p, shape, sdt)
		-- body: L = Rx(pitch) * Ry(roll) about the body center, then the heave along the body's up axis
		local th, ph = susp.pitch, susp.roll
		local ct, stt, cph, sph = math.cos(th), math.sin(th), math.cos(ph), math.sin(ph)
		local lyx, lyy, lyz = 0, ct, stt
		local lzx, lzy, lzz = sph, -cph * stt, cph * ct
		wheelDir:set(axX.x*lyx + axY.x*lyy + axZ.x*lyz, axX.y*lyx + axY.y*lyy + axZ.y*lyz, axX.z*lyx + axY.z*lyy + axZ.z*lyz)
		wheelUp:set(axX.x*lzx + axY.x*lzy + axZ.x*lzz, axX.y*lzx + axY.y*lzy + axZ.y*lzz, axX.z*lzx + axY.z*lzy + axZ.z*lzz)
		wheelQuat:setFromDir(wheelDir, wheelUp)
		qx, qy, qz, qw = wheelQuat.x, wheelQuat.y, wheelQuat.z, wheelQuat.w
		-- origin moves so the pivot (cx, cy, cz) stays put: o' = o + R (P - L P) + heave * up
		local rx_, ry_, rz_ = cx * cph + cz * sph, cy, -cx * sph + cz * cph
		local lpx, lpy, lpz = rx_, ry_ * ct - rz_ * stt, ry_ * stt + rz_ * ct
		local dx, dy, dz = cx - lpx, cy - lpy, cz - lpz + susp.heave
		bx = org.x + axX.x*dx + axY.x*dy + axZ.x*dz
		by = org.y + axX.y*dx + axY.y*dy + axZ.y*dz
		bz = org.z + axX.z*dx + axY.z*dy + axZ.z*dz
	else
		p.susp, p.suspT = nil, nil
	end
	-- parked / unchanged: the objects keep their transform, skip the engine calls
	local lb = p.meshLast
	-- compared with the last pose sent to the engine (not last frame), so slow creeping adds up and still updates:
	-- 5 mm, and 0.1 deg of rotation (|dot| > cos(0.05 deg) = 1 - 3.8e-7)
	local moved = not (cfg.skipStatic and lb and (lb[1] - bx)^2 + (lb[2] - by)^2 + (lb[3] - bz)^2 < 2.5e-5
		and math.abs(lb[4] * qx + lb[5] * qy + lb[6] * qz + lb[7] * qw) > 1 - 3.8e-7)
	if moved then
		lb = lb or {}
		lb[1], lb[2], lb[3], lb[4], lb[5], lb[6], lb[7] = bx, by, bz, qx, qy, qz, qw
		p.meshLast = lb
		for _, o in ipairs(p.meshObjects) do
			local obj = o.obj
			if obj then
				obj:setPosRot(bx, by, bz, qx, qy, qz, qw)
				obj:updateInstanceRenderData()
			end
		end
	end
	if (cfg.wheels or p.wheelObjects) and shape.wheels then -- real wheel objects are moved even with drawn wheels off
		-- jbeam wheels: centers, axes, radius and width in the same jbeam space as the body mesh
		local steer = math.max(-1, math.min(1, p.steer or 0)) * MAX_STEER
		local sc, ss = math.cos(steer), math.sin(steer)
		local objs = p.wheelShape == shape and p.wheelObjects or nil
		local dt = math.min(math.max(clock - (p.wheelT or clock), 0), 0.25)
		p.wheelT = clock
		-- rolling: forward speed (jbeam -Y) over the radius
		local vf = 0
		if objs and p.svel then vf = -(p.svel.x * axY.x + p.svel.y * axY.y + p.svel.z * axY.z) end
		for i, w in ipairs(shape.wheels) do
			local o = objs and objs[i]
			if o and o.obj then
				local roll = (o.roll + vf * dt / math.max(w.r, 0.1)) % TWO_PI
				o.roll = roll
				local st = w.s and steer or 0
				local cs, sn, cr, sr = math.cos(st), math.sin(st), math.cos(roll), math.sin(roll)
				-- wheel axes in jbeam space: roll about the axle (X), then steer about Z
				local yx, yy, yz = -sn * cr, cs * cr, sr
				local zx, zy, zz = sn * sr, -cs * sr, cr
				wheelDir:set(axX.x*yx + axY.x*yy + axZ.x*yz, axX.y*yx + axY.y*yy + axZ.y*yz, axX.z*yx + axY.z*yy + axZ.z*yz)
				wheelUp:set(axX.x*zx + axY.x*zy + axZ.x*zz, axX.y*zx + axY.y*zy + axZ.y*zz, axX.z*zx + axY.z*zy + axZ.z*zz)
				wheelQuat:setFromDir(wheelDir, wheelUp)
				local px, py, pz = toWorld(w.x, w.y, w.z + (susp and susp.off[i] or 0))
				local q = wheelQuat
				local l = o.last
				-- wheels: 5 mm and 0.5 deg of roll / steer (1 - cos(0.25 deg) = 9.5e-6) against the last sent pose
				if not (cfg.skipStatic and l and (l[1] - px)^2 + (l[2] - py)^2 + (l[3] - pz)^2 < 2.5e-5
					and math.abs(l[4] * q.x + l[5] * q.y + l[6] * q.z + l[7] * q.w) > 1 - 9.5e-6) then
					l = l or {}
					l[1], l[2], l[3], l[4], l[5], l[6], l[7] = px, py, pz, q.x, q.y, q.z, q.w
					o.last = l
					o.obj:setPosRot(px, py, pz, q.x, q.y, q.z, q.w)
				end
			end
			local real = o and o.obj and o.info
			if real and not real.rim then -- a tire mesh without its rim: a plain disc inside it
				local ax, ay, az = w.ax, w.ay, w.az
				if w.s and steer ~= 0 then ax, ay = ax * sc - ay * ss, ax * ss + ay * sc end
				local h = w.wd * 0.42
				local wz = w.z + (susp and susp.off[i] or 0)
				local x1, y1, z1 = toWorld(w.x - ax * h, w.y - ay * h, wz - az * h)
				local x2, y2, z2 = toWorld(w.x + ax * h, w.y + ay * h, wz + az * h)
				drawCylinder(x1, y1, z1, x2, y2, z2, w.r * 0.62, rimColor, true)
			end
			if (cfg.wheels or real) and not (real and real.tire) then -- drawn tire when there is no tire mesh
				local ax, ay, az = w.ax, w.ay, w.az
				if w.s and steer ~= 0 then ax, ay = ax * sc - ay * ss, ax * ss + ay * sc end
				local h = w.wd * 0.5
				local wz = w.z + (susp and susp.off[i] or 0)
				local x1, y1, z1 = toWorld(w.x - ax * h, w.y - ay * h, wz - az * h)
				local x2, y2, z2 = toWorld(w.x + ax * h, w.y + ay * h, wz + az * h)
				drawCylinder(x1, y1, z1, x2, y2, z2, w.r, wheelColor, true)
			end
		end
	elseif cfg.wheels and shape.minX then
		local W, L, H = shape.maxX - shape.minX, shape.maxY - shape.minY, shape.maxZ - shape.minZ
		local radius = math.min(math.max(H * 0.22, 0.28), 0.55)
		local gz = (shape.groundZ or 0) + radius
		local xo, xi = W * 0.5 - 0.03, W * 0.5 - 0.25
		local yf, yr = cy - L * 0.32, cy + L * 0.32 -- -Y is the front
		-- front wheels turn with the last steering input of the remote driver (BeamMP inputs packet, -1..1)
		local steer = math.max(-1, math.min(1, p.steer or 0)) * MAX_STEER
		local sx, sy = math.cos(steer), math.sin(steer)
		local half = (xo - xi) * 0.5
		for side = -1, 1, 2 do
			for w = 1, 2 do
				local y = w == 1 and yf or yr
				local mx = cx + side * (xi + xo) * 0.5
				local ax, ay = half, 0
				if w == 1 and steer ~= 0 then ax, ay = half * sx, half * sy end
				local x1, y1, z1 = toWorld(mx - ax, y - ay, gz)
				local x2, y2, z2 = toWorld(mx + ax, y + ay, gz)
				drawCylinder(x1, y1, z1, x2, y2, z2, radius, wheelColor, true)
			end
		end
	end
	return true
end

local buildTimer = nil -- lazy, see MPProxyGE.getPerfTimer
local buildStats = { ms = 0, frames = 0, maxMs = 0 }

-- ============= LOADING OVERLAY =============
local imgui = ui_imgui
local niceNames = {}
local function niceName(model)
	local n = niceNames[model]
	if n then return n end
	local ok, m = pcall(core_vehicles.getModel, model) -- cached by the game per model
	local info = ok and type(m) == "table" and m.model or nil
	if info and info.Name then
		n = (info.Brand and info.Brand ~= "" and not string.find(info.Name, info.Brand, 1, true)) and (info.Brand .. " " .. info.Name) or info.Name
	else
		n = tostring(model)
	end
	niceNames[model] = n
	return n
end

local overlayFlags = nil
local function drawOverlay()
	if not imgui or not imgui.Begin then return end
	local cjob = currentJob and not currentJob.job.prebuild and currentJob.job or nil
	local current = cjob and cjob.model or jobs[1] and jobs[1].model or waitingLoad[1]
	local text
	if current then
		local more = #jobs + #waitingLoad + (cjob and 1 or 0) - 1
		text = "Loading vehicle " .. niceName(current) .. "..." .. (more > 0 and string.format(" (+%d more)", more) or "")
	elseif pb.current and (clock < pb.showUntil or #pb.compile > 0 or #prebuildJobs > 0 or (currentJob and currentJob.job.prebuild)) then
		-- prebuild / compile: the current item stays up while the queue is not empty (and at least 0.5 s), no flicker
		text = string.format("%s vehicle %s... (%d/%d)", pb.verb or "Prebuilding", niceName(pb.current), math.min(pb.done + 1, math.max(pb.queued, 1)), math.max(pb.queued, 1))
		if pb.verb == "Compiling" then text = string.format("Compiling vehicle %s... (%d left)", niceName(pb.current), #pb.compile) end
	end
	if not text then return end
	if not overlayFlags then
		overlayFlags = imgui.flags(imgui.WindowFlags_NoTitleBar, imgui.WindowFlags_NoResize, imgui.WindowFlags_NoMove,
			imgui.WindowFlags_NoScrollbar, imgui.WindowFlags_NoCollapse, imgui.WindowFlags_NoDocking, imgui.WindowFlags_NoInputs,
			imgui.WindowFlags_AlwaysAutoResize, imgui.WindowFlags_NoSavedSettings, imgui.WindowFlags_NoFocusOnAppearing, imgui.WindowFlags_NoNav)
	end
	local vp = imgui.GetMainViewport()
	-- centered on its own size, horizontally in the middle and at 38% of the viewport height (any resolution)
	imgui.SetNextWindowPos(imgui.ImVec2(vp.Pos.x + vp.Size.x * 0.5, vp.Pos.y + vp.Size.y * 0.38), imgui.Cond_Always, imgui.ImVec2(0.5, 0.5))
	imgui.SetNextWindowBgAlpha(0.45)
	if imgui.Begin("##beammpProxyLoading", nil, overlayFlags) then
		imgui.Text(text)
	end
	imgui.End()
end

-- ============= JOIN PRELOAD =============
-- While joining, BeamMP's map loading screen is kept up (core_gamestate loading screen request, same as
-- career does) until the vehicles received on join have their meshes built and imported once, capped by
-- PRELOAD_TIMEOUT. Whatever is left continues in the background with the normal budget.
local PRELOAD_TAG = "beammpProxyPreload"
local PRELOAD_TIMEOUT = 25  -- seconds
local preload = nil

local function finishPreload(reason)
	if not preload then return end
	log('I', 'MPProxyMeshGE', string.format("Join preload finished after %.1f s (%s)", clock - preload.started, reason))
	preload = nil
	frameBudget = cfg.frameBudget
	guihooks.trigger('LoadingInfo', { message = "" })
	if core_gamestate and core_gamestate.requestExitLoadingScreen then core_gamestate.requestExitLoadingScreen(PRELOAD_TAG) end
end

local function startPreload()
	if preload or not cfg.enabled then return end
	if not (MPCoreNetwork and MPCoreNetwork.isMPSession and MPCoreNetwork.isMPSession()) then return end
	if not (core_gamestate and core_gamestate.requestEnterLoadingScreen) then return end
	preload = { started = clock, quietUntil = clock + 6 } -- 6 s for the first spawn packets
	frameBudget = PRELOAD_BUDGET_MS
	core_gamestate.requestEnterLoadingScreen(PRELOAD_TAG)
	log('I', 'MPProxyMeshGE', "Join preload started")
end

M._onRequest = function()
	if preload then preload.quietUntil = math.max(preload.quietUntil, clock + 2) end -- 2 s without new requests before finishing
end

-- imports every ready shape once (hidden pooled TSStatic), so the first real use does not hitch
local function preImport()
	local done = 0
	for _, shape in pairs(shapes) do
		if shape.state == "ready" and shape.paths and not shape.loaded then
			for _, path in ipairs(shape.paths) do -- every tier
				if not importedPaths[path] then
					local t = TIMER()
					local cdae = hasCdae(path)
					importedPaths[path] = true
					local id = takeStatic(path)
					if id then returnStatic(path, id) end
					log('I', 'MPProxyMeshGE', string.format("Engine import of %s (loading screen preload): %.1f ms, compiled .cdae was %s",
						string.match(path, "([^/]+)$") or path, t:stop(), cdae and "on disk" or "not on disk (compiled now)"))
					done = done + 1
				end
			end
			shape.loaded = true
			if done >= 1 then return true end -- one import per frame keeps the loading screen animating
		end
	end
	return done > 0
end

local function updatePreload()
	if not preload then return end
	local busy = currentJob ~= nil or #jobs > 0
	local imported = preImport()
	local current = currentJob and currentJob.job.model or jobs[1] and jobs[1].model
	if current then
		guihooks.trigger('LoadingInfo', { message = string.format("Preparing vehicles: %s (%d left)", tostring(current), #jobs + 1) })
	end
	if clock - preload.started > PRELOAD_TIMEOUT then finishPreload("timeout, continuing in background")
	elseif not busy and not imported and clock > preload.quietUntil then finishPreload("all vehicles ready") end
end

-- last use times of the cache files (written at mission end and unload, read by the size cap)
local function saveUsed()
	if PC.usedDirty and PC.used then
		FS:directoryCreate(CACHE_DIR, true)
		jsonWriteFile(CACHE_DIR .. "lru_" .. CACHE_VERSION .. "_used.json", PC.used, false)
		PC.usedDirty = false
	end
end

-- removes cache files of older CACHE_VERSIONs (and their engine .cdae copies), then keeps the current .dae files
-- under proxyMeshCacheMaxGB (0 = no cap): least recently used first (last import, else file time), with their .cdae
local function cleanOldCache()
	local removed, bytes = 0, 0
	for _, dir in ipairs({ CACHE_DIR, "/temp" .. CACHE_DIR }) do
		for _, f in ipairs(FS:findFiles(dir, "*", 0, false, false) or {}) do
			local name = string.match(f, "([^/]+)$") or f
			local current = string.find(name, "_" .. CACHE_VERSION .. "_", 1, true) or string.find(name, "_parts_" .. CACHE_VERSION .. ".json", 1, true)
			-- wheel_v5_* / wheelmeshes_v5_*: wheel files of the first real wheel version (found by guessed file names)
			if string.find(name, "^wheel_") or string.find(name, "^wheelmeshes_") then current = nil end
			if not current and name ~= "main.materials.json" then
				local st = FS:stat(f)
				bytes = bytes + (st and tonumber(st.filesize) or 0)
				FS:removeFile(f)
				removed = removed + 1
			end
		end
	end
	if removed > 0 then log('I', 'MPProxyMeshGE', string.format("Removed %d old proxy mesh cache files (%.2f GB freed)", removed, bytes / 1073741824)) end
	local usedFile = CACHE_DIR .. "lru_" .. CACHE_VERSION .. "_used.json"
	local used = FS:fileExists(usedFile) and jsonReadFile(usedFile) or nil
	PC.used = type(used) == "table" and used or {}
	local cap = (tonumber(settings.getValue("proxyMeshCacheMaxGB", 4)) or 4) * 1073741824
	local files, total = {}, 0
	for _, f in ipairs(FS:findFiles(CACHE_DIR, "*.dae", 0, false, false) or {}) do
		local st, cst = FS:stat(f), FS:stat("/temp" .. string.gsub(f, "%.dae$", ".cdae"))
		local size = (st and tonumber(st.filesize) or 0) + (cst and tonumber(cst.filesize) or 0)
		files[#files + 1] = { f = f, size = size, t = math.max(tonumber(PC.used[f]) or 0, st and tonumber(st.modtime) or 0) }
		total = total + size
	end
	local pruned, prunedBytes = 0, 0
	if cap > 0 and total > cap then
		table.sort(files, function(a, b) if a.t ~= b.t then return a.t < b.t end return a.f < b.f end)
		for _, e in ipairs(files) do
			if total <= cap then break end
			FS:removeFile(e.f)
			local c = "/temp" .. string.gsub(e.f, "%.dae$", ".cdae")
			if FS:fileExists(c) then FS:removeFile(c) end
			PC.used[e.f] = nil
			total, pruned, prunedBytes = total - e.size, pruned + 1, prunedBytes + e.size
		end
		PC.usedDirty = true
		saveUsed()
	end
	log('I', 'MPProxyMeshGE', string.format("Proxy mesh cache: %.2f GB in %d files (cap %s)%s", total / 1073741824, #files - pruned,
		cap > 0 and string.format("%.0f GB", cap / 1073741824) or "off",
		pruned > 0 and string.format(", removed %d least recently used (%.2f GB)", pruned, prunedBytes / 1073741824) or ""))
end

-- prebuild coverage (settings tab button, never on its own): how many installed models have their default config
-- proxy mesh built and compiled. Spread over frames (1 ms each), it reads one .pc and one cache .json per model.
local scan = nil
local function stepScan()
	local t0 = os.clock()
	while scan.i < #scan.models and os.clock() - t0 < 0.001 do
		scan.i = scan.i + 1
		local model = scan.models[scan.i]
		local vcf = defaultConfig(model)
		if not vcf then scan.noConfig = scan.noConfig + 1
		else
			local key = configKey(model, vcf)
			local meta = FS:fileExists(CACHE_DIR .. key .. ".json") and jsonReadFile(CACHE_DIR .. key .. ".json") or nil
			local paths = type(meta) == "table" and type(meta.paths) == "table" and meta.paths or nil
			if not paths or #paths == 0 then scan.missing = scan.missing + 1
			else
				local all = true
				for _, path in ipairs(paths) do if not hasCdae(path) then all = false break end end
				if all then scan.ready = scan.ready + 1 else scan.built = scan.built + 1 end
			end
		end
	end
	if scan.i < #scan.models then return end
	local n = #scan.models - scan.noConfig
	local msg = string.format("%d of %d models ready (%d%%), %d built but not compiled yet, %d not built%s", scan.ready, n,
		n > 0 and math.floor(scan.ready * 100 / n + 0.5) or 0, scan.built, scan.missing,
		scan.noConfig > 0 and string.format(", %d without a default config", scan.noConfig) or "")
	log('I', 'MPProxyMeshGE', string.format("Prebuild coverage: %s (scan %.0f ms over %d frames)", msg, (os.clock() - scan.t0) * 1000, scan.frames))
	guihooks.trigger("toastrMsg", { type = scan.missing + scan.built == 0 and "success" or "info", title = "Proxy prebuild coverage", msg = msg, config = { timeOut = 10000 } })
	scan = nil
end

local function scanCoverage()
	if scan then return end
	local ok, list = pcall(function() return core_vehicles.getModelList().models end)
	local models = {}
	for name, info in pairs(ok and type(list) == "table" and list or {}) do
		if type(info) == "table" and info.Type ~= "Prop" and name ~= "unicycle" then models[#models + 1] = name end
	end
	table.sort(models)
	scan = { models = models, i = 0, ready = 0, built = 0, missing = 0, noConfig = 0, t0 = os.clock(), frames = 0 }
	guihooks.trigger("toastrMsg", { type = "info", title = "Proxy prebuild coverage", msg = string.format("Scanning %d models...", #models), config = { timeOut = 3000 } })
end

local function onUpdate(dtReal)
	clock = clock + (dtReal or 0)
	suspFrame = suspFrame + 1
	if scan then scan.frames = scan.frames + 1 stepScan() end
	if not cfg.enabled then return end
	updateFpsCap(dtReal or 0, clock)
	if currentJob or #jobs > 0 or #wheelJobs > 0 then
		if buildTimer == nil then
			local ok, t = pcall(function() return (hptimer and hptimer()) or (HighPerfTimer and HighPerfTimer()) end)
			buildTimer = ok and t or false
		end
		if buildTimer then buildTimer:stopAndReset() end
		stepJobs()
		if buildTimer then
			local ms = buildTimer:stop()
			buildStats.ms, buildStats.frames = buildStats.ms + ms, buildStats.frames + 1
			if ms > buildStats.maxMs then buildStats.maxMs = ms end
		end
	end
	-- prebuild: its own queue, kept going whenever enabled (stepJobs only takes it when nothing else is queued)
	if cfg.prebuild and not currentJob and #jobs == 0 and #wheelJobs == 0 and #prebuildJobs > 0 then stepJobs() end
	updatePreload()
	-- compile prebuilt / cached sets (.dae -> .cdae through the engine import): one per frame on the loading screen,
	-- else paced like first uses and only when no proxy needs anything
	local nc = pb.compile[1]
	if nc then
		local idle = not (currentJob and not currentJob.job.prebuild) and #jobs == 0 and #waitingLoad == 0
		if preload or (idle and clock >= nextNewShapeAllowed) then
			table.remove(pb.compile, 1)
			if not importedPaths[nc.path] and not hasCdae(nc.path) then
				local t = TIMER()
				importedPaths[nc.path] = true
				local id = takeStatic(nc.path)
				if id then returnStatic(nc.path, id) end
				cdaeCache[nc.path] = nil
				pb.compiled = pb.compiled + 1
				pb.current, pb.verb, pb.showUntil = nc.model, "Compiling", clock + 0.5
				if not preload then nextNewShapeAllowed = clock + NEW_SHAPE_INTERVAL end
				log('I', 'MPProxyMeshGE', string.format("Prebuild compile of %s (%s): %.1f ms, .cdae now %s%s", string.match(nc.path, "([^/]+)$") or nc.path,
					nc.model, t:stop(), hasCdae(nc.path) and "on disk" or "not found yet", preload and ", loading screen" or ""))
			end
		end
	end
	drawOverlay() -- also on the loading screen (whether ImGui shows above the loading UI depends on the UI layering)
	if pb.started and not pb.summary and #prebuildJobs == 0 and #pb.compile == 0 and not (currentJob and currentJob.job.prebuild) then
		pb.summary = true
		log('I', 'MPProxyMeshGE', string.format("Prebuild: %d models queued, %d built, %d compiled, %d skipped (cached)", pb.queued, pb.built, pb.compiled, pb.skipped))
	end
	if cfg.prebuild and not pb.started and MPCoreNetwork and MPCoreNetwork.isMPSession and MPCoreNetwork.isMPSession() then
		pb.started = true
		local ok, list = pcall(function() return core_vehicles.getModelList().models end) -- once per session
		local n = 0
		for name, info in pairs(ok and type(list) == "table" and list or {}) do
			if type(info) == "table" and info.Type ~= "Prop" and name ~= "unicycle" then
				if requestDefault(name, true) then n = n + 1 end
			end
		end
		log('I', 'MPProxyMeshGE', string.format("Prebuilding default config proxy meshes of %d models in the background", n))
	end
end

--- Cache / pool statistics for MPProxyTest.
local function getStats(resetWindow)
	local out = { queued = #jobs + (currentJob and 1 or 0), building = currentJob and currentJob.job and currentJob.job.key or nil,
		ready = 0, failed = 0, liveObjects = liveCount, fpsCap = fps.cap ~= math.huge and fps.cap or nil,
		buildFrames = buildStats.frames, avgBuildMs = buildStats.frames > 0 and buildStats.ms / buildStats.frames or 0, maxBuildMs = buildStats.maxMs }
	for _, sh in pairs(shapes) do
		if sh.state == "ready" then out.ready = out.ready + 1 elseif sh.state == "failed" then out.failed = out.failed + 1 end
	end
	if resetWindow then buildStats.ms, buildStats.frames, buildStats.maxMs = 0, 0, 0 end
	return out
end

local function reset()
	table.clear(waitingLoad)
	table.clear(importedPaths)
	table.clear(cdaeCache)
	for id, _ in pairs(allObjects) do
		local obj = scenetree.findObjectById(id)
		if obj then obj:delete() end
	end
	allObjects = {}
	pools = {}
	liveCount = 0
	table.clear(D.skinFields) -- found / missing skin materials are per mission too
	materialsLoaded = {} -- materials are invalidated on mission end (core_vehicle_manager does the same)
	shapes = {} -- rebuilt from the disk cache (cheap) on the next request
	jobs = {}
	prebuildJobs = {}
	wheelJobs = {}
	wheelFiles = {}
	fallbackOf = {}
	defaultKeys = {}
	pb.started, pb.summary, pb.compile = false, false, {}
	pb.queued, pb.built, pb.compiled, pb.skipped, pb.done, pb.current = 0, 0, 0, 0, 0, nil
	currentJob = nil
end

--- Deletes the objects of a proxy that is going away (vehicle removed or swapped to real).
local function release(p)
	if p then detach(p) end
end

--- Clears the per proxy references after reset (objects are gone).
local function forget(p)
	if p then p.meshObjects = nil p.meshShape = nil p.meshKey = nil p.wheelObjects = nil p.wheelShape = nil end
end

local function onSettingsChanged() readSettings() if not preload then frameBudget = cfg.frameBudget end end
-- TSStatics (body and wheel meshes) of an earlier load of this extension (Lua reload), by their name prefix
local function removeLeftovers()
	local n = 0
	for _, name in ipairs(scenetree.findClassObjects("TSStatic") or {}) do
		if string.find(name, "^beammpProxyMesh") then
			local obj = scenetree.findObject(name)
			if obj and not allObjects[obj:getId()] then obj:delete() n = n + 1 end
		end
	end
	if n > 0 then log('I', 'MPProxyMeshGE', string.format("Removed %d proxy mesh objects of an earlier load", n)) end
end

local function onExtensionLoaded()
	readSettings()
	if settings.getValue("proxyCleanupOnReload", true) ~= false then
		local ok, err = pcall(removeLeftovers)
		if not ok then log('W', 'MPProxyMeshGE', "Leftover cleanup failed: " .. tostring(err)) end
	end
	frameBudget = cfg.frameBudget
	local ok, err = pcall(cleanOldCache)
	if not ok then log('W', 'MPProxyMeshGE', "Cache cleanup failed: " .. tostring(err)) end
end

detectGlobalWrites() -- reenable global write notifications

M.request           = request
M.getShape          = getShape
M.getSound          = getSound
M.getLodSettings    = function() return cfg.lodFull, cfg.lodParts, math.min(cfg.lodShell, cfg.distance) end
M.decide            = decide
M.drawProxy         = drawProxy
M.release           = release
M.forget            = forget
M.reset             = reset
M.onUpdate          = onUpdate
M.getStats          = getStats
M.scanCoverage      = scanCoverage
M.isEnabled         = function() return cfg.enabled end
M.onSettingsChanged = onSettingsChanged
M.onExtensionLoaded = onExtensionLoaded
M.onClientEndMission = function() finishPreload("mission ended") saveUsed() reset() end
M.onExtensionUnloaded = function() saveUsed() end
M.onClientStartMission = startPreload
M.onInit = function() setExtensionUnloadMode(M, "manual") end

return M
