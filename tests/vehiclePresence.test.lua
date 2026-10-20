-- Run from the repository root: lua tests/vehiclePresence.test.lua
local function noop() end
vec3 = function() return {} end
quat = function() return {} end
ColorI = function() return {} end
color = function() return {} end
nop = noop
detectGlobalWrites = noop
core_vehicles = {}
extensions = {core_vehicle_partmgmt = {}, isExtensionLoaded = function() return false end}
gameplay_garageMode = {}
Engine = {}
settings = {getValue = function() return false end}

local multiplayer = true
MPCoreNetwork = {isMPSession = function() return multiplayer end}
local warnings = {}
log = function(level, tag, message)
	if level == "W" then warnings[#warnings + 1] = {tag = tag, message = message} end
end

local module = dofile("lua/ge/extensions/MPVehicleGE.lua")
local function upvalue(fn, name)
	for index = 1, math.huge do
		local key, value = debug.getupvalue(fn, index)
		if not key then error("Missing upvalue: "..name) end
		if key == name then return value end
	end
end

local vehicles = upvalue(module.isOwn, "vehicles")
local vehiclesMap = upvalue(module.isOwn, "vehiclesMap")
vehicles["1-0"] = {isLocal = true}
vehicles["2-0"] = {isLocal = false}
vehiclesMap[101] = "1-0"
vehiclesMap[202] = "2-0"

local count = 0
local function checkMode(vehicleId, initialMode, expected)
	local query = {player = 0, vehicleId = vehicleId, mode = initialMode}
	module.onResolveVehiclePresenceMode(query)
	assert(query.mode == expected, "Unexpected mode: "..tostring(query.mode))
	count = count + 1
end

checkMode(101, nil, "unrestricted")
checkMode(202, nil, nil)
checkMode(303, nil, nil)
checkMode(nil, nil, nil)
checkMode(101, "passenger", "passenger")
checkMode(101, "driver", "driver")
multiplayer = false
checkMode(101, nil, nil)
multiplayer = true

local network = upvalue(module.handle, "HandleNetwork")
local onServerVehicleSpawned = upvalue(network.s, "onServerVehicleSpawned")
local refresh = upvalue(onServerVehicleSpawned, "refreshUnseatedLocalPresence")
local presences = {}
local playerPresences = {}
local currentVehicles = {}
local requests = {}
local requestSuccess = true
be = {getPlayerVehicleID = function(_, player) return currentVehicles[player] end}
gameplay_seatOccupants = {
	getVehiclePresences = function() return presences end,
	getPlayerPresence = function(player) return playerPresences[player] end,
	requestUnseatedPresence = function(player, vehicleId, override)
		assert(override == nil, "Must not persist a permission override")
		local query = {player = player, vehicleId = vehicleId}
		module.onResolveVehiclePresenceMode(query)
		requests[#requests + 1] = {player = player, mode = query.mode}
		return requestSuccess, "testFailure"
	end,
}

local function presence(player, unseated, mode, currentVehicle, override)
	presences[#presences + 1] = {player = player, unseated = unseated, permissionMode = mode}
	playerPresences[player] = {permissionOverride = override}
	currentVehicles[player] = currentVehicle
end
presence(0, true, "passenger", 101)
presence(1, false, "passenger", 101)
presence(2, false, "driver", 101)
presence(3, true, "unrestricted", 101)
presence(4, true, "passenger", 202)
presence(5, true, "passenger", 101, "passenger")
presence(6, true, "passenger", 101)

refresh(101)
assert(#requests == 2 and requests[1].player == 0 and requests[2].player == 6)
assert(requests[1].mode == "unrestricted" and requests[2].mode == "unrestricted")
count = count + 1
requests = {}
refresh(202)
refresh(303)
assert(#requests == 0, "Remote and unknown vehicles must not be refreshed")
count = count + 1
multiplayer = false
refresh(101)
assert(#requests == 0, "Single-player must not be refreshed")
count = count + 1
multiplayer = true

local occupants = gameplay_seatOccupants
gameplay_seatOccupants = nil
refresh(101)
gameplay_seatOccupants = occupants
count = count + 1
requestSuccess = false
refresh(101)
assert(#warnings == 2 and warnings[1].message:find("testFailure", 1, true))
count = count + 1

-- Exercise the real spawn-acknowledgement path, not just the refresh helper.
requestSuccess = true
requests = {}
presences = {}
playerPresences = {}
presence(0, true, "passenger", 404)
MPConfig = {getPlayerServerID = function() return 1 end}
MPGameNetwork = {send = noop}
MPNetworkHelpers = {generatePacketBuffer = noop}
dumps = function() return "" end
dumpsz = dumps
jsonDecode = function() return {vid = 404, jbm = "pickup"} end
getObjectByID = function() return {getActive = function() return true end} end
module.getPlayers()[1] = {name = "LocalPlayer", addVehicle = noop}
assert(not module.isOwn(404))
checkMode(404, nil, nil)
module.handle('s:USER:LocalPlayer:1-1:{"vid":404,"jbm":"pickup"}')
assert(module.isOwn(404), "Acknowledgement must establish ownership")
assert(#requests == 1 and requests[1].mode == "unrestricted")
count = count + 1

print("Passed "..count.." vehicle presence regression checks")
