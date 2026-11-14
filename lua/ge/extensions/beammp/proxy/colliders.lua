-- Copyright (C) 2026 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- beammp.proxy.colliders - invisible, pooled collision vehicles for proxies near the local vehicle (proxyCollision).
-- Moving a TSStatic with setPosRot only moves its render mesh, the static collision used by the vehicle physics is
-- baked and only rebuilt with be:reloadCollision() (a full world rebuild, see core/dynamicProps.lua), so a moving
-- static collision box is not viable. Vehicles collide with vehicles, so each close proxy borrows a cheap
-- simple_traffic vehicle of its size class, drawn with mesh alpha 0 (the proxy mesh stays what you see). It follows
-- the proxy through the regular positionVE mailbox ("vehPosPckt"..serverVehicleID) like a real remote vehicle.
-- Colliders are spawned on demand (a spawn stutters, so it shares the real spawn rate limit), parked with
-- setActive(0) when free and reused for the next proxy of the same class. Proxies longer than MAX_LEN (buses,
-- trailers) and walking players get none: no stock simple_traffic config is close to their shape.
local M = {}

local MAX_LEN = 8.5
local RELEASE_MARGIN = 15 -- m beyond the radius before a collider is taken back
-- size classes, first match wins (length / height of the proxy, m); simple_traffic configs of the game
local CLASSES = {
	{ name = "small", maxLen = 4.3, maxH = 1.65, config = "covet_base" },
	{ name = "medium", maxLen = 5.1, maxH = 1.65, config = "fullsize_stock" },
	{ name = "large", maxLen = 5.9, maxH = 2.0, config = "pickup_d15" },
	{ name = "van", maxLen = MAX_LEN, maxH = math.huge, config = "van_passenger" },
}

local colliders = {} -- [gameVehicleID] = { class = name, serverVehicleID = string|nil }
local count = 0

local function classFor(p)
	if p.isPerson or (p.L or 0) > MAX_LEN then return nil end
	for _, c in ipairs(CLASSES) do
		if (p.L or 4.5) <= c.maxLen and (p.H or 1.5) <= c.maxH then return c end
	end
	return nil
end

local function hide(veh)
	veh:setMeshAlpha(0, "", false)
end

function M.release(gameVehicleID)
	local c = colliders[gameVehicleID]
	if not c then return end
	local vehicle = c.serverVehicleID and MPVehicleGE.getVehicleByServerID(c.serverVehicleID)
	if vehicle and vehicle.proxyColliderID == gameVehicleID then vehicle.proxyColliderID = nil end
	c.serverVehicleID = nil
	local veh = getObjectByID(gameVehicleID)
	if veh then
		veh:queueLuaCommand("if MPVehicleVE then MPVehicleVE.setServerID('') end")
		veh:setActive(0)
	end
end

local function applyTarget(gameVehicleID)
	local c = colliders[gameVehicleID]
	local veh = getObjectByID(gameVehicleID)
	if not c or not veh or not c.serverVehicleID then return end
	veh:queueLuaCommand("if MPVehicleVE then MPVehicleVE.setVehicleType('R') MPVehicleVE.setServerID(mime.unb64('"..MPHelpers.b64encode(c.serverVehicleID).."')) end")
end

local function assign(gameVehicleID, vehicle)
	local c = colliders[gameVehicleID]
	local veh = getObjectByID(gameVehicleID)
	local p = vehicle.proxy
	if not c or not veh or not p then return end
	c.serverVehicleID = vehicle.serverVehicleString
	vehicle.proxyColliderID = gameVehicleID
	veh:setActive(1)
	hide(veh)
	-- same rotation convention as the reset packets (onServerVehicleResetted)
	veh:setPositionRotation(p.rpos.x, p.rpos.y, p.rpos.z, p.rrot.x, p.rrot.y, p.rrot.z, p.rrot.w)
	applyTarget(gameVehicleID)
end

