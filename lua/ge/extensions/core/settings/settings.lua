-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local persistencyfile = 'settings/game-settings.ini'
local persistencyfileCloud = 'settings/cloud/game-settings-cloud.ini'

local M = {}
local options = {
  uiUnitLength = {modes={keys={'metric','imperial'}, values={'ui.unit.metric', 'ui.unit.imperial'}}},
  uiUnitTemperature = {modes={keys={'c', 'f', 'k'}, values={'ui.unit.c', 'ui.unit.f', 'ui.unit.k'}}},
  uiUnitWeight = {modes={keys={'lb', 'kg'}, values={'ui.unit.lb', 'ui.unit.kg'}}},
  uiUnitConsumptionRate = {modes={keys={'metric', 'imperial'}, values={'ui.unit.ltr100', 'ui.unit.mpg'}}},
  uiUnitTorque = {modes={keys={'metric', 'imperial'}, values={'ui.unit.nm', 'ui.unit.lbft'}}},
  uiUnitEnergy = {modes={keys={'metric', 'imperial'}, values={'ui.unit.j', 'ui.unit.ftlb'}}},
  uiUnitDate = {modes={keys={'ger', 'uk', 'us'}, values={'DD.MM.YYYY', 'DD/MM/YYYY', 'MM/DD/YYYY'}}},
  uiUnitPower = {modes={keys={'hp', 'bhp', 'kw'}, values={'ui.unit.hp', 'ui.unit.bhp', 'ui.unit.kw'}}},
  uiUnitVolume = {modes={keys={'l', 'gal'}, values={'ui.unit.l', 'ui.unit.gal'}}},
  uiUnitPressure = {modes={keys={'inHg', 'bar', 'psi', 'kPa'}, values={'ui.unit.inHg', 'ui.unit.bar', 'ui.unit.psi', 'ui.unit.kPa'}}},

  uiUpscaling = {modes={keys={'disabled', '720', '1080', '1440'}, values={'Disabled', '1280 x 720', '1920 x 1080', '2560 x 1440'}}},
  onlineFeatures = {modes={keys={'enable', 'disable'}, values={'ui.common.enable', 'ui.common.disable'}}},
  telemetry = {modes={keys={'enable', 'disable'}, values={'ui.common.enable', 'ui.common.disable'}}},
  defaultGearboxBehavior = {modes={keys={'arcade', 'realistic'}, values={'ui.common.arcade', 'ui.common.realistic'}}},
  absBehavior = {modes={keys={'realistic', 'off', 'arcade'}, values={'ui.common.ABSrealistic', 'ui.common.ABSoff', 'ui.common.ABSarcade'}}},
  escBehavior = {modes={keys={'arcade', 'realistic', 'off'}, values={'ui.common.arcade', 'ui.common.realistic', 'ui.common.off'}}},
  trafficSetup = {modes={keys={'smart', 'smartConfigs', 'random', 'randomConfigs'}, values={'ui.common.smart', 'ui.common.smartConfigs', 'ui.common.random', 'ui.common.randomConfigs'}}},
  communityTranslations = {modes={keys={'enable', 'disable'}, values={'ui.common.enable', 'ui.common.disable'}}},
}
M.options = options
local disk = 1
local cloud = 2
local discard = 3
local deprecated = discard
local settingsList = {       -- { storage, default_value }
  languageOS                  = { discard, nil },
  languageOSLong              = { discard, nil },
  languageProvider            = { discard, nil },
  languageProviderLong        = { discard, nil },
  communityLanguages          = { deprecated, nil },
  userLanguageSelected        = { discard, nil },
  userLanguageSelectedLong    = { discard, nil },
  userLanguagesAvailable      = { discard, nil },
  userColorPresets            = { cloud, nil },
  uiLanguage                  = { discard, nil },
  uiUnits                     = { cloud  , nil },
  uiUnitLength                = { cloud  , 'imperial' },
  uiUnitDistance              = { deprecated, nil },
  uiUnitTemperature           = { cloud  , 'f' },
  uiUnitWeight                = { cloud  , 'lb' },
  uiUnitTorque                = { cloud  , 'imperial' },
  uiUnitConsumptionRate       = { cloud  , 'imperial' },
  uiUnitTorque                = { cloud  , 'imperial' },
  uiUnitEnergy                = { cloud  , 'imperial' },
  uiUnitDate                  = { cloud  , 'us' },
  uiUnitPower                 = { cloud  , 'bhp' },
  uiUnitVolume                = { cloud  , 'gal' },
  uiUnitPressure              = { cloud  , 'psi' },
  onlineFeatures              = { cloud  , 'ask' },
  telemetry                   = { cloud  , 'ask' },
  modAutoUpdates              = { disk   , false },
  communityTranslations       = { cloud  , 'disable' },
  disableDynamicCollision     = { disk   , false },
  devMode                     = { cloud  , false },
  creatorMode                 = { deprecated , false },
  externalUi                  = { cloud  , false },
  showPcs                     = { cloud  , false },
  multiseat                   = { discard, false }, -- intentionally use multiseat only until game is closed
  multiseatTags               = { cloud  ,  true },
  foo                         = { deprecated,false },
  fooTests                    = { disk   , false },
  traffic                     = { discard, false }, -- intentionally use traffic only until game is closed
  rpmLedsEnabled              = { disk   , false },
  unfocusedInput              = { cloud  , false },
  filter0_limitEnabled        = { deprecated },
  filter0_limitStartSpeed     = { deprecated },
  filter0_limitEndSpeed       = { deprecated },
  filter0_limitMultiplier     = { deprecated },
  filter1_limitEnabled        = { deprecated },
  filter1_limitStartSpeed     = { deprecated },
  filter1_limitEndSpeed       = { deprecated },
  filter1_limitMultiplier     = { deprecated },
  filter2_limitEnabled        = { deprecated },
  filter2_limitStartSpeed     = { deprecated },
  filter2_limitEndSpeed       = { deprecated },
  filter2_limitMultiplier     = { deprecated },
  filter3_limitEnabled        = { deprecated },
  filter3_limitStartSpeed     = { deprecated },
  filter3_limitEndSpeed       = { deprecated },
  filter3_limitMultiplier     = { deprecated },
  -- key (grip)
  inputFilter0_limitEnabled   = { disk   , false },
  inputFilter0_limitStartSpeed= { disk   ,    14 },
  inputFilter0_limitEndSpeed  = { disk   ,    70 },
  inputFilter0_limitMultiplier= { disk   ,   0.3 },
  -- pad
  inputFilter1_limitEnabled   = { disk   , false },
  inputFilter1_limitStartSpeed= { disk   ,    14 },
  inputFilter1_limitEndSpeed  = { disk   ,    70 },
  inputFilter1_limitMultiplier= { disk   ,   0.5 },
  -- direct
  inputFilter2_limitEnabled   = { disk   , false },
  inputFilter2_limitStartSpeed= { disk   ,     0 },
  inputFilter2_limitEndSpeed  = { disk   ,   100 },
  inputFilter2_limitMultiplier= { disk   ,   0.8 },
  -- key (drift)
  inputFilter3_limitEnabled   = { disk   , false },
  inputFilter3_limitStartSpeed= { disk   ,    20 },
  inputFilter3_limitEndSpeed  = { disk   ,    80 },
  inputFilter3_limitMultiplier= { disk   ,   0.8 },
  userLanguage                = { cloud  , '' }, -- empty = no user language set, using steam or OS language then
  cameraOrbitRelaxation       = { cloud  , 3 },
  cameraOrbitFovModifier      = { cloud  , 0 },
  cameraOrbitMaxDynamicFov    = { cloud  , 40 },
  cameraOrbitSmoothing        = { cloud  , true },
  cameraFOVTune               = { deprecated, nil },
  cameraPosTuneX              = { deprecated, nil },
  cameraPosTuneY              = { deprecated, nil },
  cameraPosTuneZ              = { deprecated, nil },
  cameraDriverVehicleConfigs  = { cloud  , nil },
  cameraDriverFov             = { cloud  , 45 },
  cameraDriverPhysics         = { cloud  , 100 },
  cameraDriverStableHorizon   = { cloud  , 0 },
  cameraDriverAutocenter      = { cloud  , true },
  cameraDriverAllowSeatAdjustments={cloud, false },
  cameraFanVsTV               = { cloud  , 0.1 },
  cameraTVSpeed               = { cloud  , 1 },
  cameraTransitionTime        = { cloud  , 300 },
  cameraCollision             = { cloud  , false },
  couplerCameraModifier       = { cloud  , true },
  disableSteeringwheel        = { cloud  , false },
  interpolatePosition         = { cloud  , true },
  interpolateAlternative      = { cloud  , false },
  interpolateFull             = { cloud  , false },
  interpolateLua              = { cloud  , false },
  replayLevel                 = { cloud  , -1 },
  replayAlpha                 = { disk   , true },
  replayA                     = { disk   , false },
  replayB                     = { disk   , true },
  replayC                     = { disk   , true },
  replayD                     = { disk   , true },
  replayE                     = { disk   , true },
  replayF                     = { disk   , false },
  replayG                     = { disk   , false },
  replayH                     = { disk   , false },
  replayI                     = { disk   , false },
  replayJ                     = { disk   , true },
  replayK                     = { disk   , false },
  replayL                     = { disk   , true },
  replayM                     = { disk   , false },
  replayN                     = { disk   , true },
  replayO                     = { disk   , true },
  replayP                     = { disk   , true },
  --replayQ                     = { disk   , true },
  --replayR                     = { disk   , true },
  restrictScenarios           = { cloud  , true },
  autoSaveInGarage            = { cloud  , false },
  cameraChaseRollSmoothing    = { cloud  , 1 },
  uiUpscaling                 = { disk   , '1080' },
  outgaugeEnabled             = { cloud  , false },
  outgaugeIP                  = { cloud  , '127.0.0.1' },
  outgaugePort                = { cloud  , 4444 },
  startThermalsPreHeated      = { cloud  , true },
  startBrakeThermalsPreHeated = { cloud  , true },
  defaultGearboxBehavior      = { cloud  , 'arcade' },
  absBehavior                 = { cloud  , 'realistic' },
  escBehavior                 = { cloud  , 'realistic' },
  autoClutch                  = { cloud  , true },
  autoThrottle                = { cloud  , true },
  gearboxSafety               = { cloud  , true },
  useFmodLiveUpdate           = { cloud  , false },
  defaultShifterMode          = { deprecated, nil },
  gameplayDefaultShifterMode  = { deprecated, nil },
  autoShiftPrevention         = { deprecated, nil },
  aiAwareness                 = { disk , true },
  trafficAmount               = { disk , 0 },
  trafficSetup                = { cloud, 'smart' },
  trafficAllowMods            = { cloud, true },
  trafficMinimap              = { cloud, false },
  trafficAllModels            = { deprecated, nil },
  trafficAllConfigs           = { deprecated, nil },
  cameraConfig                = { cloud  , nil },
  cameraOrder                 = { deprecated, nil },
  defaultCameraMode           = { deprecated, nil },
  cameraLoadCustomModes       = { deprecated, nil },
  PostFXHDRGeneralEnabled     = { disk   , nil },
  GraphicGPU                  = { disk   , nil },
  GraphicSyncFullscreen       = { deprecated, nil },
  vsync                       = { disk   , false },
  GraphicResolutions          = { deprecated   , nil },
  GraphicGrassDensity         = { disk   , nil },
  AudioMasterVol              = { disk   , nil },
  AudioMusicVol               = { disk   , nil },
  AudioMaxVoices              = { disk   , nil },
  AudioEffectsVol             = { disk   , nil },
  AudioMaxChannels            = { deprecated, nil },
  FPSLimiter                  = { disk   , 60 },
  FPSLimiterEnabled           = { disk   , false },
  HighPerformancePlan         = { disk   , true },
  PostFXLightRaysEnabled      = { disk   , nil },
  AudioInterfaceVol           = { disk   , nil },
  GraphicDynReflectionDetail  = { disk   , nil },
  GraphicBorderless           = { deprecated, nil },
  GraphicFullscreen           = { deprecated, false },
  GraphicRefreshRate          = { disk   , nil },
  GraphicShaderQuality        = { disk   , nil },
  GraphicDisplayDriver        = { disk   , nil },
  GraphicDisplayModes         = { disk   , nil },
  GraphicDisplayRefreshRates  = { disk   , nil },
  GraphicDisplayResolutions   = { disk   , nil },
  GraphicAnisotropic          = { disk   , nil },
  GraphicDynReflectionFacesPerupdate={disk,nil },
  GraphicAntialiasType        = { disk   , nil },
  GraphicGamma                = { disk   , nil },
  GraphicDynReflectionEnabled = { disk   , nil },
  GraphicOverallQuality       = { disk   , nil },
  GraphicAntialias            = { disk   , nil },
  GraphicDynReflectionTexsize = { disk   , nil },
  PostFXDOFGeneralEnabled     = { disk   , nil },
  GraphicMeshQuality          = { disk   , nil },
  GraphicLightingQuality      = { disk   , nil },
  GraphicTextureQuality       = { disk   , nil },
  GraphicDynReflectionDistance= { disk   , nil },
  GraphicPostfxQuality        = { disk   , nil },
  GraphicDisableShadows       = { disk   , nil },
  WindowPlacement             = { disk   , '' },
  AudioDevice                 = { disk   , nil },
  MainMenuBackgroundModeBrokenCefVersion      = { disk   , nil },
  AudioAmbienceVol            = { disk   , nil },
  PostFXSSAOGeneralEnabled    = { disk   , nil },
  AudioProvider               = { disk   , nil },
  OnlineHiddenMessageIDs      = { disk   , nil },
  useSteamName                = { cloud  , true },
  PerformanceWarningstoomanycache          = { disk, nil },
  PerformanceWarningsmissing64binary       = { disk, nil },
  PerformanceWarningstoolessmemoryfor64bit = { disk, nil },
  PerformanceWarningsthirdpartysoftware    = { disk, nil },
  PerformanceWarningslowmem                = { disk, nil },
  PerformanceWarningsminmem                = { disk, nil },
  PerformanceWarningsmemused               = { disk, nil },
  PerformanceWarningsfreememlow            = { disk, nil },
  PerformanceWarningsminmem                = { disk, nil },
  PerformanceWarningscpuonecore            = { disk, nil },
  PerformanceWarningscpuquadcore           = { disk, nil },
  PerformanceWarningscpulowclock           = { disk, nil },
  PerformanceWarningscpu64bits             = { disk, nil },
  PerformanceWarningsremotedesktop         = { disk, nil },
  PerformanceWarningsintelgpu              = { disk, nil },
  PerformanceWarningsgeforcemin            = { disk, nil },
  PerformanceWarningsamdhd                 = { disk, nil },
  PerformanceWarningsamdradeon             = { disk, nil },
  PerformanceWarningsgpulowmem             = { disk, nil },
  PerformanceWarningsgpurecmem             = { disk, nil },
  PerformanceWarningsos32bits              = { disk, nil },
  PerformanceWarningsoldwin7               = { disk, nil },
  PerformanceWarningsxinput                = { disk, nil },
  PerformanceWarningsdinput                = { disk, nil },
  PerformanceWarningsoswin8                = { disk, nil },
  PerformanceWarningsapp32                 = { disk, nil },
  PerformanceWarningspowerdisconnected     = { disk, nil },
  PerformanceWarningsbatterylow            = { disk, nil },
  PerformanceWarningsbatterycritical       = { disk, nil },
  PerformanceWarningswin8rec               = { disk, nil },
  PerformanceWarningshighseas              = { disk, nil },
  SleepInBackground                        = { disk, nil },

  motionSimEnabled                         = { disk, false },
  motionSimVersion                         = { disk, 1 },
  motionSimIP                              = { disk, "127.0.0.1" },
  motionSimPort                            = { disk, 4444 },
  motionSimHz                              = { disk, 100 },
  motionSimAccelerationSmoothingX          = { disk, 40 },
  motionSimAccelerationSmoothingY          = { disk, 40 },
  motionSimAccelerationSmoothingZ          = { disk, 40 },

  modNumParallelDownload                   = { disk, 3 },
  disableRichPresence                      = { cloud  , false },
  uiAcceleratedRender                      = { disk, false },

  -- Multiplayer Settings
  showNameTags                             = { disk, true },
  showDebugOutput                          = { disk, false },
  launcherPort                             = { disk, 4444 },
}

