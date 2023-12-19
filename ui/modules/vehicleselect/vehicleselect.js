angular.module('beamng.stuff')

.value('VehiclePrefs', {
  filters: {},
  showConfigurations: false,
  query: ''
})

.value('VehicleOpenTab', {
  nr: 0
})

.value('VehicleSelectOptions', {
  showAuxiliary: !beamng.shipping
})

.service('VehicleSelectConfig', ['Vehicles', '$state', '$rootScope', function (Vehicles, $state, $rootScope) {
  var configs = {
    default: {
      hide: {},
      selected: (carObj, model, config, color, spawnNew, protected) => {
        Vehicles.addToGame(model, config, color, spawnNew, protected)
        $state.go('play')
      },
      parentState: 'menu',
      name: 'default',
      filter: {}
    }
  }

  return {
    get configs () {return configs},
    addConfig: (name, c) => {
      if (name !== undefined && name !== 'default') {
        configs[name] = c
      }
    }
  }
}])

/**
 * @ngdoc service
 * @name  beamng.stuff:Vehicles
 * @requires $q
 * @requires $rootScope
 * @requires $timeout
 * @requires beamng.stuff:bngApi
 *
 * @description Handles all vehicles-related stuff
**/
.service('Vehicles', ['$q', '$rootScope', '$timeout', 'Utils',
  function ($q, $rootScope, $timeout, Utils) {
    'use strict'

    function updateFilters (vehicles) {
      if (vehicles.origFilters !== undefined && vehicles.displayInfo !== undefined) {
        var res = {}

        for (var key in vehicles.origFilters) {
          if (vehicles.displayInfo.units[key] !== undefined) {
            if (vehicles.displayInfo.ranges.all.includes(key)) {
              res[key] = {
                min: Utils.roundDec(UiUnits[vehicles.displayInfo.units[key].type](vehicles.origFilters[key].min).val, vehicles.displayInfo.units[key].dec),
                max: Utils.roundDec(UiUnits[vehicles.displayInfo.units[key].type](vehicles.origFilters[key].max).val, vehicles.displayInfo.units[key].dec)
              }
            } else {
              res[key] = {}
              for (var val in vehicles.origFilters[key]) {
                res[Utils.roundDec(UiUnits[vehicles.displayInfo.units[key].type](Number(vehicles.origFilters[key][val])).val, vehicles.displayInfo.units[key].dec).toString()] = true
              }
            }
          } else {
            res[key] = vehicles.origFilters[key]
          }
          if (!vehicles.displayInfo.ranges.all.includes(key)) {
            res[key]['...'] = true
          }
        }
        return res
      } else {
        return vehicles.origFilters
      }
    }

    function considerUnit (key, val, str, units) {
      var res = {}
      if (key !== undefined) {
        var unit = (units !== undefined ? units : vehiclesData.displayInfo.units[key])
        var preUnit = vehiclesData.displayInfo.predefinedUnits[key]
        if (unit !== undefined) {
          if (str) {
            res = {val: UiUnits.buildString(unit.type, val, unit.dec),}
          } else {
            var help = UiUnits[unit.type](val)
            res = {
              unit: help.unit,
              val: Utils.roundDec(help.val, unit.dec)
            }

          }
        } else if (preUnit !== undefined) {
          res = {
            unit: preUnit.unit,
            val: Utils.roundDecStr(val, preUnit.dec)
          }
          if (str) {
            res = {val: `${res.val} ${res.unit}`}
          }
        } else {
          res = {val: val}
        }
      } else {
        res = {val: 'Unknown'}
      }

      if (str) {
        return res.val
      } else {
        return res
      }
    }

    // just as a test, needs rework (like only update on uiUnitsChange)
    $rootScope.$on('SettingsChanged', function () {
      if (vehiclesData) {
        vehiclesData.filters = updateFilters(vehiclesData)
      }
    })

    $rootScope.$on('sendVehicleList', function (event, response) {
      response.origFilters = angular.copy(response.filters)
      response.filters = updateFilters(response)
      vehiclesData = response
    })

    return {

      considerUnit: considerUnit,

      showData: function (key, details, perf) {
        var short = vehiclesData.displayInfo
        if (details && short.dontShowInDetails.indexOf(key) !== -1) {
          return false
        }

        // && UiUnits[short.predefinedUnits[key].type](100).unit === short.predefinedUnits[key].ifIs)
        if (perf === true && short.predefinedUnits[key] !== undefined) {
          if  (UiUnits[short.predefinedUnits[key].type](1).unit === short.predefinedUnits[key].ifIs || UiUnits[short.predefinedUnits[key].type](100).unit === short.predefinedUnits[key].ifIs) {
            return true
          }
        }

        if (short.predefinedUnits[key] !== undefined && UiUnits[short.predefinedUnits[key].type](0).unit !== short.predefinedUnits[key].ifIs) {
          return false
        }

        if (perf !== undefined) {

          return short.perfData.indexOf(key) !== -1 ? perf : !perf
        }
        return true
      },

      /**
       * @ngdoc method
       * @name  beamng.stuff:Vehicles#populate
       * @methodOf beamng.stuff:Vehicles
       * @description Retrieves all the available vehicles using the Lua interface and stores the result into vehiclesData
       * @returns {promise} ???
      **/
      populate: function () {
        var d = $q.defer()

        var listener = $rootScope.$on('sendVehicleList', function (event, response) {
          d.resolve()
          listener()
        })

        bngApi.engineLua('core_vehicles.requestList()')
        return d.promise
      },

      // Adds a new vehicle to the game
      //   spawnNew Whether to spawn a new vehicle into game instead of replacing the current
      addToGame: function (model, config, color, spawnNew, protectedConf = false) {
        var fallback = $timeout(() => {
          // if the car isn't spawned by now it will probably not spawn at all, so remove the waiting sign
          $rootScope.$broadcast('app:waiting', false)
        }, 3000)


        $rootScope.$broadcast('app:waiting', true, function () {
          var luaArgs = {}

          if (config) {
            if (typeof config === 'string') {
              luaArgs.config = config
            } else if (typeof config === 'object') {
              luaArgs.config = config.key
            }
          }

          if (color) {
            var values = color.split(' ').slice(0, 8)
            luaArgs.paint = {"baseColor":[values[0], values[1], values[2], values[3]],
                        "metallic": values[4],
                        "roughness": values[5],
                        "clearcoat": values[6],
                        "clearcoatRoughness": values[7]}
          }

          if (typeof model === 'object') {
            model = model.key
          }

          luaArgs.protectedConf = protectedConf

          bngApi.engineLua('core_vehicles.' + (spawnNew?"spawnNewVehicle":"replaceVehicle") + '("' + model + '", ' + bngApi.serializeToLua(luaArgs) + ')', function () {
            $rootScope.$broadcast('app:waiting', false)
            // car was spawned clear fallback
            $timeout.cancel(fallback)
          })
          bngApi.engineLua('extensions.hook("trackNewVeh")')
        })

      }
    }
}])


