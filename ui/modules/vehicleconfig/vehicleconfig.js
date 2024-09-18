angular.module('beamng.stuff')

/**
 * @ngdoc service
 * @name beamng.stuff:VehicleConfig
 *
 * @description
 * Helper functions for editing a vehicle's configuration
 */
.factory('VehicleConfig', ['$q', 'Utils', function ($q, Utils) {
  let _generateTreeBranch = function (data, part, simple, depth) {
    let res = []
    if(depth>200) return

    let defaultHighlight = !data.partsHighlighted

    for (var slotName in part.slotInfoUi) {
      let slotInfo = part.slotInfoUi[slotName]
      let isHighlighted = defaultHighlight
      let chosenPart = data.chosenParts[slotName]

      if (chosenPart === ''){
        isHighlighted = false
      }
      else {
        if (data.partsHighlighted && data.partsHighlighted[chosenPart] !== undefined) {
          isHighlighted = data.partsHighlighted[chosenPart]
        }
      }

      let element = {
        name: slotName,
        description: slotInfo.description,

        type: slotInfo.type, // slots1
        allowTypes: slotInfo.allowTypes, // slots2
        denyTypes: slotInfo.denyTypes, // slots2

        val: '',
        options: [],
        highlight: isHighlighted
      }
      let elOptions = element.options
      let optionCount = 0
      let slotAllowedTypes = slotInfo.allowTypes || [slotInfo.type]
      for (let st of slotAllowedTypes) {
        if(data.slotMap[st] !== undefined) {
          for (var i=0; i < data.slotMap[st].length; i++) {
            let slotPartName = data.slotMap[st][i]
            let slotPart = data.availableParts[slotPartName]
            if(slotPart === undefined) {
              console.error('slot part not found: ', slotPartName)
            } else {
              elOptions[elOptions.length] = {
                name: slotPartName,
                description: slotPart.description,
                isAuxiliary: slotPart.isAuxiliary,
                val: slotPartName
              }
              optionCount++
              if (data.chosenParts[slotName] == slotPartName || data.chosenParts[st] == slotPartName) {
                element.val = slotPartName
                if (slotPart.slotInfoUi) {
                  element.parts = _generateTreeBranch(data, slotPart, simple, depth + 1)
                }
                if (element.parts !== undefined && element.parts.length === 0) {
                  delete element.parts
                }
              }
            }
          }
        }
      }
      if(slotInfo.coreSlot === undefined && optionCount > 0) {
        element.options.unshift({name: '<empty>', description: 'Empty', val: ''})
      } else {
        element.open = true
      }

      if (!simple || element.options.length > 2 || (element.options.length > 1 && element.options[0].val !== '') || depth < 1) {
        res.push(element)
      }
    }
    return res
  }


  return {
    generateTree: function (data, simple) {
      return _generateTreeBranch(data, data.availableParts[data.mainPartName], simple)
    },

    generateConfig: function (d, res) {
      res = res || {}
      if (!d) return res

      d.map((x) => {
        res[x.name] = x.val
        if (x.parts) this.generateConfig(x.parts, res)
      })
      return res
    },

    defaultVarValToDisVal: function (v) {
      let valClamped = Utils.clamp(v.default, Math.min(v.min, v.max), Math.max(v.min, v.max))
      let vData = (valClamped - v.min) / (v.max - v.min); //lua ratio
      return Utils.roundDec(vData * (v.maxDis - v.minDis) + v.minDis, 7)
    },

    varValToDisVal: function (v, val) {
      val = val === undefined ? v.val : val
      let valClamped = Utils.clamp(val, Math.min(v.min, v.max), Math.max(v.min, v.max))
      let vData = (valClamped - v.min) / (v.max - v.min); //lua ratio
      return Utils.roundDec(vData * (v.maxDis - v.minDis) + v.minDis, 7)
    },

    isDisValDefault: function (v) {
      return Math.abs(v.valDis - v.defaultValDis) <= 0.000001
    },

    getVariablesConfig: function (variables) {
      let configObj = {}
      for (var i in variables) {
        let v = variables[i]
        let vDis = (v.valDis - v.minDis) / (v.maxDis - v.minDis)
        v.val = Utils.roundDec(vDis * (v.max - v.min) + v.min, 7)
        configObj[v.name] = v.val
      }
      return configObj
    },

    getVariablesWithNonDefaultValuesConfig: function (variables) {
      let configObj = {}
      for (var i in variables) {
        let v = variables[i]
        if (!v.configDefaultDefined && this.isDisValDefault(v)) {
          continue
        }
        let vDis = (v.valDis - v.minDis) / (v.maxDis - v.minDis)
        v.val = Utils.roundDec(vDis * (v.max - v.min) + v.min, 7)
        configObj[v.name] = v.val
      }
      return configObj
    },

    loadConfigList: function () {
      let d = $q.defer()

      bngApi.engineLua('extensions.core_vehicle_partmgmt.getConfigList()', (configs) => {
        //var list = configs.map((elem) => elem.slice(0, -3))
        configs = Array.isArray(configs) ? configs : []
        d.resolve(configs)
      })

      return d.promise
    },

    treeSort: function _treeSort_ (a, b) {
      if (a.parts) {
        a.parts.sort(_treeSort_)
        if (!b.parts) return 1
      }

      if (b.parts) {
        b.parts.sort(_treeSort_)
        if (!a.parts) return -1
      }

      return a.name.localeCompare(b.name)
    }
  }

  // return service
}])

