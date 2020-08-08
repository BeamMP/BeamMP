angular.module('beamng.stuff')

/**
 * @ngdoc service
 * @name beamng.stuff:VehicleConfig
 *
 * @description
 * Helper functions for editing a vehicle's configuration
 */
.factory('VehicleConfig', ['logger', '$q', 'bngApi', 'Utils', function (logger, $q, bngApi, Utils) {
  var _generateTreeBranch = function (data, part, simple, depth) {
    var res = [];
    if(depth>200) return;

    for (var slotType in part.slots) {
      var slot = part.slots[slotType];
      var element = {
        name: slot.description,
        slot: slotType,
        val: '',
        options: [],
        highlight: true
      };
      if(slot.coreSlot === undefined) {
        element.options.push({name: 'Empty', val: ''});
      } else {
        element.open = true;
      }

      var elOptions = element.options;
      if(data.slotMap[slotType] !== undefined) {
        for (var i=0; i < data.slotMap[slotType].length; i++) {
          var slotPartName = data.slotMap[slotType][i]
          var slotPart = data.availableParts[slotPartName]
          if(slotPart === undefined) {
            console.error('slot part not found: ', slotPartName)
          } else {
            elOptions[elOptions.length] = {
              name: slotPart.description,
              val: slotPartName
            };
            if (data.chosenParts[slotType] == slotPartName) {
              element.val = slotPartName;
              if (slotPart.slots)
                element.parts = _generateTreeBranch(data, slotPart, simple, depth + 1);
              if (simple && element.parts !== undefined && element.parts.length === 0)
                delete element.parts;
            }
          }
        }
      }
      if (!simple || element.options.length > 2 || (element.options.length > 1 && element.options[0].val !== '') || depth < 1) {
        res.push(element);
      }
    }
    return res;
  };


  return {
    generateTree: function (data, simple) {
      return _generateTreeBranch(data, data.availableParts[data.mainPartName], simple);
    },

    generateConfig: function (d, res) {
      res = res || {};
      if (!d) return res;

      d.map((x) => {
        res[x.slot] = x.val;
        if (x.parts) this.generateConfig(x.parts, res);
      });

      return res;
    },

    varValToDisVal: function (v) {
      var vData = (v.val - v.min) / (v.max - v.min); //lua ratio
      return Utils.roundDec( Utils.round(vData * (v.maxDis - v.minDis), v.stepDis) + v.minDis, v.stepDis.countDecimals() );
    },

    getVariablesConfig: function (variables) {
      var configObj = {};
      for (var i in variables) {
        var v = variables[i];
        var vDis = (v.valDis - v.minDis) / (v.maxDis - v.minDis);
        v.val = Utils.roundDec( Utils.round(vDis * (v.max - v.min), v.step) + v.min, v.step.countDecimals() );
        configObj[v.name] = v.val;
      }
      return configObj;
    },

    loadConfigList: function () {
      var d = $q.defer();

      bngApi.engineLua('extensions.core_vehicle_partmgmt.getConfigList()', (configs) => {
        var list = configs.map((elem) => elem.slice(0, -3));
        d.resolve(list);
      });

      return d.promise;
    },

    treeSort: function _treeSort_ (a, b) {
      if (a.parts) {
        a.parts.sort(_treeSort_);
        if (!b.parts) return 1;
      }

      if (b.parts) {
        b.parts.sort(_treeSort_);
        if (!a.parts) return -1;
      }

      return a.slot.localeCompare(b.slot);
    }
  };

  // return service;
}])

