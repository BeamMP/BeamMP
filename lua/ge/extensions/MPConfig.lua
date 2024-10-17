-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- MPConfig API - This script sets Default settings if not present and handles session specific data.
-- Author of this documentation is Titch2000
-- @module MPConfig
-- @usage local nickname = getNickname() -- internal access
-- @usage local nickname = MPConfig.getNickname() -- external access


local M = {}

-- MP VARIABLES
local Nickname = ""
local PlayerServerID = -1

--- Returns a table of all to the disk saved unicycle configs
-- @treturn[1] table eg. {"MyFavConfig": "MyFavConfig.pc"}
-- @usage INTERNAL ONLY / GAME SPECIFIC
local function getUnicycleConfigs()
	-- Load the unicycle configurations:
	local pcfiles = FS:findFiles("/vehicles/unicycle/", "*.pc", 0, true, false)
	local pcFileRegex = "^/vehicles/unicycle/(.*)%.pc"
	local tmp = {}

	for _, filename in ipairs(pcfiles) do
		local file = filename:match(pcFileRegex)
		if file ~= "beammp_default" then
			tmp[file] = file..'.pc'
		end
	end

	if tmp ~= settings.getValue('unicycleConfigs') then settings.setValue('unicycleConfigs', tmp) end -- multiplayer.partial ui will read this value
	return tmp
end

--- Sets a new default Unicycle
-- @tparam string configFileName eg. "MyFavConfig" not "MyFavConfig.pc"
-- @treturn[1] true if Success
-- @treturn[2] nil if Failure
local function setDefaultUnicycle(configFileName)
	local configFileName = configFileName .. ".pc"
	local handle = io.open("vehicles/unicycle/" .. configFileName, "r")
	if handle == nil then
		log('I', "setDefaultUnicycle", 'Cannot open "vehicles/unicycle/' .. configFileName .. '" in read mode.')
		return nil
	end
	local newconfig = handle:read("*all")
	handle:close()
	
	local handle = io.open("vehicles/unicycle/beammp_default.pc", "w")
	if handle == nil then
		log('I', "setDefaultUnicycle", 'Cannot open "vehicles/unicycle/beammp_default.pc" in write mode.')
		return nil
	end
	handle:write(newconfig)
	handle:close()
	return true
end

local defaultSettings = {
	autoSyncVehicles = true, nameTagShowDistance = true, enableBlobs = true, showSpectators = true, nametagCharLimit = 32, showPlayerIDs = false,
	-- queue system
	enableSpawnQueue = true, enableQueueAuto = true, queueSkipUnicycle = true, queueApplySpeed = 2, queueApplyTimeout = 3, highlightQueuedPlayers = true, queueWithLMB = true,
	-- colors
	showBlobQueued = true, blobColorQueued = "#FF6400", showBlobIllegal = true, blobColorIllegal = "#000000", showBlobDeleted = true, blobColorDeleted = "#333333",

	-- new chat menu
	enableNewChatMenu = false,

	-- show custom vehicles in vehicle selector
	showPcs = true,
	
	enablePosSmoother = false, -- experimental

	-- unicycle configurations
	unicycleConfigs = getUnicycleConfigs(), unicycleAutoSave = true,
	--unicycle_pc = nil, -- temp value introduced to share the user selected default unicycle config from the multiplayer.partial ui to MPConfig.setDefaultUnicycle()

	disableInstabilityPausing = true,

	launcherPort = 4444
}

--- Called when the mod is loaded by the games modloader. 
-- @usage INTERNAL ONLY / GAME SPECIFIC
local function onExtensionLoaded()
	for k,v in pairs(defaultSettings) do
		if settings.getValue(k) == nil or k == 'unicycleConfigs' then settings.setValue(k, v) end
		--settings.impl.defaults[k] = { 'local', v }
		--settings.impl.defaultValues[k] = v
	end
	--dump(defaultSettings)
	settings.impl.invalidateCache()
end

--- Set the users Nickname variable for use by other aspects of the mod.
-- @tparam string x The users nickname that we have received.
-- @usage MPConfig.setNickname(`<nickname>`)
local function setNickname(x)
	log('M', 'setNickname', 'Nickname Set To: '..x)
	Nickname = x
end

--- Get the users Nickname.
-- @treturn string The users nickname.
-- @usage local nickname = MPConfig.getNickname()
local function getNickname()
	return Nickname
end

--- Sets the ID the server gave this Client, for use by other aspects of the mod.
-- @tparam number x The PlayerServerID that we have received.
-- @usage MPConfig.setPlayerServerID(`<players server ID>`)
local function setPlayerServerID(x)
	PlayerServerID = tonumber(x)
end

--- Get the PlayerServerID variable.
-- @treturn number The users server ID.
-- @usage local nickname = MPConfig.getPlayerServerID()
local function getPlayerServerID()
	return PlayerServerID
end

--- Check for old configuration files and move them to the new location if found.
-- @treturn boolean True if any files were moved, false otherwise.
-- @usage local updatedConfigs = MPConfig.checkForOldConfig()
local function checkForOldConfig()
	if not FS:directoryExists("BeamMP") then
		return false
	end

	if not FS:directoryExists("settings/BeamMP") then
		FS:directoryCreate("settings/BeamMP")
	end

	local movedfiles = false

	local oldfav = '/BeamMP/favorites.json'
	local newfav = '/settings/BeamMP/favorites.json'
	if FS:fileExists(oldfav) then
		FS:copyFile(oldfav, newfav)
		FS:removeFile(oldfav)
		movedfiles = true
	end

	local oldconf = '/BeamMP/config.json'
	local newconf = '/settings/BeamMP/config.json'
	if FS:fileExists(oldconf) then
		FS:copyFile(oldconf, newconf)
		FS:removeFile(oldconf)
		movedfiles = true
	end
	return movedfiles