.controller('VehicleconfigCtrl', ['$scope', '$state', function ($scope, $state) {
  const tabs = ['menu.vehicleconfig.parts', 'menu.vehicleconfig.tuning', 'menu.vehicleconfig.color', 'menu.vehicleconfig.save', 'menu.vehicleconfig.debug']

  currentTabUpdate()

  function currentTabUpdate() {
    if ($state.current.name.startsWith("menu.vehicleconfig.vue")) {
      const wrapname = "menu.vehicleconfig.vue-angular"
      if ($state.current.name === wrapname) {
        $state.go("menu.vehicleconfig.vue")
      } else if ($state.current.name.startsWith(wrapname)) {
        $state.go($state.current.name.replace(".vue-angular.", ".vue."))
      }
      return
    }
    const current = tabs.indexOf($state.current.name)
    $scope.model = {selected: current === -1 ? 0 : current }
  }

  $scope.$watch("$state.current.name", currentTabUpdate);
}])
/**
 * @ngdoc controller
 * @name beamng.stuff:Vehicleconfig_config
 * @description The controller for the Vehicle Config entry. It handles all tabs in the view.
 * @require $scope
 * @require beamng.stuff:bngApi
 * @require beamng.stuff:VehicleConfig
**/
.controller('Vehicleconfig_parts', ['$filter', '$scope', '$window', 'RateLimiter', 'VehicleConfig',
function ($filter, $scope, $window, RateLimiter, VehicleConfig) {
  let vm = this

  // Multi Part Highlighting

  // function used to flatten objects
  function iterateParts (obj, func) {
    func(obj)
    if (obj.parts) {
      obj.parts.forEach(function (parts) {
        iterateParts(parts, func)
      })
    }
  }

  // Highlights the selected part and its subparts
  vm.highlightParts = function(selectedPart) {
    // Highlight part and subparts
    iterateParts(selectedPart, function (obj) {
      obj.highlight = selectedPart.highlight
    })

    // Get all parts highlights and return them
    let flattenedParts = {}
    for (var key in vm.d.data) {
      let part = vm.d.data[key]

      iterateParts(part, function(obj) {
        if (obj.val !== '') {
          flattenedParts[obj.val] = obj.highlight
        }
      })
    }
    //console.log("highlightparts: ", flattenedParts)
    bngApi.engineLua(`extensions.core_vehicle_partmgmt.highlightParts(${bngApi.serializeToLua(flattenedParts)})`)
  }

  $scope.$on('VehicleFocusChanged', function(event, data) {
    bngApi.engineLua('extensions.core_vehicle_partmgmt.sendDataToUI()')
  })

  $scope.$on('VehicleJbeamIoChanged', function(event, data) {
    bngApi.engineLua('extensions.core_vehicle_partmgmt.sendDataToUI()')
  })

  // LICENSE PLATE STUFF
  vm.licensePlate = ''

  let getLicensePlate = function () {
    bngApi.engineLua('core_vehicles.getVehicleLicenseText(getPlayerVehicle(0))', function (str) {
      $scope.$evalAsync(() => { vm.licensePlate = str; })
    })
  }
  // --------------------------------------- BEAMMP --------------------------------------- //

  vm.isMPSession = false;
  bngApi.engineLua('MPCoreNetwork.isMPSession()', function (str) {
    $scope.$evalAsync(() => { vm.isMPSession = str; });
  });

  // --------------------------------------- BEAMMP --------------------------------------- //
  getLicensePlate()

  vm.applyLicensePlateDebounced  = RateLimiter.debounce(() => {
    if(vm.applyPartChangesAutomatically) {
      vm.applyLicensePlate()
    }
  }, 500)

  vm.applyLicensePlate = function () {
    bngApi.engineLua(`core_vehicles.setPlateText("${vm.licensePlate}")`)
  }

  vm.applyRandomLicensePlate = function () {
    bngApi.engineLua(`core_vehicles.setPlateText(core_vehicles.regenerateVehicleLicenseText(getPlayerVehicle(0)),nil,nil,nil)`)
    getLicensePlate()
  }
  // --------------

  vm.stopPropagation = function(event) {
    event.stopPropagation()
  }

  vm.open = {}
  vm.d = {}
  vm.stickyPartSelection = false
  vm.selectSubParts = true
  vm.applyPartChangesAutomatically = true
  vm.simple = false
  vm.displayNames = false
  vm.showAuxiliary = !beamng.shipping
  vm.partSearchString = ''
  vm.partSearchQuery = {}
  vm.searchMode = false
  vm.searchResString = ''
  vm.searchResults = []
  vm.partsChanged = false
  vm.skipLicGen = false

  vm.searchHistory = []
  vm.searchHistoryPosition = 0
  vm.searchHistoryBrowsing = false

  let currentConfig = null

  vm.emptyFront = function (option) {
    if (option.description === 'Empty') {
      return 0
    }
  }

  // Selects part (highlight part temporarily, like on hovering part) and its subparts
  vm.selectParts = function (event, selectedPart) {
    event.stopPropagation()

    // Little hacky way to prevent the UI from automatically selecting a slot and thus highlighting a part, after the user selects a part
    // relatedTarget and sourceCapabilities will be null when the UI automatically selects the slot as the FocusEvent wasn't generated by user input
    // In case this stops working, try using "event.currentTarget"
    if (event instanceof FocusEvent && event.relatedTarget === null && event.sourceCapabilities === null) return

    let flattenedParts = {}

    if (vm.selectSubParts) {
      iterateParts(selectedPart, function (obj) {
        flattenedParts[obj.val] = true
      })
    }
    else {
      flattenedParts[selectedPart.val] = true
    }

    //console.log('selectParts: ', selectedPart, flattenedParts)
    bngApi.engineLua(`extensions.core_vehicle_partmgmt.selectParts(${bngApi.serializeToLua(flattenedParts)})`)
  }

  vm.deselectPart = function (sticky) {
    if (vm.d && vm.d.data && vm.d.data.length > 0) {
      // console.debug(`Reset part selection`)
      // bngApi.engineLua('extensions.core_vehicle_partmgmt.showHighlightedParts()')
      bngApi.engineLua(`extensions.core_vehicle_partmgmt.showHighlightedParts()`)
    }
  }

  vm.partConfigChanged = function(part) {
    if(!vm.applyPartChangesAutomatically) {
      // only mark as changed
      part.changed = true
      vm.partsChanged = true
      return
    }
    vm.write()
  }

  $scope.settingsChanged = function() {
    bngApi.engineLua('settings.getValue("SkipGenerateLicencePlate")', (data) => {
      vm.skipLicGen = data
    })
  }
  $scope.settingsChanged()

  vm.applySettingChanged = function() {
    localStorage.setItem('applyPartChangesAutomatically', JSON.stringify(vm.applyPartChangesAutomatically))
  }

  vm.write = function () {
    let newConfig = VehicleConfig.generateConfig(vm.d.data)
    // console.debug(`Setting configuration`, newConfig)
    setTimeout(() => {
      // make async so html has more time to update render parts
      bngApi.engineLua(`extensions.core_vehicle_partmgmt.setPartsConfig(${bngApi.serializeToLua(newConfig)})`)
    })
    //console.time('waitingForLua')
  }

  vm.reset = function () {
    bngApi.engineLua(`extensions.core_vehicle_partmgmt.resetPartsToLoadedConfig()`)
  }
  // --------------------------------------- BEAMMP --------------------------------------- //

  vm.mpapply = function () {
    bngApi.engineLua("MPVehicleGE.sendVehicleEdit(be:getPlayerVehicle(0):getID())");
  }
  // --------------------------------------- BEAMMP --------------------------------------- //

  function calcTreesync (config) {
    currentConfig = config
    vm.partsChanged = false
    //console.log("config = ", config)
    let tree = VehicleConfig.generateTree(config, vm.simple)
    tree.sort(VehicleConfig.treeSort)
    let configArray = []
    let variable_categories = {}

    for (var o in config.variables) {
      let v = config.variables[o]
      if (!variable_categories[v.category])
        variable_categories[v.category] = true
      //v.defaultValDis = VehicleConfig.defaultVarValToDisVal(v)
      let defaultVal = config.defaults.vars[o]
      if (defaultVal === undefined) {
        defaultVal = v.default
        v.configDefaultDefined = false
      }
      else {
        v.configDefaultDefined = true
      }
      v.defaultValDis = VehicleConfig.varValToDisVal(v, defaultVal)
      v.valDis = VehicleConfig.varValToDisVal(v)
      configArray.push(v)
    }
    // console.table(configArray)

    vm.d.data = tree
    vm.d.variables = $filter('orderBy')(configArray, 'name')
    vm.d.variable_categories = Object.keys(variable_categories)
    // loadOpenSlots()

    //console.log('tree = ', tree)
  }

  function calcTree (config) {
    //console.timeEnd('waitingForLua')

    $scope.$evalAsync(function () {
      calcTreesync(config)
      //console.log("tree = ", vm.d.data)
      filterTree()
    })
  }

  let queryModes = {
    "or": function(a, b) { return a || b; },
    "and": function(a, b) { return a && b; },
  }

  // applies filters against mod info
  function filterPartByName(partName, queryArgs) {
    let part = currentConfig.availableParts[partName]
    if(!part) return

    let modMatch = false
    if(queryArgs['mod'] !== undefined) {
      if(part.modName !== undefined)    modMatch = modMatch || part.modName.toLowerCase().indexOf(queryArgs['mod']) != -1
      if(part.modTagLine !== undefined) modMatch = modMatch || part.modTagLine.toLowerCase().indexOf(queryArgs['mod']) != -1
      if(part.modTitle !== undefined)   modMatch = modMatch || part.modTitle.toLowerCase().indexOf(queryArgs['mod']) != -1
    }

    if(queryArgs['author'] !== undefined) {
      if(part.authors !== undefined)    modMatch = modMatch || part.authors.toLowerCase().indexOf(queryArgs['author']) != -1
    }

    return modMatch
  }

  function filterTreeNode(searchResults, treeNode, queryArgs) {

    // match this part first
    let matched = false
    if(queryArgs['mode'] == 'or') matched = false
    else if(queryArgs['mode'] == 'and') matched = true

    if(queryArgs['name'] && treeNode.name !== undefined) matched = queryModes[queryArgs['mode']](matched, treeNode.name.toLowerCase().indexOf(queryArgs['name']) != -1)
    if(queryArgs['description'] && treeNode.description !== undefined) matched = queryModes[queryArgs['mode']](matched, treeNode.description.toLowerCase().indexOf(queryArgs['description']) != -1)
    if(queryArgs['slot'] && treeNode.name !== undefined) matched = queryModes[queryArgs['mode']](matched, treeNode.name.toLowerCase().indexOf(queryArgs['slot']) != -1)
    //if(!matched && treeNode.name !== undefined) matched = matched || treeNode.name.toLowerCase().indexOf(queryArgs) != -1
    if(!matched) {
      for (var optIdx in treeNode.options) {
        let option = treeNode.options[optIdx]
        if (option.isAuxiliary && !vm.showAuxiliary) continue;
        if (queryArgs['name'] && option.name !== undefined) matched = queryModes[queryArgs['mode']](matched, option.name.toLowerCase().indexOf(queryArgs['name']) != -1)
        if (!matched && queryArgs['description'] && option.description !== undefined) matched = queryModes[queryArgs['mode']](matched, option.description.toLowerCase().indexOf(queryArgs['description']) != -1)
        if (!matched && queryArgs['partname'] && option.val !== undefined) matched = queryModes[queryArgs['mode']](matched, option.val.toLowerCase().indexOf(queryArgs['partname']) != -1)
        if (matched) break;
      }
    }

    // mod filters
    if(queryArgs['mod'] || queryArgs['author']) {
      filterPartByName(treeNode.val, queryArgs)
      for (var optIdx in treeNode.options) {
        let option = treeNode.options[optIdx]
        if (option.isAuxiliary && !vm.showAuxiliary) continue;
        if(option.val !== undefined) {
          matched = queryModes[queryArgs['mode']](matched,
            filterPartByName(option.val, queryArgs)
          )
        }
      }
    }

    if(matched) searchResults.push(treeNode)

    // match child parts
    for (var partIdx in treeNode.parts) {
      filterTreeNode(searchResults, treeNode.parts[partIdx], queryArgs)
    }
  }

  function saveSearchHistory() {
    localStorage.setItem('partSearchHistory', JSON.stringify(vm.searchHistory))
  }

  function loadSearchHistory() {
    let res = localStorage.getItem('partSearchHistory')
    if(res !== null) {
      vm.searchHistory = JSON.parse(res) || []
    }
  }

  function filterTree() {
    let queryString = vm.partSearchString.toLowerCase()
    let queryArgs = {}
    queryArgs['mode'] = 'or'
    vm.searchResString = ''

    // default: search all
    if (queryString.indexOf(':') == -1) {
      queryArgs['description'] = queryString
    } else {
      let parsedargs = 0
      let args = queryString.split(/[ ,]+/)
      for(i = 0; i < args.length; i++) {
        if (args[i].indexOf(':') != -1) {
          let args2 = args[i].split(/:/)
          if(args2.length == 2 && args2[1].trim() != '') {
            queryArgs[args2[0]] = args2[1]
            parsedargs++
          } else {
            vm.searchResString += 'invalid search format: ' + args[i] + '\n'
          }
        } else {
          vm.searchResString += 'unknown search argument: ' + args[i] + '\n'
        }
      }
      if(parsedargs > 1) queryArgs['mode'] = 'and'
    }

    vm.searchResults = []
    if(queryString != '' && queryString.length < 3) {
      vm.searchResString = "Search term too short"
      return
    }
    vm.partSearchQuery = {
      ...queryArgs,
      highlight: queryArgs.description || queryArgs.name || null,
    }

    // add to search history
    if (queryString.trim() !== '' && !vm.searchHistoryBrowsing) {
      let lastHistory = vm.searchHistory[vm.searchHistory.length - 1] || ""
      if(queryString.indexOf(lastHistory) != -1) {
        vm.searchHistory[vm.searchHistory.length - 1] = queryString
      } else if(lastHistory.indexOf(queryString) != -1) {
        // removing chars do not change the last item
      } else {
        vm.searchHistory.push(queryString)
      }
      saveSearchHistory()
      //console.log("Search history: ", vm.searchHistory)
    }


    //console.log("queryArgs = ", queryArgs)

    for (var partIdx in vm.d.data) {
      let part = vm.d.data[partIdx]
      filterTreeNode(vm.searchResults, part, queryArgs)
    }
    if(vm.searchResults.length == 0) {
      vm.searchResString = "No results found"
    }
    //console.log("> searchResults: ", vm.searchResults)
  }

  vm.recalcTree = function () {
    calcTree(currentConfig)
  }
  vm.startSearch = function() {
    vm.searchMode = true
  }
  vm.stopSearch = function() {
    vm.partSearchString = ''
    vm.partSearchQuery = {}
    vm.searchResults = []
    vm.searchMode = false
  }

  vm.onKeyDown = function(event) {
    //console.log("Search onKeyDown: ", event)
    if(vm.searchHistory.length > 0 && event.key == "ArrowDown") {
      vm.searchHistoryBrowsing = true
      vm.searchHistoryPosition++
      if(vm.searchHistoryPosition >= vm.searchHistory.length) vm.searchHistoryPosition = 0
      vm.partSearchString = vm.searchHistory[vm.searchHistoryPosition]
      filterTree()
      event.preventDefault()

    } else if(vm.searchHistory.length > 0 && event.key == "ArrowUp") {
      vm.searchHistoryBrowsing = true
      vm.searchHistoryPosition--
      if(vm.searchHistoryPosition < 0) vm.searchHistoryPosition = vm.searchHistory.length - 1
      vm.partSearchString = vm.searchHistory[vm.searchHistoryPosition]
      filterTree()
      event.preventDefault()

    } else if(event.key == "k" && event.ctrlKey == true) {
      console.log("Search history cleaned")
      localStorage.removeItem('partSearchHistory')
      vm.searchHistory = []
      vm.searchHistoryPosition = 0
      vm.searchHistoryBrowsing = false
      event.preventDefault()

    } else {
      vm.searchHistoryBrowsing = false
    }
  }

  vm.filterChanged = function() {
    if (!vm.searchMode && vm.partSearchString)
      vm.startSearch();
    filterTree()
  }
  $scope.$on('VehicleConfigChange', (event, config) => calcTree(config))

  $scope.$on('$destroy', () => {
    vm.deselectPart(false)
  })

  // Initial data load
  bngApi.engineLua('extensions.core_vehicle_partmgmt.sendDataToUI()')
  loadSearchHistory()

  let applyPartChangesAutomatically = localStorage.getItem('applyPartChangesAutomatically')
  if(applyPartChangesAutomatically !== null) {
    vm.applyPartChangesAutomatically = JSON.parse(applyPartChangesAutomatically) || false
  }
}])
.filter('highlightResults', function($sce) {
  return function(text, search) {
    if (!search) {
      return $sce.trustAsHtml(text)
    }
    return $sce.trustAsHtml(unescape(escape(text).replace(new RegExp(escape(search), 'gi'), '<span class="highlightResults">$&</span>')))
  }
})
.controller('Vehicleconfig_tuning', ["RateLimiter", "VehicleConfig", "$scope", "$filter", function (RateLimiter, VehicleConfig, $scope, $filter) {
  let vm = this

  vm.open = {}
  vm.openRuntime = {}
  vm.d = {}
  vm.liveVariablesUpdate = false

  // --------------------------------------- BEAMMP --------------------------------------- //

  
  vm.isMPSession = false;
  bngApi.engineLua('MPCoreNetwork.isMPSession()', function (str) {
    $scope.$evalAsync(() => { vm.isMPSession = str; });
  });

  // --------------------------------------- BEAMMP --------------------------------------- //


  let autoUpdateVariables = RateLimiter.debounce(() => {
    // console.debug(`Writing vehicle configuration (live update)`)
    vm.write()
  }, 200)

  vm.addSpacer = (function () {
    let lastCategory
    return (cat) => {
      let res = cat !== lastCategory
      lastCategory = cat
      return res
    }
  })()

  vm.write = function () {
    setTimeout(() => {
      // make async so html has more time to update render parts
      let vars = VehicleConfig.getVariablesWithNonDefaultValuesConfig(vm.d.variables)
      bngApi.engineLua(`extensions.core_vehicle_partmgmt.setConfigVars(${bngApi.serializeToLua(vars)})`)
    })
  }

  vm.tuningVariablesChanged = function () {
    if (vm.liveVariablesUpdate)
      autoUpdateVariables()
  }

  vm.isDisValDefault = function(v) {
    return VehicleConfig.isDisValDefault(v)
  }

  vm.resetVar = function (v) {
    v.valDis = v.defaultValDis
    vm.tuningVariablesChanged(); // got to call this, since the change didn't come from the inputs.
  }

  vm.resetVars = function () {
    vm.d.variables.forEach((x) => {
      x.valDis = x.defaultValDis
    })
    vm.tuningVariablesChanged(); // got to call this, since the change didn't come from the inputs.
  }

  bngApi.engineLua('extensions.core_vehicle_partmgmt.sendDataToUI()')

  function calcTree (config) {
    $scope.$evalAsync(function () {
      let configArray = []
      let variable_categories = {}

      for (var o in config.variables) {
        let v = config.variables[o]
        //if the variable wants to be hidden in the UI, skip it
        if (v.hideInUI === true)
           continue;
        if (!variable_categories[v.category])
          variable_categories[v.category] = true
        //v.defaultValDis = VehicleConfig.defaultVarValToDisVal(v)
        let defaultVal = config.defaults.vars[o]
        if (defaultVal === undefined) {
          defaultVal = v.default
          v.configDefaultDefined = false
        }
        else {
          v.configDefaultDefined = true
        }
        v.defaultValDis = VehicleConfig.varValToDisVal(v, defaultVal)
        v.valDis = VehicleConfig.varValToDisVal(v)
        configArray.push(v)
      }
      // console.table(configArray)

      vm.d.variables = $filter('orderBy')(configArray, 'name')
      vm.d.variable_categories = Object.keys(variable_categories)
      // loadOpenSlots()
    })
  }

  $scope.$on('VehicleFocusChanged', () => bngApi.engineLua('extensions.core_vehicle_partmgmt.sendDataToUI()'))
  $scope.$on('VehicleConfigChange', (event, config) => calcTree(config))


  let liveVariablesUpdate = localStorage.getItem('applyTuningChangesAutomatically')
  if(liveVariablesUpdate !== null) {
    vm.liveVariablesUpdate = JSON.parse(liveVariablesUpdate) || false
  }

  vm.applySettingChanged = function() {
    localStorage.setItem('applyTuningChangesAutomatically', JSON.stringify(vm.liveVariablesUpdate))
  }


  // advanced wheel debug
  vm.awdData = null
  vm.awdShow = false

  let streamsList = ['advancedWheelDebugData']
  StreamsManager.add(streamsList)

  function register() {
    bngApi.activeObjectLua('extensions.advancedwheeldebug.registerDebugUser("advancedWheelDebugApp", true)')
  }

  register()

  $scope.$on('streamsUpdate', function (event, data) {
    $scope.$evalAsync(function () {
      vm.awdData = data.advancedWheelDebugData && data.advancedWheelDebugData.length > 0 ? data.advancedWheelDebugData : null
      if (vm.awdShow && !vm.awdData)
        vm.awdShow = false
    })
  })

  $scope.$on('VehicleReset', register)
  $scope.$on('VehicleChange', register)

  $scope.$on('$destroy', function () {
    StreamsManager.remove(streamsList)
    bngApi.activeObjectLua('extensions.advancedwheeldebug.registerDebugUser("advancedWheelDebugApp", false)')
  })
  // /advanced wheel debug
}])

