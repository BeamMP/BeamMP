--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================
-- Node sync related test functions
--====================================================================================

local M = {}



-- ============= VARIABLES =============
local lastPos = vec3(0,0,0)
-- ============= VARIABLES =============



local function distance( x1, y1, z1, x2, y2, z2 )
	local dx = x1 - x2
	local dy = y1 - y2
	local dz = z1 - z2
	return math.sqrt ( dx*dx + dy*dy + dz*dz)
end



local function getNodes()

  -- TODO: color
  local save = {}
  --save.nodeCount = #v.data.nodes
  --save.beamCount = #v.data.beams
  --save.luaState = serialize(serializePackages("save"))
  --save.hydros = {}
  --for _, h in pairs(hydros.hydros) do
    --table.insert(save.hydros, h.state)
  --end

  save.nodes = {}
  for _, node in pairs(v.data.nodes) do
	local Pos = obj:getNodePosition(node.cid)
	Pos.x = Round(Pos.x,3)
	Pos.y = Round(Pos.y,3)
	Pos.z = Round(Pos.z,3)
    local d = {vec3(Pos):toTable()}

    if math.abs(obj:getOriginalNodeMass(node.cid) - obj:getNodeMass(node.cid)) > 0.1 then
      table.insert(d, obj:getNodeMass(node.cid))
    end
    save.nodes[node.cid + 1] = d
  end

  save.beams = {}
  for _, beam in pairs(v.data.beams) do
    local d = {
      Round(obj:getBeamRestLength(beam.cid),3),
      obj:beamIsBroken(beam.cid),
      Round(obj:getBeamDeformation(beam.cid),3)
    }
    save.beams[beam.cid + 1] = d
  end


	--print("ok")
	--local pos = obj:getPosition()
	--local dist = distance(pos.x, pos.y, pos.z, lastPos.x, lastPos.y, lastPos.z)
	--lastPos = pos
	--if (dist > 0.02) then return end

	--local save = {}
  --save.nodeCount = #v.data.nodes
  --save.beamCount = #v.data.beams

  --[[save.hydros = {}
  for _, h in pairs(hydros.hydros) do
    table.insert(save.hydros, h.state)
  end]]

  --[[save.nodes = {}
  for _, node in pairs(v.data.nodes) do
    local d = {
      vec3(obj:getNodePosition(node.cid)):toTable()
    }
    if math.abs(obj:getOriginalNodeMass(node.cid) - obj:getNodeMass(node.cid)) > 0.1 then
      table.insert(d, obj:getNodeMass(node.cid))
    end
    save.nodes[node.cid + 1] = d
  end]]

  --[[save.beams = {}
  for _, beam in pairs(v.data.beams) do
    local d = {
      obj:getBeamRestLength(beam.cid),
      obj:beamIsBroken(beam.cid),
      obj:getBeamDeformation(beam.cid)
    }
    save.beams[beam.cid + 1] = d
  end]]

	obj:queueGameEngineLua("nodesGE.sendNodes(\'"..jsonEncode(save).."\', "..obj:getID()..")") -- Send it to GE lua
end



local function applyNodes(data)

	--obj:requestReset(RESET_PHYSICS)
	local save = jsonDecode(data)

  print("Applied "..string.len(data).." bytes!")
  --importPersistentData(save.luaState)

  --[[for k, h in pairs(save.hydros) do
    hydros.hydros[k].state = h
  end]]

  for cid, node in pairs(save.nodes) do
    cid = tonumber(cid) - 1
    obj:setNodePosition(cid, vec3(node[1]):toFloat3())
    if #node > 1 then
      obj:setNodeMass(cid, node[2])
    end
  end

  for cid, beam in pairs(save.beams) do
		cid = tonumber(cid) - 1
		if beam[2] == true then
			obj:breakBeam(cid)
			beamstate.beamBroken(cid,1)
		else
			obj:setBeamLength(cid, beam[1])
			if beam[3] > 0 then
			--print('deformed: ' .. tostring(cid) .. ' = ' .. tostring(beam[3]))
			beamstate.beamDeformed(cid, beam[3])
			end
		end
  end


  --[[if not decodedData or decodedData.nodeCount ~= #v.data.nodes then --or decodedData.beamCount ~= #v.data.beams then
    log("E", "nodesVE", "unable to use nodes data.")
    return
  end]]
  print("Node Data Good, Attempting to apply...")
  --[[for k, h in pairs(decodedData.hydros) do
    hydros.hydros[k].state = h
  end]]

  --[[for cid, node in pairs(decodedData.nodes) do
    cid = tonumber(cid) - 1
    obj:setNodePosition(cid, vec3(node[1]):toFloat3())
    if #node > 1 then
      obj:setNodeMass(cid, node[2])
    end
  end]]

  --[[for cid, beam in pairs(decodedData.beams) do
    cid = tonumber(cid) - 1
    obj:setBeamLength(cid, beam[1])
    if beam[2] == true then
      obj:breakBeam(cid)
    end
    if beam[3] > 0 then
      -- deformation: do not call c++ at all, its just used on the lua side anyways
      --print('deformed: ' .. tostring(cid) .. ' = ' .. tostring(beam[3]))
      beamDeformed(cid, beam[3])
    end
  end]]

	--[[for cid, node in pairs(decodedData.nodes) do
		cid = tonumber(cid) - 1

		local beam = v.data.beams[cid]
		local beamPrecompression = beam.beamPrecompression or 1
		local deformLimit = type(beam.deformLimit) == 'number' and beam.deformLimit or math.huge
		obj:setBeam(-1, beam.id1, beam.id2, beam.beamStrength, beam.beamSpring,
			beam.beamDamp, type(beam.dampCutoffHz) == 'number' and beam.dampCutoffHz or 0,
			beam.beamDeform, deformLimit, type(beam.deformLimitExpansion) == 'number' and beam.deformLimitExpansion or deformLimit,
			beamPrecompression
		)
		--print(dump(node))
		obj:setNodePosition(cid, vec3(node[1]):toFloat3())
		if #node > 1 then
			obj:setNodeMass(cid, node[2])
		end

	end]]
  print("Node Data Should be applied!")
