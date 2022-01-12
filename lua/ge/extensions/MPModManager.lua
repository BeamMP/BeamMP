--====================================================================================
-- All work by Titch2000 and jojos38.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading MPModManager...")



local timer = 0
local serverMods = {}
local mods = {"multiplayerbeammp", "beammp"}
local backupAllowed = true



local function IsModAllowed(n)
	for k,v in pairs(mods) do
		if string.lower(v) == string.lower(n) then
			return true
		end
	end
	for k,v in pairs(serverMods) do
		if string.lower(v) == string.lower(n) then
			return true
		end
	end
	return false
end



local function checkMod(mod)
	local modname = mod.modname
	local modAllowed = IsModAllowed(modname)
	if not modAllowed and mod.active then -- This mod is not allowed to be running
		log('W', 'checkMod', "This mod should not be running: "..modname)
		core_modmanager.deactivateMod(modname)
		if mods.dirname == '/mods/multiplayer/' then
			core_modmanager.deleteMod(modname)
		end
	elseif modAllowed then
		if mod.active then -- this mod just got enabled for MP, run modscript
			--dump(mod)
			local dir, basefilename, ext = path.splitWithoutExt(mod.fullpath)
			--dump(path.splitWithoutExt(mod.fullpath))

			local modscriptpath = "/scripts/"..basefilename.."/modScript.lua"
			--print(mod.filename)
			log('I', 'checkMod', "Loaded  " .. basefilename)
			
			
			local f = io.open(modscriptpath, "r")
			if f == nil or not io.close(f) then print(modscriptpath.." cant be opened") return end -- modscript file not found
			
			local status, ret = pcall(dofile, modscriptpath)
			if not status then
				log('E', 'initDB.modScript', 'Failed to execute ' .. modscriptpath)
				log('E', 'initDB.modScript', dumps(ret))
			else
				log('I', 'checkMod', "Ran modscript ("..modscriptpath..")")
				loadCoreExtensions()
			end
		else
			print("Inactive Mod but Should be Active: "..modname)
			core_modmanager.activateMod(modname)--'/mods/'..string.lower(v)..'.zip')
			MPCoreNetwork.modLoaded(modname)
		end
	end
end



local function checkAllMods()
	for modname, mod in pairs(core_modmanager.getModList()) do
		print("Checking mod "..mod.modname)
		checkMod(mod)
	end
end



local function cleanUpSessionMods()
	log('M', "cleanUpSessionMods", "Deleting all multiplayer mods")
	local modsDB = jsonReadFile("mods/db.json")
	if modsDB then
			backupAllowed = false
			local modsFound = false
			local count = 0
			for modname, mod in pairs(modsDB.mods) do
					if mod.dirname == "/mods/multiplayer/" and modname ~= "multiplayerbeammp" then
							count = count + 1
							core_modmanager.deleteMod(modname)
							modsFound = true
					end
			end
			backupAllowed = true
			log('M', "cleanUpSessionMods", count.." Mods cleaned up")
			if modsFound then Lua:requestReload() end -- reload Lua to make sure we don't have any leftover GE files
	end
end



local function setServerMods(receivedMods)
	print("Server Mods Set:")
	dump(mods)
	serverMods = receivedMods
	for k,v in pairs(serverMods) do
		serverMods[k] = 'multiplayer'..v
	end
end



local function showServerMods()
	print(serverMods)
	dump(serverMods)
end



local function backupLoadedMods()
	-- Backup the current mods before joining the server
	local modsDB = jsonReadFile("mods/db.json")
	if modsDB then
		os.remove("settings/db-backup.json")
		jsonWriteFile("settings/db-backup.json", modsDB, true)
		print("Backed up db.json file")
	else
		print("No db.json file found")
	end
end



local function restoreLoadedMods()
	-- Backup the current mods before joining the server
	local modsDBBackup = jsonReadFile("settings/db-backup.json")
	if modsDBBackup then
		os.remove("mods/db.json")
		jsonWriteFile("mods/db.json", modsDBBackup, true)
		-- And delete the backup file because we don't need it anymore
		os.remove("settings/db-backup.json")
		print("Restored db.json backup")
	else
		print("No db.json backup found")
	end
end



-- Called from beammp\lua\ge\extensions\core
local function onModStateChanged(mod)
	-- The function makes two calls, one with a table and one with the mod name
	-- We only want the table not the mod name call
	if type(mod) ~= "table" then return end
	if MPCoreNetwork.isGoingMPSession() or MPCoreNetwork.isMPSession() then
		checkMod(mod)
	end
end



local function onInit()
	-- When the game inits we restore the db.json which deletes it and then back it up.
	-- If the game was closed correctly, there should be no db-backup.json file which mean
	-- that restoreLoadedMods won't do anything. Therefor not restoring a wrong backup
	restoreLoadedMods()
	backupLoadedMods()
end



local function onExit() -- Called when the user exits the game
	restoreLoadedMods() -- Restore the mods and delete db-backup.json when we quit the game
	-- Don't add isMPSession checking because onClientEndMission is called before!
end



local function onClientStartMission(mission)
	if MPCoreNetwork.isMPSession() then
		checkAllMods() -- Checking all the mods
	end
	-- Checking all the mods again because BeamNG.drive have a bug with mods not deactivating
end



local function onClientEndMission(mission)
	-- We restore the db.json before lua reloads because on reload the db.json get backup up
	-- if we were connected to a server this would cause a backup of the db.json with all mods disabled
	-- By doing this, lua activate itself the mods after the reload so we don't even need
	-- to enable the mods ourself.
	restoreLoadedMods()
end



local function modsDatabaseChanged()
	if not MPCoreNetwork.isMPSession() then
		backupLoadedMods()
	end
end



M.modsDatabaseChanged = modsDatabaseChanged
M.onClientEndMission = onClientEndMission
M.onClientStartMission = onClientStartMission
M.modsDatabaseChanged = modsDatabaseChanged
M.onModStateChanged = onModStateChanged
M.backupLoadedMods = backupLoadedMods
M.restoreLoadedMods = restoreLoadedMods
M.cleanUpSessionMods = cleanUpSessionMods
M.showServerMods = showServerMods
M.setServerMods = setServerMods
M.checkAllMods = checkAllMods
M.onExit = onExit
M.onInit = onInit



print("MPModManager loaded")
return M
