angular.module('beamng.stuff')

.value('Settings', {
  values: {},
  options: {}
})


.constant('SettingsAuxData', {
  graphicPresets: [],

  uiElements: {
    graphics: {
      checkboxGroup1: [
        { name: 'ui.options.graphics.PostFXSSAOGeneralEnabled', key: 'PostFXSSAOGeneralEnabled' },
        { name: 'ui.options.graphics.PostFXLightRaysEnabled',    key: 'PostFXLightRaysEnabled'   },
        { name: 'ui.options.graphics.PostFXBloomGeneralEnabled',  key: 'PostFXBloomGeneralEnabled'  },
        { name: 'ui.options.graphics.PostFXDOFGeneralEnabled',  key: 'PostFXDOFGeneralEnabled'  }
      ],

      checkboxGroup2: [
        { name: 'ui.options.graphics.GraphicAntialiasType',   tooltip: 'ui.options.graphics.GraphicAntialiasTypeTooltip',   key: 'GraphicAntialiasType'   },
        { name: 'ui.options.graphics.GraphicMeshQuality',     tooltip: 'ui.options.graphics.GraphicMeshQualityTooltip',     key: 'GraphicMeshQuality'     },
        { name: 'ui.options.graphics.GraphicTextureQuality',  tooltip: 'ui.options.graphics.GraphicTextureQualityTooltip',  key: 'GraphicTextureQuality'  },
        { name: 'ui.options.graphics.GraphicLightingQuality', tooltip: 'ui.options.graphics.GraphicLightingQualityTooltip', key: 'GraphicLightingQuality' },
        { name: 'ui.options.graphics.GraphicShaderQuality',   tooltip: 'ui.options.graphics.GraphicShaderQualityTooltip',   key: 'GraphicShaderQuality'   },
        { name: 'ui.options.graphics.GraphicPostfxQuality',   tooltip: 'ui.options.graphics.GraphicPostfxQualityTooltip',   key: 'GraphicPostfxQuality'   },
        { name: 'ui.options.graphics.GraphicAnisotropic',     tooltip: 'ui.options.graphics.GraphicAnisotropicTooltip',     key: 'GraphicAnisotropic'     }
      ],

      dynReflectionSliders: [
        { name: 'Texture Size', tooltip: 'GraphicDynReflectionTexsizeTooltip',        key: 'GraphicDynReflectionTexsize',        min: 0,  max: 3,    step: 1   },
        { name: 'Update Rate',  tooltip: 'GraphicDynReflectionFacesPerupdateTooltip', key: 'GraphicDynReflectionFacesPerupdate', min: 1,  max: 6,    step: 1   },
        { name: 'Detail',       tooltip: 'GraphicDynReflectionDetailTooltip',         key: 'GraphicDynReflectionDetail',         min: 0,  max: 1,    step: 0.1 },
        { name: 'Distance',     tooltip: 'GraphicDynReflectionDistanceTooltip',       key: 'GraphicDynReflectionDistance',       min: 50, max: 1000, step: 50, unitsTxt: 'm' }
      ]
    },

    audio: {
      selectGroup1: [
        { name: 'ui.options.audio.audioProvider', key: 'AudioProvider'},
      ],

      volumeSliders: [
        { name: 'ui.options.audio.masterVol',     key: 'AudioMasterVol'   },
        { name: 'ui.options.audio.effectsVol',    key: 'AudioEffectsVol'  },
        { name: 'ui.options.audio.ambienceVol',   key: 'AudioAmbienceVol' },
        { name: 'ui.options.audio.musicVol',      key: 'AudioMusicVol'    }
      ]
    }
  }
})




.value('UiUnitsOptions', {
  highLvlOpt: {
    'imperial': 'Imperial',
    'metric': 'Metric (SI)',
    'british': 'British',
    'custom': 'Custom',
  },

  settable: [ 'uiUnitLength', 'uiUnitTemperature', 'uiUnitWeight', 'uiUnitVolume', 'uiUnitConsumptionRate', 'uiUnitPower', 'uiUnitTorque', 'uiUnitEnergy',  'uiUnitPressure', 'uiUnitDate'],
  names:    [ 'ui.options.units.length', 'ui.options.units.temperature', 'ui.options.units.weight', 'ui.options.units.volume', 'ui.options.units.fuelConsumption', 'ui.options.units.power', 'ui.options.units.torque', 'ui.options.units.energy', 'ui.options.units.pressure', 'ui.options.units.dateFormat'],

  default: {
    imperial: [ 'imperial', 'f', 'lb', 'gal', 'imperial', 'bhp', 'imperial', 'imperial', 'psi', 'us'  ],
    metric:   [ 'metric', 'c', 'kg', 'l',   'metric',   'hp',  'metric',   'metric', 'bar',   'ger' ],
    british:  [ 'imperial', 'c', 'kg', 'l', 'imperial', 'bhp', 'imperial', 'imperial', 'inHg', 'uk'  ]
  },
  system: 'imperial'
})

/**
 * @ngdoc controller
 * @name beamng.stuff.controllers:OptionsController
 * @description Controller for the abstract Settings view.
 */
.controller('OptionsController', ['$scope', 'bngApi', 'SettingsAuxData', 'UiUnitsOptions', '$state', '$timeout', 'RateLimiter',
function($scope, bngApi, SettingsAuxData, UiUnitsOptions, $state, $timeout, RateLimiter) {

  var vm = this;
  vm.shipping = beamng.shipping;
  vm.stateName = $state.current.name;
  var uiUnitsOptions = UiUnitsOptions;

  bngApi.engineLua('core_gamestate.requestGameState();');   // if this isnt called the gamestate in menu doesnt update correctly...

  $scope.$on('$stateChangeSuccess', function (event, toState, toParams, fromState, fromParams) {
    vm.stateName = toState.name;
  });

  vm.uiElements = SettingsAuxData.uiElements;

  vm.data = {values: {}, options: {}};

  $scope.$on('SettingsChanged', function (event, data) {
    $scope.$evalAsync(function () {
      $scope.options.online = data.values.onlineFeatures == 'enable';
      $scope.options.telemetry = data.values.telemetry == 'enable';
      vm.data = data;
      vm.checkUiUnitsSystem();
    });
  });

  $scope.$watch('options.data.values.GraphicDynReflectionTexsize', function(value) {
    if (value == 0) { $scope.GraphicDynReflectionTexsizeText = "128"; }
    if (value == 1) { $scope.GraphicDynReflectionTexsizeText = "256"; }
    if (value == 2) { $scope.GraphicDynReflectionTexsizeText = "512"; }
    if (value == 3) { $scope.GraphicDynReflectionTexsizeText = "1024"; }
  });

  bngApi.engineLua('settings.requestState()');

  vm.applyLanguage = function () {
    // unload current page, save language, then reload current page
    // this forces re-reading of all one-time data-bindings, to reflect the new language without having to use slow two-time data-bindings
    var currentState = $state.current.name;
    $state.go('menu');
    bngApi.engineLua(`settings.setState(${bngApi.serializeToLua(vm.data.values)})`,
      function (ret) { $timeout( function(){
        $state.go(currentState);
      }, 500 ); }
    );
  };

  function applyState (stateObj) {
    var onlineFeatures = 'disable';
    var telemetryFeatures = 'disable';
    if ($scope.options.online) {
      onlineFeatures = 'enable';
      if ($scope.options.telemetry) {
        telemetryFeatures = 'enable';
      }
    } else {
      $scope.options.telemetry = false;
    }

    vm.data.values.onlineFeatures = onlineFeatures;
    vm.data.values.telemetry = telemetryFeatures;


    bngApi.engineLua(`settings.setState(${bngApi.serializeToLua(stateObj || vm.data.values)})`);
  }

  function mpSetting(opt, val) {
    vm.multiplayer.values.showNameTags;
    console.log(`MP SETTING. OPT: ${opt}, VAL: ${val}, SET: ${vm.data.values.showNameTags}`)
    bngApi.engineLua(`mpConfig.setConfigState(${opt}, ${vm.data.values.showNameTags})`);
  }

  function refreshGraphicsState () {
    bngApi.engineLua(`core_settings_graphic.refreshGraphicsState(${bngApi.serializeToLua(vm.data.values)})`);
  }

  function applyGraphicsState () {
    bngApi.engineLua(`core_settings_graphic.applyGraphicsState()`);
  }

  /**
   * @ngdoc method
   * @name mpSetting
   * @methodOf beamng.stuff.controllers:OptionsController
   * @param {object} [stateObj] The settings to be changed. If not provided, all the current settings will be applied.
   * @description Applies the current settings to the game
   */
  vm.mpSetting = RateLimiter.debounce(mpSetting, 100);

  /**
   * @ngdoc method
   * @name clearLauncherCache
   * @methodOf beamng.stuff.controllers:SettingsAudioCtrl
   * @description Toggles Master volume.
   */
  vm.clearLauncherCache = function () {

  }

  /**
   * @ngdoc method
   * @name applyState
   * @methodOf beamng.stuff.controllers:OptionsController
   * @param {object} [stateObj] The settings to be changed. If not provided, all the current settings will be applied.
   * @description Applies the current settings to the game
   */
  vm.applyState = RateLimiter.debounce(applyState, 100);
  vm.refreshGraphicsState = RateLimiter.debounce(refreshGraphicsState, 100);
  vm.applyGraphicsState = RateLimiter.debounce(applyGraphicsState, 100);

  /**
   * @ngdoc method
   * @ngdoc checkUiUnitsSystem
   * @methodOf beamng.stuff.controllers:OptionsController
   * @description Check if UI units correspond to a preset.
   */
  vm.checkUiUnitsSystem = function () {
    var system = 'custom';

    for (var j in uiUnitsOptions.default) {
      var res = true;
      uiUnitsOptions.settable.forEach((elem, i) => {
        res = res && (vm.data.values[elem] === uiUnitsOptions.default[j][i]);
      });
      if (res) {
        system = j;
        break;
      }
    }

    uiUnitsOptions.system = system;
  };


}])


/**
 * @ngdoc controller
 * @name beamng.stuff.controllers:SettingsGraphicsCtrl
 * @description Controller for the graphics settings view
 */
