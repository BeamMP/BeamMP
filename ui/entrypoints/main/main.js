angular.module('beamng.stuff', ['ngAnimate', 'toastr'])
angular.module('beamng.gameUI', ['ngAnimate', 'toastr'])
angular.module('beamng.color', [])
angular.module('beamng.gamepadNav', [])
angular.module('beamng.controls', [])

angular.module('BeamNG.ui', ['beamng.core', 'beamng.components', 'beamng.data', 'ngMaterial', 'ngAnimate', 'ui.router', 'beamng.stuff', 'beamng.gameUI', 'beamng.apps', 'beamng.color', 'pascalprecht.translate', 'beamng.gamepadNav', 'beamng.controls', 'fc.paging','ngSanitize','jkAngularRatingStars','ngFitText'])

.config(['$compileProvider', '$logProvider', '$stateProvider', '$urlRouterProvider', '$mdThemingProvider', '$translateProvider', 'toastrConfig', '$provide',
  function($compileProvider, $logProvider, $stateProvider, $urlRouterProvider, $mdThemingProvider, $translateProvider, toastrConfig, $provide) {

  $translateProvider.useStaticFilesLoader({
    prefix: '/locales/',
    suffix: '.json'
  })
  $translateProvider.useSanitizeValueStrategy('escaped')
  $translateProvider.preferredLanguage('en-US'); // this is the default language to load
  $translateProvider.fallbackLanguage('en-US'); // this is the fallback in case individual translations are missing
  //$translateProvider.useLoaderCache(true); // default is false which means disable
  //$translateProvider.forceAsyncReload(true);


  //$translateProvider.use('de-DE')

  $logProvider.debugEnabled(false)


  // ..... User Interface states
  $stateProvider

  .state('play', {
    url: '/play',
    templateUrl: '/ui/modules/play/play.html',
    controller: 'PlayController as playCtrl',
    menuActionMapEnabled: false, // defaults to true
    uiAppsShown: true, // defaults to false
  })

  .state('menu', {
    url: '/menu',
    templateUrl: '/ui/modules/menu/menu.html',
    controller: 'MenuController as menuCtrl',
    uiLayout: 'menu',
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

    .state('menu.start', {
      loaderVisible: true,
      views: {
        'loader@': { // target the loader view in parent menu state
          templateUrl: '/ui/modules/startScreen/startScreen.html',
          controller: 'startScreenController as startScreen',
        },
        '@menu': { }
      },
    })

    .state('menu.start_loadmainmenu', {
      loaderVisible: true,
      views: {
        'loader@': { // target the loader view in parent menu state
          templateUrl: '/ui/modules/startScreen/startScreen.html',
          controller: 'startScreenController as startScreen',
        },
        '@menu': { // target the unnamed view in parent menu state
          templateUrl: '/ui/modules/menu/menu.html',
          controller: 'MenuController as menuCtrl',
        }
      },
      transitionAnimation: 'moduleBlendOnLeave',
    })

    .state('menu.mainmenu', {
      views: {
        'loader':{}, // empty the loader view
        '@menu': { // targe the unnamed default view in the menu parent state
          templateUrl: `/ui/modules/mainmenu/${beamng.product}/mainmenu.html`,
          controller: 'MainMenuController as mmCtrl',
        }
      }
    })

    .state('menu.onlineFeatures', {
      url: '/onlineFeatures',
      templateUrl: `/ui/modules/onlineFeatures/online.html`,
      controller: 'OnlineFeaturesController',
      backState: 'menu.mainmenu',
    })

    .state('menu.bigmap', {
      url: '/bigmap',
      templateUrl: '/ui/modules/bigmap/bigmap.html',
      controller: 'BigMapController',
      backState: 'menu',
    })

    .state('menu.levels', {
      url: '/levels',
      templateUrl: '/ui/modules/levelselect/levelselect.html',
      controller:  'LevelSelectController as lsCtrl',
      backState: 'menu.mainmenu',
    })

    .state('menu.levelDetails', {
      url: '/levels-details/:levelName',
      templateUrl: '/ui/modules/levelselect/levelselect-details.html',
      controller:  'LevelSelectDetailsController as levelsDetails',
      backState: 'menu.levels',
    })

    .state('menu.busRoutes', {
      url: '/bus',
      templateUrl: '/ui/modules/busRoute/busRoute.html',
      controller: 'BusRoutesController as busCtrl',
      backState: 'menu.mainmenu',
    })

    .state('menu.busRoutesLevelSelect', {
      url: '/bus/level',
      templateUrl: '/ui/modules/busRoute/levelSelect.html',
      controller: 'BusRoutesLevelController',
      backState: 'menu.busRoutes',
    })

    .state('menu.busRoutesVehicleSelect', {
      url: '/bus/vehicle/:garage/:mode/:event',
      templateUrl: '/ui/modules/vehicleselect/vehicleselect.html',
      controller: 'VehicleSelectController as vehicles',
      backState: 'menu.busRoutes',
    })

    .state('menu.busRoutesRouteSelect', {
      url: '/bus/route',
      templateUrl: '/ui/modules/busRoute/routeSelect.html',
      controller: 'BusRoutesRouteController',
      backState: 'menu.busRoutes',
    })

    .state('menu.environment', {
      url: '/environment',
      templateUrl: '/ui/modules/environment/environment.html',
      controller:  'EnvironmentController as environment',
      backState: 'menu',
    })

    // Track Builder
    // .state('menu.trackBuilder', {
    //   url: '/trackBuilder',
    //   templateUrl: '/ui/modules/trackBuilder/trackBuilder.html',
    //   controller:  'TrackBuilderController as trackBuilder'
    // })

    .state('menu.scenarios', {
      url: '/scenarios',
      templateUrl: '/ui/modules/scenarioselect/scenarioselect.html',
      controller: 'ScenarioSelectController',
      backState: 'menu.mainmenu',
    })

    .state('menu.campaigns', {
      url: '/campaigns',
      templateUrl: '/ui/modules/campaignselect/campaignselect.html',
      controller: 'CampaignSelectController as campaignSelect',
      backState: 'menu.mainmenu',
    })



    .state('menu.appedit', {
      url: '/appedit/:mode',
      templateUrl: '/ui/modules/appedit/appedit.html',
      controller: 'AppEditController as ctrl',
      backState: 'menu',
      uiAppsShown: true, // defaults to false
    })

    .state('menu.appselect', {
      url: '/appselect',
      templateUrl: '/ui/modules/appselect/appselect.html',
      controller: 'AppSelectController as apps',
      backState: 'menu.appedit',
    })

    .state('menu.vehicles', {
      url: '/vehicleselect/:garage/:mode/:event',
      templateUrl: '/ui/modules/vehicleselect/vehicleselect.html',
      controller: 'VehicleSelectController as vehicles',
      backState: 'BACK_TO_MENU',
    })

    .state('menu.vehiclesdetails', {
      url: '/vehicle-details/:model/:config/:mode/:event',
      templateUrl: '/ui/modules/vehicleselect/vehicleselect-details.html',
      controller: 'VehicleDetailsController as vehicle',
      backState: 'menu.vehicles',
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

    .state('menu.spDragraceDialog', {
      url: '/spDrag',
      templateUrl: '/ui/modules/multiplayer/multiplayerMissions/dragRaceDialog/sp/dragrace_dialog.html',
      controller: 'SPDragRaceController',
      params: { data: {} }
    })

    .state('menu.mpDragraceDialog', {
      url: '/mpDrag',
      templateUrl: '/ui/modules/multiplayer/multiplayerMissions/dragRaceDialog/mp/dragrace_dialog.html',
      controller: 'MPDragRaceController',
      params: { playerList: [] }
    })
    // -------------------------------------- BEAMMP -------------------------------------- //

    .state('menu.options', {
      url: '/options',
      templateUrl: '/ui/modules/options/options.html',
      controller: 'OptionsController',
      controllerAs: 'options',
      backState: 'BACK_TO_MENU',
      abstract: true
    })
    .state('menu.options.multiplayer', {
      url: '/multiplayer',
      templateUrl: '/ui/modules/options/multiplayer.partial.html',
      controller: 'SettingsGameplayCtrl as opt',
      backState: 'BACK_TO_MENU',
    })
      .state('menu.options.help', {
        url: '/help',
        templateUrl: '/ui/modules/options/help.partial.html',
        controller: 'SettingsHelpCtrl as opt',
        backState: 'BACK_TO_MENU',
      })
      .state('menu.options.performance', {
        url: '/performance',
        templateUrl: '/ui/modules/options/performance.partial.html',
        controller: 'SettingsPerformanceCtrl as opt',
        backState: 'BACK_TO_MENU',
      })
      .state('menu.options.display', {
        url: '/display',
        templateUrl: '/ui/modules/options/display.partial.html',
        controller: 'SettingsGraphicsCtrl as opt',
        backState: 'BACK_TO_MENU',
      })
      .state('menu.options.graphics', {
        url: '/graphics',
        templateUrl: '/ui/modules/options/graphics.partial.html',
        controller: 'SettingsGraphicsCtrl as opt',
        backState: 'BACK_TO_MENU',
      })

      .state('menu.options.audio', {
        url: '/audio',
        templateUrl: '/ui/modules/options/audio.partial.html',
        controller: 'SettingsAudioCtrl as opt',
        backState: 'BACK_TO_MENU',
      })

      .state('menu.options.gameplay', {
        url: '/gameplay',
        templateUrl: '/ui/modules/options/gameplay.partial.html',
        controller: 'SettingsGameplayCtrl as opt',
        backState: 'BACK_TO_MENU',
      })

      .state('menu.options.camera', {
        url: '/camera',
        templateUrl: '/ui/modules/options/camera.partial.html',
        controller: 'SettingsGameplayCtrl as opt',
        backState: 'BACK_TO_MENU',
      })

      .state('menu.options.userInterface', {
        url: '/userInterface',
        templateUrl: '/ui/modules/options/userinterface.partial.html',
        controller: 'SettingsGameplayCtrl as opt',
        backState: 'BACK_TO_MENU',
      })

      .state('menu.options.language', {
        url: '/language',
        templateUrl: '/ui/modules/options/language.partial.html',
        controller: 'SettingsGameplayCtrl as opt',
        backState: 'BACK_TO_MENU',
      })

      .state('menu.options.other', {
        url: '/other',
        templateUrl: '/ui/modules/options/other.partial.html',
        controller: 'SettingsGameplayCtrl as opt',
        backState: 'BACK_TO_MENU',
      })

      .state('menu.options.licenses', {
        url: '/licenses',
        templateUrl: '/ui/modules/options/licenses.partial.html',
        controller: 'SettingsGameplayCtrl as opt',
        backState: 'BACK_TO_MENU',
      })

      .state('menu.options.controls', {
        url: '/controls',
        templateUrl: '/ui/modules/options/controls.html',
        controller: 'ControlsController as controls',
        backState: 'BACK_TO_MENU',
      })
        .state('menu.options.controls.bindings', {
          views: {
            '': {
              url: '/bindings',
              templateUrl: '/ui/modules/options/controls-bindings.html',
              controller: 'ControlsBindingsCtrl as controlsBindings'
            }
          },
          backState: 'BACK_TO_MENU',
        })
            .state('menu.options.controls.bindings.edit', {
              views: {
                'edit@menu.options': {
                  url: '/edit',
                  templateUrl: '/ui/modules/options/controls-edit.html',
                  controller: 'ControlsEditCtrl as controlsEdit'
                }
              },
              params: {action: '', oldBinding: {}, showFfb: false},
              backState: 'BACK_TO_MENU',
            })

        .state('menu.options.controls.filters', {
          views: {
            '': {
              url: '/filters',
              templateUrl: '/ui/modules/options/controls-filters.html',
              controller: 'ControlsFiltersCtrl as controlsFilters'
            },
          },
          backState: 'BACK_TO_MENU',
        })

        .state('menu.options.controls.ffb', {
          views: {
            '': {
              url: '/ffb',
              templateUrl: '/ui/modules/options/controls-ffb.html',
              controller: 'ControlsFfbCtrl as controlsFfb'
            }
          },
          backState: 'BACK_TO_MENU',
        })

            .state('menu.options.controls.ffb.edit', {
              views: {
                'edit@menu.options': {
                  url: '/edit',
                  templateUrl: '/ui/modules/options/controls-edit.html',
                  controller: 'ControlsEditCtrl as controlsEdit'
                }
              },
              params: {action: '', oldBinding: {}, showFfb: ''},
              backState: 'BACK_TO_MENU',
            })

      .state('menu.options.controls.hardware', {
        views: {
          '': {
            url: '/hardware',
            templateUrl: '/ui/modules/options/controls-hardware.html',
            controller: 'ControlsHardwareCtrl as controlsHw'
          }
        },
        backState: 'BACK_TO_MENU',
      })

    .state('menu.vehicleconfig', {
      url: '/vehicle-config',
      templateUrl: '/ui/modules/vehicleconfig/vehicleconfig.html',
      controller: 'VehicleconfigCtrl',
      redirectTo: 'menu.vehicleconfig.parts',
      backState: 'play',
    })
    .state('menu.vehicleconfig.parts', {
      url: '/vehicle-config/parts',
      templateUrl: '/ui/modules/vehicleconfig/partial.parts.html',
      controller: 'Vehicleconfig_parts as vehConf_parts',
      backState: 'play',
      uiAppsShown: true, // defaults to false
    })
    .state('menu.vehicleconfig.tuning', {
      url: '/vehicle-config/tuning',
      templateUrl: '/ui/modules/vehicleconfig/partial.tuning.html',
      controller: 'Vehicleconfig_tuning as vehConf_tuning',
      backState: 'play',
      uiAppsShown: true, // defaults to false
    })
    .state('menu.vehicleconfig.color', {
      url: '/vehicle-config/color',
      templateUrl: '/ui/modules/vehicleconfig/partial.color.html',
      controller: 'Vehicleconfig_color as vehConf_color',
      backState: 'play',
    })
    .state('menu.vehicleconfig.save', {
      url: '/vehicle-config/save',
      templateUrl: '/ui/modules/vehicleconfig/partial.save.html',
      controller: 'Vehicleconfig_save as vehConf_save',
      backState: 'play',
    })
    .state('menu.vehicleconfig.debug', {
      url: '/vehicle-config/debug',
      templateUrl: '/ui/modules/vehicleconfig/debug.partial.html',
      controller: 'Vehicleconfig_debug as vehConf_debug',
      backState: 'play',
      uiAppsShown: true, // defaults to false
    })



    .state('menu.mods', {
      url: '/mods',
      template: '<ui-view class="filler" style="position: relative;"></ui-view>',
      abstract: true,
      controller: 'ModManagerController as modCtrl',
      backState: 'BACK_TO_MENU',
    })

      .state('menu.mods.local', {
        url: '/local',
        views: {
          '': {
            controller: 'LocalModController as modLoclCtrl',
            templateUrl: '/ui/modules/modmanager/mods.html'
          },
          'content@menu.mods.local': {
            templateUrl: '/ui/modules/modmanager/local.html'
          },
          'filter@menu.mods.local': {
            templateUrl: '/ui/modules/modmanager/filter.html'
          }
        },
        backState: 'BACK_TO_MENU',
      })

      .state('menu.mods.downloaded', {
        url: '/downloaded',
        views: {
          '': {
            controller: 'DownloadModController as modDwlCtrl',
            templateUrl: '/ui/modules/modmanager/mods.html'
          },
          'content@menu.mods.downloaded': {
            templateUrl: '/ui/modules/modmanager/downloaded.html',
          }
        },
        backState: 'BACK_TO_MENU',
      })

      .state('menu.mods.scheduled', {
        url: '/scheduled',
        views: {
          '': {
            controller: 'ScheduledModController as modSchCtrl',
            templateUrl: '/ui/modules/modmanager/mods.html'
          },
          'content@menu.mods.scheduled': {
            templateUrl: '/ui/modules/modmanager/scheduled.html',
          },
          'filter@menu.mods.scheduled': {
            templateUrl: '/ui/modules/modmanager/scheduled_conflict.html'
          }
        },
        backState: 'BACK_TO_MENU',
      })

      .state('menu.mods.repository', {
        url: '/repository?query',
        views: {
          '': {
            controller: 'RepositoryController as repo',
            templateUrl: '/ui/modules/modmanager/mods.html'
          },
          'content@menu.mods.repository': {
            templateUrl: '/ui/modules/repository/repository.html'
          },
          'filter@menu.mods.repository': {
            templateUrl: '/ui/modules/repository/filter.html'
          }
        },
        backState: 'BACK_TO_MENU',
      })

      .state('menu.mods.automation', {
        url: '/automation?query',
        views: {
          '': {
            controller: 'AutomationController as automation',
            templateUrl: '/ui/modules/modmanager/mods.html'
          },
          'content@menu.mods.automation': {
            templateUrl: '/ui/modules/automation/automation.html'
          },
          'filter@menu.mods.automation': {
            templateUrl: '/ui/modules/automation/filter.html'
          }
        },
        backState: 'BACK_TO_MENU',
      })

      .state('menu.mods.automationDetails', {
        url: '/automation/detail/{modId:[0-9A-Z]+}?page&param',
        views: {
          '': {
            controller: 'AutomationDetailsController as automationDetailCtrl',
            templateUrl: '/ui/modules/modmanager/mods.html'
          },
          'content@menu.mods.automationDetails': {
            templateUrl: '/ui/modules/automation/automation-details.html'
          },
          'filter@menu.mods.automationDetails': {
            templateUrl: '/ui/modules/automation/info.html'
          }
        },
        backState: 'BACK_TO_MENU',
      })

      .state('menu.mods.details', {
        url: '/detail/{modId:[0-9A-Z]+}?page&param',
        views: {
          '': {
            controller: 'RepositoryDetailsController as repoDetailCtrl',
            templateUrl: '/ui/modules/modmanager/mods.html'
          },
          'content@menu.mods.details': {
            templateUrl: '/ui/modules/repository/repository-details.html'
          },
          'filter@menu.mods.details': {
            templateUrl: '/ui/modules/repository/info.html'
          }
        },
        backState: 'menu.mods.repository',
      })

    .state('menu.modsDetails', {
      url: '/modmanager/details:modFilePath',
      templateUrl: '/ui/modules/modmanager/info.html',
      controller: 'ModManagerControllerDetails',
      backState: 'BACK_TO_MENU',
    })

  .state('menu.gameContext', {
      url: '/gameContext',
      templateUrl: '/ui/modules/gameContext/gameContext.html',
      controller: 'GameContextController',
      backState: 'BACK_TO_MENU',
  })

  .state('scenario-start', {
    url: '/scenariocontrol/start',
    params: {
      data: {}
    },
    templateUrl: '/ui/modules/scenariocontrol/start.html',
    controller: 'ScenarioStartController as scenarioStart',
    backState: 'BACK_TO_MENU',
  })

  .state('scenario-end', {
    url: '/scenariocontrol/end',
    params: {
        stats: {},
        rewards: {},
        portrait: {}
    },
    templateUrl: '/ui/modules/scenariocontrol/end.html',
    controller: 'ScenarioEndController',
    backState: 'BACK_TO_MENU',
  })

  .state('quickrace-end', {
    url: '/quickraceEnd',
    params: {
        stats: {},
        mockScenario: {}
    },
    templateUrl: '/ui/modules/scenariocontrol/quickraceEnd.html',
    controller: 'ScenarioEndController',
    backState: 'BACK_TO_MENU',
  })

  .state('chapter-end', {
    url: '/cchapterEnd',
    params: {
        stats: {}
    },
    templateUrl: '/ui/modules/scenariocontrol/end.html',
    controller: 'ScenarioEndController',
    backState: 'BACK_TO_MENU',
  })

  // Transition to this state is handled by some unknown dark force (Torque?).
  // Until this chanages, keep the url hash to "loading".
  .state('loading', {
    url: '/loading',
    templateUrl: '/ui/modules/loading/loading.html',
    controller:  'LoadingController as loading',
    transitionAnimation: 'moduleBlendOnLeave',
    backState: 'BLOCK',
  })

  .state('comic', {
    url: '/comic',
    params: {
        comiclist: {}
    },
    templateUrl: '/ui/modules/comic/comic.html',
    controller: 'ComicController',
    backState: null,
  })

  .state('menu.photomode', {
    url: '/photo-mode',
    templateUrl: '/ui/modules/photomode/photomode.html',
    controller:  'PhotoModeController as photo',
    backState: 'menu',
  })

  .state('menu.replay', {
    url: '/replay',
    templateUrl: '/ui/modules/replay/replay.html',
    controller:  'ReplayController as replay',
    backState: 'BACK_TO_MENU',
  })

  .state('credits', {
    url: '/credits',
    templateUrl: '/ui/modules/credits/credits.html',
    controller: 'CreditsController as creditsCtrl',
    backState: 'BACK_TO_MENU',
  })

  .state('iconViewer', {
    url: '/iconViewer',
    templateUrl: '/ui/modules/iconView/icons.html',
    controller: 'iconViewerCtrl as iconCtrl',
    backState: 'BACK_TO_MENU',
  })

  .state('fadeScreen', {
    url: '/fadeScreen',
    templateUrl: '/ui/modules/fadeScreen/fadeScreen.html',
    params: {
        fadeIn: 1,
        pause: 0,
        fadeOut: 1
    },
    controller: 'fadeScreen',
    backState: 'BLOCK',
  })

    .state('mapview', {
      url: '/mapview',
      templateUrl: '/ui/modules/mapview/mapview.html',
      controller: 'MapViewCtrl as mapview',
      params: {
        data: {}
      },
      backState: 'BACK_TO_MENU',
      // params: {
      //   baseImg: '',
      //   points: [],
      //   onClick: ''
      // }
    })

    //Dragrace states WIP
    .state('menu.dragRaceOverview', {
      url: '/dragrace/overview',
      templateUrl: '/ui/modules/dragrace/overview.html',
      controller: 'DragRaceController',
      params: {
        results: {},
        cinematicEnabled: true
      },
      backState: 'BACK_TO_MENU',
    })

    // LightRunner States
    .state('menu.lightrunnerOverview', {
      url: '/lightrunner/overview',
      templateUrl: '/ui/modules/lightrunner/overview.html',
      controller: 'LightRunnerController',
      backState: 'BACK_TO_MENU',
    })

    .state('menu.lightrunnerTrackSelect', {
      url: '/lightrunner/track',
      templateUrl: '/ui/modules/lightrunner/trackSelect.html',
      controller: 'LightRunnerTrackController',
      backState: 'BACK_TO_MENU',
    })

    //Quickrace states WIP
    .state('menu.quickraceOverview', {
      url: '/quickrace/overview',
      templateUrl: '/ui/modules/quickrace/overview.html',
      controller: 'QuickraceController',
      backState: 'BACK_TO_MENU',
    })

    .state('menu.quickraceLevelselect', {
      url: '/quickrace/level',
      templateUrl: '/ui/modules/quickrace/levelSelect.html',
      controller: 'QuickraceLevelController',
      backState: 'BACK_TO_MENU',
    })

    .state('menu.quickraceTrackselect', {
      url: '/quickrace/track',
      templateUrl: '/ui/modules/quickrace/trackSelect.html',
      controller: 'QuickraceTrackController',
      backState: 'BACK_TO_MENU',
    })

    .state('campaign', {
      url: '/campaign',
      template: '<ui-view class="container"></ui-view>',
      backState: 'BACK_TO_MENU',
    })

    .state('campaign.quickraceOverview', {
      url: '/quickrace/overview',
      params: {
        level: {},
        track: {},
        vehicles: {},
      },
      templateUrl: '/ui/modules/quickrace/overview.html',
      controller: 'QuickraceController',
      backState: 'BACK_TO_MENU',
    })

    .state('campaign.quickraceLevelselect', {
      url: '/quickrace/level',
      templateUrl: '/ui/modules/quickrace/levelSelect.html',
      controller: 'QuickraceLevelController',
      backState: 'BACK_TO_MENU',
    })


    .state('campaign.quickraceTrackselect', {
      url: '/quickrace/track',
      templateUrl: '/ui/modules/quickrace/trackSelect.html',
      controller: 'QuickraceTrackController',
      backState: 'BACK_TO_MENU',
    })

    .state('campaign.vehicles', {
      url: '/vehicleselect/:garage/:mode',
      templateUrl: '/ui/modules/vehicleselect/vehicleselect.html',
      controller: 'VehicleSelectController as vehicles',
      backState: 'BACK_TO_MENU',
    })

    .state('campaign.vehicleDetails', {
      url: '/vehicle-details/:model/:config/:mode',
      templateUrl: '/ui/modules/vehicleselect/vehicleselect-details.html',
      controller: 'VehicleDetailsController as vehicle',
      backState: 'BACK_TO_MENU',
    })


  // default entry that is loaded on startup:
  $urlRouterProvider.otherwise('menu.start')

  $compileProvider.debugInfoEnabled(false)

  // whitelist for local:// prefix
  $compileProvider.aHrefSanitizationWhitelist(/^\s*(https?|ftp|mailto|local):/)
  $compileProvider.imgSrcSanitizationWhitelist(/^\s*(https?|ftp|mailto|local):/)

  let theme = $mdThemingProvider.theme('default')
  theme.dark()

  $mdThemingProvider.definePalette('customPrimary', {
    '50': '#ffffff',
    '100': '#e9e9e9',
    '200': '#d3d3d3',
    '300': '#bebebe',
    '400': '#a9a9a9',
    '500': '#959595',
    '600': '#818181',
    '700': '#6d6d6d',
    '800': '#5b5b5b',
    '900': '#484848',
    'A100': '#373737',
    'A200': '#262626', // ### hue-3
    'A400': '#171717', // ### hue-2
    'A700': '#000000',
    'contrastDefaultColor':'dark',
    'contrastLightColors': ['600', '700', '800', '900', 'A100', 'A200', 'A400', 'A700']
  })
  theme.primaryPalette('customPrimary', {
    'default': '800', // by default use shade A800 from the custom palette for primary intentions
    'hue-1': 'A100', // use shade A900 for the <code>md-hue-1</code> class
    'hue-2': 'A400', // use shade A400 for the <code>md-hue-2</code> class
    'hue-3': '50', // use shade A100 for the <code>md-hue-3</code> class
  })

  $mdThemingProvider.definePalette('customAccent', {
    '50': '#662800',
    '100': '#803200',
    '200': '#993c00',
    '300': '#b34600',
    '400': '#cc5000',
    '500': '#e65a00',
    '600': '#ff741a',
    '700': '#ff8333',
    '800': '#ff934d',
    '900': '#ffa266',
    'A100': '#ff741a',
    'A200': '#ff6400',
    'A400': '#e65a00',
    'A700': '#ffb280',
    'contrastDefaultColor':'dark',
    'contrastLightColors': ['500', '600', '700', '800', '900', 'A100', 'A200', 'A400', 'A700']
  })
  theme.accentPalette('customAccent', {
    'default': '500',
    'hue-1': '300',
    'hue-2': '800',
    'hue-3': 'A100',
  })

  $mdThemingProvider.definePalette('customWarn', {
    '50': '#ff7b82',
    '100': '#ff626a',
    '200': '#ff4852',
    '300': '#ff2f3a',
    '400': '#ff1522',
    '500': '#fb000d',
    '600': '#e1000c',
    '700': '#c8000a',
    '800': '#ae0009',
    '900': '#950008',
    'A100': '#ff959a',
    'A200': '#ffaeb3',
    'A400': '#ffc8cb',
    'A700': '#7b0006',
    'contrastDefaultColor':'dark',
    'contrastLightColors': ['300','400','500', '600', '700', '800', '900', 'A200', 'A400', 'A700']
  })
  theme.warnPalette('customWarn', {
    'default': '400',
    'hue-1': '500',
    'hue-2': '100',
    'hue-3': 'A700',
  })

  $mdThemingProvider.definePalette('customBackground', {
    '50':  'rgba(35,35,35,0.35)',
    '100': 'rgba(35,35,35,0.4)',
    //workaround for now, no clue why checkboxes are using '200'
    //200': 'rgba(35,35,35,0.45)',
    '200': '#FFF',
    '300': 'rgba(35,35,35,0.5)',
    '400': 'rgba(35,35,35,0.55)',
    '500': 'rgba(35,35,35,0.6)',
    '600': 'rgba(35,35,35,0.65)',
    '700': 'rgba(35,35,35,0.7)',
    '800': 'rgba(35,35,35,0.75)',
    '900': 'rgba(35,35,35,0.8)',
    'A100':'rgba(35,35,35,0.85)',
    'A200':'rgba(35,35,35,0.9)',
    'A400':'rgba(35,35,35,0.95)',
    'A700':'rgba(35,35,35,1)',
    'contrastDefaultColor':'light',
  })
  theme.backgroundPalette('customBackground', {
    'default': 'A400',
    'hue-1': '300',
    'hue-2': '600',
    'hue-3': '900',
  })


  // debug with this:
  //console.log("UI theme setup: ", $mdThemingProvider)

  angular.extend(toastrConfig, {
    autoDismiss: false,
    containerId: 'toast-container',
    maxOpened: 10,
    newestOnTop: true,
    positionClass: 'toast-top-right',
    preventOpenDuplicates: true,
    allowHtml: true,
  })


}])

.run(['$animate', '$http', '$rootScope', '$templateCache', '$window', '$translate', 'UIAppStorage', 'Settings', 'SettingsAuxData', 'bngWSApi', '$state',
function ($animate, $http, $rootScope, $templateCache, $window, $translate,  UIAppStorage, Settings, SettingsAuxData, bngWSApi, $state) {

  $http.get('/ui/modules/vehicleconfig/vehicle-config-tree.html').then(function (tmpl) {
    $templateCache.put('vehicle-config-tree', tmpl.data)
  })

  $http.get('/ui/assets/sprites/svg-symbols.svg')
  .success(svgSprite => {
    var iconsSprite = angular.element(svgSprite)
    angular.element(document.head).append(iconsSprite)
  })


  $http.get('/ui/modules/options/settingsPresets.json')
  .success(presets => {
    SettingsAuxData.graphicPresets = presets
  })

  registerWindowHooks($rootScope, $window)

  /* --- VUE3 START --- */
  // i18n vue3 basics

  // apply language settings
  $rootScope.$on('SettingsChanged', function(evt, data) {
    if(data.values.uiLanguage) {
      let lang = data.values.uiLanguage
      if(lang == '') lang = 'en-US'
      $http.get(`/locales/${lang}.json`,).then(function(res) {
        vueI18n.global.locale = lang
        vueI18n.global.setLocaleMessage(lang, res.data)
      })
    }
  })
	// -------------------------------------- BEAMMP -------------------------------------- //

	bngApi.engineLua(`MPConfig.getConfig()`, (data) => {
		if (data != null) {
			if (!localStorage.getItem("tosAccepted")) {
				localStorage.setItem("tosAccepted", data.tos);
			}
		}
	});

	// -------------------------------------- BEAMMP -------------------------------------- //
  /* --- VUE3 END --- */
  $rootScope.$on('$translateChangeSuccess', (event, data) => {
    i18nLanguageUsed = data.language
  })

  $rootScope.$on('$translateChangeStart', () => {
    i18NLanguageFinished = false
  })

  $rootScope.$on('$translateChangeEnd', () => {
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

  bngApi.engineLua('ui_apps.requestUIAppsData()')

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
  angular.element($window).bind('resize', function () {
    var size = {width: window.innerWidth, height: window.innerHeight}
    $rootScope.$broadcast('windowResize', size)
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

  $rootScope.$on('SettingsChanged', function (event, data) {
    Settings.options = data.options
    Settings.values = data.values
  })

  bngApi.engineLua('settings.requestState()')
  bngApi.engineLua('core_gamestate.requestMainMenuState()')
  bngApi.engineLua('core_gamestate.requestGameState()')
  // bngApi.engineLua('print("requesting gamestate here and now")')

  // settings storage end

  // navigate to start pages
  if (beamng.shipping && beamng.buildtype === 'RELEASE') {
    $state.go('menu.start')
  } else {
    $state.go('menu.mainmenu')
  }

}])

//------------Trying filter for date translation --------- put on separate file!!!

.filter('formattedDate', function(dateFilter, $translate) {

  var format = null, translated = false

  function returnFilter(inputDate) {
    if(format){
      return dateFilter(inputDate, format)
    }else{
      return '-'
    }
  }

  function formattedDateFilter(inputDate){
    if( format === null ) {
      if( !translated ){
        translated = true
        $translate('general.time_format').then(function (result) {
          format = result
        },function (translationId) {
          format = translationId
        })
      }

    }
    else return returnFilter(inputDate)
  }

  formattedDateFilter.$stateful = true
  return formattedDateFilter
})


angular.module('beamng.stuff')

.service('translateService', ['$translate', function($translate){
  contextTranslate = function(val) {
    if(typeof val == "string") {
      return $translate.instant(val)
    } else {
      if (val && val.txt && val.context) {
        return $translate.instant(val.txt, val.context)
      }
    }
    return
  }
  multiContextTranslate = function(val) {
    let description = ""
    for (var i = 0; i < val.length; i++) {
      description = description + contextTranslate(val[i])
    }
    return description
  }
  return {
    contextTranslate: contextTranslate,
    multiContextTranslate: multiContextTranslate
  }
}])

.service('gamepadNav', ['$rootScope', '$state',
  function ($rootScope, $state) {
    'use strict'

    // TODO: hook this up to lua settings
    // TODO: think about using a list of actions, so when one module unregisters it's action the old action gets used.
    // this would have the benefit for example of dropdowns beeing opened, and while open their actions would be used
    // todo: actually test the list approach
    let useCrossfire = true
    let scope = {}
    let useGamepadNavigation = false
    let noop = () => {}
    let actions = {
      up: [{module: 'root', func: noop}],
      down: [{module: 'root', func: noop}],
      right: [{module: 'root', func: noop}],
      left: [{module: 'root', func: noop}],
      confirm: [{module: 'root', func: noop}],
      back: [{module: 'root', func: noop}],
    }
    let prefix = {
      up: 'menu_item_up',
      down: 'menu_item_down',
      right: 'menu_item_right',
      left: 'menu_item_left',
      confirm: 'menu_item_select',
      back: 'menu_item_back',
      'radial-x': 'menu_item_radial_x',
      'radial-y': 'menu_item_radial_y',
      'tab-right': 'menu_tab_right',
      'tab-left': 'menu_tab_left',
    }


    function assignNavFunc (module, data) {
      for (var name in data) {
        if (actions[name] !== undefined) {
          if (nonAssignable.indexOf(name) === -1) {
            actions[name].push({module: module, func: data[name]})
            // console.debug('Registered new function to "' + name+ '"')
          } else {
            // console.error('"' + name + '" is an unchangable action')
          }
        } else {
          // console.error('"' + name + '" is not a valid action')
        }
      }
    }

    function unregisterActions (module, data) {
      for (var name in data) {
        if (actions[name] !== undefined) {
          var helper = actions[name].map((elem) => elem.module)
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

    $rootScope.$on('MenuItemNavigation', function (event, action, val) {
      //console.log('Got action: ' + action)
      //console.log('Enabled Librarys', useCrossfire, useGamepadNavigation)

      if (action == 'toggleMenues') {
        $rootScope.$broadcast('MenuToggle', val)
        return
      }
      if(action == 'back') {
        $rootScope.$broadcast('MenuToggle')
        return
      }
      if (["left", "right", "up", "down"].indexOf(action) != -1) {
        bngApi.engineLua('extensions.hook("onMenuItemNavigation")')
      }

      if (useCrossfire) {
        if(action == 'confirm') {
          if (document.activeElement.classList.contains("menu-navigation")) {
            document.activeElement.click(); // only click with confirm+crossfire if ornage focus border is shown
          }
        } else if(action == 'back') {
          $rootScope.$broadcast('MenuToggle')
        } else if (["left", "right", "up", "down"].indexOf(action) != -1) {
          bngApi.engineLua('extensions.hook("onMenuItemNavigation")')
          var targets = collectRects()
          navigate(targets, action)
          //console.log(`navigation ${action} handled by Crossfire`)
        } else if (action == 'tab-left') {
            $rootScope.$broadcast('$tabLeft')
        } else if (action == 'tab-right') {
            $rootScope.$broadcast('$tabRight')
        }
      }

      if (useGamepadNavigation && actions[action]) {
        //console.log(actions[action])
        // console.log(actions[action][0])
        $rootScope.$evalAsync(actions[action][0].func)
      }
    })

    return {
      crossfireEnabled: () => useCrossfire,
      gamepadNavEnabled: () => useGamepadNavigation,
      spatialNavEnabled: () => useCrossfire,
      // TODO: make this intuitive (omiting the value shouldn't do something unexpected)
      enableCrossfire: (val) => useCrossfire = val,
      enableGamepadNav: (val) => useGamepadNavigation = val,
      //enableSpatialNav: (val) => { log.error("SpatialNavigation is deprecated. Please use Crossfire."); useCrossfire = val },
      registerActions: assignNavFunc,
      unregisterActions: unregisterActions,
      provideScope: (scope) => scope = scope,
      prefix: (val) => prefix[val] || val,
    }
}])

/**
 * @ngdoc controller
 * @name beamng.stuff.controller:AppCtrl
 * @description This is the top-level controller used throughout the game
**/
.controller('AppCtrl', ['$document', '$log', '$rootScope', '$scope', '$sce', '$compile', '$state', '$translate', '$window', 'ControlsUtils', 'Utils', 'Settings', 'toastr', '$timeout', 'gamepadNav', '$injector', '$location', 'translateService', 'UiAppsService',
  function($document, $log, $rootScope, $scope, $sce, $compile, $state, $translate, $window, ControlsUtils, Utils, Settings, toastr, $timeout, gamepadNav, $injector, $location, translateService, UiAppsService) {
  var vm = this

  // hack to fix backspace navigating between different menus.
  // https://stackoverflow.com/questions/29006000/prevent-backspace-from-navigating-back-in-angularjs
  $document.on('keydown', function(e){
    if(e.which === 8 && ( e.target.nodeName !== "INPUT" && e.target.nodeName !== "SELECT" ) ){ // you can add others here inside brackets.
      e.preventDefault()
    }
  })

  setTimeout(() => {
    gamepadNav.provideScope($scope)
  })

  bngApi.engineLua('extensions.hook("onUIInitialised")')

  $scope.$on('requestUIInitialised', () => {
    bngApi.engineLua('core_gamestate.onUIInitialised()')
  })

  vm.shipping = beamng.shipping
  vm.uitest = false

  // on CEF devtools toggle
  $scope.$on('onCEFDevToolsVisibility', (event, enabled) => {
    $scope.$applyAsync(function () {
      vm.uitest = enabled
    })
  })

  // figure out if CEF devtools are already open
  bngApi.engineLua("getCefDevConsoleOpen()", (enabled)=> {
    $scope.$applyAsync(function () {
      vm.uitest = enabled
    })
  })

  // *** DEBUG START
  vm.currentStateName = ''
  vm.stickyPlayState = null

  $scope.$state = $state
  vm.states = $state.get().filter(state => !state.abstract) // filter abstract states
  //console.log("vm.states = ", vm.states)

  vm.emitMenuNav = function(action, val) {
    $rootScope.$broadcast('MenuItemNavigation', action, val)
  }
  vm.switchState = function(stateName) {
    if(stateName !== undefined) {
      $state.go(stateName)
    }
  }
  vm.prevState = function() {
    if(vm.currentStateName === '') vm.currentStateName = vm.states[0].name
    let nextStateIdx = -1
    for(let i in vm.states) {
      if(vm.states[i].name == vm.currentStateName) {
        nextStateIdx = parseInt(i) - 1
        if(nextStateIdx < 0) nextStateIdx = vm.states.length - 1
        break
      }
    }
    if(nextStateIdx != -1) {
      console.log("Switching to new state: " + vm.states[nextStateIdx].name)
      $state.go(vm.states[nextStateIdx].name)
    }
  }
  vm.nextState = function() {
    if(vm.currentStateName === '') vm.currentStateName = vm.states[0].name
    let nextStateIdx = -1
    for(let i in vm.states) {
      if(vm.states[i].name == vm.currentStateName) {
        nextStateIdx = parseInt(i) + 1
        if(nextStateIdx >= vm.states.length) nextStateIdx = 0
        break
      }
    }
    if(nextStateIdx != -1) {
      console.log("Switching to new state: " + vm.states[nextStateIdx].name)
      $state.go(vm.states[nextStateIdx].name)
    }
  }
  vm.reloadUI = function() {
    window.location.reload()
  }

  // shortcut for debugging
  window.openState = function(name) {
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
  vm.uiLayoutPrevious = false;
  function updatePauseState() {
      vm.physicsPaused= !vm.replayActive && vm.physicsMaybePaused
      vm.showPauseIcon = vm.physicsPaused || vm.replayPaused
      //console.log("updatePauseState", $state.current.name, vm.showPauseIcon)
  }

  // quite a hack, but the alternative would have been to manage a list and wait for each state to be actiavated
  // the problem only occured because changeState was called almost simultaniously and before on state could be transitioned to the other ocnditinal was already executed next.
  // TODO change this to use the $state.transition promise
  var transitioningTo

  $scope.$on('$stateChangeSuccess', function (event, toState, toParams, fromState, fromParams) {
    //console.log(`switching stage from ${fromState.name} to ${toState.name}`)
    //console.trace()
    vm.currentStateName = toState.name

    // update activated action maps for UI bindings
    let menuActionMapEnabled = $state.current.menuActionMapEnabled === undefined? true : $state.current.menuActionMapEnabled // true by default
    bngApi.engineLua(`extensions.core_input_bindings.setMenuActionMapEnabled(${menuActionMapEnabled})`)
    bngApi.engineLua(`extensions.hook("onUiChangedState", "${toState.name}", "${fromState.name}")`)

    // update ui apps layout
    if ($state.current.uiLayout === undefined) {
      // no particular ui layout defined, ensure we are in the default/previous one (whichever that may have been)
      if (vm.uiLayoutPrevious) {
        $scope.$emit('appContainer:loadLayoutByReqData', vm.uiLayoutPrevious)
        vm.uiLayoutPrevious = null;
      }
    } else {
      // this state requires a particular ui layout, set
      vm.uiLayoutPrevious = UiAppsService.getLayout()
      $scope.$emit('appContainer:loadLayoutByType', $state.current.uiLayout)
    }

    // update ui apps visibility
    let showApps = $state.current.uiAppsShown === true // defaults to false
    $scope.$emit('ShowApps', showApps)

    transitioningTo = undefined
    updatePauseState()
  })

  $scope.$on('setNavigationStickyPlayState', function(event, stateName) {
    vm.stickyPlayState = stateName
  })

  $scope.$on('$stateChangeCancel', function ( event, toState, toParams, fromState, fromParams) {
    //console.warn('$stateChangeCancel', JSON.stringify({toState: toState, toParams: toParams, fromState: fromState, fromParams: fromParams}, null, '  '))
  })

  $scope.$on('$stateChangeError', function ( event, toState, toParams, fromState, fromParams, error) {
    console.error('$stateChangeError', JSON.stringify({toState: toState, toParams: toParams, fromState: fromState, fromParams: fromParams}, null, '  '), error)
  })

  $scope.$on('$stateNotFound', function (event, unfoundState, fromState, fromParams) {
    console.error('$stateNotFound', JSON.stringify({unfoundState : unfoundState, fromState: fromState, fromParams: fromParams}, null, '  '))
  })

  $scope.$on('$stateChangeStart', function (event, toState, toParams, fromState, fromParams) {
    newPageSilenceEventCounter = 2
    newPageTimestamp = Date.now()
    //console.log('stateChangeStart', toState, toParams, fromState, fromParams)
    //console.trace()
    transitioningTo = toState.name
    vm.transitionAnimation = toState.transitionAnimation || fromState.transitionAnimation; // prefer the animation of the target state, otherwise use the state we came from
  })


  $scope.$on('ChangeState', function (event, data, ifCurrent) {
    //console.log('received ForceStateChange w/', data, ifCurrent, $state.current.name, transitioningTo)
    params = data.params || {}


    state = (typeof data === 'string' ? data : data.state)
    help = (transitioningTo !== undefined && transitioningTo !== $state.current.name ? transitioningTo : $state.current.name)
    if (help === ifCurrent || ifCurrent === undefined || (Array.isArray(ifCurrent) && ifCurrent.indexOf(help) !== -1)) {
      //console.log(`switching to state: ${state}`)
      var stateTransitioning = $state.go(state, params, {reload: true})
      //console.log(`switched: ${stateTransitioning}`)
    }
  })

  $scope.$on('onCrosshairVisibilityChanged', function (event, visible) {
    $scope.$applyAsync(function () {
      vm.showCrosshair = visible
    })
  })

  vm.showApps = true
  vm.uiVisible = true
  vm.mainmenu = true
  vm.gameState = null
  vm.settings = Settings
  vm.uiReady = false

  // downloader start
  var dlinfo = {}
  function cancelHelper (id, ctr) {
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
  $window.downloadStateChanged = function(data) {
    if(data.filename == '') return

    //console.log('downloadStateChanged', data)
    if(data.state == 'working' && !dlinfo[data.id]) {
      // the 0% is imporatne here, so the toaster library doesn't think the success msg later one to be a duplicate, so please leave it there
      var t = toastr.info(data.filename + ': 0%', 'Downloading mod', {
        positionClass: 'toast-top-right',
        timeOut: 0,
        extendedTimeOut: 0,
        // progressBar: true,
        closeButton: true,
        onTap: function () {
          $state.go('menu.mods.downloaded')
        }
      })
      dlinfo[data.id] = [1, t]
      console.warn(dlinfo[data.id])
    } else if(data.state == 'working' && dlinfo[data.id][0] == 1) {
      $scope.$evalAsync(function () {
        if(dlinfo[data.id]) {
          dlinfo[data.id][1].scope.message = $sce.trustAsHtml(data.filename + ": " + Math.floor(data.dlnow / data.dltotal * 100) + "%")
        }
      })

    } else if(data.state == 'finished') {
      cancelHelper(data.id)

      var t = toastr.success(data.filename, 'Downloaded mod', {
        positionClass: 'toast-top-right',
        timeOut: 20000,
        closeButton: true,
        onTap: function () {
          var help = data.filename
          if (help.slice(-4) === '.zip') {
            help = help.slice(0, -4)
          }
          $state.go('menu.mods.downloaded', {
            // modFilePath: encodeURIComponent(help)
          })
        }
      })
    }
  }
  // downloader end

  // let Lua know the UI is up and running
  angular.element(document).ready(function() {
    bngApi.engineLua("uiReady()")
    vm.uiReady = true
  })
  $scope.$on('isUIReady', function (event) {
    if(vm.uiReady) bngApi.engineLua("uiReady()")
  })

  $scope.$on('modmanagerError', function (event, data) {
    $scope.$emit('app:waiting', false)
    toastr.error(data, 'Error in Modmanager', {
      positionClass: 'toast-top-right',
      preventDuplicates: true,
      progressBar: true,
      timeOut: 10000,
      extendedTimeOut: 1000,
      closeButton: true
    })
  })

  var toasts = {}

  $scope.$on('toastrMsg', function (ev, data) {
    toasts[data.title] = toastr[data.type]($translate.instant(data.msg, data.context), $translate.instant(data.title, data.context), data.config)
  })

  $scope.$on('toastrClose', function (ev, name) {
    toastr.clear(toasts[name])
    // delete toasts[name]
  })

  vm.sections = { // defines in which state after which icons should be a divider
    freeroam: ['menu.vehicleconfig.parts', 'menu.environment', 'menu.photomode', 'menu.options.graphics'],
    scenario: ['menu.photomode'],
  }

  $scope.$on('ShowEntertainingBackground', (ev, mainmenu) => {
    //console.log("ShowEntertainingBackground")
    $scope.$evalAsync(() => {
      vm.mainmenu = mainmenu
    })
  })

  vm.openRepo = function() {
    var onlineState = Settings.values.onlineFeatures
    if (onlineState === 'enable') {
      $state.go('menu.mods.repository')
    }
    else {
      window.location.href = 'http-external://www.beamng.com/resources/'
    }
  }

  // The "GameStateUpdate" is triggered by calling "getGameState()" in the Lua engine.
  // $rootScope takes care of this each time there is a state change.
  $scope.$on('GameStateUpdate', function (event, data) {
    //console.log(`got game state: ${data.state}`, data)

    $scope.$evalAsync(() => {
        vm.gameState = data.menuItems
    })
  })

  $scope.$on('ShowApps', function (event, data) {
    // console.log('got', (data ? 'show' : 'hide'), 'apps')
    vm.showApps = data
  })

  $scope.$on("MenuFocusShow", function (event, enabled) {
    //if (!enabled) uncollectRects($scope)
  })

  // Method used to show mods on repository when 'view ingame' on https://www.beamng.com/resources/ is clicked.
  $scope.$on('ShowMod', function (event, data) {
    var startTimeout

    if (data) {
      (function checkStart() {
        // check if startScreen is still active every 100ms
        if($state.current.name === 'startScreen') {
          startTimeout = setTimeout(checkStart, 100)
        } else {
          // if no startScreen then we can continue to show mod
          window.location.href = `local://local/ui/entrypoints/main/index.html#/menu/mods/detail/${data}`
          clearTimeout(startTimeout)
        }
      })()
    }
  })

  $scope.$on('MenuToggle', (event, data) => {
    //console.log('toggleMenu', data, $state.current)
    //console.trace()
    // *** navigation back logic here
    if($state.current.backState) {
      let targetState = $state.current.backState
      if(targetState === 'BLOCK') {
        if(!$state.current.tryCounter) {
          $state.current.tryCounter = 0
        }
        $state.current.tryCounter++
        if($state.current.tryCounter < 6) {
          return
        }
        $state.current.tryCounter = null
        targetState = 'BACK_TO_MENU'
      }

      if(targetState === 'BACK_TO_MENU') {
        targetState = vm.mainmenu ? 'menu.mainmenu' : 'menu'
      }
      $state.go(targetState) // , stateParams)
      return
    } else if($state.current.backAction) {
      $state.current.backAction($state)
    }

    //console.log(`received MenuToggle in gamestate: ${vm.gameState}. currently in state: ${$state.current.name}`)

    let showMenu = false
    $scope.$evalAsync(function () {
      if (typeof(data) == 'boolean') {
        showMenu = data
      } else {
        showMenu = $state.current.name !== 'menu'
      }
      if (showMenu) {
        $state.go(vm.mainmenu ? 'menu.mainmenu' : 'menu')
      } else {
        // figure out where to go 'back' to. Normally the play state, but in scenarios it might be different
        let targetState = 'play'
        if(vm.stickyPlayState) {
          targetState = vm.stickyPlayState
        }
        $state.go(targetState)
      }
    })
    bngApi.engineLua(`extensions.hook("onMenuToggled", ${showMenu})`)
  })


  $scope.$on('MenuHide', function (event, data) {
    // TODO FIXME
    //console.log(">>>> MENUHIDE")
    //console.trace()
    // TODO: FIXME
    let showMenu = false
    if (typeof(data) == 'boolean') {
      showMenu = data
    }
    if (showMenu) {
      $state.go(vm.mainmenu ? 'menu.mainmenu' : 'menu')
    } else {
      $state.go('play')
    }
  })

  $scope.$on('onCefVisibilityChanged', function (event, cefVisible) {
    $scope.$evalAsync(function () {
        vm.uiVisible = cefVisible
    })
  })

  $scope.$on('hide_ui', function (event, visible) {
    let cmd = (visible === undefined) ? `extensions.ui_visibility.toggleCef()` : `extensions.ui_visibility.set(${visible})`
    console.error('The hide_ui function is deprecated and will stop working in the future. Please use ' + cmd)
    bngApi.engineLua(cmd)
  })

  vm.quit = function () {
    if (vm.mainmenu) {
      bngApi.engineScript('quit();'); //It should work but doesn't, `Platform::postQuitMessage` is executed but nothing happens, maybe CEF catch that message
      bngApi.engineLua("TorqueScript.eval('quit();')")
    } else {
      bngApi.engineLua("returnToMainMenu()")
    }
  }

  $scope.$on('CloseMenu', () => {
    var newTarget = vm.mainmenu ? 'menu.mainmenu' : 'menu'
    $state.go(newTarget)
  })

  $scope.$on('quit', vm.quit)

  $scope.$on('SettingsChanged', (ev, data) => {
    //console.log('SettingsChanged, updating languages... ', data.values.uiLanguage)
    if(data.values.uiLanguage && data.values.uiLanguage !== '' && i18NLanguageFinished && i18nLanguageUsed !== data.values.uiLanguage) {
      $rootScope.$eval(function() {
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
  $scope.$on('MenuOpenModule', function (event, data) {
    //console.log('received MenuOpenModule w/', data)
    switch (data) {
    case 'help':
      $state.go('menu.help')
      break
    case 'vehicleselect':
      $state.go('menu.vehicles')
      break
    case 'vehicleconfig':
      $state.go('menu.vehicleconfig.parts')
      break
    case 'options':
      $state.go('menu.options.graphics')
      break
    case 'appedit':
      $state.go('menu.appedit')
      break
    default:
      $state.go(data)
      break
    }
  })

  $scope.$on('InputBindingsChanged', function (event, data) {
    $scope.pauseControlText = ""
    $scope.pauseControlIcon = ""
    for (var i = 0; i < data.bindings.length; i++) {
      for (var j = 0; j < data.bindings[i].contents.bindings.length; j++) {
        var binding = data.bindings[i].contents.bindings[j]
        if (binding.action != "pause") continue
        $scope.pauseControlText = binding.control
        $scope.pauseControlIcon =  ControlsUtils.deviceIcon(data.bindings[i].contents.devicetype)
        break
      }
    }
  })

  $scope.$on('physicsStateChanged', function (event, state) {
    $scope.$evalAsync(function () {
      vm.physicsMaybePaused = !state
      updatePauseState()
    })
  })

  $scope.$on('replayStateChanged', function (event, core_replay) {
    $scope.$evalAsync(function () {
      vm.replayActive = core_replay.state === 'playing'
      vm.replayPaused = vm.replayActive && core_replay.paused
      updatePauseState()
    })
  })


  vm.unpause = function () {
    bngApi.engineLua('bullettime.pause(false)')
  }

  $scope.$on('requestPhysicsState', function (event) {
    $scope.$broadcast('physicsStateChanged', !vm.physicsPaused)
  })
  // -------------------------------------- BEAMMP -------------------------------------- //
  //ingame red connection warning
  $scope.$on('showConnectionIssues', function(evt, data) {
    vm.showConnectionIssues = data;
  });

	// -------------------------------------- BEAMMP -------------------------------------- //

  vm.isWaiting = false

  $scope.$on('app:waiting', function (event, value, callback) {
    vm.isWaiting = value
    Utils.waitForCefAndAngular(() => {
      if (callback !== undefined && typeof callback === 'function') {
        callback(vm.isWaiting)
      }
    })
  })

  $scope.$on('onLevelsChanged', function(event, data){
    levelsData = data
  })
  bngApi.engineLua('extensions.core_levels.requestData()')

  /*
  $rootScope.$watch(function() {
    console.log("### DIGEST ###")
    /// if you want to find out where the digest is triggered:
    //console.trace()
  })
  */

}])

.service('BlurGame', [function () {
  // todo: find a solution if i should actually overflow at some point
  let i = 0
  let list = {}
  let disabled = false


  function updateLua () {
    // console.log('update blur to lua', list);
    bngApi.engineLua(`extensions.ui_gameBlur.replaceGroup("uiBlur", ${bngApi.serializeToLua(disabled ? {} : list)})`);
  }

  return {
    register: function (coord) {
      if (coord !== undefined) {
        i += 1;

        if (list.isEmpty()) {
          bngApi.engineLua('extensions.load("ui_gameBlur");');
        }

        list[i] = coord;
      } else {
        throw new Error('You need to specify the coordinates to register');
      }
      updateLua();

      return i;
    },
    unregister: function (i) {
      delete list[i];
      updateLua();

      if (list.isEmpty()) {
        i = 0;
        bngApi.engineLua('extensions.unload("ui_gameBlur");');
      }
    },
    update: function (i, coord) {
      list[i] = coord;
      updateLua();
    },
    disable: function (bool) {
      disable = !!bool;
      updateLua();
    }
  }
}])

.directive('bngBlur', ['BlurGame', 'RateLimiter', function (BlurGame, RateLimiter) {
  return {
    restrict: 'A',
    link: function (scope, elem, attrs) {
      let id
      let blurAmount = 1
      let blurUpdateWrapper = RateLimiter.debounce(updateBlur, 50)

      const resizeObserver = new ResizeObserver(entries => {
        blurUpdateWrapper()
      })
      resizeObserver.observe(elem[0])

      scope.$watch(attrs.bngBlur, (val) => {
        if (val !== undefined) {
          if(val === true) {
            val = 1
          } else if(val === false) {
            val = 0
          }
          blurAmount = val;
          blurUpdateWrapper()
        }
      });

      function calcBlur () {
        let help = elem[0].getBoundingClientRect();
        return [
          help.left / screen.width, // x
          help.top / screen.height, // y
          help.width / screen.width, // width
          help.height / screen.height, // height
          blurAmount
        ];
      }

      function updateBlur () {
        if (blurAmount > 0) {
          if (id === undefined) {
            id = BlurGame.register(calcBlur())
          } else {
            BlurGame.update(id, calcBlur())
          }
        } else {
          BlurGame.unregister(id)
          id = undefined
        }
      }

      scope.$on('$destroy', () => {
        BlurGame.unregister(id)
      })

      scope.$on('windowResize', () => {
        blurUpdateWrapper()
      })
    }
  }
}])

// this directive translates the view frustum a bit to make up for lost space behind side menu and alike
// use it like this: <md-content bng-frustum-mover="left">
.directive('bngFrustumMover', ['RateLimiter', function (RateLimiter) {
  return {
    restrict: 'A',
    link: function (scope, elem, attrs) {
      function updateGE() {
        let screenWidth = window.screen.width
        let sideBarWidth = elem[0].getBoundingClientRect().width
        let percentHidden = (sideBarWidth / screenWidth) * 0.1 // no idea why 1/10 of it :|
        if(attrs.bngFrustumMover === 'left') {
          percentHidden *= -1
        } else if(attrs.bngFrustumMover === 'right') {
          //all good
        } else {
          console.error("only left/rigth supported right now")
        }
        if(0.1 - Math.abs(percentHidden) < 0.0001) {
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
      scope.$on('$destroy', () => {
        //console.log("resetting frustom side offset")
        bngApi.engineLua(`scenetree.OnlyGui:setFrustumCameraCenterOffset(Point2F(0, 0))`)
      })

      scope.$on('windowResize', () => {
        updateGE()
      })
    }
  }
}])
