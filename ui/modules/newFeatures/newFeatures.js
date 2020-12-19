(function () {
'use strict';

angular.module('beamng.stuff')
  /**
  * @ngdoc controller
  * @name beamng.stuff:NewFeaturesController
  * @requires $scope
  * @requires bngApi
  * @requires $state
  * @requires $timeout
  * @requires $document
  *
  * @description
  * Basic controller for the new features scene
  **/
  .controller('NewFeaturesController', ['$scope', 'bngApi', '$state', '$timeout', '$document', function($scope, bngApi, $state, $timeout, $document) {
    console.log("aaaaaaaaaaaaaaa IM HERE")
    // The lua setting need to be functional before we redirect, otherwise we'll land here again.
    // for that reason, we listen for the settings changed event that will ensure that the main menu will not get back here again
    var vm = this;
    $scope.showNewFeatures = null;
    $scope.hide = null;
    vm.doNotShowUntilNextUpdate = false;

    $scope.toMainMenu = function() {
      $scope.hide = false

      if ($scope.doNotShowUntilNextUpdate == true) {
        $scope.doNotShowUntilNextUpdate = 'disable';
      }


      var newState = {
        showNewFeatures: '4.0',
        doNotShowUntilNextUpdate: $scope.doNotShowUntilNextUpdate
      };

      bngApi.engineLua(`settings.setState(${bngApi.serializeToLua(newState)})`);
      $state.go('menu.mainmenu');
    };

    $scope.setDontShowAgain = function(state) {
      console.log(state);
    };
  }]);
})();
