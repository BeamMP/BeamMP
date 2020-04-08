--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}



-- ============= VARIABLES =============
local lastPos = vec3(0,0,0)
-- ============= VARIABLES =============



function distance( x1, y1, z1, x2, y2, z2 )
	local dx = x1 - x2
	local dy = y1 - y2
	local dz = z1 - z2
	return math.sqrt ( dx*dx + dy*dy + dz*dz)
end



local function getNodes()
	print("ok")
	local pos = obj:getPosition()
	local dist = distance(pos.x, pos.y, pos.z, lastPos.x, lastPos.y, lastPos.z)
	lastPos = pos
	if (dist > 0.5) then return end


	for _, node in pairs(v.data.nodes) do
	local p=obj:getNodePosition(node.cid)
	local np=float3(nodesVE.round(p.x, 3), nodesVE.round(p.y, 3), nodesVE.round(p.z, 3))
	obj:setNodePosition(node.cid, np)
	end

	local save = {}
	save.nodeCount = #v.data.nodes
	save.nodes = {}
		for _, node in pairs(v.data.nodes) do
			--print(obj:beamIsBroken(node.cid))
			--if obj:beamIsBroken(node.cid) == false then
				local pos = obj:getNodePosition(node.cid)
				local roundedPos = {round(pos.x, 3), round(pos.y, 3), round(pos.z, 3)}
				local d = roundedPos
				if math.abs(obj:getOriginalNodeMass(node.cid) - obj:getNodeMass(node.cid)) > 0.1 then
				table.insert(d, obj:getNodeMass(node.cid))
			--else
			--	save.nodeCount = save.nodeCount - 1
			--end
		end
		save.nodes[node.cid + 1] = d
	end
	print(jsonEncode(save))
	obj:queueGameEngineLua("nodesGE.sendNodes(\'"..jsonEncode(save).."\', \'"..obj:getID().."\')") -- Send it to GE lua
end



local function applyNodes(data)

	--obj:requestReset(RESET_PHYSICS)

	local decodedData = jsonDecode(data)
	for cid, node in pairs(decodedData.nodes) do
		cid = tonumber(cid) - 1

		local beam = v.data.beams[cid]
		local beamPrecompression = beam.beamPrecompression or 1
		local deformLimit = type(beam.deformLimit) == 'number' and beam.deformLimit or math.huge
		obj:setBeam(-1, beam.id1, beam.id2, beam.beamStrength, beam.beamSpring,
			beam.beamDamp, type(beam.dampCutoffHz) == 'number' and beam.dampCutoffHz or 0,
			beam.beamDeform, deformLimit, type(beam.deformLimitExpansion) == 'number' and beam.deformLimitExpansion or deformLimit,
			beamPrecompression
		)

		obj:setNodePosition(cid, vec3(node[1]):toFloat3())
		if #node > 1 then
			obj:setNodeMass(cid, node[2])
		end

	end
end



function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end



M.round      = round
M.distance   = distance
M.applyNodes = applyNodes
M.getNodes   = getNodes



return M
