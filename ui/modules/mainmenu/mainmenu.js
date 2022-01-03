'use strict'

angular.module('beamng.stuff')


// no fucking clue, why this doesn't just work in the videoBackgroundDirective itself, but well you know
// idea from: http://stackoverflow.com/questions/28016476/angular-on-video-load-event
.directive('onVideoStart', function () {
  return {
    restrict: 'A',
    scope: {
      onVideoStart: '&'
    },
    link: function (scope, $element) {
      $element[0].addEventListener('play', function () {
        scope.onVideoStart()
      })
    }
  }
})

.directive('fancyBackground', ['TechLicenseState', function (techLicenseState) {
  return {
    template: `
        <imageslider imageurls="files" delay="10000" class="filler"></imageslider>
    `,
    scope: {
      videoLoaded: '&'
    },
    link: function (scope, $element, attr) {
      scope.sailingTheHighSeas = false

      bngApi.engineLua('sailingTheHighSeas', (val) => {
        scope.sailingTheHighSeas = val
      })

      scope.files = []
      if (scope.sailingTheHighSeas === true) {
        scope.files = ['/ui/modules/mainmenu/unofficial_version.jpg']
      } else {
        scope.files = [
          '/ui/modules/mainmenu/drive/images/1.jpg',
          '/ui/modules/mainmenu/drive/images/2.jpg',
          '/ui/modules/mainmenu/drive/images/3.jpg',
          '/ui/modules/mainmenu/drive/images/4.jpg',
          '/ui/modules/mainmenu/drive/images/5.jpg',
          '/ui/modules/mainmenu/drive/images/6.jpg',
          '/ui/modules/mainmenu/drive/images/7.jpg',
          '/ui/modules/mainmenu/drive/images/8.jpg',
        ]
      }

      techLicenseState.state.then((licenseVerified) => {
        if(licenseVerified) {
          scope.files = ['/ui/modules/mainmenu/drive/tech_images/1.jpg']
        }
      })

    }
  }
}])

