-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local ready = nil

local persistencyfile = 'mods/db.json'

local mods = {}
local dbHeader = {}
local modeDef = {
  vehicle= {
    has= {'%.jbeam', 'vehicles/'},
    mountPoint= 'vehicles/'
  },
  terrain= {
    has= {'%.mis', "main.level.json", "main"},
    mountPoint= 'levels/'
  },
  app= {
    has= {'ui/'}
  },
  scenario= {
    has= {'scenarios/'},
    hasnt= {'%.mis'}
  },
  sound= {
    has= {'%.sbeam'},
    hasnt= {'%.jbeam', '%.mis'}
  }
}
local checkStartup = false
local checkingModUpdate = false
local autoMount = true
local modDisabledCheckedOnce = false

local function sendGUIState()
  --local list = {}
  --for k, v in pairs(mods) do
  --  table.insert(list, v)
  --end
  --guihooks.trigger('ModManagerModsChanged', list)

  local vehicles = {}

  local files = FS:findFiles('/vehicles/', '*', 0, true, true)
  for _, path in ipairs(files) do
    if string.startswith(path, "/vehicles/") and not string.startswith(path, "/vehicles/mod_info") then
    vehicles[string.sub(path, 20)] = 1
    end
  end
  vehicles = tableKeys(vehicles)

  guihooks.trigger('ModManagerModsChanged', mods)
  guihooks.trigger('ModManagerVehiclesChanged', vehicles)

  extensions.core_levels.requestData() -- send levels to the UI
end

local function stateChanged()
  -- send new state to gui: as a list
  sendGUIState()

  -- and save it to disc (if not in safe mode)
  if not isSafeMode() then
    jsonWriteFile(persistencyfile, { header = dbHeader, mods = mods}, true)
	if MPModManager then MPModManager.modsDatabaseChanged() end-- ///////////////////////////////////////////////////////////// BEAMMP
  end
end

-- this mounts a zipfile to the correct place (backward compatibility)
local function addMountEntryToList(list, filename, mountPoint)
  local entry = {}
  entry.srcPath = filename
  entry.mountPath = mountPoint
  table.insert(list, entry)
end

local function openEntryInExplorer(filename)
  if not mods[filename] then return end

  if mods[filename].unpackedPath then
    Engine.Platform.exploreFolder(mods[filename].unpackedPath)
  end
end

local function mountEntry(filename, mountPoint)
  extensions.hook('onBeforeMountEntry', filename, mountPoint)
  local mountList = {}
  addMountEntryToList( mountList, filename, mountPoint )
  if not FS:mountList(mountList) then
    guihooks.trigger('modmanagerError', 'Error mounting mods')
    log('E', 'mountEntry', 'mountList Error')
  end
end

local function getModNameFromPath(path)
  local modname = string.lower(path)
  modname = modname:gsub('dir:/', '') --should have been killed by now
  modname = modname:gsub('/mods/', '')
  modname = modname:gsub('repo/', '')
  modname = modname:gsub('unpacked/', '')
  modname = modname:gsub('/', '')
  modname = modname:gsub('.zip$', '')
  --log('I', 'getModNameFromPath', "getModNameFromPath path = "..path .."    name = "..dumps(modname) )
  return modname
end

local function getModFromPath(vfsPath, withHashes)
  local realPath = FS:findOverrides(vfsPath) or {}
  for _, p in ipairs(realPath) do
    p = string.lower(p:gsub('\\', '/'))
    local _, filename, ext = path.splitWithoutExt(p)
    local mod = mods[filename]
    if mod then
      return mod.modID or mod.modname
    end
  end
end

-- checks the type of a mod based on the existing files
-- should be replaced be info comming from the mod as soon as that is available
local function checkType (files)
  local couldBe = {}
  local cannotBe = {}
  local needsMountPoint = {}

  for _, v in pairs(files) do
    for k2, v2 in pairs(modeDef) do
      if v2.has and not couldBe[k2] then
        for _, v3 in pairs(v2.has) do
          if v:find(v3) then
            couldBe[k2] = true
            if v2.mountPoint ~= nil and not v:find(v2.mountPoint) then
              needsMountPoint[k2] = v2.mountPoint
            end
          end
        end
      end

      if v2.hasnt and not cannotBe[k2] then
        for _, v3 in pairs(v2.hasnt) do
          if v:find(v3) then
            cannotBe[k2] = true
          end
        end
      end
    end
  end

  for k, _ in pairs(couldBe) do
    if cannotBe[k] then
      cannotBe[k] = nil
      couldBe[k] = nil
    end
  end

  local keys = tableKeys(couldBe)
  if tableSize(keys) == 1 then
    if needsMountPoint[keys[1]] then
      return {key = keys[1], mountPoint = needsMountPoint[keys[1]]}
    else
      return {key = keys[1]}
    end
  else
    return {key = 'unknown'}
  end
end

local function modsOwnFile(modname,filepath)
  if mods[modname].modData == nil or mods[modname].modData.hashes == nil then return false end
  for k,v in pairs(mods[modname].modData.hashes) do
    v[1] = v[1]:gsub("\\/","/")
    if v[1] == filepath then
      return true
    end
  end
  return false
end

