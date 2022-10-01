'use strict'

angular.module('beamng.stuff')
  // no fucking clue, why this doesn't just work in the videoBackgroundDirective itself, but well you know (blame the angular devs -Daniel W.)
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

  .directive("mainBackground", ["TechLicenseState", function (techLicenseState) {
    return {
      template: `
        <img-carousel imageurls="files" delay="10000" slow="true" nav="false" random="true"></img-carousel>
      `,
      scope: {
        videoLoaded: "&",
      },
      link: function (scope, elem, attr) {
        scope.files = [
          "/ui/modules/mp_mainmenu/drive/images/bg1.jpg",
          "/ui/modules/mp_mainmenu/drive/images/bg2.jpg",
          "/ui/modules/mp_mainmenu/drive/images/bg3.jpg",
        ];
      }
    }
  }])

  .directive('mpMenuNavbar', ['Utils', '$rootScope', function (Utils, $rootScope) {
    return {
      template: `
      <div class="mpMenuNavbar">
        <div layout="row" layout-align="start stretch" flex="noshrink">
          <span bng-no-nav="true" class="nav-item clickable" style="text-transform: uppercase" ng-click="openBrowser('https://beammp.com')">BeamMP.com</span>
          <span bng-no-nav="true" class="nav-item clickable" style="text-transform: uppercase" ng-click="openBrowser('https://forum.beammp.com/')">FORUM</span>
          <span bng-no-nav="true" class="nav-item clickable" style="text-transform: uppercase" ng-click="openBrowser('https://www.patreon.com/BeamMP')">PATREON</span>
          <span bng-no-nav="true" class="nav-item clickable" style="text-transform: uppercase" ng-click="openBrowser('https://discord.gg/beammp')">DISCORD</span>
        </div>

        <div class="nav-item">
          <div ng-if="beammpData && beammpData.players && beammpData.servers" layout="row" layout-align="start fill">
            <div layout="row" layout-align="start center" ng-cloak >
              <img src="/ui/modules/mp_mainmenu/drive/icons/account-multiple.svg" height="100%">
              <div>&nbsp;</div>
              <div layout="row">
                <span>Players: <strong>{{ ::beammpData.players }}</strong> </span>
              </div>
            </div>
          </div>
        </div>
        <div bng-no-nav="true" class="nav-item">
          <div>BeamMP v{{ ::beammpGameVer }}</div>
        </div>
        <div bng-no-nav="true" ng-click="showBuildInfo = !showBuildInfo" class="nav-item clickable">
          <div ng-show='!showBuildInfo'>Alpha v{{ ::versionSimpleStr }}</div>
          <div ng-show='showBuildInfo' style="font-size:0.8em;">Alpha v{{ ::versionStr }}<br/> {{ ::buildInfoStr }}</div>
        </div>
        <div class="nav-item clickable" ng-click="nav('settings')" ui-sref="menu.options.graphics">
          <img src="/ui/modules/mp_mainmenu/drive/icons/settings.svg" style="width: 16px; height: 16px; filter: invert(1);">
        </div>
        <div class="nav-item clickable" ng-click="::quit()">
          <img src="/ui/modules/mp_mainmenu/drive/icons/exit2.svg" style="width: 16px; height: 16px; filter: invert(1);">
        </div>
      </div>
    `,
      scope: {
      },
      link: function (scope, $element, attr) {
        // do quick check right in main menu, to ensure *some* of our UI/LUA code can work in languages with certain non-english characters
        bngApi.serializeToLuaCheck("English: " + "hello")
        bngApi.serializeToLuaCheck("Spanish: " + "güeñes")
        bngApi.serializeToLuaCheck("French: " + "bâguéttè, garçon")
        bngApi.serializeToLuaCheck("Czech: " + "Kl�vesnice")
        bngApi.serializeToLuaCheck("Korean: " + decodeURIComponent("%0D%EF%BF%BD%EF%BF%BD%0B%EF%BF%BD%EF%BF%BD%0B%EF%BF%BD%EF%BF%BD"))
        bngApi.serializeToLuaCheck("Chinese Sim: " + "欢迎来到简体中文版的")
        bngApi.serializeToLuaCheck("Chinese Tr: " + "歡迎來到")
        bngApi.serializeToLuaCheck("Japanese: " + "』日本語版にようこそ")
        bngApi.serializeToLuaCheck("Polish: " + "źćłąóę")
        bngApi.serializeToLuaCheck("Russian: " + "абвгеёьъ")

        scope.nav = function (action, val) {
          $rootScope.$broadcast('MenuItemNavigation', action, val)
        }

        scope.radialMenu = function (action, val) {
          bngApi.engineLua("extensions.core_quickAccess.setEnabled(true)")
        }
        // VERSION INFO
        scope.showBuildInfo = false
        scope.versionStr = beamng.version
        // TODO #203 Fix this to actually use the real launcher version!
        scope.beammpGameVer = '4.6.0'
        scope.beammpLauncherVer = '3.0.0'

        // convert from 1.2.3.4 to 1.2.3 as we do not want to attach the build number in the simple display
        var versionSplit = scope.versionStr.split('.')
        if (versionSplit.length == 5) versionSplit.pop() // remove build number (5th)
        for (var i = 0; i < 3; i++) {
          if (versionSplit[versionSplit.length - 1] == '0') versionSplit.pop(); // remove any '0' for simplicity reasons
        }
        scope.versionSimpleStr = versionSplit.join('.')
        scope.buildInfoStr = beamng.buildinfo

        scope.quit = function () {
          bngApi.engineScript('quit();');
          bngApi.engineLua("TorqueScript.eval('quit();')")
        }

        scope.openBrowser = function (url) {
          bngApi.engineLua('openWebBrowser("' + url + '")');
        }

        scope.onlineState = false
        scope.$on('OnlineStateChanged', function (event, data) {
          // console.log('OnlineStateChanged', data)
          scope.$apply(function () {
            scope.onlineState = data
          })
        })
        scope.$on('ShowEntertainingBackground', (ev, mainmenu) => {
          scope.$evalAsync(() => {
            scope.mainmenu = mainmenu
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
              scope.style = scope.messageData[key].css //{position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, 'background': ' repeating-linear-gradient(45deg, rgba(0, 0, 0, 0.75), rgba(0, 0, 0, 0.75) 35px, rgba(0, 0, 0, 0.8) 35px, rgba(0, 0, 0, 0.8) 70px)'}
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

  .controller('MPMainMenuController', ['$rootScope', '$scope', 'toastr', '$state', 'Settings', '$http', '$filter', 'Utils', 'gamepadNav', 'TechLicenseState', 'ConfirmationDialog', function ($rootScope, $scope, toastr, $state, Settings, $http, $filter, Utils, gamepadNav, techLicenseState, ConfirmationDialog) {
    let vm = this;

    bngApi.engineLua('(function() local cmdArgs = Engine.getStartingArgs(); return cmdArgs and tableFindKey(cmdArgs, "--startupTS") ~= nil end)()', function (startingUsingTS) {
      $scope.$evalAsync(function () {
        vm.startingUsingTS = startingUsingTS;
      })
    })

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

    $scope.$on('SteamInfo', function (event, data) {
      $scope.$evalAsync(function () {
        $scope.steamData = data
      })
    })

    // hardwareinfo warnings, etc
    {
      bngApi.engineLua('core_hardwareinfo.requestInfo()')
      $scope.$on('HardwareInfo', function (event, data) {
        if (data.globalState !== 'ok') {
          for (var key in data) {
            if (data[key].warnings === undefined) continue

            for (var i = 0; i < data[key].warnings.length; i++) {
              if (data[key].warnings[i].ack !== undefined) continue

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
        vm.modsTotal = list.filter((elem) => elem.modname != 'translations').length
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
  
    $scope.radialmenu = function() {}

    $scope.openBrowser = function (url) {
      bngApi.engineLua(`openWebBrowser("${url}")`)
    }

    vm.handleClick = function (card) {
      if (card.action) {
        card.action()
        return
      }
      if (card.targetState) {
        $state.go(card.targetState)
        return
      }
    }
  }])