.directive('menuNavbar', ['Utils', '$rootScope', function (Utils, $rootScope, ) {
  return {
    template: `
      <div class="menuNavbar" layout="row" bng-blur="true" layout-align="center center" layout-wrap="">
        <div layout="row" layout-align="start stretch" flex="noshrink" flex="75" flex-md="100">
          <p bng-no-nav="true" bng-translate='ui.mainmenu.navbar.select' class="navBtn" layout="row" layout-align="center center" style="margin-top: 0px; margin-bottom: 0px; margin-left: 0px; margin-right: 8px" ng-click="nav('confirm')"></p>
          <p bng-no-nav="true" bng-translate='ui.mainmenu.navbar.back' class="navBtn" layout="row" layout-align="center center" style="margin-top: 0px; margin-bottom: 0px; margin-left: 0px; margin-right: 8px" ng-click="nav('back')"></p>
          <p bng-no-nav="true" bng-translate='ui.mainmenu.navbar.tab_left' class="navBtn" layout="row" layout-align="center center" style="margin-top: 0px; margin-bottom: 0px; margin-right: 0px; margin-right: 8px" ng-click="nav('tab-left')"></p>
          <p bng-no-nav="true" bng-translate='ui.mainmenu.navbar.tab_right' class="navBtn" layout="row" layout-align="center center" style="margin-top: 0px; margin-bottom: 0px; margin-right: 0px; margin-right: 8px" ng-click="nav('tab-right')"></p>
        </div>
        <div layout="row" layout-align="start fill" style="margin:0;padding:0;color:white;">
          <div ng-if="steamData && steamData.working && steamData.loggedin" layout="row" layout-align="start center" ng-cloak >
            <img src="/ui/modules/mainmenu/steamicon.png" style="padding: 5px">
            <div layout="row" style="padding: 5px">
              <span>{{ ::steamData.playerName }}</span>
              <span ng-if="::steamData.branch != 'public'" style="padding-left: 5px;">Branch: {{ ::steamData.branch }}</span>
            </div>
          </div>
          <div id="onlinestate" ng-show="onlineState">
            ONLINE
          </div>
        </div>
        <div style="margin-left:16px;border-right:3px solid #333;height:100%">&nbsp;</div>
        <div style="text-align:right; color:white;margin-left:16px;">
          <div ng-if="beammpData && beammpData.players && beammpData.servers" layout="row" layout-align="start fill" style="margin:0;padding:0;color:white;">
            <div layout="row" layout-align="start center" ng-cloak >
              <img src="/ui/modules/mainmenu/drive/icons/account-multiple.svg" style="padding: 5px" height="22px">
              <div layout="row" style="padding: 5px">
                <span style="padding-left: 5px;">Players: <strong>{{ ::beammpData.players }}</strong> </span>
              </div>
            </div>
          </div>
        </div>
        <div style="margin-left:16px;border-right:3px solid #333;height:100%">&nbsp;</div>
        <div style="text-align:right; color:white;margin-left:16px;">
          <div>BeamMP v4.2.3</div>
        </div>
        <div style="margin-left:16px;border-right:3px solid #333;height:100%">&nbsp;</div>
        <div bng-no-nav="true" ng-click="showBuildInfo = !showBuildInfo" style="text-align:right;cursor: pointer; color:white;margin-left:16px;">
          <div ng-show='!showBuildInfo'>Alpha v{{ ::versionSimpleStr }}</div>
          <div ng-show='showBuildInfo' style="font-size:0.7em;">Alpha v{{ ::versionStr }} <br/> {{ ::buildInfoStr }}</div>
        </div>
      </div>
    `,
    scope: {
    },
    link: function (scope, $element, attr) {
      // do quick check right in main menu, to ensure *some* of our UI/LUA code can work in languages with certain non-english characters
      let testString = "If you see this message in logs, the JS>LUA serializer is broken for non-english languages. See jira ticket GE-3042. BEGIN TEST STRING Kl�vesnice END TEST STRIN"
      bngApi.engineLua(`dumps(${bngApi.serializeToLua(testString)})`)

      scope.nav = function(action, val) {
        $rootScope.$broadcast('MenuItemNavigation', action, val)
      }
      scope.radialMenu = function(action, val) {
        bngApi.engineLua("extensions.core_quickAccess.setEnabled(true)")
      }
      // VERSION INFO
      scope.showBuildInfo = false
      scope.versionStr = beamng.version

      // convert from 1.2.3.4 to 1.2.3 as we do not want to attach the build number in the simple display
      var versionSplit = scope.versionStr.split('.')
      if(versionSplit.length == 5) versionSplit.pop() // remove build number (5th)
      for(var i = 0; i < 3; i++) {
        if(versionSplit[versionSplit.length - 1] == '0') versionSplit.pop(); // remove any '0' for simplicity reasons
      }
      scope.versionSimpleStr = versionSplit.join('.')
      scope.buildInfoStr = beamng.buildinfo

      // account info
      scope.$on('SteamInfo', function (event, data) {
        scope.$apply(function () {
          scope.steamData = data
        })
      })
      scope.onlineState = false
      scope.$on('OnlineStateChanged', function (event, data) {
        // console.log('OnlineStateChanged', data)
        scope.$apply(function () {
          scope.onlineState = data
        })
      })
      bngApi.engineLua('core_online.requestState()')

      // beammp info
      scope.$on('BeamMPInfo', function (event, data) {
        scope.$apply(function () {
          scope.beammpData = data
        })
      })
      bngApi.engineLua('MPCoreNetwork.requestPlayers()')
    }
  }
}])