.controller('SettingsGraphicsCtrl', ['$scope', 'bngApi', 'SettingsAuxData', function ($scope, bngApi, SettingsAuxData) {
  var vm = this;
  var settings = $scope.$parent.options;

  /**
   * @ngdoc method
   * @name resetGamma
   * @methodOf beamng.stuff.controllers:SettingsGraphicsCtrl
   * @description Resets gamma value to 1
   */
  vm.resetGamma = function () {
    settings.applyState({GraphicGamma: 1.0});
  };

  /**
   * @ngdoc method
   * @name applyOverallQuality
   * @methodOf beamng.stuff.controllers:SettingsGraphicsCtrl
   * @description Applies a graphics "overall quality" preset
   */
  vm.applyOverallQuality = function () {
    var preset = settings.data.values.GraphicOverallQuality;
    settings.applyState(angular.merge({GraphicOverallQuality: preset}, SettingsAuxData.graphicPresets[parseInt(preset)]));
  };


  /**
   * @ngdoc method
   * @name openPostFXManager
   * @methodOf beamng.stuff.controllers:SettingsGraphicsCtrl
   * @description Possibly deprecated. Opens a "Post FX Manager" window - not sure this thing works though.
   * Also this is not used anywhere, kept here just in case.
   */
  vm.openPostFXManager = function() {
    bngApi.engineScript('Canvas.pushDialog(PostFXManager);');
  };

  vm.resetPostFX = function() {
    bngApi.engineScript('exec("core/scripts/client/postFx/presets/default.postfxpreset.cs"); PostFXManager.settingsApplyFromPreset();');
  };



}])

.directive('tripleScreenCanvas', ['logger','Utils', '$timeout', function (logger, Utils, $timeout) {
  return {
    template: `
      <canvas style="border: 1px gray solid;width:100%"></canvas>
    `,
    replace: true,
    restrict: 'AEC',
    link: function (scope, element, attrs) {
      var canvas = element[0];
      var ctx = canvas.getContext('2d');

      var scale = (canvas.clientWidth / canvas.clientHeight);
      canvas.setAttribute('width', canvas.width * scale);
      canvas.setAttribute('height', canvas.height * scale);

      var hfov = 0;
      var aspectRatio = 1;

      //var screenSize = 32; // inch
      //var bezelSizes = 2;

      function degToRad(deg) {
        return deg * (Math.PI / 180)
      }

      function drawText(x, y, rot, yOffset, text, color) {
        var rotInRad = degToRad(rot)
        ctx.save()
        ctx.translate(x, y);
        ctx.rotate(rotInRad);
        ctx.font = "20px monospace";
        ctx.textAlign = "center";
        ctx.fillStyle = color;
        ctx.fillText(text, 0, -yOffset);
        ctx.restore();
      }

      function drawArrow(x, y, x2, y2, color) {
        ctx.beginPath();
        ctx.moveTo(x, y)
        ctx.lineTo(x2, y2)
        ctx.strokeStyle = color;
        ctx.stroke();
      }

      function drawArrowRot(x, y, len, rot, color) {
        var rotInRad = degToRad(rot)
        drawArrow(x, y, x + Math.cos(rotInRad) * len, y + Math.sin(rotInRad) * len, color)
      }

      function drawBoxRot(x, y, w, h, rot, fillStyle, strokeStyle) {
        var rotInRad = degToRad(rot)
        ctx.save()
        ctx.translate(x, y);
        ctx.rotate(rotInRad);

        ctx.beginPath();
        ctx.rect(- w * 0.5, - h * 0.5, w, h);
        if(fillStyle) {
          ctx.fillStyle = fillStyle;
          ctx.fill();
        }
        if(strokeStyle) {
          ctx.strokeStyle = strokeStyle;
          ctx.stroke();
        }

        ctx.restore();
      }

      function redraw() {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.save();

        var a = hfov / 3;

        var color = 'black';

        var screenDepth = 6;


        // middle screen
        var x = canvas.width * 0.5
        var y = canvas.height * 0.4
        drawBoxRot(x, y, 120, screenDepth, 0, '#ff6b00')
        drawArrowRot(x, y, 100, 90, color)
        drawText(x, y, 0, screenDepth, 'screen 2', color)
        drawBoxRot(x, 50, 120, 120 / aspectRatio, 0, null, '#ff6b00')

        // left screen
        var x1 = x - 60 - Math.cos(degToRad(-a)) * 60
        var y1 = y - Math.sin(degToRad(-a)) * 60
        drawBoxRot(x1, y1, 120, screenDepth, -a, '#ff6b00')
        drawArrowRot(x1, y1, 100, -a + 90, color)
        drawText(x1, y1, -a, screenDepth, 'screen 1', color)

        drawBoxRot(x1, 50, 120, 120 / aspectRatio, 0, null, '#ff6b00')

        //drawArrow(x1, y1, x1, canvas.height * 0.7, color)

        // right screen
        var x2 = x + 60 + Math.cos(degToRad(a)) * 60
        var y2 = y + Math.sin(degToRad(a)) * 60
        drawBoxRot(x2, y2, 120, screenDepth, a, '#ff6b00')
        drawArrowRot(x2, y2, 100, a + 90, color)
        drawText(x2, y2, a, screenDepth, 'screen 3', color)
        drawBoxRot(x2, 50, 120, 120 / aspectRatio, 0, null, '#ff6b00')



        ctx.restore();
      }

      scope.$watch('$parent.options.data.values', function(values) {
        //console.log('FOV changed: ', values.GraphicTripleMonitorFov)
        //console.log('screen res: ', values.GraphicDisplayResolutions)
        var aspectRatioStr = values.GraphicDisplayResolutions.split(' ')
        aspectRatio = parseInt(aspectRatioStr[0]) / parseInt(aspectRatioStr[1])
        //console.log('screen aspectRatio: ', aspectRatio)
        hfov = values.GraphicTripleMonitorFov
        redraw();
      });
    }
  }
}])

/**
 * @ngdoc controller
 * @name beamng.stuff.controllers:SettingsGameplayCtrl
 * @description Controller for the gameplay settings view
 */
.controller('SettingsGameplayCtrl', ['$location', '$scope', 'bngApi', 'mdx', 'ControlsUtils', 'UiUnitsOptions', 'AppDefaults' , function ($location, $scope, bngApi, mdx, ControlsUtils, UiUnitsOptions, AppDefaults) {
  var vm = this;
  var settings = $scope.$parent.options;
  vm.cameraConfig = [];
  vm.cameraBindings = [];
   for (i = 1; i < 11; i++) {
       vm.cameraBindings[i] = ControlsUtils.findBindingForAction("camera_"+i);
   }

  vm.focusedCamName;
  vm.lastSlotId = 0;
  vm.defaultId = null;

  $scope.$on('CameraConfigChanged', function (event, data) {
    $scope.$apply(
      function() {
        vm.cameraConfig = data.cameraConfig;
        vm.focusedCamName = data.focusedCamName;
        vm.defaultId = null;
        for (i in vm.cameraConfig) {
            if (vm.defaultId == null && !vm.cameraConfig[i].hidden && vm.cameraConfig[i].enabled) vm.defaultId = i;
            if (vm.cameraConfig[i].slotId) vm.lastSlotId = i;
        }
      }
    );
  });

  vm.changeOrder     = function(camId, offset) { bngApi.engineLua(`core_camera.changeOrder      (${camId+1}, ${offset})`); }
  vm.setCameraByName = function(camName) { bngApi.engineLua(`core_camera.setByName(0, '${camName}')`); }
  vm.toggleEnabledCameraById = function(camId) {console.log(camId); bngApi.engineLua(`core_camera.toggleEnabledById(${camId+1})`           ); }
  vm.resetConfiguration      = function     () { bngApi.engineLua(`core_camera.resetConfiguration()`                    ); }

  vm.resetSeat = function () {
    bngApi.engineLua(`if core_camera then core_camera.proxy_Player('resetSeat') end`);
  };
  vm.resetSeatAll = function () {
    bngApi.engineLua(`if core_camera then core_camera.proxy_Player('resetSeatAll') end`);
  };

  vm.updateTranslations = function () {
    bngApi.engineLua('updateTranslations()');
  };

  vm.enableCommunityTranslations = function() {
    bngApi.engineLua('enableCommunityTranslations()');
  };

  vm.intelCard = function () {
    return vm.values.GraphicGPU.toLowerCase().indexOf('intel') != -1;
  };

  // [ ---------- UI UNITS  --------- ]
  var checkUiUnitType = function (settings, defaults) {
    for (var j in defaults.default) {
      var res = true;
      defaults.settable.forEach((elem, i) => {
        res = res && (settings[elem] === defaults.default[j][i]);
      });
      if(res) return j;
    }
    // otherwise, it's custom
    return 'custom';
  };

  vm.specialUiUnit = UiUnitsOptions;
  vm.specialUiUnit.applyState = function () {

    var uiUnitsObj = {};
    var system = vm.specialUiUnit.system;

    if (system != 'custom') {
      uiUnitsObj['uiUnits'] = system;
      vm.specialUiUnit.settable.forEach((elem, i) => {
        uiUnitsObj[elem] = vm.specialUiUnit.default[system][i];
      });

      bngApi.engineLua(`settings.setState(${bngApi.serializeToLua(uiUnitsObj)})`);
    }
  };


  // [ ---------- UI COLORS --------- ]


  vm.uiConfig = JSON.parse(localStorage.getItem('angularThemeConfig')) || AppDefaults.uiTheme;
  vm.palettes = mdx.mdxThemeColors._PALETTES;

  /**
   * @ngdoc method
   * @name colorPaletteToRgbStr
   * @methodOf beamng.stuff.controllers:SettingsGameplayCtrl
   * @param {string} name Material UI palette name
   * @param {string} palette Palette hue
   * @description [ADD DESCRIPTION]
   * @return {String} RGB string corresponding to the palette
   */
  vm.colorPaletteToRgbStr = function (name, palette) {
    var which = (vm.uiConfig.dark ? 'dark' : 'light');
    return `rgb(${vm.palettes[name][mdx.indices[palette][which]].value.toString()})`;
  };

  /**
   * @ngdoc method
   * @name paletteChanged
   * @methodOf beamng.stuff.controllers:SettingsGameplayCtrl
   * @description Applies the palette changes made ingame.
   */
  vm.paletteChanged = function () {
    localStorage.setItem('angularThemeConfig', JSON.stringify(vm.uiConfig));
    window.location.reload();
  };

  /**
   * @ngdoc method
   * @name resetTheme
   * @methodOf beamng.stuff.controllers:SettingsGameplayCtrl
   * @description Loads the defaults for the theme and applies them
   */
  vm.resetTheme = function () {
    vm.uiConfig = AppDefaults.uiTheme;
    vm.paletteChanged();
  };

  // Logs all color rgbs in mdColorPalette
  // console.log($scope.uiConfig);
  // var help = {};
  // for (var i in mdx.mdxThemeColors._PALETTES) {
  //   help[i] = {};
  //   for (var j in mdx.mdxThemeColors._PALETTES[i]) {
  //     help[i][j] = mdx.mdxThemeColors._PALETTES[i][j].value.toString() || mdx.mdxThemeColors._PALETTES[i][j].value;
  //   }
  // }
  // console.table(help);

  vm.internal = beamng.buildtype === 'INTERNAL';

  bngApi.engineLua('if core_camera then core_camera.requestConfig() end');
}])