.controller('Vehicleconfig_color', ["$scope", function ($scope) {
  let vm = this
  vm.updateColor = function (index, value) {
    bngApi.engineLua(`core_vehicle_colors.setVehicleColor(${index}, "${value}");`)
  }
  $scope.selectorIndex = -1

  function fetchDefinedColors () {
    vm.color = ['White', 'White', 'White']
    $scope.selectorIndex = -1

    bngApi.engineLua('getVehicleColor()', res => {
      vm.color[0] = res || vm.color[0]
      $scope.selectorIndex = 0
    })

    for (var i=1; i<vm.color.length; i++) {
      // yes this is needed, since otherwise we crate a function inside the for loop and thanks to clojure i would always be 4
      // bngApi.engineLua(`getVehicleColorPalette(${i-1})`, ((id) =>
      //   (res) => {
      //     vm.color[id] = res || vm.color[id]
      //   }
      // )(i))
      const idx = i;
      bngApi.engineLua(`getVehicleColorPalette(${i-1})`,
        res => vm.color[idx] = res || vm.color[idx]
      )
    }
  }

  vm.carColorPresets = {}

  function getVehicleColors () {
    bngApi.engineLua('core_vehicles.getCurrentVehicleDetails()', (data) => {
      if (data.model !== undefined && data.model.paints !== undefined) {
        $scope.$evalAsync(() => {
          let colors = {}
          for (var paintName in data.model.paints) {
            let paint = data.model.paints[paintName]
            let color = paint.baseColor[0] + " " + paint.baseColor[1] + " " + paint.baseColor[2] + " " + paint.baseColor[3] + " " + paint.metallic + " " + paint.roughness + " " + paint.clearcoat + " " + paint.clearcoatRoughness
            colors[paintName] = color
          }
          vm.carColorPresets = colors
        })
      }
    })
    fetchDefinedColors();
  }

  getVehicleColors()

  $scope.$on('VehicleChange', getVehicleColors)
  $scope.$on('VehicleFocusChanged', getVehicleColors)
  $scope.$on('VehicleChangeColor', fetchDefinedColors)
}])

