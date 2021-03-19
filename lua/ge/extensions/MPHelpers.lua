--====================================================================================
-- All work by 20dka.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================
-- Helper functions for use in BeamMP and its extensions
--====================================================================================

local M = {}

local function colorMatch(old, new) -- we assume the new color object has more data
	for k,v in ipairs(new) do
		for kk, vv in ipairs(v) do
			--dump(k, v, kk, vv)
			if not old[k] or not old[k][kk] or tostring(old[k][kk]):sub(1,7) ~= tostring(vv):sub(1,7) then
				--print(tostring(old[k][kk]))
				--print(tostring(vv))
				return false
			end
		end
	end
	return true
end

local function tableDiff(old, new)
	local diff, o, n = {},{},{}
	
	if not old then return new, {}, new end
	if not new then return old, old, {} end
	
	for k,v in pairs(old) do if new[k] ~= v then diff[k] = v; o[k] = v end end
	for k,v in pairs(new) do if old[k] ~= v then diff[k] = v; n[k] = v end end

	return diff, o, n
end


--generic
M.tableLength  = tableSize

--local
M.colorMatch   = colorMatch
M.tableDiff    = tableDiff


local function onExtensionLoaded()

	dump("ONEXTENSIONLOADED:")
	if MPVehicleGE then
		print("MPVehicleGE exists!")
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
	end
end

M.onExtensionLoaded = onExtensionLoaded

return M