.controller('VehicleconfigCtrl', ['$scope', '$state', function ($scope, $state) {
  var tabs = ['menu.vehicleconfig.parts', 'menu.vehicleconfig.tuning', 'menu.vehicleconfig.color', 'menu.vehicleconfig.save'];
  var current = tabs.indexOf($state.current.name);
  $scope.model = {selected: current === -1 ? 0 : current };
}])
/**
 * @ngdoc controller
 * @name beamng.stuff:Vehicleconfig_config
 * @description The controller for the Vehicle Config entry. It handles all tabs in the view.
 * @require logger
 * @require $scope
 * @require beamng.stuff:bngApi
 * @require beamng.stuff:VehicleConfig
**/
.controller('Vehicleconfig_parts', ['$filter', 'logger', '$scope', '$window', 'bngApi', 'RateLimiter', 'VehicleConfig', 'StreamsManager',
function ($filter, logger, $scope, $window, bngApi, RateLimiter, VehicleConfig, StreamsManager) {
  var vm = this;

  // Multi Part Highlighting

  // function used to flatten objects
  function processPart (obj, func) {
    func(obj);
    if (obj.parts) {
      obj.parts.forEach(function (parts) {
        processPart(parts, func);
      });
    }
  }

  vm.highlightParts = function(selectedPart) {
    processPart(selectedPart, function (obj) {
      obj.highlight = selectedPart.highlight;
    });

    var flattenedParts = [];
    for (var key in vm.d.data) {
      processPart(vm.d.data[key], function(obj) {
        flattenedParts.push(obj);
      })
    }
    bngApi.engineLua(`extensions.core_vehicle_partmgmt.highlightParts(${bngApi.serializeToLua(flattenedParts)})`);
  };

  $scope.$on('VehicleFocusChanged', function(event, data) {
    bngApi.engineLua('extensions.core_vehicle_partmgmt.sendDataToUI()');
  })

  // LICENSE PLATE STUFF
  vm.licensePlate = '';

  bngApi.engineLua('core_vehicles.getVehicleLicenseName()', function (str) {
    $scope.$evalAsync(() => { vm.licensePlate = str; });
  });

  vm.updateLicensePlate = function () {
    bngApi.engineLua(`core_vehicles.setPlateText("${vm.licensePlate}")`);
  };
  vm.genLicensePlate = function () {
    bngApi.engineLua(`core_vehicles.setPlateText(nil,nil,nil,nil,true);`);

    bngApi.engineLua('core_vehicles.getVehicleLicenseName()', function (str) {
      $scope.$evalAsync(() => { vm.licensePlate = str; });
    });
  };
  // --------------

  vm.stopPropagation = function(event) {
    event.stopPropagation();
  };

  vm.open = {};
  vm.d = {};
  vm.stickyPartSelection = false;
  vm.selectSubParts = true;
  vm.simple = false;

  var initConfig = null
    , loadedConfig = null
    , init = true
  ;


  vm.emptyFront = function (option) {
    if (option.name === 'Empty') {
      return 0;
    }
  };

  vm.selectPart = function (event, element) {
    event.stopPropagation();
    logger.vehicleconfig.debug(`Selecting part ${element} (subparts: ${vm.selectSubParts})`);
    bngApi.engineLua(`extensions.core_vehicle_partmgmt.selectPart("${element}", ${vm.selectSubParts})`);
  };

  vm.deselectPart = function (sticky) {
    var flattenedParts = [];
    if (vm.d && vm.d.data.length > 0) {
      for (var key in vm.d.data) {
        processPart(vm.d.data[key], function(obj) {
          flattenedParts.push(obj);
        })
      }
      logger.vehicleconfig.debug(`Reset part selection`);
      // bngApi.engineLua('extensions.core_vehicle_partmgmt.selectReset()');
      bngApi.engineLua(`extensions.core_vehicle_partmgmt.highlightParts(${bngApi.serializeToLua(flattenedParts)})`);
    }
  };


  vm.write = function () {
    var newConfig = VehicleConfig.generateConfig(vm.d.data);
    logger.vehicleconfig.debug(`Setting configuration`, newConfig);
    setTimeout(() => {
      // make async so html has more time to update render parts
      bngApi.engineLua(`extensions.core_vehicle_partmgmt.setPartsConfig(${bngApi.serializeToLua(newConfig)})`);
    });
    //console.time('waitingForLua')
  };

  vm.reset = function () {
    if (loadedConfig && typeof(loadedConfig) == 'string') {
      logger.vehicleconfig.debug(`Resetting to loaded configuration`, data);
      vm.load(loadedConfig);
    } else {
      $scope.$evalAsync(function () {
        calcTreesync(initConfig)
        var newConfig = VehicleConfig.generateConfig(vm.d.data);
        bngApi.engineLua(`extensions.core_vehicle_partmgmt.setPartsConfig(${bngApi.serializeToLua(newConfig)})`);
      })
    }
  };

  vm.mpapply = function () {
    console.log("[BeamMP] Attempting to send vehicle edits to all clients")
    bngApi.activeObjectLua("obj:queueGameEngineLua(\"vehicleGE.sendCustomVehicleData('\"..obj:getID()..\"', '\"..jsonEncode(v.config)..\"')\")");
  }

  function calcTreesync (config) {
    if (init) {
      init = false;
      initConfig = config;
    }

    var tree = VehicleConfig.generateTree(config, vm.simple);
    tree.sort(VehicleConfig.treeSort);
    var configArray = [];
    var variable_categories = {};

    for (var o in config.variables) {
      var v = config.variables[o];
      if (!variable_categories[v.category])
        variable_categories[v.category] = true;
      v.valDis = VehicleConfig.varValToDisVal(v);
      configArray.push(v);
    }
    // console.table(configArray)

    vm.d.data = tree;
    vm.d.variables = $filter('orderBy')(configArray, 'name');
    vm.d.variable_categories = Object.keys(variable_categories);
    // loadOpenSlots();
  }

  function calcTree (config) {
    //console.timeEnd('waitingForLua')

    $scope.$evalAsync(function () {
      calcTreesync(config)
    });
  }


  vm.recalcTree = function () {
    calcTree(initConfig);
  };

  $scope.$on('VehicleConfigChange', (event, config) => calcTree(config));


  $scope.$on('$destroy', () => {
    vm.deselectPart(false);
  });

  // Initial data load
  bngApi.engineLua('extensions.core_vehicle_partmgmt.sendDataToUI()');

}])

