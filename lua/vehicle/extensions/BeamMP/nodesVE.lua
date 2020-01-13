--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}



local function getNodes()
	local save = {}
	save.nodeCount = #v.data.nodes
	save.nodes = {}
		for _, node in pairs(v.data.nodes) do
			local d = {vec3(obj:getNodePosition(node.cid)):toTable()}
			if math.abs(obj:getOriginalNodeMass(node.cid) - obj:getNodeMass(node.cid)) > 0.1 then
			table.insert(d, obj:getNodeMass(node.cid))
		end
		save.nodes[node.cid + 1] = d
	end
	obj:queueGameEngineLua("nodesGE.sendNodes(\'"..jsonEncode(save).."\', \'"..obj:getID().."\')") -- Send it to GE lua
end



local function applyNodes(data)
	local decodedData = jsonDecode("["..data)
	for cid, node in pairs(decodedData.nodes) do
		cid = tonumber(cid) - 1
		obj:setNodePosition(cid, vec3(node[1]):toFloat3())
		if #node > 1 then
			obj:setNodeMass(cid, node[2])
		end
	end
end



M.applyNodes = applyNodes
M.getNodes   = getNodes



return M
