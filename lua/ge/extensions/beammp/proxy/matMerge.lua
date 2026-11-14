-- Copyright (C) 2026 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- beammp.proxy.matMerge - merges the meshes of one proxy mesh piece by material.
-- A TSStatic draws each mesh of its shape once per material it uses, and a vehicle .dae has one mesh per jbeam
-- flexbody (a pickup body tier: 100+ meshes, ~40 materials). Here all triangles of a piece that use the same
-- material become one mesh: node transforms are baked into the vertex positions / normals, the sources are
-- appended per semantic and the indices shifted. Layout per merged mesh: VERTEX, NORMAL, TEXCOORD set 0,
-- TEXCOORD set 1 and one COLOR when any member has them (members without get a default value).
-- Geometries this cannot handle (polylist / polygons / tristrips, extra inputs on <vertices>, missing arrays,
-- nodes with translate / rotate / scale elements) are passed through unchanged; lines are dropped (not drawn
-- by a TSStatic anyway). A merged mesh is capped at MAX_CORNERS triangle corners, so its unique vertex count
-- stays under 65536 whatever index size the engine uses for it.
local M = {}

local MAX_CORNERS = 60000
local IDENTITY = { 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 }
local checkBudget = function() end
function M.setBudgetCheck(fn) checkBudget = fn or function() end end

local find, match, gmatch, format, concat = string.find, string.match, string.gmatch, string.format, table.concat

