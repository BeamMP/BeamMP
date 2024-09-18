angular.module("beamng.stuff", ["ngAnimate", "toastr"])
angular.module("beamng.gameUI", ["ngAnimate", "toastr"])
angular.module("beamng.color", [])
angular.module("beamng.gamepadNav", [])
angular.module("beamng.controls", [])

angular
  .module("BeamNG.ui", [
    "beamng.core",
    "beamng.components",
    "beamng.data",
    "ngMaterial",
    "ngAnimate",
    "ui.router",
    "beamng.stuff",
    "beamng.gameUI",
    "beamng.apps",
    "beamng.color",
    "pascalprecht.translate",
    "beamng.gamepadNav",
    "beamng.controls",
    "fc.paging",
    "ngSanitize",
    "jkAngularRatingStars",
    "ngFitText",
  ])

  .config([
    "$compileProvider",
    "$logProvider",
    "$stateProvider",
    "$urlRouterProvider",
    "$mdThemingProvider",
    "$translateProvider",
    "toastrConfig",
    "$provide",
    function ($compileProvider, $logProvider, $stateProvider, $urlRouterProvider, $mdThemingProvider, $translateProvider, toastrConfig, $provide) {
      $translateProvider.useStaticFilesLoader({
        prefix: "/locales/",
        suffix: ".json",
      })
      $translateProvider.useSanitizeValueStrategy("escaped")
      $translateProvider.preferredLanguage("en-US") // this is the default language to load
      // this is the fallback in case individual translations are missing:
      if (beamng.shipping) {
        $translateProvider.fallbackLanguage("en-US")
      } else {
        $translateProvider.fallbackLanguage(["en-US", "not-shipping.internal"])
      }
      //$translateProvider.use('de-DE')

      MARK_TRANSLATIONS = 1 // force translation markers AUTO
      //MARK_TRANSLATIONS = 1 // force translation markers OFF
      //MARK_TRANSLATIONS = 2 // force translation markers ON (quiet)
      //MARK_TRANSLATIONS = 3 // force translation markers ON (verbose)

      $logProvider.debugEnabled(false)

      // ..... User Interface states
      $stateProvider

        .state("play", {
          url: "/play",
          templateUrl: "/ui/modules/play/play.html",
          controller: "PlayController as playCtrl",
          menuActionMapEnabled: false, // defaults to true
          uiAppsShown: true, // defaults to false
        })

        .state("menu", {
          url: "/menu",
          templateUrl: "/ui/modules/menu/menu.html",
          controller: "MenuController as menuCtrl",
          uiLayout: "menu",
          uiAppsShown: true, // defaults to false
        })

        // so the trick is: we load the real menu in the background in another view while the startscreen is covering it up
        // This ensures that everything is properly loaded before we switch to it.
        // Ideally, no dom changes are required then :)
        // more docs to read: https://github.com/angular-ui/ui-router/wiki/Multiple-Named-Views#view-names---relative-vs-absolute-names
        // this is a three stage process right now:
        // 1) load menu.start which just loads the startscreen
        // 2) the controller will navigate after some tiny bit to 'menu.start_loadmainmenu'
        // 3) the controller will navigate after 3 seconds to 'menu.mainmenu'
        // this process ensures that:
        //  a) BeamNG Logo is not perceived as 'lagging' as the mainmenu is loading at the same time.
        //  b) Mainmenu can load safely with the start screen fully done with everything.

        .state("menu.start", {
          loaderVisible: true,
          views: {
            "loader@": {
              // target the loader view in parent menu state
              templateUrl: "/ui/modules/startScreen/startScreen.html",
              controller: "startScreenController as startScreen",
            },
            "@menu": {},
          },
        })

        .state("menu.start_loadmainmenu", {
          loaderVisible: true,
          views: {
            "loader@": {
              // target the loader view in parent menu state
              templateUrl: "/ui/modules/startScreen/startScreen.html",
              controller: "startScreenController as startScreen",
            },
            "@menu": {
              // target the unnamed view in parent menu state
              templateUrl: "/ui/modules/menu/menu.html",
              controller: "MenuController as menuCtrl",
            },
          },
          transitionAnimation: "moduleBlendOnLeave",
        })

        .state("menu.mainmenu", {
          views: {
            loader: {}, // empty the loader view
            "@menu": {
              // targe the unnamed default view in the menu parent state
              templateUrl: `/ui/modules/mainmenu/drive/mainmenu.html`,
              controller: "MainMenuController as mmCtrl",
            },
          },
        })

        .state("menu.onlineFeatures", {
          url: "/onlineFeatures",
          templateUrl: `/ui/modules/onlineFeatures/online.html`,
          controller: "OnlineFeaturesController",
          backState: "menu.mainmenu",
        })

        .state("menu.bigmap", {
          url: "/bigmap",
          templateUrl: "/ui/modules/bigmap/bigmap.html",
          controller: "BigMapController",
          backState: "BACK_TO_MENU",
          params: {
            missionId: null,
          },
          careerUiLayout: "careerBigMap",
          uiLayout: "blank",
          uiAppsShown: true, // defaults to false
        })

        .state("menu.levels", {
          url: "/levels",
          templateUrl: "/ui/modules/levelselect/levelselect.html",
          controller: "LevelSelectController as lsCtrl",
          backState: "menu.mainmenu",
        })

        .state("menu.levelDetails", {
          url: "/levels-details/:levelName",
          templateUrl: "/ui/modules/levelselect/levelselect-details.html",
          controller: "LevelSelectDetailsController as levelsDetails",
          backState: "menu.levels",
        })

        .state("menu.busRoutes", {
          url: "/bus",
          templateUrl: "/ui/modules/busRoute/busRoute.html",
          controller: "BusRoutesController as busCtrl",
          backState: "menu.mainmenu",
        })

        .state("menu.busRoutesLevelSelect", {
          url: "/bus/level",
          templateUrl: "/ui/modules/busRoute/levelSelect.html",
          controller: "BusRoutesLevelController",
          backState: "menu.busRoutes",
        })

        // .state('menu.busRoutesVehicleSelect', {
        //   url: '/bus/vehicle/:garage/:mode/:event',
        //   templateUrl: '/ui/modules/vehicleselect/vehicleselect.html',
        //   controller: 'VehicleSelectController as vehicles',
        //   backState: 'menu.busRoutes',
        // })

        .state("menu.busRoutesRouteSelect", {
          url: "/bus/route",
          templateUrl: "/ui/modules/busRoute/routeSelect.html",
          controller: "BusRoutesRouteController",
          backState: "menu.busRoutes",
        })

        .state("menu.environment", {
          url: "/environment",
          templateUrl: "/ui/modules/environment/environment.html",
          controller: "EnvironmentController as environment",
          backState: "BACK_TO_MENU",
        })

        // Track Builder
        // .state('menu.trackBuilder', {
        //   url: '/trackBuilder',
        //   templateUrl: '/ui/modules/trackBuilder/trackBuilder.html',
        //   controller:  'TrackBuilderController as trackBuilder'
        // })

        .state("menu.scenarios", {
          url: "/scenarios",
          templateUrl: "/ui/modules/scenarioselect/scenarioselect.html",
          controller: "ScenarioSelectController",
          backState: "menu.mainmenu",
        })

        .state("menu.campaigns", {
          url: "/campaigns",
          templateUrl: "/ui/modules/campaignselect/campaignselect.html",
          controller: "CampaignSelectController as campaignSelect",
          backState: "menu.mainmenu",
        })

        .state("menu.appedit", {
          url: "/appedit/:mode",
          templateUrl: "/ui/modules/appedit/appedit.html",
          controller: "AppEditController as ctrl",
          backState: "BACK_TO_MENU",
          uiAppsShown: true, // defaults to false
        })

        .state("menu.appselect", {
          url: "/appselect",
          templateUrl: "/ui/modules/appselect/appselect.html",
          controller: "AppSelectController as apps",
          backState: "menu.appedit",
        })

        .state("menu.vehicles", {
          url: "/vehicleselect/:garage/:mode/:event",
          templateUrl: "/ui/modules/vehicleselect/vehicleselect.html",
          controller: "VehicleSelectController as vehicles",
          backState($scope, $state, $stateParams) {
            if ($scope.gameState === "garage") return "garagemode"
            if ($stateParams && $stateParams.hasOwnProperty("mode")) {
              switch ($stateParams.mode) {
                case "busRoutes":
                  return "menu.busRoutes"
                case "lightRunner":
                  return "menu.lightrunnerOverview"
                case "quickrace":
                  return "menu.quickraceOverview"
              }
            }
            return "BACK_TO_MENU"
          },
        })

        .state("menu.vehiclesdetails", {
          url: "/vehicle-details/:model/:config/:mode/:event/{showAuxiliary:bool}",
          templateUrl: "/ui/modules/vehicleselect/vehicleselect-details.html",
          controller: "VehicleDetailsController as vehicle",
          backState: "menu.vehicles",
        })

        // -------------------------------------- BEAMMP -------------------------------------- //
        .state('menu.multiplayer', {
          url: '/multiplayer',
          templateUrl: '/ui/modules/multiplayer/multiplayer.html',
          controller: 'MultiplayerController as multiplayer',
          backState: 'BACK_TO_MENU',
          abstract: true
        })
        .state('menu.multiplayer.tos', {
          url: '/mptos',
          templateUrl: '/ui/modules/multiplayer/tos.partial.html',
          controller: 'MultiplayerTOSController as multiplayertos',
          backState: 'BACK_TO_MENU'
        })
        .state('menu.multiplayer.launcher', {
          url: '/mplauncher',
          templateUrl: '/ui/modules/multiplayer/launcher.partial.html',
          controller: 'MultiplayerLauncherController as multiplayerlauncher',
          backState: 'BACK_TO_MENU'
        })
        .state('menu.multiplayer.login', {
          url: '/mplogin',
          templateUrl: '/ui/modules/multiplayer/login.partial.html',
          controller: 'MultiplayerLoginController as multiplayerlogin',
          backState: 'BACK_TO_MENU'
        })
        .state('menu.multiplayer.servers', {
          url: '/mpservers',
          templateUrl: '/ui/modules/multiplayer/servers.partial.html',
          controller: 'MultiplayerServersController as multiplayermenu',
          backState: 'BACK_TO_MENU'
        })
        .state('menu.multiplayer.official', {
          url: '/mpofficial',
          templateUrl: '/ui/modules/multiplayer/official.partial.html',
          controller: 'MultiplayerOfficialController as multiplayermenu',
          backState: 'BACK_TO_MENU'
        })
        .state('menu.multiplayer.featured', {
          url: '/mpfeatured',
          templateUrl: '/ui/modules/multiplayer/featured.partial.html',
          controller: 'MultiplayerFeaturedController as multiplayermenu',
          backState: 'BACK_TO_MENU'
        })
        .state('menu.multiplayer.partner', {
          url: '/mppartner',
          templateUrl: '/ui/modules/multiplayer/partner.partial.html',
          controller: 'MultiplayerPartnerController as multiplayermenu',
          backState: 'BACK_TO_MENU'
        })
        .state('menu.multiplayer.recent', {
          url: '/mprecent',
          templateUrl: '/ui/modules/multiplayer/recent.partial.html',
          controller: 'MultiplayerRecentController as multiplayermenu',
          backState: 'BACK_TO_MENU'
        })
        .state('menu.multiplayer.favorites', {
          url: '/mpfavorites',
          templateUrl: '/ui/modules/multiplayer/favorites.partial.html',
          controller: 'MultiplayerFavoritesController as multiplayermenu',
          backState: 'BACK_TO_MENU'
        })
        .state('menu.multiplayer.direct', {
          url: '/mpdirect',
          templateUrl: '/ui/modules/multiplayer/direct.partial.html',
          controller: 'MultiplayerDirectController as multiplayermenu',
          backState: 'BACK_TO_MENU'
        })
        // -------------------------------------- BEAMMP -------------------------------------- //

        .state("menu.options", {
          url: "/options",
          templateUrl: "/ui/modules/options/options.html",
          controller: "OptionsController",
          controllerAs: "options",
          backState: "BACK_TO_MENU",
          abstract: true,
        })
        // -------------------------------------- BEAMMP -------------------------------------- //
        .state('menu.options.multiplayer', {
          url: '/multiplayer',
          templateUrl: '/ui/modules/options/multiplayer.partial.html',
          backState: 'BACK_TO_MENU',
        })
        // -------------------------------------- BEAMMP -------------------------------------- //
        .state("menu.options.help", {
          url: "/help",
          templateUrl: "/ui/modules/options/help.partial.html",
          controller: "SettingsHelpCtrl as opt",
          backState: "BACK_TO_MENU",
        })
        .state("menu.options.performance", {
          url: "/performance",
          templateUrl: "/ui/modules/options/performance.partial.html",
          controller: "SettingsPerformanceCtrl as opt",
          backState: "BACK_TO_MENU",
        })
        .state("menu.options.display", {
          url: "/display",
          templateUrl: "/ui/modules/options/display.partial.html",
          controller: "SettingsGraphicsCtrl as opt",
          backState: "BACK_TO_MENU",
        })
        .state("menu.options.graphics", {
          url: "/graphics",
          templateUrl: "/ui/modules/options/graphics.partial.html",
          controller: "SettingsGraphicsCtrl as opt",
          backState: "BACK_TO_MENU",
        })

        .state("menu.options.audio", {
          url: "/audio",
          templateUrl: "/ui/modules/options/audio.partial.html",
          controller: "SettingsAudioCtrl as opt",
          backState: "BACK_TO_MENU",
        })

        .state("menu.options.gameplay", {
          url: "/gameplay",
          templateUrl: "/ui/modules/options/gameplay.partial.html",
          controller: "SettingsGameplayCtrl as opt",
          backState: "BACK_TO_MENU",
        })

        .state("menu.options.camera", {
          url: "/camera",
          templateUrl: "/ui/modules/options/camera.partial.html",
          controller: "SettingsCameraCtrl as opt",
          backState: "BACK_TO_MENU",
        })

        .state("menu.options.userInterface", {
          url: "/userInterface",
          templateUrl: "/ui/modules/options/userinterface.partial.html",
          controller: "SettingsUserInterfaceCtrl as opt",
          backState: "BACK_TO_MENU",
        })

        .state("menu.options.language", {
          url: "/language",
          templateUrl: "/ui/modules/options/language.partial.html",
          controller: "SettingsLanguageCtrl as opt",
          backState: "BACK_TO_MENU",
        })

        .state("menu.options.stats", {
          url: "/stat:category",
          templateUrl: "/ui/modules/stat/stats.html",
          controller: "StatsController as statCtrl",
          backState: "menu.mainmenu",
        })

        .state("menu.options.other", {
          url: "/other",
          templateUrl: "/ui/modules/options/other.partial.html",
          controller: "SettingsOtherCtrl as opt",
          backState: "BACK_TO_MENU",
        })

        .state("menu.options.licenses", {
          url: "/licenses",
          templateUrl: "/ui/modules/options/licenses.partial.html",
          controller: "SettingsLicensesCtrl as opt",
          backState: "BACK_TO_MENU",
        })

        .state("menu.options.controls", {
          url: "/controls",
          templateUrl: "/ui/modules/options/controls.html",
          controller: "ControlsController as controls",
          backState: "BACK_TO_MENU",
        })
        .state("menu.options.controls.bindings", {
          views: {
            "": {
              url: "/bindings",
              templateUrl: "/ui/modules/options/controls-bindings.html",
              controller: "ControlsBindingsCtrl as controlsBindings",
            },
          },
          backState: "BACK_TO_MENU",
        })
        .state("menu.options.controls.bindings.edit", {
          views: {
            "edit@menu.options": {
              url: "/edit",
              templateUrl: "/ui/modules/options/controls-edit.html",
              controller: "ControlsEditCtrl as controlsEdit",
            },
          },
          params: { action: "", oldBinding: {} },
          backState: "BACK_TO_MENU",
        })

        .state("menu.options.controls.filters", {
          views: {
            "": {
              url: "/filters",
              templateUrl: "/ui/modules/options/controls-filters.html",
              controller: "ControlsFiltersCtrl as controlsFilters",
            },
          },
          backState: "BACK_TO_MENU",
        })

        .state("menu.options.controls.ffb", {
          views: {
            "": {
              url: "/ffb",
              templateUrl: "/ui/modules/options/controls-ffb.html",
              controller: "ControlsFfbCtrl as controlsFfb",
            },
          },
          backState: "BACK_TO_MENU",
        })

        .state("menu.options.controls.ffb.edit", {
          views: {
            "edit@menu.options": {
              url: "/edit",
              templateUrl: "/ui/modules/options/controls-edit.html",
              controller: "ControlsEditCtrl as controlsEdit",
            },
          },
          params: { action: "", oldBinding: {} },
          backState: "BACK_TO_MENU",
        })

        .state("menu.options.controls.hardware", {
          views: {
            "": {
              url: "/hardware",
              templateUrl: "/ui/modules/options/controls-hardware.html",
              controller: "ControlsHardwareCtrl as controlsHw",
            },
          },
          backState: "BACK_TO_MENU",
        })

        .state("menu.vehicleconfig", {
          url: "/vehicle-config",
          templateUrl: "/ui/modules/vehicleconfig/vehicleconfig.html",
          controller: "VehicleconfigCtrl",
          redirectTo: "menu.vehicleconfig.parts",
          backState($scope, $state, $stateParams) {
            if ($scope.gameState === "garage") return "garagemode"
            return "BACK_TO_MENU"
          },
        })
        .state("menu.vehicleconfig.parts", {
          url: "/vehicle-config/parts",
          templateUrl: "/ui/modules/vehicleconfig/partial.parts.html",
          controller: "Vehicleconfig_parts as vehConf_parts",
          backState($scope, $state, $stateParams) {
            if ($scope.gameState === "garage") return "garagemode"
            return "BACK_TO_MENU"
          },
          uiAppsShown: true, // defaults to false
        })
        .state("menu.vehicleconfig.tuning", {
          url: "/vehicle-config/tuning",
          templateUrl: "/ui/modules/vehicleconfig/partial.tuning.html",
          controller: "Vehicleconfig_tuning as vehConf_tuning",
          backState($scope, $state, $stateParams) {
            if ($scope.gameState === "garage") return "garagemode"
            return "BACK_TO_MENU"
          },
          uiAppsShown: true, // defaults to false
        })
        .state("menu.vehicleconfig.color", {
          url: "/vehicle-config/color",
          templateUrl: "/ui/modules/vehicleconfig/partial.color.html",
          controller: "Vehicleconfig_color as vehConf_color",
          backState($scope, $state, $stateParams) {
            if ($scope.gameState === "garage") return "garagemode"
            return "BACK_TO_MENU"
          },
        })
        .state("menu.vehicleconfig.save", {
          url: "/vehicle-config/save",
          templateUrl: "/ui/modules/vehicleconfig/partial.save.html",
          controller: "Vehicleconfig_save as vehConf_save",
          backState($scope, $state, $stateParams) {
            if ($scope.gameState === "garage") return "garagemode"
            return "BACK_TO_MENU"
          },
        })
        .state("menu.vehicleconfig.debug", {
          url: "/vehicle-config/debug",
          templateUrl: "/ui/modules/vehicleconfig/debug.partial.html",
          controller: "Vehicleconfig_debug as vehConf_debug",
          backState($scope, $state, $stateParams) {
            if ($scope.gameState === "garage") return "garagemode"
            return "BACK_TO_MENU"
          },
          uiAppsShown: true, // defaults to false
        })

        .state("menu.vehicleconfig.vue", {
          url: "/vehicle-config/vue",
          uiAppsShown: true, // defaults to false
        })
        .state("menu.vehicleconfig.vue.tuning", {
          url: "/vehicle-config/vue/tuning",
          uiAppsShown: true, // defaults to false
        })
        // the following is to force angular menu to show up
        .state("menu.vehicleconfig.vue-angular", {
          url: "/vehicle-config/vue-angular",
          redirectTo: "menu.vehicleconfig.vue",
          uiAppsShown: true, // defaults to false
        })
        .state("menu.vehicleconfig.vue-angular.tuning", {
          url: "/vehicle-config/vue-angular/tuning",
          redirectTo: "menu.vehicleconfig.vue.tuning",
          uiAppsShown: true, // defaults to false
        })

        .state("menu.mods", {
          url: "/mods",
          template: '<ui-view class="filler" style="position: relative;"></ui-view>',
          abstract: true,
          controller: "ModManagerController as modCtrl",
          backState: "BACK_TO_MENU",
        })

        .state("menu.mods.local", {
          url: "/local",
          views: {
            "": {
              controller: "LocalModController as modLoclCtrl",
              templateUrl: "/ui/modules/modmanager/mods.html",
            },
            "content@menu.mods.local": {
              templateUrl: "/ui/modules/modmanager/local.html",
            },
            "filter@menu.mods.local": {
              templateUrl: "/ui/modules/modmanager/filter.html",
            },
          },
          backState: "BACK_TO_MENU",
        })

        .state("menu.mods.downloaded", {
          url: "/downloaded",
          views: {
            "": {
              controller: "DownloadModController as modDwlCtrl",
              templateUrl: "/ui/modules/modmanager/mods.html",
            },
            "content@menu.mods.downloaded": {
              templateUrl: "/ui/modules/modmanager/downloaded.html",
            },
          },
          backState: "BACK_TO_MENU",
        })

        .state("menu.mods.scheduled", {
          url: "/scheduled",
          views: {
            "": {
              controller: "ScheduledModController as modSchCtrl",
              templateUrl: "/ui/modules/modmanager/mods.html",
            },
            "content@menu.mods.scheduled": {
              templateUrl: "/ui/modules/modmanager/scheduled.html",
            },
            "filter@menu.mods.scheduled": {
              templateUrl: "/ui/modules/modmanager/scheduled_conflict.html",
            },
          },
          backState: "BACK_TO_MENU",
        })

        .state("menu.mods.repository", {
          url: "/repository?query",
          views: {
            "": {
              controller: "RepositoryController as repo",
              templateUrl: "/ui/modules/modmanager/mods.html",
            },
            "content@menu.mods.repository": {
              templateUrl: "/ui/modules/repository/repository.html",
            },
            "filter@menu.mods.repository": {
              templateUrl: "/ui/modules/repository/filter.html",
            },
          },
          backState: "BACK_TO_MENU",
        })

        .state("menu.mods.automation", {
          url: "/automation?query",
          views: {
            "": {
              controller: "AutomationController as automation",
              templateUrl: "/ui/modules/modmanager/mods.html",
            },
            "content@menu.mods.automation": {
              templateUrl: "/ui/modules/automation/automation.html",
            },
            "filter@menu.mods.automation": {
              templateUrl: "/ui/modules/automation/filter.html",
            },
          },
          backState: "BACK_TO_MENU",
        })

        .state("menu.mods.automationDetails", {
          url: "/automation/detail/{modId:[0-9A-Z]+}?page&param",
          views: {
            "": {
              controller: "AutomationDetailsController as automationDetailCtrl",
              templateUrl: "/ui/modules/modmanager/mods.html",
            },
            "content@menu.mods.automationDetails": {
              templateUrl: "/ui/modules/automation/automation-details.html",
            },
            "filter@menu.mods.automationDetails": {
              templateUrl: "/ui/modules/automation/info.html",
            },
          },
          backState: "BACK_TO_MENU",
        })

        .state("menu.mods.details", {
          url: "/detail/{modId:[0-9A-Z]+}?page&param",
          views: {
            "": {
              controller: "RepositoryDetailsController as repoDetailCtrl",
              templateUrl: "/ui/modules/modmanager/mods.html",
            },
            "content@menu.mods.details": {
              templateUrl: "/ui/modules/repository/repository-details.html",
            },
            "filter@menu.mods.details": {
              templateUrl: "/ui/modules/repository/info.html",
            },
          },
          backState: "menu.mods.repository",
        })

        .state("menu.modsDetails", {
          url: "/modmanager/details:modFilePath",
          templateUrl: "/ui/modules/modmanager/info.html",
          controller: "ModManagerControllerDetails as managerDetailCtrl",
          backState: "menu.mods.repository",
        })

        .state("menu.gameContext", {
          url: "/gameContext",
          templateUrl: "/ui/modules/gameContext/gameContext.html",
          controller: "GameContextController",
          backState: "BACK_TO_MENU",
        })

        .state("scenario-start", {
          url: "/scenariocontrol/start",
          params: {
            data: {},
          },
          templateUrl: "/ui/modules/scenariocontrol/start.html",
          controller: "ScenarioStartController as scenarioStart",
          backState: "BACK_TO_MENU",
          uiLayout: "blank",
          uiAppsShown: true,
        })

        .state("scenario-end", {
          url: "/scenariocontrol/end",
          params: {
            missionData: {},
            stats: {},
            rewards: {},
            portrait: {},
          },
          templateUrl: "/ui/modules/scenariocontrol/end.html",
          controller: "ScenarioEndController",
          backState: "BACK_TO_MENU",
          careerUiLayout: "careerMissionEnd",
          uiAppsShown: true,
        })

        .state("quickrace-end", {
          url: "/quickraceEnd",
          params: {
            stats: {},
            mockScenario: {},
          },
          templateUrl: "/ui/modules/scenariocontrol/quickraceEnd.html",
          controller: "ScenarioEndController",
          backState: "BACK_TO_MENU",
        })

        .state("chapter-end", {
          url: "/cchapterEnd",
          params: {
            stats: {},
          },
          templateUrl: "/ui/modules/scenariocontrol/end.html",
          controller: "ScenarioEndController",
          backState: "BACK_TO_MENU",
        })

        // Transition to this state is handled by some unknown dark force (Torque?).
        // Until this chanages, keep the url hash to "loading".
        .state("loading", {
          url: "/loading",
          templateUrl: "/ui/modules/loading/loading.html",
          controller: "LoadingController as loading",
          transitionAnimation: "moduleBlendOnLeave",
          backState: "BLOCK",
        })

        .state("comic", {
          url: "/comic",
          params: {
            comiclist: {},
          },
          templateUrl: "/ui/modules/comic/comic.html",
          controller: "ComicController",
          backState: null,
        })

        .state("menu.photomode", {
          url: "/photo-mode",
          templateUrl: "/ui/modules/photomode/photomode.html",
          controller: "PhotoModeController as photo",
          backState: "BACK_TO_MENU",
          backState($scope, $state, $stateParams) {
            if ($scope.gameState === "garage") return "garagemode"
            return "BACK_TO_MENU"
          },
        })

        .state("menu.replay", {
          url: "/replay",
          templateUrl: "/ui/modules/replay/replay.html",
          controller: "ReplayController as replay",
          backState: "BACK_TO_MENU",
        })

        .state("blank", {
          uiAppsShown: true,
        })

        .state("iconViewer", {
          url: "/iconViewer",
          templateUrl: "/ui/modules/iconView/icons.html",
          controller: "iconViewerCtrl as iconCtrl",
          backState: "BACK_TO_MENU",
        })

        .state("fadeScreen", {
          url: "/fadeScreen",
          templateUrl: "/ui/modules/fadeScreen/fadeScreen.html",
          params: {
            fadeIn: 1,
            pause: 0,
            fadeOut: 1,
            data: {},
          },
          controller: "fadeScreen",
          backState: "BLOCK",
        })

        .state("mapview", {
          url: "/mapview",
          templateUrl: "/ui/modules/mapview/mapview.html",
          controller: "MapViewCtrl as mapview",
          params: {
            data: {},
          },
          backState: "BACK_TO_MENU",
          // params: {
          //   baseImg: '',
          //   points: [],
          //   onClick: ''
          // }
        })

        //Dragrace states WIP
        .state("menu.dragRaceOverview", {
          url: "/dragrace/overview",
          templateUrl: "/ui/modules/dragrace/overview.html",
          controller: "DragRaceController",
          params: {
            results: {},
            cinematicEnabled: true,
          },
          backState: "BACK_TO_MENU",
        })

        // LightRunner States
        .state("menu.lightrunnerOverview", {
          url: "/lightrunner/overview",
          templateUrl: "/ui/modules/lightrunner/overview.html",
          controller: "LightRunnerController",
          backState: "BACK_TO_MENU",
        })

        .state("menu.lightrunnerTrackSelect", {
          url: "/lightrunner/track",
          templateUrl: "/ui/modules/lightrunner/trackSelect.html",
          controller: "LightRunnerTrackController",
          backState: "BACK_TO_MENU",
        })

        //Quickrace states WIP
        .state("menu.quickraceOverview", {
          url: "/quickrace/overview",
          templateUrl: "/ui/modules/quickrace/overview.html",
          controller: "QuickraceController",
          backState: "BACK_TO_MENU",
        })

        .state("menu.quickraceLevelselect", {
          url: "/quickrace/level",
          templateUrl: "/ui/modules/quickrace/levelSelect.html",
          controller: "QuickraceLevelController",
          backState: "menu.quickraceOverview",
        })

        .state("menu.quickraceTrackselect", {
          url: "/quickrace/track",
          templateUrl: "/ui/modules/quickrace/trackSelect.html",
          controller: "QuickraceTrackController",
          backState: "menu.quickraceLevelselect",
        })

        .state("campaign", {
          url: "/campaign",
          template: '<ui-view class="container"></ui-view>',
          backState: "BACK_TO_MENU",
        })

        .state("campaign.quickraceOverview", {
          url: "/quickrace/overview",
          params: {
            level: {},
            track: {},
            vehicles: {},
          },
          templateUrl: "/ui/modules/quickrace/overview.html",
          controller: "QuickraceController",
          backState: "BACK_TO_MENU",
        })

        .state("campaign.quickraceLevelselect", {
          url: "/quickrace/level",
          templateUrl: "/ui/modules/quickrace/levelSelect.html",
          controller: "QuickraceLevelController",
          backState: "BACK_TO_MENU",
        })

        .state("campaign.quickraceTrackselect", {
          url: "/quickrace/track",
          templateUrl: "/ui/modules/quickrace/trackSelect.html",
          controller: "QuickraceTrackController",
          backState: "BACK_TO_MENU",
        })

        .state("campaign.vehicles", {
          url: "/vehicleselect/:garage/:mode",
          templateUrl: "/ui/modules/vehicleselect/vehicleselect.html",
          controller: "VehicleSelectController as vehicles",
          backState: "BACK_TO_MENU",
        })

        .state("campaign.vehicleDetails", {
          url: "/vehicle-details/:model/:config/:mode",
          templateUrl: "/ui/modules/vehicleselect/vehicleselect-details.html",
          controller: "VehicleDetailsController as vehicle",
          backState: "BACK_TO_MENU",
        })

        // .state('garagemode', {
        //   url: '/garagemode',
        //   templateUrl: '/ui/modules/garage/garage.html',
        //   controller: 'GarageController as garageCtrl',
        //   // menuActionMapEnabled: false,
        //   uiAppsShown: true,
        //   uiLayout: 'garage',
        //   backState: "menu.mainmenu",
        // })

        .state("menu.career", {
          url: "/career",
          templateUrl: "/ui/modules/career/career.html",
          controller: "CareerController",
          backState: "BACK_TO_MENU",
        })

        .state("menu.careermission", {
          url: "/career-mission",
          templateUrl: "/ui/modules/careermission/mission.html",
          controller: "GameContextController",
          params: {
            isCareer: true,
          },
          backState: "BACK_TO_MENU",
          uiLayout: "blank",
          uiAppsShown: true, // defaults to false,
        })

        .state("menu.careerPause", {
          url: "/careerPause",
          templateUrl: "/ui/modules/careerPause/careerPause.html",
          controller: "CareerPauseController",
          backState: "BACK_TO_MENU",
          //careerUiLayout: 'careerPause',
          uiAppsShown: true,
        })

        .state("menu.careerQuests", {
          url: "/career-quest",
          templateUrl: "/ui/modules/careerQuests/questsOverview.html",
          controller: "QuestOverviewController",
          params: {
            questId: undefined,
          },
          backState: "BACK_TO_MENU",
        })

        .state("menu.careerVehicleSelect", {
          url: "/careerVehicleSelect",
          templateUrl: "/ui/modules/careerVehicleSelect/careerVehicleSelect.html",
          params: {
            data: {},
          },
          //uiAppsShown: false,
          controller: "CareerVehicleSelectController",
          backState: "BACK_TO_MENU",
        })

        .state("menu.threeElementSelect", {
          url: "/threeElementSelect",
          templateUrl: "/ui/modules/threeElementSelect/threeElementSelect.html",
          params: {
            data: {},
          },
          //uiAppsShown: false,
          controller: "ThreeElementSelectController",
          backState: "BACK_TO_MENU",
        })

      // REMOVED as it seems unnecessary and causes Vue screens to be zapped by the URL '/menu.start' occasionally
      // default entry that is loaded on startup:
      //$urlRouterProvider.otherwise('menu.start')

      $compileProvider.debugInfoEnabled(false)

      // whitelist for local:// prefix
      $compileProvider.aHrefSanitizationWhitelist(/^\s*(https?|ftp|mailto|local|file):/)
      $compileProvider.imgSrcSanitizationWhitelist(/^\s*(https?|ftp|mailto|local|file):/)

      let theme = $mdThemingProvider.theme("default")
      theme.dark()

      $mdThemingProvider.definePalette("customPrimary", {
        50: "#ffffff",
        100: "#e9e9e9",
        200: "#d3d3d3",
        300: "#bebebe",
        400: "#a9a9a9",
        500: "#959595",
        600: "#818181",
        700: "#6d6d6d",
        800: "#5b5b5b",
        900: "#484848",
        A100: "#373737",
        A200: "#262626", // ### hue-3
        A400: "#171717", // ### hue-2
        A700: "#000000",
        contrastDefaultColor: "dark",
        contrastLightColors: ["600", "700", "800", "900", "A100", "A200", "A400", "A700"],
      })
      theme.primaryPalette("customPrimary", {
        default: "800", // by default use shade A800 from the custom palette for primary intentions
        "hue-1": "A100", // use shade A900 for the <code>md-hue-1</code> class
        "hue-2": "A400", // use shade A400 for the <code>md-hue-2</code> class
        "hue-3": "50", // use shade A100 for the <code>md-hue-3</code> class
      })

      $mdThemingProvider.definePalette("customAccent", {
        50: "#662800",
        100: "#803200",
        200: "#993c00",
        300: "#b34600",
        400: "#cc5000",
        500: "#e65a00",
        600: "#ff741a",
        700: "#ff8333",
        800: "#ff934d",
        900: "#ffa266",
        A100: "#ff741a",
        A200: "#ff6400",
        A400: "#e65a00",
        A700: "#ffb280",
        contrastDefaultColor: "dark",
        contrastLightColors: ["500", "600", "700", "800", "900", "A100", "A200", "A400", "A700"],
      })
      theme.accentPalette("customAccent", {
        default: "500",
        "hue-1": "300",
        "hue-2": "800",
        "hue-3": "A100",
      })

      $mdThemingProvider.definePalette("customWarn", {
        50: "#ff7b82",
        100: "#ff626a",
        200: "#ff4852",
        300: "#ff2f3a",
        400: "#ff1522",
        500: "#fb000d",
        600: "#e1000c",
        700: "#c8000a",
        800: "#ae0009",
        900: "#950008",
        A100: "#ff959a",
        A200: "#ffaeb3",
        A400: "#ffc8cb",
        A700: "#7b0006",
        contrastDefaultColor: "dark",
        contrastLightColors: ["300", "400", "500", "600", "700", "800", "900", "A200", "A400", "A700"],
      })
      theme.warnPalette("customWarn", {
        default: "400",
        "hue-1": "500",
        "hue-2": "100",
        "hue-3": "A700",
      })

      $mdThemingProvider.definePalette("customBackground", {
        50: "rgba(35,35,35,0.35)",
        100: "rgba(35,35,35,0.4)",
        //workaround for now, no clue why checkboxes are using '200'
        //200': 'rgba(35,35,35,0.45)',
        200: "#FFF",
        300: "rgba(35,35,35,0.5)",
        400: "rgba(35,35,35,0.55)",
        500: "rgba(35,35,35,0.6)",
        600: "rgba(35,35,35,0.65)",
        700: "rgba(35,35,35,0.7)",
        800: "rgba(35,35,35,0.75)",
        900: "rgba(35,35,35,0.8)",
        A100: "rgba(35,35,35,0.85)",
        A200: "rgba(35,35,35,0.9)",
        A400: "rgba(35,35,35,0.95)",
        A700: "rgba(35,35,35,1)",
        contrastDefaultColor: "light",
      })
      theme.backgroundPalette("customBackground", {
        default: "A400",
        "hue-1": "300",
        "hue-2": "600",
        "hue-3": "900",
      })

      // debug with this:
      //console.log("UI theme setup: ", $mdThemingProvider)

      angular.extend(toastrConfig, {
        autoDismiss: false,
        containerId: "toast-container",
        maxOpened: 10,
        newestOnTop: true,
        positionClass: "toast-top-right",
        preventOpenDuplicates: true,
        allowHtml: true,
      })
    },
  ])

  .run([
    "$animate",
    "$http",
    "$rootScope",
    "$templateCache",
    "$window",
    "$translate",
    "UIAppStorage",
    "Settings",
    "SettingsAuxData",
    "bngWSApi",
    "$state",
    function ($animate, $http, $rootScope, $templateCache, $window, $translate, UIAppStorage, Settings, SettingsAuxData, bngWSApi, $state) {
      // apply language settings
      $rootScope.$on("SettingsChanged", function (evt, data) {
        if (data.values.uiLanguage) {
          let lang = data.values.uiLanguage
          if (lang == "") lang = "en-US"
          $http.get(`/locales/${lang}.json`).then(function (res) {
            vueI18n.global.locale = lang
            vueI18n.global.setLocaleMessage(lang, window.bngVue.preprocessLocaleJSON(res.data))
          })
        }
      })

      // Check for server to join
      $rootScope.$on('AutoJoinConfirmation', function(evt, data) {
        console.log('AutoJoinConfirmation',evt,data)
        var d = JSON.parse(decodeURI(data.message))
        confirmationMessage = `Do you want to connect to the server at ${d.ip}:${d.port}?`
        userConfirmed = window.confirm(confirmationMessage); 
        //userConfirmed ? alert('Connecting to the server...') : alert('Connection canceled.');
        if (userConfirmed) {
          bngApi.engineLua(`MPCoreNetwork.connectToServer("${d.ip}","${d.port}","${d.sname}")`);
        }
      })

      $http.get("/ui/modules/vehicleconfig/vehicle-config-tree.html").then(function (tmpl) {
        $templateCache.put("vehicle-config-tree", tmpl.data)
      })

      $http.get("/ui/assets/sprites/svg-symbols.svg").success(svgSprite => {
        var iconsSprite = angular.element(svgSprite)
        angular.element(document.head).append(iconsSprite)
      })

      window.globalAngularRootScope = $rootScope

      /* --- VUE3 START --- */
      // i18n vue3 basics
      window.bngVue &&
        window.bngVue.start({
          i18n: vueI18n,
        })
      i18NLanguageFinished = true

      /* --- VUE3 END --- */
      $rootScope.$on("$translateChangeSuccess", (event, data) => {
        i18nLanguageUsed = data.language
      })

      $rootScope.$on("$translateChangeStart", () => {
        i18NLanguageFinished = false
      })

      $rootScope.$on("$translateChangeEnd", () => {
        i18NLanguageFinished = true
      })

      /*
  $rootScope.$on('$translateChangeError', () => { console.log('translateChangeError')})
  $rootScope.$on('$translateLoadingStart', () => { console.log('translateLoadingStart')})
  $rootScope.$on('$translateLoadingSuccess', () => { console.log('translateLoadingSuccess')})
  $rootScope.$on('$translateLoadingError', () => { console.log('translateLoadingError')})
  $rootScope.$on('$translateLoadingEnd', () => { console.log('translateLoadingEnd')})
  $rootScope.$on('$translatePartialLoaderStructureChanged', () => { console.log('translatePartialLoaderStructureChanged')})
  */

      //$animate.enabled(false)

      bngApi.engineLua("ui_apps.requestUIAppsData()")

      // ..... Define all objects attached directly to the window object here

      /**
       * HookManager is maybe the most important object to share status between
       * the game and the user interface. Common usage from the game modules looks
       * like HookManager.trigger(<event name>, <data>). In order to catch these events
       * inside a controller, one has to set up a listener like
       *
       * @example
       * $scope.$on('EventName', function (event, data) {
       *   // do all kinds of stuff with data...
       * })
       *
       * Angular's event system manages the listener's removal on the $destroy event of
       * the current scope.
       **/

      // listen to the window resize event. Maybe this can also be handled from the CEF side.
      angular.element($window).bind("resize", function () {
        var size = { width: window.innerWidth, height: window.innerHeight }
        $rootScope.$broadcast("windowResize", size)
      })

      // This should not be a function attached to the window object, but rather a HookManager event.
      // Until this is done, we just mock up the process.
      // $window.updateProgress = function(val, txt) {
      //   $rootScope.$broadcast('UpdateProgress', {value: Math.floor(100 * val), text: txt })
      // }

      // Update game state each time a route change is triggered.
      // Maybe an overkill, but why not be sure?
      //$rootScope.$on('$stateChangeSuccess', function (event, toState, toStateParams) {
      //})

      // // settings storage for simple consumers in JS
      // $rootScope.Settings = null
      // $rootScope.$on('SettingsChanged', function (event, data) {
      //   $rootScope.Settings = data
      // })

      // use this to imitate settings lag
      // let lag = false;
      $rootScope.$on("SettingsChanged", function (event, data) {
        // if (lag)
        //   Settings.loaded = true;
        // lag = true;
        Settings.loaded = true // flag Settings as loaded
        Settings.options = data.options
        Settings.values = data.values
      })

      bngApi.engineLua("settings.notifyUI()")
      bngApi.engineLua("core_gamestate.requestMainMenuState()")
      bngApi.engineLua("core_gamestate.requestGameState()")
      // bngApi.engineLua('print("requesting gamestate here and now")')

      // settings storage end

      // navigate to start pages
      if (beamng.shipping && beamng.ingame && beamng.buildtype === "RELEASE") {
        $state.go("menu.start")
      } else {
        $state.go("menu.mainmenu")
      }

      // set browser-ui background
      if (!beamng.ingame) {
        const el = document.body || document.getElementsByTagName("body")[0]
        el.style.backgroundImage = 'url("/ui/modules/mainmenu/drive/tech_images/1_blur.jpg")'
        el.style.backgroundSize = "cover"
        el.style.backgroundPosition = "50% 50%"
      }
    },
  ])

  //------------Trying filter for date translation --------- put on separate file!!!

  .filter("formattedDate", function (dateFilter, $translate) {
    var format = null,
      translated = false

    function returnFilter(inputDate) {
      if (format) {
        return dateFilter(inputDate, format)
      } else {
        return "-"
      }
    }

    function formattedDateFilter(inputDate) {
      if (format === null) {
        if (!translated) {
          translated = true
          $translate("general.time_format").then(
            function (result) {
              format = result
            },
            function (translationId) {
              format = translationId
            }
          )
        }
      } else return returnFilter(inputDate)
    }

    formattedDateFilter.$stateful = true
    return formattedDateFilter
  })