/**
 * @ngdoc controller
 * @name beamng.stuff.controllers:SettingsAudioCtrl
 * @description Controller for the audio settings view
 */
.controller('SettingsAudioCtrl', ['$scope', 'bngApi', function ($scope, bngApi) {
  var vm = this;
  var settings = $scope.$parent.options;

  var lastMasterVol = 0.8;
  vm.lastMaxChannels = settings.data.values.AudioMaxVoices;

  /**
   * @ngdoc method
   * @name toggleMute
   * @methodOf beamng.stuff.controllers:SettingsAudioCtrl
   * @description Toggles Master volume.
   */
  vm.toggleMute = function () {
    if (settings.data.values.AudioMasterVol > 1e-3) {
      lastMasterVol = settings.data.values.AudioMasterVol;
      settings.data.values.AudioMasterVol = 0;
    } else {
      settings.data.values.AudioMasterVol = lastMasterVol;
    }

    settings.applyState();
  }

}])

/**
 * @ngdoc object
 * @name  beamng.stuff:controlsContents
 *
 * @description Controls-related information used by various controllers and services.
 * Populated by the {@link beamng.stuff:ControlsUtils} when something changes
 * (bindings, available controllers) by using data coming from the
 * "ControllersChanged" and "InputBindingsChanged" events after this data is refactored
 * into a more UI-friendly format.
 */
.value('controlsContents', {
  actions: {},
  actionCategories: {},
  bindingTemplate: {},
  bindings: {},
  controllers: {}
})

.directive('binding', ['controlsContents', 'logger', 'ControlsUtils', 'Utils', function (controlsContents, logger, ControlsUtils, Utils) {
  return {
    template: `
      <span style="display: inline-block;" layout="row" layout-align="center center">
        <kbd ng-class="{light: !dark, dark: dark}" ng-if="viewerObj && !viewerObj.special">
          <span layout="row" layout-align="center center">
            <md-icon class="material-icons bng-binding-icon" style="font-size: 1em; padding-right: 0.14em" ng-style="{color: (dark ? 'white' : 'black')}">{{ viewerObj.icon }}</md-icon>
            <span ng-hide="hideName">{{ viewerObj.control | uppercase | replace:' ':' + ' | replace:'-':' + '}}</span>
          </span>
        </kbd>
        <div ng-style="{'-webkit-filter': (!dark ? 'invert(1)' : '')}" ng-if="viewerObj !== undefined && viewerObj.special" style="height: 1.4em; width: 1.4em;">
          <object style="max-height: 100%; max-width: 100%; pointer-events: none;" type="image/svg+xml" data="{{viewerObj.url}}"></object>
        </div>
        <div ng-style="{'-webkit-filter': (!dark ? 'invert(1)' : '')}" ng-if="viewerObj === undefined" style="height: 1.4em; width: 1.4em;">
          <object style="max-height: 100%; max-width: 100%; type="image/svg+xml" data="modules/options/deviceIcons/unknown.svg"></object>
        </div>
      </span>
    `,
    replace: true,
    scope: {
      hideName: '=',
      action: '@',
      device: '=',
      key: '=',
      dark: '='
    },
    link: function (scope, element, attrs) {

      var icons = {
        xinput:
        { btn_a: 'xbox/x_btn_a'
        , btn_b: 'xbox/x_btn_b'
        , btn_x: 'xbox/x_btn_x'
        , btn_y: 'xbox/x_btn_y'
        , btn_back: 'xbox/x_btn_back'
        , btn_start: 'xbox/x_btn_start'
        , btn_l: 'xbox/x_btn_lb'
        , triggerl: 'xbox/x_btn_lt'
        , btn_r: 'xbox/x_btn_rb'
        , triggerr: 'xbox/x_btn_rt'
        , dpov: 'xbox/x_dpad_down'
        , lpov: 'xbox/x_dpad_left'
        , rpov: 'xbox/x_dpad_right'
        , upov: 'xbox/x_dpad_up'
        , thumblx: 'xbox/x_thumb_left_x'
        , thumbly: 'xbox/x_thumb_left_y'
        , thumbrx: 'xbox/x_thumb_right_x'
        , thumbry: 'xbox/x_thumb_right_y'
        }
      }

      scope.$on('InputBindingsChanged', () => Utils.waitForCefAndAngular(getBinding));
      scope.$watch(() => scope.action + ' ' + scope.device + ' ' + scope.key, getBinding);

      function getBinding () {
        var helper = {};
        if (scope.key !== undefined) {
          helper = {
            icon: ControlsUtils.deviceIcon(scope.device),
            control: scope.key,
            devname: scope.device
          };
        } else if (scope.action !== undefined) {
          helper = ControlsUtils.findBindingForAction(scope.action, scope.device);
        }
        if (helper !== undefined) {
          var device;
          if (helper.devname) {
            for (var key in icons) {
              if (helper.devname.indexOf(key) === 0) {
                device = key;
              }
            }
          }
          scope.$evalAsync(() => {
            if (device && icons[device] !== undefined && icons[device][helper.control]) {
              scope.viewerObj = {
                special: true,
                url: `modules/options/deviceIcons/${icons[device][helper.control]}.svg`
              }
            } else {
              helper.special = false;
              scope.viewerObj = helper;
            }
          });
        }
      }
    }
  };
}])

/**
 * @ngdoc directive
 * @name beamng.stuff:hardwareControl
 *
 * @description
 * A small directive to give feedback to the user about the input
 * being captured. Each one refers to a specific control of a specific
 * device, listens to the incoming 'RawInputChanged' events and displays it
 * graphically.
 */
.directive('hardwareControl', function () {
    // @example
    // <example module="beamng.stuff">
    //   <file name="controls.js">
    //     <hardware-control width="80" device="xinput0" name="thumblry"></hardware-control>
    //   </file>
    // </example>

  return {
    template: '<div flex>' +
                '{{ ::name }}<br>' +
                '<div style="position: relative; height: 5px; background-color: white; border: solid grey 1px">' +
                  '<div style="position: absolute; top: 0; left: 0; height: 100%; background-color: darkgrey; width: {{ value }}px"></div>' +
                '</div>' +
              '<div>',
    replace: true,
    scope: {
      name: '@'
    },
    link: function (scope, element, attrs) {
      var device = attrs.device;
      scope.value = 0;
      scope.$on('RawInputChanged', function (event, data) {
        if (data.control == scope.name && data.devName == device) {
          scope.$evalAsync(function () {
            // get the width of the container and subtract the 2px border
            scope.value = (element[0].childNodes[2].offsetWidth -2) * data.value;
          });
        }
      });
    }
  };
})


/**
 * @ngdoc directive
 * @name beamng.stuff:hardwareKeyControl
 * @description A small directive to give feedback to the user about the
 * keys being pressed in a specified device. Much like {@link beamng.stuff:hardwareControl}
 * but more appropriate for keys.
**/
.directive('hardwareKeyControl', function () {
  return {
    template: `<span ng-repeat="ctrl in activeControls"><binding dark="true" key="ctrl" device="dev" style="margin: 5px;"></binding></span>`,
    replace: true,
    link: function (scope, element, attrs) {
      scope.dev = attrs.device;
      scope.activeControls = [];
      scope.$on('RawInputChanged', function (event, data) {
        if (data.devName != scope.dev) return;

        scope.$evalAsync(function () {
          var ctrlIndex = scope.activeControls.indexOf(data.control);
          if (data.value > 0.1 && ctrlIndex < 0) {
            scope.activeControls.push(data.control);
          } else if (data.value < 0.1) {
            scope.activeControls.splice(ctrlIndex, 1);
          }
        });

      });
    }
  };
})


/**
 * @ngdoc directive
 * @name beamng.stuff:ffbOptions
 * @description Options shown when editing a force-feedback control.
 */