local function checkMod(modname)
  if modname == nil or mods[modname] == nil then return nil end
  --if not FS:isMounted(mods[modname].fullpath) then log('D', 'checkMod', "Mods "..modname.." isn't mounted yet"); return nil end
  mods[modname].valid = true
  if mods[modname].modData.hashes then
    local hashes = mods[modname].modData.hashes
    for k,v in pairs(hashes) do
      v[1] = v[1]:gsub("\\/","/")
      if FS:fileExists(v[1]) then
        local hash = FS:hashFile(v[1])
        if hash ~= v[2] then
          log('E', 'checkMod', "Mods "..modname.. " have a wrong file : "..v[1].. "  original Hash="..v[2].."  Current Hash="..hash)
          mods[modname].valid = false
        end
      else
          log('E', 'checkMod', "Mods "..modname.. " have a missing file : "..v[1])
          mods[modname].valid = false
      end
    end
  else
    log('E', 'checkMod', "Mods "..modname.. " doesn't have hash manifest")
    mods[modname].valid = false
  end

  local vehiculesTest =false
  local vehName =""
  mods[modname].conflict = {}
  if mods[modname].modData.hashes ~= nil then
    for k,v in pairs(mods[modname].modData.hashes) do
      v[1] = v[1]:gsub("\\/","/")
      if v[1]:match("vehicles/[%w]+") ~= nil and not vehiculesTest then
        vehName =v[1]:match("vehicles/([%w]+)")
        vehiculesTest = true
      end
    end
    if vehiculesTest and vehName~="" then
      local vfiles = FS:findFiles("/vehicles/"..vehName, "*", -1, true, false)


      for _,vf in pairs(vfiles) do
        if not modsOwnFile(modname,vf) then
          table.insert(mods[modname].conflict,{file=vf, path=FS:getFileRealPath(vf)})
          log('I', 'checkMod', "Mods "..modname.." have a file conflict "..dumps({file=vf, path=FS:getFileRealPath(vf)}) )
        end
      end
    end
  end

  log('I', 'checkMod', "Mods "..modname.." valid= "..tostring(mods[modname].valid) .. " conflict="..#(mods[modname].conflict or {}) )
  return mods[modname].valid and #mods[modname].conflict == 0
end

-- adds / updates a file in the DB
local function updateZIPEntry(filename)
  --log('I', 'updateZIPEntry', "filename : "..dumps(filename))
  local modname = getModNameFromPath(filename)
  local zip = ZipArchive()
  if not zip:openArchiveName( filename, "R" ) and FS:fileExists(filename) then
    local errMsg = "Invalid ZIP file: "..dumps(filename)
    log("E","updZipEntry", errMsg)
    guihooks.trigger('modmanagerError', errMsg)
    return nil,nil
  end
  local filesInZIP = zip:getFileList()

  if mods[modname] and mods[modname].fullpath == filename then
    --log('D', 'updateZIPEntry', "mod already known: " .. tostring(filename))
  elseif mods[modname] and mods[modname].fullpath ~= filename then --fix for FS changes (mandatory root slash), could also fix reactivation when you mode around
    log('D', 'updateZIPEntry', "mod changed path: " .. dumps(mods[modname].fullpath) .. " -> " .. dumps(filename))
    mods[modname].fullpath = filename
    mods[modname].dirname, mods[modname].filename = path.split(mods[modname].fullpath)
    if filename:find('/unpacked/') and filename:endswith('/') then
      mods[modname].orgZipFilename = filename:gsub('unpacked/', '')
      mods[modname].orgZipFilename = mods[modname].orgZipFilename:gsub('.zip/', '/') -- old format
      mods[modname].orgZipFilename = mods[modname].orgZipFilename:gsub('/$', '')
      mods[modname].orgZipFilename = mods[modname].orgZipFilename..'.zip'
      mods[modname].unpackedPath = filename
    end
    mods[modname].stat = FS:stat(filename)
  else
    if FS:isMounted(filename) then
      FS:unmount(filename)
    end
    -- new entry
    local d = {}
    --log('D', 'updateZIPEntry', "new DB entry: " .. filename )
    local hash = 'wip' -- FS:hashFile(filename)
    if hash then
      d.hash = string.lower(hash)
      --log('D', 'updateZIPEntry', " * " .. tostring(filename) .. " = " .. tostring(hash))
    end

    d.mountPoint = nil -- normally mounts in the game main directory
    d.dateAdded = os.time(os.date('*t'))
    d.stat = FS:stat(filename)

    -- get file list of each zip files
    if FS:isMounted(filename) then
      FS:unmount(filename)
    end
    --local zip = ZipArchive()
    --zip:openArchiveName( filename, "R" )
    --filesInZIP = zip:getFileList()
    --log('D', 'updateZIPEntry', "  entries: " .. tostring( #filesInZIP ) )
    --d.files = {}

    local typeHelper = checkType(filesInZIP);
    if typeHelper.mountPoint then
      d.mountPoint = typeHelper.mountPoint
      d.oldFolders = true
    end

    d.modType = typeHelper.key

    -- activated by default
    d.active = true
    d.fullpath = filename
    d.dirname, d.filename = path.split(d.fullpath)

    if filename:find('/unpacked/') and filename:endswith('/') then
      d.orgZipFilename = filename:gsub('unpacked/', '')
      d.orgZipFilename = d.orgZipFilename:gsub('.zip/', '/') -- old format
      d.orgZipFilename = d.orgZipFilename:gsub('/$', '')
      d.orgZipFilename = d.orgZipFilename..'.zip'
      d.unpackedPath = filename

      local oldLvlFiles = FS:findFiles( "/"..filename..'levels/', "*.mis", 1, true, false )
      local lvlFiles = FS:findFiles( "/"..filename..'levels/', "*.level.json", 3, true, false )
      local vehFiles = FS:findFiles( "/"..filename..'vehicles/', "*", 0, true, true )
      if #oldLvlFiles > 0 or #lvlFiles > 0 then d.modType = 'terrain' end
      if #vehFiles > 0 then d.modType = 'vehicle' end
      -- not sure if it's actually usefull do to the folowing as it happen only when mod is new
      -- arrayConcat(filesInZIP, oldLvlFiles)
      -- arrayConcat(filesInZIP, lvlFiles)
      -- arrayConcat(filesInZIP, vehFiles)
    end

    d.modname = modname
    mods[d.modname] = d

    --log('D', 'updateZIPEntry', "new zip:")
    --dump(d)
  end


  -- fix old bug in db
  if M.modIsUnpacked(modname) and filename:find('/unpacked/') and mods[modname].orgZipFilename:startswith('/mods') and not mods[modname].orgZipFilename:startswith('/mods/') then
    mods[modname].orgZipFilename = mods[modname].orgZipFilename:gsub('/mods', '/mods/')
  end

  --refresh mod info if file is changed
  for k2, v2 in pairs(filesInZIP) do
    v2 = string.lower(v2)
    local modID = string.match(tostring(v2), '^/?mod_info/([0-9a-zA-Z]*)/info%.json')
    if modID then
      -- its a repo info file!
      modID = modID:upper()
      mods[modname].modID = modID
      mods[modname].modInfoPath = '/mod_info/'..modID..'/'
      local jsonContent = zip:readFileEntryByIdx(k2)
      if jsonContent then
        mods[modname].modData = jsonDecode(jsonContent, tostring(filename) .. ' : ' .. tostring(v2))
        -- fix the relative paths to be absolute paths for the UI
        if not mods[modname].modData then
          local errMsg = "Coudn't decode repo manifest for "..dumps(v2).." inside "..dumps(filename)
          log('E', "checkDuplicatedMods", errMsg)
          guihooks.trigger('modmanagerError', errMsg)
          break
        end
        if type(mods[modname].modData.attachments) == 'table' then
          mods[modname].modData.imgs = {}
          for _,va in pairs(mods[modname].modData.attachments) do
            table.insert(mods[modname].modData.imgs, mods[modname].modInfoPath .. va.thumb_filename:gsub("\\", "/") )
            --table.insert(d.modData.imgs, d.modInfoPath .. "/images/" .. va.data_filename:gsub("\\", "/") )
          end
        end
        if type(mods[modname].modData.icon) == 'string' then
          mods[modname].modData.icon = mods[modname].modInfoPath .. mods[modname].modData.icon
        end
      end
      break
    end
  end
  zip:close()

  --if you only have vanila and unpacked, the level list do not get refreshed
  if filename:find('/unpacked/') and filename:endswith('/') then
    if FS:directoryExists(filename.."levels/") then
      filesInZIP[#filesInZIP+1] = "/levels/" --dirty hack to refresh level list
    end
    if FS:directoryExists(filename.."vehicles/") then
      filesInZIP[#filesInZIP+1] = "/vehicles/foo/bar.jbeam" --dirty hack to refresh veh list
    end
    local modFiles = FS:findFiles(filename, '*', -1, true, false)
    for i,e in ipairs(modFiles) do
      local tmp = e:gsub(filename, "")
      if tmp:sub(1,1) ~= "/" then tmp = "/"..tmp end
      filesInZIP[#filesInZIP+1] = tmp
    end
  end

  return mods[modname], filesInZIP
end

local function checkDuplicatedMods(filelist)
  local outFilelist = {}
  local uniqueModList = {}
  local idModList = {}
  local oldModToDelete = {}
  for _, filepath in ipairs(filelist) do
    -- log('D', 'checkDuplicatedMods', "filepath = ".. dumps(filepath) )
    local modname = getModNameFromPath(filepath)
    if not uniqueModList[modname] then
      table.insert(outFilelist, filepath)
      uniqueModList[modname] = filepath
      if string.endswith(filepath, ".zip" ) and FS:fileExists(filepath) then
        -- log('D', 'checkDuplicatedMods', "opening zip")
        local zip = ZipArchive()
        zip:openArchiveName( filepath, "R" )
        local filesInZIP = zip:getFileList()
        for k2, v2 in pairs(filesInZIP) do
          v2 = string.lower(v2)
          local modID = string.match(tostring(v2), '^/?mod_info/([0-9a-zA-Z]*)/info%.json')
          if modID then
            -- log('D', 'checkDuplicatedMods', "found repo metadate = "..dumps(modID))
            local jsonContent = zip:readFileEntryByIdx(k2)
            if jsonContent then
              local modInfo = jsonDecode(jsonContent, tostring(filename) .. ' : ' .. tostring(v2))
              if not modInfo then
                log('E', "checkDuplicatedMods", "Coudn't decode repo manifest for "..dumps(v2).." inside "..dumps(filepath))
                break
              end
              -- log('D', 'checkDuplicatedMods', dumps(modInfo.filename).."  "..modID.."  "..dumps(modInfo.last_update).."  res="..tostring(modInfo.resource_date).."  rel="..tostring(modInfo.release_date).."")
              if idModList[modID] ~= nil then
                local oldFilepath = ""
                local oldModName = ""
                if idModList[modID].lastUpdate == nil or modInfo.last_update == nil then
                  log('E', 'checkDuplicatedMods', "One of the mods have an invalid data !")
                  local mi = modInfo or {}
                  log('D', 'checkDuplicatedMods', "modInfo = ".. dumps(mi) )
                  log('D', 'checkDuplicatedMods', "modID = "..tostring(mi.modID or mi.tagid or filepath).." => "..tostring(mi.lastUpdate) )
                  log('D', 'checkDuplicatedMods', "modID = "..tostring(modID).." => "..tostring(idModList[modID].lastUpdate) )
                  break
                end
                if idModList[modID].lastUpdate >= (modInfo.last_update or modInfo.release_date) then
                  log('D', 'checkDuplicatedMods', "caseid1 "..modname.."("..filepath.." | "..tostring(modInfo.last_update)..") is older than "..idModList[modID].modname.. "("..idModList[modID].fp.." | "..tostring(idModList[modID].lastUpdate)..")")
                  oldFilepath = filepath
                  uniqueModList[modname] = nil
                  oldModName = modname
                  table.remove(outFilelist)
                else
                  log('D', 'checkDuplicatedMods', "caseid2 "..idModList[modID].modname.."("..idModList[modID].fp.." | "..tostring(idModList[modID].lastUpdate)..") is older than "..modname.."("..filepath.." | "..tostring(modInfo.last_update)..")")
                  oldFilepath = idModList[modID].fp
                  oldModName = idModList[modID].modname
                  uniqueModList[idModList[modID].modname] = nil
                  idModList[modID] = {fp=filepath,lastUpdate=(modInfo.last_update or modInfo.release_date),modname=modname}
                  for kf,of in pairs(outFilelist) do
                    if of == oldFilepath then table.remove( outFilelist, kf ); break end
                  end
                end
                local errMsgID = ""
                local needManualAction = true
                if string.sub(oldFilepath,1,11) == "/mods/repo/" then
                  zip:close()
                  zip = nil
                  table.insert(oldModToDelete,{name=oldModName,path=oldFilepath})
                  needManualAction = false
                end
                if needManualAction then
                  errMsgID = "Duplicate mod id="..modID.."\n Delete this old file ["..oldFilepath.."]"
                  log('E', 'initDB(chkDupli)', errMsgID)
                  guihooks.trigger('modmanagerError', errMsgID)
                end
                log('D', 'checkDuplicatedMods', "needManualAction = "..dumps(needManualAction))
              else
                idModList[modID] = {fp=filepath,lastUpdate=(modInfo.last_update or modInfo.release_date),modname=modname}
              end
            end
            break
          end
        end
        if zip then
          zip:close()
          zip = nil
        end
      end
    else
      local errMsg = 'Duplicated mod[ '..modname..' ]\n['..uniqueModList[modname]..']\n - ['..filepath..']'
      log('E', 'initDB(chkDupli)', errMsg)
      guihooks.trigger('modmanagerError', errMsg)
      mods[modname] = nil -- force update DB
    end
  end
  for _,v in pairs(oldModToDelete) do
    log('E', 'chkDupli.oldModToDelete', dumps(v.name))
    M.deleteMod(v.name)
    if FS:fileExists(v.path) then log('D', 'checkDuplicatedMods', "delete '"..tostring(v.path).."' = "..dumps(FS:removeFile(v.path)) ) end
    if FS:fileExists(v.path) then
      log('E', 'checkDuplicatedMods', "failed to delete "..tostring(v.path))
      local errMsgID = "Duplicate mod id="..v.name.."\n Delete this old file ["..v.path.."]"
      guihooks.trigger('modmanagerError', errMsgID)
    end
  end
  return outFilelist
end


local function getModsDisabledAfterUpdate()
  if not modDisabledCheckedOnce then
    local updatedFromVersion = nil
    local cmdArgs = Engine.getStartingArgs()
    for i, v in ipairs(cmdArgs) do
      if v == '-versionUpdated' then
        if #cmdArgs > i then
          updatedFromVersion = cmdArgs[i + 1]
        end
        log('I', 'initDB', "Version update found. Coming from version '" .. tostring(updatedFromVersion) .. "'")

        -- check if mods exist
        local modData = jsonReadFile(persistencyfile)
        local modsInstalled = (type(modData) == 'table' and type(modData.mods) == 'table' and not tableIsEmpty(modData.mods))
        if modsInstalled then
          -- only disable mods if some were installed in the first place
          settings.setValue('disableModsAfterUpdate', true)
        end
        break
      end
    end
    modDisabledCheckedOnce = true
  end

  return settings.getValue('disableModsAfterUpdate')
end

local initDB = extensions.core_jobsystem.wrap(function(job)
  --log('D', 'initDB', 'initDB() ...')

  if getModsDisabledAfterUpdate() then
    log('I', '', 'Mods disabled by setting disableModsAfterUpdate')
    ready = true
    extensions.hook('onModManagerReady')
    guihooks.trigger('ModManagerReady')
    return
  end

  -- check DB version number
  if not dbHeader or dbHeader.version ~= 1.1 then
    mods = {} -- rebuild DB
    dbHeader = { version = 1.1 }
  end

  local newMountedFiles = {} --array of files added by mount
  -- catch new files
  local zipfileList = FS:findFiles( "/mods/", "*.zip", -1, false, false )
  local unpackedList = FS:findFiles( "/mods/unpacked/", "*", 0, false, true )
  --if unpackedList[1] == 'mods/unpacked/' then unpackedList[1] = '' end --fix for previous FS
  local fileList = {}
  for k, v in ipairs(unpackedList) do table.insert(fileList, v) end
  for k, v in ipairs(zipfileList) do table.insert(fileList, v) end
  fileList = checkDuplicatedMods(fileList)

  local mountList = {}
  for k,filename in pairs(fileList) do
    filename = string.lower(filename)
    -- ensure the window is refreshing

    -- mount only zip files and unpacked zip folders
    if string.endswith(filename, '.zip') or FS:directoryExists(filename) then
      -- check for unpacked mods

      if FS:directoryExists(filename) then filename=filename.."/" end

      local mod, modFiles = updateZIPEntry(filename)
      if mod and isSafeMode() then mod.active = false end

      if mod and mod.active ~= false then
        log('D', 'initDB', 'mountEntry -- ' .. tostring(filename) .. ': ' .. (mod.modID or '') .. ' : ' .. (mod.modname or ''))
        addMountEntryToList(mountList, filename, mod.mountPoint)
        if modFiles and #modFiles>0 then
          newMountedFiles = arrayConcat(newMountedFiles,modFiles)
        end
        job.yield()
      end
    end
    --Engine.Platform.repaintCanvas() -- This repaint must happen *after* the first yield (rather than before); Otherwise imgui is not properly initialized, which can lead to crashes somewhere else. For instance, it made career imgui UI crash on the first frame after ctrl+L)
  end

  if( #mountList > 0) then
    if not FS:mountList(mountList) then
      guihooks.trigger('modmanagerError', 'Error mounting mods')
      log('E', 'initDB', 'mountList Error')
    end
  end
  --log('D', 'initDB', '... finished')

  -- catch deleted files
  for k,v in pairs(mods) do
    if not FS:fileExists(v.fullpath) and not FS:directoryExists(v.fullpath) then
      mods[v.modname] = nil
      log('W', 'initDB', 'mod vanished: ' .. tostring(v.fullpath))
    end
  end

  --File change notification
  local tim = hptimer()
  for k,v in pairs(newMountedFiles) do
    newMountedFiles[k] = {filename = v, type = "added" }
  end
  log("D","initDB", "Notification : took ".. tostring(tim:stopAndReset()) .. "ms to reorganise ".. tostring(#newMountedFiles) .. " files")
  _G.onFileChanged(newMountedFiles) --main.lua
  log("D","initDB", "Notification : took ".. tostring(tim:stopAndReset()) .. "ms to callback")

  --dump(mods)
  stateChanged()
  extensions.load('core_repository') -- load core_repository if not loaded to make sure event gets fired
  if ready ~= true then
    ready = true
    extensions.hook('onModManagerReady')
    guihooks.trigger('ModManagerReady')
  end

  -- execute modScripts
  -- TODO deprecated: some modScripts are used to load extensions, added backward compatibility
  local old_loadModule = extensions.load
  extensions.load = function(module)
    log('E', 'initDB.modScript', 'extensions.luaModule(m) is deprecated for this case, please use registerCoreModule(m)', module)
    old_loadModule(module)
    registerCoreModule(module)
  end

  local modScriptFiles = FS:findFiles('/scripts/', 'modScript.lua', -1, true, false)
  for k,v in ipairs(modScriptFiles) do
    local status, ret = pcall(dofile, v)
    if not status then
      log('E', 'initDB.modScript', 'Failed to execute ' .. v)
      log('E', 'initDB.modScript', dumps(ret))
    end
  end

  modScriptFiles = FS:findFiles('/mods_data/', 'modScript.lua', 1, true, false)
  for k,v in ipairs(modScriptFiles) do
    if not pcall(dofile, v) then
      log('E', 'initDB.modScript', 'Failed to execute ' .. v)
    end
  end

  extensions.load = old_loadModule
  loadCoreExtensions()

  if checkStartup and settings.getValue('modAutoUpdates') and Engine.Platform.isNetworkUnrestricted() then
    M.checkUpdate()
    checkStartup = false
  end
end)

local function deactivateAllMods()
  for modname, v in pairs(mods) do
    M.deactivateMod(modname)
  end
  stateChanged()
end

local function onUiReady()
  if getModsDisabledAfterUpdate() then return end

  if ready then return end
  local data = nil
  data = jsonReadFile(persistencyfile)
  if data then
    dbHeader = data.header
    if data.mods then
      tableMerge(mods, data.mods)
    end
  end

  initDB()
end

local function enableModsAfterUpdate()
  settings.setValue('disableModsAfterUpdate', false)
  onUiReady()
end

local function safeDelete(filename)
  if not string.startswith(filename, '/mods/') or filename:find("%.%.") ~= nil then
    log('E', 'safeDelete', 'unable to delete file: not in mods folder: ' .. filename)
    return false
  end
  if not FS:fileExists(filename) and not FS:directoryExists(filename) then
    return true
  end
  if FS:remove(filename) ~= 0 then
    log('E', 'safeDelete', 'unable to delete : ' .. dumps(filename))
    return false
  end
  return true
end

local function safeDeleteFolder(folderPath)
  -- delete old files in reverse order for empty folders before try to delete it
  -- local deleteFileList = FS:findFiles( folderPath, "*", -1, true, true )
  --dump(deleteFileList)
  -- for i = #deleteFileList, 1, -1 do
  --   safeDelete( deleteFileList[i] )
  -- end
  safeDelete(folderPath) --FS:remove is recursive and deletes both folder and dir
end

-- WIP ZIP interface
--[[
local function test()
  local files = getFilesInDirectory('mods')
  for k, v in pairs(files) do
    --local hash = hashFile(v)
    print(" * " .. tostring(v) .. " = " .. tostring(hash))


    local path, filename, ext = path.split(v)
    local infofile = path .. string.sub(filename, 0, -string.len(ext)-2) .. '.json'
    local data = jsonReadFile(infofile)
    if data then
      dump(data)
    end
  end
end
local function testZips()
  print('testZips')
  local fileList = FS:findFiles( "/mods", "*.zip", -1, true, false )
  for k,v in pairs(fileList) do
    print( "ZIP file: " .. v )

    -- get file list of each zip files
    local zip = ZipArchive()
    zip:openArchiveName( v, "R" )
    local filesInZIP = zip:getFileList()
    print("  entries: " .. tostring( #filesInZIP ) )
    for k2,v2 in pairs(filesInZIP) do
      print( "  " .. v2 )
      if v2:find(".jbeam") then
        local text = zip:readFileEntryByIdx(k2)
        print( "     Contains: " .. text)
      end

    end

    -- test mounting
    print( "  Testing mounting of " .. v)
    print( "     checking isMountedZIP ... RESULT " .. tostring( FS:isMounted(v) ))
    print( "     checking mountZIP ... RESULT " .. tostring( FS:mount(v) ))
    print( "     checking isMountedZIP ... RESULT " .. tostring( FS:isMounted(v) ))
    print( "     checking unmountZIP ... RESULT " .. tostring( FS:unmount(v) ))
    print( "     checking isMountedZIP ... RESULT " .. tostring( FS:isMounted(v) ))

  end
end
--]]

local function _cleanPathFromHash(p)
  return p:gsub("\\","")
end

-- avoid calling for unpacked mods because of perf reason
-- does not work with specific mountpath
local function _getModFsNotifFileList(modname,reason) --reason ["added", "deleted"]
  if not mods[modname] then
    log('E', '_getModContentFileList', 'mod not existing ' .. tostring(modname))
    return {}
  end

  local mountedFilesChange = {}

  if mods[modname].modData and mods[modname].modData.hashes then --repo mod
    for i,e in ipairs(mods[modname].modData.hashes) do
      mountedFilesChange[i] = {filename = "/" .. _cleanPathFromHash(e[1]) , type = reason } --e[2] is hash
    end
  elseif mods[modname].unpackedPath then --unpacked, no fs notif because too slow to do findfiles on everything
    local modFiles = FS:findFiles(mods[modname].unpackedPath, '*', -1, true, false)
    for i,e in ipairs(modFiles) do
      local tmp = e:gsub(mods[modname].unpackedPath, "")
      if tmp:sub(1,1) ~= "/" then tmp = "/"..tmp end
      mountedFilesChange[i] = {filename = tmp, type = reason }
    end

  else--packed zip with no info
    local zip = ZipArchive()
    if zip:openArchiveName( mods[modname].fullpath, "R" ) and FS:fileExists(mods[modname].fullpath) then
      local filesInZIP = zip:getFileList()
      for k,v in ipairs(filesInZIP) do
        mountedFilesChange[#mountedFilesChange+1] = {filename = v, type = reason }
      end
    else
      log("E","_getModFsNotifFileList", "Invalid ZIP file: "..dumps(mods[modname].fullpath))
      mountedFilesChange = {}
    end
    zip:close()
    zip = nil
  end

  return mountedFilesChange
end

local function _getModScriptFiles(modname)
  if not mods[modname] then
    log('E', '_getModContentFileList', 'mod not existing ' .. tostring(modname))
    return nil
  end

  local modScripts = {}

  if mods[modname].modData and mods[modname].modData.hashes then --repo mod
    for i,e in ipairs(mods[modname].modData.hashes) do
      local fp = "/" .. _cleanPathFromHash(e[1]) --e[2] is hash
      if (string.startswith(fp,'/scripts/') or string.startswith(fp,'/mods_data/'))
      and string.endswith(fp,'/modScript.lua') then
        modScripts[#modScripts+1] = fp
      end
    end
  elseif mods[modname].unpackedPath then --unpacked, no fs notif because too slow to do findfiles on everything
    local modScriptFiles = FS:findFiles(mods[modname].unpackedPath .. '/scripts/', 'modScript.lua', -1, true, false)
    modScripts = arrayConcat(modScripts,modScriptFiles)

    modScriptFiles = FS:findFiles(mods[modname].unpackedPath .. '/mods_data/', 'modScript.lua', 1, true, false)
    modScripts = arrayConcat(modScripts,modScriptFiles)

  else--packed zip with no info
    local zip = ZipArchive()
    if zip:openArchiveName( mods[modname].fullpath, "R" ) and FS:fileExists(mods[modname].fullpath) then
      local filesInZIP = zip:getFileList()
      for k,v in ipairs(filesInZIP) do
        if (string.startswith(v,'/scripts/') or string.startswith(v,'/mods_data/'))
        and string.endswith(v,'/modScript.lua') then
          modScripts[#modScripts+1] = v
        end
      end
    else
      log("E","activateMod.modScript", "Invalid ZIP file: "..dumps(mods[modname].fullpath))
    end
    zip:close()
    zip = nil
  end
  return modScripts
end

local function deactivateMod(modname)
  if not mods[modname] then
    log('I', 'deactivateMod', 'mod not existing ' .. tostring(modname))
    return
  end
  local filename = mods[modname].fullpath
  if FS:isMounted(filename) then
    FS:unmount(filename)
  end

  local mountedFilesChange = nil
  local mountPoint = ""
  if mods[modname].mountPoint then
    mountPoint = mods[modname].mountPoint
  end

  mountedFilesChange = _getModFsNotifFileList(modname,"deleted")

  mods[modname].active = false
  extensions.hook('onModDeactivated', deepcopy(mods[modname]))
  if mountedFilesChange then
    _G.onFileChanged(mountedFilesChange) --main.lua
  end
  stateChanged()
  
  MPModManager.onModStateChanged(modname) -- ///////////////////////////////////////////////////////////// BEAMMP
end

local function getModNameFromID(modID)
  for name,m in pairs(mods) do
    if m.modData ~= nil and m.modData.tagid ~= nil and m.modData.tagid == modID then
      return name
    end
    if name == modID then return modID end
  end
  return nil
end

local function deactivateModId(modID)
  local name = getModNameFromID(modID)
  if name then
      deactivateMod(name)
  else
    log('I', 'deactivateModId', 'mod not existing ' .. tostring(modID))
  end
end

local function activateMod(modname)
  if not mods[modname] then
     log('I', 'activateMod', 'mod not existing ' .. tostring(modname))
    return
  end
  if not FS:isMounted(mods[modname].fullpath) then
    mountEntry(mods[modname].fullpath, mods[modname].mountPoint)
  end

  local mountedFilesChange
  mountedFilesChange = _getModFsNotifFileList(modname,"added")
  local modScripts = _getModScriptFiles(modname)
  local mountPoint = ""
  if mods[modname].mountPoint then
    mountPoint = mods[modname].mountPoint
  end

  log('D', 'activateMod', 'modScripts' .. dumps(modScripts))

  for k,v in ipairs(modScripts) do
    local status, ret = pcall(dofile, v)
    if not status then
      log('E', 'activateMod.modScript', 'Failed to execute ' .. v)
      log('E', 'activateMod.modScript', dumps(ret))
    end
  end

  mods[modname].active = true
  extensions.hook('onModActivated', deepcopy(mods[modname]))
  if mountedFilesChange and #mountedFilesChange>0 then
    _G.onFileChanged(mountedFilesChange) --main.lua
  end

  stateChanged()
  
  MPModManager.onModStateChanged(modname) -- ///////////////////////////////////////////////////////////// BEAMMP
end

local function activateModId(modID)
  local name = getModNameFromID(modID)
  if name then
    activateMod(name)
  else
    log('I', 'activateModId', 'mod not existing ' .. tostring(modID))
  end
end

local function activateAllMods()
  local mountList = {}
  local mountedFilesChange = {}
  local modScripts = {}
  for modname, v in pairs(mods) do
    if not FS:isMounted(v.fullpath) then
      addMountEntryToList( mountList, v.fullpath, v.mountPoint )

      --fs notif and modscript
      local newMountedFilesChange = _getModFsNotifFileList(modname,"added")
      mountedFilesChange = arrayConcat(mountedFilesChange,newMountedFilesChange)
      local newModScripts = _getModScriptFiles(modname)
      if newModScripts and #newModScripts>0 then
        modScripts = arrayConcat(modScripts,newModScripts)
      end
    end

    if mods[modname] and not mods[modname].active then
      mods[modname].active = true
      extensions.hook('onModActivated', deepcopy(mods[modname]))
    end
  end

  if( #mountList > 0) then
    if not FS:mountList(mountList) then
      guihooks.trigger('modmanagerError', 'Error mounting mods')
      log('E', 'activateAllMods', 'mountList Error')
    end
  end

  log('D', 'activateAllMods', 'modScripts' .. dumps(modScripts))

  for k,v in ipairs(modScripts) do
    local status, ret = pcall(dofile, v)
    if not status then
      log('E', 'activateAllMods.modScript', 'Failed to execute ' .. v)
      log('E', 'activateAllMods.modScript', dumps(ret))
    end
  end
  _G.onFileChanged(mountedFilesChange) --main.lua

  stateChanged()
end

local function deleteMod(modname)
  --print("removeMod")
  --print(hash)
  if not mods[modname] then
    log('I', 'deleteMod', 'mod not existing ' .. tostring(modname))
    return
  end
  local filename = mods[modname].fullpath
  if FS:isMounted(filename) then
    if not FS:unmount(filename) then
      log("E", "deleteMod", "unmount failed")
    end

    --fs notif
    local rmMountedFilesChange = _getModFsNotifFileList(modname,"deleted")
  end

  if not safeDelete(filename) then return false end
  mods[modname] = nil
  stateChanged()
  return true
end

local function deleteAllMods()
  for mod, v in pairs(mods) do
    if v.dirname == "/mods/repo/" then
      deleteMod(mod)
    end
  end
  core_online.apiCall('s2/v4/modUnsubscribeAll')
  stateChanged()
end

local function unpackMod(modname)
  if not mods[modname] then
    guihooks.trigger('modmanagerError', 'Error extracting file:  not existing:' .. tostring(modname))
    return
  end

  local filename = mods[modname].fullpath
  if FS:isMounted(filename) then
    FS:unmount(filename)
  end

  local dir, basefilename, ext = path.splitWithoutExt(filename)
  local targetPathOrg = '/mods/unpacked/' .. basefilename
  local targetPath = targetPathOrg

  local zipOldCopy = deepcopy(mods[filename])
  -- auto-corrects the mount point
  if mods[modname].mountPoint then
    targetPath = targetPath .. '/' .. mods[modname].mountPoint
    mods[modname].mountPoint = nil
  end
  --print("targetPath: " .. targetPath)

  local zip = ZipArchive()
  if not zip:openArchiveName(filename, 'r') then
    guihooks.trigger('modmanagerError', 'Error unpacking mod[ '..modname.. ' ]. ZIP file is not valid')
    return
  end
  local files = zip:getFileList()

  Engine.Platform.taskbarSetProgress(0.0)
  Engine.Platform.taskbarSetProgressState(2)
  --dump(files)
  local extractionRes = true
  for i,v in ipairs(files) do
    --print('extractFile: ' .. tostring(v) .. ' -> ' .. tostring(targetPath) .. v)
    Engine.Platform.taskbarSetProgress(i / #files)
    if not zip:extractFile(v, targetPath .. v) then
      extractionRes = false
      guihooks.trigger('modmanagerError', 'Error extracting file: ' .. tostring(v))
      log('E', 'unpackMod', 'error extracting file: ' .. tostring(v))
      Engine.Platform.taskbarSetProgressState(4)
    end
  end
  zip:close()

  if not extractionRes then
    safeDeleteFolder(targetPath)
    mods[modname] = zipOldCopy
    guihooks.trigger('modmanagerError', 'Error extracting file: ' .. tostring(v))
    Engine.Platform.taskbarSetProgressState(0)
    return
  end

  if not safeDelete(filename) then
    Engine.Platform.taskbarSetProgressState(4)
    guihooks.trigger('modmanagerError', 'Error : could not safe delete: ' .. dumps(filename))
    log('E', 'unpackMod', 'Error : could not safe delete: ' .. dumps(filename))
    messageBox("BeamNG.drive - Modmager",
    "The zip file could not be deleted properlly.\nThis happens when it's open by another software.\nYou need to close that software and manually delete the file bellow :\n"..dumps(filename), 0, 0)
  end
  Engine.Platform.taskbarSetProgressState(0)

  FS:mount(targetPathOrg)
  mods[modname].dirname, mods[modname].filename = path.split(targetPathOrg)

  mods[modname].orgZipFilename = filename
  mods[modname].unpackedPath = targetPathOrg
  mods[modname].fullpath = targetPathOrg
  mods[modname].stat = FS:stat(targetPathOrg)

  stateChanged()
end

local function packMod(dirPath)
  log('D', 'packMod', 'Packing : ' .. tostring(dirPath))
  if not FS:directoryExists(dirPath) then
    log('E', 'packMod', 'path is not a folder path='..dumps(dirPath))
    return false
  end
  local modpath, modname, modext = path.splitWithoutExt( dirPath:gsub('/$', '')..'.zip' )
  if not mods[modname] then
    guihooks.trigger('modmanagerError', 'Unable to pack mod: not existing: ' .. tostring(dirPath))
    return false
  end
  if not mods[modname].unpackedPath then
    guihooks.trigger('modmanagerError', 'Unable to pack mod: not unpacked: ' .. tostring(filename))
    log('E', 'packMod', 'unable to pack mod: not unpacked: ' .. tostring(filename))
    return false
  end

  if FS:isMounted(mods[modname].unpackedPath) then
    FS:unmount(mods[modname].unpackedPath)
  end

  local zipFilename = mods[modname].orgZipFilename
  if not zipFilename then
    log('E', 'packMod', 'unable to pack mod: no zip filename')
    guihooks.trigger('modmanagerError', 'Unable to pack mod: no zip existing')
    return false
  end

  safeDelete(zipFilename)

  local zip = ZipArchive()
  zip:openArchiveName(zipFilename, 'w')

  if not string.find(zip:getModeString(), "write") then
    log('E', 'packMod', 'unable to pack mod: Zip is in read only')
    guihooks.trigger('modmanagerError', 'Unable to pack mod: Zip is in read only, close other software')
    return false
  end

  Engine.Platform.taskbarSetProgressState(1)

  local fileList = FS:findFiles( mods[modname].unpackedPath, "*", -1, false, false )

  Engine.Platform.taskbarSetProgress(0.0)
  Engine.Platform.taskbarSetProgressState(2)

  for k,v in pairs(fileList) do
    local zipPath = v
    -- copy only files
    if zipPath:startswith(mods[modname].unpackedPath) then
      zipPath = string.sub(zipPath, string.len(mods[modname].unpackedPath) + 1)
      if string.startswith(zipPath, '/') then
        zipPath = string.sub(zipPath, 2)
      end
    end
    log('D', 'packMod', 'zip-addfile: ' .. tostring(v) .. ' > ' .. tostring(zipPath))
    zip:addFile(v, zipPath)
    Engine.Platform.taskbarSetProgress(k/#fileList)
  end
  zip:close()
  Engine.Platform.taskbarSetProgressState(0)

  -- debug output the files in there
  --zip = ZipArchive()
  --zip:openArchiveName(zipFilename, 'r')
  --local files = zip:getFileList()
  --dump(files)
  safeDeleteFolder(mods[modname].unpackedPath)

  mods[modname].unpackedPath = nil
  mods[modname].orgZipFilename = nil


  mods[modname].fullpath = zipFilename
  mods[modname].dirname, mods[modname].filename = path.split(zipFilename)
  mods[modname].stat = FS:stat(zipFilename)

  stateChanged()
end

local function workOffChangedMod(filename, type)
  -- check if we have mod unpacked
  local modname = getModNameFromPath(filename)
  if mods[modname] and mods[modname].unpackedPath and type == 'added' then
    safeDelete(filename)
    log('E', '', 'You have a unpacked version of [ '..modname..' ]. Need to be Packed before update')
    guihooks.trigger('modmanagerError', 'You have a unpacked version of [ '..modname..' ]. Need to be Packed before update')
    return
  end
  local dir, basefilename, ext = path.splitWithoutExt(filename)
  if ext == 'zip' and FS:fileExists(filename) and (type == 'added' or type == 'modified') then
    log('D', '', tostring(filename) .. ' : ' .. tostring(type) .. ' > ' .. tostring(ext))
    local mod, files = updateZIPEntry(filename)
    if mod and mod.active ~= false then
      log('D', '', 'activateMod -- ' .. tostring(filename))
      activateMod(mod.modname)
	  MPCoreNetwork.modLoaded(mod.modname) -- //////////////////////////////////////////////////////////////																								 
    end
    FS:triggerFilesChanged(files) -- alert c++ of changed files
    stateChanged()
  end
end

local function onFileChanged(filename, type)
  if filename:startswith("/mods/unpacked") then return end
  if filename:startswith("/mods/") and filename:endswith(".zip") and filename ~= persistencyfile and autoMount then
    workOffChangedMod(filename, type)
  end
end

local function isReady()
  return ready
end

local checkUpdate = extensions.core_jobsystem.wrap(function(job)

  if checkingModUpdate == true then return end

  checkingModUpdate = true

  local data = {}

  for k,v in pairs(mods) do
    if v.modData ~= nil and v.modData.tagid ~= nil then
      table.insert(data, {id = v.modData.tagid, ver = (v.modData.resource_version_id or 0)})
    else
      if v.fullpath:match("/mods/unpacked") == nil then --no check for unpacked
        log('I', 'checkUpdate', 'old mod ' .. tostring(k))
        --[[local wasMounted = false
        if FS:isMounted(v.fullpath) then --TODO FS
          wasMounted = true
          FS:unmount(v.fullpath)
        end
        local zip = ZipArchive()
        if not zip:openArchiveName(v.fullpath, "r") then
          log('E', 'checkUpdate', 'error opening zip file for reading: ' .. tostring(v.fullpath))
          goto continue
        end
        local filesInZIP = zip:getFileList()
        log('D', 'checkUpdate', "  entries: " .. tostring( #filesInZIP ) )
        table.insert(data, {name = k, hash = {} } )
        data[#data] = filesInZIP
        --]]
        --[[
        for k, v in pairs(filesInZIP) do
          local hash = zip:getFileEntryHashByIdx(k)
          if hash == '' then
            log('E', 'checkUpdate', 'unable to hash file in zip: ' .. tostring(v.fullpath) .. ' / ' .. tostring(v))
          else
            table.insert(data[#data].hash, {file = v, hash = hash})
          end
        end

        if wasMounted then
          FS:mount(v.fullpath)
        end--]]
      end
    end
    guihooks.trigger('checkUpdateCheckedMod', k)
    ::continue::
  end
  log('D', 'checkUpdate', dumps(data))

  core_online.apiCall('s2/v4/modSync', function(request)
      if request.responseData == nil then
        guihooks.trigger('modmanagerError', 'Server Error')
        log('E', 'installMod.downloadFinishedCallback', 'Server Error')
        log('E', 'installMod.downloadFinishedCallback', 'url = '..tostring(request.uri))
        log('E', 'installMod.downloadFinishedCallback', 'responseBuf = '..tostring(request.responseBuffer))
        return
      end
      --print(dumps( request.responseData) )
      if not request.responseData and request.responseData.ok == 1 then
        log('E', 'checkUpdate', 'modSync failed =' .. (request.responseBuffer or "")  )
        guihooks.trigger('modmanagerError', 'Check Update failed')
      else
        for k,v in pairs(request.responseData.data) do
          if v['action'] ~= nil then
            if v['action'] == "deactivate" then
              deactivateModId(v.id)
              guihooks.trigger('modmanagerError', 'You have an outdated version of [ '..tostring(getModNameFromID(v.id))..' ]. This mod has been deactivated`')
            else if v['action'] == "update" or v['action'] == "missing" then
              v.reason = v.action
              log('I', 'checkUpdate', tostring(v['action'])..' -- ' .. tostring(v.id) .. "  to " .. tostring(v.ver))
              extensions.core_repository.addUpdateQueue(v)
              else if v['action'] == "404OLD" then
                log('I', 'checkUpdate', 'update OLD Didn\'t found any replacement :' .. v.name)
                guihooks.trigger('modmanagerError', "Didn't found replacement for this mod : "..v.name)
                deactivateMod(v.name)
                else
                    log('I', 'checkUpdate', 'unknown action for mod ' .. tostring(v.id))
                end
              end
            end
          end
          guihooks.trigger('checkUpdateCheckedMod', "SYNC "..tostring(core_modmanager.getModNameFromID(v.id) or v.filename:gsub(".zip","")) )
          job.yield()
        end
      end
      extensions.core_repository.uiUpdateQueue()
      guihooks.trigger('checkingUpdatesEnd')

      core_repository.updateAllMods()
    end, {
      mods = data,
    })

  guihooks.trigger('ModManagerModsChanged', mods)
  checkingModUpdate = false

end, 500)

local function getConflict(modname)
  if mods[modname] == nil or mods[modname].conflict == nil then return nil end
  return mods[modname].conflict
end

local function getModDB(modname)
  return mods[modname]
end

local function openModFolderInExplorer()
    Engine.Platform.exploreFolder("/mods/")
end

local function modIsUnpacked(modname)
  local modname = getModNameFromPath(modname)
  --log('I', 'modIsUnpacked', modname)
  if mods[modname] == nil then return false end
  --log('I', 'modIsUnpacked', mods[modname].unpackedPath)
  return mods[modname].unpackedPath ~= nil
end

-- returns the modname and the info of the filename
local gamePath = FS:getGamePath() -- these never change at runtime
local userPath = FS:getUserPath()
local function getModForFilename(filename_virtual)
  local realPath = FS:getFileRealPath(filename_virtual)
  if string.startswith(realPath, gamePath) then
    -- no mods allowed in game path
    return
  end
  if string.startswith(realPath, userPath) then
    local modPath = realPath:sub(string.len(userPath))
    modPath = modPath:gsub("\\", "/")
    local zipPos = modPath:find('.zip')
    if zipPos then
      modPath = modPath:sub(1, zipPos + 3)
    else
      -- not a zip, thus not a mod. unpacked mods not supported right now
      return
    end

    for modname, mod in pairs(mods) do
      if mod.fullpath == modPath then
        return modname, mod
      end
    end
  end
end

local function check4Update()
  checkStartup = true
end

local function onSettingsChanged()
  if ready == nil then return end
  if settings.getValue('onlineFeatures') == 'enable' then
    checkStartup = true
  end
end

local function disableAutoMount()
  autoMount = false
end

local function enableAutoMount()
  autoMount = true
  initDB()
end

local function getStats()
  local r = {zip=0, unpacked=0, disabled=0}
  for modname,mdata in pairs(mods) do
    if not mdata.active then
      r.disabled = r.disabled+1
    elseif mdata.stat.filetype == "file" then
      r.zip = r.zip+1
    elseif mdata.stat.filetype == "dir" then
      r.unpacked = r.unpacked+1
    end

  end
  return r
end

local function updateZipMod(oldFileName,newFileName)
  local oldMod = nil
  oldMod = getModDB( getModNameFromPath(oldFileName) )
  if oldMod == nil then
    for mn,md in pairs(mods) do
      if m.filename == oldFileName then
        oldMod = md
        break
      end
    end
    if oldMod == nil and not FS:fileExists("/mods/"..oldFileName) then
      guihooks.trigger('modmanagerError', "updateZipMod: Old ZIP not found")
      log("E","updateZipMod","Old file not found ")
      return
    end
  end

  if oldMod then
    deleteMod(getModNameFromPath(oldFileName))
  else
    if FS:isMounted("/mods/"..oldFileName) then
      FS:unmount("/mods/"..oldFileName)
      log("E","updateZipMod","Unmounting a mod that is not in the mod DB. This is Wrong!. Zip="..oldFileName)
    end
    if FS:removeFile("/mods/"..oldFileName) ~= 0 then
      guihooks.trigger('modmanagerError', "updateZipMod: Failed to delete old ZIP")
      log("E","updateZipMod","Failed to delete old ZIP "..tostring(oldFileName))
      return
    end
  end

  if FS:renameFile("/mods/"..newFileName,"/mods/"..oldFileName) ~= 0 then
    guihooks.trigger('modmanagerError', "updateZipMod: Failed to rename ZIP")
    log("E","updateZipMod","Failed to rename ZIP ''"..tostring(oldFileNamex).."' > '"..newFileName.."'")
    return
  end
end


-- ///////////////////////////////////////////////////////////////////
local function getModList()
  return mods
end
M.getModList = getModList
log("I","BeamMP"," Custom modmanager injected.")
-- ///////////////////////////////////////////////////////////////////

-- public interface
M.isReady = isReady
M.onFileChanged = onFileChanged
M.initDB = initDB

--M.testZips = testZips
M.unpackMod = unpackMod
M.openEntryInExplorer = openEntryInExplorer
M.openModFolderInExplorer = openModFolderInExplorer
M.packMod = packMod
M.onUiReady = onUiReady
M.requestState = sendGUIState

M.updateZipMod = updateZipMod

M.getModNameFromID = getModNameFromID
M.getStats = getStats

M.deleteMod = deleteMod
M.deactivateMod = deactivateMod
M.deactivateModId = deactivateModId
M.activateMod = activateMod
M.activateModId = activateModId

M.enableModsAfterUpdate = enableModsAfterUpdate
M.deactivateAllMods = deactivateAllMods
M.activateAllMods = activateAllMods
M.deleteAllMods = deleteAllMods
M.workOffChangedMod = workOffChangedMod
M.checkMod = checkMod
M.checkUpdate = checkUpdate
M.getConflict = getConflict
M.getModDB = getModDB
M.modIsUnpacked = modIsUnpacked
M.check4Update = check4Update
M.getModFromPath = getModFromPath

M.getModForFilename = getModForFilename

M.disableAutoMount = disableAutoMount
M.enableAutoMount = enableAutoMount

return M