angular
  .module("beamng.stuff")

  .service("translateService", [
    "$translate",
    function ($translate) {
      // super hacky workaround to allow use of $translate in our new Vue stuff...
      // (at least temporarily in areas where translation strings containing AngularJS interpolation syntax are
      // shared between AngularJS and Vue areas)
      window.angular$translate = $translate

      const contextTranslate = function (val, translateContext) {
        if (typeof val == "string") {
          return $translate.instant(val)
        } else {
          if (val && val.txt && val.context) {
            let context = val.context
            if (translateContext) {
              let newContext = {}
              for (let key in context) {
                if (context.hasOwnProperty(key)) {
                  newContext[key] = contextTranslate(context[key], true)
                }
              }
              context = newContext
            }
            return $translate.instant(val.txt, context)
          }
        }
        return val
      }
      const multiContextTranslate = function (val) {
        if (val.txt) {
          return contextTranslate(val)
        }
        let description = ""
        for (var i = 0; i < val.length; i++) {
          description = description + contextTranslate(val[i])
        }
        return description
      }
      return {
        contextTranslate: contextTranslate,
        multiContextTranslate: multiContextTranslate,
      }
    },
  ])

  .filter("contextTranslate", [
    "translateService",
    function ($translateService) {
      function contextTranslateFilter(input) {
        return $translateService.contextTranslate(input, true)
      }

      contextTranslateFilter.$stateful = true
      return contextTranslateFilter
    },
  ])

  .service("gamepadNav", [
    "$rootScope",
    function ($rootScope) {
      "use strict"

      const UINav = () => (window.bridge && window.bridge.uiNavEvents) || {}

      // TODO: hook this up to lua settings
      // TODO: think about using a list of actions, so when one module unregisters it's action the old action gets used.
      // this would have the benefit for example of dropdowns beeing opened, and while open their actions would be used
      // todo: actually test the list approach
      // let useCrossfire = true

      let useGamepadNavigation = false
      let noop = () => {}
      let actions = {
        up: [{ module: "root", func: noop }],
        down: [{ module: "root", func: noop }],
        right: [{ module: "root", func: noop }],
        left: [{ module: "root", func: noop }],
        confirm: [{ module: "root", func: noop }],
        back: [{ module: "root", func: noop }],
      }
      let prefix = {
        up: "menu_item_up",
        down: "menu_item_down",
        right: "menu_item_right",
        left: "menu_item_left",
        confirm: "menu_item_select",
        back: "menu_item_back",
        "radial-x": "menu_item_radial_x",
        "radial-y": "menu_item_radial_y",
        "radial-right-x": "menu_item_radial_right_x",
        "radial-right-y": "menu_item_radial_right_y",
        "tab-right": "menu_tab_right",
        "tab-left": "menu_tab_left",
      }

      function assignNavFunc(module, data) {
        for (var name in data) {
          if (actions[name] !== undefined) {
            if (nonAssignable.indexOf(name) === -1) {
              actions[name].push({ module: module, func: data[name] })
              // console.debug('Registered new function to "' + name+ '"')
            } else {
              // console.error('"' + name + '" is an unchangable action')
            }
          } else {
            // console.error('"' + name + '" is not a valid action')
          }
        }
      }

      function unregisterActions(module, data) {
        for (var name in data) {
          if (actions[name] !== undefined) {
            var helper = actions[name].map(elem => elem.module)
            if (helper.indexOf(module) !== -1) {
              if (nonAssignable.indexOf(name) === -1) {
                actions[name].splice(helper.indexOf(module), 1)
                // console.debug('Succesfully unregistered "' + name+ '"')
              } else {
                // console.error('"' + name + '" is an unchangable action')
              }
            } else {
              // console.error('Could not unregister "' + name + '" because there was no registered action from this modul')
            }
          } else {
            // console.warn('Could not unregister "' + name + '" because it is not a valid action')
          }
        }
      }

      // const navActions = ["left", "right", "up", "down"];
      // const scrollActions = {
      //   "radial-right-x": "horizontal",
      //   "radial-right-y": "vertical",
      // };

      $rootScope.$on("MenuItemNavigation", function (event, action, val) {
        // console.log('MenuItemNavigation - Got action: ' + action, val)
        //console.log('Enabled Librarys', useCrossfire, useGamepadNavigation)
        if (!beamng.ingame) return

        // NOTE - this needs to stay for now. Used quite a lot
        if (action == "toggleMenues") {
          console.log("received MenuItemNavigation 'toggleMenues' action")
          $rootScope.$broadcast("MenuToggle", val)
          return
        }

        // TODO - remove when tested - Crossfire now fed from UINavEvents
        // if(action == 'back') {
        //   console.log("received MenuItemNavigation 'back' action")
        //   $rootScope.$broadcast('MenuToggle')
        //   return
        // }

        // TODO - remove when tested - Crossfire now fed from UINavEvents
        // if (navActions.includes(action)) {
        //   bngApi.engineLua('extensions.hook("onMenuItemNavigation")')
        // }

        // if (useCrossfire) {

        // TODO - remove when tested - Crossfire now fed from UINavEvents
        // if (action == 'confirm') {
        //   const active = document.activeElement;
        //   if (isNavigatable(active)) {
        //     if (typeof active.click === "function") {
        //       active.click()
        //     } else {
        //       let click = new CustomEvent("click")
        //       active.dispatchEvent(click)
        //     }
        //   }
        // } else if(action == 'back') {
        //
        //

        // // Is this even used??? If action='back' it will have been handled above
        // if (action == 'back') {
        //   console.log("received MenuItemNavigation 'back' action (crossfire)")
        //   $rootScope.$broadcast('MenuToggle')

        //}

        // TODO - remove when tested - Crossfire now fed from UINavEvents
        // } else if (navActions.includes(action)) {
        //   const targets = collectRects(action);
        //   navigate(targets, action);
        //   //console.log(`navigation ${action} handled by Crossfire`)

        // TODO - remove when tested - Crossfire now fed from UINavEvents
        // } else if (scrollActions.hasOwnProperty(action)) {
        //   navigateScroll(scrollActions[action], val);
        // } else if (action == 'tab-left') {
        // if (action == 'tab-left') {
        //     $rootScope.$broadcast('$tabLeft')
        // } else if (action == 'tab-right') {
        //     $rootScope.$broadcast('$tabRight')
        // }
        // }

        // TODO - check what this is? Is it used?
        if (useGamepadNavigation && actions[action]) {
          //console.log(actions[action])
          // console.log(actions[action][0])
          $rootScope.$evalAsync(actions[action][0].func)
        }
      })

      return {
        // crossfireEnabled: () => useCrossfire,
        crossfireEnabled: () => UINav().useCrossfire,
        gamepadNavEnabled: () => useGamepadNavigation,
        // spatialNavEnabled: () => useCrossfire,
        spatialNavEnabled: () => UINav().useCrossfire,
        // // TODO: make this intuitive (omiting the value shouldn't do something unexpected)
        // enableCrossfire: (val) => useCrossfire = val,
        enableCrossfire: (val = true) => (UINav().useCrossfire = val),
        enableGamepadNav: (val = true) => (useGamepadNavigation = val),
        // enableSpatialNav: (val) => { log.error("SpatialNavigation is deprecated. Please use Crossfire."); useCrossfire = val },
        enableSpatialNav: (val = true) => {
          log.error("SpatialNavigation is deprecated. Please use Crossfire.")
          UINav().useCrossfire = val
        },

        // TODO - Find out what these are???
        registerActions: assignNavFunc,
        unregisterActions: unregisterActions,

        provideScope: scope => (scope = scope),
        prefix: val => prefix[val] || val,
      }
    },
  ])

  /**
   * @ngdoc controller
   * @name beamng.stuff.controller:AppCtrl
   * @description This is the top-level controller used throughout the game
   **/
  .controller("AppCtrl", [
    "$document",
    "$log",
    "$rootScope",
    "$scope",
    "$sce",
    "$compile",
    "$state",
    "$stateParams",
    "$translate",
    "$window",
    "ControlsUtils",
    "Utils",
    "Settings",
    "toastr",
    "$timeout",
    "gamepadNav",
    "$injector",
    "$location",
    "translateService",
    "UiAppsService",
    "MessageToasterService",
    "InputCapturer",
    "ConfirmationDialog",
    function (
      $document,
      $log,
      $rootScope,
      $scope,
      $sce,
      $compile,
      $state,
      $stateParams,
      $translate,
      $window,
      ControlsUtils,
      Utils,
      Settings,
      toastr,
      $timeout,
      gamepadNav,
      $injector,
      $location,
      translateService,
      UiAppsService,
      messageToasterService,
      InputCapturer,
      ConfirmationDialog
    ) {
      var vm = this
      vm.uiSheetActive = false

      // hack to fix backspace navigating between different menus.
      // https://stackoverflow.com/questions/29006000/prevent-backspace-from-navigating-back-in-angularjs
      $document.on("keydown", function (e) {
        if (e.which === 8 && e.target.nodeName !== "INPUT" && e.target.nodeName !== "TEXTAREA" && e.target.nodeName !== "SELECT") {
          // you can add others here inside brackets.
          e.preventDefault()
        }
      })

      // // Attempted fix to prevent keyboard events getting through to game when a textbox is being edited
      // // Unfortunately causes other issues, but this may be on the right lines. Commented for now as it causes
      // // more issues, and probably doesn't address some instances where the problem occurs. Related ticket is GE-4138

      // $document.on('mouseup', function(e){
      //   $timeout(() => {
      //     vm.uiSheetActive = ["INPUT", "TEXTAREA"].includes(document.activeElement.tagName) ? true : false;
      //   }, 10);
      // })

      // Handle "Messages" of the category 'career' with MessageToasterService
      messageToasterService.handledCategories = ["career"]
      messageToasterService.active = true

      setTimeout(() => {
        gamepadNav.provideScope($scope)
      })

      bngApi.engineLua('extensions.hook("onUIInitialised")')

      $scope.$on("requestUIInitialised", () => {
        bngApi.engineLua("core_gamestate.onUIInitialised()")
      })

      vm.shipping = beamng.shipping
      vm.uitest = false
      vm.uitestshow = false

      // on CEF devtools toggle
      $scope.$on("onCEFDevToolsVisibility", (event, enabled) => {
        $scope.$applyAsync(function () {
          vm.uitest = enabled
          bngVue.debug(enabled)
          vm.translationMarkCycle(0)
        })
      })

      let openDialogs = {}
      $scope.$on("ConfirmationDialogOpen", function (event, title, body, buttonOkText, buttonOkLua, buttonCancelText, buttonCancelLua) {
        let def = false
        let buttons = []
        if (typeof buttonCancelText == "string" && typeof buttonCancelLua == "string") {
          buttons.push({ label: buttonCancelText, key: "cancel", default: def, isCancel: true })
          def = true
        }
        if (typeof buttonOkText == "string" && typeof buttonOkLua == "string") {
          buttons.push({ label: buttonOkText, key: "ok", default: def, isCancel: false })
        }
        openDialogs[title] = ConfirmationDialog.open(title, body, buttons, { class: "leftAlignPrompt" })
        openDialogs[title].then(res => {
          delete openDialogs[title]
          if (res === "cancel") {
            bngApi.engineLua(buttonCancelLua)
          } else if (res === "ok") {
            bngApi.engineLua(buttonOkLua)
          } else if (res === undefined) {
            // do nothing special, just let it close
          } else {
            console.log("Unrecognized ConfirmationDialog return value: " + res)
          }
        })
      })

      $scope.$on("ConfirmationDialogClose", function (event, title) {
        openDialogs[title].close()
      })

      // figure out if CEF devtools are already open
      bngApi.engineLua("getCefDevConsoleOpen()", enabled => {
        $scope.$applyAsync(function () {
          vm.uitest = enabled
          bngVue.debug(enabled)
          vm.translationMarkCycle(0)
        })
      })

      // *** DEBUG START
      vm.currentStateName = ""
      vm.stickyPlayState = null

      $scope.$state = $state
      vm.states = $state.get().filter(state => !state.abstract) // filter abstract states
      //console.log("vm.states = ", vm.states)

      vm.emitMenuNav = function (action, val) {
        $rootScope.$broadcast("MenuItemNavigation", action, val)
      }
      vm.switchState = function (stateName, params) {
        if (stateName !== undefined) {
          $state.go(stateName, params)
        }
      }
      vm.prevState = function () {
        if (vm.currentStateName === "") vm.currentStateName = vm.states[0].name
        let nextStateIdx = -1
        for (let i in vm.states) {
          if (vm.states[i].name == vm.currentStateName) {
            nextStateIdx = parseInt(i) - 1
            if (nextStateIdx < 0) nextStateIdx = vm.states.length - 1
            break
          }
        }
        if (nextStateIdx != -1) {
          console.log("Switching to new state: " + vm.states[nextStateIdx].name)
          $state.go(vm.states[nextStateIdx].name)
        }
      }
      vm.translationMark = MARK_TRANSLATIONS
      vm.translationMarkCycle = function (amount) {
        vm.translationMark = (vm.translationMark + amount) % 4
        if (vm.translationMark == 0) {
          MARK_TRANSLATIONS = vm.uitest ? 2 : 1
        } else {
          MARK_TRANSLATIONS = vm.translationMark
        }
      }
      vm.nextState = function () {
        if (vm.currentStateName === "") vm.currentStateName = vm.states[0].name
        let nextStateIdx = -1
        for (let i in vm.states) {
          if (vm.states[i].name == vm.currentStateName) {
            nextStateIdx = parseInt(i) + 1
            if (nextStateIdx >= vm.states.length) nextStateIdx = 0
            break
          }
        }
        if (nextStateIdx != -1) {
          console.log("Switching to new state: " + vm.states[nextStateIdx].name)
          $state.go(vm.states[nextStateIdx].name)
        }
      }
      vm.reloadUI = function () {
        window.location.reload()
      }

      // shortcut for debugging
      window.openState = function (name) {
        console.log("Switching to new state: " + name)
        //bngApi.engineLua("ActionMap.enableInputCommands(false)")
        $state.go(name)
      }
      // *** DEBUG END

      vm.replayPaused = false
      vm.replayActive = false
      vm.physicsPaused = false
      vm.physicsMaybePaused = false
      vm.showPauseIcon = false
      vm.showCrosshair = false
      // vm.uiLayoutPrevious = false
      vm.playmodeState = null

      function updatePauseState() {
        vm.physicsPaused = !vm.replayActive && vm.physicsMaybePaused
        vm.showPauseIcon = vm.physicsPaused || vm.replayPaused
        //console.log("updatePauseState", $state.current.name, vm.showPauseIcon)
      }

      // quite a hack, but the alternative would have been to manage a list and wait for each state to be actiavated
      // the problem only occured because changeState was called almost simultaniously and before on state could be transitioned to the other ocnditinal was already executed next.
      // TODO change this to use the $state.transition promise
      var transitioningTo

      // Screens that tasklist UI app will be visible
      const captureInput = InputCapturer()
      $scope.$on("$stateChangeSuccess", function (event, toState, toParams, fromState, fromParams) {
        //console.log(`switching stage from ${fromState.name} to ${toState.name}`)
        //console.trace()
        vm.currentStateName = toState.name

        // make sure Vue sees all state changes that affect location hash
        if (toState.url && location.hash != toState.url) location.hash = toState.url

        // update activated action maps for UI bindings
        let menuActionMapEnabled = typeof $state.current.menuActionMapEnabled === "boolean" ? $state.current.menuActionMapEnabled : true // true by default
        // bngApi.engineLua(`extensions.core_input_bindings.setMenuActionMapEnabled(${menuActionMapEnabled})`)
        captureInput(menuActionMapEnabled)
        if (menuActionMapEnabled) window.bridge && window.bridge.uiNavEvents.clearFilteredEvents() // risky?

        bngApi.engineLua(`extensions.hook("onUiChangedState", "${toState.name}", "${fromState.name}")`)

        // bngApi.engineLua("career_career.isActive()", data => {
        //   if (data) {
        //     console.log(toState)
        //     if (toState.name == 'play') {
        //       console.log(menuActionMapEnabled)
        //       bngApi.engineLua(`simTimeAuthority.pause(${menuActionMapEnabled})`);
        //     }
        //     if (fromState.name == 'play') {
        //       console.log(menuActionMapEnabled)
        //       bngApi.engineLua(`simTimeAuthority.pause(${menuActionMapEnabled})`);
        //     }
        //   }
        // });

        // update ui apps layout
        bngApi.engineLua("career_career.isActive()", isCareerActive => {
          $scope.$evalAsync(() => {
            if (isCareerActive && $state.current.careerUiLayout) {
              $scope.$emit("appContainer:loadLayoutByType", $state.current.careerUiLayout)
              isUILayoutOverriden = true
            } else {
              if (vm.currentStateName === "blank") {
                // console.log('Current state name is blank. Ignoring layout update because this may be already handled ' +
                //   'ChangeState for Vue screens.')
              } else if ($state.current.uiLayout === "blank") {
                // console.log('Current layout name is blank. Clearing layout.')
                $scope.$emit("appContainer:clear")
                // $scope.$emit('appContainer:clear')
              } else if ($state.current.uiLayout === undefined) {
                // no particular ui layout defined, ensure we are in the default/previous one (whichever that may have been)
                // console.log(`No layout defined - using previous (${vm.uiLayoutPrevious})`)
                if (
                  vm.playmodeState &&
                  (vm.playmodeState.state || vm.playmodeState.appLayout) &&
                  // ignore menu.appselect from emitting layout to prevent issue menu.appedit
                  // selected layout will always be current game layout
                  vm.currentStateName !== "menu.appselect"
                ) {
                  if (typeof vm.playmodeState.appLayout === "string") {
                    $scope.$emit("appContainer:loadLayoutByType", vm.playmodeState.appLayout)
                  } else if (typeof vm.playmodeState.appLayout === "object") {
                    $scope.$emit("appContainer:loadLayoutByObject", vm.playmodeState.appLayout)
                  } else {
                    $scope.$emit("appContainer:loadLayoutByReqData", { type: vm.playmodeState.state })
                  }
                  // if (vm.uiLayoutPrevious) {
                  //   $scope.$emit('appContainer:loadLayoutByReqData', vm.uiLayoutPrevious)
                  //   vm.uiLayoutPrevious = null
                  // }
                }
              } else {
                // console.log(`Layout defined (${$state.current.uiLayout})`)

                // this state requires a particular ui layout, set
                // vm.uiLayoutPrevious = UiAppsService.getLayout()
                $scope.$emit("appContainer:loadLayoutByType", $state.current.uiLayout)
              }
            }

            // update ui apps visibility
            $scope.$emit("ShowApps", !!$state.current.uiAppsShown)

            $state.previous = fromState
            $state.previousArgs = fromParams

            if (fromState.name !== "menu" && fromState.name.indexOf("menu.") !== 0 && (toState.name === "menu" || toState.name.indexOf("menu.") === 0)) {
              $state.gamestate = fromState
              $state.gamestateArgs = fromParams
            }

            transitioningTo = undefined
            updatePauseState()
          })
        })
      })

      $scope.$on("GameStateUpdate", function (event, data) {
        vm.playmodeState = data
      })

      $scope.$on("setNavigationStickyPlayState", function (event, stateName) {
        vm.stickyPlayState = stateName
      })

      $scope.$on("$stateChangeCancel", function (event, toState, toParams, fromState, fromParams) {
        //console.warn('$stateChangeCancel', JSON.stringify({toState: toState, toParams: toParams, fromState: fromState, fromParams: fromParams}, null, '  '))
      })

      $scope.$on("$stateChangeError", function (event, toState, toParams, fromState, fromParams, error) {
        console.error("$stateChangeError", toState, toParams, fromState, fromParams, error)
      })

      vm.changeAngularStateFromVue = function (state, params) {
        vm.switchState(state, params)
      }

      const vueScreenUiAppLayoutMap = {
        refueling: {
          uiAppsShow: true,
          uiLayout: "tasklist",
        },
        computer: {
          uiAppsShow: true,
          uiLayout: "tasklist",
        },
        partShopping: {
          uiAppsShow: true,
          uiLayout: "tasklist",
        },
        vehicleShopping: {
          uiAppsShow: true,
          uiLayout: "tasklistTall",
        },
        cargoOverview: {
          uiAppsShow: false,
        },
        "mission-details": {
          uiAppsShow: false,
        },
      }
      $scope.$on("$stateNotFound", function (event, unfoundState, fromState, fromParams) {
        const unfoundStateTo = unfoundState.to
        const vueScreenConfig = vueScreenUiAppLayoutMap[unfoundStateTo]
        if (vueScreenConfig) {
          bngApi.engineLua("career_career.isActive()", isCareerActive => {
            if (isCareerActive && vueScreenConfig.uiAppsShow) {
              $scope.$emit("appContainer:loadLayoutByType", vueScreenConfig.uiLayout)
            } else if (isCareerActive) {
              $scope.$emit("appContainer:clear")
            }
          })
        }
        // angular doesn't recognise the state, so try Vue (making sure it doesn't pingpong back to here)
        bngVue.gotoGameState(unfoundState.to, { params: unfoundState.toParams, tryAngularJS: false })
        unfoundState.to = "blank"
      })

      $scope.$on("$stateChangeStart", function (event, toState, toParams, fromState, fromParams) {
        if (toState.name == "loading" && !beamng.ingame) {
          // in external UI: do not ever allow transitioning into the loading state
          event.preventDefault()
          return
        }
        newPageSilenceEventCounter = 2
        newPageTimestamp = Date.now()
        //console.log('stateChangeStart', toState, toParams, fromState, fromParams)
        //console.trace()
        transitioningTo = toState.name
        vm.transitionAnimation = toState.transitionAnimation || fromState.transitionAnimation // prefer the animation of the target state, otherwise use the state we came from
      })

      $scope.$on("ChangeState", function (event, target, ifCurrent) {
        let targetName = typeof target === "string" ? target : target.state
        let current = $state.current.name
        // console.log('received ForceStateChange w/', { targetName, ifCurrent, current, transitioningTo});
        // set current name if we're during a transition
        if (typeof transitioningTo !== "undefined" && transitioningTo !== current) {
          current = transitioningTo
        }

        // fix ifCurrent
        if (typeof ifCurrent !== "undefined" && !Array.isArray(ifCurrent)) {
          ifCurrent = [ifCurrent]
        }
        // console.log(current, ifCurrent, ifCurrent.includes(current));
        // decide if we're going to change state//
        if (!ifCurrent || ifCurrent.includes(current)) {
          // console.log(`switching to state: ${targetName}`);
          let params = target.params || {}

          let stateTransitioning = $state.go(targetName, params, { reload: true })
          // console.log("switched:", stateTransitioning);
        }
      })

      $scope.$on("onCrosshairVisibilityChanged", function (event, visible) {
        $scope.$applyAsync(function () {
          vm.showCrosshair = visible
        })
      })

      vm.showApps = true
      vm.uiVisible = true
      vm.mainmenu = true
      vm.gameState = null
      vm.ingame = beamng.ingame
      vm.settings = Settings
      vm.uiReady = false

      // downloader start
      var dlinfo = {}
      function cancelHelper(id, ctr) {
        if (dlinfo[id] && dlinfo[id][0] == 1) {
          // hacky fix to remove downloading toastr when it gets stuck.
          // This seems to be an issue with ngAnimate, more info here:
          // https://github.com/Foxandxss/angular-toastr/issues/136
          dlinfo[id][1].el[0].style.display = "none"
          toastr.clear(dlinfo[id][1])
          delete dlinfo[id]
        } else {
          if (ctr < 4) {
            // setTimeout(cancelHelper.bind(undefined, id, ctr + 1),200)
          }
        }
      }
      $window.downloadStateChanged = function (data) {
        if (data.filename == "") return

        //console.log('downloadStateChanged', data)
        if (data.state == "working" && !dlinfo[data.id]) {
          // the 0% is imporatne here, so the toaster library doesn't think the success msg later one to be a duplicate, so please leave it there
          var t = toastr.info(data.filename + ": 0%", "Downloading mod", {
            positionClass: "toast-top-right",
            timeOut: 0,
            extendedTimeOut: 0,
            // progressBar: true,
            closeButton: true,
            onTap: function () {
              $state.go("menu.mods.downloaded")
            },
          })
          dlinfo[data.id] = [1, t]
          console.warn(dlinfo[data.id])
        } else if (data.state == "working" && dlinfo[data.id][0] == 1) {
          $scope.$evalAsync(function () {
            if (dlinfo[data.id]) {
              dlinfo[data.id][1].scope.message = $sce.trustAsHtml(data.filename + ": " + Math.floor((data.dlnow / data.dltotal) * 100) + "%")
            }
          })
        } else if (data.state == "finished") {
          cancelHelper(data.id)

          var t = toastr.success(data.filename, "Downloaded mod", {
            positionClass: "toast-top-right",
            timeOut: 20000,
            closeButton: true,
            onTap: function () {
              var help = data.filename
              if (help.slice(-4) === ".zip") {
                help = help.slice(0, -4)
              }
              $state.go("menu.mods.downloaded", {
                // modFilePath: encodeURIComponent(help)
              })
            },
          })
        }
      }
      // downloader end

      // let Lua know the UI is up and running
      let ngLoaded = false,
        made2ndSettingsRequest = false
      function checkReadiness(canForce = false) {
        if (vm.uiReady)
          // may happen when SettingsChanged event fired twice at once and this function not yet evaluated
          return
        if (Settings.loaded) {
          lsnSettingsChange()
          if (ngLoaded) {
            // if this is false - either UI is still loading or broken due to mods
            bngApi.engineLua("uiReady()")
            vm.uiReady = true
          }
        } else if (!made2ndSettingsRequest) {
          // just to make sure, we'll send another request for settings but only once - we have a listener here anyway
          // to imitate lag, find line above with $rootScope.$on('SettingsChanged'
          // console.log("Settings are lagging behind...");
          bngApi.engineLua("settings.notifyUI()")
          made2ndSettingsRequest = true
        } else if (ngLoaded && canForce) {
          console.warn("Settings not being loaded after subsequent requests. This error should never happen. Forcing UI to show.")
          bngApi.engineLua("uiReady()")
          vm.uiReady = true
        }
      }
      let lsnSettingsChange = $scope.$on("SettingsChanged", () => {
        setTimeout(() => checkReadiness(true), 50)
      })
      angular.element(document).ready(() => {
        ngLoaded = true
        checkReadiness(true)
      })
      $scope.$on("isUIReady", function (event) {
        // is this ever firing?
        if (vm.uiReady) {
          bngApi.engineLua("uiReady()")
        } else {
          // not necessary, just for additional safety
          checkReadiness()
        }
      })

      $scope.$on("modmanagerError", function (event, data) {
        $scope.$emit("app:waiting", false)
        toastr.error(data, "Error in Modmanager", {
          positionClass: "toast-top-right",
          preventDuplicates: true,
          progressBar: true,
          timeOut: 10000,
          extendedTimeOut: 1000,
          closeButton: true,
        })
      })

      var toasts = {}

      $scope.$on("toastrMsg", function (ev, data) {
        toasts[data.title] = toastr[data.type]($translate.instant(data.msg, data.context), $translate.instant(data.title, data.context), data.config)
      })

      $scope.$on("toastrClose", function (ev, name) {
        toastr.clear(toasts[name])
        // delete toasts[name]
      })

      vm.sections = {
        // defines in which state after which icons should be a divider
        freeroam: ["menu.vehicleconfig.parts", "menu.environment", "menu.photomode", "menu.options.graphics"],
        scenario: ["menu.photomode"],
      }

      $scope.$on("ShowEntertainingBackground", (ev, mainmenu) => {
        //console.log("ShowEntertainingBackground")
        $scope.$evalAsync(() => {
          vm.mainmenu = mainmenu
        })
      })

      vm.openRepo = function () {
        var onlineState = Settings.values.onlineFeatures
        if (onlineState === "enable") {
          $state.go("menu.mods.repository")
        } else {
          window.location.href = "http-external://www.beamng.com/resources/"
        }
      }

      // The "GameStateUpdate" is triggered by calling "getGameState()" in the Lua engine.
      // $rootScope takes care of this each time there is a state change.
      $scope.$on("GameStateUpdate", function (event, data) {
        //console.log(`got game state: ${data.state}`, data)

        $scope.$evalAsync(() => {
          vm.gameState = data.menuItems
        })
      })

      $scope.$on("ShowApps", function (event, data) {
        // console.log('got', (data ? 'show' : 'hide'), 'apps')
        vm.showApps = data
      })

      // Method used to show mods on repository when 'view ingame' on https://www.beamng.com/resources/ is clicked.
      $scope.$on("ShowMod", function (event, data) {
        var startTimeout

        if (data) {
          ;(function checkStart() {
            // check if startScreen is still active every 100ms
            if ($state.current.name === "startScreen") {
              startTimeout = setTimeout(checkStart, 100)
            } else {
              // if no startScreen then we can continue to show mod
              window.location.href = `local://local/ui/entrypoints/main/index.html#/menu/mods/detail/${data}`
              clearTimeout(startTimeout)
            }
          })()
        }
      })

      $scope.$on("MenuToggle", (event, data) => {
        //console.log('toggleMenu', data, $state.current)
        //console.trace()

        // when in browser ui
        // if (!beamng.ingame) return

        // *** navigation back logic here
        let backState = $state.current.backState
        // this hack allows to catch Esc or (B) gamepad button
        // currently used in garage mode and bigmap
        if (typeof $state.preventStateChange === "function" && $state.preventStateChange()) {
          backState = "BLOCK"
        } else if (typeof backState === "function") {
          backState = backState(vm, $state, $stateParams)
        }
        if (backState) {
          let targetState = backState

          if (targetState === "BLOCK") {
            if (!$state.current.tryCounter) {
              $state.current.tryCounter = 0
            }
            $state.current.tryCounter++
            if ($state.current.tryCounter < 6) {
              return
            }
            $state.current.tryCounter = null
            targetState = "BACK_TO_MENU"
          }

          if (targetState === "BACK_TO_MENU") {
            targetState = selectTopMenu()
          } else if (targetState == "play" && vm.stickyPlayState) {
            targetState = vm.stickyPlayState
          }

          $state.go(targetState, getPrevArgs($state, targetState))
          return
        }

        //console.log(`received MenuToggle in gamestate: ${vm.gameState}. currently in state: ${$state.current.name}`)

        let showMenu = false
        $scope.$evalAsync(function () {
          if (typeof data == "boolean") {
            showMenu = data
          } else {
            showMenu = $state.current.name !== (vm.gameState === "garage" ? "menu.mainmenu" : "menu")
          }
          let targetState
          if (showMenu) {
            targetState = selectTopMenu()
          } else {
            // figure out where to go 'back' to. Normally the play state, but in scenarios it might be different
            targetState = vm.stickyPlayState || "play"
          }
          $state.go(targetState, getPrevArgs($state, targetState))
        })
        bngApi.engineLua(`extensions.hook("onMenuToggled", ${showMenu})`)
      })
      function getPrevArgs($state, targetState) {
        // exiting menus
        if ($state.gamestate && $state.gamestateArgs && $state.gamestate.name === targetState) {
          return $state.gamestateArgs
        }
        // generic going back
        if ($state.previous && $state.previousArgs && $state.previous.name === targetState) {
          return $state.previousArgs
        }
        return null
      }
      function selectTopMenu() {
        return vm.mainmenu || vm.gameState === "garage" ? "menu.mainmenu" : "menu"
      }

      $scope.$on("MenuHide", function (event, data) {
        if (!beamng.ingame) return
        // TODO FIXME
        //console.log(">>>> MENUHIDE", data)
        //console.trace()
        // TODO: FIXME
        let showMenu = false
        if (typeof data == "boolean") {
          showMenu = data
        }
        if (showMenu) {
          $state.go(vm.mainmenu ? "menu.mainmenu" : "menu")
        } else {
          $state.go("play")
        }
      })

      $scope.$on("onCefVisibilityChanged", function (event, cefVisible) {
        $scope.$evalAsync(function () {
          vm.uiVisible = cefVisible
        })
      })

      $scope.$on("hide_ui", function (event, visible) {
        let cmd = visible === undefined ? `extensions.ui_visibility.toggleCef()` : `extensions.ui_visibility.set(${visible})`
        console.error("The hide_ui function is deprecated and will stop working in the future. Please use " + cmd)
        bngApi.engineLua(cmd)
      })

      vm.quit = function () {
        if (vm.mainmenu) {
          bngApi.engineScript("quit();") //It should work but doesn't, `Platform::postQuitMessage` is executed but nothing happens, maybe CEF catch that message
          bngApi.engineLua("TorqueScript.eval('quit();')")
        } else {
          bngApi.engineLua("returnToMainMenu()")
        }
      }

      $scope.$on("CloseMenu", () => {
        var newTarget = vm.mainmenu ? "menu.mainmenu" : "menu"
        $state.go(newTarget)
      })

      $scope.$on("quit", vm.quit)

      $scope.$on("SettingsChanged", (ev, data) => {
        //console.log('SettingsChanged, updating languages... ', data.values.uiLanguage)
        if (data.values.uiLanguage && data.values.uiLanguage !== "" && i18NLanguageFinished && i18nLanguageUsed !== data.values.uiLanguage) {
          $rootScope.$eval(function () {
            $translate.use(data.values.uiLanguage)
          })
        }
      })
      // **************************************************************************

      // The "MenuOpenModule" event is used to quickly open a state from keyboard.
      // The various arguments are defined in the lua/t3d/input_actions.json file
      // and map actions to HookManager calls (and stuff for other modules).
      //
      // NOTE: Remember that transitioning to a state is not enough - menu must be open too!!
      $scope.$on("MenuOpenModule", function (event, data) {
        //console.log('received MenuOpenModule w/', data)
        let isString = typeof data === "string"
        if (isString) {
          switch (data) {
            case "help":
              $state.go("menu.options.help")
              break
            case "vehicleselect":
              $state.go("menu.vehicles")
              break
            case "vehicleconfig":
              $state.go("menu.vehicleconfig.parts")
              break
            case "vehicledebug":
              $state.go("menu.vehicleconfig.debug")
              break
            case "options":
              $state.go("menu.options.display")
              break
            case "appedit":
              $state.go("menu.appedit")
              break
            default:
              $state.go(data)
              break
          }
        } else {
          $state.go(data.state, data.params)
        }
      })

      $scope.$on("InputBindingsChanged", function (event, data) {
        $scope.pauseControlText = ""
        $scope.pauseControlIcon = ""
        for (var i = 0; i < data.bindings.length; i++) {
          for (var j = 0; j < data.bindings[i].contents.bindings.length; j++) {
            var binding = data.bindings[i].contents.bindings[j]
            if (binding.action != "pause") continue
            $scope.pauseControlText = binding.control
            $scope.pauseControlIcon = ControlsUtils.deviceIcon(data.bindings[i].contents.devicetype)
            break
          }
        }
      })

      $scope.$on("physicsStateChanged", function (event, state) {
        $scope.$evalAsync(function () {
          vm.physicsMaybePaused = !state
          updatePauseState()
        })
      })

      $scope.$on("replayStateChanged", function (event, core_replay) {
        $scope.$evalAsync(function () {
          vm.replayActive = core_replay.state === "playback"
          vm.replayPaused = vm.replayActive && core_replay.paused
          updatePauseState()
        })
      })

      vm.unpause = function () {
        bngApi.engineLua("simTimeAuthority.pause(false)")
      }

      $scope.$on("requestPhysicsState", function (event) {
        $scope.$broadcast("physicsStateChanged", !vm.physicsPaused)
      })

      vm.isWaiting = false

      $scope.$on("app:waiting", function (event, value, callback) {
        vm.isWaiting = value
        Utils.waitForCefAndAngular(() => {
          if (callback !== undefined && typeof callback === "function") {
            callback(vm.isWaiting)
          }
          bngApi.engineLua('extensions.hook("onUiWaitingState", ' + String(value) + ")")
        })
      })

      $scope.$on("onLevelsChanged", function (event, data) {
        levelsData = data
      })
      bngApi.engineLua("extensions.core_levels.requestData()")

      /*
  $rootScope.$watch(function() {
    console.log("### DIGEST ###")
    /// if you want to find out where the digest is triggered:
    //console.trace()
  })
  */
    },
  ])

  .service("BlurGame", [
    function () {
      return window.bridge.gameBlurrer
    },
  ])

  .directive("bngBlur", [
    "BlurGame",
    "RateLimiter",
    function (BlurGame, RateLimiter) {
      return {
        restrict: "A",
        link: function (scope, elem, attrs) {
          let id
          let blurAmount = 1
          let blurUpdateWrapper = RateLimiter.debounce(updateBlur, 50)

          const resizeObserver = new ResizeObserver(blurUpdateWrapper)

          // TODO - maybe revisit this - removed position monitoring for Angular blur since it appears to cause issues
          //
          //const removePositionObserver = window.observePosition(elem[0], blurUpdateWrapper)

          resizeObserver.observe(elem[0])


          scope.$watch(attrs.bngBlur, val => {
            switch (typeof val) {
              case "undefined":
                val = 1
                break
              case "boolean":
                val = val ? 1 : 0
                break
              case "number":
                if (val < 0 || val > 1) {
                  console.error(`Attempted to use bng-blur with a number out of range 0..1: ${val}\nSee stack:\n${new Error().stack}`)
                  val = 1
                }
                // all fine
                break
              default:
                console.error(`Attempted to use bng-blur with a non-number, non-boolean value: ${val}\nSee stack:\n${new Error().stack}`)
                val = 0
                break
            }
            blurAmount = val
            blurUpdateWrapper()
          })

          function calcBlur() {
            let rect = elem[0].getBoundingClientRect()
            if (
              // valid size (at least 1px)
              rect.width > 0 &&
              rect.height > 0 &&
              // on screen (for at least 1px)
              rect.bottom > 0 &&
              rect.top < screen.height &&
              rect.right > 0 &&
              rect.left < screen.width
            ) {
              return [
                rect.left / screen.width, // x
                rect.top / screen.height, // y
                rect.width / screen.width, // width
                rect.height / screen.height, // height
                blurAmount,
              ]
            }
            return null
          }

          function updateBlur() {
            if (blurAmount && isVisibleFast(elem[0])) {
              const blur = calcBlur()
              if (!id && blur) {
                id = BlurGame.register(blur)
              } else if (!blur) {
                BlurGame.unregister(id)
                id = null
              } else {
                BlurGame.update(id, blur)
              }
            } else {
              if (id) {
                BlurGame.unregister(id)
                id = null
              }
            }
          }

          scope.$on("$destroy", () => {
            resizeObserver.disconnect()
            // TODO - maybe revisit this - removed position monitoring for Angular blur since it appears to cause issues
            //
            //removePositionObserver()
            blurAmount = 0
            blurUpdateWrapper()
          })

          scope.$on("windowResize", () => {
            blurUpdateWrapper()
          })
        },
      }
    },
  ])

  // this directive translates the view frustum a bit to make up for lost space behind side menu and alike
  // use it like this: <md-content bng-frustum-mover="left">
  .directive("bngFrustumMover", [
    "RateLimiter",
    function (RateLimiter) {
      return {
        restrict: "A",
        link: function (scope, elem, attrs) {
          function updateGE() {
            let screenWidth = window.screen.width
            let sideBarWidth = elem[0].getBoundingClientRect().width
            let percentHidden = sideBarWidth / screenWidth
            if (attrs.bngFrustumMover === "left") {
              percentHidden *= -1
            } else if (attrs.bngFrustumMover === "right") {
              //all good
            } else {
              console.error("only left/rigth supported right now")
            }
            if (Math.abs(percentHidden) < 0.0001) {
              ;``
              //console.log("complete overlap")
              percentHidden = 0
            }
            //console.log("adjusting frustom side offset:", screenWidth, sideBarWidth, percentHidden)
            bngApi.engineLua(`scenetree.OnlyGui:setFrustumCameraCenterOffset(Point2F(${percentHidden}, 0))`)
          }

          angular.element(elem).ready(function () {
            updateGE()
          })

          // update on resize
          const resizeObserver = new ResizeObserver(entries => {
            updateGE()
          })
          resizeObserver.observe(elem[0])

          // rest on destroy
          scope.$on("$destroy", () => {
            //console.log("resetting frustom side offset")
            bngApi.engineLua(`scenetree.OnlyGui:setFrustumCameraCenterOffset(Point2F(0, 0))`)
          })

          scope.$on("windowResize", () => {
            updateGE()
          })
        },
      }
    },
  ])

  .service("InputCapturer", [
    "$state",
    function ($state) {
      // captures input on UI
      // usage:
      //   const captureInput = InputCapturer(); // create an instance
      //   captureInput(true|false); // change the value for that instance
      // options can be specified:
      //   const captureInput = InputCapturer({
      //     // do something on Esc/B press
      //     backAction() {
      //       if (something) return true; // return true to prevent default action (e.g. BACK_TO_MENU)
      //       else return false;          // if returned false or nothing - default action is allowed
      //     }
      //   });
      let isEnabled = false,
        counter = 0
      function enabler(enable) {
        counter += enable ? 1 : -1
        if (counter < 0) counter = 0
        // console.log(counter);
        if ((isEnabled && enable) || (!isEnabled && !enable) || (isEnabled && !enable && counter > 0)) return
        isEnabled = enable
        bngApi.engineLua(`extensions.core_input_bindings.setMenuActionMapEnabled(${enable})`)
      }
      const backActions = []
      $state.preventStateChange = () => {
        if (backActions.length > 0) return backActions[0]()
        return false
      }
      return opts => {
        if (typeof opts !== "object") opts = {}
        // return a function that tracks previous state and passes it further only when change happened
        let current
        return enable => {
          if (typeof current !== "undefined" && current === enable) return
          current = enable
          enabler(enable)
          if (typeof opts.backAction === "function") {
            if (enable) backActions.unshift(opts.backAction)
            else backActions.shift()
          }
        }
      }
    },
  ])
