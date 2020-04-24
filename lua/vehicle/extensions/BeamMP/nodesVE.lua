--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}



-- ============= VARIABLES =============
local lastPos = vec3(0,0,0)
local latestData
local dataToApply
local requestReset = false
local calculated = false
local latestRot
-- ============= VARIABLES =============



local function distance( x1, y1, z1, x2, y2, z2 )
	local dx = x1 - x2
	local dy = y1 - y2
	local dz = z1 - z2
	return math.sqrt ( dx*dx + dy*dy + dz*dz)
end

local function H(q1, q2)
	w = q1.w*q2.w - q1.x*q2.x - q1.y*q2.y - q1.z*q2.z
    x = q1.w*q2.x + q1.x*q2.w + q1.y*q2.z - q1.z*q2.y
    y = q1.w*q2.y + q1.y*q2.w + q1.z*q2.x - q1.x*q2.z
    z = q1.w*q2.z + q1.z*q2.w + q1.x*q2.y - q1.y*q2.x
    return quat(x, y, z, w)
end

local function copysign(x, y)
	if y >= 0 then
		return math.abs(x)
	else
		return -math.abs(x)
	end
end

local function round(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end



local function getNodes()
	local save = {}
	local r = obj:getRotation()
	local rp = quat(-r.x, -r.y, -r.z, r.w)

	-- For each node calculate it's position at rotation 0
	-- so that when the other user receive the data he
	-- can calculate the theorical position by using the
	-- obj:getRotation() of the user that sent the data
	save.nodes = {}
	for _, node in pairs(v.data.nodes) do
		local pos = obj:getNodePosition(node.cid)
		local p = quat(pos.x, pos.y, pos.z, 0)
		local newPos = H(H(r, p), rp)
		local d = {round(newPos.x, 4), round(newPos.y, 4), round(newPos.z, 4)}
		save.nodes[node.cid + 1] = d
	end

	save.beams = {}
	for _, beam in pairs(v.data.beams) do
		save.beams[beam.cid + 1] = round(obj:getBeamRestLength(beam.cid), 3)
	end
	obj:queueGameEngineLua("nodesGE.sendNodes(\'"..jsonEncode(save).."\', \'"..obj:getID().."\')") -- Send it to GE lua
end



local function applyNodes(data)
	latestData = jsonDecode(data)
	dataToApply = jsonDecode(data)
	calculated = false
	if requestReset then
		obj:requestReset(RESET_PHYSICS)
		requestReset = false
	end
end



local function requestRes()
	requestReset = true
end



local function onUpdate(dt) --ONUPDATE OPEN

	local pos = obj:getPosition()
	local dist = distance(pos.x, pos.y, pos.z, lastPos.x, lastPos.y, lastPos.z)
	lastPos = pos
	if (dist < 0.07) then return end

	if dataToApply and latestRot then
		if not calculated then
			if latestData then
				-- Get the rotation
				local r = quat(latestRot.ang.x, latestRot.ang.y, latestRot.ang.z, latestRot.ang.w)
				-- Get the opposite except for w
				local rp = quat(-latestRot.ang.x, -latestRot.ang.y, -latestRot.ang.z, latestRot.ang.w)
				for index, node in pairs(latestData.nodes) do
					local cid = index - 1
					-- Get node pos from latest crash data
					local pos = float3(node[1], node[2], node[3])
					-- Put it as a quaternion with w = 0
					local p = quat(pos.x, pos.y, pos.z, 0)
					-- Should be newPos = H(H(r, p), rp) but for some reason the rotation is inverted
					local newPos = H(H(rp, p), r)
					dataToApply.nodes[index][1] = newPos.x
					dataToApply.nodes[index][2] = newPos.y
					dataToApply.nodes[index][3] = newPos.z
				end
			end
			calculated = true
		end
		for index, node in pairs(dataToApply.nodes) do
			cid = index - 1
			obj:setNodePosition(cid, float3(node[1], node[2], node[3]))
		end
		for index, beam in pairs(dataToApply.beams) do
			cid = index - 1
			obj:setBeamLength(cid, beam)
		end
	end
end



-- 1 = pos.x
-- 2 = pos.y
-- 3 = pos.z
-- 4 = rot.x
-- 5 = rot.y
-- 6 = rot.z
-- 7 = rot.w
local function applyRotation(tempRot) -- Rotation in Quaternions
	latestRot = jsonDecode(tempRot)
	calculated = false
end



M.H = H
M.applyRotation = applyRotation
M.toEulerAngles = toEulerAngles
M.requestRes 	= requestRes
M.round      	= round
M.rotate    	= rotate
M.distance   	= distance
M.applyNodes 	= applyNodes
M.getNodes   	= getNodes
M.updateGFX	    = onUpdate



return M