.directive('ffbOptions', ['mdx', function (mdx) {
  return {
    replace: true,
    scope: { data: '=' },
    template: `
      <md-list>
        <md-divider></md-divider>
        <h3>Force Feedback Configuration</h3>
        <md-list-item md-no-ink>
          <p>Enabled</p>
          <md-tooltip md-direction="">Use if you desire to use your FFB-capable hardware</md-tooltip>
          <md-checkbox ng-model="data.isForceEnabled"></md-checkbox>
        </md-list-item>

        <md-list-item md-no-ink>
          <p>Inverted</p>
          <md-checkbox ng-model="data.isForceInverted"></md-checkbox>
          <md-tooltip md-direction="">Use this if your wheel force is acting on the opposite direction it should</md-tooltip>
        </md-list-item>

        <md-list-item layout>
          <span flex="35">Strength</span>
          <md-tooltip md-direction="top">Tweak to increase or decrease the overall strength of the Force Feedback</md-tooltip>
          <md-slider ng-model="data.ffb.forceCoef" flex min="0" max="1000" step="10" aria-label="_"></md-slider>
          <md-input-container class="bng-controls-aux-input">
            <input aria-label="_" type="number" min="0" max="1000" step="10" ng-model="data.ffb.forceCoef">
          </md-input-container>
        </md-list-item>

        <md-list-item layout>
          <span flex="35">Smoothing</span>
          <md-tooltip md-direction="">Reduces vibrations (but also increases response times and removes detail)</md-tooltip>
          <md-slider ng-model="data.ffb.smoothing" flex min="0" max="500" step="10" aria-label="_"></md-slider>
          <md-input-container class="bng-controls-aux-input">
            <input aria-label="_" type="number" min="0" max="500" step="10" ng-model="data.ffb.smoothing">
          </md-input-container>
        </md-list-item>

        <md-divider></md-divider>
        <md-list-item md-no-ink>
          <p>Reduce strength at low speeds</p>
          <md-checkbox ng-model="data.ffb.lowspeedCoef"></md-checkbox>
          <md-tooltip md-direction="top">Can help with vibrations</md-tooltip>
        </md-list-item>

        <md-list-item layout>
          <span flex="35">Side Accel Feedback</span>
          <md-tooltip md-direction="">Adds steering forces to emulate the sideways force on the driver</md-tooltip>
          <md-slider ng-model="uidata.ffb.gforceCoef" flex min="0" max="20" step="1" aria-label="_"></md-slider>
          {{ uidata.ffb.gforceCoef }} %
        </md-list-item>

        <md-list-item layout layout="row">
          <span flex="35">Max strength</span>
          <md-tooltip md-direction="">Safety guard against too strong forces (they will be capped at the specified limit)</md-tooltip>
          <md-slider ng-model="uidata.ffb.forceLimit" flex min="0" max="100" step="1" aria-label="_"></md-slider>
          <md-input-container class="bng-controls-aux-input">
            <input aria-label="_" type="number" min="0" max="100" step="1" ng-model="uidata.ffb.forceLimit">
          </md-input-container>
          %
        </md-list-item>

        <md-list-item layout>
          <p>Update rate limit</p>
          <md-tooltip md-direction="">How often force feedback updates are allowed to reach the device drivers. Greater rates are better, assuming hardware and firmware support them.</md-tooltip>
          <md-select flex ng-model="data.ffb.frequency" aria-label="_" class="bng-select-fullwidth">
            <md-option value="0" md-no-ink>Automatic</md-option>
            <md-option ng-repeat="i in [2000, 1500, 1250, 1000, 750, 600, 500, 400, 333, 250, 200, 150, 100, 75, 60, 50, 30]" value="{{i}}" md-no-ink>{{i}} Hz</md-option>
          </md-select>
        </md-list-item>

        <md-list-item layout>
          <p>Update type</p>
          <md-tooltip md-direction="">Certain FFB systems may require full updates to work</md-tooltip>
          <md-select flex ng-model="data.ffbUpdateType" aria-label="_" class="bng-select-fullwidth">
            <md-option value="0" md-no-ink>Fast (default)</md-option>
            <md-option value="1" md-no-ink>Full</md-option>
          </md-select>
        </md-list-item>

        <md-list-item md-no-ink>
          <p>Use Response Correction Curve</p>
          <md-checkbox ng-model="data.ffb.responseCorrected"></md-checkbox>
          <md-tooltip md-direction="top">Allows to BeamNG.drive to compensate for the non-linear nature of most force feedback hardware, increasing the response fidelity</md-tooltip>
        </md-list-item>
        <div ng-show="data.ffb.responseCorrected">
          <div style="width:310px; height: 150px; position:relative; border: solid grey 2px; margin-left: 20px;">
            <canvas id="ffbResponseCurve" style="position:absolute; top:0px; left:0px; width:100%; height: 100%"></canvas>
            <div class="curveHelp"        style="position:absolute; top:0px; left:0px; width:100%; height: 100%">
              <div class="curveHelpText" style="height: 100%">
                <small><strong>Hint:</strong> place a curve file in your <code>settings/inputmaps</code> directory, press <code>ctrl+L</code>, click Apply and reopen this menu. The inputmap <code>.diff</code> file will be automatically updated with the new curve data.</small>
                <br/>
                <br/>
                <small><strong>Accepted filenames:</strong>
                <span style="cursor:pointer">
                  <md-tooltip md-direction="top">Compatible with Assetto Corsa&trade; ff_post_process curves</md-tooltip>
                  <code>wheel.lut</code>
                  <md-icon class="material-icons" style="font-size: 1em">help</md-icon>
                </span>
                <span style="border: none">,</span>
                <span style="cursor:pointer">
                  <md-tooltip md-direction="top">Compatible with iRacing&trade; WheelCheck csv files (log-2 option)</md-tooltip>
                  <code>wheel.log</code>
                  <md-icon class="material-icons" style="font-size: 1em">help</md-icon>
                </span>
                <span style="border: none">,</span>
                <span style="cursor:pointer">
                  <md-tooltip md-direction="top">Compatible with Project Cars&trade; Force Curve Modifier exported files (linear force response option)</md-tooltip>
                  <code>wheel.fcm</code>
                  <md-icon class="material-icons" style="font-size: 1em">help</md-icon>
                </span>
                <span style="border-left: 0px">and<span>
                <span style="cursor:pointer">
                  <md-tooltip md-direction="top">Manually created file, each line having a <code>force</code>,<code>response</code> pair of values. Header lines are accepted. Any number scale may be used</md-tooltip>
                  <code>wheel.csv</code>
                  <md-icon class="material-icons" style="font-size: 1em">help</md-icon>
                </span>
                <span style="border-left: 0px">.<span>
                <br/>
              </div>
            </div>
          </div>
        </div>
      </md-list>`,
    link: function (scope, element, attrs) {
      scope.ffbResponseCurveRender = function() {
        var canvas = document.querySelector("[id=ffbResponseCurve]");
        var width = canvas.width;
        var height = canvas.height;
        var ctx = canvas.getContext("2d");
        var lineWidth = 3;

        var curve = scope.data.ffb.responseCurve;
        var xrange = 0;
        var yrange = 0;
        var lastDeadzoneX = 0;
        for (i in curve) {
          xrange = Math.max(curve[i][0], xrange);
          yrange = Math.max(curve[i][1], yrange);
          if (curve[i][1] <= 0) lastDeadzoneX = curve[i][0];
        }
        var lastDeadzoneScaledX = width*lastDeadzoneX/xrange;

        var accent     = "rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().accent    ][600].value.toString()+")"
        var accentLight= "rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().accent    ][200].value.toString()+")"
        var accentLight2="rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().accent    ][100].value.toString()+")"
        var primary    = "rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().primary   ][400].value.toString()+")"
        var primaryLight="rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().primary   ][100].value.toString()+")"
        var background = "rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().background][400].value.toString()+")"
        var warn       = "rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().warn      ][400].value.toString()+")"

        // deadzone filled rectangle
        ctx.fillStyle = accentLight2;
        ctx.fillRect(0,0, lastDeadzoneScaledX,height-1);

        // deadzone vertical line
        ctx.strokeStyle=accent;
        ctx.lineWidth=1;
        ctx.beginPath();
        ctx.moveTo(lastDeadzoneScaledX,height-1);
        ctx.lineTo(lastDeadzoneScaledX,0);
        ctx.stroke();


        // grid lines
        ctx.strokeStyle=primaryLight;
        ctx.lineWidth=1;
        var vtcells = 4
        var hzcells = 4
        var i;
        for(i=0; i<vtcells; i++) {
            ctx.beginPath();
            ctx.moveTo(    0, i*height/vtcells);
            ctx.lineTo(width, i*height/vtcells);
            ctx.stroke();
        }
        for(i=0; i<hzcells; i++) {
            ctx.beginPath();
            ctx.moveTo(i*width/hzcells, 0);
            ctx.lineTo(i*width/hzcells, height);
            ctx.stroke();
        }

        // linear line, starting after deadzone
        ctx.strokeStyle=accentLight;
        ctx.lineWidth=1;
        ctx.beginPath();
        ctx.moveTo(lastDeadzoneScaledX,height-1);
        ctx.lineTo(width, 0);
        ctx.stroke();

        // deadzone text
        ctx.strokeStyle=accent;
        ctx.lineWidth=1;
        var textHeight = 11;
        ctx.font = textHeight + "px sans-serif";
        var textSeparationY = textHeight;
        var textSeparationX = lastDeadzoneScaledX+10;
        ctx.beginPath();
        ctx.moveTo(lastDeadzoneScaledX,textSeparationY-textHeight*0.3);
        ctx.lineTo(textSeparationX-1, textSeparationY-textHeight*0.3);
        ctx.stroke();
        ctx.fillStyle = accent;
        ctx.fillText("force deadzone: ~"+ Math.round(100*lastDeadzoneX/xrange) + "%", textSeparationX, textSeparationY);

        // datapoint crosses
        var pointHeight = 5;
        for (i in curve) {
          var x = curve[i][0];
          var y = curve[i][1];
          var scaledx = width*x/xrange;
          var scaledy = height-height*y/yrange;
          ctx.strokeStyle=primary;
          ctx.lineWidth="1";
          ctx.beginPath();
              ctx.moveTo(scaledx, scaledy+lineWidth/2+pointHeight/2);
              ctx.lineTo(scaledx, scaledy-lineWidth/2-pointHeight/2);
          ctx.stroke();
        }

        // datapoints curve
        ctx.moveTo(0,height-1);
        ctx.strokeStyle=accent; // good for line, leave as is
        ctx.lineWidth=lineWidth;
        ctx.beginPath();
        for (i in curve) {
            var x = curve[i][0];
            var y = curve[i][1];
            var scaledx = width*x/xrange;
            var scaledy = height-height*y/yrange;
            ctx.lineTo(scaledx, scaledy);
        }
        ctx.stroke();
      };
      scope.ffbResponseCurveRender();

      var mapUI = function(sourceModel, mappedModel, path, getter, setter) {
          // Allows to point ng-model at the mappedModel, rather than sourceModel
          //   getter defines the source-to-mapped conversion
          //   setter defines the mapped-to-source conversion
          // Can be used to display custom units *only* in the UI
          //
          // Example: mapUI(dict1, dict2, "foo.bar.z", v=>v+1, v=>v-1)
          // Will expose the 0-based index <dict1.foo.bar.z> as a 1-based index at <dict2.foo.bar.z>
          //
          function ref(obj,is,value) {
            // if <is> has a value of "foo.bar.z", this function will return obj.foo.bar.z
            // if <value> is defined, obj.foo.bar.z will be assigned <value> before returning
            if (typeof is == 'string') return ref(obj,is.split('.'), value);
            else if (is.length==1 && value!==undefined) return obj[is[0]] = value;
            else if (is.length==0) return obj;
            else return ref(obj[is[0]],is.slice(1), value);
          }
          // build the necessary empty dict structure in 'mappedModel', that allows access to the 'path' object
          var subpaths = path.split('.');
          var subpath;
          for(i in subpaths) {
            subpath = subpaths[i];
            if (i == subpaths.length-1) break;
            if (mappedModel[subpath] === undefined) mappedModel[subpath] = {};
            mappedModel = mappedModel[subpath];
          }
          // define the actual conversion setter & getter
          Object.defineProperty(mappedModel, subpath, {
            get:function(){return getter(ref(sourceModel, path));},
            set:function(v){ref(sourceModel, path, setter(v));}
          });
      };

      scope.uidata = {};
      mapUI(scope.data, scope.uidata, "ffb.forceLimit", v=>Math.round(v*10), v=>v/10); //0-10 => 0-100
      mapUI(scope.data, scope.uidata, "ffb.gforceCoef", v=>Math.round(v*100), v=>v/100); //0-0.2 => 0-20
    }
  };
}])

/**
 * @ngdoc directive
 * @name beamng.stuff:axisOptions
 * @description Options shown when editing an axis-type control.
 */