.controller('Vehicleconfig_tuning', ["logger", "RateLimiter", "VehicleConfig", "bngApi", "$scope", "$filter", function (logger,RateLimiter, VehicleConfig, bngApi, $scope, $filter) {
  var vm = this;

  vm.open = {};
  vm.openRuntime = {};
  vm.d = {};
  vm.liveVariablesUpdate = false;

  var autoUpdateVariables = RateLimiter.debounce(() => {
    logger.vehicleconfig.debug(`Writing vehicle configuration (live update)`);
    vm.write();
  }, 200);

  vm.addSpacer = (function () {
    var lastCategory;
    return (cat) => {
      var res = cat !== lastCategory;
      lastCategory = cat;
      return res;
    }
  })();

  vm.write = function () {
    setTimeout(() => {
      // make async so html has more time to update render parts
      var vars = VehicleConfig.getVariablesConfig(vm.d.variables);
      bngApi.engineLua(`extensions.core_vehicle_partmgmt.setConfigVars(${bngApi.serializeToLua(vars)})`);
    });
  };

  vm.tuningVariablesChanged = function () {
    if (vm.liveVariablesUpdate)
      autoUpdateVariables();
  };

  vm.resetVars = function () {
    vm.d.variables.forEach((x) => {
      x.val = x.default;
      x.valDis = VehicleConfig.varValToDisVal(x);
    });
    vm.tuningVariablesChanged(); // got to call this, since the change didn't come from the inputs.
  };

  bngApi.engineLua('extensions.core_vehicle_partmgmt.sendDataToUI()');

  function calcTree (config) {
    $scope.$evalAsync(function () {
      var configArray = [];
      var variable_categories = {};

      for (var o in config.variables) {
        var v = config.variables[o];
        if (!variable_categories[v.category])
          variable_categories[v.category] = true;
        v.valDis = VehicleConfig.varValToDisVal(v);
        configArray.push(v);
      }
      // console.table(configArray)

      vm.d.variables = $filter('orderBy')(configArray, 'name');
      vm.d.variable_categories = Object.keys(variable_categories);
      // loadOpenSlots();
    });
  }

  $scope.$on('VehicleConfigChange', (event, config) => calcTree(config));
}])

