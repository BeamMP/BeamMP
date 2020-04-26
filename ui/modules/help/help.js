angular.module('beamng.stuff')

.controller('HelpController', ['$log', '$scope', '$stateParams', '$state', '$timeout', '$filter', '$http', '$sce', '$sanitize', 'bngApi', 'Utils',
  function($log, $scope, $stateParams, $state, $timeout, $filter, $http, $sce, $sanitize, bngApi, Utils) {
  // set up the display
  $scope.useThemeBackground = true;
  $scope.tabs = [
    {
      name: 'help',
      title: 'ui.faq',
      html: 'modules/help/faq.html'
    },
    {
      name: 'performance',
      title: 'ui.performance',
      html: 'modules/help/performance.html'
    },
    // {
    //   name: 'changelog',
    //   title: 'ui.changelog',
    //   html: 'modules/help/changelog.html'
    // }
  ];

  function findId (name) {
    //legacy will remove when back from holdiay to be sure we don't miss something
    if (!isNaN(Number(name))) {
      return Number(name);
    }
    for (var i = 0; i < $scope.tabs.length; i+=1) {
      if ($scope.tabs[i].name === name) {
        return i;
      }
    }
    return -1;
  }

  $scope.currentView = findId($stateParams.pageIndex) || 0;
  // console.log(findId($stateParams.pageIndex));
  $scope.changeView = function(i) {
    $state.transitionTo('menu.help', {pageIndex: i});
  };
  $scope.linkTo = function(location) {
    $state.transitionTo(location);
  };

  bngApi.engineLua('settings.requestState()');

  $scope.$on('SettingsChanged', function (event, data) {
    //console.log('onHardwareInfo', data)
    $scope.$apply(function() {
      $scope.settings = data.values;
    });
  });

  $scope.openTabs = [true];

  $scope.BBToHtml = function (code) {
    return $sce.trustAsHtml(Utils.parseBBCode(code));
  }

  // changelog tab
  $http.get('https://api.steampowered.com/ISteamNews/GetNewsForApp/v0002/?format=json&appid=284160&feeds=steam_community_announcements').
  success(function(data) {
    // console.log(arguments);
    // console.log(data.appnews.newsitems);
    $scope.changelogExists = true;

    $scope.changelog = data.appnews.newsitems.map(function(elem) {
      elem.html = $scope.BBToHtml(elem.contents);
      elem.date = Utils.dateFromUnixTs(elem.date).toDateString();
      return elem;
    });
  }).
  error(function() {
    // console.log(arguments);
    $scope.changelogExists = false;
  });

  // perforamnce tab
  $scope.requestHardwareInfo = function() {
    bngApi.engineLua('core_hardwareinfo.requestInfo()');
  };
  $scope.$on('HardwareInfo', function (event, data) {
    //console.log('onHardwareInfo', data)
    $scope.$apply(function() {
      $scope.hwinfo = data;
      $scope.hstxt = $sce.trustAsHtml(Utils.parseBBCode($sanitize($filter('translate')('ui.performance.highsea.txt'))));
    });
  });


  $scope.bananabenchRunning = false;

  $scope.runPhysicsBenchmark = function() {
    $scope.bananabenchRunning = true;
    bngApi.engineLua('core_hardwareinfo.runPhysicsBenchmark()');
  };

  $scope.$on('BananaBenchReady', function (event, data) {
    $scope.$evalAsync(() => {
      $scope.bananabenchRunning = false;
      $scope.bananabench = data;
      $scope.bananabench.testVehicle = Object.keys(data.tests)[0];
      $scope.bananabench.test = data.tests[$scope.bananabench.testVehicle];
      $scope.benchmarkExists = true;
      //console.log($scope.bananabench);
    });
  });
  bngApi.engineLua('core_hardwareinfo.latestBenchmarkExists()', function(res) {
    if (res) {
      bngApi.engineLua('core_hardwareinfo.latestBananbench()', function(data) {
        $scope.$evalAsync(() => {
          $scope.bananabench = data;
          $scope.bananabench.testVehicle = Object.keys(data.tests)[0];
          $scope.bananabench.test = data.tests[$scope.bananabench.testVehicle];
        });
      });
    }
    $scope.$evalAsync(() => {
      $scope.benchmarkExists = res;
    });
  });

  $scope.acknowledgeWarning = function(msg) {
    bngApi.engineLua(`core_hardwareinfo.acknowledgeWarning(${bngApi.serializeToLua(msg)})`);
  }

  $scope.runDiskUsage = function() {
    bngApi.engineLua('core_hardwareinfo.runDiskUsage()');
  };
  $scope.$on('diskInfoCallback', function (event, data) {
    $scope.$evalAsync(() => {
      if($scope.disk == undefined)
        $scope.disk= {};
      if($scope.disk.usage == undefined)
        $scope.disk.usage= {};
      $scope.disk.usage[data.name] = {running: data.running, size: data.size};
      // console.log($scope.disk);
    });
  });

  $scope.bytes = function(bytes, precision) {
    precision = precision || 1;
    var number = Math.floor(Math.log(bytes) / Math.log(1024));
    return (bytes / Math.pow(1024, Math.floor(number))).toFixed(precision);
  };

  var recRefHWPromise = {};
  function recRefHW() {
    recRefHWPromise = $timeout(
      function() {
        // console.log('updating hws automatically');
        $scope.requestHardwareInfo();
        recRefHW();
      },
      5000
    );
  }

  $scope.requestHardwareInfo();
  $scope.$watch(
    function(scope) {return scope.currentView; },
    function() {
      if ($scope.currentView === 3) {
        recRefHW();
      } else if (recRefHWPromise !== {}) {
        $timeout.cancel(recRefHWPromise);
      }
    }
  );
  $scope.$on('$destroy', function() {
    if (recRefHWPromise !== {}) {
      $timeout.cancel(recRefHWPromise);
    }
  });

}]);
