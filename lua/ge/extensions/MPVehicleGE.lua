-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- MPVehicleGE API - This is responsible for all Vehicle related controlling within BeamMP for the Game Engine (GE).
-- Author of this documentation is Neverless
-- @module MPVehicleGE
-- @usage local gameVehicleID = getGameVehicleID("0-0") -- internal access
-- @usage local gameVehicleID = MPVehicleGE.getGameVehicleID("0-0") -- external access


local M = {}

local jbeamIO = require('jbeam/io') -- to be used later for getting slotting information of parts

setmetatable(_G,{}) -- temporarily disable global notifications

-- ============= VARIABLES =============
local lastResetTime = {}
local oneSecCounter = 0
local nicknamesAllowed = true
local onVehicleDestroyedAllowed = true
local nextSpawnIsRemote = false
local editSyncTimer = 0
local localCounter = 0
local vehiclesToSync = {}
local sentPastVehiclesYet = true
local queueApplyTimer = 0
local isAtSyncSpeed = true
local hideNicknamesToggle = false

local original_removeAllExceptCurrent
local original_spawnNewVehicle
local original_replaceVehicle
local original_spawnDefault


--- Contains Information about Backend authorized Roles
-- @table roleToInfo
-- @tfield roleToInfo_subtable RoleName_1 Contains the Role Specific Data
-- @tfield roleToInfo_subtable RoleName_N ..
-- @usage local roleInfo = roleToInfo["USER"]
local roleToInfo = {
	['USER']	= { backcolor = { r = 000, g = 000, b = 000 }, forecolor = { r = 255, g = 255, b = 255 }, tag = "", shorttag = "" },
	['EA']		= { backcolor = { r = 069, g = 000, b = 150 }, forecolor = { r = 193, g = 139, b = 255 }, tag = " [Early Access]", shorttag = " [EA]" },
	['CONT']	= { backcolor = { r = 069, g = 000, b = 150 }, forecolor = { r = 193, g = 139, b = 255 }, tag = " [Contributor]", shorttag = " [CO]" },
	['YT']		= { backcolor = { r = 200, g = 000, b = 000 }, forecolor = { r = 255, g = 000, b = 000 }, tag = " [Content Creator]", shorttag = " [CC]" },
	['ET']		= { backcolor = { r = 210, g = 214, b = 109 }, forecolor = { r = 210, g = 214, b = 109 }, tag = " [Events Team]", shorttag = " [Events]" },
	['SUPPORT']	= { backcolor = { r = 068, g = 109, b = 184 }, forecolor = { r = 099, g = 154, b = 255 }, tag = " [Support]", shorttag = " [Staff]" },
	['STAFF']	= { backcolor = { r = 068, g = 109, b = 184 }, forecolor = { r = 099, g = 154, b = 255 }, tag = " [BeamMP Staff]", shorttag = " [Staff]" },
	['MOD']		= { backcolor = { r = 068, g = 109, b = 184 }, forecolor = { r = 099, g = 154, b = 255 }, tag = " [Moderator]", shorttag = " [Mod]" },
	['ADM']		= { backcolor = { r = 218, g = 000, b = 078 }, forecolor = { r = 255, g = 000, b = 089 }, tag = " [Admin]", shorttag = " [Adm]" },
	['MDEV']	= { backcolor = { r = 194, g = 055, b = 055 }, forecolor = { r = 255, g = 070, b = 101 }, tag = " [BeamMP Dev]", shorttag = " [Dev]" },
	['NGDEV']	= { backcolor = { r = 252, g = 107, b = 003 }, forecolor = { r = 252, g = 107, b = 003 }, tag = " [BeamNG Developer]", shorttag = " [BNG]" },
	['NGSTAFF']	= { backcolor = { r = 252, g = 107, b = 003 }, forecolor = { r = 252, g = 107, b = 003 }, tag = " [BeamNG Staff]", shorttag = " [BNG]" },
	['NGAFFIL']	= { backcolor = { r = 252, g = 107, b = 003 }, forecolor = { r = 252, g = 107, b = 003 }, tag = " [BeamNG Affiliate]", shorttag = " [BNG]" }
}

--- (in table) Specifies the table in roleToInfo
-- @table roleToInfo_subtable
-- @tfield ColorI backcolor Contains RGBA Values wiki.beamng.com/Lua:Reference#ColorI
-- @tfield string tag Contains the Tag
-- @tfield string shorttag Contains the Short version of Tag
-- @usage local roleInfo = roleToInfo["USER"].tag
-- @usage local roleInfo = roleToInfo["USER"].backcolor.r

--- Contains the known simplified Vehicle versions.
-- JBeamNames are Strings eg. "moonhawk", "unicycle"
-- @table simplified_vehicles
-- @tfield string JBeamName_1 eg. "simple_traffic_body_5door_wagon"
-- @tfield string JBeamName_N
-- @usage local simplified = simplified_vehicles["coupe"]
local simplified_vehicles = {
	atv         = "simple_traffic_atv",
	autobello   = "simple_traffic_autobello",
	barstow     = "simple_traffic_body_2door_coupe",
	bastion     = "simple_traffic_body_4door_sedan",
	bluebuck    = "simple_traffic_body_4door_sedan",
	bolide      = "simple_traffic_bolide",
	burnside    = "simple_traffic_body_4door_sedan",
	bx          = "simple_traffic_body_2door_coupe",
	citybus     = "simple_traffic_citybus",
	covet       = "simple_traffic_body_3door_hatch",
	etk800      = "simple_traffic_body_5door_wagon",
	etkc        = "simple_traffic_body_2door_coupe",
	etki        = "simple_traffic_body_4door_sedan",
	fullsize    = "simple_traffic_body_4door_sedan", -- THIS DOES NOT WORK, IT SHOULD REPLACE THE FRAME SLOT BUT WE ONLY DOING BODY SLOT RIGHT NOW
	hopper      = "simple_traffic_hopper",
	lansdale    = "simple_traffic_body_5door_wagon",
	legran      = "simple_traffic_body_4door_sedan",
	midsize     = "simple_traffic_body_4door_sedan",
	midtruck    = "simple_traffic_midtruck",
	miramar     = "simple_traffic_body_4door_sedan",
	moonhawk    = "simple_traffic_body_2door_coupe",
	pessima     = "simple_traffic_body_4door_sedan",
	pickup      = "simple_traffic_body_d10", -- THIS DOES NOT WORK, IT SHOULD REPLACE THE FRAME SLOT BUT WE ONLY DOING BODY SLOT RIGHT NOW
	pigeon      = "simple_traffic_pigeon",
	racetruck   = "simple_traffic_racetruck",
	roamer      = "simple_traffic_body_5door_wagon", -- THIS DOES NOT WORK, IT SHOULD REPLACE THE FRAME SLOT BUT WE ONLY DOING BODY SLOT RIGHT NOW
	rockbouncer = "simple_traffic_rockbouncer",
	sbr         = "simple_traffic_body_2door_coupe",
	scintilla   = "simple_traffic_scintilla",
	sunburst    = "simple_traffic_body_4door_sedan",
	us_semi     = "simple_traffic_us_semi",
	utv         = "simple_traffic_utv",
	van         = "simple_traffic_body_6door_van", -- THIS DOES NOT WORK, IT SHOULD REPLACE THE FRAME SLOT BUT WE ONLY DOING BODY SLOT RIGHT NOW
	vivace      = "simple_traffic_vivace", -- why are you always the weird one
	wendover    = "simple_traffic_body_2door_coupe",
	wigeon      = "simple_traffic_wigeon"
}

local settingsCache = {
}
-- ============= VARIABLES =============

--- Contains all known Players.
-- PlayerID's are integers starting at 0
-- @table players
-- @tfield players_subtable PlayerID_1 Contains all information known about this Player
-- @tfield players_subtable PlayerID_N ..
-- @usage local player = players[0]
local players = {}

--- (in table) Specifies the table in players
-- @table players_subtable
-- @tfield string name Holds the PlayerName linked to this PlayerID
-- @tfield integer activeVehicleID Contains the serverVehicleID as eg. 0 not 0-0, that the Client is currently Viewing. Can be the players own vehicle or another players vehicle.
-- @tfield string shortname Shortend name of the Shortnames Option
-- @tfield integer playerID ID that the Server has given this Player
-- @tfield bool isLocal true if this player is this client
-- @tfield integer ping Contains the current known ping of this Player
-- @tfield players_nickPrefixes nickPrefixes Contains all Prefixes for Tag drawing
-- @tfield players_nickSuffixes nickSuffixes Contains all Suffixes for Tag drawing
-- @tfield players_role role Contains information about the backend authorized Role of this Player
-- @tfield players_vehicles vehicles Note from the Author of this Documentation: Im unsure about this tables contents
-- @usage local name = players[0].name

--- (in table) Specifies the nickPrefixes table for players_subtable
-- @table players_nickPrefixes
-- @tfield string tagSource_1 Contains the added Text
-- @tfield string tagSource_N Contains the added Text
-- @usage local prefixes = players[0].nickPrefixes

--- (in table) Specifies the nickSuffixes table for players_subtable
-- @table players_nickSuffixes
-- @tfield string tagSource_1 Contains the added Text
-- @tfield string tagSource_N Contains the added Text
-- @usage local suffixes = players[0].nickSuffixes

--- (in table) Specifies the role table for players_subtable
-- @table players_role
-- @tfield string name Name of the Role
-- @tfield ColorI backcolor RGBA color. Can be nil
-- @tfield string tag Can be nil
-- @tfield string shorttag Can be nil
-- @usage local roleInfo = players[0].role
-- @usage local roleInfo = players[0].role.backcolor.r

--- (in table) Specifies the vehicles table for players_subtable.
-- Note from the Author of this Documentation: Im unsure about this tables contents
-- @table players_vehicles
-- @tfield integer gameVehicleID
-- @tfield bool isSpawned
-- @tfield unknown IDs

--- Contains all known Multiplayer Vehicles.
-- serverVehicleID is a String X-Y. Where X is the PlayerID and Y the Players VehicleID
-- @table vehicles
-- @tfield vehicles_subtable serverVehicleID_1 Contains all known vehicle related Information
-- @tfield vehicles_subtable serverVehicleID_N ..
-- @usage local vehicle = vehicles["0-0"]
local vehicles = {}

--- (in table) Specifies the table in vehicles
-- @table vehicles_subtable
-- @tfield string name Holds the OwnerName of this Vehicle
-- @tfield integer gameVehicleID The ID that the game gives this Vehicle on Spawn
-- @tfield string jbeam JBeam name of the Vehicle
-- @tfield integer remoteVehID gameVehicleID on the Client that owns this Vehicle
-- @tfield integer serverVehicleString serverVehicleID as eg. 0 not 0-0
-- @tfield integer ownerID The PlayerID of the player that owns this Vehicle
-- @tfield string Holds the OwnerName of that Vehicle (duplicate?)
-- @tfield bool isLocal True when this Vehicle is owned by this Client
-- @tfield bool isSpawned True once the Vehicle is no longer quoed and Available in the World. Is set to False when isDeleted
-- @tfield bool isDeleted True once the Vehicle has been deleted by the Client (it becomes a black blob)
-- @tfield nil position Appears to be unused
-- @tfield nil rotation Appears to be unused
-- @tfield vehicles_spectators spectators Holds PlayerID's that are spectating this Vehicle at the moment
-- @tfield vehicles_spawnQueue spawnQueue Holds the data required for when the Spawn is triggered. Is nil if this Vehicles Spawn is not qued.
-- @tfield string editQueue Holds the data required for when a Edit is triggered. serverVehicleID:{vehicleJson}. Is nil is no Edit for this Vehicle is qued
-- @usage local gameVehicleID = vehicles["0-0"].gameVehicleID

--- (in table) Specifies the spectators table in vehicles_subtable.
-- Every player in this table is currently spectating this vehicle
-- @table vehicles_spectators
-- @tfield true PlayerID_1
-- @tfield true PlayerID_N
-- @usage for PlayerID, v in pairs(vehicles["0-0"].spectators) do end
-- @usage local spectators = vehicles["0-0"].spectators

--- (in table) Specifies the spawnQueue table in vehicles_subtable
-- @table vehicles_spawnQueue
-- @tfield string playerNickname OwnerName of the Vehicle to be Spawned
-- @tfield string serverVehicleID serverVehicleID as eg. 0-0
-- @tfield string data Format = ROLE:PlayerName:serverVehicleID:{vehicleJson}
-- @usage if vehicles["0-0"].spawnQueue then local vehicleData = vehicles["0-0"].spawnQueue.data end

