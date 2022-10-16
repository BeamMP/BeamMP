--====================================================================================
-- All work by Titch2000.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading MPConfig...")

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
	enableNewChatMenu = true,

	-- show custom vehicles in vehicle selector
	showPcs = true,
}

local function onExtensionLoaded()
	for k,v in pairs(defaultSettings) do
		--if settings.getValue(k) == nil then settings.setValue(k, v) end
		settings.impl.defaults[k] = { 'local', v }
		settings.impl.defaultValues[k] = v
	end
	settings.impl.invalidateCache()
end


local function setNickname(x)
	log('M', 'setNickname', 'Nickname Set To: '..x)
	Nickname = x
end

local function getNickname()
	return Nickname
end

local function setPlayerServerID(x)
	PlayerServerID = tonumber(x)
end

local function getPlayerServerID()
	return PlayerServerID
end

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
	return favs
end


local function setFavorites(favstr)
	if not FS:directoryExists("settings/BeamMP") then
		FS:directoryCreate("settings/BeamMP")
	end

	local favs = json.decode(favstr)
	local favsfile = '/settings/BeamMP/favorites.json'
	jsonWriteFile(favsfile, favs)
end


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

local function setConfig(settingName, settingVal)
	local config = getConfig()
	if not config then config = {} end

	config[settingName] = settingVal

	local favsfile = '/settings/BeamMP/config.json'
	jsonWriteFile(favsfile, config)
end


local function acceptTos()
	local config = getConfig()
	if not config then config = {} end

	config.tos = true

	local favsfile = '/settings/BeamMP/config.json'
	jsonWriteFile(favsfile, config)
end

local function onSerialize()
	local data = {
		Nickname = Nickname,
		PlayerServerID = PlayerServerID
	}
	return data
end

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

print("MPConfig loaded")
return M
