'use strict'

angular.module('beamng.stuff')
.controller('MenuController', ['$rootScope', '$scope', 'Utils', '$state', '$timeout', 'mdx', function ($rootScope, $scope, Utils, $state, $timeout, mdx) {
  let vm = this

  let availableMenuEntries = [
    {
      translateid: 'ui.inputActions.menu.menu_item_back.title',
      icon: 'arrow_back',
      class: "dashBrdButtonStart dashBrdButtonTopLeft",
      soundClass: "bng_back_hover_generic",
      targetState: '',
      action: () => {
        $rootScope.$broadcast('MenuToggle')
      },
      onlyIngame: false,
      gamepadNavigateable: false,
      navigationDisabled: true,
    },
    {
      translateid: 'ui.dashboard.menu',
      iconSVG: '/ui/modules/menu/icon-gamemodes.svg',
      targetState: 'menu.mainmenu',
      onlyIngame: false,
    },
    {
      translateid: 'ui.playmodes.career',
      iconSVG: '/ui/modules/menu/icon-gamemodes.svg',
      targetState: 'menu.careerPause',
      onlyIngame: true,
      isVisible: () => $scope.inCareer,
    },
    {
      translateid: 'ui.playmodes.multiplayer',
      iconSVG: '/ui/modules/multiplayer/icons/account-multiple.svg',
      targetState: 'menu.multiplayerPause',
      onlyIngame: true,
      isVisible: () => $scope.isMPSession,
    },
    // {
    //   translateid: 'ui.mainmenu.garage',
    //   iconSVG: '/ui/modules/mainmenu/drive/icons/garage.svg',
    //   targetState: '',
    //   action: () => {
    //     bngApi.engineLua("career_modules_playerDriving.onResetGameplay()");
    //   },
    //   onlyIngame: true,
    //   isVisible: () => $scope.inCareer,
    //   blackListStates: ['scenario','mission','garage'],
    // },
    {
      translateid: 'ui.dashboard.bigmap',
      //iconSVG: '/ui/modules/menu/icon-map.svg',
      icon: 'map',
      targetState: 'menu.bigmap',
      blackListStates: ['scenario','mission','garage'],
      onlyIngame: true,
      isVisible: () => !$scope.inCareer || ($scope.inCareer && $state.gamestate.name!=='garage')
    },
    {
      translateid: 'ui.dashboard.gameContext',
      iconSVG: '/ui/modules/menu/icon-flag.svg',
      targetState: 'menu.careermission',
      isVisible: () => vm.missionEnabled,
      blackListStates: ['scenario','garage'],
      onlyIngame: true,
    },
    {
      translateid: 'ui.dashboard.mods',
      iconSVG: '/ui/modules/menu/icon-puzzle.svg',
      targetState: 'menu.mods.local',
      blackListStates: ['scenario','mission','garage'],
      substate: 'menu.mods',
      onlyIngame: true,
    },
    {
      translateid: 'ui.dashboard.vehicles',
      iconSVG: '/ui/modules/menu/icon-car.svg',
      targetState: 'menu.vehicles',
      blackListStates: ['scenario','mission','garage','career'],
      substate: 'menu.vehicles',
      onlyIngame: true,
    },
    {
      translateid: 'ui.dashboard.vehicleconfig',
      iconSVG: '/ui/modules/menu/icon-engine.svg',
      targetState: 'menu.vehicleconfig.parts',
      blackListStates: ['scenario','mission','garage','career'],
      substate: 'menu.vehicleconfig',
      onlyIngame: true,
    },
    {
      translateid: 'ui.dashboard.environment',
      iconSVG: '/ui/modules/menu/icon-weather.svg',
      targetState: 'menu.environment',
      blackListStates: ['scenario','mission','garage'],
      isVisible: () => !$scope.inCareer,
      onlyIngame: true,
    },
    {
      translateid: 'ui.dashboard.photomode',
      iconSVG: '/ui/modules/menu/icon-photo.svg',
      targetState: 'menu.photomode',
      onlyIngame: true,
      blackListStates: ['garage'],
    },
    {
      translateid: 'ui.dashboard.appedit',
      iconSVG: '/ui/modules/menu/icon-hud.svg',
      targetState: 'menu.appedit',
      onlyIngame: true,
      blackListStates: ['scenario'],
    },
    {
      translateid: 'ui.dashboard.options',
      iconSVG: '/ui/modules/menu/icon-adjust.svg',
      targetState: 'menu.options.graphics',
      substate: 'menu.options',
      onlyIngame: true,
    },
  ]

  for(let m of availableMenuEntries) {
    if(!m.action && m.targetState) {
      // if no action is defined, toggle the states
      m.action = () => {
        if ($state.current.name !== m.targetState) {
          $state.go(m.targetState);
        }
        else
          $scope.$emit("MenuToggle");
      }
    }
    if(!m.action) {
      console.error('state is missing action or targetState')
    }
  }

  // Mission Menu, Career Stuff and Multiplayer
  vm.missionEnabled = false
  $scope.inCareer = false;
  $scope.isMPSession = false;
  bngApi.engineLua(`{
    gameContext = core_gameContext and core_gameContext.getGameContext(),
    isCareerActive = career_career.isActive(),
    isMPSession = MPCoreNetwork.isMPSession()
  }`, data => {
    $scope.$evalAsync(() => {
      vm.missionEnabled = data.gameContext && data.gameContext.context && data.gameContext.context !== "empty";
      $scope.inCareer = !!data.isCareerActive;
      $scope.isMPSession = !!data.isMPSession;
      if ($state.current && $state.current.name === "menu") {
        if (vm.missionEnabled)
          $state.go("menu.careermission");
        else if ($scope.inCareer)
          $state.go("menu.careerPause");
        else if ($scope.isMPSession)
          $state.go("menu.multiplayerPause");
      }
      updateMenu();
    })
  });

  $scope.$on("onMissionAvailabilityChanged", (event, res) => {
    if(res && res.missionCount !== undefined) {
      vm.missionEnabled = res.missionCount > 0
      updateMenu()
      if($state.current && $state.current.name === "menu.careermission" && !vm.missionEnabled) {
        $state.go("menu");
      }
    }
  })

  vm.pause = function() {
    bngApi.engineLua(`simTimeAuthority.pause(true)`)
  }

  $rootScope.$broadcast("TopMenuButtons", (button, index=-1) => {
    if (typeof index !== "number" && index < availableMenuEntries.length)
      index = -1;
    if (index > 0)
      availableMenuEntries.splice(index, 0, button);
    else
      availableMenuEntries.push(button);
    updateMenu();
  });

  function updateMenu() {
    let entries = [];
    const app = $scope.$parent && $scope.$parent.app ? $scope.$parent.app : {};
    if ($state.current.name !== 'menu.mainmenu' || !app.mainmenu) {
      // TODO: revert to normal gamestate when it will be implemented for career (but don't forget about career's garage)
      if ($scope.inCareer && ["freeroam", "garage"].includes(app.gameState))
        $scope.gameState = "career";
      else
        $scope.gameState = app.gameState;
      for(let entry of availableMenuEntries) {
        // visibility
        if(entry.blackListStates && entry.blackListStates.includes($scope.gameState)) {
          continue;
        }
        if(entry.isVisible && !entry.isVisible()) {
          continue;
        }
        if($scope.$parent && app.mainmenu && entry.onlyIngame) {
          //console.log('ignored menu entry in main menu: ', entry)
          continue
        }

        if (entry.navigationDisabled === undefined) {
          entry.navigationDisabled = false
        }

        // determine if the thing is 'active' as in 'used / switched on'
        entry.active = false
        if (entry.isActive) {
          entry.active = entry.isActive()
        } else {
          let isInSubState = false
          if(entry.substate) {
            isInSubState = $state.current.name.startsWith(entry.substate)
          }
          entry.active = ($state.includes(entry.targetState) | isInSubState) && entry.targetState != '.' && entry.targetState != ''
        }
        entries.push(entry)
      }
      //console.log('updateMenu = ', entries)
    }

    if(entries.length > 0) {
      entries[entries.length-1].isLastItem = true
    }

    $scope.$applyAsync(() => {
      for (let i = 0; i < entries.length; i++)
        entries[i].id = `top-menu-${i}`;
      vm.entries = entries;
    })
  }
  $scope.$on('$stateChangeSuccess', function (event, toState, toParams, fromState, fromParams) {
    updateMenu()
  })
  updateMenu()


  // Angular material theme palette tests
  let palettes = ['primary', 'accent', 'warn', 'background']
  let types = ['default', 'hue-1', 'hue-2', 'hue-3']
  let colors = {}
  let theme = mdx.mdxThemeColors.theme('default')
  for(let pIdx in palettes) {
    let p = palettes[pIdx]
    for(let tIdx in types) {
      let t = types[tIdx]
      let paletteName = 'custom' + p.substr(0, 1).toUpperCase() + p.substr(1)
      let ref = theme.colors[p]['hues'][t]
      if(paletteName in mdx.mdxThemeColors._PALETTES) {
        let col = 'rgb(' + (mdx.mdxThemeColors._PALETTES[paletteName][ref].value.toString()) + ')'
        let colContrast = 'rgb(' + (mdx.mdxThemeColors._PALETTES[paletteName][ref].contrast.toString()) + ')'
        colors[paletteName + "/" + t] = [ref, col, colContrast]
      }
    }
  }
  //vm.colorDebug = colors

  // switches to the next or previous visible menu entry (increment +1 or -1 respectively)
  vm.selectVisibleMenuEntry = function(increment) {
    if ($scope.$parent && $scope.$parent.app && $scope.$parent.app.mainmenu)
      return; // tab navigation shouldn't work while in the Main Menu

    // first, find the current active element
    let currMenuEntryIndex = 0
    for (let i in vm.entries) {
      if (!vm.entries[i].active) continue
      currMenuEntryIndex = Number(i)
      break
    }

    // then find the next suitable one
    let newIndex = currMenuEntryIndex
    for(let i = 0; i < 5; i++) {
      newIndex = newIndex + increment
      if (newIndex >= vm.entries.length) newIndex = 0
      if (newIndex < 0) newIndex = vm.entries.length - 1
      if (vm.entries[newIndex].gamepadNavigateable === false || vm.entries[newIndex].targetState === undefined)
        continue;
      if (!vm.entries[newIndex].targetState && !vm.entries[newIndex].action)
        continue;
      // found a suitable element ...
      break
    }

    // navigate left (increment -1) or right (increment +1), wrapping around when reaching the menu borders
    //console.log('newIndex = ', newIndex, 'vm.entries = ', vm.entries)
    if (vm.entries[newIndex].targetState) {
      $state.go(vm.entries[newIndex].targetState)
    } else if (vm.entries[newIndex].action && vm.entries[newIndex].id) {
      try {
        document.getElementById(vm.entries[newIndex].id).focus();
        for (let i = 0; i < vm.entries.length; i++)
          vm.entries[i].active = i === newIndex;
        vm.entries[newIndex].activeSilent = true;
      } catch (err) { }
    }
  }

  $scope.$on('$tabLeft',  () => { vm.selectVisibleMenuEntry(-1) })
  $scope.$on('$tabRight', () => { vm.selectVisibleMenuEntry( 1) })
}])

