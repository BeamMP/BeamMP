angular.module('beamng.stuff', ['ngAnimate', 'toastr']);
angular.module('beamng.gameUI', ['ngAnimate', 'toastr']);
angular.module('beamng.garage', []);
angular.module('beamng.color', []);
angular.module('beamng.gamepadNav', []);
angular.module('beamng.controls', []);
angular.module('beamng.ui2Ports', []);

angular.module('BeamNG.ui', ['beamng.ui2Ports', 'beamng.core', 'beamng.components', 'beamng.data', 'ngMaterial', 'ngAnimate', 'ui.router', 'beamng.stuff', 'beamng.gameUI', 'beamng.apps', 'beamng.color', 'beamng.garage', 'pascalprecht.translate', 'beamng.gamepadNav', 'beamng.controls', 'fc.paging','ngSanitize','jkAngularRatingStars','ngFitText'])

.factory('customTranslationsLoader', ['$rootScope', '$timeout', '$q', function ($rootScope, $timeout, $q) {
  var data = {};
  $rootScope.$on('translationFileUpdate', (ev, d) => {data = d});
  return function (options) {
    var deferred = $q.defer();
    $timeout(() => {
      if (data[options.key]) {
        return deferred.resolve(data[options.key].translations);
      }
      return deferred.reject(options.key);
    }, 100);
    return deferred.promise;
  };
}])

