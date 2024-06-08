-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- MPModManager API.
--- Author of this documentation is Titch
--- @module MPModManager


local M = {}

local serverMods = {} -- multiplayerModName1, multiplayerModName2
local whitelist = {"multiplayerbeammp", "beammp", "translations"} -- these mods won't be activated or deactivated
local hasMods = false

--TODO: build handler for repo mod downloads

function queueExtensionToLoad(extension)  -- temporary workaround for mods still using that function
	guihooks.trigger("toastrMsg", {type="error", title="queueExtensionToLoad", msg="This function is deprecated, please use setExtensionUnloadMode() instead."})
	log('E','queueExtensionToLoad', 'This function is deprecated, please use setExtensionUnloadMode() instead.')
	setExtensionUnloadMode(extension, 'manual')
end


local function unloadLocalesAndDefaults()
	FS:unmount('/temp/beammp/beammp_locales_and_defaults.zip')
	FS:directoryRemove('/temp/beammp')
end

--- Load the BeamMP provided locales + defalts and merge them into a working set for BeamNG
local function loadLocalesAndDefaults() -- loads beammp locales and default settings without having to directly replace the game locales and default settings
	unloadLocalesAndDefaults()
	local mp_locales = FS:findFiles('/mp_locales/', '*.json', 0)
	local game_locales = FS:findFiles('/locales/', '*.json', 0)

	for _, mp_locale in pairs(mp_locales) do
		for _, game_locale in pairs(game_locales) do
			if game_locale:gsub('/locales/', '') == mp_locale:gsub('/mp_locales/', '') then
				local merged_locale = tableMergeRecursive(jsonReadFile(game_locale), jsonReadFile(mp_locale))
				log('M', 'loadLocalesAndDefaults', 'Writing '..game_locale)
				jsonWriteFile('/temp/beammp/'.. game_locale, merged_locale, true)
			end
		end
	end

	local merged_settings = tableMergeRecursive(jsonReadFile('/settings/defaults.json'), jsonReadFile('/settings/mp_defaults.json'))
	log('M', 'loadLocalesAndDefaults', 'Writing /settings/defaults.json')
	jsonWriteFile('/temp/beammp/settings/defaults.json', merged_settings, true)

	if FS:directoryExists('/temp/beammp/locales/') then
		local zip = ZipArchive()
		local fileList = FS:findFiles('/temp/beammp/locales/', '*.json', 0)
		zip:openArchiveName('temp/beammp/beammp_locales_and_defaults.zip', 'w')
		for _, file in pairs(fileList) do
			zip:addFile(file, 'locales/'..file:gsub('/temp/beammp/locales/', ''))
		end
		
		zip:addFile('/temp/beammp/settings/defaults.json', 'settings/defaults.json')
		zip:close()
	end
	FS:mount('/temp/beammp/beammp_locales_and_defaults.zip')
	FS:directoryRemove('/temp/beammp/locales')
	FS:directoryRemove('/temp/beammp/settings')
end

--- Check if a mod is allowed according to the servers mods
-- @param modName string The mod in question to check
-- @return boolean
-- @usage MPModManager.isModAllowed('...')
local function isModAllowed(modName)
	for _,v in pairs(serverMods) do -- checking for server mods
		if string.lower(v) == string.lower(modName) then --[[ log('M', 'isModAllowed', modName .. ' is allowed.') ]] return true end
	end
	--log('W', 'isModAllowed', modName .. ' is not allowed.')
	return false
end

--- Check if a mod is whitelisted according to BeamMP core set E.g. itself, BeamMP.
-- @param modName string The mod in question to check
-- @return boolean
-- @usage MPModManager.isModWhitelisted('...')
local function isModWhitelisted(modName)
	for _,v in pairs(whitelist) do
		if string.lower(v) == string.lower(modName) then --[[log('M', 'isModWhitelisted', modName .. ' is whitelisted.')]] return true end
	end
	return false
end