end

--- Get the favorites from the favorites.json file.
-- @treturn table The favorites data.
-- @usage local favorites = MPConfig.getFavorites()
local function getFavorites()
	if not FS:directoryExists("settings/BeamMP") then
		if checkForOldConfig() then
			return getFavorites()
		else
			return nil
		end
	end

	local favs = nil
	local favsfile = '/settings/BeamMP/favorites.json'
	if FS:fileExists(favsfile) then
		favs = jsonReadFile(favsfile)
	else
		log('M', 'getFavorites', "Favs file doesn't exist")
	end
	
	local function sortByAgeDesc(a, b)
		return a.addTime > b.addTime
	end

	-- Sort the data table using the comparison function
	if favs then
		table.sort(favs, sortByAgeDesc)
	else
		log('E', 'getFavorites', 'Unable to read favorites from file or file is empty')
		favs = {} -- Initialize favs to an empty table to avoid further errors
	end

	local cleanedServers = {}

  -- Create a table to track which keys have already been added to the filtered data
  local addedKeys = {}

  -- Iterate over the input data table
  for i, server in ipairs(favs) do
    -- Get the value of the key for this object
    local serverKey = ''..server['ip']..':'..server['port']

    -- If the key has not been added to the filtered data yet, add the object and mark the key as added
    if not addedKeys[serverKey] then
      table.insert(cleanedServers, server)
      addedKeys[serverKey] = true
    end
  end

	return cleanedServers
end

--- Set the favorites in the favorites.json file.
-- @tparam string favstr The favorites data as a base64 encoded string.
-- @usage MPConfig.setFavorites(`<favorites table>`)
local function setFavorites(favstr)
	local favstr = MPHelpers.b64decode(favstr)
	if not FS:directoryExists("settings/BeamMP") then
		FS:directoryCreate("settings/BeamMP")
	end

	local favs = jsonDecode(favstr)
	local favsfile = '/settings/BeamMP/favorites.json'
	jsonWriteFile(favsfile, favs, true)
end

--- Get the configuration from the config.json file.
-- @treturn table The configuration data.
-- @usage local config = MPConfig.getConfig()
local function getConfig()
	if not FS:directoryExists("settings/BeamMP") then
		if checkForOldConfig() then
			return getConfig()
		else
			return nil
		end
	end

	local file = '/settings/BeamMP/config.json'
	if FS:fileExists(file) then
		return jsonReadFile(file)
	else
		log('M', 'getConfig', "Config file doesn't exist")
		return nil
	end
end

--- Set a configuration setting in the config.json file.
-- @tparam string settingName The name of the setting.
-- @param settingVal The value of the setting.
-- @usage MPConfig.setConfig(`<setting name>, <setting value>`)
local function setConfig(settingName, settingVal)
	local config = getConfig()
	if not config then config = {} end

	config[settingName] = settingVal

	local favsfile = '/settings/BeamMP/config.json'
	jsonWriteFile(favsfile, config, true)
end

--- Accept the BeamMP terms of service.
-- @usage INTERNAL ONLY / GAME SPECIFIC
local function acceptTos()
	local config = getConfig()
	if not config then config = {} end

	config.tos = true

	local favsfile = '/settings/BeamMP/config.json'
	jsonWriteFile(favsfile, config, true)
end

--- Serialize the data for saving.
-- @treturn table The serialized data.
-- @usage INTERNAL ONLY / GAME SPECIFIC
local function onSerialize()
	local data = {
		Nickname = Nickname,
		PlayerServerID = PlayerServerID
	}
	return data
end

--- Deserialize the data when loading.
-- @tparam table data The deserialized data.
-- @usage INTERNAL ONLY / GAME SPECIFIC
local function onDeserialized(data)
	Nickname = data.Nickname
	PlayerServerID = data.PlayerServerID
end

--- Multiplayer Options <-> Lua data bridge
-- @usage INTERNAL ONLY / GAME SPECIFIC
local function onSettingsChanged()
	local unicycle_pc = settings.getValue("unicycle_pc")
	if unicycle_pc ~= nil then
		setDefaultUnicycle(unicycle_pc)
		settings.setValue("unicycle_pc", nil) -- reset to prevent reapply on every setting change
		guihooks.trigger('toastrMsg', {type="info", title = "Unicycle", msg = MPTranslate("ui.options.multiplayer.unicycleOnSwitch") .. " " .. unicycle_pc, config = {timeOut = 3000}})
	end
	getUnicycleConfigs()
end

-- Events
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized
M.onExtensionLoaded = onExtensionLoaded
M.onSettingsChanged = onSettingsChanged

-- Functions
M.getPlayerServerID = getPlayerServerID
M.setPlayerServerID = setPlayerServerID
M.setDefaultUnicycle = setDefaultUnicycle

M.getNickname = getNickname
M.setNickname = setNickname

M.getFavorites = getFavorites
M.setFavorites = setFavorites
M.getConfig = getConfig
M.setConfig = setConfig

M.acceptTos = acceptTos
M.onInit = function() setExtensionUnloadMode(M, "manual") end

return M