.controller('Vehicleconfig_color', ["$scope", "bngApi", function ($scope, bngApi) {
  var vm = this;
  vm.updateColor = function (index, value) {
    bngApi.engineLua(`core_vehicle_colors.setVehicleColor(${index}, "${value}");`);
  };

  function fetchDefinedColors () {
    vm.color = ['White', 'White', 'White'];

    bngApi.engineLua('getVehicleColor()', (res) => {
      vm.color[0] = res || vm.color[0];
    });

    for (var i=1; i<vm.color.length; i++) {
      // yes this is needed, since otherwise we crate a function inside the for loop and thanks to clojure i would always be 4
      bngApi.engineLua(`getVehicleColorPalette(${i-1})`, ((id) =>
        (res) => {
          vm.color[id] = res || vm.color[id];
        }
      )(i));
    }
  }

  vm.carColorPresets = {};

  function getVehicleColors () {
    bngApi.engineLua('core_vehicles.getCurrentVehicleDetails()', (data) => {
      if (data.model !== undefined && data.model.colors !== undefined) {
        $scope.$evalAsync(() => {
          vm.carColorPresets = data.model.colors;
        });
      }
    });
  }

  getVehicleColors();
  fetchDefinedColors();

  $scope.$on('VehicleChange', getVehicleColors);
  $scope.$on('VehicleChangeColor', fetchDefinedColors);
}])

.controller('Vehicleconfig_save', ["$scope", "VehicleConfig", "bngApi", function ($scope, VehicleConfig, bngApi) {
  var vm = this;

  vm.save = function (configName) {
    bngApi.engineLua(`extensions.core_vehicle_partmgmt.saveLocal("${configName}.pc")`);

    $scope.$emit('hide_ui', true);

    // This function starts a chain to hide the UI, set up the camera and take a screenshot.
    // This is done in such way to be able to queue the commands, so that are being executed in the correct order
    // Taking advantage of the small delay that occurs when queueing commands from JS to LUA and viceversa
    // This helps avoid timing issue with the UI, which could be visible in the thumbnail.
    // Every step that needs to be run precisely after another is separated into its own stage.
    // See lua/ge/extensions/core/vehicles/partmgmt.lua

    setTimeout(function() { bngApi.engineLua(`extensions.core_vehicle_partmgmt.saveLocalScreenshot("${configName}.pc")`); }, 100);

    // Stage 1
    $scope.$on('saveLocalScreenshot_stage1', function () {
      // Stage 2 (Screenshot - LUA)
      bngApi.engineLua(`extensions.core_vehicle_partmgmt.saveLocalScreenshot_stage2("${configName}")`);
    });

    // Stage 3 (Reset)
    $scope.$on('saveLocalScreenshot_stage3', function () {
      bngApi.engineLua(`setCameraFov(60)`);
      bngApi.engineLua(`commands.setGameCamera()`);
      $scope.$emit('hide_ui', false);
    });
  };

  /**
   * @ngdoc method
   * @name load
   * @methodOf beamng.stuff:VehicleconfigController
   *
   * @description
   * Loads an available configuration from a file.
   */
  vm.load = function ($event, config) {
    loadedConfig = config;
    bngApi.engineLua(`extensions.core_vehicle_partmgmt.loadLocal("${config}.pc")`);
    $event.stopPropagation();
  };

  function getConfigList () {
    VehicleConfig.loadConfigList().then((list) => {
      vm.configList = list;
    });
  }

  $scope.$on('VehicleChange', getConfigList);
  $scope.$on('VehicleconfigSaved', getConfigList);
  getConfigList();

}])