.directive('axisOptions', ['mdx', function (mdx) {
  return {
    replace: true,
    scope: { data: '=', isCentered: '<iscentered' },
    template: `
    <md-list>
      <md-divider></md-divider>

      <md-list-item layout ng-if="data.details.action == 'steering'">
        <span flex="30">Steering Lock Angle</span>
        <md-tooltip md-direction="">How much your steering wheel can turn, from lock to lock. Advice: use the same number displayed in the drivers configuration panel, which should be set to the maximum your steering wheel supports.</md-tooltip>
        <md-slider ng-model="data.details.angle" ng-change="inputResponseCurveRender()" flex min="0" max="6000" step="10" aria-label="_"></md-slider>
        <md-input-container class="bng-controls-aux-input" >
          <input aria-label="_" type="number" min="0" max="6000" step="10" ng-model="data.details.angle" ng-change="inputResponseCurveRender()">
        </md-input-container>
      </md-list-item>
      <md-list-item layout style="margin: 0px 16px; color: red; border: red 1px solid; border-radius: 4px;" class="md-caption md-padding" ng-if="data.details.lockType != '0' && data.details.angle <= 0">
        <strong style="margin: 0px 12px 0px 0px;">{{:: 'ui.options.graphics.Warning' | translate}}</strong>
        <p>{{:: 'ui.controls.lockType.warningMissingAngle' | translate}}</p>
      </md-list-item>
      <md-list-item layout style="margin: 0px 16px; color: red; border: red 1px solid; border-radius: 4px;" class="md-caption md-padding" ng-if="data.details.lockType == '0' && data.details.angle > 0">
        <strong style="margin: 0px 12px 0px 0px;">{{:: 'ui.options.graphics.Warning' | translate}}</strong>
        <p>{{:: 'ui.controls.lockType.warningAdvice' | translate}}</p>
      </md-list-item>
      <md-list-item layout>
        <span flex="35">{{:: "ui.controls.lockType" | translate }}</span>
        <md-select flex ng-model="data.details.lockType" aria-label="_" class="bng-select-fullwidth">
          <md-option value="0" md-no-ink>{{:: "ui.controls.lockTypes.0" | translate }}</md-option>
          <md-option value="1" md-no-ink>{{:: "ui.controls.lockTypes.1" | translate }}</md-option>
          <md-option value="2" md-no-ink>{{:: "ui.controls.lockTypes.2" | translate }}</md-option>
        </md-select>
        <md-tooltip md-direction="">How BeamNG.drive will attempt to match your steering wheel to the vehicle you're driving. Any 1:1 lock type is recommended over 1:N</md-tooltip>
      </md-list-item>

      <div style="width:310px; height: 150px; position:relative; border: solid grey 2px; margin-left: 20px;">
        <canvas id="inputResponseCurve" style="position:absolute; top:0px; left:0px; width:100%; height: 100%"></canvas>
      </div>

      <md-list-item md-no-ink>
        <p>Inverted Axis</p>
        <md-tooltip md-direction="">Use if the action triggers when you stop using the controller</md-tooltip>
        <md-checkbox ng-model="data.details.isInverted" ng-change="inputResponseCurveRender()"></md-checkbox>
      </md-list-item>

      <md-list-item layout>
        <span flex="30">Linearity</span>
        <md-tooltip md-direction="">Greater values mean slower response in the center (and faster response on the edges)</md-tooltip>
        <md-slider ng-change="inputResponseCurveRender()" ng-model="data.details.linearity" flex min="0.1" max="5" step="0.1" aria-label="_"></md-slider>
        <md-input-container class="bng-controls-aux-input">
          <input aria-label="_" type="number" min="0.1" max="5" step="0.1" ng-model="data.details.linearity" ng-change="inputResponseCurveRender()">
        </md-input-container>
      </md-list-item>

      <md-list-item layout>
        <span flex="30">Deadzone (rest)</span>
        <md-tooltip md-direction="">Use when the resting position of your controller is still triggering an action. Typical values are 0.1 to 0.25</md-tooltip>
        <md-slider ng-model="data.details.deadzoneResting" ng-change="inputResponseCurveRender()" flex min="0" max="1" step="0.025" aria-label="_"></md-slider>
        <md-input-container class="bng-controls-aux-input" >
          <input aria-label="_" type="number" min="0" max="1" step="0.025" ng-model="data.details.deadzoneResting" ng-change="inputResponseCurveRender()">
        </md-input-container>
      </md-list-item>
      <md-list-item layout>
        <span flex="30">Deadzone (end)</span>
        <md-tooltip md-direction="">Use when you cannot reach all the axis travel range. Typical values are 0 to 0.25</md-tooltip>
        <md-slider ng-model="data.details.deadzoneEnd" ng-change="inputResponseCurveRender()" flex min="0" max="1" step="0.025" aria-label="_"></md-slider>
        <md-input-container class="bng-controls-aux-input" >
          <input aria-label="_" type="number" min="0" max="1" step="0.025" ng-model="data.details.deadzoneEnd" ng-change="inputResponseCurveRender()">
        </md-input-container>
      </md-list-item>
    </md-list>`,
    link: function (scope, element, attrs) {
      var applyFilters = function(value, filter, isCentered) {
          var deadzoneResting = Math.max(0, filter.deadzoneResting);
          var deadzoneEnd = Math.max(0, filter.deadzoneEnd);
          var x = value;
          var linearity = Math.max(0.1, filter.linearity);
          if (filter.isInverted) {
              x = 1.0 - x;
              value = 1.0 - value;
          }
          if (isCentered) {
              value = value * 2.0 - 1.0; // means converting from [0..+1] to [-1..+1]
          }
          if (value >= -deadzoneResting && value <= deadzoneResting) {
              value = 0.0;
          } else {
              if (value >= 0.0) value = (value - deadzoneResting) / (1.0 - deadzoneResting - deadzoneEnd);
              else              value = (value + deadzoneResting) / (1.0 - deadzoneResting - deadzoneEnd);
          }
          value = (value < 0.0 ? -1.0 : 1.0) * Math.min(1, Math.pow(Math.abs(value), linearity));
          return [x, value];
      };
      var lastRawValue = scope.isCentered ? 1/2 : 0;
      scope.$on('RawInputChanged', function (event, data) {
        if (scope.data.device == data.devName && scope.data.details.control == data.control) {
            lastRawValue = data.value;
            scope.inputResponseCurveRender();
        }
      });
      scope.inputResponseCurveRender = function() {
        var canvas = document.querySelector("[id=inputResponseCurve]");
        var width = canvas.width;
        var height = canvas.height;
        var ctx = canvas.getContext("2d");
        var lineWidth = 3;

        var curve = [];
        var dzRestingRaw = Math.max(0,scope.data.details.deadzoneResting);
        var dzEndRaw = Math.max(0,scope.data.details.deadzoneEnd);
        var deadzoneEnd = dzEndRaw;
        var deadzoneResting = dzRestingRaw;
        if (scope.isCentered) deadzoneResting = (deadzoneResting + 1) / 2;
        if (scope.isCentered) deadzoneEnd /= 2;
        var data = scope.data.details;
        var i = 0;
        var x = 0;
        for(x=0; x<=1.0001; x += 0.01) {
            var point = applyFilters(x, data, scope.isCentered);
            curve[i++] = point;
        }

        var xrange = 1;
        var yrange = 1;
        var dzRestingEndScaled = width*deadzoneResting/xrange;
        var dzEndEndScaled = width-(width*deadzoneEnd/xrange);
        var dzRestingBeginScaled = -dzRestingEndScaled;
        if (scope.isCentered) dzRestingBeginScaled = width - dzRestingEndScaled;

        var accent     = "rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().accent    ][600].value.toString()+")"
        var accentLight= "rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().accent    ][200].value.toString()+")"
        var accentLight2="rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().accent    ][100].value.toString()+")"
        var primary    = "rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().primary   ][400].value.toString()+")"
        var primaryLight="rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().primary   ][100].value.toString()+")"
        var background = "rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().background][400].value.toString()+")"
        var warn       = "rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().warn      ][400].value.toString()+")"
        var white = "rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().background][100].value.toString()+")"

        // redraw from scratch
        ctx.clearRect(0, 0, width, height);

        // deadzone filled rectangle
        ctx.fillStyle = accentLight2;
        // resting deadzone
        ctx.fillRect(dzRestingBeginScaled,0, dzRestingEndScaled-dzRestingBeginScaled,height-1);
        // end deadzone
        ctx.fillRect(dzEndEndScaled,0, width,height-1);
        if (scope.isCentered) ctx.fillRect(0,0, width-dzEndEndScaled,height-1);

        // deadzone vertical lines
        ctx.strokeStyle=accent;
        ctx.lineWidth=1;
        ctx.beginPath();
        // resting deadzone
        ctx.moveTo(dzRestingBeginScaled,height-1);
        ctx.lineTo(dzRestingBeginScaled,0);
        ctx.moveTo(dzRestingEndScaled,height-1);
        ctx.lineTo(dzRestingEndScaled,0);
        // end deadzone
        ctx.moveTo(dzEndEndScaled,height-1);
        ctx.lineTo(dzEndEndScaled,0);
        if (scope.isCentered) {
            // resting deadzone
            ctx.moveTo(width/2,height-1);
            ctx.lineTo(width/2,0);
            // end deadzone
            ctx.moveTo(width-dzEndEndScaled,height-1);
            ctx.lineTo(width-dzEndEndScaled,0);
        }
        ctx.stroke();


        // grid lines
        ctx.strokeStyle=primaryLight;
        ctx.lineWidth=1;
        var vtcells = 4
        var hzcells = 4
        for(i=0; i<vtcells; i++) {
            ctx.beginPath();
            ctx.moveTo(    0, i*height/vtcells);
            ctx.lineTo(width, i*height/vtcells);
            ctx.stroke();
        }
        for(i=0; i<hzcells; i++) {
            ctx.beginPath();
            ctx.moveTo(i*width/hzcells, 0);
            ctx.lineTo(i*width/hzcells, height);
            ctx.stroke();
        }

        // linear lines, starting after deadzone
        ctx.strokeStyle=accentLight;
        ctx.lineWidth=1;
        ctx.beginPath();
        if (scope.isCentered) {
            ctx.moveTo(width-dzEndEndScaled,0);
            ctx.lineTo(dzRestingBeginScaled, height-1);
        }
        ctx.moveTo(dzRestingEndScaled,height-1);
        ctx.lineTo(dzEndEndScaled, 0);
        ctx.stroke();

        // deadzone text
        ctx.strokeStyle=accent;
        ctx.lineWidth=1;
        var textHeight = 11;
        ctx.font = textHeight + "px sans-serif";
        ctx.fillStyle = accent;
        var textSeparationY = textHeight;
        var textSeparationX = dzRestingEndScaled+10;
        // resting deadzone
        if (dzRestingRaw != 0) {
            ctx.save();
            ctx.beginPath();
            ctx.moveTo(dzRestingEndScaled,textSeparationY*2-textHeight*0.3);
            ctx.lineTo(textSeparationX-1, textSeparationY*2-textHeight*0.3);
            ctx.stroke();
            var dzRestingText = "deadzone: " + Math.round(100*dzRestingRaw/xrange) + "%";
            ctx.fillText(dzRestingText, textSeparationX, textSeparationY*2);
            ctx.restore();
        }
        // end deadzone
        if (dzEndRaw != 0) {
            ctx.save();
            ctx.beginPath();
            ctx.moveTo(dzEndEndScaled,textSeparationY-textHeight*0.3);
            ctx.lineTo(dzEndEndScaled-10, textSeparationY-textHeight*0.3);
            ctx.stroke();
            ctx.textAlign = "right";
            var dzEndText = "deadzone: " + Math.round(100*dzEndRaw/xrange) + "%";
            ctx.fillText(dzEndText, dzEndEndScaled-10, textSeparationY);
            ctx.restore();
        }

        // legend text
        ctx.save();
        ctx.strokeStyle=accentLight;
        ctx.translate(0, 0);
        ctx.textAlign = "right";
        var outputLabel = "output";
        var point = applyFilters(lastRawValue, data, scope.isCentered);
        var x = point[0], y = point[1];
        outputLabel += ": " + Math.round(y*100) + "%";
        ctx.fillText(outputLabel, width-8, height-textHeight*0.3);
        ctx.restore();

        // datapoints curve
        if (scope.isCentered) ctx.moveTo(0,0);
        else ctx.moveTo(0,height-1);
        ctx.strokeStyle=accent; // good for line, leave as is
        ctx.lineWidth=lineWidth;
        ctx.beginPath();
        for (i in curve) {
            var x = curve[i][0];
            var y = curve[i][1];
            if (y < 0) y *= -1;
            var scaledx = width*x/xrange;
            var scaledy = height-height*y/yrange;
            ctx.lineTo(scaledx, scaledy);
        }
        ctx.stroke();

        // current output, highlighted with a cross
        var point = applyFilters(lastRawValue, data, scope.isCentered);
        var x = point[0], y = point[1];
        var ox = 0;
        if (scope.isCentered) ox = 1 / 2;
        var oy = 0;
        ctx.lineTo(width/2,0);
        if (y < 0) y *= -1;
        var scaledx = width*x/xrange;
        var scaledy = height-height*y/yrange;
        var scaledox = width*ox/xrange;
        var scaledoy = height-height*oy/yrange;

        // overall cross
        ctx.lineWidth=1;
        ctx.strokeStyle=accentLight;
        ctx.beginPath();
          ctx.moveTo(scaledx, 0);
          ctx.lineTo(scaledx, height);
          ctx.moveTo(0,      scaledy);
          ctx.lineTo(width,  scaledy);
        ctx.stroke();

        // trunk line
        ctx.strokeStyle=accent;
        ctx.lineWidth=3;
        ctx.beginPath();
          ctx.moveTo(scaledx, scaledoy);
          ctx.lineTo(scaledx, scaledy);
        ctx.stroke();

        // circle perimeter
        ctx.lineWidth=2;
        ctx.beginPath();
          ctx.fillStyle = white;
          ctx.arc(scaledx, scaledy, 4, 0, 2 * Math.PI);
          ctx.fill();
        ctx.stroke();

      };
      scope.inputResponseCurveRender();
    }
  };
}])