.config(['$compileProvider', '$logProvider', 'loggerProvider', '$stateProvider', '$urlRouterProvider', '$mdThemingProvider', '$translateProvider', 'AppDefaults', 'toastrConfig', '$provide',
  function($compileProvider, $logProvider, loggerProvider, $stateProvider, $urlRouterProvider, $mdThemingProvider, $translateProvider, AppDefaults, toastrConfig, $provide) {

  // removed custom loader for now: does not work when changing languages
  // $translateProvider.useLoader('customTranslationsLoader');
  $translateProvider.useStaticFilesLoader({
    prefix: '/locales/',
    suffix: '.json'
  });
  $translateProvider.useSanitizeValueStrategy('escaped');
  $translateProvider.preferredLanguage('en-US'); // this is the default language to load
  $translateProvider.fallbackLanguage('en-US'); // this is the fallback in case individual translations are missing

  // ------------------- REMOVE THIS ASAP: ONLY FOR TRANSLATION DEBUGGING PURPOSE ------------------
  // the filter breaks the direct translation of the gameplay page when the user changes the language setting
  // var debugTranslationsKey = 'beamng:debugTranslations';

  // if (! window.localStorage.getItem(debugTranslationsKey))
  //   window.localStorage.setItem('beamng:debugTranslations', '0'); // normal translations by default

  // window.toggleDebugTranslations = function () {
  //   var dt = parseInt(window.localStorage.getItem(debugTranslationsKey));
  //   window.localStorage.setItem(debugTranslationsKey, dt > 0 ? '0' : '1');
  //   window.location.reload();
  // };

  // $provide.decorator('translateFilter',  function ($delegate) {
  //   return function () {
  //     var debugMode = parseInt(window.localStorage.getItem(debugTranslationsKey)) > 0;
  //     return debugMode ? arguments['0'] : $delegate.apply(this, arguments);
  //   };
  // });
  // ------------------------------------------------------------------------------------------------





  //$translateProvider.use('de-DE');

  window.jsLogging = { provider: $logProvider, enabled: true};
  $logProvider.debugEnabled(false);
  // Aux.logging = {provider: $logProvider, enabled: false};

  // should be enabled? (default: true)
  loggerProvider.enabled(true);
  // loggerProvider.crazyAlign(true);
  loggerProvider.crazyAlign(false);
  loggerProvider.align(false);
  // Define classes:
  loggerProvider.addClasses(['HookManager', 'spatialNav', 'spine', 'spinePerf', 'mainMenu', 'jsonDump', 'AppCtrl', 'StreamsManager', 'AppLayout', 'app-container', 'Modmanager', 'App', 'vehicleconfig', 'garageParts', 'gamepadNav', 'authGame', 'scenarioControl', 'UiUnits']);
  // show everything except specified
  loggerProvider.hideMessages(['HookManager', 'spatialNav', 'spine', 'spinePerf', 'mainMenu', 'jsonDump', 'AppCtrl', 'StreamsManager', 'AppLayout', 'app-container', 'Modmanager', 'vehicleconfig', 'garageParts', 'scenarioControl', 'gamepadNav'], true);
  // hide everything except specified
  // loggerProvider.hideMessages(['warn', 'log'], false);

  // ..... User Interface states
  $stateProvider

  .state('menu', {
    url: '/menu',
    templateUrl: 'entrypoints/main/menu.html',
    controller: 'MenuController as menuCtrl'
  })

    .state('menu.mainmenu', {
      url: '/mainmenu',
      templateUrl: `modules/mainmenu/${beamng.product}/mainmenu.html`,
      controller: 'MainMenuController',
    })

    .state('menu.onlineFeatures', {
      url: '/onlineFeatures',
      templateUrl: `modules/onlineFeatures/online.html`,
      controller: 'OnlineFeaturesController',
    })

    .state('menu.playmodes', {
      url: '/playmodes',
      templateUrl: 'modules/playmodes/playmodes.html',
      controller: 'PlayModesController as modes'
    })

    .state('menu.levels', {
      url: '/levels',
      templateUrl: 'modules/levelselect/levelselect.html',
      controller:  'LevelSelectController as levels'
    })

    .state('menu.levelDetails', {
      url: '/levels-details/:level/:spawnPoint',
      templateUrl: 'modules/levelselect/levelselect-details.html',
      controller:  'LevelSelectDetailsController as levelsDetails'
    })

    .state('menu.busRoutes', {
      url: '/bus',
      templateUrl: 'modules/busRoute/busRoute.html',
      controller: 'BusRoutesController as busCtrl'
    })

    .state('menu.busRoutesLevelSelect', {
      url: '/bus/level',
      templateUrl: 'modules/busRoute/levelSelect.html',
      controller: 'BusRoutesLevelController'
    })


    .state('menu.busRoutesRouteSelect', {
      url: '/bus/route',
      templateUrl: 'modules/busRoute/routeSelect.html',
      controller: 'BusRoutesRouteController'
    })

    .state('menu.environment', {
      url: '/environment',
      templateUrl: 'modules/environment/environment.html',
      controller:  'EnvironmentController as environment'
    })

    // Track Builder
    // .state('menu.trackBuilder', {
    //   url: '/trackBuilder',
    //   templateUrl: 'modules/trackBuilder/trackBuilder.html',
    //   controller:  'TrackBuilderController as trackBuilder'
    // })

    .state('menu.scenarios', {
      url: '/scenarios',
      templateUrl: 'modules/scenarioselect/scenarioselect.html',
      controller: 'ScenarioSelectController'
    })

    .state('menu.campaigns', {
      url: '/campaigns',
      templateUrl: 'modules/campaignselect/campaignselect.html',
      controller: 'CampaignSelectController as campaignSelect'
    })



    .state('appedit', {
      url: '/appedit',
      templateUrl: 'modules/appselect/appedit.html',
      controller: 'AppEditController'
    })

    // modWizard
    // .state('menu.modwizard', {
    //   url: '/modwizard',
    //   templateUrl: 'modules/modwizard/modwizard.html',
    //   controller:  'ModWizardController as modWzrdCtrl'
    // })

    // .state('menu.skinwizard', {
    //   url: '/modwizard/skin',
    //   templateUrl: 'modules/modwizard/skinWizard/skinwizard.html',
    //   controller:  'SkinWizardController as skinWzrdCtrl'
    // })

    // .state('menu.vehiclewizard', {
    //   url: '/modwizard/vehicle',
    //   templateUrl: 'modules/modwizard/vehicleWizard/vehiclewizard.html',
    //   controller:  'VehicleWizardController as vhclWzrdCtrl'
    // })

    // .state('menu.terrainwizard', {
    //   url: '/modwizard/terrain',
    //   templateUrl: 'modules/modwizard/terrainWizard/terrainwizard.html',
    //   controller:  'TerrainWizardController as terrWzrdCtrl'
    // })

    // .state('menu.appwizard', {
    //   url: '/modwizard/app',
    //   templateUrl: 'modules/modwizard/appwizard.html',
    //   controller:  'appWizardController as appWizard'
    // })

    // .state('menu.configwizard', {
    //   url: '/modwizard/config',
    //   templateUrl: 'modules/modwizard/configwizard.html',
    //   controller:  'configWizardController as configWizard'
    // })

    .state('appselect', {
      url: '/appselect',
      templateUrl: 'modules/appselect/appselect.html',
      controller: 'AppSelectController as apps'
    })

    .state('menu.vehicles', {
      url: '/vehicleselect/:garage/:mode/:event',
      templateUrl: 'modules/vehicleselect/vehicleselect.html',
      controller: 'VehicleSelectController as vehicles',
    })

    .state('menu.vehicleDetails', {
      url: '/vehicle-details/:model/:config/:mode/:event',
      templateUrl: 'modules/vehicleselect/vehicleselect-details.html',
      controller: 'VehicleDetailsController as vehicle'
    })
	
	// -------------------------------------- BEAMMP -------------------------------------- //
	.state('menu.multiplayer', {
	  url: '/multiplayer',
	  templateUrl: 'modules/multiplayer/multiplayer.html',
	  controller: 'MultiplayerController as multiplayer'
	})

	  .state('menu.multiplayer.servers', {
	    url: '/mpservers',
	    templateUrl: 'modules/multiplayer/servers.partial.html',
	    controller: 'MultiplayerServersController as multiplayermenu'
	  })

	  .state('menu.multiplayer.recent', {
	    url: '/mpservers',
	    templateUrl: 'modules/multiplayer/recent.partial.html',
	    controller: 'MultiplayerRecentController as multiplayermenu'
	  })

  	  .state('menu.multiplayer.favorites', {
  	    url: '/mpfavorites',
  	    templateUrl: 'modules/multiplayer/favorites.partial.html',
  	    controller: 'MultiplayerFavoritesController as multiplayermenu'
  	  })

	  .state('menu.multiplayer.direct', {
	    url: '/mpdirect',
	    templateUrl: 'modules/multiplayer/direct.partial.html',
	    controller: 'MultiplayerDirectController as multiplayermenu'
	  })
	// -------------------------------------- BEAMMP -------------------------------------- //

    .state('menu.options', {
      url: '/options',
      templateUrl: 'modules/options/options.html',
      controller: 'OptionsController',
      controllerAs: 'options',
      abstract: true
    })
      .state('menu.options.graphics', {
        url: '/graphics',
        templateUrl: 'modules/options/graphics.partial.html',
        controller: 'SettingsGraphicsCtrl as opt'
      })

      .state('menu.options.audio', {
        url: '/audio',
        templateUrl: 'modules/options/audio.partial.html',
        controller: 'SettingsAudioCtrl as opt'
      })

      .state('menu.options.gameplay', {
        url: '/gameplay',
        templateUrl: 'modules/options/gameplay.partial.html',
        controller: 'SettingsGameplayCtrl as opt'
      })

      .state('menu.options.camera', {
        url: '/camera',
        templateUrl: 'modules/options/camera.partial.html',
        controller: 'SettingsGameplayCtrl as opt'
      })

      .state('menu.options.userInterface', {
        url: '/userInterface',
        templateUrl: 'modules/options/userinterface.partial.html',
        controller: 'SettingsGameplayCtrl as opt'
      })

      .state('menu.options.language', {
        url: '/language',
        templateUrl: 'modules/options/language.partial.html',
        controller: 'SettingsGameplayCtrl as opt'
      })

      .state('menu.options.other', {
        url: '/other',
        templateUrl: 'modules/options/other.partial.html',
        controller: 'SettingsGameplayCtrl as opt'
      })
	  
	  // -------------------------------------- BEAMMP -------------------------------------- //
	  .state('menu.options.multiplayer', {
        url: '/multiplayer',
        templateUrl: 'modules/options/multiplayer.partial.html',
        controller: 'SettingsGameplayCtrl as opt'
      })
	  // -------------------------------------- BEAMMP -------------------------------------- //

      .state('menu.options.licenses', {
        url: '/licenses',
        templateUrl: 'modules/options/licenses.partial.html',
        controller: 'SettingsGameplayCtrl as opt'
      })

      .state('menu.options.controls', {
        url: '/controls',
        templateUrl: 'modules/options/controls.html',
        controller: 'ControlsController as controls'
      })
        .state('menu.options.controls.bindings', {
          views: {
            '': {
              url: '/bindings',
              templateUrl: 'modules/options/controls-bindings.html',
              controller: 'ControlsBindingsCtrl as controlsBindings'
            }
          }
        })
            .state('menu.options.controls.bindings.edit', {
              views: {
                'edit@menu.options': {
                  url: '/edit',
                  templateUrl: 'modules/options/controls-edit.html',
                  controller: 'ControlsEditCtrl as controlsEdit'
                }
              },
              params: {action: '', oldBinding: {}, showFfb: false}
            })

        .state('menu.options.controls.filters', {
          views: {
            '': {
              url: '/filters',
              templateUrl: 'modules/options/controls-filters.html',
              controller: 'ControlsFiltersCtrl as controlsFilters'
            }
          }
        })

        .state('menu.options.controls.ffb', {
          views: {
            '': {
              url: '/ffb',
              templateUrl: 'modules/options/controls-ffb.html',
              controller: 'ControlsFfbCtrl as controlsFfb'
            }
          }
        })

            .state('menu.options.controls.ffb.edit', {
              views: {
                'edit@menu.options': {
                  url: '/edit',
                  templateUrl: 'modules/options/controls-edit.html',
                  controller: 'ControlsEditCtrl as controlsEdit'
                }
              },
              params: {action: '', oldBinding: {}, showFfb: ''}
            })

      .state('menu.options.controls.hardware', {
        views: {
          '': {
            url: '/hardware',
            templateUrl: 'modules/options/controls-hardware.html',
            controller: 'ControlsHardwareCtrl as controlsHw'
          }
        }
      })

    .state('menu.debug', {
      url: '/debug',
      templateUrl: 'modules/debug/debug.html',
      controller:  'DebugController as debug'
    })

    .state('menu.vehicleconfig', {
      url: '/vehicle-config',
      templateUrl: 'modules/vehicleconfig/vehicleconfig.html',
      controller: 'VehicleconfigCtrl',
      redirectTo: 'menu.vehicleconfig.parts'
    })

    .state('menu.vehicleconfig.parts', {
      url: '/vehicle-config/parts',
      templateUrl: 'modules/vehicleconfig/partial.parts.html',
      controller: 'Vehicleconfig_parts as vehConf_parts'
    })

    .state('menu.vehicleconfig.tuning', {
      url: '/vehicle-config/tuning',
      templateUrl: 'modules/vehicleconfig/partial.tuning.html',
      controller: 'Vehicleconfig_tuning as vehConf_tuning'
    })

    .state('menu.vehicleconfig.color', {
      url: '/vehicle-config/color',
      templateUrl: 'modules/vehicleconfig/partial.color.html',
      controller: 'Vehicleconfig_color as vehConf_color'
    })

    .state('menu.vehicleconfig.save', {
      url: '/vehicle-config/save',
      templateUrl: 'modules/vehicleconfig/partial.save.html',
      controller: 'Vehicleconfig_save as vehConf_save'
    })


    .state('menu.help', {
      url: '/help:pageIndex',
      templateUrl: 'modules/help/help.html',
      controller: 'HelpController'
    })

    .state('menu.mods', {
      url: '/mods',
      template: '<ui-view class="filler" style="position: relative;"></ui-view>',
      controller: 'ModManagerController as modCtrl'
    })

      .state('menu.mods.local', {
        url: '/local',
        views: {
          '': {
            controller: 'LocalModController as modLoclCtrl',
            templateUrl: 'modules/modmanager/mods.html'
          },
          'content@menu.mods.local': {
            templateUrl: 'modules/modmanager/local.html'
          },
          'filter@menu.mods.local': {
            templateUrl: 'modules/modmanager/filter.html'
          }
        }
      })

      .state('menu.mods.downloaded', {
        url: '/downloaded',
        views: {
          '': {
            controller: 'DownloadModController as modDwlCtrl',
            templateUrl: 'modules/modmanager/mods.html'
          },
          'content@menu.mods.downloaded': {
            templateUrl: 'modules/modmanager/downloaded.html',
          }
        }
      })

      .state('menu.mods.scheduled', {
        url: '/scheduled',
        views: {
          '': {
            controller: 'ScheduledModController as modSchCtrl',
            templateUrl: 'modules/modmanager/mods.html'
          },
          'content@menu.mods.scheduled': {
            templateUrl: 'modules/modmanager/scheduled.html',
          },
          'filter@menu.mods.scheduled': {
            templateUrl: 'modules/modmanager/scheduled_conflict.html'
          }
        }
      })

      .state('menu.mods.repository', {
        url: '/repository?query',
        views: {
          '': {
            controller: 'RepositoryController as repo',
            templateUrl: 'modules/modmanager/mods.html'
          },
          'content@menu.mods.repository': {
            templateUrl: 'modules/repository/repository.html'
          },
          'filter@menu.mods.repository': {
            templateUrl: 'modules/repository/filter.html'
          }
        }
      })

      .state('menu.mods.automation', {
        url: '/automation?query',
        views: {
          '': {
            controller: 'AutomationController as automation',
            templateUrl: 'modules/modmanager/mods.html'
          },
          'content@menu.mods.automation': {
            templateUrl: 'modules/automation/automation.html'
          },
          'filter@menu.mods.automation': {
            templateUrl: 'modules/automation/filter.html'
          }
        },

      })

      .state('menu.mods.automationDetails', {
        url: '/automation/detail/{modId:[0-9A-Z]+}?page&param',
        views: {
          '': {
            controller: 'AutomationDetailsController as automationDetailCtrl',
            templateUrl: 'modules/modmanager/mods.html'
          },
          'content@menu.mods.automationDetails': {
            templateUrl: 'modules/automation/automation-details.html'
          },
          'filter@menu.mods.automationDetails': {
            templateUrl: 'modules/automation/info.html'
          }
        },
      })

      .state('menu.mods.details', {
        url: '/detail/{modId:[0-9A-Z]+}?page&param',
        views: {
          '': {
            controller: 'RepositoryDetailsController as repoDetailCtrl',
            templateUrl: 'modules/modmanager/mods.html'
          },
          'content@menu.mods.details': {
            templateUrl: 'modules/repository/repository-details.html'
          },
          'filter@menu.mods.details': {
            templateUrl: 'modules/repository/info.html'
          }
        },
      })

    .state('menu.modsDetails', {
      url: '/modmanager/details:modFilePath',
      templateUrl: 'modules/modmanager/info.html',
      controller: 'ModManagerControllerDetails'
    })

    .state('menu.audiodebug', {
      url: '/audiodebug',
      templateUrl: 'modules/audiodebug/audiodebug.html',
      controller: 'AudioDebugController'
    })


  .state('scenario-start', {
    url: '/scenariocontrol/start',
    params: {
      data: {}
    },
    templateUrl: 'modules/scenariocontrol/start.html',
    controller: 'ScenarioStartController as scenarioStart'
  })

  .state('scenario-end', {
    url: '/scenariocontrol/end',
    params: {
        stats: {},
        rewards: {},
        portrait: {}
    },
    templateUrl: 'modules/scenariocontrol/end.html',
    controller: 'ScenarioEndController'
  })

  .state('quickrace-end', {
    url: '/quickraceEnd',
    params: {
        stats: {}
    },
    templateUrl: 'modules/scenariocontrol/quickraceEnd.html',
    controller: 'ScenarioEndController'
  })

  .state('chapter-end', {
    url: '/cchapterEnd',
    params: {
        stats: {}
    },
    templateUrl: 'modules/scenariocontrol/end.html',
    controller: 'ScenarioEndController'
  })

  // Transition to this state is handled by some unknown dark force (Torque?).
  // Until this chanages, keep the url hash to "loading".
  .state('loading', {
    url: '/loading',
    templateUrl: 'modules/loading/loading.html',
    controller:  'LoadingController as loading',
    transitionAnimation: 'moduleBlendOnLeave',
  })

  .state('comic', {
    url: '/comic',
    params: {
        comiclist: {}
    },
    templateUrl: 'modules/comic/comic.html',
    controller: 'ComicController'
  })

  .state('photomode', {
    url: '/photo-mode',
    templateUrl: 'modules/photomode/photomode.html',
    controller:  'PhotoModeController as photo'
  })

  .state('menu.replay', {
    url: '/replay',
    templateUrl: 'modules/replay/replay.html',
    controller:  'ReplayController as replay'
  })

  .state('credits', {
    url: '/credits',
    templateUrl: 'modules/credits/credits.html',
    controller: 'CreditsController as credits'
  })

  .state('startScreen', {
    url: '/startScreen',
    templateUrl: 'modules/startScreen/startScreen.html',
    controller: 'startScreenController as startScreen',
    transitionAnimation: 'moduleStartScreenFade',
  })

  .state('iconViewer', {
    url: '/iconViewer',
    templateUrl: 'modules/iconView/icons.html',
    controller: 'iconViewerCtrl as iconCtrl',
  })


  .state('garage', {
      url: '/garageNew',
      templateUrl: 'modules/garageNew/garage.html',
      controller: 'garageCtrl'
    })

      .state('garage.menu', {
        url: '/garageNew',
        templateUrl: 'modules/garageNew/garageMenu/menu.html',
        controller: 'garageMenuCtrl as gp'
      })


      .state('garage.menu.select', {
        url: '/garageNew/select',
        templateUrl: 'modules/garageNew/garageSelect/select.html',
        controller: 'garageSelect as gpSelect'
      })

      .state('garage.menu.parts', {
        url: '/garageNew/parts',
        templateUrl: 'modules/garageNew/garageParts/parts.html',
        controller: 'garageParts as gpParts'
      })

      .state('garage.menu.tune', {
        url: '/garageNew/tune',
        templateUrl: 'modules/garageNew/garageTune/tune.html',
        controller: 'garageTune as gpTune'
      })

      .state('garage.menu.paint', {
        url: '/garageNew/paint',
        templateUrl: 'modules/garageNew/garagePaint/paint.html',
        controller: 'garagePaint as gpPaint'
      })

      .state('garage.menu.photo', {
        url: '/garageNew/photo',
        templateUrl: 'modules/garageNew/garagePhoto/photo.html',
        controller: 'garagePhoto as gpPhoto'
      })

      .state('garage.menu.load', {
        url: '/garageNew/load',
        templateUrl: 'modules/garageNew/garageLoad/load.html',
        controller: 'garageLoad as gpLoad'
      })

      .state('garage.save', {
        url: '/garageNew/save',
        templateUrl: 'modules/garageNew/garageSave/save.html',
        controller: 'garageSave as gpSave'
      })

    // ingame garage prototype
    .state('garageProto', {
      url: '/garageProto',
      templateUrl: 'modules/garagePrototype/garage.html',
      controller: 'garageProtoCtrl'
    })

      .state('garageProto.menu', {
        url: '/garageProto',
        templateUrl: 'modules/garagePrototype/garageMenu/menu.html',
        controller: 'garageProtoMenuCtrl as gpProtoMenu'
      })

      .state('garageProto.menu.select', {
        url: '/garageProto/select',
        params: {
          vehicles: {},
          mode:     {},
          money:    {}
        },
        templateUrl: 'modules/garagePrototype/garageSelect/select.html',
        controller: 'garageProtoSelect as gpProtoSelect'
      })


    .state('mapview', {
      url: '/mapview',
      templateUrl: 'modules/mapview/mapview.html',
      controller: 'MapViewCtrl as mapview',
      params: {
        data: {}
      }
      // params: {
      //   baseImg: '',
      //   points: [],
      //   onClick: ''
      // }
    })

    //Dragrace states WIP
    .state('menu.dragRaceOverview', {
      url: '/dragrace/overview',
      templateUrl: 'modules/dragrace/overview.html',
      controller: 'DragRaceController',
      params: {
        results: {}
      }
    })

    // LightRunner States
    .state('menu.lightrunnerOverview', {
      url: '/lightrunner/overview',
      templateUrl: 'modules/lightrunner/overview.html',
      controller: 'LightRunnerController',
    })

    .state('menu.lightrunnerTrackSelect', {
      url: '/lightrunner/track',
      templateUrl: 'modules/lightrunner/trackSelect.html',
      controller: 'LightRunnerTrackController'
    })

    //Quickrace states WIP
    .state('menu.quickraceOverview', {
      url: '/quickrace/overview',
      templateUrl: 'modules/quickrace/overview.html',
      controller: 'QuickraceController',
    })

    .state('menu.quickraceLevelselect', {
      url: '/quickrace/level',
      templateUrl: 'modules/quickrace/levelSelect.html',
      controller: 'QuickraceLevelController'
    })

    .state('menu.quickraceTrackselect', {
      url: '/quickrace/track',
      templateUrl: 'modules/quickrace/trackSelect.html',
      controller: 'QuickraceTrackController'
    })

    .state('campaign', {
      url: '/campaign',
      template: '<ui-view class="container"></ui-view>'
    })

    .state('campaign.quickraceOverview', {
      url: '/quickrace/overview',
      params: {
        level: {},
        track: {},
        vehicles: {},
      },
      templateUrl: 'modules/quickrace/overview.html',
      controller: 'QuickraceController'
    })

    .state('campaign.quickraceLevelselect', {
      url: '/quickrace/level',
      templateUrl: 'modules/quickrace/levelSelect.html',
      controller: 'QuickraceLevelController'
    })


    .state('campaign.quickraceTrackselect', {
      url: '/quickrace/track',
      templateUrl: 'modules/quickrace/trackSelect.html',
      controller: 'QuickraceTrackController'
    })

    .state('campaign.vehicles', {
      url: '/vehicleselect/:garage/:mode',
      templateUrl: 'modules/vehicleselect/vehicleselect.html',
      controller: 'VehicleSelectController as vehicles',
    })

    .state('campaign.vehicleDetails', {
      url: '/vehicle-details/:model/:config/:mode',
      templateUrl: 'modules/vehicleselect/vehicleselect-details.html',
      controller: 'VehicleDetailsController as vehicle'
    })

    //-------------------------------------------------------------- UI3 states ---- test space ----------------------------------***************************
    .state('menu.menu2view', {
      url: '/menu2',
      templateUrl: `modules/mainmenu2/menu2view.html`,
      controller: 'MainMenu2Controller',
    })

    .state('menu.menu2view.mainMenu2', {
      url: '/mainmenu2',
      templateUrl: `modules/mainmenu2/mainmenu2.html`,
      controller: '',
    })

    .state('menu.menu2view.quickPlayMenu', {
      url: '/quickplay',
      templateUrl: 'modules/quickplaymenu/quickplaymenu.html',
      controller: '' //TODO
    })

    .state('menu.menu2view.freePlay', {
      url: '/freeplay',
      templateUrl: 'modules/freeplay/freeplay.html',
      controller: 'FreePlayController as fpctrl'
    })

    .state('menu.menu2view.freePlaySpawn', {
      url: '/freeplay/:level',
      templateUrl: 'modules/freeplay-spawn/freeplay-spawn.html',
      controller: 'FreePlaySpawnController as fpsctrl'
    })

    .state('menu.menu2view.modManager2', {
      url: '/modmanager',
      templateUrl: 'modules/modmanager2/modmanager2.html',
      controller: '' //TODO
    })

    .state('menu.menu2view.options2', {
      url: '/options',
      templateUrl: 'modules/options2/options2.html',
      controller: '' //TODO
    })

    .state('menu.menu2view.graphicsBasic', {
      url: '/options/graphicsbasic',
      templateUrl: 'modules/options2/graphicsbasic/graphicsbasic.html',
      controller: 'OptionsGraphicsController' //TODO
    })

    //-------------------------------------------------------------- UI3 states ---- test space ----------------------------------***************************
    ;

  if(beamng.shipping) {
    $stateProvider

    ;
  }

  for (var key in AppDefaults.playModes) {
    if (AppDefaults.playModes[key].targetState == "career") {
      if (!AppDefaults.playModes[key].disabled) {
        $stateProvider.state('menu.career', {
          url: '/career',
          templateUrl: 'modules/careerselect/careerselect.html',
          controller: 'CareerSelectController as careerSelect'
        });
      }
      break;
    }
  }

  // default entry that is loaded on startup:
  // if(beamng.buildtype === 'GDC17') {
    // $urlRouterProvider.otherwise('loading');
  // } else
  if (beamng.shipping && beamng.buildtype === 'RELEASE') {
    $urlRouterProvider.otherwise('startScreen');
  } else {
    $urlRouterProvider.otherwise('/menu/mainmenu');
  }


  $compileProvider.debugInfoEnabled(false);

  // whitelist for local:// prefix
  $compileProvider.aHrefSanitizationWhitelist(/^\s*(https?|ftp|mailto|local):/);
  $compileProvider.imgSrcSanitizationWhitelist(/^\s*(https?|ftp|mailto|local):/);


  // Very unsatisfying, but chreating a proper pallete based on this color results in a200 having a too big luminance value and thus not looking good anymore
  $mdThemingProvider.definePalette('beamng-orange', {
    '50': '#ffffff',
    '100': '#ffd7bd',
    '200': '#ffb685',
    '300': '#ff8b3d',
    '400': '#ff781f',
    '500': '#ff6600',
    '600': '#e05a00',
    '700': '#FF6700',
    '800': '#a34100',
    '900': '#853500',
    'A100': '#FFD7BD',
    'A200': '#ff6600',
    'A400': '#ff781f',
    'A700': '#FF6700',
    'contrastDefaultColor': 'light',    // whether, by default, text (contrast)
                                        // on this palette should be dark or light
    'contrastDarkColors': ['50', '100', //hues which contrast should be 'dark' by default
     '200', '300', '400', 'A100'],
    'contrastLightColors': undefined    // could also specify this if default was 'dark'
  });

  // todo: fix this to use settings instead
  var uiTheme = JSON.parse(localStorage.getItem('angularThemeConfig')) || AppDefaults.uiTheme;

  $mdThemingProvider.theme('default')
    .primaryPalette(uiTheme.primary)
    .accentPalette(uiTheme.accent)
    .warnPalette(uiTheme.warn)
    .backgroundPalette(uiTheme.background);
  if(uiTheme.dark) {$mdThemingProvider.theme('default').dark();}

  angular.extend(toastrConfig, {
    autoDismiss: false,
    containerId: 'toast-container',
    maxOpened: 10,
    newestOnTop: true,
    positionClass: 'toast-top-right',
    preventOpenDuplicates: true,
    allowHtml: true,
  });


}])