--- Resolves gameVehicleID to serverVehicleID
-- @table vehiclesMap
-- @tfield integer gameVehicleID_1 Contains serverVehicleID as eg. 0 not 0-0
-- @tfield integer gameVehicleID_N ..
-- @usage local serverVehicleID = vehiclesMap[11171]
local vehiclesMap = {}

--- Contains the Distances in meters from the Clients POV to the known Multiplayer Vehicles
-- @table distanceMap
-- @tfield float gameVehicleID_1
-- @tfield float gameVehicleID_N
-- @usage local distanceTo = distanceMap[11171]
local distanceMap = {}

-- decoded vehicle data of all players
local players_vehicle_configs = {}

-- VV============== FUNCTIONS USEABLE BY SCRIPTERS ==============VV

--- Resolves a serverVehicleID into the gameVehicleID
-- @tparam string serverVehicleID X-Y. Where X is the PlayerID and Y the Players VehicleID
-- @treturn[1] integer If success eg. 11171
-- @treturn[2] -1 If either the Vehicle is unknown or the Vehicle is not Spawned on the Client
-- @usage local gameVehicleID = getGameVehicleID("0-0")
function getGameVehicleID(serverVehicleID)
	if vehicles[serverVehicleID] and vehicles[serverVehicleID].gameVehicleID then
		return vehicles[serverVehicleID].gameVehicleID
	else
		log('E', 'getGameVehicleID', "can't get game id from " .. serverVehicleID)
		return -1
	end
end


--- Resolves a gameVehicleID into the serverVehicleID
-- @tparam integer gameVehicleID
-- @treturn[1] string If success. serverVehicleID eg. "0-0"
-- @treturn[2] nil If either the gameVehicleID is unknown or invalid
-- @usage local serverVehicleID = getServerVehicleID(11171)
function getServerVehicleID(gameVehicleID)
	if type(gameVehicleID) == "string" then
		log('W', "getServerVehicleID", "received string ID, please use numbers")
		gameVehicleID = tonumber(gameVehicleID)
	end

	if not vehiclesMap[gameVehicleID] or not vehicles[vehiclesMap[gameVehicleID]] then
		log('E', 'getServerVehicleID', "can't get server id from " .. tostring(gameVehicleID))
		log('M', 'getServerVehicleID', debug.traceback())
		return
	end

	return vehiclesMap[gameVehicleID]
end

--- Returns the vehicle table for this Vehicle
-- @tparam string serverVehicleID X-Y. Where X is the PlayerID and Y the Players VehicleID
-- @treturn[1] vehicles_subtable
-- @treturn[2] nil If the serverVehicleID is invalid
-- @usage local vehicle = getVehicleByServerID("0-0")
function getVehicleByServerID(serverVehicleID)
	return vehicles[serverVehicleID]
end

--- Returns the vehicle table for this Vehicle
-- @tparam integer gameVehicleID
-- @treturn[1] vehicles_subtable
-- @treturn[2] nil If the gameVehicleID is invalid
-- @usage local vehicle = getVehicleByGameID(11171)
function getVehicleByGameID(gameVehicleID)
	return vehicles[vehiclesMap[gameVehicleID]]
end

--- Returns this Players table and ID
-- @tparam string name The Players Name
-- @treturn[1] players_subtable
-- @treturn[1] integer playerID
-- @treturn[2] nil If the name is invalid
-- @usage local player, playerID = getPlayerByName("Neverless")
function getPlayerByName(name)
	for playerID, player in pairs(players) do
		if player.name == name then
			return player, playerID
		end
	end
end

--- Checks if the given vehicle belongs to this Client
-- @tparam integer gameVehicleID
-- @treturn[1] bool true if this Vehicle belongs to this Client
-- @treturn[2] bool false if this Vehicle does not belong to this Client or when the Vehicle does not exist
-- @usage if getServerVehicleID(11171) ~= nil and isOwn(11171) then local isOwn = true end -- only true when the vehicle exists and isOwn()
-- @usage local isOwn = isOwn(11171)
function isOwn(gameVehicleID)
	if type(gameVehicleID) == "string" then
		log('W', "isOwn", "received string ID, please use numbers")
		gameVehicleID = tonumber(gameVehicleID)
	end
	return vehicles[vehiclesMap[gameVehicleID]] and vehicles[vehiclesMap[gameVehicleID]].isLocal == true or false
end

--- Returns a table that contains a list of all Vehicles that are owned by this Client
-- @treturn table {gameVehicleID_1 = vehicles_subtable}
-- @treturn table {gameVehicleID_N = vehicles_subtable}
-- @usage local myVehicles = getOwnMap()
-- @see vehicles_subtable
function getOwnMap()
	local own = {}

	for serverVehicleID, vehicle in pairs(vehicles) do
		if vehicle.isLocal then
			own[vehicle.gameVehicleID] = vehicle
		end
	end
	return own
end

--- Returns a table of all known multiplayer vehicles
-- @treturn table {serverVehicleID_1 = gameVehicleID}
-- @treturn table {serverVehicleID_N = gameVehicleID}
-- @usage local vehicles = getVehicleMap()
function getVehicleMap()
	local t = {}

	for serverVehicleID, vehicle in pairs(vehicles) do
		t[serverVehicleID] = vehicle.gameVehicleID
	end
	return t
end

--- Returns a table containing the distance from each Multiplayer Vehicle to this Clients Point of View
-- @treturn distanceMap
-- @usage local distanceMap = getDistanceMap()
function getDistanceMap()
	return distanceMap
end

--- Returns a table containing all Multiplayer gameVehicleID's with their Ownernames
-- @treturn table {gameVehicleID_1 = OwnerName}
-- @treturn table {gameVehicleID_N = OwnerName}
-- @usage local nicknameMap = getNicknameMap()
function getNicknameMap() -- Returns a [localID] = "username" table of all vehicles, including own ones
	local nicknameSimple = {}

	for serverVehicleID, v in pairs(vehicles) do
		nicknameSimple[v.gameVehicleID] = v.ownerName
	end

	return nicknameSimple
end

--- Adds a Prefix to a given PlayerTag.
-- eg. "1st. Neverless". You can set multiple by having alternating tagSource's
-- @tparam string targetName PlayerName
-- @tparam string tagSource Name of the Prefix
-- @tparam string text Text to add
-- @treturn nil
-- @usage setPlayerNickPrefix("Neverless", "MYPREFIX", "1st.")
function setPlayerNickPrefix(targetName, tagSource, text)
	if targetName == nil then return end
	for k,player in pairs(players) do
		if player.name == targetName then
			player:setNickPrefix(tagSource, text)
			return
		end
	end
end

--- Adds a Suffix to a given PlayerTag.
-- eg. "Neverless [In Mission]". You can set multiple by having alternating tagSource's
-- @tparam string targetName PlayerName
-- @tparam string tagSource Name of the Prefix
-- @tparam string text Text to add
-- @treturn nil
-- @usage setPlayerNickSuffix("Neverless", "MYSUFFIX", "[In Mission]")
function setPlayerNickSuffix(targetName, tagSource, text)
	if targetName == nil then return end
	for k,player in pairs(players) do
		if player.name == targetName then
			player:setNickSuffix(tagSource, text)
			return
		end
	end
end

--- Turns On or Off the Nametag drawing from BeamMP
-- @tparam bool hide
-- @treturn nil
-- @usage hideNicknames(true)
function hideNicknames(hide)
	nicknamesAllowed = not hide
end


--- Simple function to toggle the displaying of nametags. This is only for the current lua instance and does not persist between restarts.
-- @usage `MPVehicleGE.toggleNicknames()`
function toggleNicknames() hideNicknamesToggle = not hideNicknamesToggle end

--- Returns the whole Players table
-- @treturn players
-- @usage local players = getPlayers()
function getPlayers() return players end

--- Returns the whole Vehicles table
-- @treturn vehicles
-- @usage local vehicles = getVehicles()
function getVehicles() return vehicles end

local function createRoleHelper(tag, shorttag, red, green, blue)
	if type(red) ~= "number" then return nil, "invalid red channel data" end
	if type(green) ~= "number" then return nil, "invalid green channel data" end
	if type(blue) ~= "number" then return nil, "invalid blue channel data" end

	local contents = { backcolor = { r = clamp(red, 0, 255), g = clamp(green, 0, 255), b = clamp(blue, 0, 255)}, tag = "", shorttag = "" }
	if type(tag) == "string" then
		contents.tag = " [" .. tag .. "]"
	end

	if type(shorttag) == "string" then
		contents.shorttag = " [" .. shorttag .. "]"
	end

	return contents
end

--- Sets a custom role for a player
-- @tparam int playerID ID of the player
-- @tparam string tag normal version of the role tag
-- @tparam string shorttag shortened version of the role tag
-- @tparam int red red channel of the role's color
-- @tparam int green green channel of the role's color
-- @tparam int blue blue channel of the role's color
-- @treturn bool true in case of success, false in case of error
-- @treturn nil, string error message
-- @usage local success, error = setPlayerRole(0, "Example", "EX", 0, 127, 255)
function setPlayerRole(playerID, ...)
	local p = players[playerID]
	if not p then return false, "player not found" end

	local role, err = createRoleHelper(...)
	if not role then
		log('E', 'setPlayerRole', 'Function called with invalid arguments: ' .. tostring(err))
		return false, err
	end

	p:setCustomRole(role)
end

--- Clears a custom role for a player
-- @tparam int playerID ID of the player
-- @treturn bool true in case of success, false in case of error
-- @usage local success, error = clearPlayerRole(0)
function clearPlayerRole(playerID)
	return players[playerID] and players[playerID]:clearCustomRole() or false
end

--- Sets a custom role for a vehicle
-- @tparam string playerIDVehicleID ID of the vehicle
-- @tparam string tag normal version of the role tag
-- @tparam string shorttag shortened version of the role tag
-- @tparam int red red channel of the role's color
-- @tparam int green green channel of the role's color
-- @tparam int blue blue channel of the role's color
-- @treturn bool true in case of success, false in case of error
-- @treturn nil, string error message
-- @usage local success, error = setVehicleRole("0-0", "Example", "EX", 0, 127, 255)
function setVehicleRole(playerIDVehicleID, ...)
	local v = vehicles[playerIDVehicleID]
	if not v then return false, "vehicle not found" end

	local role, err = createRoleHelper(...)
	if not role then
		log('E', 'setVehicleRole', 'Function called with invalid arguments: ' .. tostring(err))
		return false, err
	end

	v:setCustomRole(role)
end

--- Clears a custom role for a vehicle
-- @tparam string playerIDVehicleID ID of the vehicle
-- @treturn bool true in case of success, false in case of error
-- @usage local success, error = clearVehicleRole("0-0")
function clearVehicleRole(playerIDVehicleID)
	return vehicles[playerIDVehicleID] and vehicles[playerIDVehicleID]:clearCustomRole() or false
end

-- ============== INTERNAL FUNCTIONS ==============

--- Sets if the given given Vehicle belongs to this Client
-- @tparam string serverVehicleID X-Y. Where X is the PlayerID and Y the Players VehicleID
-- @tparam bool own
-- @treturn nil
-- @usage setOwn("0-0", true)
local function setOwn(serverVehicleID, own)
	vehicles[serverVehicleID].isLocal = own
end

local function localVehiclesExist()
	for k, v in pairs(vehicles) do
		if v.isLocal then return true end
	end
	return false
end