/**
 * @ngdoc service
 * @name beamng.stuff:ControlsUtils
 * @description Various controls-related utility functions
**/
.factory('ControlsUtils', ['$filter', '$log', '$q', '$rootScope', 'bngApi', 'controlsContents', function ($filter, $log, $q, $rootScope, bngApi, controlsContents) {
  var _captureHelper = {
    devName: null,
    stopListening: null
  };

  // [ Listeners ]
  // This is done here, so other modules can use the service and cache object, whithout having to
  // The service listens constantly for 2 events:
  //  1. ControllersChanged in order to list all the currently available devices in the Hardware tab
  //  2. InputBindingsChanged in order to populate the bindings listings in Bindings tab


  $rootScope.$on('ControllersChanged', function (event, data) {
    $rootScope.$evalAsync(function () {
      controlsContents.controllers = data;
    });
  });
  $rootScope.$on('AssignedPlayersChanged', function (event, data) {
    $rootScope.$evalAsync(function () {
      controlsContents.players = data;
    });
  });

  $rootScope.$on('InputBindingsChanged', function (event, data) {
    $rootScope.$evalAsync(function () {

      // sometimes bindings[deviceIndex].contents.bindings is an object instead of an array!
      // should be fixed, but let's cover this up until then.
      // NOTE: This is really REALLY bad.
      for (var _device in data.bindings) {
        if (!Array.isArray(data.bindings[_device].contents.bindings)) {
          var backup = angular.copy(data.bindings[_device].contents.bindings)
          data.bindings[_device].contents.bindings = [];
          for (var key in backup) {
            data.bindings[_device].contents.bindings.push(backup[key]);
          }
        }
      }

      controlsContents.categories = data.actionCategories;
      controlsContents.bindings   = data.bindings;
      controlsContents.bindingTemplate = data.bindingTemplate;

      // Normally, the key in data actions is the action name. However, in vehicle specific
      // bindings, the key is of the form {vehicle}__actionName, so get the actionName field
      // from the object to be sure.
      controlsContents.actions = {};
      for (var x in data.actions) {
        controlsContents.actions[x] = angular.merge({actionName: x}, data.actions[x]);
      }





      for (var device in data.bindings)
        controlsContents.bindings[device].icon = service.deviceIcon(data.bindings[device].devname);

      // vm.ffbBound = service.isFfbBound();

      // Refactor categories & actions
      for (var c in controlsContents.categories) {
        controlsContents.categories[c].actions = [];
      }

      for (var action in controlsContents.actions) {
        var obj = angular.merge({key: action}, controlsContents.actions[action]);
        controlsContents.categories[ controlsContents.actions[action].cat ].actions.push(obj);
      }

      controlsContents.categoriesList = [];
      Object.keys(controlsContents.categories).map(function (category) {
        controlsContents.categoriesList.push(angular.merge({key: category}, controlsContents.categories[category]));
      });
    });
  });

  bngApi.engineLua('extensions.core_input_bindings.notifyUI("controls utils service needs the data")');


  var service = {
    findBindingForAction: function (action, devname) {
      var found = false
        , device
        , control
      ;

      // it's fortunate the controler is before the keyboard in this list, since one would prefer having the controler keys over the keyboard, if one is pluged in
      for (var i = 0; i < controlsContents.bindings.length && !found && (devname === undefined || devname === controlsContents.bindings[i].devname); i += 1) {
        var toSearch = controlsContents.bindings[i].contents.bindings.map((x) => x.action)
          , index;
        if ((index = toSearch.indexOf(action)) !== -1) {
          found = true;
          device = controlsContents.bindings[i].devname;
          control = controlsContents.bindings[i].contents.bindings[index].control;
        }
      }

      if (found) {
        var help = this.getBindingDetails(device, control, action);
        help.devname = device;
        return help;
      } else {
        return undefined;
      }
    },
    /**
     * @ngdoc method
     * @name getBindingDetails
     * @methodOf beamng.stuff:ControlsUtils
     *
     * @param {string} device The name of the device
     * @param {string} control The control of the binding
     * @param {string} action Action related to that binding
     *
     * @description Returns properties of the requested binding
     */
    getBindingDetails: function (device, control, action) {
      var deviceBindings = $filter('filter')(controlsContents.bindings, {devname: device}, true)[0].contents.bindings
        , details = $filter('filter')(deviceBindings, {control: control, action: action}, true)[0] || service.defaultBindingEntry(action, control)
        , common =
          { icon: this.deviceIcon(device)
          , title: controlsContents.actions[action].title
          , desc: controlsContents.actions[action].desc
          };

      return angular.merge({}, controlsContents.bindingTemplate, details, common);
    },

    /**
     * @ngdoc method
     * @name defaultBindingEntry
     * @methodOf beamng.stuff:ControlsUtils
     *
     * @param {string} action [TODO: Add description]
     * @param {string} control [TODO: Add description]
     *
     * @description A template object for use when editing a binding
     */
    defaultBindingEntry: function (action, control) {
      var tmpl = angular.copy(controlsContents.bindingTemplate);
      tmpl.action  = action;
      tmpl.control = control;
      return tmpl;
    },

    /**
     * @ngdoc method
     * @name isAxis
     * @methodOf beamng.stuff:ControlsUtils
     *
     * @param {string} device [TODO: Add description]
     * @param {string} control [TODO: Add description]
     *
     * @description Determines if the control is of "axis" type
     */
    isAxis: function (device, control) {
      if (controlsContents.controllers[device].controls[control])
        return controlsContents.controllers[device].controls[control]['control_type'] === 'axis';
      return false;
    },

    /**
     * @ngdoc method
     * @name deviceIcon
     * @methodOf beamng.stuff:ControlsUtils
     *
     * @param {string} devName Name of the device
     *
     * @description Returns the icon to be used for a particular device.
     */
    deviceIcon: function (devName) {
      devName = devName || '';
      switch (devName.slice(0, 3)) {
        case 'key': return 'keyboard';
        case 'mou': return 'mouse';
        case 'vin': return 'phone_android';
        case 'whe': return 'radio_button_on';
        case 'gam': return 'videogame_asset';
        case 'xin': return 'videogame_asset';
        default:    return 'gamepad';
      }
    },

    deviceNames: function () {
      return controlsContents.bindings.map((elem) => elem.devname);
    },

    /**
     * @ngdoc method
     * @name bindingConflicts
     * @methodOf beamng.stuff:ControlsUtils
     *
     * @param {string} device [TODO: Add description]
     * @param {string} control [TODO: Add description]
     * @param {string} action [TODO: Add description]
     *
     * @description Finds the conflicts of a given binding. Another binding is considered
     * a conflict if it refers to the same control of the same device, and the two actions
     * belong to the same actionMap.
     *
     * @returns {array} The conflicting bindings
     */
    bindingConflicts: function (device, control, action) {
      var device = $filter('filter')(controlsContents.bindings, {devname: device})[0]
        , others = $filter('filter')(device.contents.bindings, {control: control}, true)
        , conflicts = []
      ;

      for (var i in others) {
        if (others[i].action != action)
          conflicts.push({ binding: others[i], resolved: false });
      }

      return conflicts;
    },

    /**
     * @ngdoc method
     * @name captureBinding
     * @methodOf beamng.stuff:ControlsUtils
     *
     * @param {string} devName [TODO: Add description]
     *
     * @description Captures user input.
     *
     * @returns {Promise} [TODO: Add description]
     */
    captureBinding: function (devName) {
      var controlCaptured = false
        , eventsRegister = { axis: {}, button: {}, key: [null, null] }
        , d = $q.defer()
      ;

      _captureHelper.devName = devName;
      var capturingBinding = true;

      _captureHelper.stopListening = $rootScope.$on('RawInputChanged', function (event, data) {
        if (!capturingBinding) return; // Not trying to capture bindings, ignore
        if (controlCaptured) return; // No business listening to incoming events.

        // If we are commited to listening to a specified device,
        // we don't care if another device is triggering
        if (!_captureHelper.devName || data.devName == _captureHelper.devName) {
          d.notify(data);
          var valid = false;

          // Register the received input. The control types are handled
          // separately, because different criteria apply to each one of them.
          switch(data['controlType']) {
            case 'axis':
              if (! eventsRegister.axis[data.control])
                eventsRegister.axis[data.control] = { start: data.value, end: data.value }
              else
                eventsRegister.axis[data.control].end = data.value;

              // If we are working with axes (i.e. the axis property has been populated) we
              // should be a little strict because there will probably be noise (mouse movements
              // are a perfect example). The criterion is if there is *enough* motion in a given
              // direction.
              valid = Math.abs(eventsRegister.axis[data.control].end - eventsRegister.axis[data.control].start) > 0.25;
              break;

            case 'button':
            case 'pov':
              if (!eventsRegister.button[data.control])
                eventsRegister.button[data.control] = 1;
              else
                eventsRegister.button[data.control] += 1;

              // Buttons are the easiest, we just have to listen to 2 events of
              // the same button (i.e. an on-off event cycle).
              valid = eventsRegister.button[data.control] > 1;
              break;

            case 'key':
              eventsRegister.key.push(data.control);
              eventsRegister.key = eventsRegister.key.slice(-2);

              // Keys are easy too but not as trivial as buttons, because there can be
              // key combinations. We keep track of the last two key events, if they
              // coincide (again an on-off event cycle, like the case with buttons), we
              // can assign the control.
              valid = eventsRegister.key[0] == eventsRegister.key[1];
              break;
            default:
              $log.error("Unrecognized raw input controlType: %o", data);
          }

          // Want to blacklist something? Put it here!
          if (valid) {
            // No right mouse click
            if(data.devName.startsWith('mouse') && data.control == 'button1')
              valid = false;
          }

          if (valid) {
            controlCaptured = true;
            capturingBinding = false;
            data.direction = data['controlType'] == 'axis' ? Math.sign(eventsRegister.axis[data.control].end - eventsRegister.axis[data.control].start) : 0;
            d.resolve(data);
            _captureHelper.stopListening();
          }
        }
      });

      return d.promise;
    },

    /**
     * @ngdoc method
     * @name removeBinding
     * @methodOf beamng.stuff:ControlsUtils
     *
     * @param {string} device [TODO: Add description]
     * @param {string} control [TODO: Add description]
     * @param {string} action [TODO: Add description]
     * @param {boolean} mockSave [TODO: Add description]
     *
     * @description [TODO: Add description]
     */
    removeBinding: function (device, control, action, mockSave) {
      var deviceContents = angular.copy($filter('filter')(controlsContents.bindings, {devname: device}, true)[0].contents);
      var entry = $filter('filter')(deviceContents.bindings, {control: control, action: action}, true)[0] || null;
      if (!entry) return;


      var index = deviceContents.bindings.indexOf(entry);
      deviceContents.bindings.splice(index, 1);

      if (mockSave) {
        var deviceIndex;
        for (deviceIndex = 0; deviceIndex < controlsContents.bindings.length; deviceIndex++) {
          if (controlsContents.bindings[deviceIndex].devname === device)
            break;
        }

        controlsContents.bindings[deviceIndex].contents = deviceContents;

      } else {
        bngApi.engineLua(`extensions.core_input_bindings.saveBindingsToDisk(${bngApi.serializeToLua(deviceContents)})`);
      }
    },

    /**
     * @ngdoc method
     * @name addBinding
     * @methodOf beamng.stuff:ControlsUtils
     *
     * @param {string} device [TODO: Add description]
     * @param {string} bindingData [TODO: Add description]
     * @param {boolean} replace [TODO: Add description]
     * @param {boolean} mockSave [TODO: Add description]
     *
     * @description [TODO: Add description]
     */
    addBinding: function (device, bindingData, replace, mockSave) {
      var deviceContents = angular.copy($filter('filter')(controlsContents.bindings, {devname: device}, true)[0].contents);
      if (replace) {
        var deprecated = $filter('filter')(deviceContents.bindings, {control: bindingData.details.control, action: bindingData.details.action}, true)[0];
        var index = deviceContents.bindings.indexOf(deprecated);
        deviceContents.bindings[index] = bindingData;
      } else {
        deviceContents.bindings.push(bindingData);
      }

      bngApi.engineLua(`extensions.core_input_bindings.saveBindingsToDisk(${bngApi.serializeToLua(deviceContents)})`);
    },

    /**
     * @ngdoc method
     * @name resetAllBindings
     * @methodOf beamng.stuff:ControlsUtils
     *
     * @description Resets bindings to the default settings
     */
    resetAllBindings: function () {
      bngApi.engineLua('extensions.core_input_bindings.resetAllBindings()');
    },


    /**
     * @ngdoc method
     * @name isFfbBound
     * @methodOf beamng.stuff:ControlsUtils
     *
     * @description Determines if a force-feedback control is bound
     * @returns {boolean} [TODO: Add description]
     */
    isFfbBound: function () {
      for (var i = 0; i<controlsContents.bindings.length; i++) {
        if (controlsContents.bindings[i].devname.slice(0, 3) === 'key') continue;
        if (controlsContents.bindings[i].devname.slice(0, 3) === 'mou') continue;

        for (var j = 0; j<controlsContents.bindings[i].contents.bindings.length; j++) {
          if (controlsContents.bindings[i].contents.bindings[j].action === 'steering')
            return true;
        }
      }

      return false;
    },

    /**
     * @ngdoc method
     * @name isFfbCapable
     * @methodOf beamng.stuff:ControlsUtils
     *
     * @description Determines if a force-feedback capable device is detected.
     * @returns {boolean} [TODO: Add description]
     */
    isFfbCapable: function () {
      for (var device in controlsContents.controllers) {
        if (controlsContents.controllers[device].ffbAxes && Object.keys(controlsContents.controllers[device].ffbAxes).length > 0)
          return true;
      }

      return false;
    }
  };

  return service;
}])



