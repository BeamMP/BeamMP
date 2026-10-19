export default function (deps) {
  const { SysInfo } = deps || {}

  let initialValues = {}
  const setInitialValues = values => initialValues = values

  // named boolean conditions for the layout
  // DO NOT change names! if you do - edit layout.json with a new name
  const conditions = {
    // conditions with __ prefix will be grouped under "Special" group in the UI
    __gameState_menu() {
      return !SysInfo.gameState.value
    },
    __gameState_game() {
      return !!SysInfo.gameState.value
    },

    userLanguageIsAuto(values) {
      return !values.userLanguage
    },
    communityTranslationsEnabled(values) {
      return values.communityTranslations === "enable"
    },
    communityTranslationsEnabledProvider(values) {
      // originally it included values.communityTranslations === "enable"
      return values.userLanguageSelected !== values.languageProvider
    },
    communityTranslationsEnabledOS(values) {
      // originally it included values.communityTranslations === "enable"
      return values.userLanguageSelected !== values.languageOS
    },
    richPresenceEnabled(values) {
      return values.richPresence === "enable"
    },
    externalUiEnabled(values) {
      return values.externalUI2 === "enable"
    },
    uiUnitsCustom(values) {
      return values.uiUnits === "custom"
    },
    runningOnSteamDeck(values) {
      return values.runningOnSteamDeck
    },
    graphicsDisplayModeWindow(values) {
      return values.GraphicDisplayModes === "Window"
    },
    graphicsDisplayModeNotWindow(values) {
      return values.GraphicDisplayModes !== "Window"
    },
    graphicsDisplayModeFullscreen(values) {
      return values.GraphicDisplayModes === "Fullscreen"
    },
    graphicsDisplayModeNotFullscreen(values) {
      return values.GraphicDisplayModes !== "Fullscreen"
    },
    graphicsDisplayModeNotBorderless(values) {
      return values.GraphicDisplayModes !== "Borderless"
    },
    graphicTripleMonitorEnabled(values) {
      return values.GraphicTripleMonitorEnabled
    },
    fpsLimitEnabled(values) {
      return values.fpsLimitEnabled
    },
    fpsLimitCustom(values) {
      return values.fpsLimitState === "custom"
    },
    fpsLimitBackgroundEnabled(values) {
      return values.fpsLimitBackgroundEnabled
    },
    fpsLimitBackgroundCustom(values) {
      return values.fpsLimitBackgroundState === "custom"
    },
    openXRenabled(values) {
      return !!values.openXRenabled
    },
    openXRsnapTurnUnicycle(values) {
      return values.openXRsnapTurnUnicycle
    },
    openXRenabledSnapTurnUnicycle(values) {
      return !!values.openXRenabled && values.openXRsnapTurnUnicycle
    },
    openXRenabledResolutionScaleChanged(values) {
      return !!values.openXRenabled && values.openXRresolutionScaleChanged
    },
    openXRuseControllers(values) {
      return values.openXRuseControllers
    },
    openXRuiEnabled(values) {
      return values.openXRuiEnabled
    },
    GraphicAntialiasEnabled(values) {
      return values.GraphicAntialiasType !== "off"
    },
    GraphicUpscalingSharpnessSupported(values) {
      return ["dlss", "fsr3", "fsr4", "xess", "fsrCustom", "pssr"].includes(values.GraphicAntialiasType)
    },
    GraphicLightingQualityLowest(values) {
      return values.GraphicLightingQuality === "Lowest"
    },
    GraphicLightingQualityNotLowest(values) {
      return values.GraphicLightingQuality !== "Lowest"
    },
    GraphicLightingQualityAdvanced15(values) {
      return values.GraphicLightingQuality === "High" ||
             values.GraphicLightingQuality === "Ultra"
    },
    SpecularOcclusionAvailable(values) {
      return (values.GraphicLightingQuality === "High" || values.GraphicLightingQuality === "Ultra") &&
        values.PostFXSSAOGeneralQuality !== "Off" && values.PostFXSSAOGeneralEnabled !== false
    },
    GraphicLightingQualityNotAdvanced15(values) {
      return values.GraphicLightingQuality !== "High" &&
             values.GraphicLightingQuality !== "Ultra"
    },
    GraphicShadowsQualityEnabled(values) {
      return values.GraphicLightingQuality !== "Lowest" &&
             values.GraphicShadowsQuality !== "Disabled"
    },
    GraphicShadowsQualityDisabled(values) {
      return values.GraphicLightingQuality === "Lowest" ||
             values.GraphicShadowsQuality === "Disabled"
    },
    GraphicDynReflectionEnabled(values) {
      return values.GraphicDynReflectionQuality !== "Disabled"
    },
    GraphicDynReflectionFacesPerupdateTooBig(values) {
      return values.GraphicDynReflectionQuality !== "Disabled" &&
             values.GraphicDynReflectionFacesPerupdate > 2
    },
    GraphicHDRSupported(values) {
      return values.GraphicHDRSupported
    },
    GraphicHDRUnsupported(values) {
      return !values.GraphicHDRSupported
    },
    GraphicHDRToggleEnabled(values) {
      return values.GraphicHDRSupported || values.GraphicHDREnabled
    },
    GraphicHDREnabled(values) {
      return values.GraphicHDRSupported && values.GraphicHDREnabled
    },
    GraphicHDRisHDR10(values) {
      return values.GraphicHDRSupported && values.GraphicHDREnabled && values.GraphicHDROutputModeName === "HDR10"
    },
    PostFXSSRAvailable(values) {
      return !!values.PostFXSSRAvailable &&
             (values.GraphicLightingQuality === "High" || values.GraphicLightingQuality === "Ultra")
    },
    PostFXSSRNotAvailableSM6(values) {
      return !values.PostFXSSRAvailable &&
             (values.GraphicLightingQuality === "High" || values.GraphicLightingQuality === "Ultra")
    },
    PostFXSSRNotAvailableLighting(values) {
      return !!values.PostFXSSRAvailable &&
             values.GraphicLightingQuality !== "High" && values.GraphicLightingQuality !== "Ultra"
    },
    PostFXSSRandLightingNotAvailable(values) {
      return !values.PostFXSSRAvailable &&
             values.GraphicLightingQuality !== "High" && values.GraphicLightingQuality !== "Ultra"
    },
    PostFXScreenSpaceShadowsAvailable(values) {
      return values.PostFXScreenSpaceShadowsAvailable &&
             values.GraphicLightingQuality !== "Lowest" &&
             values.GraphicShadowsQuality !== "Disabled"
    },
    PostFXScreenSpaceShadowsNotAvailableSM6(values) {
      return !values.PostFXScreenSpaceShadowsAvailable &&
             values.GraphicLightingQuality !== "Lowest" &&
             values.GraphicShadowsQuality !== "Disabled"
    },
    PostFXScreenSpaceShadowsNotAvailableLighting(values) {
      return values.PostFXScreenSpaceShadowsAvailable &&
             (values.GraphicLightingQuality === "Lowest" ||
              values.GraphicShadowsQuality === "Disabled")
    },
    PostFXScreenSpaceShadowsandLightingNotAvailable(values) {
      return !values.PostFXScreenSpaceShadowsAvailable &&
             (values.GraphicLightingQuality === "Lowest" ||
              values.GraphicShadowsQuality === "Disabled")
    },
    PostFXMotionBlurEnabled(values) {
      return values.PostFXMotionBlurEnabled
    },
    GraphicMaxDecalCountTooBig(values) {
      return values.GraphicMaxDecalCount > 10000
    },
    cameraDriverAllowSeatAdjustments(values) {
      return values.cameraDriverAllowSeatAdjustments
    },
    enableMissionReplayCapModeCount(values) {
      return values.enableMissionReplayCapModes === "count"
    },
    enableMissionReplayCapModeMaxSize(values) {
      return values.enableMissionReplayCapModes === "maxSize"
    },
    protocols_outgauge_enabled(values) {
      return values.protocols_outgauge_enabled
    },
    protocols_motionSim_enabled(values) {
      return values.protocols_motionSim_enabled
    },
    protocols_motionSim_others_enabled(values) {
      return values.protocols_motionSim_enabled || values.protocols_others_enabled
    },
    onlineFeaturesEnabled(values) {
      return values.onlineFeatures === "enable"
    },
    multiseat(values) {
      return values.multiseat
    },
    workbenchFilesPresent() { return SysInfo.workbenchFilesPresent.value },
    steeringStabilizationEnabled(values) {
      return values.steeringStabilizationEnabled
    },
    steeringUndersteerReductionEnabled(values) {
      return values.steeringUndersteerReductionEnabled
    },
    steeringSlowdownEnabled(values) {
      return values.steeringSlowdownEnabled
    },
    steeringLimitEnabled(values) {
      return values.steeringLimitEnabled
    },
    trafficExtraVehicles(values) {
      return values.trafficExtraVehicles
    },
    trafficParkedVehicles(values) {
      return values.trafficParkedVehicles
    },
    trafficAmountAuto(values) {
      return values.trafficAmount === 0
    },
    trafficAmountManual(values) {
      return values.trafficAmount > 0
    },
    trafficExtraAmountAuto(values) {
      return values.trafficExtraVehicles && values.trafficExtraAmount === 0
    },
    trafficExtraAmountManual(values) {
      return values.trafficExtraVehicles && values.trafficExtraAmount > 0
    },
    trafficParkedAmountAuto(values) {
      return values.trafficParkedVehicles && values.trafficParkingAmount === 0
    },
    trafficParkedAmountManual(values) {
      return values.trafficParkedVehicles && values.trafficParkingAmount > 0
    },
    AudioFmodEnableDebugLogging(values) {
      return values.AudioFmodEnableDebugLogging
    },
    multiplayerAvailable() {
      return SysInfo.multiplayerAvailable.value
    },
    multiplayerOptionsAvailable(values) {
      return values.onlineFeatures === "enable" && SysInfo.multiplayerAvailable.value
    },
    mpNametagsEnabled(values) {
      return values.mpNametagsEnabled
    },
    mpUseCustomServiceURL(values) {
      return values.mpUseCustomServiceURL
    },
    uiLayoutContentWidthMatch(values) {
      return !!values.uiLayoutContentWidthMatch
    },
    uiLayoutContentWidthManual(values) {
      return !values.uiLayoutContentWidthMatch
    },

    beammpEnableSpawnQueueEnabled(values) {
        return values.enableSpawnQueue===true
    },
    beammpEnableQueueAutoEnabled(values) {
        return values.enableQueueAuto===true
    },
    beammpEnableBlobs(values) {
        return values.enableBlobs===true
    },
    beammpShowBlobQueued(values) {
        return values.showBlobQueued===true
    },
    beammpShowBlobIllegal(values) {
        return values.showBlobIllegal===true
    },
    beammpShowBlobDeleted(values) {
        return values.showBlobDeleted===true
    },
    beammpNametagsEnabled(values) {
        return values.hideNameTags===false
    },
    beammpShortenNametagsEnabled(values) {
        return values.shortenNametags===true
    },
    beammpShowSpectatorsEnabled(values) {
        return values.showSpectators===true
    },
    beammpNameTagFadeEnabled(values) {
        return values.nameTagFadeEnabled===true
    },
  }

  return { setInitialValues, conditions, initialValues }
}