local vehicleSimplifiers = {
	-- complicated chaos, just looking at this put me in tears

	bastion = function(vehicleParts) -- case 1, simple body replace
		vehicleParts["bastion_body"] = "simple_traffic_body_4door_sedan"
	end,
	bx = function(vehicleParts) -- case 2, correspond with what body is used -- nvm this is minor chaos
		vehicleParts["bx_body"] = "simple_traffic_body_2door_coupe"
		if vehicleParts["bx_body"] == "bx_body_coupe" then
			--vehicleParts["simple_traffic_bodystyle"] = "simple_traffic_bodystyle_coupe" -- is default already
		else
			if vehicleParts["bx_fenderflare_RR"] == "bx_fenderflare_RR" and vehicleParts["bx_fenderflare_RL"] == "bx_fenderflare_RL"
			and ((vehicleParts["bx_fenderflare_FR_popup"] == "bx_fenderflare_FR_popup" and vehicleParts["bx_fenderflare_FL_popup"] == "bx_fenderflare_FL_popup")
			or (vehicleParts["bx_fenderflare_FR_fixed"] == "bx_fenderflare_FR_fixed" and vehicleParts["bx_fenderflare_FL_fixed"] == "bx_fenderflare_FL_fixed")) then
				vehicleParts["bx_body"] = "simple_traffic_body_2door_coupe_tuner" -- this gives widebody fenderflare bodystyle
			else
				vehicleParts["simple_traffic_bodystyle"] = "simple_traffic_bodystyle_hatch"
			end
		end
	end,
	covet = function(vehicleParts)
		vehicleParts["covet_body"] = "simple_traffic_body_3door_hatch"
	end,
	etk800 = function(vehicleParts)
		if vehicleParts["etk800_body"] == "etk800_body_sedan" then
			vehicleParts["etk800_body"] = "simple_traffic_body_4door_sedan"
		else
			vehicleParts["etk800_body"] = "simple_traffic_body_5door_wagon"
		end
	end,
	etkc = function(vehicleParts)
		vehicleParts["etkc_body"] = "simple_traffic_body_2door_coupe"
	end,
	etki = function(vehicleParts)
		vehicleParts["etki_body"] = "simple_traffic_body_4door_sedan"
	end,
	fullsize = function(vehicleParts) -- case 1.5, frame replace
		vehicleParts["fullsize_frame"] = "simple_traffic_body_4door_sedan"
	end,
	lansdale = function(vehicleParts) -- case 3, something thats not the body decides what body is used
		if vehicleParts["lansdale_radsupport"] == "lansdale_radsupport_late" then
			vehicleParts["lansdale_body"] = "simple_traffic_body_5door_wagon_facelift"
		else
			vehicleParts["lansdale_body"] = "simple_traffic_body_5door_wagon"
		end
	end,
	legran = function(vehicleParts)
		if vehicleParts["legran_body"] == "legran_body_wagon" then
			vehicleParts["legran_body"] = "simple_traffic_body_5door_wagon"
		else
			vehicleParts["legran_body"] = "simple_traffic_body_4door_sedan"
		end
	end,
	midsize = function(vehicleParts)
		vehicleParts["midsize_body"] = "simple_traffic_body_4door_sedan"
	end,
	pessima = function(vehicleParts)
		vehicleParts["pessima_body"] = "simple_traffic_body_4door_sedan"
	end,
	pickup = function(vehicleParts) -- case 4, chaos D:
		if vehicleParts["pickup_frame"] == "pickup_frame_upfit_heavy" then
			vehicleParts["pickup_frame"] = "simple_traffic_body_d45" -- boxtruck

		elseif string.match(vehicleParts["pickup_frame"], "pickup_frame_crewlongbed") or -- ingores heavy suffix for crew cabin frames
		string.match(vehicleParts["pickup_frame"], "pickup_frame_extlongbed") then -- ingores heavy for ext cabin longbed frames
			vehicleParts["pickup_frame"] = "simple_traffic_body_d25" -- ext cab long bed

		elseif string.match(vehicleParts["pickup_frame"], "pickup_frame_crew") or -- ingores heavy for (the rest of) crew cabin frames
		string.match(vehicleParts["pickup_frame"], "pickup_frame_ext") or -- ingores heavy for (the rest of) ext cabin frames
		string.match(vehicleParts["pickup_frame"], "pickup_frame_longbed") or -- ingores heavy for longbed frames
		vehicleParts["pickup_frame"] == "pickup_desert_frame_crew" or
		vehicleParts["pickup_frame"] == "pickup_desert_frame_ext" or
		string.match(vehicleParts["pickup_frame"], "pickup_frame_short_ext") then -- ingores heavy for short ext frames
			vehicleParts["pickup_frame"] = "simple_traffic_body_d15" -- crew cab normal bed

		else -- standard frame, offroad frame, short frame lands here
			vehicleParts["pickup_frame"] = "simple_traffic_body_d10" -- short frame
		end

	end,
	roamer = function(vehicleParts)
		vehicleParts["roamer_frame"] = "simple_traffic_body_5door_wagon"
	end,
	sunburst = function(vehicleParts)
		vehicleParts["sunburst_body"] = "simple_traffic_body_4door_sedan"
	end,
	van = function(vehicleParts) -- case 5 mltiple deciding factors
		if vehicleParts["van_frame"] == "van_frame_upfit_heavy" then
			vehicleParts["van_frame"] = "simple_traffic_body_2door_boxtruck"
		elseif string.match(vehicleParts["van_frame"], "van_frame_ext") then -- ingores heavy for frames
			if vehicleParts["van_body_ext"] == "van_body_passenger_ext" then
				vehicleParts["van_frame"] = "simple_traffic_body_6door_van_passenger"
			else
				vehicleParts["van_frame"] = "simple_traffic_body_6door_van_ext"
			end
		else
			vehicleParts["van_frame"] = "simple_traffic_body_6door_van"
		end
	end,
	vivace = function(vehicleParts)
		if string.match(vehicleParts["vivace_fueltank"], "vivace_battery") then
			vehicleParts["vivace_body"] = "simple_traffic_vivace_e"
		else
			vehicleParts["vivace_body"] = "simple_traffic_vivace"
		end
	end,
	wendover = function(vehicleParts)
		vehicleParts["wendover_body"] = "simple_traffic_body_2door_coupe"
	end,
	-- is there a better way to implement this mess?
}

--- modify the given vehicleConfig so it as closely resembles the original config with simplified vehicle, or not touched if simplified vehicle not possible
-- @tparam string vehicleName, eg covet, midsize
-- @tparam table vehicleConfig, aka decodedData.vcf
-- @treturn table newVehicleConfig, that now contains the simplified body/parts, or the original table if no changes can be made
-- @usage local newVehicleConfig = simplifyVehicle("vivace", vehicleConfig)
local function simplifyVehicle(vehicleName, vehicleConfig)
	local newVehicleConfig = deepcopy(vehicleConfig)

	-- this do not check for incomptable parts
	if vehicleSimplifiers[vehicleName] then
		vehicleSimplifiers[vehicleName](newVehicleConfig.parts)
		return newVehicleConfig
	end

	-- simple fallback logic
	local expectedPartID = simplified_vehicles[vehicleName]
	if expectedPartID then
		local ioCtx = jbeamIO.startLoading({string.format("/vehicles/%s/", vehicleName), "/vehicles/common/"}) -- generate io context for use later
		local part = jbeamIO.getPart(ioCtx, expectedPartID)
		if not part then
			log('W', 'simplifyVehicle fallback logic', "part "..expectedPartID.." was not found for "..vehicleName.."")
			return vehicleConfig
		end
		local slotTypes = {}
		if type(part.slotType) == 'string' then
			table.insert(slotTypes, part.slotType)
		elseif type(part.slotType) == 'table' then
			slotTypes = part.slotType
		end
		for _, slotType in ipairs(slotTypes) do
			if newVehicleConfig.parts[slotType] then
				newVehicleConfig.parts[slotType] = expectedPartID
				return newVehicleConfig
			end
		end
	end

	table.clear(newVehicleConfig)
	return vehicleConfig
end

-- ============= OBJECTS =============
local Player = {}
Player.__index = Player
function Player:new(data)
	local o = {}
	setmetatable(o, self)

	data = data or {}
	if type(data) == 'string' then data = deserialize(data) end

	o.name = data.name
	o.shortname = data.name
	o.playerID = tonumber(data.playerID)

	if data.role then -- try to apply role received from the server
		o.role = roleToInfo[data.role]
		o.role.name = data.role
	end
	if not o.role then -- fallback to user
		o.role = roleToInfo['USER']
		o.role.name = 'USER'
	end

	o.isLocal = data.isLocal or false

	o.nickPrefixes = {}
	o.nickSuffixes = {}

	o.customRole = nil

	o.vehicles = {IDs = data.vehicleIDs or {}}

	local mt =
	{
		__index = function(tbl, key)
			--dump('__index called on ', tbl, key)
			if key == "IDs" then return rawget(tbl, key) end
			return vehicles[key]
		end,
		__newindex = function(tbl, key, val)
			dump('__newindex called on ', tbl, key)
			if key == "IDs" then rawset(tbl, key, val) end
			--return vehicles[key]
		end,

		__pairs = function(tbl)
			--dump('__pairs called with ', tbl)
			local function stateless_iter(indexTable, k)
				--dump('stateless_iter called with ',tbl, k)
				k = next(indexTable, k)

				if tbl[k] ~= nil then
					return k, tbl[k]
				end
			end

			return stateless_iter, tbl.IDs , nil
		end
	}
	setmetatable(o.vehicles, mt)

	o.ping = -1
	o.activeVehicleID = nil

	o:onSettingsChanged()

	log('W', 'Player:new', string.format("Player %s (%i) created! Data:%s", o.name, o.playerID, dumps(data)))

	return o
end
function Player:addVehicle(v)
	local id = type(v) == 'table' and v.serverVehicleString or v
	self.vehicles.IDs[id] = id
	log('W', 'Player:addVehicle', 'Assigned vehicle ID '..tostring(id)..' to player '..self.name)
end
function Player:setNickPrefix(tagSource, text)
	--setPlayerNickPrefix(self.name, tagSource, text)
	if text == nil then text = tagSource; tagSource = "default" end
	self.nickPrefixes[tagSource] = text
end
function Player:setNickSuffix(tagSource, text)
	--setPlayerNickSuffix(self.name, tagSource, text)
	if text == nil then text = tagSource; tagSource = "default" end
	self.nickSuffixes[tagSource] = text
end
function Player:setCustomRole(role)
	self.customRole = role
end
function Player:clearCustomRole(roleName)
	self.customRole = nil
end
function Player:delete()
	log('W', 'Player:delete', string.format('Removing player %s (%i)! Data: %s', self.name, self.playerID, dumps(self)))
	for k, v in pairs(self.vehicles) do
		v:delete()
	end
	if self.activeVehicleID then vehicles[self.activeVehicleID].spectators[self.playerID] = nil end
	players[self.playerID] = nil

	self = nil
end
function Player:onSerialized()
	local t = {
		name = self.name,
		playerID = self.playerID,
		role = self.role.name,
		isLocal = self.isLocal,
		vehicleIDs = self.vehicles.IDs
	}
	return t
end
function Player:onSettingsChanged()
	local charLimit = tonumber(settings.getValue("nametagCharLimit"))
	if not settings.getValue("shortenNametags") or not charLimit or #self.name <= charLimit + 3 then
		self.shortname = self.name
		return
	end

	local short = self.name:sub(1, charLimit)
	if #short ~= #self.name then short = short .. "..." end

	self.shortname = short
end

local Vehicle = {}
Vehicle.__index = Vehicle
function Vehicle:new(data)
	local o = {}
	setmetatable(o, self)

	data = data or {}
	if type(data) == 'string' then data = deserialize(data) end

	o.jbeam = data.jbeam

	o.gameVehicleID = tonumber(data.gameVehicleID) or -1
	o.remoteVehID = data.remoteVehID or -1

	if data.serverVehicleString then -- combined string
		o.serverVehicleString = data.serverVehicleString
		o.ownerID, o.serverVehicleID = string.match(data.serverVehicleString, "(%d+)%-(%d+)")
		o.ownerID, o.serverVehicleID = tonumber(o.ownerID), tonumber(o.serverVehicleID)
	else
		if data.ownerID then o.ownerID = tonumber(data.ownerID) end
		if data.serverVehicleID then o.serverVehicleID = tonumber(data.serverVehicleID) end
		if o.ownerID and o.serverVehicleID then o.serverVehicleString = tostring(o.ownerID)..'-'..tostring(o.serverVehicleID) end
	end

	if o.gameVehicleID > 0 then
		vehiclesMap[o.gameVehicleID] = o.serverVehicleString
	end

	o.ownerName = data.ownerName
	o.isLocal = data.isLocal or false
	o.isSpawned = data.isSpawned ~= false -- default to true
	o.isDeleted = data.isDeleted or false

	o.position = nil
	o.rotation = nil

	o.spectators = {}

	if not settings.getValue("showDebugOutput") then
		log('W', 'Vehicle:new', string.format("Vehicle %s (%s) created! Data:%s", o.serverVehicleString, o.ownerName, dumps(data)))
	end
	return o
end
function Vehicle:getOwner()
	return players[self.ownerID], self.ownerID
end
function Vehicle:delete()
	log('W', 'Vehicle:delete', string.format('Vehicle %s deleted! Source: %s Data: %s', self.serverVehicleString, simpletraces(), dumps(self)))
	for playerID, v in pairs(self.spectators) do
		if players[playerID] then players[playerID].activeVehicleID = nil end
	end
	if players[self.ownerID] and self.serverVehicleString then players[self.ownerID].vehicles.IDs[self.serverVehicleString] = nil end
	if self.serverVehicleString then vehicles[self.serverVehicleString] = nil end

	players_vehicle_configs[self.serverVehicleString] = nil

	self = nil
