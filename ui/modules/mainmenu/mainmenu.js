angular.module('beamng.stuff')

.directive('versionInfo', [function () {
  return {
    replace: true,
    template: `
      <div ng-click="showBuildInfo = !showBuildInfo">
        <div ng-show='!showBuildInfo'>Alpha v{{ ::versionSimpleStr }}</div>
        <div ng-show='showBuildInfo'>Alpha v{{ ::versionStr }}<br/>{{ ::buildInfoStr }}<br/>MP-Version beta 4.0</div>
      </div>`,
    link: function (scope, element, attrs) {
      scope.showBuildInfo = false;
      scope.versionStr = beamng.version;

      // convert from 1.2.3.4 to 1.2.3 as we do not want to attach the build number in the simple display
      var versionSplit = scope.versionStr.split('.');
      if(versionSplit.length == 5) versionSplit.pop() // remove build number (5th)
      for(var i = 0; i < 3; i++) {
        if(versionSplit[versionSplit.length - 1] == '0') versionSplit.pop(); // remove any '0' for simplicity reasons
      }
      scope.versionSimpleStr = versionSplit.join('.');

      scope.buildInfoStr = beamng.buildinfo;
    }
  };
}])
.directive('logo', function(){
    return {
        restrict: 'E',
        link: function(scope,element,attrs) {
            var name = scope.$eval(attrs.src);
            element.replaceWith('<object data="images/'+name+'.svg" style="max-width: 90%; max-height: 75%; pointer-events: none;"></object>');
        }
    };
})
.directive('accountInfo', [function () {
  return {
    replace: true,
    template: `
      <div layout="column" layout-align="start fill" style="margin:0;padding:0;">
        <div ng-if="steamData && steamData.working && steamData.loggedin" layout="row" layout-align="start center" ng-cloak >
          <img src="modules/mainmenu/steamicon.png" style="padding: 5px">
          <div layout="column" style="padding: 5px">
            <span>{{ ::steamData.playerName }}</span>
            <span ng-if="::steamData.branch != 'public'">Branch: {{ ::steamData.branch }}</span>
          </div>
        </div>
        <div id="onlinestate" ng-show="onlineState">
          ONLINE
        </div>
      </div>`,
    link: function (scope, element, attrs) {
      scope.$on('SteamInfo', function (event, data) {
        scope.$apply(function () {
          scope.steamData = data;
        });
      });
      scope.onlineState = false;
      scope.$on('OnlineStateChanged', function (event, data) {
        // console.log('OnlineStateChanged', data);
        scope.$apply(function () {
          scope.onlineState = data;
        });
      });
    }
  };
}])

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
        scope.onVideoStart();
      });
    }
  };
})

.directive('fancyBackground', ['bngApi', 'Utils', '$timeout', 'logger', function (bngApi, Utils, $timeout, logger) {
  return {
    template: `
      <div class="filler">
        <video ng-if="videoSrc !== undefined && video" on-video-start="videoLoaded()" muted autoplay loop class="video">
          <source ng-src="{{videoSrc}}">
        </video>
        <imageslider ng-if="videoSrc === undefined || !video" imageurls="files" delay="5000" class="filler"></imageslider>
      </div>
    `,
    scope: {
      videoLoaded: '&'
    },
    link: function (scope, $element, attr) {
      var oldScalingValue
        , moduleDestroyed = false // important since it's the easiest way to cancel this flow:
        // 1. Directive get's loaded, since gameState === 'menu'
        // 2. Directive asks for uiUpscaling value
        // 3. Directive get's destroyed
        // 4. Directive sets moduleDestroyed to true
        // 5. Thanks to closure, the callback function get's executed eventhough the directive isn't loaded anymore
        // 6. Thanks to closure again it can check if the directive got destroyed and it's just some left over that should not be executed anymore
        // so bottom line: don't remove moduleDestroyed
        , scaling = true
      ;
      scope.video = true;
      scope.sailingTheHighSeas = false;

      bngApi.engineLua('settings.getValue("MainMenuBackgroundModeBrokenCefVersion")', (val) => {
        scope.$evalAsync(() => {
          scaling = val === 'VideoScaled' || val === 'ImagesScaled';
          scope.video = val === 'VideoScaled' || val === 'Video';
          setUp();
        });
      });

      function setUp () {
        bngApi.engineLua('settings.getValue("uiUpscaling")', (val) => {
          logger.mainMenu.log(`moduleDestroyed: ${moduleDestroyed}`);
          logger.mainMenu.log(`val: ${val}`);
          // if (Number(val) === 0 && !moduleDestroyed) {
            // oldScalingValue = val;
            // if (scaling) bngApi.engineLua('TorqueScript.setVar("$CEF_UI::maxSizeHeight", "1080")');
            // logger.mainMenu.log('set uiUpscaling to: "1080"');
          // }
        });

        bngApi.engineLua('sailingTheHighSeas', (val) => {
          scope.sailingTheHighSeas = val
        });

        bngApi.engineLua(`dirContent("/ui/modules/mainmenu/${beamng.product}/${scope.video ? 'videos' : 'images'}")`, (data) => {
          scope.$evalAsync(() => {
            scope.files = data.map((elem) => elem.slice('/ui/'.length));
            if (scope.sailingTheHighSeas === true) {
              scope.files = ["modules/mainmenu/unofficial_version.jpg"]
            }
            if (scope.video && scope.sailingTheHighSeas === false) {
              scope.videoSrc = scope.files[Utils.random(0, scope.files.length -1, true)];
              var currentSum = 0
                , rand = Utils.random(0, 100)

              for (var key in scope.files) {
                currentSum += scope.files[key].weight;
                if (rand <= currentSum) {
                  scope.videoSrc = scope.files[key].src;
                  break;
                }
              }
            } else if (typeof scope.videoLoaded === 'function') {
              scope.videoLoaded();
            }
            logger.mainMenu.log(scope.files);
          });
        });
      }


      scope.$on('$destroy', function () {
        moduleDestroyed = true;
        if (oldScalingValue !== undefined) {
          bngApi.engineLua(`TorqueScript.setVar("$CEF_UI::maxSizeHeight", "${oldScalingValue}")`);
          logger.mainMenu.log(`set uiUpscaling back to: ${oldScalingValue}`);
          oldScalingValue = undefined;
        }
      });
    }
  };
}])


