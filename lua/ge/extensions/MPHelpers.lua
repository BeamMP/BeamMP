-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- MPHelpers API.
--- Author of this documentation is Titch
--- @module MPHelpers
--- @usage MPHelpers.hex2rgb(...) -- external access


local M = {}
local LOCALISATION = nil
local mime = require'mime' -- Game libary. Used in BeamNG.drive\lua\common\libs\luasocket\socket\mime.lua. We only use it for b64

setmetatable(_G,{}) -- temporarily disable global write notifications

--- Returns the decoded lang table from disk
-- @tparam[opt] string lang Language code
-- @usage getLang("en-US")
-- @treturn[1] table if Success
-- @treturn[2] nil if failure
local function getLang(lang)
	local lang = lang or settings.getValue("userLanguage") or "en-US"
	local langpath = "/locales/" .. lang .. ".json"
	local handle = io.open(langpath, "r")
	if handle == nil then return nil end -- shouldnt happen
	local data = handle:read("*all")
	handle:close()
	return jsonDecode(data)
end

--- Turns translation code into language string
-- Returns the translation for the lang the player is using. Will alternatively try the en-US lang. If both not present returns the text given in useifnotpresent and if that is not given, returns which.
-- @tparam string which Give translation string
-- @tparam[opt] string useifnotpresent Used if which cannot be found
-- @usage MPTranslate("ui.options.multiplayer.fadeVehicles", "Fade out vehicles as they get closer")
-- @usage MPTranslate("ui.options.multiplayer.fadeVehicles")
-- @treturn[1] string if success. Translation string
-- @treturn[2] string if failure but useifnotpresent is given. useifnotpresent string
-- @treturn[3] string if failure. which string
function MPTranslate(which, useifnotpresent) -- global! translate() was a global func in earlier beamng builds. so we wont take that, in case it comes back
	-- if lang table not loaded or lang changed, load
	local lang = settings.getValue("userLanguage") or "en-US" -- can be nil if the user never switched the main language. main language is en-US
	if LOCALISATION == nil or LOCALISATION.lang ~= lang then
		LOCALISATION = {}
		LOCALISATION.lang = lang
		LOCALISATION.translate = getLang(lang)
	end
	
	-- entry unknown or localisation not found
	if LOCALISATION.translate == nil or LOCALISATION.translate[which] == nil then
		if LOCALISATION.lang ~= "en-US" then -- try eng variant
			local translate = getLang("en-US")
			if translate == nil or translate[which] == nil then -- not present here either
				return useifnotpresent or which
			end
			return translate[which]
		end
		return useifnotpresent or which
	end
	return LOCALISATION.translate[which]
end

--- Checks if two colors match by comparing their serialized values.
-- @param old table The first color to compare.
-- @param new table The second color to compare.
-- @return boolean True if the colors match, false otherwise.
local function colorMatch(old, new)
	return serialize(old) == serialize(new)
end

--- Base64 encodes a string (RFC 2045)
-- @tparam string string The string to be encoded
-- @treturn[1] string Base64
local function b64encode(string)
	return mime.b64(string)
end

--- Decodes a base64 string (RFC 2045)
-- @tparam string string The base64 string
-- @treturn[1] string Decoded string
local function b64decode(string)
	return mime.unb64(string)
end

--- Converts a hexadecimal color code to RGB values.
-- @param hex string The hexadecimal color code to convert.
-- @return table RGB An array containing the RGB values of the color.
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
-- @param old table The first table to compare.
-- @param new table The second table to compare.
-- @return table diff A table containing the differences between the two tables.
-- @return table o A table containing the values from the first table that are different from the second table.
-- @return table n A table containing the values from the second table that are different from the first table.
local function tableDiff(old, new)
	local diff, o, n = {},{},{}
	
	if not old then return new, {}, new end
	if not new then return old, old, {} end
	
	for k,v in pairs(old) do if new[k] ~= v then diff[k] = v; o[k] = v end end
	for k,v in pairs(new) do if old[k] ~= v then diff[k] = v; n[k] = v end end

	return diff, o, n
end

--- Splits the given string by the given delimeter and optionally converts the slices into the desired type
-- @param string string Some string to be split eg. "Hello World"
-- @param delimeter string Delimeter to split by, eg. " "
-- @param convert_into nil/number nil = string, 1 = number, 2 = bool
-- @return table t [1..n] = string, number or bool
local function splitStringToTable(string, delimeter, convert_into)
	local t = {}
	for str in string.gmatch(string, "([^"..delimeter.."]+)") do
		if convert_into == 1 then -- number
			table.insert(t, tonumber(str))
			
		elseif convert_into == 2 then -- bool
			if str:lower() == "false" then
				table.insert(t, false)
			elseif str:lower() == "true" then
				table.insert(t, false)
			end
			
		else -- string
			table.insert(t, str)
		end
	end
	return t
end

--- Reads the vehicles color directly from the obj instead of from the vehicle_manager.lua
-- @param veh object Vehicle object from eg. be:getObjectByID(gameVehicleID)
-- @return table paints Same format as extensions.core_vehicle_manager.getVehicleData(gameVehicleID).config.paints
local function getColorsFromVehObj(veh)
	local paints = {}

	local metallicPaintData = veh:getMetallicPaintData()
	paints[1] = createVehiclePaint(veh.color, metallicPaintData[1])
	paints[2] = createVehiclePaint(veh.colorPalette0, metallicPaintData[2])
	paints[3] = createVehiclePaint(veh.colorPalette1, metallicPaintData[3])

	return paints
end

--- Returns a semi formatted string with information about the caller of this function.
-- @param[opt] level number The level of the stack trace to retrieve.
-- @return string A string containing the source file, line number, name type, and name of the caller.
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
-- @param[opt] level number The level of the stack trace to retrieve.
-- @usage simpletrace()
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
	
	M.translate                = MPTranslate
end

M.b64encode                = b64encode
M.b64decode                = b64decode
M.getColorsFromVehObj      = getColorsFromVehObj
M.splitStringToTable       = splitStringToTable

M.onExtensionLoaded = onExtensionLoaded
M.onInit = function() setExtensionUnloadMode(M, "manual") end

return M
