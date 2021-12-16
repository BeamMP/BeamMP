angular.module('beamng.stuff')

.value('VehiclePrefs', {
  filters: {},
  showConfigurations: false,
  query: ''
})

.value('VehicleOpenTab', {
  nr: 0
})

.service('VehicleSelectConfig', ['Vehicles', '$state', '$rootScope', function (Vehicles, $state, $rootScope) {
  var configs = {
    default: {
      hide: {},
      selected: (carObj, model, config, color, spawnNew, mp) => {
        Vehicles.addToGame(model, config, color, spawnNew, mp)
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
            if (vehicles.displayInfo.ranges.all.indexOf(key) !== -1) {
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
          if (vehicles.displayInfo.ranges.all.indexOf(key) === -1) {
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
      //console.log('sendVehicleList', JSON.stringify(response).length, response)
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

      /**
       * @ngdoc method
       * @name beamng.stuff:Vehicles#addToGame
       * @methodOf beamng.stuff:Vehicles
       * @description Adds a new vehicle to the game
       *
       * @param {object} model <TODO>
       * @param {string} config <TODO>
       * @param {string} color <TODO>
       * @param {boolean} spawnNew Whether to spawn a new vehicle into game instead of replacing the current
       * @param {boolean} mp are we in a beammp session
      **/
      addToGame: function (model, config, color, spawnNew, mp) {
        //console.log('got', model, config, color, spawnNew, mp)

        var fallback = $timeout(() => {
          // if the car isn't spawned by now it will probably not spawn at all, so remove the waiting sign
          $rootScope.$broadcast('app:waiting', false)
        }, 3000)


        $rootScope.$broadcast('app:waiting', true, function () {
          var func = "core_vehicles.replaceVehicle"
          if (spawnNew) func = "core_vehicles.spawnNewVehicle"
          if (mp) func = "MPVehicleGE.spawnRequest";

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

          if (spawnNew) {
            luaArgs.spawnNew = true;
          }

          bngApi.engineLua(func + '("' + model + '", ' + bngApi.serializeToLua(luaArgs) + ')', function () {
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
.controller('VehicleDetailsController', ['$scope', '$stateParams', 'Vehicles', 'VehicleOpenTab', '$state', 'VehicleSelectConfig',
  function ($scope, $stateParams, Vehicles, VehicleOpenTab, $state, VehicleSelectConfig) {
  var vm = this
  vm.mode = VehicleSelectConfig.configs[$stateParams.mode || 'default']
  // console.log($stateParams)

  // --------------------------------------- BEAMMP --------------------------------------- //

  vm.isMPSession = false;
  bngApi.engineLua('MPCoreNetwork.isMPSession()', function (str) {
    $scope.$evalAsync(() => { vm.isMPSession = str; vm.isNotMPSession = !str; });
  });

  // --------------------------------------- BEAMMP --------------------------------------- //


  vm.selectConfig = function (configname, launch) {
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

    // console.log('changed to vehicle: ', vm.selectedConfig)

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

  vm.launchConfig = function (spawnNew) {
    vm.mode.selected(vm.selectedConfig, vm.model.key, vm.selectedConfig.key, vm.selectedColor, spawnNew, vm.isMPSession)
  }

  // because of bug in non compete iirc
  vm.disableSpwanNew = (state) => state.toLowerCase().indexOf('scenario') !== -1

  bngApi.engineLua('core_vehicles.getModel("' + $stateParams.model + '")', function (response) {
    if(response === undefined) {
      console.error("Error in vehicle response: ", response)
      return
    }
    // console.log(vm)

    vm.model          = response.model
    vm.hasConfigs     = Object.keys(response.configs).length > 1
    vm.configs        = response.configs


    if (vm.model !== undefined && vm.model.paints !== undefined) {
      $scope.$evalAsync(() => {
        let colors = {}
        for (var paintName in vm.model.paints) {
          let paint = vm.model.paints[paintName]
          let color = paint.baseColor[0] + " " + paint.baseColor[1] + " " + paint.baseColor[2] + " " + paint.baseColor[3] + " " + paint.metallic + " " + paint.roughness + " " + paint.clearcoat + " " + paint.clearcoatRoughness
          colors[paintName] = color
        }
        vm.model.paints = colors
        //console.log("model", vm.model)
      })
    }

    for (var key in vm.configs) {
      var config = vm.configs[key]
      config.orderKey = ((config.Value || '') + "").padStart(16, '0') + '|' + (config.Configuration || '')
    }

    // Filter out powerglow configs
    if (vm.mode && vm.mode.name !== "lightRunner") {
      for (var key in vm.configs) {
        if (vm.configs[key].key === "powerglow") {
          delete vm.configs[key]
        }
      }
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
    else if ($stateParams.mode === "busRoutes") {
      var filteredConfigs = {}
      for (var key in vm.configs) {
        var e = vm.configs[key]
        if (e.aggregates && e.aggregates["Body Style"] && e.aggregates["Body Style"]["Bus"]) {
          filteredConfigs[key] = e
        }
      }
      vm.configs = filteredConfigs
    }

    // so we can be sure the ranges list exists
    Vehicles.populate().then(() => {
      if ($stateParams.config == '' && vm.model.default_pc) {
        vm.selectConfig(vm.model.default_pc)
      } else if ($stateParams.config != '') {
        vm.selectConfig($stateParams.config)
      } else if (Object.keys(vm.configs)[0] !== undefined) {
        vm.selectConfig(Object.keys(vm.configs)[0])
      }
    })
  })

}])


/**
 * @ngdoc controller
 * @name  beamng.stuff:VehicleSelectController
 * @description <TODO>
**/
.controller('VehicleSelectController', ['$scope', '$state', '$timeout', '$stateParams', '$rootScope', 'Settings', 'VehiclePrefs', 'VehicleSelectConfig', 'Vehicles', '$filter',
function ($scope, $state, $timeout, $stateParams, $rootScope, Settings, VehiclePrefs, VehicleSelectConfig, Vehicles, $filter) {
  var vm = this
  vm.data = angular.copy(vehiclesData)
  vm.mode = VehicleSelectConfig.configs[$stateParams.mode || 'default']
  vm.shownData

  $scope.isBig = function(str) {
    if(str){
      return str.length > 28
    }
  }
  // --------------------------------------- BEAMMP --------------------------------------- //

  vm.isMPSession = false;
  vm.isNotMPSession = false;
  bngApi.engineLua('MPCoreNetwork.isMPSession()', function (str) {
    $scope.$evalAsync(() => { vm.isMPSession = str; vm.isNotMPSession = !str; });
  });

  // --------------------------------------- BEAMMP --------------------------------------- //


  Vehicles.populate().then(() => {
    vm.data = angular.copy(vehiclesData)
    if (vm.mode.name !== "lightRunner") {
      for (var key in vm.data.configs) {
        if (vm.data.configs[key].key === "powerglow") {
          vm.data.configs.splice(key, 1)
        }
      }
      // TODO: Find a better way to reset search query if lightRunner mode is not being used... yay hacks.
      if (vm.query === "Powerglow") {
        $scope.$evalAsync(function() {
          vm.query = ""
          vm.showConfigurations  = false
          vm.switchList()
        })
      }
    }
    if (vm.mode.name === "lightRunner") {
      $scope.$evalAsync(function() {
        vm.query = "Powerglow"
        vm.showConfigurations = true
        vm.switchList()
      })
    }
    // used to filter owned vehicles if quickrace is being access from career mode.
    if (VehicleSelectConfig.configs['quickrace'] && VehicleSelectConfig.configs['quickrace'].getVehicles() !== undefined) {
      var ownedVehicles = VehicleSelectConfig.configs['quickrace'].getVehicles()
      vm.data.models = vm.data.models.filter((e) => {
        for (var key in ownedVehicles) {
          if (ownedVehicles[key].model === e.key) return true
        }
        return false
      })
    }

    if ($stateParams.mode === "busRoutes") {
      vm.data.models = vm.data.models.filter((e) => {
        // filtering out every vehicle except for Official Buses
        if (e["Body Style"] === "Bus")
          return true
      })
      vm.data.configs = vm.data.configs.filter((e) => {
        // filtering out every vehicle except for Official Buses
        if (e.aggregates["Body Style"] && e.aggregates["Body Style"]["Bus"] === true)
          return true
      })
    }

    vm.data.list = (VehiclePrefs.showConfigurations ? vm.data.configs : vm.data.models)
    // todo: rethink for this what happens if the filter change? (i mean the html is not ready for it either, but think ot it anyway)
    vm.filterKeyList = vehiclesData.displayInfo.filterData
    vm.filterFromConfig()
    vm.applyFilters()
    // checkOverflow()
  })

  vm.openRepo = function () {
    window.location.href = 'http-external://www.beamng.com/resources/categories/vehicles.2/?ingame=2'
  }

  vm.launchVehicle = function (model) {
    if ((model.key !== undefined) && (model.default_pc !== undefined)){
      vm.mode.selected(model, model.key, model.default_pc, model.default_color, false, vm.isMPSession)
    }
    else if (vm.showConfigurations && model.model_key !== undefined) {
      vm.mode.selected(model, model.model_key, model.key, null, false, vm.isMPSession)
    } else {
      vm.mode.selected(model, model.key, null, null, false, vm.isMPSession)
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
      event: $stateParams.event || ''
    }

    if (model.model_key !== undefined) {
      args.model = model.model_key
      args.config = model.key
    }

    $state.go('menu.vehiclesdetails', args)
  }

  // order in which the categories should appear
  var orderedCategories = [
    'car',
    'truck',
    'automation',
    'trailer',
    'aircraft',
    'boat',
    'prop',
    'unknown' // sink to the bottom
  ]

  vm.selected = null

  vm.showConfigurations = VehiclePrefs.showConfigurations
  vm.query = VehiclePrefs.query

  vm.switchList = function () {
    if (vm.showConfigurations) {
      vm.data.list = vm.data.configs
    } else {
      vm.data.list = vm.data.models
    }
    vm.applyFilters()
  }

  vm.isRange = function (title) {
    return vm.data.displayInfo.ranges.all.indexOf(title) !== -1
  }

  vm.tilesOrder = function (vehicle) {
    var types = vehicle.aggregates.Type
    var prepend = orderedCategories.length
    for (var type in types) {
      var index = orderedCategories.indexOf(type.toLowerCase())
      index = (index > -1 ? index : orderedCategories.length)
      if (index < prepend) {
        prepend = index
      }
    }

    var help = prepend  + (vehicle.Name || '') + (vehicle.model_key || '') + vehicle.key;
    return help;
  }


  vm.userFilters = function (model, index, array) {
    let result = true
    for (var filterId in vm.data.filters) {
      if (model.aggregates.hasOwnProperty(filterId)) {
        if (vm.data.displayInfo.ranges.all.indexOf(filterId) !== -1) {
          //ranges:
          var inDateRange =
            Vehicles.considerUnit(filterId, model.aggregates[filterId].min).val <= vm.data.filters[filterId].max &&
            Vehicles.considerUnit(filterId, model.aggregates[filterId].max).val >= vm.data.filters[filterId].min

          if (!inDateRange) {
            result = false
            break
          }
        } else {
          //everything else:
          var isOk = false

          for (var propertyValue in model.aggregates[filterId]) {
            isOk = isOk || vm.data.filters[filterId][propertyValue]
            if (isOk) break
          }

          if (!isOk) {
            result = false
            break
          }
        }
      } else {
        // treat the special case of vehicles without this property set, represented with the user-facing checkbox '...'
        if (vm.data.displayInfo.ranges.all.indexOf(filterId) === -1) {
          if (!vm.data.filters[filterId]['...']) {
            result = false
            break
          }
        }
      }
    }

    return result
  }

  function _assignValueAllFilters(val) {
    for (var catName in vm.data.filters) {
      if (vm.data.displayInfo.ranges.all.indexOf(catName) === -1) {
        var cat = vm.data.filters[catName]
        for (var prop in cat) {
          cat[prop] = val
        }
      }
    }
  }

  vm.applyFilters = function () {
    // vehicles.data.list | filter: vehicles.query | filter: vehicles.userFilters | orderBy: vehicles.tilesOrder
    vm.shownData = $filter("orderBy")($filter("filter")($filter("filter")(vm.data.list, vm.userFilters), vm.query), vm.tilesOrder)
    // count how many configs per model we have, to display with the small 'folder' icon
    let configAmount = {}
    for (let i in vm.data.configs) {
      let model = vm.data.configs[i]
      let key = model.model_key
      if (configAmount[key] === undefined) configAmount[key] = 0
      configAmount[key]++
    }
    for (let i in vm.shownData) {
      let model = vm.shownData[i]
      let key = vm.showConfigurations ? model.model_key : model.key
      model.configsAmount = configAmount[key]
    }
  }

  vm.filterFromConfig = function() {
    for (var catName in vm.mode.filter) {
      if (vm.data.displayInfo.ranges.all.indexOf(catName) === -1) {
        for (var i = 0; i < vm.mode.filter[catName].length; i += 1) {
          var propName = vm.mode.filter[catName][i]
          vm.data.filters[catName][propName] = false
        }
      }
    }
  }


  vm.checkAll = function () {
    _assignValueAllFilters(true)
    vm.query = ''
  }

  vm.uncheckAll = function () {
    _assignValueAllFilters(false)
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
    bngApi.engineLua('MPVehicleGE.spawnDefaultRequest()');
    //bngApi.engineLua('core_vehicles.spawnDefault(); extensions.hook("trackNewVeh")')
    $state.go('play')
  }
  vm.saveDefault = function() {
    bngApi.activeObjectLua("obj:queueGameEngineLua(\"MPVehicleGE.saveDefaultRequest('\"..obj:getID()..\"')\")");
    //bngApi.engineLua('extensions.core_vehicle_partmgmt.savedefault();')
    $state.go('play')
  }


  $scope.$on('$destroy', function () {
    VehiclePrefs.filters = vm.data.filters
    VehiclePrefs.showConfigurations = vm.showConfigurations
    VehiclePrefs.query = vm.query
  })

}])