.directive('onlineMessage', ['$sce', 'Utils', '$state', function ($sce, Utils, $state) {
  return {
    restrict: 'E',
    replace: true,
    template: `
    <div ng-if="messageData.length > 0" layout="column" layout-align="center center" ng-style="style" >
      <div>
        <div style="height: 5vh; width:100%;" layout="row" layout-align="space-between center" class="loadingHint md-padding">
          <div>News</div>
          <div ng-click="close()" style="cursor: pointer; line-height: 50%; background-color: #FF6700">
            <md-icon class="material-icons md-default-theme" style="margin: 0 auto; font-size: 1.2em; color: black;">close</md-icon>
          </div>
        </div>

        <md-content class="filler loadingHint" style="max-height: 30vh; max-width:400px;">
          <div layout="column" layout-align="center center" ng-repeat="message in messageData" >
            <div ng-bind-html="message.msg" class="md-padding"></div>
            <div layout="row" class="md-padding" layout-wrap layout-align="start center">
              <md-button bng-nav-item ng-click="clicked(btn)" ng-repeat="btn in buttons" class="md-accent md-raised md-padding">{{btn.label | translate}}</md-button>
            </div>
          </div>
        </md-content>
      </div>
    </div>
    `,
    link: function (scope) {
      var uids = {}

      scope.$on('OnlineMessage', function (ev, data) {
        scope.messageData = data
        scope.$evalAsync(() => {
          // uid = data.uid
          for (var key in scope.messageData) {
            switch (scope.messageData[key].contenttype) {
              case 'html':
                scope.messageData[key].msg = $sce.trustAsHtml(scope.messageData[key].msg)
                break
              case 'bbcode':
                scope.messageData[key].msg = $sce.trustAsHtml(Utils.parseBBCode(scope.messageData[key].msg))
                break
              default:
                scope.messageData[key].msg = scope.messageData[key].msg
            }
            uids[key] = scope.messageData[key].uid
            scope.style =  scope.messageData[key].css //{position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, 'background': ' repeating-linear-gradient(45deg, rgba(0, 0, 0, 0.75), rgba(0, 0, 0, 0.75) 35px, rgba(0, 0, 0, 0.8) 35px, rgba(0, 0, 0, 0.8) 70px)'}
          }
        })
      })

      scope.close = function () {
        for (var key in uids) {
          bngApi.engineLua(`extensions.hook("onUIOnlineMessageHide", "${uids[key]}")`)
        }
        scope.messageData = undefined
      }

      scope.clicked = function (btn) {
        switch (btn.type) {
          case 'hide-temp':
            scope.messageData = undefined
            break
          case 'hide-perm':
            scope.messageData = undefined
            bngApi.engineLua(`extensions.hook("onUIOnlineMessageHide", "${uid}")`)
            break
          case 'luacmd':
            bngApi.engineLua(btn.cmd)
            break
          case 'url':
            document.location.href = btn.url
            break
          case 'state':
            $state.go(btn.state, btn.params || {})
            break
          default:
            console.warn('Unknown action type in online message button')
        }
      }

      bngApi.engineLua('extensions.hook("onUIOnlineMessageReady")')
    }
  }
}])