/**
 * @ngdoc controller
 * @name  beamng.stuff:VehicleDetailsController
 * @description
**/
.controller('VehicleDetailsController', ['$scope', '$stateParams', 'Vehicles', 'VehicleOpenTab', 'VehicleSelectConfig', 'VehicleSelectFilter', 'InputCapturer',
  function ($scope, $stateParams, Vehicles, VehicleOpenTab, VehicleSelectConfig, VehicleSelectFilter, InputCapturer) {
  var vm = this
  vm.mode = VehicleSelectConfig.configs[$stateParams.mode || 'default']
  vm.showAuxiliary = $stateParams.showAuxiliary
  vm.shownData = []
  vm.protectConfig = false

  let elConfig;
  // register preventer
  const captureInput = InputCapturer({
    backAction() { // action on Esc/B
      if (!elConfig)
        return false;
      try {
        // check if we're inside config details
        let elm = document.activeElement;
        while (elm.nodeType === Node.ELEMENT_NODE) {
          if (elm.id === "vehcfg-details") {
            elConfig.focus();
            elConfig = null;
            return true;
          }
          elm = elm.parentNode;
        }
      } catch (fire) {}
      return false;
    }
  });
  captureInput(true);
  $scope.$on("$destroy", () => captureInput(false));

  vm.selectAction = function (configname) {
    if (vm.selectedConfig && vm.selectedConfig.key === configname) {
      try {
        elConfig = document.activeElement;
        const btn = document.getElementById("vehcfg-default");
        if (btn)
          btn.focus();
      } catch (fire) {}
    } else {
      vm.selectConfig(configname, false);
    }
  };

  vm.selectConfig = function (configname, launch) {
    elConfig = null;
    vm.selectedConfig = vm.configs[configname]
    vm.detailsKeys = Object.keys(vm.selectedConfig.aggregates)
    // console.warn(vm.selectedConfig)

    for (var i = 0; i < vm.detailsKeys.length; i += 1) {
      var dtKeyName = vm.detailsKeys[i]
      var aggType = vm.selectedConfig.aggregates[dtKeyName]
      for (var propName in aggType) {
        if (vm.selectedConfig[dtKeyName] === undefined) {
          if (vehiclesData.displayInfo.ranges.all.indexOf(dtKeyName) !== -1) {
            vm.selectedConfig[dtKeyName] = aggType
          } else {
            vm.selectedConfig[dtKeyName] = propName
          }
        }
      }
    }

    vm.perfKeyList = vehiclesData.displayInfo.perfData
    vm.overviewKeylist = vehiclesData.displayInfo.filterData

    vm.selectedColor = vm.selectedConfig.default_color

    if (launch) vm.launchConfig(false)

    if (vm.perfKeyList.filter((elem) => vm.showData(elem, true)).length > 0
      || (vm.selectedConfig['Torque'] !== undefined && vm.selectedConfig['TorquePeakRPM'] !== undefined)
      || (vm.selectedConfig['Power'] !== undefined && vm.selectedConfig['PowerPeakRPM'] !== undefined)) {
        if (init) {
          vm.openTab = VehicleOpenTab.nr
        }
        vm.showPerf = true
    } else {
      VehicleOpenTab.nr = 0
      vm.openTab = 0
      vm.showPerf = false
    }
  }
  var init = true
  $scope.$watch(() => vm.openTab, () => {if (vm.showPerf) {VehicleOpenTab.nr = vm.openTab}})

  vm.considerUnit = (e, v) => Vehicles.considerUnit(e, v, true)

  vm.isRealRange = function (title) {
    return vehiclesData.displayInfo.ranges.real.indexOf(title) !== -1
  }

  vm.showData = (title, performance) => (vm.selectedConfig[title] !== undefined ? Vehicles.showData(title, true, performance) : false)

  vm.switchProtection = function() {
    vm.protectConfig = !vm.protectConfig
  }

  vm.launchConfig = function (spawnNew) {
    vm.mode.selected(vm.selectedConfig, vm.model.key, vm.selectedConfig.key, vm.selectedColor, spawnNew, vm.protectConfig)
  }

  // because of bug in non compete iirc
  vm.disableSpawnNew = (state) => state.toLowerCase().indexOf('scenario') !== -1


  function processData() {
    if (vm.model !== undefined && vm.model.paints !== undefined) {
      $scope.$evalAsync(() => {
        let colors = {}
        for (var paintName in vm.model.paints) {
          let paint = vm.model.paints[paintName]
          let color = paint.baseColor[0] + " " + paint.baseColor[1] + " " + paint.baseColor[2] + " " + paint.baseColor[3] + " " + paint.metallic + " " + paint.roughness + " " + paint.clearcoat + " " + paint.clearcoatRoughness
          colors[paintName] = color
        }
        vm.model.paints = colors
      })
    }

    for (var key in vm.configs) {
      var config = vm.configs[key]
      config.orderKey = ((config.Value || '') + "").padStart(16, '0') + '|' + (config.Configuration || '')
    }

    // Checking if quickrace is being used within career mode.
    // If it is then the available configs are filtered to what the player owns.
    if (VehicleSelectConfig.configs['quickrace'] && VehicleSelectConfig.configs['quickrace'].getVehicles() !== undefined) {
      var ownedVehicles = VehicleSelectConfig.configs['quickrace'].getVehicles()
      var ownedConfigs = {}
      for (var key in vm.configs) {
        for (var val in ownedVehicles) {
          if (ownedVehicles[val].config === vm.configs[key].key) {
            ownedConfigs[key] = vm.configs[key]
          }
        }
      }
      vm.configs = ownedConfigs
    }

    // so we can be sure the ranges list exists
    Vehicles.populate().then(() => {
      // this will also create vm.data.userFilters function
      const tmp = [vm.mode.filter, vm.mode.filterInv];
      vm.mode.filter = {};
      vm.mode.filterInv = {};
      VehicleSelectFilter.filterFromConfig(vm, vm.mode);
      vm.mode.filter = tmp[0];
      vm.mode.filterInv = tmp[1];

      VehicleSelectFilter.forced(vm, vm.mode);

      // this will also create vm.userFilters function
      VehicleSelectFilter.filterFromConfig(vm, vm.mode);

      // filter aux
      vm.configs = vm.configs.filter(itm => !itm.isAuxiliary || vm.showAuxiliary);

      // convert array to object (temp compat patch)
      vm.configs = vm.configs.reduce((res, cur) => ({ ...res, [cur.key]: cur }), {});

      if ($stateParams.config == '' && vm.model.default_pc && vm.configs.hasOwnProperty(vm.model.default_pc)) {
        vm.selectConfig(vm.model.default_pc)
      } else if ($stateParams.config != '') {
        vm.selectConfig($stateParams.config)
      } else if (Object.keys(vm.configs)[0] !== undefined) {
        vm.selectConfig(Object.keys(vm.configs)[0])
      }

      vm.shownData = vm.configs;
    })
  }

  vm.filters = vehiclesData.filters;
  vm.displayInfo = vehiclesData.displayInfo;
  vm.model = vehiclesData.models.find(veh => veh.key === $stateParams.model);
  if (vm.model) {
    vm.configs = vehiclesData.configs.filter(veh => veh.model_key === $stateParams.model);
    vm.hasConfigs = vm.configs.length > 1;
    processData();
  } else {
    bngApi.engineLua('core_vehicles.getModel("' + $stateParams.model + '")', function (response) {
      if(response === undefined) {
        console.error("Error in vehicle response: ", response)
        return
      }

      vm.model          = response.model
      vm.configs        = Object.values(response.configs)
      vm.hasConfigs     = vm.configs.length > 1

      processData();
    });
  }

}])


