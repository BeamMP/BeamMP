'use strict'

angular.module('beamng.stuff')


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

.directive("fancyBackground", ["TechLicenseState", function (techLicenseState) {
  return {
    template: `
      <img-carousel imageurls="files" delay="10000" slow="true" nav="false" random="true" class="filler"></img-carousel>
    `,
    scope: {
      videoLoaded: "&",
    },
    link: function (scope, elem, attr) {
      scope.files = [
        "/ui/modules/mainmenu/drive/images/1.jpg",
        "/ui/modules/mainmenu/drive/images/2.jpg",
        "/ui/modules/mainmenu/drive/images/3.jpg",
        "/ui/modules/mainmenu/drive/images/4.jpg",
        "/ui/modules/mainmenu/drive/images/5.jpg",
        "/ui/modules/mainmenu/drive/images/6.jpg",
        "/ui/modules/mainmenu/drive/images/7.jpg",
        "/ui/modules/mainmenu/drive/images/8.jpg",
      ];

      bngApi.engineLua("sailingTheHighSeas", ahoy => {
        if (ahoy)
          scope.files = ["/ui/modules/mainmenu/unofficial_version.jpg"];
      });
      techLicenseState.state.then(licenseVerified => {
        if (licenseVerified)
          scope.files = ["/ui/modules/mainmenu/drive/tech_images/1.jpg"];
      });
    }
  }
}])