/**
 * @ngdoc controller
 * @name beamng.stuff:ControlsController
 * @requires $scope
 * @requires beamng.stuff:bngApi
 * @requires beamng.stuff:controlsContents
 * @requires beamng.stuff:ControlsUtils
 * @description
**/
.controller('ControlsController', ['$scope',  'bngApi', 'controlsContents', 'ControlsUtils',
function ($scope, bngApi, controlsContents, ControlsUtils) {
  var vm = this;
  vm.data = controlsContents;
  $scope.isShipping = beamng.shipping;
}])


/**
 * @ngdoc controller
 * @name beamng.stuff:ControlsBindingsCtrl
 * @description [TODO: Add description]
 */
.controller('ControlsBindingsCtrl', ['$state', 'ControlsUtils',
  function ($state, ControlsUtils) {
  var _bindingData = { device: '', deviceIcon: '', details: {}, isAxis: false };

  var vm = this;
  vm.fActions = {}; // Placeholder for filtered actions (populated by ng-repeat directive in the controls-bindings.html template)

  vm.select = function (action, device, control) {
    $state.go('menu.options.controls.bindings.edit', { action: action, oldBinding: {device: device, control: control, sel: angular.copy(_bindingData)} });
  };

  vm.resetAll = function () {
    ControlsUtils.resetAllBindings();
  };

}])

/**
 * @ngdoc controller
 * @name beamng.stuff:ControlsEditCtrl
 * @description [TODO: Add description]
 */
.controller('ControlsEditCtrl', ['$scope', '$state', '$stateParams', 'bngApi', 'controlsContents', 'ControlsUtils',
 function ($scope, $state, $stateParams, bngApi, controlsContents, ControlsUtils) {
  var vm = this;
  var listeningTimeout;

  vm.action = controlsContents.actions[$stateParams.action];

  vm.oldBinding = $stateParams.oldBinding.sel || {};
  if ($stateParams.oldBinding.device && $stateParams.oldBinding.control) {
    vm.oldBinding.device = $stateParams.oldBinding.device,
    vm.oldBinding.deviceIcon = ControlsUtils.deviceIcon($stateParams.oldBinding.device),
    vm.oldBinding.details = ControlsUtils.getBindingDetails($stateParams.oldBinding.device, $stateParams.oldBinding.control, $stateParams.action),
    vm.oldBinding.isAxis = ControlsUtils.isAxis($stateParams.oldBinding.device, $stateParams.oldBinding.control)
  }

  vm.newBinding = angular.copy(vm.oldBinding);

  vm.conflicts = [];
  vm.listening = {msg: '', status: 0};
  vm.showFfbOptions = $stateParams.showFfb || false;

  var getConflicts = function () {
    vm.conflicts = ControlsUtils.bindingConflicts(vm.newBinding.device, vm.newBinding.details.control, vm.action.actionName).map(function (x) {
      return {device: vm.newBinding.device, control: vm.newBinding.details.control, action: x.binding.action, description: controlsContents.actions[x.binding.action].desc, title: controlsContents.actions[x.binding.action].title, resolved: false };
    });
  };

  vm.bindingChanged = function () {
    return !angular.equals(vm.newBinding, vm.oldBinding);
  };

  vm.captureBinding = function () {
    $scope.$evalAsync(function () { vm.listening.status = -1; });

    listeningTimeout = setTimeout(function () {
      $scope.$evalAsync(function () { vm.listening.status = 1; });

      ControlsUtils.captureBinding().then(
      function (result) {
        $scope.$evalAsync(function () {
          vm.listening.status = 0;

          vm.newBinding.device = result.devName;
          vm.newBinding.deviceIcon = ControlsUtils.deviceIcon(result.devName);
          vm.newBinding.details = angular.merge({control: result.control}, controlsContents.bindingTemplate);
          vm.newBinding.isAxis = ControlsUtils.isAxis(result.devName, result.control);

          getConflicts();
        });
      }, function (error) {
        // EMPTY CALLBACK (no rejection)
      }, function (data) {
        $scope.$evalAsync(function () { vm.listening.msg = data.devName + ', ' + data.control; });
      });
    }, 300);
  };

  vm.deleteBinding = function () {
    ControlsUtils.removeBinding(vm.newBinding.device, vm.newBinding.details.control, vm.action.actionName);
    $state.go('^');
  };

  vm.cancel = function () {
    // $state.go('menu.options.controls.bindings');
  };

  vm.apply = function () {
    if (vm.oldBinding.device) {
      ControlsUtils.removeBinding(vm.oldBinding.device, vm.oldBinding.details.control, vm.action.actionName, vm.oldBinding.device == vm.newBinding.device);
    }

    vm.conflicts.map(function (x) {
      if (x.resolved) ControlsUtils.removeBinding(x.device, x.control, x.action, true);
    });

    ControlsUtils.addBinding(vm.newBinding.device, angular.merge({action: vm.action.actionName}, vm.newBinding.details));
  };

  vm.revert = function () {
    vm.newBinding = angular.copy(vm.oldBinding);
    getConflicts();
  };

  // ON START
  bngApi.engineLua('WinInput.setForwardRawEvents(true);');
  getConflicts();

  if (!vm.oldBinding.device) { vm.captureBinding(); }

  // ON END
  $scope.$on('$destroy', function () {
    bngApi.engineLua('WinInput.setForwardRawEvents(false);');
    clearTimeout(listeningTimeout);
  });
}])