.service("VehicleSelectFilter", ["Vehicles", function (Vehicles) {
  return {
    // apply forced filters
    // it expects data.models, data.configs and data.filters as arrays, and data.userFilters()
    // it filters by data.configs and then selects models that left
    forced(data, mode) {
      if (!data.models)
        data.models = [];
      if (!data.configs)
        data.configs = [];
      if (mode.forceFilter && typeof mode.forceFilter === "boolean")
        mode.forceFilter = mode.filter;
      // in career mode, we have virtual vehicle configurations with Source=Career
      // that does not inherited by models and, therefore, filters. we fix this in here.
      // note: inCareer must be set in vehselector configuration. if it's not possible,
      //       we must scan all configs to find Source=Career
      if (mode.inCareer && data.filters.Source) {
        data.filters.Source.Career = true;
        for (let cfg of data.configs) {
          if (cfg.Source !== "Career")
            continue;
          const model = data.models.find(model => model.key === cfg.model_key);
          if (!model)
            continue;
          if (!model.aggregates.Source)
            model.aggregates.Source = {};
          model.aggregates.Source.Career = true;
        }
      }
      // process restrictions (effectively it is an inverted forced filter)
      // in mode.restrict, you can specify non-standard keys and negate their values (see special variable)
      let special = { key: ["!powerglow"] };
      if (mode.restrict && Object.keys(mode.restrict).length > 0) {
        if (!mode.forceFilter)
          mode.forceFilter = {};
        for (let key in mode.restrict) {
          if (!data.filters[key]) {
            special[key] = mode.restrict[key];
            continue;
          }
          // gather all filters
          mode.forceFilter[key] = Object.keys(data.filters[key]);
          // use this if you need to append instead of overwrite
          // if (!mode.forceFilter[key]) {
          //   mode.forceFilter[key] = Object.keys(data.filters[key]);
          // } else {
          //   mode.forceFilter[key].push(
          //     ...Object.keys(data.filters[key])
          //     .filter(itm => !mode.forceFilter[key].includes(itm))
          //   );
          // }
          // apply inversion
          mode.forceFilter[key] = mode.forceFilter[key].filter(
            name => !mode.restrict[key].includes(name)
          );
        }
      }
      // filter configs if there was special keys
      if (special) {
        data.configs = data.configs.filter(cfg => {
          let ok = true;
          for (let key in special) {
            ok = special[key].includes(cfg[key]);
            if (!ok)
              break;
          }
          if (!ok) {
            for (let key in special) {
              if (!special[key].find(names => names.indexOf("!") === 0))
                continue;
              ok = !special[key].includes("!" + cfg[key]);
              if (ok)
                break;
            }
          }
          return ok;
        });
      }
      // force filtering
      if (mode.forceFilter) {
        // remove unwanted filters
        for (let key in mode.forceFilter) {
          if (data.filters[key]) {
            for (let name of mode.forceFilter[key])
              delete data.filters[key][name];
          }
        }
        // filter configs
        data.__strictSource = !!data.filters.Source; // silly temp fix
        data.configs = data.configs.filter(data.userFilters);
        delete data.__strictSource;
        // filter models by configs
        const models = data.configs.map(cfg => cfg.model_key);
        const keys = data.configs.map(cfg => cfg.key);
        data.models = data.models.filter(
          model => models.includes(model.key)
        );
        for (let model of data.models) {
          if (keys.includes(model.default_pc))
            continue;
          const config = data.configs.find(cfg => cfg.model_key === model.key);
          if (!config)
            continue;
          model.preview = config.preview;
        }
      }
    }, // /forced
    filterFromConfig(data, mode) {
      if (mode.filterInv) {
        for (let catName in mode.filterInv) {
          if (!data.displayInfo.ranges.all.includes(catName)) {
            for (let propName in data.filters[catName])
              data.filters[catName][propName] = mode.filterInv[catName].includes(propName);
          }
        }
      } else {
        for (let catName in mode.filter) {
          if (!data.displayInfo.ranges.all.includes(catName)) {
            for (let propName of mode.filter[catName])
              data.filters[catName][propName] = false;
          }
        }
      }
      data.userFilters = function(model) {
        let result = true;
        for (let filterId in data.filters) {
          if (model.aggregates.hasOwnProperty(filterId)) {
            const prop = model.aggregates[filterId];
            let isOk = false;
            if (data.displayInfo.ranges.all.includes(filterId)) {
              //ranges:
              isOk =
                Vehicles.considerUnit(filterId, prop.min).val <= data.filters[filterId].max &&
                Vehicles.considerUnit(filterId, prop.max).val >= data.filters[filterId].min;
            } else if (data.__strictSource && filterId === "Source" && model.Source) {
              isOk = !!data.filters.Source[model.Source];
              // isOk = true;
              // for (let name in prop) {
              //   isOk = !!data.filters[filterId][name];
              //   if (!isOk)
              //     break;
              // }
            } else {
              //everything else:
              for (let name in prop) {
                isOk = !!data.filters[filterId][name];
                if (isOk)
                  break;
              }
            }
            if (!isOk) {
              result = false;
              break;
            }
          } else {
            // treat the special case of vehicles without this property set, represented with the user-facing checkbox '...'
            if (!data.displayInfo.ranges.all.includes(filterId) &&
              !data.filters[filterId]["..."]) {
              result = false;
              break;
            }
          }
        } // /for
        return result;
      };
    }, // /filterFromConfig
  };
}])


