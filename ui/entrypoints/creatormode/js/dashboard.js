angular.module("CreatorConsole")
.controller("DashboardController", ['$scope', '$rootScope', '$interval', 'bngApi', function($scope, $rootScope, $interval, bngApi) {

    $scope.execQuery = 'print(_VERSION)';

    /********************************************************/
    /** Performance graph START */
    var historyLength = 200;
    var startTime = Date.now() / 1000;
    $scope.flotFPSDataSet = [
      { data: [], yaxis: 1, label: 'FPS'},
      { data: [], yaxis: 2, label: 'Physics Delay' },
      { data: [], yaxis: 2, label: 'CPU Delay' },
      { data: [], yaxis: 2, label: 'GPU Delay' },
      { data: [], yaxis: 2, label: 'Lua Delay' },
    ];
    $scope.flotFPSOptions = {
        grid: {
        },
        legend: {
            show: true,
            position: "sw"
        },
        //xaxes: [ { mode: "time" } ],
        yaxes: [ {min: 0}, { position: 'right'} ],
    }

    $interval(function() {
      if($rootScope.engineConnectionState != 'connected') return;
      bngApi.engineLua('return getPerformanceMetrics()', function(d) {
        //console.log(d);
        $scope.$apply(function() {
          var ts = (Date.now() / 1000) - startTime;
          $scope.flotFPSDataSet[0].data.push([ts, d.result.fps]);
          $scope.flotFPSDataSet[1].data.push([ts, d.result.physDelay]);
          $scope.flotFPSDataSet[2].data.push([ts, d.result.cpuPreRender + d.result.cpuRender + d.result.cpuPostRender]);
          $scope.flotFPSDataSet[3].data.push([ts, d.result.gpuDelay]);
          $scope.flotFPSDataSet[4].data.push([ts, d.result.luaDelay]);
          if($scope.flotFPSDataSet[0].data.length > historyLength) {
            for(var i = 0; i < 5; i++) {
              $scope.flotFPSDataSet[i].data.shift();
            }
          }
        });
      });
    }, 250);
    /** Performance graph END */

    $scope.runEngineLua = function(q) {
        //console.log('runEngineLua', q)
        bngApi.engineLua(q, function(d) {
        $scope.$apply(function() {
          var ok = false;
          $scope.execResult = '';
          if (d.cmd !== undefined) {
            $scope.execResult = "> " + d.cmd + "\n";
            ok = true;
          }
          if (d.stdOut && d.stdOut.length > 0) {
            $scope.execResult += d.stdOut.join("\n");
            ok = true;
          }
          if (d.result) {
            $scope.execResult += JSON.stringify(d.result, null, '  ');
            ok = true;
          }
          if(!ok) {
            $scope.execResult = 'error';
          }
        });
      });
    }
}]);