end
function Vehicle:setCustomRole(role)
	self.customRole = role
end
function Vehicle:clearCustomRole(roleName)
	self.customRole = nil
end
function Vehicle:setDisplayName(displayName)
	self.customName = displayName
end
function Vehicle:onSerialized()
	local t = {
		jbeam = self.jbeam,
		spawnQueue = self.spawnQueue,
		editQueue = self.editQueue,
		gameVehicleID = self.gameVehicleID,
		remoteVehID = self.remoteVehID,
		serverVehicleString = self.serverVehicleString,
		ownerName = self.ownerName,
		isLocal = self.isLocal,
		isSpawned = self.isSpawned,
		isDeleted = self.isDeleted
	}
	return t
end

local function serializePlayers()
	local t = {}
	for k,v in pairs(players) do
		t[k] = v:onSerialized()
	end
	return t
end
local function serializeVehicles()
	local t = {}
	for k,v in pairs(vehicles) do
		t[k] = v:onSerialized()
	end
	return t
end


local function getQueueCounts()
	local spawns, edits = 0, 0
	local queuedPlayers = {}

	local highlightQueuedPlayers = settings.getValue("highlightQueuedPlayers")

	for serverVehicleID, vehicle in pairs(vehicles) do
		if vehicle.spawnQueue then 
			spawns = spawns + 1 
			if highlightQueuedPlayers then
				queuedPlayers[vehicle.ownerID] = true
			end
		end
		if vehicle.editQueue then 
			edits = edits + 1 
			if highlightQueuedPlayers then
				queuedPlayers[vehicle.ownerID] = true
			end
		end
	end
	return spawns, edits, queuedPlayers
end



-- sending section

--called by onVehicleSpawned
--============================ SEND VEHICLE ============================
local function sendVehicleSpawn(gameVehicleID)
	local veh = be:getObjectByID(gameVehicleID) -- Get spawned vehicle ID
	if veh then -- In case of bug
		local vehicleTable = {}
		local vehicleData  = extensions.core_vehicle_manager.getVehicleData(gameVehicleID)
		local pos          = veh:getPosition()
		local rot          = quat(veh:getRotation())

		vehicleTable.pid = MPConfig.getPlayerServerID() -- Player Server ID
		vehicleTable.vid = gameVehicleID -- Game Vehicle ID
		vehicleTable.jbm = veh:getJBeamFilename() -- JBeam
		vehicleTable.vcf = vehicleData.config -- Vehicle Config, contains paint data
		vehicleTable.pos = {pos.x, pos.y, pos.z} -- Position
		vehicleTable.rot = {rot.x, rot.y, rot.z, rot.w} -- Rotation
		vehicleTable.pro = settings.getValue("protectConfigFromClone", false) -- Should the config be protected?
		if vehicleTable.pro == true then
			vehicleTable.pro = "1"
		else
			vehicleTable.pro = "0"
		end
		vehicleTable.ign = settings.getValue("spawnVehicleIgnitionLevel") or 3 -- Ingition state

		-- The vehicle_manager.lua may not contain the correct color values, since v0.31, when we read them from that lua, so we read those from the object itself
		vehicleTable.vcf.paints = MPHelpers.getColorsFromVehObj(veh)

		local stringToSend = jsonEncode(vehicleTable) -- Encode table to send it as json string
		MPGameNetwork.send('Os:0:'..stringToSend) -- Send table that contain all vehicle informations for each vehicle
		log('I', "sendVehicle", "Vehicle "..gameVehicleID.." was sent")

		--local vehObj = Vehicle:new({ isLocal=true, ownerName=MPConfig.getNickname(), gameVehicleID=gameVehicleID, jbeam=vehicleTable.jbm, ownerID=vehicleTable.pid })

		if not players[vehicleTable.pid] or players[vehicleTable.pid].name ~= MPConfig.getNickname() then
			players[vehicleTable.pid] = Player:new({name=MPConfig.getNickname(), playerID=vehicleTable.pid, isLocal=true })
		end

		--vehicles[gameVehicleID] = vehObj
	end
end

--called by autosync and the ui (sync button)
--============================ SEND MODIFIED VEHICLE DATA ============================
local function sendVehicleEdit(gameVehicleID)
	local vehicleTable = {} -- Vehicle table
	local vehicleData  = extensions.core_vehicle_manager.getVehicleData(gameVehicleID)
	local veh          = be:getObjectByID(gameVehicleID)
	local c            = veh.color
	local p0           = veh.colorPalette0
	local p1           = veh.colorPalette1

	if not isOwn(veh:getID()) then return end

	vehicleTable.pid = MPConfig.getPlayerServerID()
	vehicleTable.jbm = veh:getJBeamFilename()
	vehicleTable.vcf = vehicleData.config
	vehicleTable.pro = settings.getValue("protectConfigFromClone", false) -- Should the config be protected?

	if vehicleTable.pro == true then
		vehicleTable.pro = "1"
	else
		vehicleTable.pro = "0"
	end
	vehicleTable.ign = settings.getValue("spawnVehicleIgnitionLevel") or 3 -- Ingition state
	-- The vehicle_manager.lua may not contain the correct color values, since v0.31, when we read them from that lua, so we read those from the object itself
	vehicleTable.vcf.paints = MPHelpers.getColorsFromVehObj(veh)

	local stringToSend = jsonEncode(vehicleTable) -- Encode table to send it as json string
	MPGameNetwork.send('Oc:'..getServerVehicleID(gameVehicleID)..':'..stringToSend) -- Send table that contain all vehicle informations for each vehicle
	log('I', "sendVehicleEdit", "Vehicle custom data "..gameVehicleID.." was sent")
	vehiclesToSync[gameVehicleID] = nil
end

local function sendBeamstate(data, gameVehicleID)
	MPGameNetwork.send('Ot:'..getServerVehicleID(gameVehicleID)..':'..data)
end


-- Patch Game Functions in relation to vehicle configs
local core_vehicles_cloneCurrent = core_vehicles.cloneCurrent
core_vehicles.cloneCurrent = function ()
	local vehicle = be:getPlayerVehicle(0)
	if vehicle:getField("protected", 0) == "1" then
		local title = MPHelpers.translate("ui.multiplayer.configprotection.clone.title", "Vehicle Clone Error")
		local msg = MPHelpers.translate("ui.multiplayer.configprotection.clone.message", "Sorry, you cannot clone this vehicle.")
		guihooks.trigger("toastrMsg", {type="error", title=title, msg=msg})
		return
	else
		core_vehicles_cloneCurrent()
	end
end

local core_vehicle_partmgmt_saveLocal = extensions.core_vehicle_partmgmt.saveLocal
local function core_vehicle_partmgmt_saveLocal_overwrite(p1)
	local vehicle = be:getPlayerVehicle(0)
	if vehicle:getField("protected", 0) == "1" then
		local title = MPHelpers.translate("ui.multiplayer.configprotection.save.title", "Vehicle Save Error")
		local msg = MPHelpers.translate("ui.multiplayer.configprotection.save.message", "Sorry, you cannot save this vehicle.")
		guihooks.trigger("toastrMsg", {type="error", title=title, msg=msg})
		return
	else
		core_vehicle_partmgmt_saveLocal(p1)
		
		local util_createThumbnails_startWork = util_createThumbnails.startWork
		util_createThumbnails.startWork = function (p1)
			local vehicle = be:getPlayerVehicle(0)
			if vehicle:getField("protected", 0) == "1" then
				return
			else
				util_createThumbnails_startWork(p1)
			end
		end
	end
end



-- applying section

local function checkIfVehiclenameInvalid(vehicleName, playerName, v) -- TODO: find a different way of doing this because it thinks saved configs of modded vehicles are valid
	local vehiclesList = extensions.core_vehicles.getModelList()

	if vehiclesList.models[vehicleName] ~= nil then return false end

	if v then
		v.isIllegal = true
	end

	log('W', 'applyVehSpawn', "The received vehicle "..vehicleName.." is not valid, cancelling the spawn (likely a missing mod)")
	if playerName then UI.showNotification("Player "..playerName.." spawned an illegal vehicle ("..vehicleName.."), it was skipped", ""..playerName..""..vehicleName.."illegal", "remove_circle") end
	return true
end


local function applyVehSpawn(event)
	local decodedData = jsonDecode(event.data)
	if not decodedData then --JSON decode failed
		log("E", "applyVehSpawn", "Failed to spawn vehicle from "..event.playerNickname.."!")
		return
	end

	local playerServerID = decodedData.pid -- Server ID of the player that sent the vehicle
	local gameVehicleID  = decodedData.vid -- gameVehicleID of the player that sent the vehicle
	local vehicleName    = decodedData.jbm -- Vehicle name
	local vehicleConfig  = decodedData.vcf -- Vehicle config, contains paint data
	local pos            = vec3(decodedData.pos)
	local rot            = decodedData.rot.w and quat(decodedData.rot) or quat(0,0,0,0) --ensure the rotation data is good
	local ignitionLevel  = (type(decodedData.ign) == "number") and decodedData.ign or 3
	local protected      = decodedData.pro -- Config Protected

	log('I', 'applyVehSpawn', "Spawning a vehicle from server with serverVehicleID "..event.serverVehicleID)
	log('I', 'applyVehSpawn', "It is for "..event.playerNickname)

	if checkIfVehiclenameInvalid(vehicleName, event.playerNickname, vehicles[event.serverVehicleID]) then return end

	nextSpawnIsRemote = true -- this flag is used to indicate whether the next spawn is remote or not

	if settings.getValue("simplifyRemoteVehicles") then
		vehicleConfig = simplifyVehicle(vehicleName, vehicleConfig)
	end

	local spawnedVehID = getGameVehicleID(event.serverVehicleID)
	local spawnedVeh = spawnedVehID and be:getObjectByID(spawnedVehID) or nil

	if spawnedVeh then -- if a vehicle with this ID was found update the obj
		log('W', 'applyVehSpawn', "(spawn)Updating vehicle from server "..vehicleName.." with id "..spawnedVehID)
		spawn.setVehicleObject(spawnedVeh, {model=vehicleName, config=serialize(vehicleConfig), pos=pos, rot=rot, cling=true})
		spawnedVeh:setField("protected", 0, protected or "0")
	else
		log('W', 'applyVehSpawn', "Spawning new vehicle "..vehicleName.." from server")
		spawnedVeh = spawn.spawnVehicle(vehicleName, serialize(vehicleConfig), pos, rot, { autoEnterVehicle=false, vehicleName="multiplayerVehicle", cling=true})
		spawnedVehID = spawnedVeh:getID()
		spawnedVeh:setField("protected", 0, protected or "0")
		log('W', 'applyVehSpawn', "Spawned new vehicle "..vehicleName.." from server with id "..spawnedVehID)

		if not vehicles[event.serverVehicleID] then
			vehicles[event.serverVehicleID] =
				Vehicle:new({gameVehicleID=spawnedVehID, serverVehicleString=event.serverVehicleID, ownerName=event.playerNickname, jbeam=vehicleName})
		end

		local vehicle = getVehicleByServerID(event.serverVehicleID)

		vehicle.gameVehicleID = spawnedVehID
		vehicle.isSpawned = true
		vehicle.jbeam = vehicleName
		vehicle.protected = protected
		vehiclesMap[spawnedVehID] = event.serverVehicleID

		players[vehicle.ownerID]:addVehicle(vehicle)
	end

	core_vehicles.setPlateText(event.playerNickname, spawnedVehID)
	spawnedVeh:queueLuaCommand("hydros.onFFBConfigChanged(nil)")
	spawnedVeh:queueLuaCommand("MPPowertrainVE.setIgnitionState("..ignitionLevel..")")
end

