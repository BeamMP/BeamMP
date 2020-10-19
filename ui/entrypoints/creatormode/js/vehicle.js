angular.module("CreatorConsole")
.controller("VehicleController", ['$scope', '$rootScope', '$interval', '$stateParams', 'bngApi', function($scope, $rootScope, $interval, $stateParams, bngApi) {
  $scope.execQuery = 'print(_VERSION)';

  $scope.id = $stateParams.id;
  $scope.logs = new Array();
  
  //bngApi.objectCall($scope.id, {api: 'setupLogSink'});


  $rootScope.$on('log', function(evt, instance, logPackage) {
    console.log('LOG MESSAGE: ' , instance, logPackage)
    if(instance == $scope.id) {
      $scope.$apply(function() {
        for(var i = 0; i < logPackage.data.length; i++) {
          $scope.logs.push(logPackage.data[i]);
        }
      })
    }
  })



  $scope.runVehicleLua = function(cmd) {
    var vehId = $scope.id;
    console.log('runVehicleLua', vehId, cmd)
    bngApi.objectLua(vehId, cmd, function(d) {
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