end



local function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end


--------- start of disableCollision modification

local abs = math.abs
local NORMALTYPE = 0
local NODE_FIXED = 1
local wheelNodes = {}

local function nodeCheck(nodeID)
	local connectedNodes = {}
	for _, beam in pairs(v.data.beams) do
		if beam.id1 == nodeID then
			connectedNodes[beam.id2] = 1
		else 
			if beam.id2 == nodeID then
				connectedNodes[beam.id1] = 1
			end
		end
	end
	
	local shellNode = {true, true, true}
	for id, num in  pairs(connectedNodes) do
		if abs(v.data.nodes[nodeID].pos.x) < abs(v.data.nodes[id].pos.x) then
			shellNode[0] = false
		end	
		
		if abs(v.data.nodes[nodeID].pos.y) < abs(v.data.nodes[id].pos.y) then
			shellNode[1] = false
		end	
		
		if abs(v.data.nodes[nodeID].pos.z) < abs(v.data.nodes[id].pos.z) then
			shellNode[2] = false
		end	
	end
	
	return shellNode[0] or shellNode[1] or shellNode[2]
end

local function disableCollisions()
	local doCollision = true
	if tempValue == 'true' then doCollision = true
	else doCollision = false end

	local vehType = v.mpVehicleType and v.mpVehicleType == "R" or v.mpVehicleType == "remote" or true
	if not vehType then return end --return if veh is local

	print(tostring(obj:getID()).." collision have been set to "..tostring(doCollision))

	if v.data.nodes == nil then return end
	
	for _, node in pairs(v.data.nodes) do -- For each node

		local collision = false
		local selfCollision = node.selfCollision or false
		local staticCollision = node.staticCollision or true
		
		local skip = false
		
		if node.wheelID ~= nil then
			dump(node)
		end	
		
		if node.wheelID ~= nil or nodeCheck(node.cid) == true then -- If it's a wheel
			if node.wheelID ~= nil then
				if wheelNodes[node.wheelID] == nil then
					wheelNodes[node.wheelID] = 0
				end
				
				if wheelNodes[node.wheelID] < 2 then
					wheelNodes[node.wheelID] = wheelNodes[node.wheelID] + 1
					goto continue
				else 
					wheelNodes[node.wheelID] = 0
				end
				
			else
				goto continue
			end
		end
		

		-- --------------------- Node type ---------------------
		local ntype = NORMALTYPE
		if node.fixed == true then ntype = NODE_FIXED end

		-- --------------------- Random stuff ---------------------
		local frictionCoef = type(node.frictionCoef) == 'number' and node.frictionCoef or 1
		local slidingFrictionCoef = type(node.slidingFrictionCoef) == 'number' and node.slidingFrictionCoef or frictionCoef
		local noLoadCoef = type(node.noLoadCoef) == 'number' and node.noLoadCoef or 1
		local fullLoadCoef = type(node.fullLoadCoef) == 'number' and node.fullLoadCoef or 0
		local loadSensitivitySlope = type(node.loadSensitivitySlope) == 'number' and node.loadSensitivitySlope or 0
		local nodeWeight = node.nodeWeight
		local nodeMaterialTypeID
		if node.nodeMaterial ~= nil then
			nodeMaterialTypeID = node.nodeMaterial
			if type(nodeMaterialTypeID) ~= "number" then nodeMaterialTypeID = 0 end
		else
			nodeMaterialTypeID = 0
		end

		-- We set the node
		local pos = obj:getNodePosition(node.cid)
		
		obj:setNode(
			node.cid,
			pos.x,
			pos.y,
			pos.z,
			nodeWeight,
			ntype,
			frictionCoef,
			slidingFrictionCoef,
			node.stribeckExponent or 1.75,
			node.stribeckVelMult or 1,
			noLoadCoef,
			fullLoadCoef,
			loadSensitivitySlope,
			node.softnessCoef or 0.5,
			node.treadCoef or 0.5,
			node.tag or '',
			node.couplerStrength or math.huge,
			node.firstGroup or -1,
			selfCollision,
			collision,
			staticCollision, 
			nodeMaterialTypeID
		)
		
		::continue::
	end
	
	print(tostring(obj:getID()).." state set successfully")
	
	obj:requestReset(RESET_PHYSICS)
end

local function onInit()
	print("disableCollision has been called")
	disableCollisions()
end

M.onExtensionLoaded = onInit
M.distance   = distance
M.applyNodes = applyNodes
M.getNodes   = getNodes



return M