.run(['$animate', '$http', 'logger', '$rootScope', '$templateCache', '$window', '$translate', 'AppLayout', 'Aux', 'bngApi', 'Settings', 'SettingsAuxData',
function ($animate, $http, logger, $rootScope, $templateCache, $window, $translate,  AppLayout, Aux, bngApi, Settings, SettingsAuxData) {

  $http.get('modules/vehicleconfig/vehicle-config-tree.html').then(function (tmpl) {
    $templateCache.put('vehicle-config-tree', tmpl.data);
  });

  $http.get('assets/sprites/svg-symbols.svg')
  .success(svgSprite => {
    var iconsSprite = angular.element(svgSprite);
    angular.element(document.head).append(iconsSprite);
  });


   $http.get('modules/options/settingsPresets.json')
  .success(presets => {
    SettingsAuxData.graphicPresets = presets;
  });

  //$animate.enabled(false);

  bngApi.engineLua('ui_apps.getLayouts()', function (data) {
    logger.AppLayout.log('got layouts: %o', data);
    for (var key in data)
      AppLayout[key] = data[key];
  });

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
   * });
   *
   * Angular's event system manages the listener's removal on the $destroy event of
   * the current scope.
  **/
  bngApi.registerGlobalCallback('hooks', function () {
    // variadic: accept any number of arguments
    logger.HookManager.log.apply(undefined, arguments);
    $rootScope.$broadcast.apply($rootScope, arguments);
    // console.log(arguments, Array.prototype.slice.call(arguments));
  });

  // listen to the window resize event. Maybe this can also be handled from the CEF side.
  angular.element($window).bind('resize', function () {
    var size = {width: window.innerWidth, height: window.innerHeight};
    $rootScope.$broadcast('windowResize', size);
  });

  // This should not be a function attached to the window object, but rather a HookManager event.
  // Until this is done, we just mock up the process.
  // $window.updateProgress = function(val, txt) {
  //   $rootScope.$broadcast('UpdateProgress', {value: Math.floor(100 * val), text: txt });
  // };


  $window.sendCompleteObjectState = function (value, txt) {
    //logger.log('completeObjectState', value, 'and', txt);
  };

  $window.updatePhysicsState = function (value) {
    // logger.log('[$window] got updatePhysicsState w/', value);
    $rootScope.$broadcast('updatePhysicsState', value);
  };

  // Update game state each time a route change is triggered.
  // Maybe an overkill, but why not be sure?
  // $rootScope.$on('$stateChangeSuccess', function (event, data) {
  //   logger.log('state change:', data);
  //   bngApi.engineLua('requestGameState()');
  // });


  // // settings storage for simple consumers in JS
  // $rootScope.Settings = null;
  // $rootScope.$on('SettingsChanged', function (event, data) {
  //   $rootScope.Settings = data;
  // });

  $rootScope.$on('SettingsChanged', function (event, data) {
    Settings.options = data.options;
    Settings.values = data.values;
  });

  bngApi.engineLua('settings.requestState()');
  bngApi.engineLua('core_gamestate.requestMainMenuState()');
  bngApi.engineLua('core_gamestate.requestGameState()');
  // bngApi.engineLua('print("requesting gamestate here and now")')

  // settings storage end

}])