.directive('menuNavbar', ['Utils', '$rootScope', function (Utils, $rootScope, ) {
  return {
    template: `
      <div class="menuNavbar" layout="row" bng-blur="true" layout-align="center center" layout-wrap="">
        <div layout="row" layout-align="start stretch" flex="noshrink" flex="75" flex-md="100">

          <span bng-no-nav="true" class="navBtn" layout="row" layout-align="center center" style="pointer-events: none; margin-top: 0px; margin-bottom: 0px; margin-left: 0px; margin-right: 0.5em"><div class="binding-icon-mask icon-light" style="margin-right: 0.25em; -webkit-mask-image: url('/ui/modules/options/deviceIcons/xbox/x_dpad_default_filled.svg');"></div><span>{{ "ui.mainmenu.navbar.navigate" | translate }}</span></span>

          <span bng-no-nav="true" bng-translate='ui.mainmenu.navbar.select' class="navBtn" layout="row" layout-align="center center" style="margin-top: 0px; margin-bottom: 0px; margin-left: 0px; margin-right: 0.5em" ng-click="nav('confirm')"></span>
          <span bng-no-nav="true" bng-translate='ui.mainmenu.navbar.back' class="navBtn" layout="row" layout-align="center center" style="margin-top: 0px; margin-bottom: 0px; margin-left: 0px; margin-right: 0.5em" ng-click="nav('back')"></span>
          <span bng-no-nav="true" bng-translate='ui.mainmenu.navbar.tab_left' ng-if="!mainmenu" class="navBtn" layout="row" layout-align="center center" style="margin-top: 0px; margin-bottom: 0px; margin-right: 0.5em; margin-right: 0.5em" ng-click="nav('tab-left')"></span>
          <span bng-no-nav="true" bng-translate='ui.mainmenu.navbar.tab_right' ng-if="!mainmenu" class="navBtn" layout="row" layout-align="center center" style="margin-top: 0px; margin-bottom: 0px; margin-right: 0.5em; margin-right: 0.5em" ng-click="nav('tab-right')"></span>
          <!--
          <span bng-no-nav="true" bng-translate='ui.mainmenu.navbar.scroll_h' id="xf_scroll_h" class="navBtn" layout="row" layout-align="center center" style="display: none; margin-top: 0px; margin-bottom: 0px; margin-right: 0.5em; margin-right: 0.5em"></span>
          <span bng-no-nav="true" bng-translate='ui.mainmenu.navbar.scroll_v' id="xf_scroll_v" class="navBtn" layout="row" layout-align="center center" style="display: none; margin-top: 0px; margin-bottom: 0px; margin-right: 0.5em; margin-right: 0.5em"></span>
          -->
          <span bng-no-nav="true" bng-translate='ui.mainmenu.navbar.scroll' id="xf_scroll" class="navBtn" layout="row" layout-align="center center" style="display: none; margin-top: 0px; margin-bottom: 0px; margin-right: 0.5em; margin-right: 0.5em"></span>
        </div>
        <div layout="row" layout-align="start fill" style="margin:0;padding:0;color:white;">
          <div ng-if="serviceProviderInfo && serviceProviderInfo.eos && serviceProviderInfo.eos.loggedin" layout="row" layout-align="start center" ng-cloak >
            <img src="/ui/modules/mainmenu/eosicon.png" style="padding: 5px">
          </div>
          <div ng-if="serviceProviderInfo && serviceProviderInfo.steam && serviceProviderInfo.steam.working && serviceProviderInfo.steam.loggedin" layout="row" layout-align="start center" ng-cloak >
            <img src="/ui/modules/mainmenu/steamicon.png" style="padding: 5px">
            <div layout="row" style="padding: 5px">
              <span>{{ ::serviceProviderInfo.steam.playerName }}</span>
              <span ng-if="::serviceProviderInfo.steam.branch != 'public'" style="padding-left: 5px;">Branch: {{ ::serviceProviderInfo.steam.branch }}</span>
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
              <img src="/ui/modules/multiplayer/icons/account-multiple.svg" style="padding: 5px" height="22px">
              <div layout="row" style="padding: 5px">
                <span style="padding-left: 5px;">Players: <strong>{{ ::beammpData.players }}</strong> </span>
              </div>
            </div>
          </div>
        </div>
        <div style="margin-left:16px;border-right:3px solid #333;height:100%">&nbsp;</div>
        <div bng-no-nav="true" ng-click="showBuildInfo = !showBuildInfo" style="text-align:right;cursor: pointer; color:white;margin-left:16px;">
          <div ng-show='!showBuildInfo'>BeamMP v{{ ::beammpData.beammpGameVer }}</div>
          <div ng-show='showBuildInfo' style="font-size:0.7em;">BeamMP Mod v{{ ::beammpData.beammpGameVer }} <br/> BeamMP Launcher v{{ ::beammpData.beammpLauncherVer }}</div>
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
      scope.$on('ServiceProviderInfo', function (event, data) {
        scope.$apply(function () {
          scope.serviceProviderInfo = data
          //for new mainmenu TODO: move to vue
          beamng.serviceProviderInfo = data
        })
      })
      beamng.requestServiceProviderInfo()
      scope.onlineState = false
      scope.$on('OnlineStateChanged', function (event, data) {
        scope.$applyAsync(function () {
          scope.onlineState = data
          //for new mainmenu TODO: move to vue
          beamng.onlineState = data
        })
      })
      scope.$on('ShowEntertainingBackground', (ev, mainmenu) => {
        scope.$evalAsync(() => {
          scope.mainmenu = mainmenu
          //for new mainmenu TODO: move to vue
          beamng.mainmenu = mainmenu
        })
      })
      bngApi.engineLua('core_online.requestState()')

      //for new mainmenu TODO: move to vue
      beamng.versionSimpleStr = scope.versionSimpleStr

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

.controller('MainMenuController', ['$rootScope', '$scope', 'toastr', '$state', 'Settings', '$http', '$filter', 'Utils', 'gamepadNav', 'TechLicenseState', 'ConfirmationDialog', function($rootScope, $scope, toastr, $state, Settings, $http, $filter, Utils, gamepadNav, techLicenseState, ConfirmationDialog) {
  let vm = this

  vm.product = beamng.product
  vm.productLogo = beamng.product.replace('BeamNG.', '')
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
  bngApi.engineLua('checkFSErrors()')

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


  let buttonsDefault = [
    // big
    {
      translateid: 'ui.playmodes.freeroam',
      icon: '/ui/modules/mainmenu/drive/icons/play.svg',
      targetState: 'menu.levels'
    },
    // rows with 4 elements each
    {
      translateid: 'ui.playmodes.multiplayer',
      icon: '/ui/modules/multiplayer/icons/account-multiple.svg',
      targetState: 'menu.multiplayer.tos'
    },
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
    {
      translateid: 'ui.mainmenu.garage',
      icon: '/ui/modules/mainmenu/drive/icons/garage.svg',
      action: () => {
        bngApi.engineLua(`gameplay_garageMode.start()`)
      },
      get disabled() { return $scope.$parent.app.gameState === "garage" },
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
      },
      get disabled() { return $scope.$parent.app.gameState === "garage" },
    },
    // {
    //   translateid: 'ui.quickrace.tracks.procedural',
    //   icon: '/ui/modules/mainmenu/drive/icons/infinity.svg',
    //   targetState: 'quickraceTrackSelect'
    // },
    {
      translateid: 'ui.playmodes.career',
      subtranslateid: 'ui.playmodes.comingSoon',
      icon: '/ui/modules/mainmenu/drive/icons/career.svg',
      disabled: true,
      class: "semi-disabled", // semi-disabled will make the button clickable, not changing the style if it was disabled
      // targetState: 'menu.career'
      action: () => {
        if (!$scope.inCareer) {

          ConfirmationDialog.open(
            "ui.career.experimentalTitle", "ui.career.experimentalPrompt",
            [
              { label: "ui.common.no", key: false, isCancel: true },
              // { label: "Enter and don't show this again", key: true },
              { label: "ui.career.experimentalAgree", key: true, default: true },
            ],
            { class: "experimental" }
          ).then(res => {
            if (!res)
              return;
            $state.go("menu.career");
          });
        } else {
          $state.go("menu.career");
        }
      },
    },
  ];

  let clickytmr, clickycnt = 0;
  function clicky(cnt=6, timeout=300) {
    clickytmr = clearInterval(clickytmr);
    clickycnt++;
    if (clickycnt === cnt) {
      clickycnt = 0;
      return true;
    }
    clickytmr = setInterval(() => {
      clickycnt--;
      if (clickycnt <= 0) {
        clickycnt = 0;
        clickytmr = clearInterval(clickytmr);
      }
    }, timeout);
    return false;
  }

  $scope.inCareer = false;
  bngApi.engineLua("career_career.isActive()", data => {
    $scope.inCareer = !!data;
  });

  // GFX api
  bngApi.engineLua('Engine.Render.getAdapterType()', function (isVulkan) {
    vm.videoApi = isVulkan;
  })

  // Quick load a level
  vm.quickLoadLevel = function () {
    bngApi.engineLua(`core_levels.startLevel("/levels/smallgrid/main.level.json")`)
  }

  // trial new main menu
  vm.tryNewMainMenu = () => window.bngVue.gotoGameState('mainmenu')

  vm.buttons = {
    big: null,
    groups: []
  };

  {
    let buttons = [];
    vm.addButton = function (button, draw=true) {
      if (!vm.buttons.big) {
        vm.buttons.big = button;
      } else {
        // add new button
        buttons.push(button);
        // rebuild layout
        if (draw)
          vm.rebuildButtons();
      }
    };

    let rowlimit = [3, 4]; // desired [min, max] per row
    vm.rebuildButtons = function () {
      let len = buttons.length;
      // find out optimal count per row
      const max = Math.min(Math.max(rowlimit[0], Math.ceil(Math.sqrt(len))), rowlimit[1]);
      // calculate new layout
      let top = [len % max || max]; // first row
      if (max > 3 && top[0] === 1) // change to two top rows
        top = [~~(max / 2), ~~(max / 2) + 1];
      const groupsmax = Math.ceil(len / max);
      // clear/add rows
      const groupslen = vm.buttons.groups.length;
      for (let i = 0; i < groupsmax; i++) {
        if (i < groupslen)
          vm.buttons.groups[i].list = [];
        else
          vm.buttons.groups.push({ list: [] });
      }
      // rebuild the layout
      let group = 0;
      for (let button of buttons) {
        if (vm.buttons.groups[group].list.length === (top[group] || max))
          group++;
        vm.buttons.groups[group].list.push(button);
      }
      // allow/disallow wrapping the buttons on even count
      for (let grp of vm.buttons.groups) {
        let len = grp.list.length;
        grp.class = len > 2 && len / 2 % 1 === 0 ? "mainmenu-buttons-smwrap" : null;
      }
      // sync with fancy-background
      setTimeout(fancySync, 100);
    };
  }

  // populate menu with default buttons
  for (let button of buttonsDefault)
    vm.addButton(button, false);
  vm.rebuildButtons();

  // broadcast event for an additional buttons
  $rootScope.$broadcast('MainMenuButtons', vm.addButton);

  vm.openRepo = function () {
    window.location.href = 'http-external://www.beamng.com/resources/?ingame=2'
  }

  vm.handleClick = function(card) {
    if(card.action) {
      card.action()
      return
    }
    if(card.targetState) {
      $state.go(card.targetState)
      return
    }
  }

  $scope.fancyblur = false;
  function fancySync() {
    // find fancy bg
    const fancybg = document.querySelector("fancy-background > .img-carousel");
    if (!fancybg) {
      $scope.fancyblur = false;
      return;
    }
    $scope.fancyblur = true;
    $scope.$evalAsync(() => {
      // get all target blur elements
      const blurs = Array.from(document.querySelectorAll(".fancy-blur > .img-carousel"));
      // and connect them to master so they will work in sync
      fancybg.__connect(
        blurs,
        // function to modify images list for targets - function (orig_list) { return orig_list }
        // here, we change images from "image.jpg" to "image_blur.jpg"
        images => images.map(img => img.replace(/\.(.{3,4})$/, "_blur.$1"))
        // note: blurred images are 1280x720 with gaussian blur 6.0 (resize, then blur)
      );
    });
  }
  fancySync();

}])
