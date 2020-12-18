(function () {
//'use strict';

angular.module('beamng.stuff')

.controller('multiplayerInfoPopupController', ['$scope', 'bngApi', '$state', '$timeout', '$document', function($scope, bngApi, $state, $timeout, $document) {
  //'use strict';
  console.log("aaaaaaaaaaaaaaa IM HERE")
  // The lua setting need to be functional before we redirect, otherwise we'll land here again.
  // for that reason, we listen for the settings changed event that will ensure that the main menu will not get back here again

  //var selectedAnswer = false;
  //$scope.online = null;
  //$scope.telemetry = null;

  //$scope.storeAnswer = function () {
    //if ($scope.online == null) {
      //return;
    //}

    //if ($scope.online != 'enable') {
      //$scope.telemetry = 'disable';
    //}


    //var newState = {
      //multiplayerInfoPopup: $scope.
    //};

    //bngApi.engineLua(`settings.setState(${bngApi.serializeToLua(newState)})`);

    //selectedAnswer = false;
  //};
  $scope.toMainMenu = function()
  {
    $state.go('menu.mainmenu');
  };
   $scope.setDontShowAgain() = function(state)
  {
    console.log(state);
  };

}]);

})();