.directive('onlineMessage', ['$sce', 'Utils', 'bngApi', '$state', function ($sce, Utils, bngApi, $state) {
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
              <md-button bng-nav-item ng-click="clicked(btn)" ng-repeat="btn in buttons" class="md-accent md-raised md-padding">{{::btn.label | translate}}</md-button>
            </div>
          </div>
        </md-content>
      </div>
    </div>
    `,
    link: function (scope) {
      var uids = {};

      scope.$on('OnlineMessage', function (ev, data) {
        scope.messageData = data;
        scope.$evalAsync(() => {
          // uid = data.uid;
          for (var key in scope.messageData) {
            switch (scope.messageData[key].contenttype) {
              case 'html':
                scope.messageData[key].msg = $sce.trustAsHtml(scope.messageData[key].msg);
                break;
              case 'bbcode':
                scope.messageData[key].msg = $sce.trustAsHtml(Utils.parseBBCode(scope.messageData[key].msg));
                break;
              default:
                scope.messageData[key].msg = scope.messageData[key].msg;
            }
            uids[key] = scope.messageData[key].uid;
            scope.style =  scope.messageData[key].css //{position: 'fixed', top: 0, left: 0, right: 0, bottom: 0, 'background': ' repeating-linear-gradient(45deg, rgba(0, 0, 0, 0.75), rgba(0, 0, 0, 0.75) 35px, rgba(0, 0, 0, 0.8) 35px, rgba(0, 0, 0, 0.8) 70px)'}
          }
        });
      });

      scope.close = function () {
        for (var key in uids) {
          bngApi.engineLua(`extensions.hook("onUIOnlineMessageHide", "${uids[key]}")`);
        }
        scope.messageData = undefined;
      };

      scope.clicked = function (btn) {
        switch (btn.type) {
          case 'hide-temp':
            scope.messageData = undefined;
            break;
          case 'hide-perm':
            scope.messageData = undefined;
            bngApi.engineLua(`extensions.hook("onUIOnlineMessageHide", "${uid}")`);
            break;
          case 'luacmd':
            bngApi.engineLua(btn.cmd);
            break;
          case 'url':
            document.location.href = btn.url;
            break;
          case 'state':
            $state.go(btn.state, btn.params || {});
            break;
          default:
            console.warn('Unknown action type in online message button');
        }
      }

      bngApi.engineLua('extensions.hook("onUIOnlineMessageReady")');
    }
  }
}])


.controller('MenuController', ['$scope', 'bngApi', 'Utils', '$state', function ($scope, bngApi, Utils, $state) {
  'use strict';
  var vm = this;
  bngApiScope = bngApi;

  vm.showView = false;

  // bngApi.engineLua("extensions.core_input_bindings.menuActive(true)");

  vm.videoLoaded = function () {
    $scope.$evalAsync(() => {
      vm.showView = true;
    });
  };

  function showBack(state) {
    return [ 'menu.mainmenu'
      , 'menu.quickraceOverview'
      , 'menu.onlineFeatures'
      , 'menu.newFeatures'
      , 'menu.skinwizard'
      , 'menu.vehiclewizard'
      , 'menu.terrainwizard'
      , 'menu.busRoutes'
      ].indexOf(state.name) === -1;
  }

  $scope.showBack = showBack($state.current);

  // todo: would this also work with ui-sref-active?
  $scope.$on('$stateChangeSuccess', function (event, toState, toParams, fromState, fromParams) {
    $scope.showBack = showBack(toState);
  });

  bngApi.engineLua('core_modmanager.requestState()');
  $scope.$on('ModManagerModsChanged', function (event, data) {
    var list = data.convertToArray();
    $scope.active = list.filter((elem) => elem.modname != 'translations' && elem.active).length;
    $scope.total = list.filter((elem) => elem.modname != 'translations').length;
  });

  $scope.numActiveObj = () => {return {active: $scope.active, all: $scope.total};};

  $scope.$on('$destroy', () => {
    // bngApi.engineLua("extensions.core_input_bindings.menuActive(false)");
  });

  //$scope.openRepo = function () {
    //window.location.href = 'http-external://www.beamng.com/resources/?ingame=2';
  //};

  //$scope.startResearch = function () {
    //bngApi.engineLua('extensions.util_annotation.start()');
  //}
}])

.controller('MainMenuController', ['$scope', 'toastr', '$state', 'Settings', 'bngApi', '$http', '$filter', 'Utils', 'gamepadNav', function($scope, toastr, $state, Settings, bngApi, $http, $filter, Utils, gamepadNav) {
  'use strict';

  var prevCross = gamepadNav.crossfireEnabled()
    , prevGame = gamepadNav.gamepadNavEnabled()
    , prevSpatial = gamepadNav.gamepadNavEnabled()
  ;

  gamepadNav.enableCrossfire(false);
  gamepadNav.enableGamepadNav(false);
  gamepadNav.enableSpatialNav(true);

  // just in case
  $scope.$on('SettingsChanged', (ev, data) => {
    $scope.values = data.values;
    $scope.options = data.options;
  })

  if (Settings.values.onlineFeatures === 'ask' || Settings.values.telemetry === 'ask') {
    console.log('Settings: ', Settings.values);
    $state.go('menu.onlineFeatures');
  }

  if (Settings.values.showNewFeatures != '4.0' || Settings.values.doNotShowUntilNextUpdate == false) {
    console.log('Settings: ', Settings.values);
    $state.go('menu.newFeatures');
  }

  $scope.values = Settings.values;
  $scope.options = Settings.options;
  $scope.product = beamng.product;



  $http({
    url:'https://api.steampowered.com/ISteamNews/GetNewsForApp/v0002/?format=json&appid=284160&feeds=steam_community_announcements&count=1',
    method: 'GET',
    responseType: 'json'
  }).
  success(function(data) {
    if(data && data.appnews) {
      var options = { weekday: 'short', month: 'long', day: 'numeric' };
      $scope.date = Utils.dateFromUnixTs(data.appnews.newsitems[0].date).toLocaleDateString('en-US', options);
      options.month = 'short';
      $scope.dateShort = Utils.dateFromUnixTs(data.appnews.newsitems[0].date).toLocaleDateString('en-US', options);
    }
  });

  $scope.shipping = beamng.shipping;

  $scope.quit = () => $scope.$emit('quit');

  $scope.garage = function () {
    var luaCmd = `loadGameModeModules(` + bngApi.serializeToLua(["ui_garage"]) + `)`;
    bngApi.engineLua(luaCmd);
  };

  bngApi.engineLua('core_online.requestState()');

  // date format: month/day/year hour:minutes timezone
  var t = "Jul 13, 2018 14:01 GMT+1";
  $scope.nextReleaseDate = new Date(Date.parse(t));
  $scope.nextReleaseDateStr = new Date(t).toString();


  $scope.$on('HardwareInfo', function (event, data) {
    if (data.globalState !== 'ok') {
      for (var key in data) {
        if(data[key].warnings === undefined) continue;

        for (var i=0; i < data[key].warnings.length; i++) {
          if(data[key].warnings[i].ack !== undefined) continue;

          var txt = $filter('translate')('ui.performance.warnings.' + data[key].warnings[i].msg);
          var html = Utils.parseBBCode(txt);
          toastr[(data.globalState === 'warn' ? 'warning' : 'error')](
            $filter('translate')('ui.mainmenu.warningdetails'),//need a unique message
            html,
            {
            positionClass: 'toast-top-right',
            timeOut: 0,
            extendedTimeOut: 0,
            onTap: function () {
              $state.go('menu.help', {
                pageIndex: 'performance'
              });
            }
          });
        }
      }
    }
  });

  $scope.$on('$destroy', () => {
    gamepadNav.enableCrossfire(prevCross);
    gamepadNav.enableGamepadNav(prevGame);
    gamepadNav.enableSpatialNav(prevSpatial);
  });

  bngApi.engineLua('core_hardwareinfo.requestInfo()');
}]);

function openForumLink(){
	bngApiScope.engineLua(`openWebBrowser("http://forum.beammp.com")`);
}

function openExternalLink(url){
	bngApiScope.engineLua(`openWebBrowser("`+url+`")`);
}