//------------Trying filter for date translation --------- put on separate file!!!

.filter('formattedDate', function(dateFilter, $translate) {

  var format = null, translated = false;

  function returnFilter(inputDate) {
    if(format){
      return dateFilter(inputDate, format);
    }else{
      return '-';
    }
  }

  function formattedDateFilter(inputDate){
    if( format === null ) {
      if( !translated ){
        translated = true;
        $translate('general.time_format').then(function (result) {
          format = result;
        },function (translationId) {
          format = translationId;
        });
      }

    }
    else return returnFilter(inputDate);
  }

  formattedDateFilter.$stateful = true;
  return formattedDateFilter;
});


angular.module('beamng.stuff')

/**
 * @ngdoc constant
 * @name beamng.stuff.constant:AppDefaults
 * @description Constant data that might be used throughout the whole game.
**/
.constant('AppDefaults', {
  uiTheme: {
    primary: 'blue-grey',
    accent:  'beamng-orange', //'deep-orange',
    warn:    'red',
    background: 'grey',
    dark: false
  },

  playModes: [
    { translateid: 'ui.playmodes.campaigns',    icon: 'material_star',           disabled: false,            targetState: 'campaigns',                      },
    { translateid: 'ui.playmodes.scenarios',    icon: 'material_movie_creation', disabled: false,            targetState: 'scenarios',                      },
    { translateid: 'ui.playmodes.freeroam',     icon: 'material_terrain',        disabled: false,            targetState: 'levels',                         },
    // ------------------------------------ BEAMMP ------------------------------------ //
	{ translateid: 'ui.playmodes.multiplayer',  icon: 'material_people',         disabled: false,            targetState: 'multiplayer',                    },
	// ------------------------------------ BEAMMP ------------------------------------ //
	{ translateid: 'ui.playmodes.quickrace',    icon: 'material_alarm_on',       disabled: false,            targetState: 'quickraceOverview',              },
    { translateid: 'ui.playmodes.bus',          icon: 'material_directions_bus', disabled: false,            targetState: 'busRoutes',                      },
    { translateid: 'ui.playmodes.lightRunner',  icon: 'general_light_runner',    disabled: false,            targetState: 'lightrunnerOverview'             },
    { translateid: 'ui.playmodes.trackBuilder', icon: 'material_all_inclusive',  disabled: false,            targetState: '.',     levelName: "glow_city", },
    { translateid: 'ui.playmodes.career',       icon: 'material_flag',           disabled: beamng.shipping , targetState: 'career',                         },
  ],
})


