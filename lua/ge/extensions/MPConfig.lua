--====================================================================================
-- All work by Titch2000, 20dka, snepsnepsnep.
-- You have no permission to edit, redistribute or upload other than for the purposes of contributing. 
-- Contact BeamMP for more info!
--====================================================================================

--- MPConfig API - This is the file responsible for storing the settings and values for a given session.
-- Author of this documentation is Titch2000
-- @module MPConfig
-- @usage local nickname = getNickname() -- internal access
-- @usage local nickname = MPConfig.getNickname() -- external access


local M = {}

-- MP VARIABLES
local Nickname = ""
local PlayerServerID = -1

local defaultSettings = {
	autoSyncVehicles = true, nameTagShowDistance = true, enableBlobs = true, showSpectators = true, nametagCharLimit = 32,
	-- queue system
	enableSpawnQueue = true, enableQueueAuto = true, queueSkipUnicycle = true, queueApplySpeed = 2, queueApplyTimeout = 3,
	-- colors
	showBlobQueued = true, blobColorQueued = "#FF6400", showBlobIllegal = true, blobColorIllegal = "#000000", showBlobDeleted = true, blobColorDeleted = "#333333",

	-- new chat menu
	enableNewChatMenu = false,

	-- show custom vehicles in vehicle selector
	showPcs = true,

	disableInstabilityPausing = true,

	launcherPort = 4444
}

--- Called when the mod is loaded by the games modloader. 
-- @usage INTERNAL ONLY / GAME SPECIFIC
local function onExtensionLoaded()
	for k,v in pairs(defaultSettings) do
		if settings.getValue(k) == nil then settings.setValue(k, v) end
		--settings.impl.defaults[k] = { 'local', v }
		--settings.impl.defaultValues[k] = v
	end
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

--- Set the PlayerServerID variable for use by other aspects of the mod.
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
	table.sort(favs, sortByAgeDesc)

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
-- @tparam table favstr The favorites data as a table.
-- @usage MPConfig.setFavorites(`<favorites table>`)
local function setFavorites(favstr)
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

-- Events
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized
M.onExtensionLoaded = onExtensionLoaded

-- Functions
M.getPlayerServerID = getPlayerServerID
M.setPlayerServerID = setPlayerServerID

M.getNickname = getNickname
M.setNickname = setNickname

M.getFavorites = getFavorites
M.setFavorites = setFavorites
M.getConfig = getConfig
M.setConfig = setConfig

M.acceptTos = acceptTos

return M
