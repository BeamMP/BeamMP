--====================================================================================
-- All work by Titch2000 and jojos38.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}
print("MPModManager initialising...")



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
		print("This mod should not be running: "..modname)
		core_modmanager.deactivateMod(modname)
		if string.match(string.lower(modname), 'multiplayer') then
			core_modmanager.deleteMod(modname)
		end
	elseif modAllowed and not mod.active then
		print("Inactive Mod but Should be Active: "..modname)
		core_modmanager.activateMod(modname)--'/mods/'..string.lower(v)..'.zip')
		MPCoreNetwork.modLoaded(modname)
	end
end



local function checkAllMods()
	for modname, mod in pairs(core_modmanager.getModList()) do
		checkMod(mod)
		print("Checking mod "..mod.modname)
	end
end



local function cleanUpSessionMods()
	backupAllowed = false -- Disable mods backup so it doesn't overwrite the file
	for k,v in pairs(serverMods) do
		core_modmanager.deactivateMod(string.lower(v))
		if string.match(string.lower(v), 'multiplayer') then
			core_modmanager.deleteMod(string.lower(v))
		end
	end
	backupAllowed = true
	Lua:requestReload() -- reload Lua to make sure we don't have any leftover GE files
end



--[[local function onUpdate(dt)
	if timer >= 5 and MPCoreNetwork.isGoingMPSession() then -- Checking mods every 2 seconds
		timer = 0
		--checkAllMods()
	end
	timer = timer + dt
end--]]



local function setServerMods(mods)
	print("Server Mods Set:")
	dump(mods)
	serverMods = mods
	for k,v in pairs(serverMods) do
		serverMods[k] = 'multiplayer'..v
	end
	print("Converted Server Mods Set:")
	dump(serverMods)
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
		jsonWriteFile("settings/db-backup.json", modsDB)
		print("Backed up db.json file")
	else
		print("No db.json file found")
	end
end


local function onModChanged(mod)
	if type(mod) ~= "table" then return end
	if MPCoreNetwork.isGoingMPSession() or MPCoreNetwork.isMPSession() then
		checkMod(mod)
	else
		if backupAllowed then backupLoadedMods() end
	end
end



-- Called from beammp\lua\ge\extensions\core
local function onModActivated(mod)
	onModChanged(mod)
end



-- Called from beammp\lua\ge\extensions\core
local function onModDeactivated(mod)
	onModChanged(mod)
end



local function onModManagerReady()
	-- Restore the current mods before joining the server
	local modsDBBackup = jsonReadFile("settings/db-backup.json")
	if modsDBBackup then
		jsonWriteFile("mods/db.json", modsDBBackup)
		--[[print("Restored db.json backup")
		for modname, mod in pairs(modsDBBackup.mods) do
			if mod.active then
				core_modmanager.activateMod(string.lower(modname))
			else
				core_modmanager.deactivateMod(string.lower(modname))
			end
		end--]]
	else
		print("No db.json backup found")
	end
end



M.onModManagerReady = onModManagerReady
M.backupLoadedMods = backupLoadedMods
M.checkAllMods = checkAllMods
M.onModActivated = onModActivated
M.onModDeactivated = onModDeactivated
--M.onUpdate = onUpdate
M.cleanUpSessionMods = cleanUpSessionMods
M.showServerMods = showServerMods
M.setServerMods = setServerMods



return M
