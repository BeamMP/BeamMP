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
      var elOptions = element.options;
      var optionCount = 0;
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
            optionCount++;
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
      if(slot.coreSlot === undefined && optionCount > 0) {
        element.options.unshift({name: 'Empty', val: ''});
      } else {
        element.open = true;
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
        //var list = configs.map((elem) => elem.slice(0, -3));

        d.resolve(configs);
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
      });
    }
    bngApi.engineLua(`extensions.core_vehicle_partmgmt.highlightParts(${bngApi.serializeToLua(flattenedParts)})`);
  };

  $scope.$on('VehicleFocusChanged', function(event, data) {
    bngApi.engineLua('extensions.core_vehicle_partmgmt.sendDataToUI()');
  })

  $scope.$on('VehicleJbeamIoChanged', function(event, data) {
    bngApi.engineLua('extensions.core_vehicle_partmgmt.sendDataToUI()');
  })

  // LICENSE PLATE STUFF
  vm.licensePlate = '';

  bngApi.engineLua('core_vehicles.getVehicleLicenseText(be:getPlayerVehicle(0)', function (str) {
    $scope.$evalAsync(() => { vm.licensePlate = str; });
  });

  // --------------------------------------- BEAMMP --------------------------------------- //

  vm.isMPSession = false;
  bngApi.engineLua('MPCoreNetwork.isMPSession()', function (str) {
    $scope.$evalAsync(() => { vm.isMPSession = str; });
  });

  // --------------------------------------- BEAMMP --------------------------------------- //

  vm.updateLicensePlate = function () {
    bngApi.engineLua(`core_vehicles.setPlateText("${vm.licensePlate}")`);
  };
  vm.genLicensePlate = function () {
    bngApi.engineLua(`core_vehicles.setPlateText(nil,nil,nil,nil,true);`);

    bngApi.engineLua('core_vehicles.regenerateVehicleLicenseText(be:getPlayerVehicle(0)', function (str) {
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
  vm.applyPartChangesAutomatically = true;
  vm.simple = false;
  vm.partSearchString = '';
  vm.partSearchQuery = {};
  vm.searchMode = false;
  vm.searchResString = '';
  vm.searchResults = [];
  vm.partsChanged = false;

  vm.searchHistory = [];
  vm.searchHistoryPosition = 0;
  vm.searchHistoryBrowsing = false;

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

  vm.partConfigChanged = function(part) {
    if(!vm.applyPartChangesAutomatically) {
      // only mark as changed
      part.changed = true;
      vm.partsChanged = true;
      return;
    }
    vm.write();
  }

  vm.applySettingChanged = function() {
    localStorage.setItem('applyPartChangesAutomatically', JSON.stringify(vm.applyPartChangesAutomatically));
  }

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
  
  // --------------------------------------- BEAMMP --------------------------------------- //

  vm.mpapply = function () {
    console.log("[BeamMP] Attempting to send vehicle edits to all clients")
    bngApi.engineLua("MPVehicleGE.sendCustomVehicleData(be:getPlayerVehicle(0):getID())");
  }
  // --------------------------------------- BEAMMP --------------------------------------- //

  function calcTreesync (config) {
    if (init) {
      init = false;
      initConfig = config;
    }
    vm.partsChanged = false;
    //console.log("config = ", config)

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

    //console.log('tree = ', tree)
  }

  function calcTree (config) {
    //console.timeEnd('waitingForLua')

    $scope.$evalAsync(function () {
      calcTreesync(config)
      //console.log("tree = ", vm.d.data)
      filterTree();
    });
  }

  var queryModes = {
    "or": function(a, b) { return a || b; },
    "and": function(a, b) { return a && b; },
  }

  // applies filters against mod info
  function filterPartByName(partName, queryArgs) {
    var part = initConfig.availableParts[partName]
    if(!part) return

    var modMatch = false;
    if(queryArgs['mod'] !== undefined) {
      if(part.modName !== undefined)    modMatch = modMatch || part.modName.toLowerCase().indexOf(queryArgs['mod']) != -1
      if(part.modTagLine !== undefined) modMatch = modMatch || part.modTagLine.toLowerCase().indexOf(queryArgs['mod']) != -1
      if(part.modTitle !== undefined)   modMatch = modMatch || part.modTitle.toLowerCase().indexOf(queryArgs['mod']) != -1
    }

    if(queryArgs['author'] !== undefined) {
      if(part.modName !== undefined)    modMatch = modMatch || part.authors.toLowerCase().indexOf(queryArgs['author']) != -1
    }

    return modMatch
  }

  function filterTreeNode(searchResults, treeNode, queryArgs) {

    // match this part first
    var matched = false;
    if(queryArgs['mode'] == 'or') matched = false;
    else if(queryArgs['mode'] == 'and') matched = true;

    if(queryArgs['name'] && treeNode.name !== undefined) matched = queryModes[queryArgs['mode']](matched, treeNode.name.toLowerCase().indexOf(queryArgs['name']) != -1);
    if(queryArgs['slot'] && treeNode.slot !== undefined) matched = queryModes[queryArgs['mode']](matched, treeNode.slot.toLowerCase().indexOf(queryArgs['slot']) != -1);
    //if(!matched && treeNode.slot !== undefined) matched = matched || treeNode.slot.toLowerCase().indexOf(queryArgs) != -1;
    if(queryArgs['name'] && !matched) {
      for (var optIdx in treeNode.options) {
        var option = treeNode.options[optIdx];
        if(option.name !== undefined) matched = queryModes[queryArgs['mode']](matched, option.name.toLowerCase().indexOf(queryArgs['name']) != -1);
      }
    }
    if(queryArgs['partname'] && !matched) {
      for (var optIdx in treeNode.options) {
        var option = treeNode.options[optIdx];
        if(option.val !== undefined) matched = queryModes[queryArgs['mode']](matched, option.val.toLowerCase().indexOf(queryArgs['partname']) != -1);
      }
    }

    // mod filters
    if(queryArgs['mod'] || queryArgs['author']) {
      filterPartByName(treeNode.val, queryArgs)
      for (var optIdx in treeNode.options) {
        var option = treeNode.options[optIdx];
        if(option.val !== undefined) {
          matched = queryModes[queryArgs['mode']](matched,
            filterPartByName(option.val, queryArgs)
          );
        }
      }
    }

    if(matched) searchResults.push(treeNode)

    // match child parts
    for (var partIdx in treeNode.parts) {
      filterTreeNode(searchResults, treeNode.parts[partIdx], queryArgs);
    }
  }

  function saveSearchHistory() {
    localStorage.setItem('partSearchHistory', JSON.stringify(vm.searchHistory));
  }

  function loadSearchHistory() {
    var res = localStorage.getItem('partSearchHistory')
    if(res !== null) {
      vm.searchHistory = JSON.parse(res) || [];
    }
  }

  function filterTree() {
    var queryString = vm.partSearchString.toLowerCase()
    var queryArgs = {}
    queryArgs['mode'] = 'or';
    vm.searchResString = '';

    // default: search all
    if (queryString.indexOf(':') == -1) {
      queryArgs['name'] = queryString;
    } else {
      var parsedargs = 0;
      var args = queryString.split(/[ ,]+/);
      for(i = 0; i < args.length; i++) {
        if (args[i].indexOf(':') != -1) {
          var args2 = args[i].split(/:/);
          if(args2.length == 2 && args2[1].trim() != '') {
            queryArgs[args2[0]] = args2[1]
            parsedargs++;
          } else {
            vm.searchResString += 'invalid search format: ' + args[i] + '\n';
          }
        } else {
          vm.searchResString += 'unknown search argument: ' + args[i] + '\n';
        }
      }
      if(parsedargs > 1) queryArgs['mode'] = 'and';
    }

    vm.searchResults = [];
    if(queryString != '' && queryString.length < 3) {
      vm.searchResString = "Search term too short";
      return;
    }
    vm.partSearchQuery = queryArgs

    // add to search history
    if (queryString.trim() !== '' && !vm.searchHistoryBrowsing) {
      var lastHistory = vm.searchHistory[vm.searchHistory.length - 1] || ""
      if(queryString.indexOf(lastHistory) != -1) {
        vm.searchHistory[vm.searchHistory.length - 1] = queryString
      } else if(lastHistory.indexOf(queryString) != -1) {
        // removing chars do not change the last item
      } else {
        vm.searchHistory.push(queryString);
      }
      saveSearchHistory();
      //console.log("Search history: ", vm.searchHistory)
    }


    //console.log("queryArgs = ", queryArgs)

    for (var partIdx in vm.d.data) {
      var part = vm.d.data[partIdx];
      filterTreeNode(vm.searchResults, part, queryArgs);
    }
    if(vm.searchResults.length == 0) {
      vm.searchResString = "No results found";
    }
    //console.log("> searchResults: ", vm.searchResults);
  }

  vm.recalcTree = function () {
    calcTree(initConfig);
  };
  vm.startSearch = function() {
    vm.searchMode = true;
  };
  vm.stopSearch = function() {
    vm.searchMode = false;
    vm.partSearchString = '';
    vm.partSearchQuery = {}
    vm.searchResults = [];
  };

  vm.onKeyDown = function(event) {
    //console.log("Search onKeyDown: ", event)
    if(vm.searchHistory.length > 0 && event.key == "ArrowDown") {
      vm.searchHistoryBrowsing = true;
      vm.searchHistoryPosition++;
      if(vm.searchHistoryPosition >= vm.searchHistory.length) vm.searchHistoryPosition = 0;
      vm.partSearchString = vm.searchHistory[vm.searchHistoryPosition]
      filterTree();
      event.preventDefault();

    } else if(vm.searchHistory.length > 0 && event.key == "ArrowUp") {
      vm.searchHistoryBrowsing = true;
      vm.searchHistoryPosition--;
      if(vm.searchHistoryPosition < 0) vm.searchHistoryPosition = vm.searchHistory.length - 1;
      vm.partSearchString = vm.searchHistory[vm.searchHistoryPosition]
      filterTree();
      event.preventDefault();

    } else if(event.key == "k" && event.ctrlKey == true) {
      console.log("Search history cleaned");
      localStorage.removeItem('partSearchHistory')
      vm.searchHistory = [];
      vm.searchHistoryPosition = 0;
      vm.searchHistoryBrowsing = false;
      event.preventDefault();

    } else {
      vm.searchHistoryBrowsing = false;
    }
  }

  vm.filterChanged = function() {
    filterTree();
  };
  $scope.$on('VehicleConfigChange', (event, config) => calcTree(config));

  $scope.$on('$destroy', () => {
    vm.deselectPart(false);
  });

  // Initial data load
  bngApi.engineLua('extensions.core_vehicle_partmgmt.sendDataToUI()');
  loadSearchHistory();

  var applyPartChangesAutomatically = localStorage.getItem('applyPartChangesAutomatically')
  if(applyPartChangesAutomatically !== null) {
    vm.applyPartChangesAutomatically = JSON.parse(applyPartChangesAutomatically) || false;
  }
}])
.filter('highlightResults', function($sce) {
  return function(text, search) {
    if (!search) {
      return $sce.trustAsHtml(text);
    }
    return $sce.trustAsHtml(unescape(escape(text).replace(new RegExp(escape(search), 'gi'), ' <span class="highlightResults">$&</span>')));
  }
})
.controller('Vehicleconfig_tuning', ["logger", "RateLimiter", "VehicleConfig", "bngApi", "$scope", "$filter", function (logger,RateLimiter, VehicleConfig, bngApi, $scope, $filter) {
  var vm = this;

  vm.open = {};
  vm.openRuntime = {};
  vm.d = {};
  vm.liveVariablesUpdate = false;

  // --------------------------------------- BEAMMP --------------------------------------- //


  vm.isMPSession = false;
  bngApi.engineLua('MPCoreNetwork.isMPSession()', function (str) {
    $scope.$evalAsync(() => { vm.isMPSession = str; });
  });

  // --------------------------------------- BEAMMP --------------------------------------- //


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

.controller('Vehicleconfig_save', ["$scope", "$mdDialog", "VehicleConfig", "bngApi", function ($scope, $mdDialog, VehicleConfig, bngApi) {
  var vm = this;
  vm.saveThumbnail = true;

  vm.openConfigFolderInExplorer = function(){
    bngApi.engineLua('extensions.core_vehicle_partmgmt.openConfigFolderInExplorer()');
  }

  vm.save = function (configName) {
    bngApi.engineLua(`extensions.core_vehicle_partmgmt.saveLocal("${configName}.pc")`);
    //bngApi.engineLua(`MPVehicleGE.saveConfigRequest("${configName}.pc")`);

    if (vm.saveThumbnail == true) {
      $scope.$emit('hide_ui', true);
      // This function starts a chain to hide the UI, set up the camera and take a screenshot.
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

  vm.remove = function ($event, config) {

    loadedConfig = config;
    bngApi.engineLua(`extensions.core_vehicle_partmgmt.removeLocal("${config}")`);
    getConfigList();
    $event.stopPropagation();


    // showConfirm()
    // // Confirmation dialog when deleting configuration
    // var confirm;
    // function showConfirm() {
    //   confirm = $mdDialog.confirm({
    //     title: "Are you sure?",
    //     content: "This will permanently remove the configuration. You will not be able to recover it.",
    //     ok: "Delete permanently",
    //     cancel: "Cancel"
    //   });
    //   $mdDialog
    //     .show(confirm).then(
    //       function() { removeConfig() },
    //       function() { }
    //   );
    // }

    // function removeConfig () {
    //   loadedConfig = config;
    //   bngApi.engineLua(`extensions.core_vehicle_partmgmt.removeLocal("${config}")`);
    //   getConfigList();
    //   $event.stopPropagation();
    // }
  };

  vm.configExists = function(name) {
    for(var i = 0; i<vm.configList.length; i++) {
      if(vm.configList[i].name === name)
        return true;
    }
    return false;
  }

  function getConfigList () {
    VehicleConfig.loadConfigList().then((list) => {
      vm.configList = list;
    });
  }

  $scope.$on('VehicleChange', getConfigList);
  $scope.$on('VehicleconfigSaved', getConfigList);
  getConfigList();

}])
