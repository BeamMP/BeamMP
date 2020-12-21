--====================================================================================
-- All work by Titch2000 and jojos38.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}
print("MPModManager initialising...")



local timer = 0
local serverMods = {}
local mods = {"multiplayerbeammp", "beammp"}



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
end



local function cleanUpSessionMods()
	for k,v in pairs(serverMods) do
		core_modmanager.deactivateMod(string.lower(v))
		if string.match(string.lower(v), 'multiplayer') then
			core_modmanager.deleteMod(string.lower(v))
		end
	end
	Lua:requestReload() -- reload Lua to make sure we don't have any leftover GE files
end



local function onUpdate(dt)
	if timer >= 2 and MPCoreNetwork.isGoingMPSession() then -- Checking mods every 2 seconds
		timer = 0
		for modname,mdata in pairs(core_modmanager.getModList()) do		
			local modAllowed = IsModAllowed(modname)
			if not modAllowed and mdata.active then -- This mod is not allowed to be running
				print("This mod should not be running: "..modname)
				core_modmanager.deactivateMod(modname)
				if string.match(string.lower(modname), 'multiplayer') then
					core_modmanager.deleteMod(string.lower(modname))
				end
			elseif modAllowed and not mdata.active then
				print("Inactive Mod but Should be Active: "..modname)
				core_modmanager.activateMod(string.lower(modname))--'/mods/'..string.lower(v)..'.zip')
				MPCoreNetwork.modLoaded(modname)
			end
		end
	end
	timer = timer + dt
end



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



M.onUpdate = onUpdate
M.cleanUpSessionMods = cleanUpSessionMods
M.showServerMods = showServerMods
M.setServerMods = setServerMods



return M