local defaultValues = { }
for k,v in pairs(settingsList) do
  defaultValues[k] = v[2]
end

local values = deepcopy(defaultValues)
local lastSavedTime = 0

local function sendUIState()
  --log("D", "settings.sendUIState", dumps(values))
  guihooks.trigger('SettingsChanged', {values = values, options = options})
end

local function save()
  --log("D", "settings", "Saving options to disk")
  lastSavedTime = os.clock()

  -- save options
  -- log("D", "settings.save", dumps(values))
  local localValues = {}
  local cloudValues = {}
  for k, v in pairs(values) do
    if     (settingsList[k] or {})[1] == disk    then
      localValues[k] = values[k]
    elseif (settingsList[k] or {})[1] == cloud   then
      cloudValues[k] = values[k]
    elseif (settingsList[k] or {})[1] == discard then
      -- nop - don't save anywhere
    else
      if not shipping_build then
        log("D", "", "Setting "..dumps(k).." = "..dumps(values[k]).." with unknown type '"..dumps((settingsList[k] or {})[1]).."', defaulting to cloud storage")
      end
      cloudValues[k] = values[k]
    end
  end
  -- log("D", "settings.save_local", dumps(localValues))
  -- log("D", "settings.save_cloud", dumps(cloudValues))
  saveIni(persistencyfile, localValues)
  saveIni(persistencyfileCloud, cloudValues)

  TorqueScript.eval( 'saveGlobalOptions();' );
  -- let UI and Lua know
  sendUIState()
  extensions.hook('onSettingsChanged')
  be:queueAllObjectLua('onSettingsChanged()')
