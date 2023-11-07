--====================================================================================
-- All work by 20dka.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================
-- Helper functions for use in BeamMP and its extensions
--====================================================================================

--- MPHelpers API.
--- Author of this documentation is Titch
--- @module MPHelpers
--- @usage MPHelpers.hex2rgb(...) -- external access


local M = {}

setmetatable(_G,{}) -- temporarily disable global write notifications

--- Checks if two colors match by comparing their serialized values.
--- @param old table The first color to compare.
--- @param new table The second color to compare.
--- @return boolean True if the colors match, false otherwise.
local function colorMatch(old, new)
	return serialize(old) == serialize(new)
end

--- Converts a hexadecimal color code to RGB values.
--- @param hex string The hexadecimal color code to convert.
--- @return table RGB An array containing the RGB values of the color.
local function hex2rgb(hex)
  if not hex or not hex:find("^#[%x]+$") or #hex ~= 7 then   
    return { 0,0,0 }
  end
  local hex = hex:gsub("#","")
  if hex:len() == 3 then
    return { (tonumber("0x"..hex:sub(1,1))*17)/255 or 0, (tonumber("0x"..hex:sub(2,2))*17)/255 or 0, (tonumber("0x"..hex:sub(3,3))*17)/255 or 0 }
  else
    return { tonumber("0x"..hex:sub(1,2))/255 or 0, tonumber("0x"..hex:sub(3,4))/255 or 0, tonumber("0x"..hex:sub(5,6))/255 or 0 }
  end
end


--- Compares two tables and returns the differences between them.
--- @param old table The first table to compare.
--- @param new table The second table to compare.
--- @return table diff A table containing the differences between the two tables.
--- @return table o A table containing the values from the first table that are different from the second table.
--- @return table n A table containing the values from the second table that are different from the first table.
local function tableDiff(old, new)
	local diff, o, n = {},{},{}
	
	if not old then return new, {}, new end
	if not new then return old, old, {} end
	
	for k,v in pairs(old) do if new[k] ~= v then diff[k] = v; o[k] = v end end
	for k,v in pairs(new) do if old[k] ~= v then diff[k] = v; n[k] = v end end

	return diff, o, n
end

--- Returns a semi formatted string with information about the caller of this function.
--- @param level number The level of the stack trace to retrieve. (optional)
--- @return string A string containing the source file, line number, name type, and name of the caller.
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

--- Logs a message with information about the caller of this function.
--- @param level number The level of the stack trace to retrieve. (optional)
--- @usage `simpletrace()`
function simpletrace(level)
	level = (level or 1) +1
	--print('simpletrace level: '..level)
	log('I', 'simpletrace', "Code was called from: "..simpletraces(level+1))
end

-- ?
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
M.hex2rgb      = hex2rgb

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
