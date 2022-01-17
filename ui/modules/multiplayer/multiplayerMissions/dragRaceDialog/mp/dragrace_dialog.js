angular.module('beamng.stuff')

.controller('MPDragRaceController', ['$scope', '$stateParams', function ($scope, $stateParams) {
    $scope.plist = $stateParams.playerList.playerList;

    $scope.selectedPlayer = null;

    $scope.$emit('ShowApps', false);

    $scope.invite = function() {
      if ($scope.selectedPlayer == null) return;

      $scope.$emit('ShowApps', true);

      let json = JSON.stringify({
        "player1" : $stateParams.playerList.self,
        "player2" : $scope.selectedPlayer
      });

      bngApi.engineLua("mpGameModes_dragRace_dragRace.sendInvite('"+json+"')");
    }

    $scope.selectPlayer = function(entry) {
      $scope.selectedPlayer = entry;
    }
}]);
