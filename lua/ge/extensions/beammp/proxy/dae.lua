-- Copyright (C) 2026 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- beammp.proxy.dae - collada (.dae) streaming, filtering and merging for proxy meshes.
-- Split out of MPProxyMeshGE.lua (Lua's 200 locals per function limit). No state of its own besides memo caches;
-- the long loops call the budget check MPProxyMeshGE installs with setBudgetCheck (yields inside its build coroutine).
local M = {}

local READ_CHUNK = 128 * 1024 -- bytes per read step, same as MPProxyMeshGE
local checkBudget = function() end
function M.setBudgetCheck(fn) checkBudget = fn or function() end end

local function updateBBox(bbox, geometryBlock)
	local arr = string.match(geometryBlock, '<float_array id="[^"]*positions%-array" count="%d+">([^<]*)</float_array>')
	if not arr then return end
	local i, n = 0, 0
	local x, y = 0, 0
	for num in string.gmatch(arr, "%S+") do
		local v = tonumber(num) or 0
		local axis = i % 3
		if axis == 0 then x = v elseif axis == 1 then y = v else
			if x < bbox[1] then bbox[1] = x end
			if x > bbox[4] then bbox[4] = x end
			if y < bbox[2] then bbox[2] = y end
			if y > bbox[5] then bbox[5] = y end
			if v < bbox[3] then bbox[3] = v end
			if v > bbox[6] then bbox[6] = v end
		end
		i = i + 1
		n = n + 1
		if n >= 3000 then n = 0 checkBudget() end
	end
end

-- triangles of a geometry block (triangles / polylist / polygons primitives, polygons counted as one each)
local function countTriangles(block)
	local n = 0
	for tag, count in string.gmatch(block, "<(%a+)[^>]-count=\"(%d+)\"") do
		if tag == "triangles" or tag == "polylist" or tag == "polygons" or tag == "tristrips" then n = n + (tonumber(count) or 0) end
	end
	return n
end

--- Streams one .dae. keepGeom(id, name) picks geometry blocks (appended to geoms, ids to keptIds),
-- onNode(block, name, url) sees every flat scene node. geomsOnly stops after the geometry library.
local function scanDae(filename, keepGeom, onNode, geomsOnly, header, geoms, keptIds, bbox)
	local f = io.open(filename, "r")
	if not f then return false end
	local find, sub, match = string.find, string.sub, string.match
	local mode = "header"
	local buf, at = "", 1 -- unconsumed data is buf[at..]; buf is only rebuilt once per read chunk
	local pendGeom = nil -- a geometry longer than a chunk, collected in pieces
	local eof = false
	while true do
		if not eof then
			local chunk = f:read(READ_CHUNK)
			if chunk then
				buf = (at > 1 and sub(buf, at) or buf) .. chunk -- one copy per chunk instead of one per geometry
				at = 1
			else
				eof = true
			end
		end
		local progressed = true
		while progressed do
			progressed = false
			if mode == "header" then
				local s = find(buf, "<library_geometries>", at, true)
				if s then
					header[#header + 1] = sub(buf, at, s - 1)
					at = s + 20
					mode = "geoms"
					progressed = true
				elseif #buf - at > 64 then
					header[#header + 1] = sub(buf, at, #buf - 64)
					at = #buf - 63
				end
			elseif mode == "geoms" then
				local s = find(buf, "<geometry ", at, true)
				local libEnd = find(buf, "</library_geometries>", at, true)
				if libEnd and (not s or libEnd < s) then
					at = libEnd + 21
					mode = geomsOnly and "done" or "prescene"
					progressed = true
				elseif s then
					local e = find(buf, "</geometry>", s, true)
					if e then
						local id, name = match(buf, '^<geometry id="([^"]*)" name="([^"]*)"', s)
						if id and keepGeom(id, name) then
							local block = sub(buf, s, e + 10) -- only kept blocks are copied
							geoms[#geoms + 1] = block
							keptIds[id] = true
							if bbox then -- per geometry local bounds, placed by the node transform later
								local gb = {math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge}
								updateBBox(gb, block)
								gb.tris = countTriangles(block)
								bbox[id] = gb
							end
						end
						at = e + 11
						progressed = true
						checkBudget()
					elseif #buf - s > READ_CHUNK then
						-- long geometry: collect it in pieces (no re-copy and re-search of the growing buffer per chunk)
						local id, name = match(buf, '^<geometry id="([^"]*)" name="([^"]*)"', s)
						local keep = id and keepGeom(id, name)
						pendGeom = { id = id, keep = keep, parts = keep and { sub(buf, s, #buf - 11) } or nil }
						at = #buf - 10 -- the last bytes stay, "</geometry>" may start there
						mode = "ingeom"
					else
						at = s -- wait for the rest of this geometry
					end
				elseif #buf - at > 32 then
					at = #buf - 31
				end
			elseif mode == "ingeom" then
				local e = find(buf, "</geometry>", at, true)
				local pg = pendGeom
				if e then
					if pg.keep then
						pg.parts[#pg.parts + 1] = sub(buf, at, e + 10)
						local block = table.concat(pg.parts)
						geoms[#geoms + 1] = block
						keptIds[pg.id] = true
						checkBudget()
						if bbox then
							local gb = {math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge}
							updateBBox(gb, block)
							checkBudget()
							gb.tris = countTriangles(block)
							bbox[pg.id] = gb
						end
					end
					pendGeom = nil
					at = e + 11
					mode = "geoms"
					progressed = true
					checkBudget()
				elseif #buf - at > 11 then
					if pg.keep then pg.parts[#pg.parts + 1] = sub(buf, at, #buf - 11) end
					at = #buf - 10
				end
			elseif mode == "prescene" then
				local s = find(buf, "<visual_scene", at, true)
				if s then
					at = s + 13
					mode = "scene"
					progressed = true
				elseif #buf - at > 32 then
					at = #buf - 31
				end
			elseif mode == "scene" then
				local s = find(buf, "<node ", at, true)
				local sceneEnd = find(buf, "</visual_scene>", at, true)
				if sceneEnd and (not s or sceneEnd < s) then
					mode = "done"
				elseif s then
					local e = find(buf, "</node>", s, true)
					if e then
						local nested = find(buf, "<node ", s + 1, true)
						if not nested or nested > e then -- flat nodes only, nested ones are skipped
							local block = sub(buf, s, e + 6)
							local name = match(block, 'name="([^"]*)"')
							local url = match(block, 'instance_geometry url="#([^"]*)"')
							if name and url then onNode(block, name, url) end
						end
						at = e + 7
						progressed = true
						checkBudget()
					else
						at = s
					end
				elseif #buf - at > 32 then
					at = #buf - 31
				end
			end
		end
		if mode == "done" or eof then break end
		coroutine.yield() -- one chunk per step
	end
	f:close()
	return true
end

--- Streams one .dae and returns the filtered collada text (or nil if no wanted mesh is in it).
-- Meshes are matched by scene node name (what jbeam flexbodies reference). Exporters like Blender name
-- the geometry blocks differently ("Mesh.038"), those are fetched in a second pass by the node's url.
-- adds a node's geometry bounds to bbox, transformed by the node matrix (collada: row major, column vectors).
-- Some vehicle .dae files keep meshes in centimeters or offset with a scaled/translated node, raw vertex
-- bounds of those were hundreds of meters (the "bigger than the map" boxes).
local function mergeNodeBBox(bbox, block, gb)
	if not gb or gb[1] > gb[4] then return end
	local m = {}
	local mtx = string.match(block, "<matrix[^>]*>([^<]*)</matrix>")
	if mtx then for num in string.gmatch(mtx, "%S+") do m[#m + 1] = tonumber(num) or 0 end end
	if #m ~= 16 then m = {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1} end
	for i = 0, 7 do
		local x = (i % 2 == 0) and gb[1] or gb[4]
		local y = (math.floor(i / 2) % 2 == 0) and gb[2] or gb[5]
		local z = (i < 4) and gb[3] or gb[6]
		local wx = m[1]*x + m[2]*y + m[3]*z + m[4]
		local wy = m[5]*x + m[6]*y + m[7]*z + m[8]
		local wz = m[9]*x + m[10]*y + m[11]*z + m[12]
		if wx < bbox[1] then bbox[1] = wx end
		if wx > bbox[4] then bbox[4] = wx end
		if wy < bbox[2] then bbox[2] = wy end
		if wy > bbox[5] then bbox[5] = wy end
		if wz < bbox[3] then bbox[3] = wz end
		if wz > bbox[6] then bbox[6] = wz end
	end
end

local function collectMaterials(block, mats)
	if not mats then return end
	for sym in string.gmatch(block, '<instance_material symbol="([^"]+)"') do
		mats[(string.gsub(sym, "%-material$", ""))] = true
	end
end

local function filterDae(filename, wanted, bbox, mats)
	local header, geoms, nodes, keptIds, missing = {}, {}, {}, {}, {}
	local missingCount = 0
	local geomBoxes = {}
	local function keepByName(id, name) return wanted[name] or wanted[string.gsub(id, "%-mesh$", "")] end
	local function addNode(block, url, name)
		local nb = {math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge}
		mergeNodeBBox(nb, block, geomBoxes[url])
		mergeNodeBBox(bbox, block, geomBoxes[url])
		local size = nb[1] <= nb[4] and math.sqrt((nb[4]-nb[1])^2 + (nb[5]-nb[2])^2 + (nb[6]-nb[3])^2) or 0
		nodes[#nodes + 1] = { block = block .. "\n", url = url, name = name, tris = geomBoxes[url] and geomBoxes[url].tris or 0, size = size, mats = {}, bb = nb[1] <= nb[4] and nb or nil }
		collectMaterials(block, nodes[#nodes].mats)
	end
	local ok = scanDae(filename, keepByName, function(block, name, url)
		if not wanted[name] then return end
		if keptIds[url] then addNode(block, url, name)
		elseif not missing[url] then missing[url] = { block, name } missingCount = missingCount + 1 end
	end, false, header, geoms, keptIds, geomBoxes)
	if not ok then return nil end
	if missingCount > 0 then
		scanDae(filename, function(id) return missing[id] ~= nil and not keptIds[id] end, function() end, true, {}, geoms, keptIds, geomBoxes)
		for url, m in pairs(missing) do
			if keptIds[url] then addNode(m[1], url, m[2]) end
		end
	end
	if #nodes == 0 then return nil end
	local geomById = {}
	for _, g in ipairs(geoms) do
		local id = string.match(g, '^<geometry id="([^"]*)"')
		if id then geomById[id] = g end
	end
	return { header = table.concat(header), geomById = geomById, nodes = nodes }
end

-- keeps the biggest parts (by size) that fit into the triangle budget, over all files of a mesh set, and turns
-- the parts into the plain lists mergeDae wants (only geometries some kept node uses)
-- marks n.keep on the nodes that pass filter and fit the budget (biggest first); returns kept count and triangles
local function selectNodes(all, filter, budget, minSize)
	table.sort(all, function(a, b) if a.size ~= b.size then return a.size > b.size end return a.name < b.name end)
	local sum, kept = 0, 0
	for _, n in ipairs(all) do
		n.keep = false
		if (not filter or filter(n)) and n.size >= (minSize or 0) and (budget <= 0 or sum + n.tris <= budget or sum == 0) then
			n.keep = true
			sum, kept = sum + n.tris, kept + 1
		end
	end
	return kept, sum
end

-- All filtered parts of one config go into a single .dae, so the engine imports one shape per mesh set.
-- ids are prefixed per source file (Blender names like "Mesh_038-mesh" repeat across files), materials,
-- effects and images are deduplicated by id. Files with a different <unit>/<up_axis> get their own output.
local function prefixIds(block, pre, refsToo, out)
	-- big geometries (several MB) in slices cut at a '<' (the patterns hold no '<', so none straddles a cut),
	-- appended to out with a budget check between slices instead of one long gsub over the whole block
	local gsub, find, sub = string.gsub, string.find, string.sub
	local n, at = #block, 1
	while at <= n do
		local cut = at + READ_CHUNK <= n and (find(block, "<", at + READ_CHUNK, true) or n + 1) or n + 1
		local piece = sub(block, at, cut - 1)
		piece = gsub(piece, ' id="', ' id="' .. pre)
		if refsToo then
			piece = gsub(piece, '="#', '="#' .. pre) -- geometry internal references (sources, vertices)
		else
			piece = gsub(piece, 'url="#', 'url="#' .. pre) -- node -> geometry, material targets stay
		end
		out[#out + 1] = piece
		at = cut
		checkBudget()
	end
end

-- writes the pieces to path.tmp across frames (budget checks between writes), then renames it into place
local function writePieces(path, pieces)
	local tmp = path .. ".tmp"
	local f = io.open(tmp, "wb")
	if not f then return writeFile(path, table.concat(pieces)) end -- fallback: one step
	local buf, size = {}, 0
	for i = 1, #pieces do
		buf[#buf + 1] = pieces[i]
		size = size + #pieces[i]
		if size >= READ_CHUNK * 2 or i == #pieces then
			if not f:write(table.concat(buf)) then f:close() FS:removeFile(tmp) return false end
			buf, size = {}, 0
			checkBudget()
		end
	end
	f:close()
	if FS:fileExists(path) then FS:removeFile(path) end
	if FS:renameFile(tmp, path) ~= 0 and not FS:fileExists(path) then -- rename failed: copy through memory once
		local ok = writeFile(path, table.concat(pieces))
		FS:removeFile(tmp)
		return ok
	end
	return FS:fileExists(path)
end

local function collectLib(header, lib, tag, seen, out)
	local inner = string.match(header, "<" .. lib .. ">(.-)</" .. lib .. ">")
	if not inner then return end
	for block, id in string.gmatch(inner, '(<' .. tag .. ' id="([^"]*)".-</' .. tag .. '>)') do
		if not seen[id] then seen[id] = true out[#out + 1] = block end
	end
end

local function daeSignature(header)
	return (string.match(header, "<unit[^>]*>") or "") .. (string.match(header, "<up_axis>(.-)</up_axis>") or "Z_UP")
end

local function mergeDae(list)
	local first = list[1].header
	local preamble = string.match(first, "^(.-)<asset>") or '<?xml version="1.0" encoding="utf-8"?>\n<COLLADA xmlns="http://www.collada.org/2005/11/COLLADASchema" version="1.4.1">\n'
	local out = { preamble, string.match(first, "<asset>.-</asset>") or "", "\n" }
	for _, lib in ipairs({ { "library_images", "image" }, { "library_effects", "effect" }, { "library_materials", "material" } }) do
		local seen, blocks = {}, {}
		for _, part in ipairs(list) do collectLib(part.header, lib[1], lib[2], seen, blocks) end
		if #blocks > 0 then out[#out + 1] = "<" .. lib[1] .. ">\n" .. table.concat(blocks, "\n") .. "\n</" .. lib[1] .. ">\n" end
	end
	out[#out + 1] = "<library_geometries>\n"
	for i, part in ipairs(list) do
		local pre = "f" .. i .. "_"
		for _, g in ipairs(part.geoms) do prefixIds(g, pre, true, out) out[#out + 1] = "\n" checkBudget() end
	end
	out[#out + 1] = '</library_geometries>\n<library_visual_scenes>\n<visual_scene id="Scene" name="Scene">\n'
	for i, part in ipairs(list) do
		local pre = "f" .. i .. "_"
		for _, n in ipairs(part.nodes) do prefixIds(n, pre, false, out) end
		checkBudget()
	end
	out[#out + 1] = '</visual_scene>\n</library_visual_scenes>\n<scene>\n<instance_visual_scene url="#Scene"/>\n</scene>\n</COLLADA>\n'
	return out -- pieces, written by writePieces
end

-- plausible vehicle bounds: length up to 25 m, width and height up to 6 m
local function validBBox(b)
	if type(b) ~= "table" or #b ~= 6 then return false end
	for i = 1, 6 do if type(b[i]) ~= "number" or b[i] ~= b[i] or b[i] == math.huge or b[i] == -math.huge then return false end end
	local w, l, h = b[4] - b[1], b[5] - b[2], b[6] - b[3]
	return w > 0.1 and l > 0.1 and h > 0.1 and w <= 6 and l <= 25 and h <= 6
		and math.abs(b[1] + b[4]) < 20 and math.abs(b[2] + b[5]) < 30 -- roughly centered on the jbeam origin
end

-- BeamNG creates glow map materials (signals, lights) at spawn when no material file defines them
-- (lua/common/jbeam/materials.lua), a TSStatic does not, so do the same to avoid [NO-MATERIAL]
local function ensureMaterials(list)
	for _, name in ipairs(list or {}) do
		if not scenetree.findObject(name) then
			local mat = createObject("Material")
			if mat then
				mat.mapTo = name
				mat.canSave = false
				mat:registerObject(name)
			end
			checkBudget()
		end
	end
end

-- TSStatic skin field: "old=new" pairs (";" separated) rename material targets starting with "old" to the same name
-- with "new" in its place, only when a Material named like the result exists. Vehicle skin materials are named
-- "<material>.<slot>.<skin>", the paint_design slot ("" in the vehicle skin string) as "skin" (e.g. pickup.skin.old,
-- autobello_interior_a.skin_interior.black in the game's materials.json files), so each material of the merged
-- file gets its own pair when that skin material exists. Longest names first, so "pickup_dark" is not caught by the
-- shorter "pickup" pair. Memoized per skin string and material list.
local skinFields = {}

-- Fallback for liveries whose materials do not follow "<material>.<slot>.<skin>" (older and modded vehicles):
-- a material of the merged file is renamed to an existing Material named like it plus a separator, an optional
-- slot / "skin" part and the skin name ("<material>_<skin>", "<material>.skin_<skin>", "<material>.<slot>.<skin>"
-- with another slot name...). Only names that start with the material's own name count, so a livery can
-- never put another part's material (glass, chrome, a different panel) on a mesh. Material names are read once
-- per mission (scenetree.findClassObjects), only when the regular method found nothing for a livery.
local SEP = "[%._%-]"
local function materialNames()
	local names = skinFields["\0materials"]
	if names then return names end
	names = {}
	for _, o in ipairs(scenetree.findClassObjects("Material") or {}) do
		local n = type(o) == "string" and o or (type(o) == "userdata" or type(o) == "table") and o.getName and o:getName() or nil
		if n then names[#names + 1] = n end
	end
	skinFields["\0materials"] = names
	return names
end
local function fallbackRules(sorted, skinNames, found)
	local rules = {}
	local names = materialNames()
	local taken = {}
	for _, m in ipairs(sorted) do -- longest first, like the regular pairs
		for _, nm in ipairs(skinNames) do
			if not taken[m] then
				for _, t in ipairs(names) do
					if #t > #m and string.sub(t, 1, #m) == m then
						local rest = string.sub(t, #m + 1)
						local ok = string.match(rest, "^" .. SEP .. "(.+)$")
						-- rest is "<sep><skin>" or "<sep><one slot or 'skin' word><sep><skin>", nothing else
						local pre = ok and #ok > #nm and string.sub(ok, -#nm) == nm and string.sub(ok, 1, #ok - #nm) or nil
						if ok and (ok == nm or (pre and string.match(pre, "^[%w_]+" .. SEP .. "$"))) then
							rules[#rules + 1] = m .. "=" .. t found[#found + 1] = t taken[m] = true
							break
						end
					end
				end
			end
		end
	end
	return rules
end

local function skinField(skin, mats, what)
	if not skin or skin == "" or type(mats) ~= "table" or #mats == 0 then return "" end
	local key = skin .. "|" .. table.concat(mats, ",")
	local v = skinFields[key]
	if v then return v end
	local sorted = {}
	for _, m in ipairs(mats) do sorted[#sorted + 1] = m end
	table.sort(sorted, function(a, b) if #a ~= #b then return #a > #b end return a < b end)
	local rules, found, missing = {}, {}, 0
	local skinNames = {}
	for entry in string.gmatch(skin, "[^;]+") do
		local slot, nm = string.match(entry, "^([^.]*)%.(.+)$")
		if nm then
			skinNames[#skinNames + 1] = nm
			local mid = (slot == "" and "skin" or slot) .. "." .. nm
			for _, m in ipairs(sorted) do
				local target = m .. "." .. mid
				if scenetree.findObject(target) then rules[#rules + 1] = m .. "=" .. target found[#found + 1] = target
				else missing = missing + 1 end
			end
		end
	end
	local how = "per material"
	if #rules == 0 and #skinNames > 0 then
		rules = fallbackRules(sorted, skinNames, found)
		how = "material rename fallback"
	end
	v = table.concat(rules, ";")
	skinFields[key] = v
	log(#rules > 0 and 'I' or 'W', 'MPProxyMeshGE', string.format("Proxy livery %s for %s: skin field \"%s\" (%s, %d renames, %d material / skin pairs have no skin material%s)",
		skin, tostring(what), v, how, #rules, missing, #found > 0 and (": " .. table.concat(found, ", ")) or ", nothing to rename"))
	return v
end

-- scene node names of one .dae. The visual scene sits at the end of the file (after the geometries), so the file
-- is read backwards from its end until the scene starts; files that cannot seek are read forward.
local function sceneNodeNames(file, out)
	local f = io.open(file, "rb")
	if not f then return end
	local okSeek, size = pcall(f.seek, f, "end")
	local text = nil
	if okSeek and type(size) == "number" and size > 0 then
		local parts, pos = {}, size
		while pos > 0 do
			local from = math.max(0, pos - READ_CHUNK * 2)
			f:seek("set", from)
			local chunk = f:read(pos - from)
			if not chunk then break end
			table.insert(parts, 1, chunk)
			pos = from
			local joined = table.concat(parts)
			parts = { joined }
			if string.find(joined, "<visual_scene", 1, true) then break end
			coroutine.yield()
		end
		text = parts[1]
	else
		local list = {}
		while true do
			local chunk = f:read(READ_CHUNK)
			if not chunk then break end
			list[#list + 1] = chunk
			coroutine.yield()
		end
		text = table.concat(list)
	end
	f:close()
	if not text then return end
	local sceneAt = string.find(text, "<visual_scene", 1, true) or 1
	local n = 0
	for name in string.gmatch(string.sub(text, sceneAt), '<node [^>]-name="([^"]+)"') do
		if out[name] == nil then out[name] = file end
		n = n + 1
		if n >= 200 then n = 0 checkBudget() end
	end
	checkBudget()
end

-- the node block with the flexbody transform (scale, rotation: euler +Z +X +Y intrinsic, then position relative to
-- the wheel center) applied in front of its own matrix; nil for nodes using other transform elements
local function bakeNode(block, e, unit)
	if string.find(block, "<translate", 1, true) or string.find(block, "<rotate", 1, true) or string.find(block, "<scale", 1, true) then return nil end
	local m = {}
	local mtx = string.match(block, "<matrix[^>]*>([^<]*)</matrix>")
	if mtx then for num in string.gmatch(mtx, "%S+") do m[#m + 1] = tonumber(num) or 0 end end
	if #m ~= 16 then m = {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1} end
	local rx, ry, rz = math.rad(e[5]), math.rad(e[6]), math.rad(e[7])
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	-- R = Rz * Rx * Ry
	local zx = { {cz, -sz * cx, sz * sx}, {sz, cz * cx, -cz * sx}, {0, sx, cx} }
	local R = {}
	for i = 1, 3 do
		R[i] = { zx[i][1] * cy - zx[i][3] * sy, zx[i][2], zx[i][1] * sy + zx[i][3] * cy }
	end
	local sc = { e[8], e[9], e[10] }
	local t = { e[2] / unit, e[3] / unit, e[4] / unit } -- node matrices are in file units
	local B = {}
	for i = 1, 3 do B[i] = { R[i][1] * sc[1], R[i][2] * sc[2], R[i][3] * sc[3], t[i] } end
	B[4] = { 0, 0, 0, 1 }
	local out = {}
	for i = 1, 4 do
		for j = 1, 4 do
			local v = 0
			for k = 1, 4 do v = v + B[i][k] * m[(k - 1) * 4 + j] end
			out[#out + 1] = string.format("%.7g", v)
		end
	end
	local newMtx = '<matrix sid="transform">' .. table.concat(out, " ") .. '</matrix>'
	if mtx then
		return (string.gsub(block, "<matrix[^>]*>[^<]*</matrix>", function() return newMtx end, 1))
	end
	return (string.gsub(block, "^(<node[^>]*>)", function(open) return open .. newMtx end, 1))
end

M.updateBBox = updateBBox
M.countTriangles = countTriangles
M.scanDae = scanDae
M.mergeNodeBBox = mergeNodeBBox
M.collectMaterials = collectMaterials
M.filterDae = filterDae
M.selectNodes = selectNodes
M.prefixIds = prefixIds
M.writePieces = writePieces
M.collectLib = collectLib
M.daeSignature = daeSignature
M.mergeDae = mergeDae
M.validBBox = validBBox
M.ensureMaterials = ensureMaterials
M.skinFields = skinFields
M.skinField = skinField
M.sceneNodeNames = sceneNodeNames
M.bakeNode = bakeNode

return M