end

local function refreshTSState(withValue)
  if withValue then
    for k,o in pairs(options) do
      if type(o.get) == 'function' then
        values[k] = o.get()
      end
    end
  end
  for k,o in pairs(options) do
    if type(o.getModes) == 'function' then
      o.modes = o.getModes()
    end
  end
end

local function refreshLanguages()
  -- 0) ask c++ what language is active right now, so we can see if it changed later
  local oldLanguage = Lua:getSelectedLanguage()

  -- no community translations > en-US only
  if values.communityTranslations ~= 'enable' then
    -- en-US only
    values.userLanguage = ''
  end

  local languageMap = require('utils/languageMap') -- load locally, so we don't have it hanging around in memory all the time

  -- 1) set new language
  Lua.userLanguage = values.userLanguage
  -- 2) ask C++ for the correct language
  Lua:reloadLanguages()
  -- 3) get the language that c++ chose
  values.userLanguageSelected = Lua:getSelectedLanguage()
  values.userLanguageSelectedLong = languageMap.resolve(values.userLanguageSelected)
  -- ui language is the same
  values.uiLanguage = values.userLanguageSelected
  --print(' * userLanguageSelected: ' .. tostring(values.userLanguageSelected) .. ' [' .. tostring(values.userLanguageSelectedLong) .. ']')

  -- info things for the UI, not used in the decision process
  -- list available languages
  options.userLanguagesAvailable = {}
  table.insert(options.userLanguagesAvailable, {key="", name="Automatic"}) -- the empty ('') language will be auto - it'll use the OS/steam lang
  local locales = FS:findFilesByRootPattern('/locales/', '*.json', -1, true, false)

  for _, l in pairs(locales) do
    local key = string.match(l, 'locales/([^\\.]+).json')

    table.insert(options.userLanguagesAvailable, {key=key, name = languageMap.resolve(key)})
  end
  --print(' * languagesAvailable: ' .. dumps(options.userLanguagesAvailable))

  -- detailed info, only for the user
  values.languageOS = Lua:getOSLanguage()
  values.languageOSLong = languageMap.resolve(values.languageOS)
  --print(' * languageOS: ' .. tostring(values.languageOS) .. ' [' .. tostring(values.languageOSLong) .. ']')
  values.languageProvider = Lua:getSteamLanguage()
  values.languageProviderLong = Steam and Steam.language or ""
  --print(' * languageProvider: ' .. tostring(values.languageProvider) .. ' [' .. tostring(values.languageProviderLong) .. ']')

  -- was the language changed?
  local languageChanged = Lua:getSelectedLanguage() ~= oldLanguage
  if values.userLanguage ~= Lua:getSelectedLanguage() then
    -- the system chose another one, set back to automatic
    languageChanged = true
    values.userLanguage = ''
  end
  --print(' - languageChanged >> ' .. tostring(languageChanged) .. ' | "' .. tostring(Lua:getSelectedLanguage()) .. '" ~= ' .. tostring(oldLanguage))

  -- send the new state to the UI
  if languageChanged or M.newTranslationsAvailable then
    sendUIState()
    if ui_imgui and ui_imgui.ctx ~= nil then
      for index=0, ui_imgui.IoFontsGetCount() - 1 do
        if string.startswith(ffi.string(ui_imgui.IoFontsGetName(index)), translateLanguage("ui.fonts.filename", "segoeui.ttf")) then
          log("D", "settings", "set font: " .. ffi.string(ui_imgui.IoFontsGetName(index)))
          ui_imgui.SetDefaultFont(index)
          break
        end
      end
    end
  end