--- Check if a mod is allowed (Calls isModAllowed and isModWhitelist)
-- If it is now allowed we disable it, if it is in the multiplayer folder we also delete it as this is maintained by BeamMP
-- @param mod table The mod in question to check
-- @usage MPModManager.isModAllowed('...')
local function checkMod(mod) --TODO: might have a flaw with repo mods as their name is the repo ID and not the zip name
	--log('M', 'checkMod', 'Checking mod.modname: '..mod.modname)
	local modname = mod.modname
	local modAllowed = isModAllowed(modname)
	local modWhitelisted = isModWhitelisted(modname)

	if modWhitelisted then return end -- don't do anything with whitelisted mods

	if not modAllowed and mod.active then
		log('W', 'checkMod', "This mod should not be running: "..modname)
		core_modmanager.deactivateMod(modname)
		if mod.dirname == '/mods/multiplayer/' then
			core_modmanager.deleteMod(modname)
		end
	elseif modAllowed and not mod.active then
		log('W', 'checkMod', 'Inactive Mod but Should be Active: '..modname)
		core_modmanager.activateMod(modname)--'/mods/'..string.lower(v)..'.zip')
	elseif modAllowed and mod.active then
		log('M', 'checkMod', modname..' is already active. Not doing anything.')
	else
		--log('M', 'checkMod', modname..' is none of the above.')
	end
end

--- BeamNG function from extensions/core/modmanager.lua
-- @param path string The raw mod file path
-- @return string modname The cleaned modname from the mod file path
local function getModNameFromPath(path) 
	local modname = string.lower(path)
	modname = modname:gsub('/mods/', '')
	modname = modname:gsub('repo/', '')
	modname = modname:gsub('unpacked/', '')
	modname = modname:gsub('/', '')
	modname = modname:gsub('.zip$', '')
	return modname
end

--- The mods json object which the game manages.
-- @return table mods The mods according to the game managed db
local function getModList()
	local modsDB = jsonReadFile("mods/db.json")
	return modsDB.mods
end

local waitForFilesChanged = false

--- Check the game mod list against BeamMP's expected
local function checkAllMods() --add counters?
	log('M', 'checkAllMods', 'Checking all mods...')
	for modname, mod in pairs(getModList()) do
		checkMod(mod)
	end
end

--- Load the Servers mods, these are put in by the BeamMP Launcher
local function loadServerMods()
	log('W', 'loadServerMods', 'loadServerMods')
	
	local modsDir = FS:findFiles("/mods/multiplayer", "*.zip", -1, false, false)
	for _, modPath in pairs(modsDir) do
		core_modmanager.workOffChangedMod(modPath, 'added')
	end
	checkAllMods()
	MPCoreNetwork.requestMap()
end

--- Verify that the servers mods have been loaded by the game.
-- Currently not properly functioning / missing functionality
local function verifyMods() --TODO: improve and actually implement this
	local verifyTable = {}
	for _,v in pairs(serverMods) do
		verifyTable[v] = false
	end
	for _,v in pairs(getModList()) do
		for _,n in pairs(serverMods) do
			if v.modname == n then verifyTable[n] = true end
		end
	end
end

--- Cleanup the mods from the ended session ready for another.
local function cleanUpSessionMods()
	log('M', "cleanUpSessionMods", "Deleting all multiplayer mods")
	local count = 0
	for modname, mod in pairs(getModList()) do
		if mod.dirname == "/mods/multiplayer/" and modname ~= "multiplayerbeammp" then
			hasMods = true
			count = count + 1
			core_modmanager.deleteMod(modname)
		end
	end
	log('M', "cleanUpSessionMods", count.." Mods cleaned up")
	log('M', "cleanUpSessionMods", "Unloading extensions...")
	--dump(getModList())
	-- TODO: Need to find an alternative for this...
	--unloadGameModules()
end

--- Set the servers mods as a string in Lua for loading and checking
-- Called from MPCoreNetwork
-- @param modsString string The mod string from the server
-- @usage MPModManager.setServerMods('...')
local function setServerMods(modsString) 
	if modsString == "" then log('M', 'setServerMods', 'Received no mods.') return end
	log('W', 'setMods', modsString)
	local mods = {}
	if (modsString) then -- takes: mod1.zip;mod2.zip;mod3.zip, returns a table of mod1,mod2,mod3
		for mod in string.gmatch(modsString, "([^;]+)") do
			local modFileName = mod:gsub(".zip",""):gsub(";","")
			table.insert(mods, modFileName)
		end
	end
	log('M', 'setServerMods', 'Server Mods set to: ' .. dumps(mods))
	for key, modName in pairs(mods) do -- mods in a directory deeper than /mods/ have "<directory name> + modname" as their mod name
		mods[key] = string.lower('multiplayer'..modName)
	end
	serverMods = mods
end