.directive('dashMenu', ['Utils', '$rootScope', function (Utils, $rootScope, ) {
  return {
    restrict: 'E',
    // controller: 'MenuController',
    // controllerAs: 'menuCtrl',
    replace: true,
    template: `
      <div id="dashmenu" class="dashMenuHeight" bng-blur="true">
        <div ng-repeat="entry in menuCtrl.entries"
          class="dashBrdButton {{ entry.class }}"
          ng-class="{'dashBrdButtonActive': entry.active && !entry.activeSilent, 'dashBrdButtonDiv': !entry.isLastItem && entry.targetState && app.sections[app.gameState].indexOf(entry.targetState) > -1 }"
          ng-click="entry.action($event); $event.preventDefault();"
          bng-sound-class="{{ entry.soundClass || 'bng_click_hover_generic' }}"
          bng-no-nav="{{entry.navigationDisabled}}"
          id="{{entry.id}}"
        >
          <div class="dashBrdSvgIcon" ng-if="entry.translateidIcon" bng-translate="{{entry.translateidIcon}}"></div>
          <img class="dashBrdSvgIcon" ng-if="entry.iconSVG" ng-src="{{entry.iconSVG}}" />
          <md-icon class="dashBrdSvgIcon material-icons" ng-if="entry.icon">{{entry.icon}}</md-icon>
          <span class="dashBrdText" bng-translate="{{entry.translateid}}"></span>
          <md-tooltip md-direction="bottom">{{ entry.translateid | translate}}</md-tooltip>
        </div>
        <!-- pause button (shown only while not paused), not to be confused with the pause indicator (show only while paused). see index.html -->
        <div ng-if="!app.showPauseIcon && !app.mainmenu && app.gameState !== 'garage'" class="dashMenuHeight dashBrdButton dashBrdButtonEnd dashBrdButtonPause" ng-click="menuCtrl.pause()" bng-sound-class="bng_hover_generic">
          <span style="padding:0; margin:0" bng-translate="ui.inputActions.general.pause.binding" class="bng-binding dashBrdSvgIcon"></span>
          <span class="dashBrdText">{{ 'ui.inputActions.general.pause.title' | translate }}</span>
          <md-tooltip md-direction="bottom">{{ 'ui.inputActions.general.pause.title' | translate}}</md-tooltip>
        </div>
      </div>
    `,
  }
}])