end

local function setState(newState, ignoreCache)
  if newState == nil then return end
  local isChanged = false
  for k, s in pairs(newState) do
    if values[k] == nil or (tostring(s) ~= tostring(values[k]))  then
      isChanged = true
      values[k] = s
      if options[k] and type(options[k].set) == 'function' then
        options[k].set(s)
      end
    end
  end

  if not isChanged and not ignoreCache then return end

  -- get valid state from TS
  refreshTSState(true)
  save()

  -- we can update the dynamic collision state on the fly
  if values.disableDynamicCollision ~= nil then
    be:setDynamicCollisionEnabled(not values.disableDynamicCollision)
  end

  if values.unfocusedInput         ~= nil then WinInput.setUnfocusedInput (values.unfocusedInput)        end
  if values.multiseatTags          ~= nil then be.multiseatTags          = values.multiseat and values.multiseatTags end

  if shipping_build then
    values.replayLevel            = nil
    values.interpolateAlternative = nil
    values.interpolateLua         = nil
    values.interpolateFull        = nil
  end

  if values.replayLevel            ~= nil then be.replayLevel            = values.replayLevel            end
  if values.replayAlpha            ~= nil then be.replayAlpha            = values.replayAlpha            end
  if values.replayA                ~= nil then be.replayA                = values.replayA                end
  if values.replayB                ~= nil then be.replayB                = values.replayB                end
  if values.replayC                ~= nil then be.replayC                = values.replayC                end
  if values.replayD                ~= nil then be.replayD                = values.replayD                end
  if values.replayE                ~= nil then be.replayE                = values.replayE                end
  if values.replayF                ~= nil then be.replayF                = values.replayF                end
  if values.replayG                ~= nil then be.replayG                = values.replayG                end
  if values.replayH                ~= nil then be.replayH                = values.replayH                end
  if values.replayI                ~= nil then be.replayI                = values.replayI                end
  if values.replayJ                ~= nil then be.replayJ                = values.replayJ                end
  if values.replayK                ~= nil then be.replayK                = values.replayK                end
  if values.replayL                ~= nil then be.replayL                = values.replayL                end
  if values.replayM                ~= nil then be.replayM                = values.replayM                end
  if values.replayN                ~= nil then be.replayN                = values.replayN                end
  if values.replayO                ~= nil then be.replayO                = values.replayO                end
  if values.replayP                ~= nil then be.replayP                = values.replayP                end
  --if values.replayQ                ~= nil then be.replayQ                = values.replayQ                end
  --if values.replayR                ~= nil then be.replayR                = values.replayR                end

  if values.interpolatePosition    ~= nil then be.interpolatePosition    = values.interpolatePosition    end
  if values.interpolateAlternative ~= nil then be.interpolateAlternative = values.interpolateAlternative end
  if values.interpolateFull        ~= nil then be.interpolateFull        = values.interpolateFull        end
  if values.interpolateLua         ~= nil then be.interpolateLua         = values.interpolateLua         end

  refreshLanguages()