--- Called by MPVehicleGE.onVehicleReady, the VE extensions of the collider are loaded now.
function M.onReady(gameVehicleID)
	if not colliders[gameVehicleID] then return false end
	local veh = getObjectByID(gameVehicleID)
	if veh then hide(veh) end
	applyTarget(gameVehicleID)
	return true
end

function M.isCollider(gameVehicleID)
	return colliders[gameVehicleID] ~= nil
end

function M.onDestroyed(gameVehicleID)
	local c = colliders[gameVehicleID]
	if not c then return end
	local vehicle = c.serverVehicleID and MPVehicleGE.getVehicleByServerID(c.serverVehicleID)
	if vehicle and vehicle.proxyColliderID == gameVehicleID then vehicle.proxyColliderID = nil end
	colliders[gameVehicleID] = nil
	count = count - 1
end

function M.removeAll()
	for gameVehicleID in pairs(colliders) do
		local veh = getObjectByID(gameVehicleID)
		colliders[gameVehicleID] = nil
		if veh then veh:delete() end
	end
	count = 0
end

function M.getCount()
	local used = 0
	for _, c in pairs(colliders) do if c.serverVehicleID then used = used + 1 end end
	return count, used
end

--- One pass (MPProxyGE decision interval). ctx: enabled, radius, poolSize, canSpawn, localVehPos (vec3, nil
-- without a local vehicle), model (proxyColliderModel; anything but "simple_traffic" is spawned with its default
-- config for every class). Returns true when it spawned a collider (the caller moves its spawn rate limit).
function M.releaseAll()
	for id, c in pairs(colliders) do if c.serverVehicleID then M.release(id) end end
end

function M.update(vehicles, ctx)
	if not ctx.enabled or not ctx.localVehPos then M.releaseAll() return false end
	local pos = ctx.localVehPos
	local r2 = ctx.radius * ctx.radius
	local release2 = (ctx.radius + RELEASE_MARGIN)^2
	for id, c in pairs(colliders) do
		if c.serverVehicleID then
			local v = vehicles[c.serverVehicleID]
			if not v or not v.isProxy or v.isSpawned or not v.proxy or v.proxy.rpos:squaredDistance(pos) > release2 then M.release(id) end
		end
	end
	-- the closest proxy inside the radius without a collider (one per pass keeps the work per pass small)
	local best, bestD2, bestClass = nil, r2, nil
	for _, v in pairs(vehicles) do
		local p = v.proxy
		if v.isProxy and not v.isSpawned and not v.isLocal and p and p.hasData and not v.proxyColliderID then
			local d2 = p.rpos:squaredDistance(pos)
			if d2 < bestD2 then
				local cl = classFor(p)
				if cl then best, bestD2, bestClass = v, d2, cl end
			end
		end
	end
	if not best then return false end
	local otherFree = nil
	for id, c in pairs(colliders) do
		if not c.serverVehicleID and getObjectByID(id) then
			if c.class == bestClass.name then assign(id, best) return false end
			otherFree = otherFree or id
		end
	end
	if not ctx.canSpawn then return false end
	if count >= ctx.poolSize then
		-- pool full: a parked collider of another class makes room (deleting is cheaper than the spawn after it)
		if not otherFree then return false end
		local veh = getObjectByID(otherFree)
		M.onDestroyed(otherFree)
		if veh then veh:delete() end
	end
	local custom = ctx.model and ctx.model ~= "" and ctx.model ~= "simple_traffic"
	local model = custom and ctx.model or "simple_traffic"
	local config = (not custom) and ("vehicles/simple_traffic/" .. bestClass.config .. ".pc") or nil
	local id = MPVehicleGE.spawnProxyCollider(model, best.proxy.rpos, best.proxy.rrot, config)
	if not id then return true end
	colliders[id] = { class = bestClass.name }
	count = count + 1
	local veh = getObjectByID(id)
	if veh then hide(veh) end
	log('I', 'MPProxyGE', string.format("Proxy collider %d (%s, %s) spawned for %s, pool %d/%d", id, bestClass.name, config or model,
		tostring(best.serverVehicleString), count, ctx.poolSize))
	assign(id, best)
	return true
end

return M
