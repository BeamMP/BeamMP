--====================================================================================
-- All work by Titch2000 and jojos38.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading MPModManager...")

local serverMods = {} -- multiplayerModName1, multiplayerModName2
local whitelist = {"multiplayerbeammp", "beammp", "translations"} -- these mods won't be activated or deactivated

--TODO: for some reason all mods get activated sometimes, look into it
--TODO: build handler for repo mod downloads

local function isModAllowed(modName)
	for k,v in pairs(serverMods) do -- checking for server mods
		if string.lower(v) == string.lower(modName) then --[[ log('M', 'isModAllowed', modName .. ' is allowed.') ]] return true end
	end
	--log('W', 'isModAllowed', modName .. ' is not allowed.')
	return false
end
local function isModWhitelisted(modName)
	for k,v in pairs(whitelist) do
		if string.lower(v) == string.lower(modName) then --[[log('M', 'isModWhitelisted', modName .. ' is whitelisted.')]] return true end
	end
	return false
end
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
		MPCoreNetwork.modLoaded(modname)
	elseif modAllowed and mod.active then
		log('M', 'checkMod', modname..' is already active. Not doing anything.')
		MPCoreNetwork.modLoaded(modname)
	else
		--log('M', 'checkMod', modname..' is none of the above.')
	end
end

local function getModNameFromPath(path) --BeamNG function from extensions/core/modmanager.lua
	local modname = string.lower(path)
	modname = modname:gsub('/mods/', '')
	modname = modname:gsub('repo/', '')
	modname = modname:gsub('unpacked/', '')
	modname = modname:gsub('/', '')
	modname = modname:gsub('.zip$', '')
	--log('I', 'getModNameFromPath', "getModNameFromPath path = "..path .."    name = "..dumps(modname) )
	return modname
end

local function getModList()
	local modList = {}
	local zipfileList = FS:findFiles("/mods/", "*.zip", -1, false, false)
	local unpackedList = FS:findFiles("/mods/unpacked/", "*", 0, false, true)
	for key, modPath in pairs(zipfileList) do --key = index, modPath = "/mods/mod.zip"
		log('I', 'getModList', 'modPath: '..modPath)
		local modName = getModNameFromPath(modPath)
		modList[modName] = core_modmanager.getModDB(modName)
	end
	for key, modPath in pairs(unpackedList) do --key = index, modPath = "/unpacked/mod"
		log('I', 'getModList', 'modPath: '..modPath)
		local modName = getModNameFromPath(modPath)
		modList[modName] = core_modmanager.getModDB(modName)
	end
	return modList
end

local function checkAllMods() --add counters?
	log('M', 'checkAllMods', 'Checking all mods...')
	core_modmanager.initDB()
	for modname, mod in pairs(getModList()) do
		--log('M', 'checkAllMods', 'modname: '..modname)
		--log('M', 'checkAllMods', 'mod.modname: '..mod.modname)
		checkMod(mod)
	end
end

M.verifyMods = function() -- verify that all server mods have actually been modLoaded
	local verifyTable = {}
	for k,v in pairs(serverMods) do
		verifyTable[v] = false -- set all values to false
	end
	for k,v in pairs(getModList()) do --go through the mod list
		for m,n in pairs(serverMods) do --check against the mods that are supposed to be loaded
			if v.modname == n then verifyTable[n] = true end
		end
	end
	dump(verifyTable)
	for k,v in pairs(verifyTable) do
		if v == true then return true end
	end
end


local function cleanUpSessionMods() --TODO: remove? currently unused
	log('M', "cleanUpSessionMods", "Deleting all multiplayer mods")
	local modsDB = jsonReadFile("mods/db.json")
	if modsDB then
		local modsFound = false
		local count = 0
		for modname, mod in pairs(modsDB.mods) do
			if mod.dirname == "/mods/multiplayer/" and modname ~= "multiplayerbeammp" then
				count = count + 1
				core_modmanager.deactivateMod(modname)
				core_modmanager.deleteMod(modname)
				modsFound = true
			end
		end
		log('M', "cleanUpSessionMods", count.." Mods cleaned up")
		log('M', "cleanUpSessionMods", "Unloading extensions...")
		unloadGameModules()
	end
end


local function setServerMods(modsString) -- called from MPCoreNetwork
	
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

local function onModActivated(mod)
	log('M', 'onModActivated', mod.modname)
	if MPCoreNetwork.isMPSession() then
		checkMod(mod)
	end
end

local autoMountDisabled = false
local function startModLoading()
	if not autoMountDisabled then
		log('W',"startModLoading", "Starting mod loading process, disabling automount")
		core_modmanager.disableAutoMount()
		autoMountDisabled = true
	end
end

local original_registerCoreModule = nop

local function replaceFunction()
	original_registerCoreModule = registerCoreModule
	registerCoreModule = function(modulePath)
		log('M', 'replaceFunction', modulePath)
		local debug = debug.getinfo(2)
		--dump(debug)
		debug = string.lower(debug.source)
		if string.match(debug, "beammp") then
			--log('W', 'replaceFunction', "Source is BeamMP! ".. debug)
		original_registerCoreModule(modulePath)
		elseif string.match(debug, "modscript") then
			log('W', 'replaceFunction', "Modscript attempting to register a core module! Falling back to queueExtensionToLoad " .. debug)
			queueExtensionToLoad(modulePath)
		else
			log('W', 'replaceFunction', "Source is not BeamMP or a modscript, running original function! ".. debug)
			original_registerCoreModule(modulePath)
		end
	end
end

local original_Unsubscribe = nop --TODO: finish this

M.replaceStuff = function()
	if not core_repository and not core_repository.modUnsubscribe then log('W', 'replaceStuff', 'Function does not exist!') return end
	original_Unsubscribe = core_repository.modUnsubscribe
	core_repository.modUnsubscribe = function(mod_id)
		if MPCoreNetwork and MPCoreNetwork.isMPSession() then
			log('W', 'replaceStuff', 'mod_id: ' .. mod_id)
			for k,modName in pairs(serverMods) do
				if modName == mod_id then
					log('W', 'replaceStuff', 'You cannot remove session mods! Exit the session to remove mods.')
					return
				else
					log('M', 'replaceStuff', 'Not a session mod, running original function.')
					original_Unsubscribe(mod_id)
				end
			end
		else
			log('M', 'replaceStuff', 'Not in an MP session, running original function.')
			original_Unsubscribe(mod_id)
		end
	end
end

M.onExtensionLoaded = function() --TODO: core_repository doensnt seem to be loaded at the time that these functions run after a lua reload
	--replaceFunction()
	--M.replaceStuff()
end

M.onExtensionUnloaded = function() -- restore functions back to their default values
	--core_repository.modUnsubscribe = original_Unsubscribe
	--registerCoreModule = original_registerCoreModule
end

M.onServerLeave = function() --TODO: cleaning up after a session
	log('W', 'onServerLeave', 'MPModManager')
	serverMods = {}
	checkAllMods() -- removes any leftover session mods
	unloadGameModules() --unload extensions
	core_modmanager.enableAutoMount() -- re-enable auto-mount
end

M.onSerialize = function()
	return serverMods
end

M.onDeserialized = function(data)
	log('W', 'onDeserialized', dumps(data))
	serverMods = data
end

M.cleanUpSessionMods = cleanUpSessionMods
M.setServerMods = setServerMods
M.checkAllMods = checkAllMods
M.isModWhitelisted = isModWhitelisted
M.isModAllowed = isModAllowed
M.onModActivated = onModActivated
M.startModLoading = startModLoading

M.getModList = getModList

print("MPModManager loaded")
return M
