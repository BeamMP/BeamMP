--====================================================================================
-- All work by 20dka.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================
-- Helper functions for use in BeamMP and its extensions
--====================================================================================

local M = {}

setmetatable(_G,{}) -- temporarily disable global write notifications

local function colorMatch(old, new)
	return serialize(old) == serialize(new)
end

local function tableDiff(old, new)
	local diff, o, n = {},{},{}
	
	if not old then return new, {}, new end
	if not new then return old, old, {} end
	
	for k,v in pairs(old) do if new[k] ~= v then diff[k] = v; o[k] = v end end
	for k,v in pairs(new) do if old[k] ~= v then diff[k] = v; n[k] = v end end

	return diff, o, n
end

function simpletraces(level)
	level = (level or 2) +1
	--level = level+1
	--print('simpletraces level: '..level)
	local info = debug.getinfo(level)
	if info then
		return string.format("%s:%i, %s %s", info.source, info.currentline, info.namewhat, info.name)
	else
		return "unknown"
	end
end
function simpletrace(level)
	level = (level or 1) +1
	--print('simpletrace level: '..level)
	log('I', 'simpletrace', "Code was called from: "..simpletraces(level+1))
end

do 
local _pairs = pairs 
function pairs (value) 
	local g = getmetatable(value) 
	if g then 
		if type(g.__pairs) == "function" then 
			return g.__pairs(value) 
		else 
			return _pairs(value) 
		end 
	else 
		return _pairs(value) 
	end 
end 
end

--generic
M.tableLength  = tableSize

--local
M.colorMatch   = colorMatch
M.tableDiff    = tableDiff

detectGlobalWrites() -- reenable global write notifications


local function onExtensionLoaded()
	if not MPVehicleGE then return end -- files weren't loaded in the right order :(

	-- MPVehicleGE
	M.isOwn                    = MPVehicleGE.isOwn                    -- takes: vehID  returns: bool
	M.getOwnMap                = MPVehicleGE.getOwnMap                -- takes: -      returns: { 'vehid' : true, '23456' : true }
	M.getDistanceMap           = MPVehicleGE.getDistanceMap           -- takes: -      returns: { vehid : distanceinmeters, 123: 56 }
	M.getVehicleMap            = MPVehicleGE.getVehicleMap            -- takes: -
	M.getNicknameMap           = MPVehicleGE.getNicknameMap           -- takes: -
	M.hideNicknames            = MPVehicleGE.hideNicknames            -- takes: bool   returns: -
	M.setPlayerNickPrefix      = MPVehicleGE.setPlayerNickPrefix      -- takes: string targetName, string tagSource, string text
	M.setPlayerNickSuffix      = MPVehicleGE.setPlayerNickSuffix      -- takes: string targetName, string tagSource, string text
	M.getGameVehicleID         = MPVehicleGE.getGameVehicleID         -- takes: -      returns: { 'gamevehid' : 'servervehid', '23456' : '1-2' }
	M.getServerVehicleID       = MPVehicleGE.getServerVehicleID       -- takes: -      returns: { 'servervehid' : 'gamevehid', '1-2' : '23456' }
	M.applyQueuedEvents        = MPVehicleGE.applyQueuedEvents        -- takes: -
	M.teleportVehToPlayer      = MPVehicleGE.teleportVehToPlayer      -- takes: string targetName
	M.teleportCameraToPlayer   = MPVehicleGE.focusCameraOnPlayer      -- takes: string targetName NOTE: DEPRECATED
	M.focusCameraOnPlayer      = MPVehicleGE.focusCameraOnPlayer      -- takes: string targetName
	M.groundmarkerToPlayer     = MPVehicleGE.groundmarkerToPlayer     -- takes: string targetName
	M.groundmarkerFollowPlayer = MPVehicleGE.groundmarkerFollowPlayer -- takes: string targetName

	--MPGameNetwork
	--M.addKeyEventListener = MPGameNetwork.addKeyEventListener -- takes: string keyName, function listenerFunction
	--M.getKeyState         = MPGameNetwork.getKeyState         -- takes: string keyName
end

M.onExtensionLoaded = onExtensionLoaded

return M