/**
 * @ngdoc value
 * @name beamng.stuff.value:Aux
 * @description Auxiliary values to keep track of the game state.
**/
.value('Aux', {
  playmode: 'freeroam',
  cameraMode: '',
  uiVisible: true,
  engineChangeData: null
})

.service('gamepadNav', ['logger', '$rootScope', '$state', 'SpatialNavigation',
  function (logger, $rootScope, $state, SpatialNavigation) {
    'use strict';

    // TODO: hook this up to lua settings
    // TODO: think about using a list of actions, so when one module unregisters it's action the old action gets used.
    // this would have the benefit for example of dropdowns beeing opened, and while open their actions would be used
    // todo: actually test the list approach
    var useCrossfire = true
      , scope = {}
      , useGamepadNavigation = false
      , useSpatialNav = false
      , noop = () => {}
      , nonAssignable = ['dashboard']
      , actions =
        { up: [{module: 'root', func: noop}]
        , down: [{module: 'root', func: noop}]
        , right: [{module: 'root', func: noop}]
        , left: [{module: 'root', func: noop}]
        , confirm: [{module: 'root', func: noop}]
        , back: [{module: 'root', func: noop}]
        , dashboard: [{module: 'root', func: () => $state.go('menu')}]
        }
      , prefix =
        { up: 'menu_item_up'
        , down: 'menu_item_down'
        , right: 'menu_item_right'
        , left: 'menu_item_left'
        , confirm: 'menu_item_select'
        , back: 'menu_item_back'
        , 'radial-x': 'menu_item_radial_x'
        , 'radial-y': 'menu_item_radial_y'
        , 'trigger-right': 'menu_tab_right'
        , 'trigger-left': 'menu_tab_left'
        }
    ;

    function assignNavFunc (module, data) {
      for (var name in data) {
        if (actions[name] !== undefined) {
          if (nonAssignable.indexOf(name) === -1) {
            actions[name].push({module: module, func: data[name]});
            logger.gamepadNav.debug('Registered new function to "' + name+ '"');
          } else {
            logger.gamepadNav.error('"' + name + '" is an unchangable action');
          }
        } else {
          logger.gamepadNav.error('"' + name + '" is not a valid action');
        }
      }
    }

    function unregisterActions (module, data) {
      for (var name in data) {
        if (actions[name] !== undefined) {
          var helper = actions[name].map((elem) => elem.module);
          if (helper.indexOf(module) !== -1) {
            if (nonAssignable.indexOf(name) === -1) {
              actions[name].splice(helper.indexOf(module), 1);
              logger.gamepadNav.debug('Succesfully unregistered "' + name+ '"');
            } else {
              logger.gamepadNav.error('"' + name + '" is an unchangable action');
            }
          } else {
            logger.gamepadNav.error('Could not unregister "' + name + '" because there was no registered action from this modul');
          }
        } else {
          logger.gamepadNav.warn('Could not unregister "' + name + '" because it is not a valid action');
        }
      }
    }

    SpatialNavigation.currentViewActions.toggleMenues = {cmd: () => $rootScope.$broadcast('MenuToggle'), name: 'Toggle Menues', navigation: true};

    $rootScope.$on('MenuItemNavigation', function (event, action, val) {

      logger.gamepadNav.log('Got action: ' + action);
      logger.gamepadNav.log('Enabled Librarys', useCrossfire, useGamepadNavigation, useSpatialNav);

      if (useSpatialNav) {
        SpatialNavigation.triggerAction(action, val);
      } else {
        if (action == 'toggleMenues') {
          $rootScope.$broadcast('MenuToggle');
          return;
        }
      }

      if (useCrossfire) {
        if(action == 'confirm') {
          if (document.activeElement.classList.contains("menu-navigation")) {
            document.activeElement.click(); // only click with confirm+crossfire if ornage focus border is shown
          }
        } else if (["left", "right", "up", "down"].indexOf(action) != -1) {
          var targets = collectRects();
          navigate(targets, action);
          // todo: why is this both done on the same event? (talk to bg) -yh
        }

      }

      if (useGamepadNavigation) {
        console.log(actions[action]);
        // console.log(actions[action][0]);
        $rootScope.$evalAsync(actions[action][0].func);
      }
    });

    return {
      crossfireEnabled: () => useCrossfire,
      gamepadNavEnabled: () => useGamepadNavigation,
      spatialNavEnabled: () => useSpatialNav,
      // TODO: make this intuitive (omiting the value shouldn't do something unexpected)
      enableCrossfire: (val) => useCrossfire = val,
      enableGamepadNav: (val) => useGamepadNavigation = val,
      enableSpatialNav: (val) => useSpatialNav = val,
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
.controller('AppCtrl', ['$document', '$log', 'logger', '$rootScope', '$scope', '$sce', '$compile', '$state', '$translate', '$window', 'AppDefaults', 'Aux', 'bngApi', 'ControlsUtils', 'Utils', 'Settings', 'toastr', '$timeout', 'gamepadNav', 'SimpleStateNav', 'SpatialNavigation', '$injector', '$location',
  function($document, $log, logger, $rootScope, $scope, $sce, $compile, $state, $translate, $window, AppDefaults, Aux, bngApi, ControlsUtils, Utils, Settings, toastr, $timeout, gamepadNav, SimpleStateNav, SpatialNavigation, $injector, $location) {
  var vm = this;

  // hack to fix backspace navigating between different menus.
  // https://stackoverflow.com/questions/29006000/prevent-backspace-from-navigating-back-in-angularjs
  $document.on('keydown', function(e){
    if(e.which === 8 && ( e.target.nodeName !== "INPUT" && e.target.nodeName !== "SELECT" ) ){ // you can add others here inside brackets.
      e.preventDefault();
    }
  });

  setTimeout(() => {
    gamepadNav.provideScope($scope);
  });

  bngApi.engineLua('extensions.hook("onUIInitialised")');

$scope.$on('requestUIInitialised', () => {
    bngApi.engineLua('core_gamestate.onUIInitialised()');
  })

  vm.shipping = beamng.shipping;

  vm.replayPaused = false;
  vm.replayActive = false;
  vm.physicsPaused = false;
  vm.physicsMaybePaused = false;
  vm.showPauseIcon = false;
  var updatePauseIcon = function() {
      vm.physicsPaused= !vm.replayActive && vm.physicsMaybePaused;
      var gamePaused = vm.physicsPaused || vm.replayPaused;
      var inPhotoMode  = $state.current.name === 'photomode';
      vm.showPauseIcon = !inPhotoMode && gamePaused;
  };

  // quite a hack, but the alternative would have been to manage a list and wait for each state to be actiavated
  // the problem only occured because changeState was called almost simultaniously and before on state could be transitioned to the other ocnditinal was already executed next.
  // TODO change this to use the $state.transition promise
  var transitioningTo;

  $scope.$on('$stateChangeSuccess', function (event, toState, toParams, fromState, fromParams) {
    logger.AppCtrl.debug(`From ${fromState.name} to ${toState.name}`);
    var showQuickAccess = vm.showMenu && toState.name == "menu";
    bngApi.engineLua("if core_quickAccess then core_quickAccess.setEnabled("+showQuickAccess+") end"); // no reason for this to be here >>> actually needed to hide radial menu when opening any menu such as Parts Manager, etc
    bngApi.engineLua(`extensions.hook("onUiChangedState", "${toState.name}", "${fromState.name}")`);
    transitioningTo = undefined;
    updatePauseIcon();
  });

  $scope.$on('$stateChangeCancel', function ( event, toState, toParams, fromState, fromParams) {
    logger.AppCtrl.debug('$stateChangeCancel', JSON.stringify({toState: toState, toParams: toParams, fromState: fromState, fromParams: fromParams}, null, '  '));
  });

  $scope.$on('$stateChangeError', function ( event, toState, toParams, fromState, fromParams, error) {
    logger.AppCtrl.debug('$stateChangeError', JSON.stringify({toState: toState, toParams: toParams, fromState: fromState, fromParams: fromParams}, null, '  '));
    logger.AppCtrl.error(error)
  });

  $scope.$on('$stateNotFound', function (event, unfoundState, fromState, fromParams) {
    logger.AppCtrl.debug('$stateNotFound', JSON.stringify({unfoundState : unfoundState, fromState: fromState, fromParams: fromParams}, null, '  '));
  });

  $scope.$on('$stateChangeStart', function (event, toState, toParams, fromState, fromParams) {
    logger.AppCtrl.debug('stateChangeStart', JSON.stringify({toState: toState, toParams: toParams, fromState: fromState, fromParams: fromParams}, null, '  '));
    transitioningTo = toState.name;
    vm.transitionAnimation = toState.transitionAnimation || fromState.transitionAnimation; // prefer the animation of the target state, otherwise use the state we came from

    // if (fromState.name === 'loading') {
    //   bngApi.engineLua('requestGameState()');
    // }
    if (toState.name === 'loading') {
      $scope.$broadcast('StickyState', null);
    }
  });

  $scope.$on('ChangeState', function (event, data, ifCurrent) {
    logger.AppCtrl.debug('received ForceStateChange w/', data, ifCurrent, $state.current.name, transitioningTo);
    params = data.params || {};
    state = (typeof data === 'string' ? data : data.state);
    help = (transitioningTo !== undefined && transitioningTo !== $state.current.name ? transitioningTo : $state.current.name);
    if (help === ifCurrent || ifCurrent === undefined || (Array.isArray(ifCurrent) && ifCurrent.indexOf(help) !== -1)) {
      logger.AppCtrl.log(`switching to state: ${state}`);
      stateTransitioning = $state.go(state, params, {reload: true});
    }
  });


  vm.showApps = true;
  vm.mainmenu = true;
  vm.showMenu = true;
  vm.gameState;
  vm.settings = Settings;

  vm.getMenuEntries = function (state) {
    if (vm.menuEntries[state] === undefined) {
      return vm.menuEntries.scenario;
    }
    return vm.menuEntries[state];
  }

  vm.menuEntries = {
    freeroam: [
      { translateid: 'ui.dashboard.play',          icon: 'play_arrow', state: '.', action: () => $timeout(() => $scope.$emit('MenuToggle'))},
      { translateid: 'ui.dashboard.drive',         icon: 'layers',                 state: 'menu.playmodes'     },
      { translateid: 'ui.dashboard.help',          icon: 'help',                   state: 'menu.help'          },
      { translateid: 'ui.dashboard.mods',          icon: 'shop',                   state: 'menu.mods.local',   },
      { translateid: 'ui.dashboard.vehicles',      icon: 'directions_car',         state: 'menu.vehicles'      },
      { translateid: 'ui.dashboard.vehicleconfig', icon: 'settings_applications',  state: 'menu.vehicleconfig.parts' },
      { translateid: 'ui.dashboard.environment',   icon: 'cloud_queue',            state: 'menu.environment'   },
      { translateid: 'ui.dashboard.trackBuilder',  icon: 'all_inclusive',          state: '.', action: () => bngApi.engineLua("extensions.trackbuilder_trackBuilder.toggleTrackBuilder()") },
      { translateid: 'ui.dashboard.replay',        icon: 'local_movies',           state: 'menu.replay'        },
      { translateid: 'ui.dashboard.photomode',     icon: 'photo_camera',           state: 'photomode'          },
      { translateid: 'ui.dashboard.appedit',       icon: 'web',                    state: 'appedit'            },
      { translateid: 'ui.dashboard.options',       icon: 'tune',                   state: 'menu.options.graphics'},
      { translateid: 'ui.dashboard.debug',         icon: 'bug_report',             state: 'menu.debug',      advanced: true },
      { translateid: 'ui.dashboard.performance',   icon: 'equalizer',              state: '.', action: () => bngApi.engineLua("togglePerformanceGraph()"), advanced: true },
      { translateid: 'ui.dashboard.mainmenu',      icon: 'exit_to_app', state: '.', action: () => $timeout(() => vm.quit()), bottom: true},
    ],

	// -------------------------------------------------------------------- BEAMMP --------------------------------------------------------------------//
	multiplayer: [
      { translateid: 'ui.dashboard.play',          icon: 'play_arrow', state: '.', action: () => $timeout(() => $scope.$emit('MenuToggle'))},
      { translateid: 'ui.dashboard.help',          icon: 'help',                   state: 'menu.help'          },
      { translateid: 'ui.dashboard.vehicles',      icon: 'directions_car',         state: 'menu.vehicles'      },
      { translateid: 'ui.dashboard.vehicleconfig', icon: 'settings_applications',  state: 'menu.vehicleconfig.parts' },
      { translateid: 'ui.dashboard.replay',        icon: 'local_movies',           state: 'menu.replay'        },
      { translateid: 'ui.dashboard.photomode',     icon: 'photo_camera',           state: 'photomode'          },
      { translateid: 'ui.dashboard.appedit',       icon: 'web',                    state: 'appedit'            },
      { translateid: 'ui.dashboard.options',       icon: 'tune',                   state: 'menu.options.graphics'},
      { translateid: 'ui.dashboard.debug',         icon: 'bug_report',             state: 'menu.debug',      advanced: true },
      { translateid: 'ui.dashboard.performance',   icon: 'equalizer',              state: '.', action: () => bngApi.engineLua("togglePerformanceGraph()"), advanced: true },
      { translateid: 'ui.dashboard.mainmenu',      icon: 'exit_to_app', state: '.', action: () => $timeout(() => vm.quit()), bottom: true},
	],
	// -------------------------------------------------------------------- BEAMMP --------------------------------------------------------------------//


    scenario: [
      { translateid: 'ui.dashboard.play',          icon: 'play_arrow', state: '.', action: () => $timeout(() => $scope.$emit('MenuToggle'))},
      { translateid: 'ui.dashboard.drive',         icon: 'layers',                 state: 'menu.playmodes'     },
      { translateid: 'ui.dashboard.help',          icon: 'help',                   state: 'menu.help'},
      { translateid: 'ui.dashboard.photomode',     icon: 'photo_camera',           state: 'photomode'          },
      { translateid: 'ui.dashboard.appedit',       icon: 'web',                    state: 'appedit'},
      { translateid: 'ui.dashboard.options',       icon: 'tune',                   state: 'menu.options.graphics',        },
      { translateid: 'ui.dashboard.debug',         icon: 'bug_report',             state: 'menu.debug',      advanced: true },
      { translateid: 'ui.dashboard.performance',   icon: 'equalizer',              state: '.', action: () => bngApi.engineLua("togglePerformanceGraph()"), advanced: true },
      { translateid: 'ui.dashboard.mainmenu',      icon: 'exit_to_app', state: '.', action: () => $timeout(() => vm.quit()), bottom: true},
    ],

    career: [
      { translateid: 'ui.dashboard.play',          icon: 'play_arrow', state: '.', action: () => $timeout(() => $scope.$emit('MenuToggle'))},
      { translateid: 'ui.dashboard.drive',         icon: 'layers',                 state: 'menu.playmodes'     },
      { translateid: 'ui.dashboard.help',          icon: 'help',                   state: 'menu.help'          },
      { translateid: 'ui.dashboard.replay',        icon: 'local_movies',           state: 'menu.replay'        },
      { translateid: 'ui.dashboard.photomode',     icon: 'photo_camera',           state: 'photomode'          },
      { translateid: 'ui.dashboard.options',       icon: 'tune',                   state: 'menu.options.graphics'},
      { translateid: 'ui.dashboard.performance',   icon: 'equalizer',              state: '.', action: () => bngApi.engineLua("togglePerformanceGraph()"), advanced: true },
      { translateid: 'ui.dashboard.mainmenu',      icon: 'exit_to_app', state: '.', action: () => $timeout(() => vm.quit()), bottom: true},
    ]
  };

  if(!beamng.shipping) {
    vm.menuEntries.freeroam.push({ translateid: 'Icons', icon: 'new_releases', state: 'iconViewer', advanced: true });
    // vm.menuEntries.freeroam.push({ translateid: 'Drag Race', icon: 'flag', state: 'menu.dragRaceOverview', advanced: false });
    // vm.menuEntries.freeroam.push({ translateid: 'ui.dashboard.template', icon: 'crop_free',    state: 'template', advanced: true});
    vm.menuEntries.freeroam.push({ translateid: 'UI Protoype', icon: 'new_releases',    state: '.', action: () => window.location.href = "local://local/ui2/drive/index.html"});
  }

  // downloader start
  var dlinfo = {};
  function cancelHelper (id, ctr) {
    if (dlinfo[id] && dlinfo[id][0] == 1) {
      // hacky fix to remove downloading toastr when it gets stuck.
      // This seems to be an issue with ngAnimate, more info here:
      // https://github.com/Foxandxss/angular-toastr/issues/136
      dlinfo[id][1].el[0].style.display = "none";
      toastr.clear(dlinfo[id][1]);
      delete dlinfo[id];
    } else {
      if (ctr < 4) {
        // setTimeout(cancelHelper.bind(undefined, id, ctr + 1),200);
      }
    }
  }
  $window.downloadStateChanged = function(data) {
    if(data.filename == '') return;

    logger.log('downloadStateChanged', data);
    if(data.state == 'working' && !dlinfo[data.id]) {
      // the 0% is imporatne here, so the toaster library doesn't think the success msg later one to be a duplicate, so please leave it there
      var t = toastr.info(data.filename + ': 0%', 'Downloading mod', {
        positionClass: 'toast-top-right',
        timeOut: 0,
        extendedTimeOut: 0,
        // progressBar: true,
        closeButton: true,
        onTap: function () {
          $state.go('menu.mods.downloaded');
        }
      });
      dlinfo[data.id] = [1, t];
      console.warn(dlinfo[data.id]);
    } else if(data.state == 'working' && dlinfo[data.id][0] == 1) {
      $scope.$evalAsync(function () {
        if(dlinfo[data.id]) {
          dlinfo[data.id][1].scope.message = $sce.trustAsHtml(data.filename + ": " + Math.floor(data.dlnow / data.dltotal * 100) + "%");
        }
      });

    } else if(data.state == 'finished') {
      cancelHelper(data.id);

      var t = toastr.success(data.filename, 'Downloaded mod', {
        positionClass: 'toast-top-right',
        timeOut: 20000,
        closeButton: true,
        onTap: function () {
          var help = data.filename;
          if (help.slice(-4) === '.zip') {
            help = help.slice(0, -4);
          }
          $state.go('menu.mods.downloaded', {
            // modFilePath: encodeURIComponent(help)
          });
        }
      });
    }
  };
  // downloader end
  // let Lua know the UI is up and running
  var uiReady = uiReady;
  angular.element(document).ready(function() {
    bngApi.engineLua("uiReady()");
    uiReady = true;
  });
  $scope.$on('isUIReady', function (event) {
    if(uiReady) bngApi.engineLua("uiReady()");
  });

  $scope.$on('modmanagerError', function (event, data) {
    $scope.$emit('app:waiting', false);
    toastr.error(data, 'Error in Modmanager', {
      positionClass: 'toast-top-right',
      preventDuplicates: true,
      progressBar: true,
      timeOut: 10000,
      extendedTimeOut: 1000,
      closeButton: true
    });
  });

  var toasts = {};

  $scope.$on('toastrMsg', function (ev, data) {
    toasts[data.title] = toastr[data.type]($translate.instant(data.msg, data.context), $translate.instant(data.title, data.context), data.config);
  });

  $scope.$on('toastrClose', function (ev, name) {
    toastr.clear(toasts[name]);
    // delete toasts[name];
  });

  vm.sections = { // defines in which state after which icons should be a divider
    freeroam: ['.', 'menu.help', 'menu.vehicleconfig.parts', 'menu.environment', 'performance', 'photomode', 'menu.options.graphics'],
    scenario: ['.', 'menu.help', 'performance', 'photomode'],
    career:   ['.', 'menu.drive'],
  };

  vm.stickyState = null;

  $scope.$on('ShowEntertainingBackground', (ev, mainmenu) => {
    $scope.$evalAsync(() => {
      vm.mainmenu = mainmenu;
    });
  });

  vm.openRepo = function() {
    var onlineState = Settings.values.onlineFeatures;
    if (onlineState === 'enable') {
      $state.go('menu.mods.repository');
    }
    else {
      window.location.href = 'http-external://www.beamng.com/resources/';
    }
  };

  // The "GameStateUpdate" is triggered by calling "getGameState()" in the Lua engine.
  // $rootScope takes care of this each time there is a state change.
  $scope.$on('GameStateUpdate', function (event, data) {
    // logger.log(data);
    logger.AppCtrl.log(`got game state: ${data.state}`, data);

    $scope.$evalAsync(() => {
        vm.gameState = data.menuItems;
    });
  });

  $scope.$on('ShowApps', function (event, data) {
    logger.AppCtrl.log('got', (data ? 'show' : 'hide'), 'apps');
    vm.showApps = data;
  });

  $scope.$on("MenuFocusShow", function (event, enabled) {
    if (!enabled) uncollectRects($scope);
  });

  // Method used to show mods on repository when 'view ingame' on https://www.beamng.com/resources/ is clicked.
  $scope.$on('ShowMod', function (event, data) {
    var startTimeout;
    vm.showMenu = true;

    if (data) {
      (function checkStart() {
        // check if startScreen is still active every 100ms
        if($state.current.name === 'startScreen') {
          startTimeout = setTimeout(checkStart, 100);
        } else {
          // if no startScreen then we can continue to show mod
          window.location.href = `local://local/ui/entrypoints/main/index.html#/menu/mods/detail/${data}`;
          clearTimeout(startTimeout);
        }
      })();
    }
  });

  $scope.$on('StickyState', function (event, data) {
    $scope.$applyAsync(function () {
      logger.AppCtrl.log('setting stickyState to', data);
      vm.stickyState = data;
    });
  });

  $scope.$on('MenuToggle', function (event, data) {
    logger.AppCtrl.log(`received MenuToggle in gamestate: ${vm.gameState}`);
    logger.AppCtrl.log(`currently in state: ${$state.current.name}`);
    var newTarget = vm.mainmenu ? 'menu.mainmenu' : 'menu';
    if (vm.stickyState) {
      $scope.$evalAsync(function () {
        vm.showMenu = (typeof(data) == 'boolean') ? data : !vm.showMenu;

        if (!vm.showMenu) {
          $state.go(vm.stickyState);
        } else {
          $state.go(newTarget);
        }
      });

    } else {
      $scope.$evalAsync(function () {
        vm.showMenu = (typeof(data) == 'boolean') ? data : !vm.showMenu;
        if (!vm.showMenu) {
          logger.AppCtrl.log('hiding menu');
          $state.go(newTarget);
        }
      });
    }
    bngApi.engineLua(`extensions.hook("onMenuToggled", ${!vm.showMenu})`);
  });

  $scope.$on('onCameraNameChanged', function (event, data) {
    Aux.cameraMode = data.name;
  });

  $scope.$on('MenuHide', function (event, data) {
    logger.AppCtrl.log('received MenuHide w/', data);
    if (data !== undefined && data !== null && !data) {
      $scope.$evalAsync(function () {
        vm.showMenu = true; // probably this is redundant, but better be sure.
      });
      return;
    }

    $scope.$evalAsync(function () {
      vm.showMenu = false;
    });
  });


  vm.aux = Aux;

  $scope.$on('hide_ui', function (event, data) {
    $scope.$evalAsync(function () {
        Aux.uiVisible = data !== undefined ? !data: !Aux.uiVisible;
        // logger.log("Aux.uiVisible = ", Aux.uiVisible);
    });
  });

  // This is only needed for closing current state when user clicks
  // on the same icon. Not sure why this is good...
  vm.toggleState = function (event, state) {
    if ($state.current.name == state) {
      event.preventDefault();
      var newTarget = vm.mainmenu ? 'menu.mainmenu' : 'menu';
      $state.go(newTarget);
    }
  };

  vm.quit = function () {
    if (vm.mainmenu) {
      bngApi.engineScript('quit();'); //It should work but doesn't, `Platform::postQuitMessage` is executed but nothing happens, maybe CEF catch that message
      bngApi.engineLua("TorqueScript.eval('quit();')");
    } else {
      bngApi.engineLua("returnToMainMenu()");
    }
  };

  $scope.$on('CloseMenu', () => {
    var newTarget = vm.mainmenu ? 'menu.mainmenu' : 'menu';
    $state.go(newTarget);
  })

  $scope.$on('quit', vm.quit);

  // **************************************************************************
  // language switching tests
  var langid = 0;
  var lang_available = ['en-US', 'de-DE', 'ru', 'ar'];
  function toggle_lang_example() {
    langid++;
    if(langid >= lang_available.length) langid = 0;
    // logger.log('switched language to: ', lang_available[langid]);
    $scope.$evalAsync(function() {
      $scope.$broadcast('languageChange');
      $translate.use(lang_available[langid]);
    });
    // console.log(`using lang: ${lang_available[langid]}`);
    $timeout(toggle_lang_example, 3000);
  }
  // toggle_lang_example();

  $scope.$on('translationFileUpdate',  $translate.refresh);
  bngApi.engineLua('core_modmanager.requestTranslations()');

  // **************************************************************************
  var previousLanguage = undefined;
  $scope.$on('SettingsChanged', (ev, data) => {
    if(data.values.uiLanguage && data.values.uiLanguage != '') {
      $rootScope.$eval(function() {
        //console.log("USING NEW LANGUAGE: " + data.values.uiLanguage);
        $translate.use(data.values.uiLanguage);
        previousLanguage = data.values.uiLanguage;
      });
    }
  });
  // **************************************************************************

  $scope.$watch('app.showMenu', function (newv, oldv) {
    bngApi.engineLua("extensions.core_input_bindings.menuActive("+newv+")");
    var showQuickAccess = vm.showMenu && $state.current.name == "menu";
    bngApi.engineLua("if core_quickAccess then core_quickAccess.setEnabled("+showQuickAccess+") end");
  });

  // The "MenuOpenModule" event is used to quickly open a state from keyboard.
  // The various arguments are defined in the lua/t3d/input_actions.json file
  // and map actions to HookManager calls (and stuff for other modules).
  //
  // NOTE: Remember that transitioning to a state is not enough - menu must be open too!!
  $scope.$on('MenuOpenModule', function (event, data) {
    logger.AppCtrl.log('received MenuOpenModule w/', data);
    switch (data) {
    case 'help':
      $state.go('menu.help').then(function () {vm.showMenu = true; });
      break;
    case 'vehicleselect':
      $state.go('menu.vehicles').then(function () {vm.showMenu = true; });
      break;
    case 'vehicleconfig':
      $state.go('menu.vehicleconfig.parts').then(function () {vm.showMenu = true; });
      break;
    case 'photomode':
      $state.go('photomode').then(function () {vm.showMenu = true; });
      break;
    case 'options':
      $state.go('menu.options.graphics').then(function () { vm.showMenu = true; });
      break;
    case 'appedit':
      $state.go('appedit').then(function () { vm.showMenu = true; });
      break;
    default:
      logger.warn('don\'t know which module to open with %s', data);
      return;
    }
  });


  $scope.$on('InputBindingsChanged', function (event, data) {
    $scope.pauseControlText = "";
    $scope.pauseControlIcon = "";
    for (var i = 0; i < data.bindings.length; i++) {
      for (var j = 0; j < data.bindings[i].contents.bindings.length; j++) {
        var binding = data.bindings[i].contents.bindings[j];
        if (binding.action != "pause") continue;
        $scope.pauseControlText = binding.control;
        $scope.pauseControlIcon =  ControlsUtils.deviceIcon(data.bindings[i].contents.devicetype);
        break;
      }
    }
  });

  $scope.$on('updatePhysicsState', function (event, state) {
    $scope.$evalAsync(function () {
      vm.physicsMaybePaused = !state;
      updatePauseIcon();
    });
  });

  $scope.$on('replayStateChanged', function (event, core_replay) {
    $scope.$evalAsync(function () {
      vm.replayActive = core_replay.state === 'playing';
      vm.replayPaused = vm.replayActive && core_replay.paused;
      updatePauseIcon();
    });
  });


  vm.unpause = function () {
    bngApi.engineLua('bullettime.pause(false)');
  };

  $scope.$on('requestPhysicsState', function (event) {
    $scope.$broadcast('updatePhysicsState', !vm.physicsPaused);
  });



  vm.isWaiting = false;

  $scope.$on('app:waiting', function (event, value, callback) {
    vm.isWaiting = value;
    Utils.waitForCefAndAngular(() => {
      if (callback !== undefined && typeof callback === 'function') {
        callback(vm.isWaiting);
      }
    });
  });


  //messages app port:
  (function () {
    /* Devlog mini code start */
    // Devlog function only enabled in non-shipping builds

    function pluralHelper (counts, string) {
      var count = 0;
      for (var i in counts) {
        count += counts[i];
      }

      var frakton = 1000;
      if (count > frakton && count < 2 * frakton) {
        return 'Frakton of ' + string + 's';
      } else if (count > 2 * frakton){
        return Math.round(count / frakton) + ' Frakton of ' + string + 's';
      } else if (count > 1) {
        return count + ' ' + string + 's';
      } else {
        return string;
      }
    }

    function descHelper (counts, msg) {
      var types = {
        'Lua': 0,
        'TS': 0,
        'UI': 0,
        'Cef': 0
      };
      var str = '';
      var type;
      var unknown = 0;

      if (msg !== undefined) {
        var total = 0;
        for (type in types) {
          if (msg.origin.toLowerCase().indexOf(type.toLowerCase()) !== -1) {
            if (counts[type] === undefined) { counts[type] = 0; }
            counts[type] += 1;
            total += 1;
          }
        }

        if (total < 1) {
          if (counts['unknown'] === undefined) { counts['unknown'] = 0; }
          counts['Unknown'] += 1;
          // logger.log(list[i].origin);
        }
      }

      for (type in counts) {
        if (counts[type] !== undefined && counts[type] > 0) {
          str += type + ': ' + counts[type] + ', ';
        }
      }
      str = str.slice(0, -2);
      return str;
    }

    function openErrorLog(level) {
      // TODO: FIXME
      logger.log("the error log should open here for level: ", level);
      // $scope.logBuffer = logBuffer;
      // var newWin = open('local://local/ui/index.html','windowName','height=300,width=600');
    }

    if (!vm.shipping) {
      var errorCount = {};
      var warningCount = {};
      // clear messages on level change
      $scope.$on('PreStartMission', function () { errorCount = {}; warningCount = {};});

      var args = {
        positionClass: 'toast-top-right',
        timeOut: 0,
        extendedTimeOut: 0,
        closeButton: true,
        tapToDismiss: false,
      };

      var warningToast = null;
      var errorToast = null;
      var missingImgs = [];
      $scope.$on('DevLog', function (event, data) {
        // logger.log(data);

        // fix up missing imgs beeing counted separate, but only show one error
        if(data.origin === 'ui.imgErrorDir') {
          if (missingImgs.indexOf(data.msg) === -1) {
            missingImgs.push(data.msg);
          } else {
            data.level = 'ignore';
          }
        }

        if(data.level == 'E') {
          if(errorToast === null) {
            args.onTap = function () { openErrorLog(data.level); };
            errorToast = toastr.error(descHelper(errorCount, data), pluralHelper(errorCount, 'Error'), args);
          }
          if(errorToast && errorToast.scope) {
              // it happens that we reset the logBuffer while this tries to run, resulting in an error
            errorToast.scope.title = $sce.trustAsHtml(pluralHelper(errorCount, 'Error'));
            errorToast.scope.message = $sce.trustAsHtml(descHelper(errorCount, data));
          }
        }

        if(data.level == 'W') {
          if(warningToast === null) {
            args.onTap = function () { openErrorLog(data.level); };
            warningToast = toastr.warning(descHelper(warningCount, data), pluralHelper(warningCount, 'Warning'), args);
          }
          if(warningToast && warningToast.scope) {
              // it happens that we reset the logBuffer while this tries to run, resulting in an error
            warningToast.scope.title = $sce.trustAsHtml(pluralHelper(warningCount, 'Warning'));
            warningToast.scope.message = $sce.trustAsHtml(descHelper(warningCount, data));
          }
        }

      });
    }

    /* Devlog mini code end */

    // started on toastr hook, will continue later
    // listener for toasts
    // $scope.$on('toast', function (event, data) {
    //   var type = data.type || 'info';
    //   var args = data.args || {};

    //   if (data.msg && data.title) {
    //     toastr[type](data.msg, data.title, args);
    //   } else if (data.msg || data.title) {
    //     toastr[type]((data.msg || data.title), args);
    //   } else {
    //     logger.error('Error creating Toast');
    //   }
    // });

    // // listener for
    // $scope.$on('toast', function (event, data) {

    // });

    window.debug = {$injector: $injector, state: $state, vm: vm, bngApi: bngApi, translate: $translate, scope: $scope, stateNav: SimpleStateNav};

    window.triggerSeveralEngineLua = function (cmd) {
      bngApi.engineLua(cmd);
      bngApi.engineLua(cmd);
      bngApi.engineLua(cmd);
    };

    $scope.$on('appJsonDump', (ev, data) => logger.jsonDump.log(data));
  })();

}]);

//Trying a date filter-------------------------------------------------------




