angular.module('beamng.stuff')

.controller('SPDragRaceController', ['$scope', '$stateParams', function ($scope, $stateParams) {
    $scope.curVehName = $stateParams.data.currentVehicle;
    $scope.$emit('ShowApps', false);

    $scope.start = function() {
      $scope.$emit('ShowApps', true);
      bngApi.engineLua('mpGameModes_dragRace_dragRace.startSP()');
    }
}]);