end

local function setValue(key, value, ignoreCache)
  local newValues = deepcopy(values)
  newValues[key] = value
  setState(newValues, ignoreCache)
end

local function getValue(key, defaultValue)
  if values[key] == nil then
    return defaultValue
  end
  return values[key]
end

local function loadSettingValues()
  local data = loadIni(persistencyfile) or {}
  local cloudData = loadIni(persistencyfileCloud) or {}
  -- log("D", "settings.loadSettingValues_local", dumps(data))
  -- log("D", "settings.loadSettingValues_cloud", dumps(cloudData))
  tableMerge(data, cloudData)

  return data
end

local function load(ignoreCache)
  -- fix the options up and compbine the keys and values into the dict
  for k,v in pairs(options) do
    if v.keys and v.values and not v.dict then
      v.dict = {}
      for i = 0, tableSizeC(v.keys) - 1 do
        v.dict[v.keys[i]] = v.values[i]
      end
    end
  end

  tableMerge(options, extensions.core_settings_graphic.buildOptionHelpers())
  tableMerge(options, extensions.core_settings_audio.buildOptionHelpers())
  tableMerge(options, extensions.core_settings_gameplay.buildOptionHelpers())
  core_settings_graphic.options = options

  -- ensure translation.zip is mounted before reloading the languages
  local translationsFilename = '/mods/translations.zip'
  if FS:fileExists(translationsFilename) and not FS:isMounted(translationsFilename) then
    FS:mount(translationsFilename)
  end

  refreshTSState(true)
  local newState = deepcopy(values)
  local data = loadSettingValues()
  if data then
    tableMerge(newState, defaultValues)
    tableMerge(newState, data)
  end

  --refreshTSState(true)
  -- log("D", "settings.load", dumps(newState))
  setState(newState, ignoreCache)
  core_settings_graphic.load(newState)
  --dump(data)
end

local function reload()
  refreshTSState(true)
  save()
end

local function initSettings()
  -- load the persistency file at least
  local data = loadSettingValues()
  if data then
    tableMerge(values, data)
  end

  extensions.core_settings_graphic.onInitSettings(data)
end

local function onFirstUpdate()
  -- force application of all settings the first time, since init() has not correctly applied all of them
  -- we could make init() call load(), but that would fail because it's still too early, and some stuff is not initialized yet
  load(true)
  extensions.core_settings_graphic.onFirstUpdateSettings(values)
  extensions.core_settings_audio.onFirstUpdateSettings()

  if values.onlineFeatures == 'enable' and values.telemetry == 'enable' then
    extensions.load('telemetry/gameTelemetry')
    telemetry_gameTelemetry.startTelemetry()
  end
end

local function onFileChanged(filename, type)
  if filename == persistencyfile and (os.clock()-lastSavedTime) > 5 then
    load(false)
  end
end

M.onFirstUpdate = onFirstUpdate
M.onFileChanged = onFileChanged
M.requestState = sendUIState
M.refreshTSState = refreshTSState
M.setState = setState
M.setValue = setValue
M.getValue = getValue
M.reload = reload
M.save = save
M.load = load
M.initSettings = initSettings

return M