.controller('MainMenuController', ['$scope', 'toastr', '$state', 'Settings', '$http', '$filter', 'Utils', 'gamepadNav', 'TechLicenseState', function($scope, toastr, $state, Settings, $http, $filter, Utils, gamepadNav, techLicenseState) {
  let vm = this

  vm.product = beamng.product
  vm.techLicense = false
  techLicenseState.state.then((licenseVerified) => {
    vm.techLicense = licenseVerified
  })

  // always hide apps in main menu
  $scope.$parent.app.showApps = false

  // settings
  {
    vm.settings = Settings.values
    $scope.$on('SettingsChanged', (ev, data) => {
      vm.settings = data.values
    })
  }

  if (!vm.techLicense && (Settings.values.onlineFeatures === 'ask' || Settings.values.telemetry === 'ask')) {
    $state.go('menu.onlineFeatures')
  }
  bngApi.engineLua('core_online.requestState()')

  // hardwareinfo warnings, etc
  {
    bngApi.engineLua('core_hardwareinfo.requestInfo()')
    $scope.$on('HardwareInfo', function (event, data) {
      if (data.globalState !== 'ok') {
        for (var key in data) {
          if(data[key].warnings === undefined) continue

          for (var i=0; i < data[key].warnings.length; i++) {
            if(data[key].warnings[i].ack !== undefined) continue

            var txt = $filter('translate')('ui.performance.warnings.' + data[key].warnings[i].msg)
            var html = Utils.parseBBCode(txt)
            toastr[(data.globalState === 'warn' ? 'warning' : 'error')](
              $filter('translate')('ui.mainmenu.warningdetails'),//need a unique message
              html,
              {
                positionClass: 'toast-top-right',
                timeOut: 0,
                extendedTimeOut: 0,
                onTap: function () {
                  $state.go('menu.options.performance')
                }
              }
            )
          }
        }
      }
    })
  }

  // repository button: X of Y mods active
  {
    vm.modsTotal = 0
    vm.modsActive = 0
    bngApi.engineLua('core_modmanager.requestState()')
    $scope.$on('ModManagerModsChanged', function (event, data) {
      var list = data.convertToArray()
      vm.modsActive = list.filter((elem) => elem.modname != 'translations' && elem.active).length
      vm.modsTotal  = list.filter((elem) => elem.modname != 'translations').length
    })
  }


  {
    // navigation things
    let prevCross = gamepadNav.crossfireEnabled()
    let prevGame = gamepadNav.gamepadNavEnabled()
    gamepadNav.enableCrossfire(true)
    gamepadNav.enableGamepadNav(true)
    $scope.$on('$destroy', () => {
      gamepadNav.enableCrossfire(prevCross)
      gamepadNav.enableGamepadNav(prevGame)
    })
  }

  $scope.quit = function() {
    // copypasted from entrypoints/main/main.js
    bngApi.engineScript('quit();'); //It should work but doesn't, `Platform::postQuitMessage` is executed but nothing happens, maybe CEF catch that message
    bngApi.engineLua("TorqueScript.eval('quit();')")
  }

  $scope.radialmenu = function() {
  }


  vm.big = {
    translateid: 'ui.playmodes.freeroam',
    icon: '/ui/modules/mainmenu/drive/icons/play.svg',
    targetState: 'menu.levels'
  }
  vm.groups = [
    // note: if you want buttons to be wrapped to the next line on thin window,
    //       add `class: "mainmenu-buttons-smwrap",` (button count must be even)
    {
      list: [
        {
          translateid: 'ui.playmodes.campaigns',
          icon: '/ui/modules/mainmenu/drive/icons/campaigns.svg',
          targetState: 'menu.campaigns'
        },
        {
          translateid: 'ui.playmodes.scenarios',
          icon: '/ui/modules/mainmenu/drive/icons/scenarios.svg',
          targetState: 'menu.scenarios'
        },
        {
          translateid: 'ui.playmodes.quickrace',
          icon: '/ui/modules/mainmenu/drive/icons/timetrials.svg',
          targetState: 'menu.quickraceOverview'
        },
      ],
    },
    {
      class: "mainmenu-buttons-smwrap",
      list: [
        {
          translateid: 'ui.playmodes.multiplayer',
          icon: '/ui/modules/mainmenu/drive/icons/account-multiple.svg',
          targetState: 'menu.multiplayer.tos'
        },
        {
          translateid: 'ui.playmodes.bus',
          icon: '/ui/modules/mainmenu/drive/icons/busroutes.svg',
          targetState: 'menu.busRoutes'
        },
        {
          translateid: 'ui.playmodes.lightRunner',
          icon: '/ui/modules/mainmenu/drive/icons/lightrunner.svg',
          targetState: 'menu.lightrunnerOverview'
        },
        // {
        //   translateid: 'ui.dashboard.trackBuilder',
        //   icon: '/ui/modules/mainmenu/drive/icons/autobahn.svg',
        //   action: () => bngApi.engineLua("extensions.trackbuilder_trackBuilder.toggleTrackBuilder()")
        // },
        {
          translateid: 'ui.playmodes.trackBuilder',
          icon: '/ui/modules/mainmenu/drive/icons/autobahn.svg',
          action: () => { // TODO: toggle track builder in current level
            // bngApi.engineLua("extensions.trackbuilder_trackBuilder.toggleTrackBuilder()")
            bngApi.engineLua(`freeroam_freeroam.startTrackBuilder('glow_city')`)
          }
        },
        // {
        //   translateid: 'ui.quickrace.tracks.procedural',
        //   icon: '/ui/modules/mainmenu/drive/icons/infinity.svg',
        //   targetState: 'quickraceTrackSelect'
        // },
        {
          translateid: 'ui.playmodes.career',
          icon: '/ui/modules/mainmenu/drive/icons/career.svg',
          disabled: true,
          targetState: 'career'
        },
      ]
    },
  ]

  vm.openRepo = function () {
    window.location.href = 'http-external://www.beamng.com/resources/?ingame=2'
  }

  vm.handleClick = function(card) {
    if(card.disabled) {
      return
    }
    if(card.action) {
      card.action()
      return
    }
    if(card.targetState) {
      $state.go(card.targetState)
      return
    }
  }

}])