--- A BeamNG event that is called when a mod is loaded by the games mod manager
-- @param mod table The loaded mod information
local function onModActivated(mod)
	log('M', 'onModActivated', mod.modname)
	if MPCoreNetwork.isMPSession() then
		checkMod(mod)
	end
end


local original_registerCoreModule

--- This prevents mods from registering extensions as core modules, which don't get unloaded without a lua reload
local function extensionLoader()
	original_registerCoreModule = registerCoreModule
	registerCoreModule = function(modulePath)
		--log('M', 'extensionLoader', modulePath)
		local debug = debug.getinfo(2)
		--dump(debug)
		debug = string.lower(debug.source)
		if string.match(debug, "beammp") then
			--log('W', 'extensionLoader', "Source is BeamMP! ".. debug)
		original_registerCoreModule(modulePath)
		elseif string.match(debug, "modscript") then
			log('W', 'extensionLoader', "Modscript attempting to register a core module! Falling back to setExtensionUnloadMode(arg, \"auto\") " .. debug)
			extensionName = extensions.luaPathToExtName(modulePath)
			setExtensionUnloadMode(extensionName, "auto")
		else
			log('W', 'extensionLoader', "Source is not BeamMP or a modscript, running original function! " .. debug)
			original_registerCoreModule(modulePath)
		end
	end
end

local original_Unsubscribe

M.repositoryReplacer = function() --TODO: if this function is called onExtensionLoaded core_repository is not loaded yet at that time
	if not core_repository and not core_repository.modUnsubscribe then log('W', 'repositoryReplacer', 'core_repository not loaded yet') return end
	original_Unsubscribe = core_repository.modUnsubscribe
	core_repository.modUnsubscribe = function(mod_id)
		if MPCoreNetwork and MPCoreNetwork.isMPSession() then
			log('W', 'replaceStuff', 'mod_id: ' .. mod_id)
			for k,modName in pairs(serverMods) do
				if modName == mod_id then
					log('W', 'repositoryReplacer', 'You cannot remove session mods! Quit the multiplayer session to remove mods.')
					return
				else
					original_Unsubscribe(mod_id)
				end
			end
		else
			original_Unsubscribe(mod_id)
		end
	end
end

--- Triggered by BeamNG when the lua mod is loaded by the modmanager system.
-- We use this to load our locales, cleanup the mods ahead of mp use and ensure our modloader is used
local function onExtensionLoaded()
	loadLocalesAndDefaults()
	cleanUpSessionMods()
	--extensionLoader()
	--M.replaceStuff()
end

--- Triggered by BeamNG when the lua mod is unloaded by the modmanager system.
-- We use this to cleanup our locales and restore core module defintions
local function onExtensionUnloaded() -- restore functions back to their default values
	unloadLocalesAndDefaults()
	--registerCoreModule = original_registerCoreModule and original_registerCoreModule
	if core_repository then core_repository.modUnsubscribe = original_Unsubscribe and original_Unsubscribe end
end

--- This is used to ensure the cleanup of the mods from the mod manager is done at the end of the session.
local function onServerLeave()
	if MPCoreNetwork.isMPSession() or MPCoreNetwork.isGoingMPSession() then
		log('W', 'onServerLeave', 'MPModManager')
		serverMods = {}
		cleanUpSessionMods() -- removes any leftover session mods
	end
end

local requestLuaReload = false

--- Reload lua but with a 0.5 second delay to allow other states to refresh
local function reloadLuaReloadWithDelay()
	if hasMods then -- don't reload if server doesn't contain mods
		requestLuaReload = true
	end
end
local reloadTimer = 0

--- onUpdate is a game eventloop function. It is called each frame by the game engine.
-- @param dt float
local function onUpdate(dt)
	if requestLuaReload then
		reloadTimer = reloadTimer + dt
		if reloadTimer >= 0.5 then Lua:requestReload() end
	end
end

M.reloadLuaReloadWithDelay = reloadLuaReloadWithDelay
M.cleanUpSessionMods = cleanUpSessionMods
M.isModWhitelisted = isModWhitelisted
M.loadServerMods = loadServerMods
M.setServerMods = setServerMods
M.checkAllMods = checkAllMods
M.isModAllowed = isModAllowed
M.getModList = getModList
M.verifyMods = verifyMods
--events
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onModActivated = onModActivated
M.onServerLeave = onServerLeave
M.onExit = cleanUpSessionMods
M.onUpdate = onUpdate
M.onInit = function() setExtensionUnloadMode(M, "manual") end

return M
