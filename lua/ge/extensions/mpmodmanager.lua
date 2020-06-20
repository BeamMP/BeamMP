local M = {}
print("mpmodmanager Initialising...")

-- TRY CATCH FROM: https://gist.github.com/cwarden/1207556/a3c7caa194cad0c22871ac650159b40a88ecd702
function catch(what)
   return what[1]
end

function try(what)
   local status, result = pcall(what[1])
   if not status then
      what[2](result)
   end
   return result
end

local timer = 0

local mods = {
  "beammp",
  "BeamMP",
}

local serverMods = {}

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
    core_modmanager.deleteMod(string.lower(v))
  end
end

local function onUpdate(dt)
  if timer >= 1 then
    timer = 0
    print("Checking Mods...")
    try {
       function()
         for modname,mdata in pairs(core_modmanager.getModList()) do
           if mdata.active then
             print("Active Mod:"..modname)
             if not IsModAllowed(modname) then
               -- This mod is not allowed to be running
               print("This mod should not be running: "..modname)
               core_modmanager.deactivateMod(modname)
               core_modmanager.deleteMod(modname)
             end
           else -- The mod is not active but lets check if it should be
             if IsModAllowed(modname) then
               print("Inactive Mod but Should be Active:"..modname)
               core_modmanager.activateMod(string.lower(modname))--'/mods/'..string.lower(v)..'.zip')
             end
           end
         end
       end,

       catch {
          function(error)
             print('caught error: ' .. error)
             if string.match(error, "(a nil value)") and string.match(error, "getModList") then
               print("Time to reload lua as our custom mod manager was not loaded.")
               Lua:requestReload()
             end
          end
       }
    }
  end
  timer = timer + dt
end

local function modCheck(dt)
  print("Checking Mods...")
  for modname,mdata in pairs(core_modmanager.getModList()) do
    if modname == "kjp12_awd_t-series" then--mdata.active then
      print(modname)
      dump(mdata)
      if not IsModAllowed(modname) then
        -- This mod is not allowed to be running
        print("This mod should not be running: "..modname)
        --core_modmanager.deactivateMod(modname)
      end
    end
  end
  setServerMods({})
end

local function setServerMods(mods)
  print("Server Mods Set:")
  dump(mods)
  serverMods = mods
end

local function showServerMods()
  print(serverMods)
  dump(serverMods)
end

M.onUpdate = onUpdate
M.cleanUpSessionMods = cleanUpSessionMods
M.showServerMods = showServerMods
M.modCheck = modCheck
M.setServerMods = setServerMods

print("mpmodmanager Loaded.")
return M