.controller('Vehicleconfig_save', ["$scope", "$mdDialog", "VehicleConfig", function ($scope, $mdDialog, VehicleConfig) {
  let vm = this
  vm.saveThumbnail = true

  vm.openConfigFolderInExplorer = function(){
    bngApi.engineLua('extensions.core_vehicle_partmgmt.openConfigFolderInExplorer()')
  }

  vm.save = function (configName) {
    bngApi.engineLua(`extensions.core_vehicle_partmgmt.saveLocal("${configName}.pc")`)

    if (vm.saveThumbnail == true) {
      bngApi.engineLua(`extensions.load('util_screenshotCreator'); util_screenshotCreator.startWork({selection="${configName}"})`)
    }
  }

  vm.validName = function (testName) {
    if (!testName || /[<>:"/\\|?*]/.test(testName)) {
      return false
    }
    if (/^ +| +$/.test(testName)) {
      testName = testName.replace(/^ +| +$/g, "")
    }
    if (!testName) {
      return false
    }
    return true
  }

  /**
   * @ngdoc method
   * @name load
   * @methodOf beamng.stuff:VehicleconfigController
   *
   * @description
   * Loads an available configuration from a file.
   */
  vm.load = function ($event, config) {
    loadedConfig = config
    bngApi.engineLua(`extensions.core_vehicle_partmgmt.loadLocal("${config}.pc")`)
    $event.stopPropagation()
  }

  vm.remove = function ($event, config) {

    loadedConfig = config
    bngApi.engineLua(`extensions.core_vehicle_partmgmt.removeLocal("${config}")`)
    getConfigList()
    if ($event)
      $event.stopPropagation()


    // showConfirm()
    // // Confirmation dialog when deleting configuration
    // let confirm
    // function showConfirm() {
    //   confirm = $mdDialog.confirm({
    //     title: "Are you sure?",
    //     content: "This will permanently remove the configuration. You will not be able to recover it.",
    //     ok: "Delete permanently",
    //     cancel: "Cancel"
    //   })
    //   $mdDialog
    //     .show(confirm).then(
    //       function() { removeConfig() },
    //       function() { }
    //   )
    // }

    // function removeConfig () {
    //   loadedConfig = config
    //   bngApi.engineLua(`extensions.core_vehicle_partmgmt.removeLocal("${config}")`)
    //   getConfigList()
    //   $event.stopPropagation()
    // }
  }

  vm.configExists = function(name) {
    for(var i = 0; i<vm.configList.length; i++) {
      if(vm.configList[i].name === name)
        return true
    }
    return false
  }

  function getConfigList () {
    VehicleConfig.loadConfigList().then((list) => {
      vm.configList = list
    })
  }

  $scope.$on('VehicleChange', getConfigList)
  $scope.$on('VehicleFocusChanged', getConfigList)
  $scope.$on('VehicleconfigSaved', getConfigList)
  getConfigList()

}])


.controller('Vehicleconfig_debug', ['$scope',
function ($scope) {
  let vm = this

  vm.state = {}
  vm.geState = {physicsEnabled: true, debugSpawnEnabled: false}
  vm.cameraSpeed = 0
  vm.canApplyState = true
  vm.partsSelectedSearchTerm = ''

  bngApi.engineLua("simTimeAuthority.getPause()", (state) => {
    vm.geState.physicsEnabled = !state
  })

  bngApi.engineLua("core_vehicle_manager.getDebug()", (state) => {
    vm.geState.debugSpawnEnabled = !!state
  })

  vm.update = () => {
    bngApi.engineLua("core_camera.getSpeed()", (speed) => {
      vm.cameraSpeed = Number(speed)
      bngApi.activeObjectLua('bdebug.requestState()')
    })
  }
  vm.setCameraSpeed = (cameraSpeed) => {
    vm.cameraSpeed = cameraSpeed
    bngApi.engineLua( 'core_camera.setSpeed(' + cameraSpeed + ')' )
  },

  vm.applyState = () => {
    if (vm.canApplyState) {
      bngApi.activeObjectLua(`bdebug.setState( ${bngApi.serializeToLua(vm.state)} )`)
    }
  }

  vm.partsSelectedChanged = () => {
    bngApi.activeObjectLua(`bdebug.partsSelectedChanged()`)
  }

  vm.partsSelectedchecked = () => {
    if (vm.state.vehicle == undefined) {
      return true
    }

    return vm.state.vehicle.partsSelected.length === vm.state.vehicle.parts.length
  }

  vm.partsSelectedIndeterminate = () => {
    if (vm.state.vehicle == undefined) {
      return false
    }

    return vm.state.vehicle.partsSelected.length !== 0 &&
    vm.state.vehicle.partsSelected.length !== vm.state.vehicle.parts.length
  }

  vm.partsSelectedClicked = () => {
    if (vm.state.vehicle == undefined) {
      return
    }

    if (vm.state.vehicle.partsSelected.length === vm.state.vehicle.parts.length) {
      vm.state.vehicle.partsSelected = []
    }
    else {
      vm.state.vehicle.partsSelected = Array.from({length: vm.state.vehicle.parts.length}, (_, i) => i + 1)
    }
    vm.applyState()
    vm.partsSelectedChanged()
  }

  vm.syncSelectedPartsWithPartsList = () => {
    bngApi.activeObjectLua(`bdebug.syncSelectedPartsWithPartsList()`)
  }

  vm.showOnlySelectedPartsMeshChanged = () => {
    bngApi.activeObjectLua(`bdebug.showOnlySelectedPartsMeshChanged()`)
  }

  vm.setMeshVisibility = (vis) => {
    bngApi.engineLua(`core_vehicles.setMeshVisibility(${bngApi.serializeToLua(vis)})`)
  }

  $scope.$on('BdebugUpdate', (_, debugState) => {
    // All this to workaround a bug with slider not updating
    $scope.$applyAsync(() => {
      if (vm.state.vehicle) {
        vm.canApplyState = false

        let mode = debugState.vehicle.beamVisMode - 1
        vm.state.vehicle.beamVisModes[mode].rangeMin = -Number.MAX_VALUE
        vm.state.vehicle.beamVisModes[mode].rangeMax = Number.MAX_VALUE

        // $scope.$digest()
      }

      vm.state = debugState
      // $scope.$digest()

      vm.canApplyState = true
    })
  })
  bngApi.activeObjectLua(`bdebug.requestState()`)

  $scope.$on('physicsStateChanged',  (_, state) => {
    vm.geState.physicsEnabled = !!state
  })

  $scope.$on('debugSpawnChanged',  (_, state) => {
    vm.geState.debugSpawnEnabled = !!state
  })

  vm.setCameraFov = () => {
    bngApi.engineLua(`core_camera.setFOV(0, ${vm.state.fov});`)
  },

  vm.controls = {
    vehicle: {
      buttonGroup_1: [
        { label: 'ui.debug.vehicle.loadDefault', action: () => { bngApi.engineLua('core_vehicles.loadDefault()');} },
        { label: 'ui.debug.vehicle.spawnNew', action: () => { bngApi.engineLua('core_vehicles.spawnDefault()'); } },
        { label: 'ui.debug.vehicle.removeCurrent', action: () => { bngApi.engineLua('core_vehicles.removeCurrent()'); } },
        { label: 'ui.debug.vehicle.cloneCurrent', action: () => { bngApi.engineLua('core_vehicles.cloneCurrent()'); } },
        { label: 'ui.debug.vehicle.removeAll', action: () => { bngApi.engineLua('core_vehicles.removeAll()'); } },
        { label: 'ui.debug.vehicle.removeOthers', action: () => { bngApi.engineLua('core_vehicles.removeAllExceptCurrent()'); } },
        { label: 'ui.debug.vehicle.resetAll', action: () => { bngApi.engineLua('resetGameplay(-1)'); } },
        { label: 'ui.debug.vehicle.reloadAll', action: () => { bngApi.engineLua('core_vehicle_manager.reloadAllVehicles()'); } }
      ],

      toggleGroup_1: [
        { label: 'ui.debug.activatePhysics', key: 'physicsEnabled', onChange: () => { bngApi.engineLua(`simTimeAuthority.togglePause()`) } },
        { label: 'ui.debug.debugSpawnEnabled', key: 'debugSpawnEnabled', onChange: () => { bngApi.engineLua(`core_vehicle_manager.toggleDebug()`) } }
      ],
    },

    jbeamvis: {
      buttonGroup_1: [
        { label: 'ui.debug.vehicle.toggleVis', action: () => { bngApi.activeObjectLua('bdebug.toggleEnabled()');} },
        { label: 'ui.debug.vehicle.clearSettings', action: () => { bngApi.activeObjectLua('bdebug.resetModes()');} }
      ],
      meshVisButtonGroup: [
        { label: '0%', action: () => { vm.setMeshVisibility(0) } },
        { label: '25%', action: () => { vm.setMeshVisibility(0.25) } },
        { label: '50%', action: () => { vm.setMeshVisibility(0.5) } },
        { label: '75%', action: () => { vm.setMeshVisibility(0.75) } },
        { label: '100%', action: () => { vm.setMeshVisibility(1.0) } },
      ]
    },

    effects: {
      buttonGroup_1: [
        { label: 'ui.debug.effects.toggleFreeCamera', action: () => { bngApi.engineLua('commands.toggleCamera()');} }
      ]
    },

    terrain: {
      buttonGroup_1: [
        { label: 'ui.debug.terrain.groundmodel', action: () => {bngApi.engineLua('extensions.load("util_groundModelDebug") util_groundModelDebug.openWindow()');}}
      ]
    }
  }
  vm.disableVehicleButtons = false

  $scope.$on('GameStateUpdate', (_, gamestate) => {
    vm.disableVehicleButtons = gamestate.state.toLowerCase().indexOf('scenario') !== -1
  })

  bngApi.engineLua('core_gamestate.requestGameState();')
}])
