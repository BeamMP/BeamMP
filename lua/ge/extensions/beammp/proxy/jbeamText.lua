-- Copyright (C) 2026 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- beammp.proxy.jbeamText - jbeam text scanning (flexbodies, wheel and engine sections) and jbeam value expressions.
-- Split out of MPProxyMeshGE.lua (Lua's 200 locals per function limit). No state of its own besides memo caches;
-- the long loops call the budget check MPProxyMeshGE installs with setBudgetCheck (yields inside its build coroutine).
local M = {}

local READ_CHUNK = 128 * 1024 -- bytes per read step, same as MPProxyMeshGE
local checkBudget = function() end
function M.setBudgetCheck(fn) checkBudget = fn or function() end end

local function isOffsetModifier(row)
	local function nz(t) return type(t) == "table" and ((t.x or 0) ~= 0 or (t.y or 0) ~= 0 or (t.z or 0) ~= 0) end
	local s = row.scale
	return nz(row.pos) or nz(row.rot) or (type(s) == "table" and ((s.x or 1) ~= 1 or (s.y or 1) ~= 1 or (s.z or 1) ~= 1))
end

-- flexbody rows that are never part of the body mesh sets: wheels, tires, hubcaps and brakes (bound to wheel /
-- tire / hubcap / wheelhub groups, they come from the wheel system), and rows placed by their own pos / rot /
-- scale (the body sets use the raw mesh position, those would end up at the vehicle origin)
local BODY_SKIP_GROUPS = { wheel = true, tire = true, tyre = true, hubcap = true, rim = true, wheelhub = true }

local function isWheelFlexRow(row)
	local last = row[#row]
	if #row > 1 and type(last) == "table" and last[1] == nil and isOffsetModifier(last) then return true end
	if type(row[2]) == "table" then
		for _, g in ipairs(row[2]) do
			local pre = type(g) == "string" and string.match(g, "^(%a+)_")
			if pre and BODY_SKIP_GROUPS[string.lower(pre)] then return true end
		end
	end
	return false
end

-- Finds the "flexbodies" array of every part in a jbeam text without decoding the file: a large jbeam (nodes,
-- beams, triangles of a body) took tens of ms in one jsonDecode. Strings, // and /* */ comments are skipped,
-- out[partName] = text of the part's flexbodies array (decoded alone, it is small). Returns false if the text
-- did not look like a jbeam (the caller then decodes the whole file).
-- array sections read for the wheel placement (wheelSecs[partName][key] = array text); nodes only of parts
-- that also have a wheel section (hubs, wheels, suspension), body node lists are big and not needed
-- node: default nodeWeight of the jbeam loader (lua/common/jbeam/loader.lua); wheel: pressure wheel nodes are
-- generated at spawn, a rough wheel + tire mass instead
local MASS = { node = 25, wheel = 30, skinKeys = { slotType = true, skinType = true, skinName = true, globalSkin = true } } -- skinKeys: livery fields

local WHEEL_KEYS = { slots = true, slots2 = true, pressureWheels = true, hubWheels = true, variables = true, nodes = true }

local function extractFlexbodies(text, out, sections, wheelSecs)
	local find, sub, byte, match = string.find, string.sub, string.byte, string.match
	local pos, depth, n = 1, 0, 0
	local partName, flexStart = nil, nil
	local secStart, secKey = nil, nil -- engine / sound sections (sections[partName][key] = object text)
	local arrStart, arrKey = nil, nil -- wheel related array sections
	local partSecs, nodesFrom, nodesTo = nil, nil, nil
	local lastString, lastDepth, lastEnd = nil, -1, 0
	while true do
		local s = find(text, '[{}%[%]"/]', pos)
		if not s then break end
		local c = byte(text, s)
		if c == 34 then -- string
			local e = s + 1
			while true do
				local q = find(text, '["\\]', e)
				if not q then return false end
				if byte(text, q) == 92 then e = q + 2 else e = q break end
			end
			local str = sub(text, s + 1, e - 1)
			-- livery: string fields of the part ("slotType": "paint_design", "globalSkin": "police", ...)
			if depth == 2 and partName and wheelSecs and lastString and lastDepth == 2 and MASS.skinKeys[lastString]
				and match(sub(text, lastEnd + 1, s - 1), "^%s*:%s*$") then
				partSecs = partSecs or {}
				partSecs.skin = partSecs.skin or {}
				partSecs.skin[lastString] = str
			end
			lastString, lastDepth, lastEnd = str, depth, e
			pos = e + 1
		elseif c == 47 then -- comment
			local nx = byte(text, s + 1)
			if nx == 47 then local e = find(text, "\n", s + 2, true) pos = e and e + 1 or #text + 1
			elseif nx == 42 then local e = find(text, "*/", s + 2, true) pos = e and e + 2 or #text + 1
			else pos = s + 1 end
		elseif c == 123 or c == 91 then
			depth = depth + 1
			local isKey = lastString and lastDepth == depth - 1 and match(sub(text, lastEnd + 1, s - 1), "^%s*:%s*$")
			if depth == 2 and c == 123 then partName = isKey and lastString or nil partSecs, nodesFrom = nil, nil
			elseif depth == 3 and c == 91 and isKey and lastString == "flexbodies" and partName then flexStart = s
			elseif depth == 3 and c == 91 and isKey and partName and wheelSecs and WHEEL_KEYS[lastString] then arrStart, arrKey = s, lastString
			elseif depth == 3 and c == 123 and isKey and partName and sections
				and (lastString == "mainEngine" or sub(lastString, 1, 11) == "soundConfig" or lastString == "gearbox"
					or sub(lastString, 1, 12) == "differential") then secStart, secKey = s, lastString end
			lastString = nil
			pos = s + 1
		else
			if depth == 3 and flexStart and c == 93 then out[partName] = sub(text, flexStart, s) flexStart = nil end
			if depth == 3 and secStart and c == 125 then
				sections[partName] = sections[partName] or {}
				sections[partName][secKey] = sub(text, secStart, s)
				secStart = nil
			end
			if depth == 3 and arrStart and c == 93 then
				if arrKey == "nodes" then nodesFrom, nodesTo = arrStart, s
				else partSecs = partSecs or {} partSecs[arrKey] = sub(text, arrStart, s) end
				arrStart = nil
			end
			if depth == 2 then
				if nodesFrom then -- every part's nodes: wheel placement and the mass estimate (centre of mass)
					partSecs = partSecs or {}
					partSecs.nodes = sub(text, nodesFrom, nodesTo)
				end
				if partSecs then
					wheelSecs[partName] = partSecs
				end
				partName, partSecs, nodesFrom = nil, nil, nil
			end
			depth = depth - 1
			if depth < 0 then return false end
			lastString = nil
			pos = s + 1
		end
		n = n + 1
		if n >= 400 then n = 0 checkBudget() end
	end
	return depth == 0
end

-- fields kept from the jbeam engine device and its sound sections (as read by combustionEngine.lua init)
local ENGINE_FIELDS = { idleRPM = true, maxRPM = true, revLimiterRPM = true, soundConfig = true, soundConfigExhaust = true, requiredEnergyType = true }

local SOUND_FIELDS = { sampleName = true, sampleFolder = true, mainGain = true, onLoadGain = true, offLoadGain = true,
	intakeMuffling = true, exhaustAudioMufflingBaseCoef = true }

local function keepFields(decoded, fields)
	local out, any = {}, false
	for k in pairs(fields) do
		local v = decoded[k]
		if type(v) == "number" or (type(v) == "string" and string.sub(v, 1, 1) ~= "$") then out[k] = v any = true end
	end
	return any and out or nil
end

-- gearbox / differential sections: the ratios, numbers or "$variable" / "$=expression" strings (evaluated
-- with the config's variables by the caller, see evalVal)
local function keepGearing(d)
	local out = nil
	if type(d.gearRatios) == "table" then
		local list = {}
		for i, v in ipairs(d.gearRatios) do
			if type(v) == "number" or type(v) == "string" then list[i] = v else list = nil break end
		end
		if list and #list > 0 then out = { gearRatios = list } end
	end
	if type(d.gearRatio) == "number" or type(d.gearRatio) == "string" then out = out or {} out.gearRatio = d.gearRatio end
	return out
end

-- engine[partName] = { mainEngine = {...}, [soundConfig section name] = {...}, gearbox = {...}, differential_X = {...} }
local function addEngineSections(engine, sectionTexts, filename)
	for partName, secs in pairs(sectionTexts) do
		for key, txt in pairs(secs) do
			local ok, d = pcall(jsonDecode, txt, filename)
			local gearing = key == "gearbox" or string.sub(key, 1, 12) == "differential"
			local kept = ok and type(d) == "table" and (gearing and keepGearing(d) or (not gearing and keepFields(d, key == "mainEngine" and ENGINE_FIELDS or SOUND_FIELDS))) or nil
			if kept then
				engine[partName] = engine[partName] or {}
				engine[partName][key] = kept
			end
			checkBudget()
		end
	end
end

local WHEEL_OPTS = { radius = true, tireWidth = true, hubRadius = true, hubWidth = true, wheelOffset = true, offsetFromNode = true }

local function scalar(v) return (type(v) == "number" or type(v) == "string") and v or nil end

local function vec3Raw(o) return type(o) == "table" and { scalar(o.x) or 0, scalar(o.y) or 0, scalar(o.z) or 0 } or false end

local function headerIndex(row, names)
	local idx = {}
	if type(row) ~= "table" then return idx end
	for i, v in ipairs(row) do if names[v] then idx[v] = i end end
	return idx
end

-- slots (child slot types / names, slot nodeOffset), variable defaults, wheel rows and options in order,
-- and node positions with their nodeOffset modifiers
local function compactWheelPart(secs, filename)
	local function dec(key)
		local t = secs[key]
		if not t then return nil end
		local ok, d = pcall(jsonDecode, t, filename)
		checkBudget()
		return ok and type(d) == "table" and d or nil
	end
	local out, any = {}, false
	if type(secs.skin) == "table" and (secs.skin.skinName or secs.skin.globalSkin) then out.skin = secs.skin any = true end
	local is2 = secs.slots2 ~= nil
	local sl = dec(is2 and "slots2" or "slots")
	if sl then
		local list = {}
		for _, row in ipairs(sl) do
			if type(row) == "table" and type(row[1]) == "string" and row[1] ~= "type" and row[1] ~= "name" then
				local e = { n = row[1], t = row[1] }
				if is2 then local a = row[2] e.t = type(a) == "table" and a[1] or (type(a) == "string" and a) or row[1] end
				for i = 2, #row do
					if type(row[i]) == "table" and row[i].nodeOffset then e.o = vec3Raw(row[i].nodeOffset) end
				end
				list[#list + 1] = e
			end
		end
		if #list > 0 then out.slots = list any = true end
	end
	local vars = dec("variables")
	if vars then
		local h = headerIndex(vars[1], { name = true, default = true })
		local di = h.default or 5
		local v = {}
		for i, row in ipairs(vars) do
			if i > 1 and type(row) == "table" and type(row[1]) == "string" and scalar(row[di]) then v[row[1]] = row[di] any = true end
		end
		if any then out.vars = v end
	end
	local pw = dec("pressureWheels") or dec("hubWheels")
	if pw then
		local h = headerIndex(pw[1], { ["node1:"] = true, ["node2:"] = true, wheelDir = true })
		local list = {}
		for i, row in ipairs(pw) do
			if type(row) == "table" then
				if row[1] == nil then -- options
					local o, has = {}, false
					for k in pairs(WHEEL_OPTS) do if scalar(row[k]) then o[k] = row[k] has = true end end
					if has then list[#list + 1] = { o = o } end
				elseif i > 1 and type(row[1]) == "string" and h["node1:"] and h["node2:"] then
					local last = row[#row]
					list[#list + 1] = { w = row[1], a = row[h["node1:"]], b = row[h["node2:"]], d = tonumber(row[h.wheelDir or 0]) or 1,
						s = type(last) == "table" and (last["steerAxisUp:"] ~= nil or last.steerAxisUp ~= nil) or nil }
				end
			end
		end
		if #list > 0 then out.pw = list any = true end
	end
	local nodes = dec("nodes")
	if nodes then
		local list = {}
		-- mass buckets per nodeOffset group: weight, weighted x / y / z sums and the weight on each x side
		-- (the slot / modifier offset moves x away from the centre line, see moved() in resolveWheels)
		local groups, g, weight, lastOff = {}, nil, MASS.node, nil
		for _, row in ipairs(nodes) do
			if type(row) == "table" then
				if row[1] == nil then
					if row.nodeOffset ~= nil then lastOff = vec3Raw(row.nodeOffset) list[#list + 1] = { off = lastOff } g = nil end
					if row.nodeWeight ~= nil then weight = tonumber(row.nodeWeight) or MASS.node end
				elseif type(row[1]) == "string" and row[1] ~= "id" and scalar(row[2]) and scalar(row[3]) and scalar(row[4]) then
					if out.pw then list[#list + 1] = { row[1], scalar(row[2]), scalar(row[3]), scalar(row[4]) } end
					local x, y, z = tonumber(row[2]), tonumber(row[3]), tonumber(row[4])
					local last = row[#row]
					local wt = type(last) == "table" and tonumber(last.nodeWeight) or weight
					if x and y and z and wt and wt > 0 then
						if not g then
							-- mod: an explicit modifier row (false = reset to the slot offset), else the slot offset applies
							g = { w = 0, x = 0, y = 0, z = 0, p = 0, n = 0, o = lastOff or nil, mod = lastOff ~= nil or nil }
							groups[#groups + 1] = g
						end
						g.w, g.x, g.y, g.z = g.w + wt, g.x + wt * x, g.y + wt * y, g.z + wt * z
						if x > 0 then g.p = g.p + wt elseif x < 0 then g.n = g.n + wt end
					end
				end
			end
		end
		if out.pw and #list > 0 then out.nodes = list end
		if #groups > 0 then out.mass = groups any = true end
	end
	return any and out or nil
end

-- positioned flexbodies of the wheels (rim, tire, hubcap): mesh, the wheel names from its groups ("tire_FR" -> FR),
-- pos / rot / scale as written (values may be "$var" / "$=" expressions, evaluated per config)
local WHEEL_GROUPS = { wheel = true, tire = true, tyre = true, hubcap = true, rim = true, wheelhub = "d", hub = "d", brake = "d" } -- "d": detail

local function compactWheelFlex(text, filename)
	if not (string.find(text, "tire_", 1, true) or string.find(text, "wheel_", 1, true) or string.find(text, "hubcap_", 1, true)
		or string.find(text, "hub_", 1, true) or string.find(text, "brake_", 1, true)) then return nil end
	local ok, rows = pcall(jsonDecode, text, filename)
	checkBudget()
	if not ok or type(rows) ~= "table" then return nil end
	local list = {}
	for _, row in ipairs(rows) do
		if type(row) == "table" and type(row[1]) == "string" and row[1] ~= "mesh" and type(row[2]) == "table" then
			local opt = row[#row]
			opt = (type(opt) == "table" and opt[1] == nil and type(opt.pos) == "table") and opt or nil
			local sides, seen, tire, detail = {}, {}, nil, true
			for _, g in ipairs(row[2]) do
				local pre, side = string.match(type(g) == "string" and g or "", "^(%a+)_(.+)$")
				pre = pre and string.lower(pre)
				if pre and WHEEL_GROUPS[pre] and WHEEL_GROUPS[pre] ~= "d" then detail = nil end
				if pre and WHEEL_GROUPS[pre] and not seen[side] then seen[side] = true sides[#sides + 1] = side end
				if pre == "tire" or pre == "tyre" then tire = true end
			end
			if opt and #sides > 0 then
				list[#list + 1] = { m = row[1], w = sides, p = vec3Raw(opt.pos), r = vec3Raw(opt.rot) or nil, s = vec3Raw(opt.scale) or nil, t = tire, d = detail }
			end
		end
	end
	return #list > 0 and list or nil
end

local function addWheelParts(into, wheelSecs, filename, flexTexts)
	for partName, secs in pairs(wheelSecs) do
		local c = compactWheelPart(secs, filename)
		if c then into[partName] = c end
	end
	for partName, text in pairs(flexTexts or {}) do
		local fb = compactWheelFlex(text, filename)
		if fb then
			into[partName] = into[partName] or {}
			into[partName].fb = fb
		end
	end
end

-- jbeam values: numbers, "$var", or "$=expression" (arithmetic, comparisons, and/or/not, case(c1, v1, ..., default),
-- min/max/abs...). Unknown variables (also "$components.x") become nil like in the game's evaluator.
local EXPR_NAMES = { ["nil"] = true, ["true"] = true, ["false"] = true, ["and"] = true, ["or"] = true, ["not"] = true,
	__case = true, min = true, max = true, abs = true, floor = true, ceil = true, sqrt = true, clamp = true }

local EXPR_ENV = { min = math.min, max = math.max, abs = math.abs, floor = math.floor, ceil = math.ceil, sqrt = math.sqrt,
	clamp = function(x, a, b) return math.min(math.max(x, a), b) end,
	__case = function(...)
		local n = select("#", ...)
		local args = { ... }
		for i = 1, n - 1, 2 do if args[i] then return args[i + 1] end end
		if n % 2 == 1 then return args[n] end
		return nil
	end }

local exprCache = {}

local function evalVal(v, vars)
	if type(v) == "number" then return v end
	if type(v) ~= "string" then return nil end
	if string.sub(v, 1, 2) == "$=" then
		local expr = string.gsub(string.sub(v, 3), "%$([%w_%.]+)", function(n)
			local x = tonumber(vars["$" .. n])
			return x and string.format("(%.17g)", x) or "nil"
		end)
		expr = string.gsub(expr, "!=", "~=")
		expr = string.gsub(expr, "&&", " and ")
		expr = string.gsub(expr, "||", " or ")
		expr = string.gsub(expr, "case%(", "__case(")
		for name in string.gmatch(expr, "[%a_][%w_]*") do
			if not EXPR_NAMES[name] and not string.match(name, "^[eE]%d*$") then return nil end
		end
		if string.find(expr, "[^%w_%.%+%-%*/%(%)%s,<>=~^%%]") then return nil end
		local fn = exprCache[expr]
		if fn == nil then
			fn = loadstring("return " .. expr) or false
			if fn then setfenv(fn, EXPR_ENV) end
			exprCache[expr] = fn
		end
		if not fn then return nil end
		local ok, r = pcall(fn)
		return ok and tonumber(r) or nil
	elseif string.sub(v, 1, 1) == "$" then
		return tonumber(vars[v])
	end
	return tonumber(v)
end

M.isOffsetModifier = isOffsetModifier
M.BODY_SKIP_GROUPS = BODY_SKIP_GROUPS
M.isWheelFlexRow = isWheelFlexRow
M.MASS = MASS
M.WHEEL_KEYS = WHEEL_KEYS
M.extractFlexbodies = extractFlexbodies
M.ENGINE_FIELDS = ENGINE_FIELDS
M.SOUND_FIELDS = SOUND_FIELDS
M.keepFields = keepFields
M.addEngineSections = addEngineSections
M.WHEEL_OPTS = WHEEL_OPTS
M.scalar = scalar
M.vec3Raw = vec3Raw
M.headerIndex = headerIndex
M.compactWheelPart = compactWheelPart
M.WHEEL_GROUPS = WHEEL_GROUPS
M.compactWheelFlex = compactWheelFlex
M.addWheelParts = addWheelParts
M.EXPR_NAMES = EXPR_NAMES
M.EXPR_ENV = EXPR_ENV
M.exprCache = exprCache
M.evalVal = evalVal

return M