local function applyVehEdit(serverID, data)
	local gameVehicleID = getGameVehicleID(serverID) -- Get the gameVehicleID
	if not gameVehicleID then log('E','applyVehEdit',"gameVehicleID for "..serverID.." not found") return end

	local veh = be:getObjectByID(gameVehicleID) -- Get the vehicle
	if not veh then log('E','applyVehEdit',"Vehicle "..gameVehicleID.." not found") return end

	local decodedData   = jsonDecode(data) -- Decode the data
	local vehicleName   = decodedData.jbm -- Vehicle name
	local vehicleConfig = decodedData.vcf -- Vehicle config
	local protected       = decodedData.pro

	local playerName = players[decodedData.pid] and players[decodedData.pid].name or 'Unknown'

	if checkIfVehiclenameInvalid(vehicleName, playerName, vehicles[serverID]) then return end

	if settings.getValue("simplifyRemoteVehicles") then
		vehicleConfig = simplifyVehicle(vehicleName, vehicleConfig)
	end

	if vehicleName == veh:getJBeamFilename() then
		log('I','applyVehEdit',"Updating vehicle "..gameVehicleID.." config")
		local playerVehicle = extensions.core_vehicle_manager.getVehicleData(gameVehicleID)

		local partsDiff = MPHelpers.tableDiff(playerVehicle.config.parts, vehicleConfig.parts)
		local tuningDiff = MPHelpers.tableDiff(playerVehicle.config.vars, vehicleConfig.vars)

		local configChanged = tableSize(partsDiff) > 0 or tableSize(tuningDiff) > 0
		local colorChanged = not MPHelpers.colorMatch(playerVehicle.config.paints, vehicleConfig.paints)
		--print("colorchanged: " .. tostring(colorChanged))
		if configChanged or colorChanged then
			tableMerge(playerVehicle.config, vehicleConfig) -- add new parts to the existing config

			if configChanged then
				veh:setDynDataFieldbyName("autoEnterVehicle", 0, tostring((be:getPlayerVehicle(0) and be:getPlayerVehicle(0):getID() == gameVehicleID) or false))
				veh:respawn(serialize(playerVehicle.config))
			elseif vehicleConfig.paints then
				log('I','applyVehEdit', "only color changed")
				for k, v in pairs(vehicleConfig.paints) do
					extensions.core_vehicle_manager.liveUpdateVehicleColors(gameVehicleID, veh, k, v)
				end
			end
		else
			log('I','applyVehEdit', "received edit matches local copy, ignoring message")
		end
	else
		log('W','applyVehEdit', "The received data for '"..vehicleName.."' does not correspond with the vehicle '"..veh:getJBeamFilename().."'")

		local options = {
			model = vehicleName,
			config = serialize(vehicleConfig),
			pos = veh:getPosition(), rot = quat(veh:getRotation()), cling = true,
		}

		veh:setDynDataFieldbyName("autoEnterVehicle", 0, tostring((be:getPlayerVehicle(0) and be:getPlayerVehicle(0):getID() == gameVehicleID) or false))
		log('I', 'applyVehEdit', "Updating vehicle from server "..vehicleName.." with id "..serverID)
		spawn.setVehicleObject(veh, options)
	end
	
	veh:setField("protected", 0, protected or "0")
end



-- local events

--============================ ON VEHICLE SPAWNED (CLIENT) ============================
local function onVehicleSpawned(gameVehicleID)

	if not MPCoreNetwork.isMPSession() then return end -- do nothing if singleplayer

	local veh = be:getObjectByID(gameVehicleID)
	local newJbeamName = veh:getJBeamFilename()

	local vehicle = getVehicleByGameID(gameVehicleID)

	if not vehicle or not vehicle.jbeam then -- If it's not an edit
		log("I", "onVehicleSpawned", "New Vehicle Spawned "..gameVehicleID)
		--log('E', 'nextSpawnIsRemote', tostring(nextSpawnIsRemote))

		if not nextSpawnIsRemote then
			sendVehicleSpawn(gameVehicleID) -- Send it to the server
			commands.setGameCamera() -- Force switch from freecam to vehicle camera
		end

		nextSpawnIsRemote = false

	else
		if vehicle.jbeam ~= newJbeamName then
			log("I", "onVehicleSpawned", string.format("Vehicle %i updated from %s to %s", gameVehicleID, vehicle.jbeam, newJbeamName))

			if not nextSpawnIsRemote then
				sendVehicleEdit(gameVehicleID) -- Send it to the server (as an edit)
			end

			nextSpawnIsRemote = false

		else
			log("I", "onVehicleSpawned", "Vehicle " .. gameVehicleID .. " edited")
			editSyncTimer = 0
			vehiclesToSync[gameVehicleID] = 1.
		end
	end

	veh:queueLuaCommand("extensions.loadModulesInDirectory('lua/vehicle/extensions/BeamMP')") -- Load VE lua extensions

	if vehicle then
		vehicle.jbeam = newJbeamName
		vehicle.vehicleHeight = veh:getInitialHeight()
	end

end

--============================ ON VEHICLE REMOVED (CLIENT) ============================

local function spawnDestroyedVehicles(serverVehID)

	local vehdata = players_vehicle_configs[serverVehID]
	if vehdata == nil then
		log("I", "restorePlayerVehicle", "couldnt find vehdata from the id given")
		return
	end

	if vehicles[serverVehID].isDeleted == false then
		UI.showNotification(''..vehicles[serverVehID].ownerName.."'s "..vehicles[serverVehID].jbeam.." hasn't been deleted yet?", ''..serverVehID..'delete', 'warning')
		log("I", "restorePlayerVehicle", "This vehicle hasn't been deleted yet")
		return
	end

	vehicles[serverVehID].isSpawned = true
	vehicles[serverVehID].isDeleted = false
		-- queue system
--		local eventdata = {
--			playerNickname = playerNickname,  -- same as owner name??? we shall find out
--			serverVehicleID = serverVehicleID,
--			data = data
--		}

	local playerOwnerName = vehicles[serverVehID].ownerName

	local encodedVehicleData = jsonEncode(vehdata)

	local eventdata = {
		playerNickname = playerOwnerName,  --- mabye a issue?
		serverVehicleID = serverVehID,
		data = encodedVehicleData
	}
	UI.showNotification('Trying to respawn '..playerOwnerName.."'s "..vehicles[serverVehID].jbeam, ''..playerOwnerName..''..serverVehID..'respawn', 'directions_car')
	if settings.getValue("enableSpawnQueue") then
		vehicles[serverVehID].spawnQueue = eventdata
		UI.updateQueue(getQueueCounts())
	else
		log("D", "restorePlayerVehicle", "Queue disabled, spawning vehicle now")
		applyVehSpawn(eventdata)
		UI.updateQueue(0, 0)
	end
end

local function restorePlayerVehicle(playerName)
	-- not a properproper wayyy of doing this

	local player = getPlayerByName(playerName)
	if player == nil then
		log("E", "restorePlayerVehicle", "Couldnt find player??")
	end

	-- its a table of ids
	local vehicles_ServerIDs = player.vehicles.IDs

	for x,y in pairs(vehicles_ServerIDs)do
		spawnDestroyedVehicles(y)
		log("D", "restorePlayerVehicle", "Trying to respawn : ".. tostring(x) .. tostring(y))
	end
end


local function onVehicleDestroyed(gameVehicleID)
	if MPGameNetwork.launcherConnected() then
		local vehicle = getVehicleByGameID(gameVehicleID)

		log('W', 'onVehicleDestroyed', gameVehicleID .. ' ' )

		if not vehicle then return end
		local serverVehicleID = vehicle.serverVehicleString -- Get the serverVehicleID

		vehicle.isSpawned = false
		vehicle.isDeleted = true

		if onVehicleDestroyedAllowed then -- If function is not coming from onServerVehicleRemoved then
			log('I', "onVehicleDestroyed", string.format("Vehicle %i (%s) removed by local player", gameVehicleID, serverVehicleID or "?"))
			if vehicle.isLocal then
				if serverVehicleID then
					local veh = be:getObjectByID(gameVehicleID)
					if veh:getJBeamFilename() == "unicycle" and settings.getValue("unicycleAutoSave") == true then -- if the player destroyed their unicycle
						local vehicleConfig = extensions.core_vehicle_manager.getVehicleData(gameVehicleID).config
						--[[ Contains as of 0.30
							[parts] = table
								["slot_part_n"] = "plug_part_n"
							[paints] = array[3]
								[n] = table
									[metallic] = float
									[roughness] = float
									[clearcoat] = float
									[clearcoatRoughness] = float
									[baseColor] = array[4]
										[n] = float
							[partConfigFilename] = string
							[mainPartName] = string
							[licenseName] = string
							[model] = string

							the .pc format v2 contains all the same data in the same structure.. just with "format" and not with "partConfigFilename"
						]]
						vehicleConfig.format = 2
						vehicleConfig.partConfigFilename = nil

						local handle = io.open("vehicles/unicycle/beammp_default.pc", "w")
						if handle == nil then
							log('I', "onVehicleDestroyed", 'Cannot open "vehicles/unicycle/beammp_default.pc" in write mode.')
						else
							handle:write(jsonEncode(vehicleConfig))
							handle:close()
						end
					end
					MPGameNetwork.send('Od:'..serverVehicleID)
					vehicles[serverVehicleID]:delete()
				end
			end
		else
			log('I', "onVehicleDestroyed", string.format("Vehicle %i (%s) removed by server", gameVehicleID, serverVehicleID or "?"))
			onVehicleDestroyedAllowed = true
			vehicles[serverVehicleID]:delete()
		end

	end
end

local function sendActiveVehicleID(newVehObj)
	local newServerVehicleID = newVehObj.serverVehicleString -- Get serverVehicleID of the vehicle the player switched to
	if not newServerVehicleID then
		newServerVehicleID = tostring(MPConfig.getPlayerServerID()) .. '-' .. -1 -- if the vehicle doesn't exist we still want to send that it changed to remove the spectator nametag
	end
	if newServerVehicleID then
		local playerID = MPConfig.getPlayerServerID()
		local s = tostring(playerID) .. ':' .. newServerVehicleID

		MPGameNetwork.send('Om:'.. s)
	end
end