/**
 * @ngdoc controller
 * @name  beamng.stuff:VehicleSelectController
 * @description <TODO>
**/
.controller('VehicleSelectController', ['$scope', '$state', '$timeout', '$stateParams', '$rootScope', 'Settings', 'VehiclePrefs', 'VehicleSelectConfig', 'VehicleSelectFilter', 'VehicleSelectOptions', 'Vehicles', '$filter', "GarageVehicleState", "ConfirmationDialog",
function ($scope, $state, $timeout, $stateParams, $rootScope, Settings, VehiclePrefs, VehicleSelectConfig, VehicleSelectFilter, VehicleSelectOptions, Vehicles, $filter, GarageVehicleState, ConfirmationDialog) {
  var vm = this
  vm.data = angular.copy(vehiclesData)
  vm.mode = VehicleSelectConfig.configs[$stateParams.mode || 'default']
  vm.shownData = []

  if ($stateParams.mode === "garageMode") {
    if (!vm.mode) {
      VehicleSelectConfig.addConfig("garageMode", {
        hide: {
          "removeBtns": true,
          "spawnNew": true
        },
        selected: (carObj, model, config, color, spawnNew, protected) => {
          if (GarageVehicleState.vehicleDirty) {
            ConfirmationDialog.open(
              null, "ui.career.garage.vehicleSwitchPrompt",
              [
                { label: "ui.common.yes", key: true },
                { label: "ui.common.no", key: false, default: true, isCancel: true }
              ]
            ).then(res => {
              if (res) {
                if (carObj.spawnFunction) {
                  bngApi.engineLua(carObj.spawnFunction);
                } else {
                  Vehicles.addToGame(model, config, color, spawnNew, protected);
                }
                $state.go("garagemode");
              }
            });
          } else {
            if (carObj.spawnFunction) {
              bngApi.engineLua(carObj.spawnFunction);
            } else {
              Vehicles.addToGame(model, config, color, spawnNew, protected);
            }
            $state.go("garagemode");
          }
        },
        selectButton: "ui.garage.load.loadCar",
        name: "garageMode",
        restrict: {},
      });
      vm.mode = VehicleSelectConfig.configs.garageMode;
    }
    // official:                     Source = ["BeamNG - Official"]
    // official with custom configs: Source = ["BeamNG - Official", "Custom"]
    // unofficial:                   Source = ["Mod", "Custom"]
    // and "Automation" is in Type for some reason...
    // /// show configs in "My cars" instead of models:
    // vm.mode.showConfigurations = $stateParams.garage === "own" && $stateParams.inCareer;
    if ($stateParams.garage === "own") {
      vm.mode.showStandalonePcs = true;
      vm.mode.restrict.Source = ["Custom", "Mod", "Career"];
    } else if ($stateParams.garage === "own-career") { // not actually used
      vm.mode.showStandalonePcs = false;
      delete vm.mode.restrict.Source; // not sure about that
    } else {
      // delete vm.mode.showStandalonePcs;
      vm.mode.showStandalonePcs = false;
      vm.mode.restrict.Source = ["Custom", "BeamNG - Official", "Mod"];
    }
  }

  function loadList() {
    Vehicles.populate().then(() => {
      vm.data = angular.copy(vehiclesData)

      // this will also create vm.data.userFilters function
      const tmp = [vm.mode.filter, vm.mode.filterInv];
      vm.mode.filter = {};
      vm.mode.filterInv = {};
      VehicleSelectFilter.filterFromConfig(vm.data, vm.mode);
      vm.mode.filter = tmp[0];
      vm.mode.filterInv = tmp[1];

      VehicleSelectFilter.forced(vm.data, vm.mode);

      // used to filter owned vehicles if quickrace is being access from career mode.
      // TODO: transfer logic to VehicleSelectConfig
      if (VehicleSelectConfig.configs['quickrace'] && VehicleSelectConfig.configs['quickrace'].getVehicles() !== undefined) {
        const ownedVehicles = Object.values(
          VehicleSelectConfig.configs['quickrace'].getVehicles()
        ).map(e => e.model);
        vm.data.models = vm.data.models.filter(e => ownedVehicles.includes(e.key));
      }

      // this will also create vm.data.userFilters function
      VehicleSelectFilter.filterFromConfig(vm.data, vm.mode);

      // calculate big names for tooltips
      function isBig(itm) {
        let str = itm.Brand + " " + (itm.Name || "Unknown");
        return str.length >= 28;
      }
      for (let itm of vm.data.models)
        itm._bigName = isBig(itm);
      for (let itm of vm.data.configs)
        itm._bigName = isBig(itm);

      vm.data.list = vm.showConfigurations ? vm.data.configs : vm.data.models;

      // todo: rethink for this what happens if the filter change? (i mean the html is not ready for it either, but think ot it anyway)
      vm.filterKeyList = vehiclesData.displayInfo.filterData
      vm.applyFilters()
      // checkOverflow()

      setTimeout(() => bngApi.engineLua('core_vehicles.requestListEnd()'), 10);
    })
  }

  vm.openRepo = function () {
    window.location.href = 'http-external://www.beamng.com/resources/categories/vehicles.2/?ingame=2'
  }

  vm.launchVehicle = function (model) {
    if ((model.key !== undefined) && (model.default_pc !== undefined)){
        vm.mode.selected(model, model.key, model.default_pc, model.default_color)
    } else if (vm.showConfigurations && model.model_key !== undefined) {
      vm.mode.selected(model, model.model_key, model.key)
    } else {
      vm.mode.selected(model, model.key)
    }
  }

  vm.showData = (key) => Vehicles.showData(key, false)

  vm.getStep = function (key) {
    var unit = vehiclesData.displayInfo.units[key] || vehiclesData.displayInfo.predefinedUnits[key]
    if (unit !== undefined) {
      return Math.pow(10, -1 * unit.dec)
    } else {
      return 0
    }
  }
  vm.considerUnit = (e, v) => {
    var short = Vehicles.considerUnit(e, v)
    return `${v} ${short.unit || ''}`
  }
  vm.titleUnit = (elem) => {
    var short = Vehicles.considerUnit(elem, 0)
    if (short.unit !== undefined) {
      return `${elem} (${short.unit})`
    } else {
      return elem
    }
  }

  vm.goToConfigs = function (model) {
    var args = {
      model: model.key,
      mode: $stateParams.mode || 'default',
      event: $stateParams.event || '',
      showAuxiliary: vm.showAuxiliary
    }

    if (model.model_key !== undefined) {
      args.model = model.model_key
      args.config = model.key
    }

    $state.go('menu.vehiclesdetails', args)
  }

  // order in which the categories should appear
  let orderedCategories = {
    'car':1,
    'truck':1,
    'aircraft':1,
    'boat':1,
    'automation':2,
    'trailer':3,
    // rest will fallback to 9
  }
  let categoryColors = {
    1: "rgba(255, 255, 255, 0.0)",
    2: "rgba(255, 100, 130, 0.2)",
    3: "rgba(90, 130, 255, 0.2)",
    9: "rgba(255, 190, 100, 0.2)",
  }

  vm.selected = null

  vm.showConfigurations = !!vm.mode.showConfigurations;
  vm.query = VehiclePrefs.query
  vm.showAuxiliary = VehicleSelectOptions.showAuxiliary

  $scope.$watch(() => vm.showAuxiliary, () => { VehicleSelectOptions.showAuxiliary= vm.showAuxiliary } )

  vm.switchList = function () {
    if (vm.showConfigurations) {
      vm.data.list = vm.data.configs
    } else {
      vm.data.list = vm.data.models
    }
    vm.applyFilters()
  }

  vm.showStandalonePcsOverriden = false;
  let showStandalonePcsOrig;
  let loadedWithPcs = null;
  vm.showStandalonePcsChanged = function (callback) {
    const changeObj = { showStandalonePcs: !!vm.showStandalonePcs };
    bngApi.engineLua(
      `settings.setState( ${bngApi.serializeToLua(changeObj)} )`,
      () => callback && callback()
    );
  }
  let windowPlacement;
  $scope.$on('SettingsChanged', function (event, data) {
    let oldPlacement = windowPlacement
    windowPlacement = data.options.WindowPlacement.placement
    if (oldPlacement && oldPlacement !== windowPlacement) return;

    vm.showStandalonePcs = data.values.showStandalonePcs;
    let wantedPcs = vm.showStandalonePcs;
    if (vm.mode.hasOwnProperty("showStandalonePcs")) {
      wantedPcs = !!vm.mode.showStandalonePcs;
      // save the original value to restore it on $destroy
      if (!vm.showStandalonePcsOverriden) {
        vm.showStandalonePcsOverriden = true;
        if (vm.showStandalonePcs !== wantedPcs)
          showStandalonePcsOrig = data.values.showStandalonePcs;
      }
    }
    if (vm.showStandalonePcs !== wantedPcs) {
      // console.log("set", wantedPcs)
      vm.showStandalonePcs = wantedPcs;
      vm.showStandalonePcsChanged();
    } else if (typeof loadedWithPcs !== "boolean" || loadedWithPcs !== wantedPcs) {
      // console.log("load", wantedPcs)
      loadedWithPcs = wantedPcs;
      loadList();
    } else {
      // console.log("skip")
    }
  })
  bngApi.engineLua('settings.notifyUI()');

  vm.isRange = function (title) {
    return vm.data.displayInfo.ranges.all.indexOf(title) !== -1
  }

  vm.getTileCategory = function(vehicle) {
    let vehicleTypes = vehicle.aggregates.Type
    let result = 9 // fallback (string order would break above 9 due to amount of chars in number string)
    for (let vehicleType in vehicleTypes) {
      let orderValue = orderedCategories[vehicleType.toLowerCase()]
      if (orderValue !== undefined) {
        result = Math.min(result, orderValue)
      }
    }
    return result
  }

  vm.getTileCategoryColor = function(vehicle) {
    return categoryColors[vm.getTileCategory(vehicle)]
  }

  vm.tilesOrder = function (vehicle) {
    return vm.getTileCategory(vehicle) + (vehicle.Brand || '') + (vehicle.Name || '') + (vehicle.model_key || '') + vehicle.key
  }

  function _assignValueAllFilters(val) {
    for (let catName in vm.data.filters) {
      if (!vm.data.displayInfo.ranges.all.includes(catName)) {
        for (let prop in vm.data.filters[catName])
          vm.data.filters[catName][prop] = val;
      }
    }
  }

  vm.applyFilters = function () {
    // vehicles.data.list | filter: vehicles.query | filter: vehicles.userFilters | orderBy: vehicles.tilesOrder
    vm.shownData = $filter("orderBy")(
      $filter("filter")(
        vm.data.list.filter(vm.data.userFilters),
        vm.query
      ),
      vm.tilesOrder
    );
    // filter aux
    vm.shownData = vm.shownData.filter(itm => !itm.isAuxiliary || vm.showAuxiliary);
    // count how many configs per model we have, to display with the small 'folder' icon
    let configAmount = {};
    for (let model of vm.data.configs) {
      let key = model.model_key;
      if (!configAmount.hasOwnProperty(key))
        configAmount[key] = 0;
      configAmount[key]++;
    }
    for (let model of vm.shownData) {
      let key = vm.showConfigurations ? model.model_key : model.key;
      model.configsAmount = configAmount[key];

      // retrieve label background color
      model.bgColor = vm.getTileCategoryColor(model)
    }
  }


  vm.checkAll = function () {
    _assignValueAllFilters(true)
    vm.query = ''
    vm.applyFilters()
  }

  vm.uncheckAll = function () {
    _assignValueAllFilters(false)
    vm.applyFilters()
  }

  vm.cloneCurrentVehicle = function() {
    var fallback = $timeout(() => {
      // if the car isn't spawned by now it will probably not spawn at all, so remove the waiting sign
      $rootScope.$broadcast('app:waiting', false)
    }, 3000)


    $rootScope.$broadcast('app:waiting', true, function () {
      bngApi.engineLua('core_vehicles.cloneCurrent()', function () {
        $rootScope.$broadcast('app:waiting', false)
        // car was spawned clear fallback
        $timeout.cancel(fallback)
        $state.go('play')
      })
      bngApi.engineLua('extensions.hook("trackNewVeh")')
    })
  }
  vm.resetAll = function() {
    bngApi.engineLua('resetGameplay(-1)')
    $state.go('play')
  }
  vm.removeCurrentVehicle = function() {
    bngApi.engineLua('core_vehicles.removeCurrent(); extensions.hook("trackNewVeh")')
    $state.go('play')
  }
  vm.removeAllVehicles = function() {
    bngApi.engineLua('core_vehicles.removeAll(); extensions.hook("trackNewVeh")')
  }
  vm.removeAllExceptCurrentVehicle = function() {
    bngApi.engineLua('core_vehicles.removeAllExceptCurrent()')
    $state.go('play')
  }
  vm.loadDefault = function() {
    bngApi.engineLua('core_vehicles.spawnDefault(); extensions.hook("trackNewVeh")')
    $state.go('play')
  }
  vm.saveDefault = function() {
    bngApi.engineLua('extensions.core_vehicle_partmgmt.savedefault();')
    $state.go('play')
  }

  $scope.$on('$destroy', function () {
    VehiclePrefs.filters = vm.data.filters
    // VehiclePrefs.showConfigurations = vm.showConfigurations
    VehiclePrefs.query = vm.query
    if (vm.showStandalonePcsOverriden) {
      vm.showStandalonePcs = showStandalonePcsOrig;
      vm.showStandalonePcsChanged();
    }
  })

}])