.controller('ControlsFiltersCtrl', ['$scope', '$state', 'bngApi', 'ControlsUtils', 'mdx', 'UiUnits', function ($scope, $state, bngApi, ControlsUtils, mdx, UiUnits) {
  var vm = this;
  var settings = $scope.$parent.options;
  vm.order = [ 0, 3, 1, 2];
  vm.filters = {};
  vm.unit = UiUnits.buildString;

  var settingTypes = [ "limitEnabled", "limitStartSpeed", "limitEndSpeed", "limitMultiplier" ];
  $scope.$on('SettingsChanged', function (_, data) {
    $scope.$evalAsync(function () {
      var v = data.values;
      for (i in vm.order) {
        var filterId = vm.order[i];
        if (vm.filters[filterId] === undefined) {
          vm.filters[filterId] = {};
        }
        for(j in settingTypes) {
          var settingType = settingTypes[j];
          vm.filters[filterId][settingType] = v["inputFilter"+filterId+"_"+settingType];
        }
        // sanitize speeds
        if (vm.filters[filterId].limitStartSpeed > vm.filters[filterId].limitEndSpeed) {
          vm.filters[filterId].limitStartSpeed = vm.filters[filterId].limitEndSpeed;
          vm.filters[filterId].limitEndSpeed = v["inputFilter"+filterId+"_limitStartSpeed"];
        }
        vm.limitCurveRender(filterId);
      }
    });
  });
  vm.apply = function (filterId, sanitizeStart) {
    var v = settings.data.values;
    if (sanitizeStart ==  true) vm.filters[filterId].limitStartSpeed = Math.min(vm.filters[filterId].limitStartSpeed, vm.filters[filterId].limitEndSpeed);
    if (sanitizeStart == false) vm.filters[filterId].limitEndSpeed   = Math.max(vm.filters[filterId].limitStartSpeed, vm.filters[filterId].limitEndSpeed);
    for(j in settingTypes) {
      var settingType = settingTypes[j];
      v["inputFilter"+filterId+"_"+settingType] = vm.filters[filterId][settingType];
    }
    vm.limitCurveRender(filterId);
    settings.applyState(); // save values to settings
  };
  vm.limitCurveRender = function(filterId) {
    var canvas = document.querySelector("[id=inputFilter"+filterId+"_graph]");
    var width = canvas.width;
    var height = canvas.height;
    var ctx = canvas.getContext("2d");
    var lineWidth = 3;

    var accent     = "rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().accent    ][600].value.toString()+")"
    var accentLight= "rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().accent    ][200].value.toString()+")"
    var accentLight2="rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().accent    ][100].value.toString()+")"
    var primary    = "rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().primary   ][400].value.toString()+")"
    var primaryLight="rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().primary   ][100].value.toString()+")"
    var background = "rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().background][400].value.toString()+")"
    var warn       = "rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().warn      ][400].value.toString()+")"
    var white = "rgb("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().background][100].value.toString()+")"

    // redraw from scratch
    ctx.clearRect(0, 0, width, height);

    // grid lines
    ctx.strokeStyle=primaryLight;
    ctx.lineWidth=1;
    var vtcells = 4
    var hzcells = 10
    for(i=0; i<vtcells; i++) {
        ctx.beginPath();
        ctx.moveTo(    0, i*height/vtcells);
        ctx.lineTo(width, i*height/vtcells);
        ctx.stroke();
    }
    for(i=0; i<hzcells; i++) {
        ctx.beginPath();
        ctx.moveTo(i*width/hzcells, 0);
        ctx.lineTo(i*width/hzcells, height);
        ctx.stroke();
    }

    var start = vm.filters[filterId].limitStartSpeed
    var end = vm.filters[filterId].limitEndSpeed
    var mult = vm.filters[filterId].limitMultiplier

    // fill the graph area
    ctx.lineWidth=0;
    ctx.beginPath();
    ctx.moveTo(0,0); // top-left corner
    ctx.lineTo(start/100*width,0); // begin of slope
    ctx.lineTo(end/100*width, (1-mult)*height-1); // end of slope
    ctx.lineTo(width, (1-mult)*height-1); // right border
    ctx.lineTo(width,height); // bottom-right corner
    ctx.lineTo(0,height); // bottom-left corner
    ctx.fillStyle = accentLight2;
    ctx.closePath();
    ctx.fill();

    // end line
    ctx.lineWidth=2;
    ctx.strokeStyle=accentLight;
    ctx.beginPath();
      ctx.moveTo(end/100*width, 0);
      ctx.lineTo(end/100*width, height);
    ctx.stroke();

    // start line
    ctx.lineWidth=2;
    ctx.strokeStyle=accentLight;
    ctx.beginPath();
      ctx.moveTo(start/100*width, 0);
      ctx.lineTo(start/100*width, height);
    ctx.stroke();

    // draw main graph line
    ctx.strokeStyle=accent; // good for line, leave as is
    ctx.lineWidth=lineWidth;
    ctx.beginPath();
    ctx.moveTo(0,0); // top-left corner
    ctx.lineTo(start/100*width,0); // begin of slope
    ctx.lineTo(end/100*width, (1-mult)*height-1); // end of slope
    ctx.lineTo(width, (1-mult)*height-1); // right border
    ctx.stroke();

    // limit text
    ctx.strokeStyle=accent;
    var textHeight = 11;
    ctx.font = textHeight + "px sans-serif";
    ctx.fillStyle = accent;
    ctx.textAlign = "right";
    var textSeparationY = textHeight;
    var limitText = "limit: " + Math.round(100*mult) + "%";
    ctx.fillText(limitText, width, ((1-mult)*height-1)+(mult>=0.75?+1:-0.3)*textSeparationY);
  };
  bngApi.engineLua('settings.requestState()');
}])

/**
 * @ngdoc controller
 * @name beamng.stuff:ControlsFfbCtrl
 * @description [TODO: Add description]
 */
.controller('ControlsFfbCtrl', ['$state', 'ControlsUtils', function ($state, ControlsUtils) {
  var vm = this;
  var _bindingData = { device: '', deviceIcon: '', details: {}, isAxis: false };

  vm.ffbBound = ControlsUtils.isFfbBound();
  vm.ffbCapable = ControlsUtils.isFfbCapable();

  vm.select = function (action, device, control) {
    $state.go('menu.options.controls.ffb.edit', { action: action, oldBinding: {device: device, control: control, sel: angular.copy(_bindingData)}, showFfb: true });
  };
}])

/**
 * @ngdoc controller
 * @name beamng.stuff:ControlsHardwareCtrl
 * @description [TODO: Add description]
 */
.controller('ControlsHardwareCtrl', ['$scope', 'bngApi', 'controlsContents', 'ControlsUtils',
  function ($scope, bngApi, controlsContents, ControlsUtils) {
    var vm = this;
    vm.utils = ControlsUtils;

    vm.showAndroid = false;
    vm.qrData = null;
    vm.qrData2 = null;
    vm.remoteBlocked = false;
    vm.nDevices = Object.keys(controlsContents.controllers).length;

    bngApi.engineLua('core_remoteController.devicesConnected()', (bool) => {
      $scope.$evalAsync(() => {
        vm.showAndroid = bool;
      });
    });

    var firewallPollInterval;

    var pollFirewall = function () {
      bngApi.engineLua('be:isBlockedByFirewall()', function (blocked) {
        $scope.$evalAsync(function () { vm.remoteBlocked = blocked; });
      });
    };

    vm.androidToggled = function () {
      if (!vm.showAndroid) {
        clearInterval(firewallPollInterval);
        return;
      }
      firewallPollInterval = setInterval(pollFirewall, 1000);
      // todo: disable the controlers
    };

    bngApi.engineLua('core_remoteController.getQRCode()', function (data) {
      $scope.$evalAsync(function () {
        vm.qrData = data;
      });
    });

    bngApi.engineLua('core_remoteController.getQRCodeIOS()', function (data2) {
      $scope.$evalAsync(function () {
        vm.qrData2 = data2;
      });
    });

    vm.addFirewallException = function () {

    };

    bngApi.engineLua('WinInput.setForwardRawEvents(true);');

    $scope.$on('$destroy', function () {
      bngApi.engineLua('WinInput.setForwardRawEvents(false);');
      clearInterval(firewallPollInterval);
    });
}])


// http://home/redmine/issues/1338

.constant('ControlsWizardActions', {
  singleActions: [
    {action: 'accelerate',    direction: 1},
    {action: 'brake',         direction: -1},
    {action: 'steer_left',    direction: -1},
    {action: 'steer_right',   direction: 1},
    {action: 'recover_vehicle', direction: 0},
    {action: 'toggleMenues', direction: 0},
    {action: 'center_camera', direction: 0},
    {action: 'reset_physics', direction: 0}
    // {action: restart scenario, recover vehicle, reset camera, show dashboard
  ],

  combos: [
    {action: 'steering',         parts: ['steer_left', 'steer_right']},
    {action: 'accelerate_brake', parts: ['accelerate', 'brake']}
  ]
})
