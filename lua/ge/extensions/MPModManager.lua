--====================================================================================
-- All work by Titch2000 and jojos38.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading MPModManager...")

local serverMods = {}
local whitelist = {"multiplayerbeammp", "beammp"}


local function IsModAllowed(n)
	for k,v in pairs(whitelist) do -- checking for beammp
		if string.lower(v) == string.lower(n) then
			return true
		end
	end
	for k,v in pairs(serverMods) do -- checking for server mods
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
		if mod.dirname == '/mods/multiplayer/' then
			core_modmanager.deleteMod(modname)
		end
	elseif modAllowed then
		print("Inactive Mod but Should be Active: "..modname)
		core_modmanager.activateMod(modname)--'/mods/'..string.lower(v)..'.zip')
		MPCoreNetwork.modLoaded(modname)
	end
end

local function getModList()
	for k,v in pairs(FS:findFiles( "/mods/", "*.zip", -1)) do
		core_modmanager.getModForFilename(v)
	end
end

local function checkAllMods()
	for modname, mod in pairs(getModList()) do
		log('M', 'checkAllMods', 'Checking mod '..mod.modname)
		checkMod(mod)
	end
end



local function cleanUpSessionMods() --TODO: find a way to unload GE Core extensions without reloading Lua
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
			--if modsFound then Lua:requestReload() end -- reload Lua to make sure we don't have any leftover GE files
			--Lua:requestReload() -- reloads lua every time so chat doesn't duplicate
	end
end


local function setServerMods(receivedMods)
	log('M', 'setServerMods', 'Server Mods set to: ' .. dumps(receivedMods))
	serverMods = receivedMods
	for k,v in pairs(serverMods) do
		serverMods[k] = 'multiplayer'..v
	end
end



local function showServerMods()
	print(serverMods)
	dump(serverMods)
end


M.cleanUpSessionMods = cleanUpSessionMods
M.showServerMods = showServerMods
M.setServerMods = setServerMods
M.checkAllMods = checkAllMods

M.getModList = getModList

print("MPModManager loaded")
return M