local function parseMatrix(block)
	if find(block, "<translate", 1, true) or find(block, "<rotate", 1, true) or find(block, "<scale", 1, true) then return nil end
	local mtx = match(block, "<matrix[^>]*>([^<]*)</matrix>")
	if not mtx then return IDENTITY, true end
	local m = {}
	for num in gmatch(mtx, "%S+") do m[#m + 1] = tonumber(num) or 0 end
	if #m ~= 16 then return nil end
	local ident = true
	for i = 1, 16 do if math.abs(m[i] - IDENTITY[i]) > 1e-7 then ident = false break end end
	return m, ident
end

-- { [id] = { arr = float text, stride, count } } and the POSITION source of <vertices>. Plain finds over the
-- geometry text (a body geometry is several MB): only the float arrays and index lists are copied out.
local function parseGeometry(g)
	local srcs = {}
	local at = 1
	while true do
		local s = find(g, "<source id=\"", at, true)
		if not s then break end
		local e = find(g, "</source>", s, true)
		if not e then return nil end
		local sid = match(g, '^<source id="([^"]+)"', s)
		local fa = find(g, "<float_array", s, true)
		if sid and fa and fa < e then
			local open = find(g, ">", fa, true)
			local close = find(g, "</float_array>", open, true)
			if close and close < e then
				local tail = string.sub(g, close, e)
				local stride = tonumber(match(tail, '<accessor[^>]-stride="(%d+)"') or "1") or 1
				local count = tonumber(match(tail, '<accessor[^>]-count="(%d+)"') or "")
				if count then srcs[sid] = { arr = string.sub(g, open + 1, close - 1), stride = stride, count = count } end
			end
		end
		at = e + 9
		checkBudget()
	end
	local vs = find(g, "<vertices", 1, true)
	local ve = vs and find(g, "</vertices>", vs, true)
	if not ve then return nil end
	local vblock = string.sub(g, vs, ve)
	local vid = match(vblock, '^<vertices id="([^"]+)"')
	local nIn, posSrc = 0, nil
	for sem, src in gmatch(vblock, '<input semantic="(%w+)" source="#([^"]+)"') do
		nIn = nIn + 1
		if sem == "POSITION" then posSrc = src end
	end
	if nIn ~= 1 or not posSrc or not srcs[posSrc] or srcs[posSrc].stride ~= 3 then return nil end
	if find(g, "<polylist", 1, true) or find(g, "<polygons", 1, true) or find(g, "<tristrips", 1, true) or find(g, "<trifans", 1, true) then return nil end
	local prims = {}
	at = 1
	while true do -- lines / linestrips: dropped
		local s = find(g, "<triangles", at, true)
		if not s then break end
		local ps = find(g, "<p>", s, true)
		local pe = ps and find(g, "</p>", ps, true)
		if not pe then return nil end
		local head = string.sub(g, s, ps)
		local pr = { mat = match(head, 'material="([^"]+)"') or "", stride = 0, corners = 3 * (tonumber(match(head, 'count="(%d+)"') or "0") or 0) }
		for inp in gmatch(head, "<input [^>]*>") do
			local sem, src, off = match(inp, 'semantic="(%w+)"'), match(inp, 'source="#([^"]+)"'), tonumber(match(inp, 'offset="(%d+)"') or "")
			local set = tonumber(match(inp, 'set="(%d+)"') or "0") or 0
			if not (sem and src and off) then return nil end
			if off + 1 > pr.stride then pr.stride = off + 1 end
			if sem == "VERTEX" then if src ~= vid then return nil end pr.v = off
			elseif sem == "NORMAL" and not pr.n then pr.n, pr.ns = off, src
			elseif sem == "TEXCOORD" and set == 0 and not pr.t0 then pr.t0, pr.t0s = off, src
			elseif sem == "TEXCOORD" and set == 1 and not pr.t1 then pr.t1, pr.t1s = off, src
			elseif sem == "COLOR" and not pr.c then pr.c, pr.cs = off, src end
		end
		if not pr.v then return nil end
		for _, k in ipairs({ "ns", "t0s", "t1s", "cs" }) do if pr[k] and not srcs[pr[k]] then return nil end end
		pr.p = string.sub(g, ps + 3, pe - 1)
		prims[#prims + 1] = pr
		at = pe + 4
		checkBudget()
	end
	if #prims == 0 then return nil end
	return { srcs = srcs, pos = posSrc, prims = prims }
end

-- appends the values of source s (want values per element, transformed for positions / normals) to out
local function appendSource(out, s, want, kind, m)
	if kind == "pos" or kind == "nrm" then
		if not m then out[#out + 1] = s.arr return end
		local a, b, c, d, e, f, g, h, i
		if kind == "nrm" then -- inverse transpose of the upper 3x3 (non uniform scale), then normalized
			local m11, m12, m13, m21, m22, m23, m31, m32, m33 = m[1], m[2], m[3], m[5], m[6], m[7], m[9], m[10], m[11]
			a, b, c = m22 * m33 - m23 * m32, m23 * m31 - m21 * m33, m21 * m32 - m22 * m31
			d, e, f = m13 * m32 - m12 * m33, m11 * m33 - m13 * m31, m12 * m31 - m11 * m32
			g, h, i = m12 * m23 - m13 * m22, m13 * m21 - m11 * m23, m11 * m22 - m12 * m21
		end
		local buf, n, x, y = {}, 0, 0, 0
		for num in gmatch(s.arr, "%S+") do
			local v = tonumber(num) or 0
			local k = n % 3
			if k == 0 then x = v elseif k == 1 then y = v else
				if kind == "pos" then
					buf[#buf + 1] = format("%.6g %.6g %.6g", m[1]*x + m[2]*y + m[3]*v + m[4], m[5]*x + m[6]*y + m[7]*v + m[8], m[9]*x + m[10]*y + m[11]*v + m[12])
				else
					local nx, ny, nz = a*x + b*y + c*v, d*x + e*y + f*v, g*x + h*y + i*v
					local l = math.sqrt(nx*nx + ny*ny + nz*nz)
					if l < 1e-12 then l = 1 end
					buf[#buf + 1] = format("%.5g %.5g %.5g", nx / l, ny / l, nz / l)
				end
				if #buf % 500 == 0 then checkBudget() end
			end
			n = n + 1
		end
		out[#out + 1] = concat(buf, " ")
		return
	end
	if s.stride == want then out[#out + 1] = s.arr return end
	-- other stride (rgb colors, uvw coords): take the first values, pad colors with alpha 1
	local buf, vals, n = {}, {}, 0
	for num in gmatch(s.arr, "%S+") do
		n = n + 1
		vals[n] = num
		if n == s.stride then
			for k = 1, want do buf[#buf + 1] = vals[k] or (k == 4 and "1" or "0") end
			n = 0
			if #buf % 4000 == 0 then checkBudget() end
		end
	end
	out[#out + 1] = concat(buf, " ")
end

local KINDS = { { "pos", 3, "X Y Z" }, { "nrm", 3, "X Y Z" }, { "uv0", 2, "S T" }, { "uv1", 2, "S T" }, { "col", 4, "R G B A" } }
local DEFAULTS = { nrm = "0 0 1", uv0 = "0 0", uv1 = "0 0", col = "1 1 1 1" }

local function sourceXml(gid, kind, want, params, data, count)
	local pl = {}
	for p in gmatch(params, "%S+") do pl[#pl + 1] = '<param name="' .. p .. '" type="float"/>' end
	return format('<source id="%s-%s"><float_array id="%s-%s-array" count="%d">', gid, kind, gid, kind, count * want) .. data ..
		format('</float_array><technique_common><accessor source="#%s-%s-array" count="%d" stride="%d">%s</accessor></technique_common></source>\n',
			gid, kind, count, want, concat(pl))
end

-- builds one merged geometry + node for a chunk (members = { { geo, prim, m, key } })
local function buildChunk(ck, index, out)
	local gid = "mm" .. index
	local has = { pos = true, nrm = true, uv0 = true, uv1 = false, col = false }
	for _, mb in ipairs(ck.members) do
		if mb.prim.t1 then has.uv1 = true end
		if mb.prim.c then has.col = true end
	end
	local data, counts, base = {}, {}, {}
	for _, k in ipairs(KINDS) do data[k[1]], counts[k[1]] = {}, 0 end
	local defaultAt = {}
	local function default(kind)
		if not defaultAt[kind] then
			defaultAt[kind] = counts[kind]
			data[kind][#data[kind] + 1] = DEFAULTS[kind]
			counts[kind] = counts[kind] + 1
		end
		return defaultAt[kind]
	end
	local idx = {}
	local corners = 0
	for _, mb in ipairs(ck.members) do
		local geo, pr, m = mb.geo, mb.prim, mb.m
		local function src(kind, id, want)
			if not id then return nil end
			local key = mb.key .. "|" .. kind .. "|" .. id
			local b = base[key]
			if b == nil then
				local s = geo.srcs[id]
				b = counts[kind]
				appendSource(data[kind], s, want, kind, (kind == "pos" or kind == "nrm") and m or nil)
				counts[kind] = counts[kind] + s.count
				base[key] = b
			end
			return b
		end
		local bp = src("pos", geo.pos, 3)
		local bn = src("nrm", pr.ns, 3)
		local b0 = src("uv0", pr.t0s, 2)
		local b1 = has.uv1 and src("uv1", pr.t1s, 2)
		local bc = has.col and src("col", pr.cs, 4)
		local dn = not bn and default("nrm")
		local d0 = not b0 and default("uv0")
		local d1 = has.uv1 and not b1 and default("uv1")
		local dc = has.col and not bc and default("col")
		local stride, vals, n = pr.stride, {}, 0
		local ov, on, o0, o1, oc = pr.v + 1, pr.n and pr.n + 1, pr.t0 and pr.t0 + 1, pr.t1 and pr.t1 + 1, pr.c and pr.c + 1
		for num in gmatch(pr.p, "%d+") do
			n = n + 1
			vals[n] = tonumber(num)
			if n == stride then
				idx[#idx + 1] = bp + vals[ov]
				idx[#idx + 1] = bn and (bn + vals[on]) or dn
				idx[#idx + 1] = b0 and (b0 + vals[o0]) or d0
				if has.uv1 then idx[#idx + 1] = b1 and (b1 + vals[o1]) or d1 end
				if has.col then idx[#idx + 1] = bc and (bc + vals[oc]) or dc end
				n = 0
				corners = corners + 1
				if corners % 1500 == 0 then checkBudget() end
			end
		end
	end
	local g = { format('<geometry id="%s" name="%s"><mesh>\n', gid, gid) }
	for _, k in ipairs(KINDS) do
		if has[k[1]] then g[#g + 1] = sourceXml(gid, k[1], k[2], k[3], concat(data[k[1]], " "), counts[k[1]]) end
	end
	g[#g + 1] = format('<vertices id="%s-vtx"><input semantic="POSITION" source="#%s-pos"/></vertices>\n', gid, gid)
	g[#g + 1] = format('<triangles material="%s" count="%d"><input semantic="VERTEX" source="#%s-vtx" offset="0"/><input semantic="NORMAL" source="#%s-nrm" offset="1"/><input semantic="TEXCOORD" source="#%s-uv0" offset="2" set="0"/>',
		ck.symbol, math.floor(corners / 3), gid, gid, gid)
	local off = 3
	if has.uv1 then g[#g + 1] = format('<input semantic="TEXCOORD" source="#%s-uv1" offset="%d" set="1"/>', gid, off) off = off + 1 end
	if has.col then g[#g + 1] = format('<input semantic="COLOR" source="#%s-col" offset="%d" set="0"/>', gid, off) end
	g[#g + 1] = "<p>"
	g[#g + 1] = concat(idx, " ")
	g[#g + 1] = "</p></triangles>\n</mesh></geometry>"
	out.geoms[#out.geoms + 1] = concat(g)
	local bind = ck.target and format('<bind_material><technique_common><instance_material symbol="%s" target="%s"/></technique_common></bind_material>', ck.symbol, ck.target) or ""
	-- the node name ends in letters: a trailing number can read as a detail size to shape importers
	out.nodes[#out.nodes + 1] = format('<node id="%s-node" name="proxy%d_mm" type="NODE"><matrix sid="transform">1 0 0 0 0 1 0 0 0 0 1 0 0 0 0 1</matrix><instance_geometry url="#%s" name="proxy%d_mm">%s</instance_geometry></node>\n',
		gid, index, gid, index, bind)
	checkBudget()
end

--- lists: what mergeDae takes ({ header, nodes = {node block}, geoms = {geometry block} } per source file, all with
-- the same unit / up axis). Returns a new list in the same format and the mesh counts before / after.
function M.mergeByMaterial(lists)
	local chunks, order = {}, {}
	local passNodes, passGeoms = {}, {}
	local before = 0
	for li, part in ipairs(lists) do
		local geoById = {}
		for _, g in ipairs(part.geoms) do
			local id = match(g, '^<geometry id="([^"]*)"')
			if id then geoById[id] = { text = g } end
		end
		for ni, nb in ipairs(part.nodes) do
			before = before + 1
			local url = match(nb, 'instance_geometry url="#([^"]*)"')
			local ge = url and geoById[url]
			local m, ident = parseMatrix(nb)
			local geo = ge and m and (ge.parsed == nil and (function() ge.parsed = parseGeometry(ge.text) or false return ge.parsed end)() or ge.parsed)
			checkBudget()
			if not geo then
				passNodes[#passNodes + 1] = { li = li, node = nb }
				if ge and not ge.passed then ge.passed = true passGeoms[#passGeoms + 1] = { li = li, geom = ge.text } end
			else
				local bindings = {}
				for sym, tgt in gmatch(nb, '<instance_material symbol="([^"]+)" target="([^"]+)"') do bindings[sym] = tgt end
				for _, pr in ipairs(geo.prims) do
					local tgt = bindings[pr.mat]
					local key = tgt or ("?" .. pr.mat)
					local corners = pr.corners
					local list = chunks[key]
					if not list then list = {} chunks[key] = list order[#order + 1] = key end
					local ck = list[#list]
					if not ck or (ck.corners > 0 and ck.corners + corners > MAX_CORNERS) then
						ck = { symbol = pr.mat, target = tgt, members = {}, corners = 0 }
						list[#list + 1] = ck
					end
					ck.members[#ck.members + 1] = { geo = geo, prim = pr, m = (not ident) and m or nil, key = li .. ":" .. ni }
					ck.corners = ck.corners + corners
				end
			end
		end
	end
	local out = { header = lists[1].header, nodes = {}, geoms = {} }
	local n = 0
	for _, key in ipairs(order) do
		for _, ck in ipairs(chunks[key]) do
			n = n + 1
			buildChunk(ck, n, out)
		end
	end
	-- passed through meshes keep their own file's entry (ids are prefixed per entry by mergeDae)
	local result = { out }
	local extra = {}
	for li, part in ipairs(lists) do
		local e = { header = part.header, nodes = {}, geoms = {} }
		extra[li] = e
		result[#result + 1] = e
	end
	for _, p in ipairs(passNodes) do table.insert(extra[p.li].nodes, p.node) end
	for _, p in ipairs(passGeoms) do table.insert(extra[p.li].geoms, p.geom) end
	return result, before, n + #passNodes
end

return M