--============================ ON VEHICLE SWITCHED (CLIENT) ============================
local function onVehicleSwitched(oldGameVehicleID, newGameVehicleID)
	extensions.core_vehicle_partmgmt.saveLocal = core_vehicle_partmgmt_saveLocal_overwrite
	if MPCoreNetwork.isMPSession() then
		log('I', "onVehicleSwitched", "Vehicle switched from "..oldGameVehicleID or "unknown".." to "..newGameVehicleID or "unknown")

		if newGameVehicleID and newGameVehicleID > -1 then
			local skipOthers = settings.getValue("skipOtherPlayersVehicles", false)
			local oldVehicle = be:getObjectByID(oldGameVehicleID or -1)
			local newVehicle = be:getObjectByID(newGameVehicleID or -1)

			local newVehObj = getVehicleByGameID(newGameVehicleID) or {}

			-- enter a remote car as a passenger
			if not newVehObj.isLocal and oldVehicle and oldVehicle:getJBeamFilename() == "unicycle" then
				--core_camera.setByName(0,"onboard.rider") -- citybus
				core_camera.setByName(0,"passenger") -- auto generated
				core_camera.setByName(0,"onboard.passenger") -- custom
			elseif not newVehObj.isLocal and ((skipOthers and localVehiclesExist()) or newVehObj.jbeam == "unicycle") then
				-- switch away from this vehicle if it shouldn't be accessible

				local allVehicles = getAllVehicles()
				--local oldIndex = nil -- the old vehicle's index
				local curIndex = nil -- the current (new) vehicle's index
				for index,vehicle in ipairs(allVehicles) do
					local id = vehicle and vehicle:getID()
					--if id == oldGameVehicleID then
					--	oldIndex = index
					--end
					if id == newGameVehicleID then
						curIndex = index
						break
					end
					if --[[(oldGameVehicleID == -1 or oldIndex) and]] curIndex then break end
				end
				curIndex = curIndex or #allVehicles
				--print("current vehicle index is " .. curIndex)

				local findFunc = function(from, to)
					for i = from, to do
						local id = allVehicles[i] and allVehicles[i]:getID()
						local jbeamName = allVehicles[i]:getJBeamFilename()
						if isOwn(id) or not skipOthers and jbeamName ~= "unicycle" then
							log('I', "onVehicleSwitched", "Found suitable vehicle " .. jbeamName)
							return i
						end
					end
					return nil
				end

				--print("direction:")
				--print(oldIndex or -1 < curIndex)

				local nextIndex = findFunc(curIndex+1, #allVehicles) or findFunc(1, curIndex) -- could flip these if we knew the direction

				if allVehicles[nextIndex] then -- found a good vehicle, swtich to it
					be:enterVehicle(0, allVehicles[nextIndex])
				else -- no suitable vehicle found, go to freecam
					be:exitVehicle(0)
					log('E', "onVehicleSwitched", "Could not find a suitable vehicle to switch to, exiting current veh")
				end
			else
				sendActiveVehicleID(newVehObj)
			end
		end
	end
end

--============================ ON VEHICLE RESETTED (CLIENT) ============================
local function onVehicleResetted(gameVehicleID)
	if MPGameNetwork.launcherConnected() then
		local vehicle = getVehicleByGameID(gameVehicleID)
		if vehicle and vehicle.serverVehicleString and vehicle.isLocal then -- If serverVehicleID not null and player own vehicle -- If it's not null
			--print("Vehicle "..gameVehicleID.." resetted by client")
			local veh = be:getObjectByID(gameVehicleID)
			local pos = veh:getPosition()
			local rot = quat(veh:getRotation())
			local tempTable = {
				pos = {
					x = pos.x,
					y = pos.y,
					z = pos.z
				},
				rot = {
					x = rot.x,
					y = rot.y,
					z = rot.z,
					w = rot.w
				}
			}
			MPGameNetwork.send('Or:'..vehicle.serverVehicleString..":"..jsonEncode(tempTable).."")
		end
	end
end



-- server events

--============================ ON VEHICLE SPAWNED (SERVER) ============================
local function onServerVehicleSpawned(playerRole, playerNickname, serverVehicleID, data)
	local decodedData = jsonDecode(data)
	if not decodedData then --JSON decode failed
		log("E", "onServerVehicleSpawned", "Failed to spawn vehicle from "..playerNickname.."! (Invalid JSON data)")
		return
	end

	local playerServerID = tonumber(decodedData.pid) -- Server ID of the owner
	local gameVehicleID  = tonumber(decodedData.vid) -- remote gameVehicleID

	--create player object if this is their first vehicle
	if not players[playerServerID] or players[playerServerID].name ~= playerNickname then
		players[playerServerID] =
			Player:new({name=playerNickname, playerID=playerServerID, role=playerRole})
	end

	if not settings.getValue("showDebugOutput") then
		log("I", "onServerVehicleSpawned", "Received a vehicle spawn for player " .. playerNickname .. " with ID " .. serverVehicleID .. ' '..dumpsz(decodedData, 2))
	end

	if MPConfig.getPlayerServerID() == decodedData.pid then -- If the IDs match it's a local vehicle

		local vehObject =
			Vehicle:new({gameVehicleID=gameVehicleID, serverVehicleString=serverVehicleID, ownerName=playerNickname, isLocal = true, jbeam=decodedData.jbm})

		vehicles[serverVehicleID] = vehObject

		vehiclesMap[gameVehicleID] = serverVehicleID

		players[playerServerID]:addVehicle(vehObject)

		if be:getPlayerVehicleID(0) == gameVehicleID then
			sendActiveVehicleID(vehObject)
		end

		log("W", "onServerVehicleSpawned", "ID is same as received ID, synced vehicle gameVehicleID: "..gameVehicleID.." with ServerID: "..serverVehicleID)

	elseif vehicles[serverVehicleID] and vehicles[serverVehicleID].remoteVehID == gameVehicleID then

		log("I", "onServerVehicleSpawned", "This ID already exists, syncing vehicles")

	else
		--create temporary vehicle object
		local vehObject =
			Vehicle:new({serverVehicleString=serverVehicleID, ownerName=playerNickname, isSpawned=false, remoteVehID=gameVehicleID})

		vehicles[serverVehicleID] = vehObject
		players[playerServerID]:addVehicle(vehObject)

		-- queue system
		local eventdata = {
			playerNickname = playerNickname,
			serverVehicleID = serverVehicleID,
			data = data
		}

		players_vehicle_configs[serverVehicleID] = decodedData

		if settings.getValue("enableSpawnQueue") and not (settings.getValue("queueSkipUnicycle") and decodedData.jbm == "unicycle") then
			log("I", "onServerVehicleSpawned", "Adding spawn for " .. playerNickname .. " to queue")

			vehicles[serverVehicleID].spawnQueue = eventdata

			local icon = 'directions_car'
			if decodedData.jbm == "unicycle" then
				icon = "person"
			end

			UI.updateQueue(getQueueCounts())
			UI.showNotification('Spawn received and queued for '..playerNickname, ''..playerNickname..''..serverVehicleID..'spawn', icon)
		else
			log("I", "onServerVehicleSpawned", "Queue disabled, spawning vehicle now")

			applyVehSpawn(eventdata)
			UI.updateQueue(0, 0)
		end
	end
end

--============================ ON VEHICLE EDITED (SERVER) ============================
local function onServerVehicleEdited(serverID, data)
	local decodedData = jsonDecode(data)
	log('I', 'onServerVehicleEdited', "Edit received for "..serverID)

	if not vehicles[serverID] then
		vehicles[serverID] = Vehicle:new({ ServerVehicleString = serverID, isSpawned = false })
	end
	local owner = vehicles[serverID]:getOwner()
	if not owner.vehicles.IDs[serverID] then owner:addVehicle(vehicles[serverID]) end

	local saveVehicleRot = players_vehicle_configs[serverID].rot
	local saveVehiclePos = players_vehicle_configs[serverID].pos

	players_vehicle_configs[serverID] = decodedData
	players_vehicle_configs[serverID].pos = saveVehiclePos
	players_vehicle_configs[serverID].rot = saveVehicleRot


	if settings.getValue("enableSpawnQueue") and not (settings.getValue("queueSkipUnicycle") and decodedData.jbm == "unicycle") then
		vehicles[serverID].editQueue = data

		log('I', 'onServerVehicleEdited', "edit "..serverID.." queued")
		local playerNickname = owner and owner.name or "unknown"
		UI.updateQueue(getQueueCounts())
		UI.showNotification('Edit received and queued for '..playerNickname, ''..playerNickname..''..serverID..'edit', 'build')
	else
		local currentVeh = be:getPlayerVehicle(0) -- Camera fix

		applyVehEdit(serverID, data)
		UI.updateQueue(0, 0)

		if currentVeh then be:enterVehicle(0, currentVeh) end -- Camera fix
	end
end

--============================ ON VEHICLE REMOVED (SERVER) ============================
local function onServerVehicleRemoved(serverVehicleID)
	local vehicle = vehicles[serverVehicleID]
	if not vehicle then
		log('W', "onServerVehicleRemoved", "Vehicle "..serverVehicleID.." not found")
		return
	end

	if vehicle.spawnQueue then
		log('W', "onServerVehicleRemoved", "Vehicle "..serverVehicleID.." is still in the queue, removing from there")
		vehicle:delete()
		UI.updateQueue(getQueueCounts())
		return
	end

	local gameVehicleID = vehicle.gameVehicleID
	if gameVehicleID > 0 then
		log('I', "onServerVehicleRemoved", string.format("Vehicle %i (%s) removed by server ", gameVehicleID, serverVehicleID))
		local veh = be:getObjectByID(gameVehicleID) -- Get associated vehicle
		if veh then
			onVehicleDestroyedAllowed = false
			local currveh = be:getPlayerVehicle(0)
			local isCurrent = (currveh and currveh:getID() == gameVehicleID) or false
			veh:delete() -- Remove it
			if isCurrent then be:enterNextVehicle(0,1) end-- Fix camera
			--vehicle:delete()
		else
			log('W', "onServerVehicleRemoved", "Failed removing vehicle "..serverVehicleID..", Vehicle can't be found")
			vehicle:delete()
		end
	else
		log('W', "onServerVehicleRemoved", "Failed removing vehicle "..serverVehicleID..", ID is unknown")
		vehicle:delete()
	end
end

--============================ ON VEHICLE RESETTED (SERVER) ============================
local function onServerVehicleResetted(serverVehicleID, data)
	--print("Reset Event Received for a player")
	local gameVehicleID = getGameVehicleID(serverVehicleID) -- Get game ID
	if localCounter - (lastResetTime[serverVehicleID] or 0) > 0.2 then
		if gameVehicleID then
			local veh = be:getObjectByID(gameVehicleID) -- Get associated vehicle
			if veh then
				local pr = jsonDecode(data) -- Decoded data
				veh:queueLuaCommand("extensions.hook(\"onBeamMPVehicleReset\")")
				if pr then
					veh:setPositionRotation(pr.pos.x, pr.pos.y, pr.pos.z, pr.rot.x, pr.rot.y, pr.rot.z, pr.rot.w) -- Apply position
					veh:resetBrokenFlexMesh() -- setPositionRotation resets the vehicle but not the FlexMesh so we need to do that manually
				else
					veh:reset()
					log('E', "onServerVehicleResetted", "Could not parse posrot JSON")
				end
			end
		else
			log('E', "onServerVehicleResetted", "gameVehicleID for "..serverVehicleID.." not found")
		end
	end
	lastResetTime[serverVehicleID] = localCounter
end

local function onServerVehicleCoupled(serverVehicleID, data)
	local vehicle = getVehicleByServerID(serverVehicleID) -- Get game ID
	if not vehicle.isLocal then
		local veh = be:getObjectByID(vehicle.gameVehicleID)
		if veh then
			veh:queueLuaCommand("couplerVE.toggleCouplerState(mime.unb64(\'".. MPHelpers.b64encode(data) .."\'))")
		end
	end
end

local function onServerCameraSwitched(playerID, serverVehicleID)
	if not players[playerID] then return end -- TODO: better fix?
	if players[playerID] and players[playerID].activeVehicleID and vehicles[players[playerID].activeVehicleID] then
		vehicles[players[playerID].activeVehicleID].spectators[playerID] = nil -- clear prev spectator field
	end

	players[playerID].activeVehicleID = serverVehicleID

	if not vehicles[serverVehicleID] then return end
	vehicles[serverVehicleID].spectators[playerID] = true
end


local HandleNetwork = {
	['s'] = function(rawData) -- spawn
		if not sentPastVehiclesYet then
			sentPastVehiclesYet = true
			M.sendPastVehicles()
		end


		local playerRole, playerNickname, serverVehicleID, data = string.match(rawData, "^(%w+)%:([%g%s]+)%:(%d+%-%d+)%:({.+})") -- 'ROLE:name:0-0:{jsonstring}'

		if playerRole ~= nil then
			onServerVehicleSpawned(playerRole, playerNickname, serverVehicleID, data)
		else
			log('E', "HandleNetwork", "Spawn pattern match failed")
			log('M', 'HandleNetwork', rawData)
		end
	end,
	['r'] = function(rawData) -- reset
		local serverVehicleID, data = string.match(rawData,"^(%d+%-%d+)%:({.+})") -- '0-0:{jsonstring}'

		if serverVehicleID ~= nil then
			onServerVehicleResetted(serverVehicleID, data)
		else
			log('E', "HandleNetwork", "Reset pattern match failed")
		end
	end,
	['c'] = function(rawData) -- config sync
		local serverVehicleID, data = string.match(rawData,"^(%d+%-%d+)%:({.+})") -- '0-0:{jsonstring}'

		if serverVehicleID ~= nil then
			onServerVehicleEdited(serverVehicleID, data)
		else
			log('E', "HandleNetwork", "Config pattern match failed")
		end
	end,
	['d'] = function(rawData) -- remove
		onServerVehicleRemoved(rawData)
	end,
	['t'] = function(rawData) -- coupler
		local serverVehicleID, data = string.match(rawData,"^(%d+%-%d+)%:(%[.+%])") -- '0-0:[jsonstring]'

		if serverVehicleID ~= nil then
			onServerVehicleCoupled(serverVehicleID, data)
		else
			log('E', "HandleNetwork", "Coupler pattern match failed")
		end
	end,
	['m'] = function(rawData) -- camera switched
		local playerID, serverVehicleID = string.match(rawData,"^(%d+)%:(%d+%-%d+)") -- '0:0-0'
		playerID = tonumber(playerID)
		if playerID and serverVehicleID then
			onServerCameraSwitched(playerID, serverVehicleID)
		else
			-- public version has missing playerID
		end
	end
}

local function handle(rawData)
	local code = string.sub(rawData, 1, 1)
	local rawData = string.sub(rawData, 3)
	if HandleNetwork[code] then
		HandleNetwork[code](rawData)
	else
		log('W', 'handle', "Received unknown packet '"..tostring(code).."'! ".. rawData)
	end
end

local function saveDefaultRequest()
	local currentVehicle = be:getPlayerVehicle(0)
	if not MPCoreNetwork.isMPSession() or currentVehicle and isOwn(currentVehicle:getID()) then
		extensions.core_vehicle_partmgmt.savedefault()
		log('I', "saveDefaultRequest", "Request to save vehicle accepted")
	else
		guihooks.trigger('Message', {ttl = 5, msg = "Cant't set another player's vehicle as default", icon = 'error'})
		log('W', "saveDefaultRequest", "Request to save vehicle denied")
	end
end

local function spawnDefaultRequest()
	if not MPCoreNetwork.isMPSession() then original_spawnDefault(); extensions.hook("trackNewVeh"); return end

	local currentVehicle = be:getPlayerVehicle(0)
	local defaultConfig = jsonReadFile('settings/default.pc')

	if currentVehicle then
		local gameVehicleID = currentVehicle:getID()
		local vehicle = getVehicleByGameID(gameVehicleID)
		if vehicle.isLocal then
			return original_replaceVehicle(defaultConfig and defaultConfig.model or core_vehicles.defaultVehicleModel, defaultConfig and {config = 'settings/default.pc', licenseText = defaultConfig.licenseName} or {})
		else
			return original_spawnNewVehicle(defaultConfig and defaultConfig.model or core_vehicles.defaultVehicleModel, defaultConfig and {config = 'settings/default.pc', licenseText = defaultConfig.licenseName} or {})
		end
	else
		return original_spawnNewVehicle(defaultConfig and defaultConfig.model or core_vehicles.defaultVehicleModel, defaultConfig and {config = 'settings/default.pc', licenseText = defaultConfig.licenseName} or {})
	end
	--extensions.hook("trackNewVeh")
end

local function spawnRequest(model, config, colors)
	return original_spawnNewVehicle(model, config or {})
	--extensions.hook("trackNewVeh")
end

local function replaceRequest(model, config, colors)
	local currentVehicle = be:getPlayerVehicle(0)
	local gameVehicleID = currentVehicle and currentVehicle:getID() or -1
	local vehicle = getVehicleByGameID(gameVehicleID)

	if currentVehicle and vehicle and vehicle.isLocal then
		vehicle.jbeam = '-'
		return original_replaceVehicle(model, config or {})
	else
		return original_spawnNewVehicle(model, config or {})
	end
	--extensions.hook("trackNewVeh")
end

M.runPostJoin = function()
	original_removeAllExceptCurrent = core_vehicles.removeAllExceptCurrent
	original_spawnNewVehicle = core_vehicles.spawnNewVehicle
	original_replaceVehicle = core_vehicles.replaceVehicle
	original_spawnDefault = core_vehicles.spawnDefault
	core_vehicles.removeAllExceptCurrent = function() log('W', 'removeAllExceptCurrentVehicle', 'You cannot remove other vehicles in a Multiplayer session!') end
	core_vehicles.spawnNewVehicle = MPVehicleGE.spawnRequest
	core_vehicles.replaceVehicle = MPVehicleGE.replaceRequest
	core_vehicles.spawnDefault = MPVehicleGE.spawnDefaultRequest
end

M.onServerLeave = function() --NOTE: the nil checks are so the function doesn't get set to a nil after a lua reload
	if original_removeAllExceptCurrent then core_vehicles.removeAllExceptCurrent = original_removeAllExceptCurrent end
	if original_spawnNewVehicle then core_vehicles.spawnNewVehicle = original_spawnNewVehicle end
	if original_replaceVehicle then core_vehicles.replaceVehicle = original_replaceVehicle end
	if original_spawnDefault then core_vehicles.spawnDefault = original_spawnDefault end
end

local function sendPendingVehicleEdits()
	for gameVehicleID,_ in pairs(vehiclesToSync) do
		local veh = be:getObjectByID(gameVehicleID)
		if veh and isOwn(veh:getID()) then
			log('I', "syncVehicles", "Autosyncing vehicle "..gameVehicleID)
			sendVehicleEdit(gameVehicleID)
		end
	end
	vehiclesToSync = {}
end


-- groundmarker section

local lastGmQuery = -1 --get player pos on first run
local groundmarkerRoads = {}
local gmTargetPlayer = nil
local lastGmFocus = nil

local function queryRoadNodeToPosition(targetPosition, owner)
	if not owner then owner = "target" end
	targetPosition = vec3(targetPosition)
	local first, second, distance = map.findClosestRoad(targetPosition)
	if not first and not second then return false end

	groundmarkerRoads[owner] = {position=targetPosition}
	if first ~= 'nil' and second ~= 'nil' then
		groundmarkerRoads[owner].first = first
		groundmarkerRoads[owner].next = second

		local mapData = map.getMap()
		local node1 = mapData.nodes[first]
		local node2 = mapData.nodes[second]
		if node1 and node2 then
			-- find which node is closest to the owner
			local sqrDist1 = (targetPosition - node1.pos):squaredLength()
			local sqrDist2 = (targetPosition - node2.pos):squaredLength()

			if sqrDist1 < sqrDist2 then groundmarkerRoads[owner].best = first
			else groundmarkerRoads[owner].best = second end

			return true, groundmarkerRoads[owner].best
		end
	end
	return false, nil
end

local function groundmarkerToPlayer(targetName)
	if not targetName then
		groundmarkerRoads["targetVeh"] = nil
		lastGmFocus = nil
		core_groundMarkers.setFocus(nil)
	end
	for serverVehicleID, vehicle in pairs(vehicles) do
		if vehicle.ownerName == targetName then
			local targetVeh = be:getObjectByID(vehicle.gameVehicleID)
			local targetVehPos = targetVeh:getPosition()
			local vec3Pos = vec3(targetVehPos.x, targetVehPos.y, targetVehPos.z)

			queryRoadNodeToPosition(vec3Pos, "targetVeh")
			return
		end
	end
end

local function groundmarkerFollowPlayer(targetName, dontfollow)
	if dontfollow then --static
		groundmarkerToPlayer(targetName)
	else
		if targetName then gmTargetPlayer = targetName
		else
			gmTargetPlayer = nil
			groundmarkerRoads["targetVeh"] = nil
			lastGmFocus = nil
			core_groundMarkers.setFocus(nil)
		end
	end
end

local function teleportVehToPlayer(targetName)
	local activeVehicle = be:getPlayerVehicle(0)

	if activeVehicle then
		for serverVehicleID, vehicle in pairs(vehicles) do
			if vehicle.ownerName == targetName then
				--print("teleporting to "..tostring(i))
				local targetVeh = be:getObjectByID(vehicle.gameVehicleID)
				local targetVehPos = targetVeh:getPosition()
				local targetVehRot = quatFromDir(vec3(targetVeh:getDirectionVector()), vec3(targetVeh:getDirectionVectorUp()))

				local vec3Pos = vec3(targetVehPos.x, targetVehPos.y, targetVehPos.z)

				spawn.safeTeleport(activeVehicle, vec3Pos, targetVehRot, false)
				return
			end
		end
	else
		log('W', "teleportVehToPlayer", "no active vehicle found, teleporting camera instead")
		focusCameraOnPlayer(targetName)
	end
end

local function focusCameraOnPlayer(targetName)
	local activeVehicle = be:getPlayerVehicle(0)
	local activeVehicleID = activeVehicle and activeVehicle:getID() or nil
	log('I', "focusCameraOnPlayer", "Teleporting camera to: "..targetName)

	for serverVehicleID, vehicle in pairs(vehicles) do
		if vehicle.ownerName == targetName and vehicle.jbeam ~= "unicycle" then
			log('I', "focusCameraOnPlayer", "Found vehicle: "..vehicle.gameVehicleID)
			local targetVeh = be:getObjectByID(vehicle.gameVehicleID)

			if vehicle.gameVehicleID ~= activeVehicleID and targetVeh then
				log('I', "focusCameraOnPlayer", "Entering vehicle "..vehicle.gameVehicleID)
				be:enterVehicle(0,targetVeh)
				return
			end
		end
	end
end

local function applyVehicleQueues(serverVehicleID, vehicle) 
	if vehicle.spawnQueue then
		local data = vehicle.spawnQueue
		vehicle.spawnQueue = nil
		applyVehSpawn(data)
	end
	if vehicle.editQueue then
		local data = vehicle.editQueue
		vehicle.editQueue = nil
		applyVehEdit(serverVehicleID, data)
	end
end

local function applyQueuedEvents()
	for serverVehicleID, vehicle in pairs(vehicles) do
		applyVehicleQueues(serverVehicleID, vehicle)
	end

	UI.updateQueue(getQueueCounts())
	--if currentVeh then be:enterVehicle(0, currentVeh) print("entered "..currentVeh:getJBeamFilename()) end -- Camera fix
end

local function applyPlayerQueues(playerID)
	for serverVehicleID, vehicle in pairs(vehicles) do
		if vehicle.ownerID == playerID then
			applyVehicleQueues(serverVehicleID, vehicle)
		end
	end

	UI.updateQueue(getQueueCounts())
end

local function onUpdate(dt)
	if MPGameNetwork and MPGameNetwork.launcherConnected() then
		localCounter = localCounter + dt
	end
end

local function onPreRender(dt)
	if MPGameNetwork and MPGameNetwork.launcherConnected() then

		-- get current vehicle ID and position
		local activeVeh = be:getPlayerVehicle(0)
		local activeVehPos = activeVeh and vec3(activeVeh:getPosition()) or nil
		local activeVehID = activeVeh and activeVeh:getID() or nil

		-- Groundmarkers
		if activeVehPos then
			lastGmQuery = lastGmQuery - dt
			if lastGmQuery <= 0 then
				lastGmQuery = 0.2
				queryRoadNodeToPosition(activeVehPos, 'player')
				if gmTargetPlayer then groundmarkerToPlayer(gmTargetPlayer) end
			end

			local playerRoadData = groundmarkerRoads['player']
			if playerRoadData and playerRoadData.first and playerRoadData.first ~= 'nil' then
				for target, data in pairs(groundmarkerRoads) do
					if target ~= 'player' then
						if data.best and data.best ~= lastGmFocus then
							if (activeVehPos - data.position):squaredLength() > 200 then
								core_groundMarkers.setFocus(data.best)
								log('M', 'onPreRender', 'setting focus to '..data.best)
								lastGmFocus = data.best
							else
								core_groundMarkers.setFocus(nil)
								groundmarkerRoads[target] = nil
							end
						end
					end
				end
			end
		end


		-- get camera position, apply queue
		local cameraPos = vec3(core_camera.getPosition())
		if activeVeh then
			if not commands.isFreeCamera() then cameraPos = activeVehPos end

			if settings.getValue("queueAutoSkipRemote") and not isOwn(activeVehID) then applyQueuedEvents() end

			if settings.getValue("enableQueueAuto") then
				local vehicleSpd = math.abs(activeVeh:getVelocity():length() or 0)

				local maxSyncSpd = settings.getValue("queueApplySpeed")
				local maxTime = settings.getValue("queueApplyTimeout")


				-- If below set speed
				if (vehicleSpd <= maxSyncSpd) then
					queueApplyTimer = queueApplyTimer + dt
					guihooks.trigger("setAutoQueueProgress", tostring((queueApplyTimer / maxTime)*100))
					-- if time under speed more than or equal to max
					if (queueApplyTimer >= maxTime) then
						applyQueuedEvents()
						queueApplyTimer = 0
					end
				else -- Reset timer and UI
					if queueApplyTimer > 0 then
						guihooks.trigger("setAutoQueueProgress", "0")
					end
					queueApplyTimer = 0
				end
			end
		else
			queueApplyTimer = 0
			applyQueuedEvents()
			if not commands.isFreeCamera() then
				commands.setFreeCamera()		-- Fix camera
			end
		end


		--if not activeVeh and be:getObjectCount() == 0 then return end -- If no vehicle do nothing
		-- Vehicles syncing timer
		editSyncTimer = editSyncTimer + dt
		if editSyncTimer > 15 then
			if settings.getValue("autoSyncVehicles") then sendPendingVehicleEdits() end
			editSyncTimer = 0
		end

		for serverVehicleID, v in pairs(vehicles) do
			local owner = v:getOwner()
			if v.isLocal or not owner then goto skip_vehicle end
			local gameVehicleID = v.gameVehicleID
			local veh = be:getObjectByID(gameVehicleID)

			if v.isSpawned and veh then -- update position if available
				if not v.vehicleHeight then
					v.vehicleHeight = veh:getInitialHeight()
				end
				local tempPosx,tempPosy,tempPosz = be:getObjectOOBBCenterXYZ(gameVehicleID)
				v.position = vec3(tempPosx,tempPosy,tempPosz)
				v.position.z = v.position.z + (v.vehicleHeight * 0.5) + 0.2

				v.rotation = quatFromDir(-vec3(veh:getDirectionVector()), vec3(veh:getDirectionVectorUp())) -- getRotation doesn't update in GE so we need to use direction vectors instead
			end

			if not v.position then goto skip_vehicle end -- return if no position has been received yet
			local pos = Point3F(v.position.x, v.position.y, v.position.z)

			if settings.getValue("enableBlobs") and not v.isSpawned then
				local colors = nil

				if v.spawnQueue then -- in queue
					if settingsCache.showBlobQueued then
						colors = MPHelpers.hex2rgb(settings.getValue("blobColorQueued"))
					end
				elseif v.isIllegal then -- illegal (modded)
					if settingsCache.showBlobIllegal then
						colors = MPHelpers.hex2rgb(settings.getValue("blobColorIllegal"))
					end
				elseif v.isDeleted then
					if settingsCache.showBlobDeleted then
						colors = MPHelpers.hex2rgb(settings.getValue("blobColorDeleted"))
					end
				else
					colors = { 1, 0, 1 }
				end

				if colors then
					debugDrawer:drawSphere(pos, 1, ColorF(colors[1], colors[2], colors[3], 0.5))
					pos.z = pos.z + 1
				end
			end

			local nametagAlpha = 1
			local nametagFadeoutDistance = settings.getValue("nameTagFadeDistance", 40)

			local distfloat = (cameraPos or vec3()):distance(pos)
			distanceMap[gameVehicleID] = distfloat
			nametagAlpha = clamp(linearScale(distfloat, nametagFadeoutDistance, 0, 0, 1), 0, 1)

			if not settings.getValue("hideNameTags") and nicknamesAllowed and not hideNicknamesToggle then

				local dist = ""
				if distfloat > 10 and settings.getValue("nameTagShowDistance") then
					local unit
					local mapEntry = distfloat
					if settings.getValue("uiUnitLength") == "imperial" then
						mapEntry = mapEntry * 3.28084
						if mapEntry > 5280 then
							mapEntry = math.floor((mapEntry / 5280 * 100) + 0.5) / 100
							unit = "mi"
						else
							mapEntry = math.floor(mapEntry)
							unit = "ft"
						end
					else
						if mapEntry >= 1000 then
							mapEntry = math.floor((mapEntry / 10) + 0.5) / 100
							unit = "km"
						else
							mapEntry = math.floor(mapEntry)
							unit = "m"
						end
					end

					dist = string.format(" %s %s", tostring(mapEntry), unit)
				end

				if settings.getValue("fadeVehicles") and veh then
					if activeVehID == gameVehicleID then veh:setMeshAlpha(1, "", false)
					else veh:setMeshAlpha(1 - clamp(linearScale(distfloat, 20, 0, 0, 1), 0, 1), "", false) end
				end

				if v.hideNametag or owner.hideNametag then goto skip_vehicle end

				if settings.getValue("nameTagFadeEnabled") and not commands.isFreeCamera() then
					if settings.getValue("nameTagFadeInvert") then
						nametagAlpha = 1 - nametagAlpha
					end
				end

				if not settings.getValue("nameTagFadeEnabled") then nametagAlpha = 1 end
				if settings.getValue("nameTagDontFullyHide") then nametagAlpha = math.max(0.3, nametagAlpha) end


				local roleInfo = v.customRole or owner.customRole or owner.role

				local ownerName = settings.getValue("shortenNametags") and owner.shortname or owner.name
				local name = v.customName or ownerName

				local tag = settings.getValue("shortenNametags") and roleInfo.shorttag or roleInfo.tag
				local backColor = ColorI(roleInfo.backcolor.r, roleInfo.backcolor.g, roleInfo.backcolor.b, math.floor(nametagAlpha*127))

				local prefix = ""
				for source, tag in pairs(owner.nickPrefixes)
					do prefix = prefix..tag.." " end

				local suffix = ""
				for source, tag in pairs(owner.nickSuffixes)
					do suffix = suffix..tag.." " end


				-- draw spectators
				if settings.getValue("showSpectators") then
					local spectators = ""

					for spectatorID, _ in pairs(v.spectators) do
						local spectator = players[spectatorID]
						if not (spectator == owner or spectator.isLocal) then
							spectators = spectators .. spectator.name .. ', '
						end
					end

					spectators = spectators:sub(1,-3) -- cut off tailing comma

					if spectators ~= "" then
						local spectatorBackColor = backColor
						if settings.getValue("spectatorUnifiedColors") then
							spectatorBackColor = ColorI(roleToInfo.USER.backcolor.r, roleToInfo.USER.backcolor.g, roleToInfo.USER.backcolor.b, math.floor(nametagAlpha*127))
						end
						debugDrawer:drawTextAdvanced(
							pos, -- Location
							String(" ".. spectators .." "), -- Text
							ColorF(1, 1, 1, nametagAlpha), true, false, -- Foreground Color / Draw background / Wtf
							spectatorBackColor) -- Background Color

						pos.z = pos.z + 0.01 -- has to be positive
					end
				end

				-- draw main nametag
				debugDrawer:drawTextAdvanced(
					pos, -- Location
					String(" " .. table.concat({prefix, name, suffix, tag, dist}) .. " "), -- Text
					ColorF(1, 1, 1, nametagAlpha), true, false, -- Foreground Color / Draw background / Wtf
					backColor -- Background Color
				)
			end
			:: skip_vehicle ::
		end
	end
end

local function onSerialize()
	if (getMissionFilename() or "") == "" then return end

	local data = {
		vehicles = serializeVehicles(),
		players = serializePlayers()
	}
	return data
end

local function onDeserialized(data)
	if true then return end -- TODO: check if server has been switched instead
	if (getMissionFilename() or "") == "" then return end

	for k,v in pairs(data.vehicles) do
		vehicles[k] = Vehicle:new(v)
	end

	for k,v in pairs(data.players) do
		players[k] = Player:new(v)
	end
	sentPastVehiclesYet = false
end

local function sendPastVehicles()
	local thisID = MPConfig.getPlayerServerID()

	if thisID > -1 then
		dump(players[thisID].vehicles)

		local gameIDs = {}

		for k,v in pairs(players[thisID].vehicles) do
			--print('deleting '..dumps(v))
			gameIDs[k] = v.gameVehicleID
			v:delete()
		end

		for k, v in pairs(gameIDs) do
			sendVehicleSpawn(v)
		end
	end


end

local function onDisconnect()
	for playerID, player in pairs(players) do
		player:delete()
	end
	players = {}

	for serverVehicleID, vehicle in pairs(vehicles) do
		vehicle:delete()
	end
	vehicles = {}
end

local function onPlayerLeft(name)
	for playerID, player in pairs(players) do
		if player.name == name then
			players[playerID]:delete()
			break
		end
	end
end

local function onVehicleReady(gameVehicleID)
	log('M', 'onVehicleReady', 'Vehicle '..tostring(gameVehicleID)..' signaled that it is ready')
	local veh = be:getObjectByID(gameVehicleID)
	if not veh then
		log('E', 'onVehicleReady', 'Vehicle does not exist!')
		return
	end

	if veh.mpVehicleType then
		veh:queueLuaCommand("MPVehicleVE.setVehicleType(mime.unb64(\'".. MPHelpers.b64encode(veh.mpVehicleType) .."\'))")
	end
	MPGameNetwork.onVehicleReady(gameVehicleID)
end


local function onUIInitialised()
	UI.updateQueue(getQueueCounts())
end

local function onExtensionLoaded()
	onSettingsChanged()
end

local function onSettingsChanged()
	for playerID,player in pairs(players) do
		player:onSettingsChanged()
	end

	local cacheKeys = { "showBlobQueued", "showBlobIllegal", "showBlobDeleted" }
	local colorKeys = { "blobColorQueued", "blobColorIllegal", "blobColorDeleted" }

	for _,k in pairs(cacheKeys) do
		settingsCache[k] = settings.getValue(k)
	end

	--for _,v in pairs(colorKeys) do
	--	local p = table.pack(MPHelpers.hex2rgb(settings.getValue(k)))
	--	p[4] = 0.5
	--
	--	settingsCache[k]  = ColorF(table.unpack(p))
	--end
end

detectGlobalWrites() -- reenable global write notifications

-- Functions
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

M.sendPastVehicles = sendPastVehicles

-- EVENTS
M.onUpdate                 = onUpdate
M.onPreRender              = onPreRender
M.onDisconnect             = onDisconnect
M.handle                   = handle
M.onVehicleSpawned         = onVehicleSpawned
M.onVehicleDestroyed       = onVehicleDestroyed
M.onVehicleSwitched        = onVehicleSwitched
M.onVehicleResetted        = onVehicleResetted
M.onPlayerLeft             = onPlayerLeft
M.onClientPostStartMission = onDisconnect
M.onUIInitialised          = onUIInitialised
-- FUNCTIONS
M.restorePlayerVehicle     = restorePlayerVehicle         -- takes: playerID eg 1 2 3 4
M.getPlayers               = getPlayers               -- takes: -
M.getVehicles              = getVehicles              -- takes: -
M.getVehicleByGameID       = getVehicleByGameID       -- takes: number gameID, returns Vehicle
M.getVehicleByServerID     = getVehicleByServerID     -- takes: string serverVehicleID, returns Vehicle
M.getPlayerByName          = getPlayerByName          -- takes: string name, returns Player
M.isOwn                    = isOwn                    -- takes: number vehID  returns: bool
M.getOwnMap                = getOwnMap                -- takes: -      returns: { 'vehid' : true, '23456' : true }
M.setOwn                   = setOwn                   -- takes: number vehID, bool own
M.getDistanceMap           = getDistanceMap           -- takes: -      returns: { vehid : distanceinmeters, 123: 56 }
M.getVehicleMap            = getVehicleMap            -- takes: -
M.getNicknameMap           = getNicknameMap           -- takes: -
M.hideNicknames            = hideNicknames            -- takes: bool   returns: -
M.toggleNicknames          = toggleNicknames          -- takes: -
M.setPlayerNickPrefix      = setPlayerNickPrefix      -- takes: string targetName, string tagSource, string text
M.setPlayerNickSuffix      = setPlayerNickSuffix      -- takes: string targetName, string tagSource, string text
M.setVehicleRole           = setVehicleRole           -- takes: string playerIDvehicleID, string tag, string shorttag, number red, number green, number blue
M.clearVehicleRole         = clearVehicleRole         -- takes: string playerIDVehicleID
M.setPlayerRole            = setPlayerRole            -- takes: string playerID, string tag, string shorttag, number red, number green, number blue
M.clearPlayerRole          = clearPlayerRole          -- takes: string playerID
M.getGameVehicleID         = getGameVehicleID         -- takes: -      returns: { 'gamevehid' : 'servervehid', '23456' : '1-2' }
M.getServerVehicleID       = getServerVehicleID       -- takes: -      returns: { 'servervehid' : 'gamevehid', '1-2' : '23456' }
M.saveDefaultRequest       = saveDefaultRequest       -- takes: -
M.spawnDefaultRequest      = spawnDefaultRequest      -- takes: -
M.spawnRequest             = spawnRequest             -- takes: jbeamName, config, colors
M.replaceRequest           = replaceRequest           -- takes: jbeamName, config, colors
M.sendBeamstate            = sendBeamstate            -- takes: string state, number gameVehicleID
M.applyQueuedEvents        = applyQueuedEvents        -- takes: -      returns: -
M.applyPlayerQueues        = applyPlayerQueues        -- takes: playerID
M.teleportVehToPlayer      = teleportVehToPlayer      -- takes: string targetName
M.focusCameraOnPlayer      = focusCameraOnPlayer      -- takes: string targetName
M.groundmarkerToPlayer     = groundmarkerToPlayer     -- takes: string targetName
M.groundmarkerFollowPlayer = groundmarkerFollowPlayer -- takes: string targetName
M.queryRoadNodeToPosition  = queryRoadNodeToPosition  -- takes: vec3 target position, optional string targetname
M.sendVehicleEdit          = sendVehicleEdit          -- UI 'Sync' button
M.onVehicleReady           = onVehicleReady           -- Called when our VE files load and the vehicle is ready
M.onSettingsChanged        = onSettingsChanged        -- takes: -
M.onInit = function() setExtensionUnloadMode(M, "manual") end

local function depricationWarning(oldFnName, replacementName)
	local msg = "Deprecated function! Please update your code to use " .. tostring(replacementName)
	log('E', oldFnName, debug.traceback(msg))
	guihooks.trigger("toastrMsg", {type="warning", title="Deprecated BeamMP function used", msg=msg})

	return nil, msg
end


local function teleportCameraToPlayer(playername)
	depricationWarning('teleportCameraToPlayer', 'MPVehicleGE.focusCameraOnPlayer')
	focusCameraOnPlayer(playername)
end

function createRole() depricationWarning('createRole', 'MPVehicleGE.setVehicleRole/setPlayerRole') end
function removeRole() depricationWarning('removeRole', 'MPVehicleGE.clearVehicleRole/clearPlayerRole') end
function removeVehicleRole() depricationWarning('removeVehicleRole', 'MPVehicleGE.clearVehicleRole/clearPlayerRole') end

M.createRole = createRole
M.removeRole = removeRole
M.removeVehicleRole = removeVehicleRole
M.teleportCameraToPlayer   = teleportCameraToPlayer

return M
