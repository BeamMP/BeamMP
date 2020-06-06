angular.module('beamng.stuff')

/**
 * @ngdoc service
 * @name beamng.stuff:VehicleConfig
 *
 * @description
 * Helper functions for editing a vehicle's configuration
 */
.factory('VehicleConfig', ['logger', '$q', 'bngApi', 'Utils', function (logger, $q, bngApi, Utils) {
  var prefix = '';

  var _generateTreeBranch = function (d, des, simple, depth) {
    var res = [];
    depth = depth || 0;

    for (var child in d) {
      var slot = d[child];
      var element = {
        name: des[child].replace(prefix, ''),
        slot: slot[0].partType,
        val: '',
        options: [],
        highlight: true
      };
      if(slot[0].coreSlot === undefined) {
        element.options.push({name: 'Empty', val: ''});
      } else {
        element.open = true;
      }

      var help = element.options;
      for (var item=0; item<slot.length; item++) {
        help[help.length] = {
          name: slot[item].name.replace('prefix', ''),
          val: slot[item].partName
        };
        if (slot[item].active) {
          element.val = slot[item].partName;
          if (slot[item].parts)
            element.parts = _generateTreeBranch(slot[item].parts, des, simple, depth + 1);
          if (simple && element.parts !== undefined && element.parts.length === 0)
            delete element.parts;
        }
      }
      if (!simple || element.options.length > 2 || (element.options.length > 1 && element.options[0].val !== '') || depth < 1) {
        res.push(element);
      }
    }
    return res;
  };

  var _getPrefix = function (des) {
    var strings = [];

    Object.keys(des).map(function (x) { strings.push(des[x]); });

    var max = Math.max.apply(null, strings.map(function (x) { return x.length; }));

    for (var i=0; i<max; i++) {
      for (var key in des) {
        if (des[key].indexOf(prefix) !== 0) {
          return strings[0].substring(0, (i-2));
        }
      }
      prefix = strings[0].substring(0, i);
    }
    return '';
  };

  return {
    get prefix () {
      return prefix;
    },

    generateTree: function (data, simple) {
      prefix = _getPrefix(data.slotDescriptions);
      return _generateTreeBranch(data.slotMap, data.slotDescriptions, simple);
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

      bngApi.activeObjectLua('partmgmt.getConfigList()', (configs) => {
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
    bngApi.activeObjectLua(`partmgmt.highlightParts(${bngApi.serializeToLua(flattenedParts)})`);
  };

  $scope.$on('VehicleFocusChanged', function(event, data) {
    bngApi.activeObjectLua('partmgmt.vehicleResetted()');
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
    bngApi.activeObjectLua(`partmgmt.selectPart("${element}", ${vm.selectSubParts})`);
  };

  vm.deselectPart = function (sticky) {
    var flattenedParts = [];
    if (vm.d.data.length > 0) {
      for (var key in vm.d.data) {
        processPart(vm.d.data[key], function(obj) {
          flattenedParts.push(obj);
        })
      }
      logger.vehicleconfig.debug(`Reset part selection`);
      // bngApi.activeObjectLua('partmgmt.selectReset()');
      bngApi.activeObjectLua(`partmgmt.highlightParts(${bngApi.serializeToLua(flattenedParts)})`);
    }
  };


  vm.write = function () {
    var newConfig = VehicleConfig.generateConfig(vm.d.data);
    logger.vehicleconfig.debug(`Setting configuration`, newConfig);
    setTimeout(() => {
      // make async so html has more time to update render parts
      bngApi.activeObjectLua(`partmgmt.setPartsConfig(${bngApi.serializeToLua(newConfig)})`);
    });
    console.time('waitingForLua')
  };

  vm.reset = function () {
    if (loadedConfig && typeof(loadedConfig) == 'string') {
      logger.vehicleconfig.debug(`Resetting to loaded configuration`, data);
      vm.load(loadedConfig);
    } else {
      bngApi.activeObjectLua(`partmgmt.setPartsConfig(${bngApi.serializeToLua(initConfig)})`);
    }
  };

  vm.mpapply = function () {
    console.log("[BeamMP] Attempting to send vehicle edits to all clients")
    bngApi.activeObjectLua("obj:queueGameEngineLua(\"vehicleGE.sendCustomVehicleData('\"..obj:getID()..\"', '\"..jsonEncode(partmgmt.state.config)..\"')\")");
  }

  function calcTree (config) {
    console.timeEnd('waitingForLua')

    $scope.$evalAsync(function () {
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
    });
  }


  vm.recalcTree = function () {
    calcTree(initConfig);
  };

  $scope.$on('VehicleconfigChange', (event, config) => calcTree(config));


  $scope.$on('$destroy', () => {
    vm.deselectPart(false);
  });

  // Initial data load
  bngApi.activeObjectLua('partmgmt.vehicleResetted()');

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
      bngApi.activeObjectLua(`partmgmt.setConfigVars(${bngApi.serializeToLua(vars)})`);
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

  bngApi.activeObjectLua('partmgmt.vehicleResetted()');

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

  $scope.$on('VehicleconfigChange', (event, config) => calcTree(config));
}])

.controller('Vehicleconfig_color', ["$scope", "bngApi", function ($scope, bngApi) {
  var vm = this;
  vm.updateColor = function (index, value) {
     console.log( `setVehicleColorPalette(${index-1}, "${value}");` );
     console.log('setVehicleColorPalette(' + (index-1) + ',"' + value + '");')
     console.log( `changeVehicleColor("${value}");` );
     console.log('changeVehicleColor("' + value  + '");');

    if (index === 0) {
      bngApi.engineScript(`changeVehicleColor("${value}");`);
    } else {
      bngApi.engineScript(`setVehicleColorPalette(${index-1}, "${value}");`);
    }
  };

  function fetchDefinedColors () {
    vm.color = ['White', 'White', 'White'];

    bngApi.engineLua('getVehicleColor()', (res) => {
      vm.color[0] = res || vm.color[0];
    });

    for (var i=1; i<vm.color.length; i++) {
      // yes this is needed, since otherwise we crate a function inside the for loop and thanks to clojure i would always be 4
      bngApi.engineScript(`getVehicleColorPalette(${i-1});`, ((id) =>
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
    bngApi.activeObjectLua(`partmgmt.saveLocal("${configName}.pc")`);
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
    bngApi.activeObjectLua(`partmgmt.loadLocal("${config}.pc")`);
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
