'use strict'

angular.module('beamng.stuff')

.controller('MultiplayerPauseController', ['$rootScope', '$scope', 'toastr', '$state', 'Settings', '$http', '$filter', 'Utils', 'gamepadNav', 'ConfirmationDialog', 'translateService', 'MessageToasterService', function($rootScope, $scope, toastr, $state, Settings, $http, $filter, Utils, gamepadNav, ConfirmationDialog, translateService, messageToasterService) {

  $scope.exitingMultiplayer = false


  $scope.exitingMultiplayerSwitch = function() {
    $scope.exitingMultiplayer = !$scope.exitingMultiplayer
  }

  $scope.goToLogbook = function(entryId) {
    if(entryId !== undefined)
      $state.go("logbook",{id: (''+entryId).replace(/\//g, '%')})  // forward slashes breaking routing (angular?) - a bit of a hack to fix it
    else
      $state.go("logbook")
  }

  $scope.resume = function() {
    $state.go("play");
  }

  $scope.load = function() {
    if ($scope.tutorialActive) {
      $state.go("menu.career");
      return;
    }
    ConfirmationDialog.open(
      "Your progress will be lost", "Make sure to save before loading",
      [
        { label: "Continue", key: true, default: true },
        { label: "Cancel", key: false, isCancel: true }
      ]
    ).then(res => {
      if (!res) {
        return;
      }
      $state.go("menu.career");
    });
  }

  function infoToast(str) {
    toastr['info'](translateService.contextTranslate(str, true), "", messageToasterService.toastOptions)
  }

  $scope.exit = function() {
    if ($scope.tutorialActive) {
      bngApi.engineLua("career_career.deactivateCareer()");
      bngApi.engineLua("endActiveGameMode()");
      $state.go("menu.mainmenu");
      return;
    }
    //Maybe there is a mistake here? Discuss with les seniors
    ConfirmationDialog.open(
      null, "ui.career.exitPrompt",
      [
        { label: "ui.common.yes", key: 1, default: true },
        { label: "ui.common.no", key: 2, isCancel: false },
        { label: "ui.common.cancel", key: 0, isCancel: true }
      ], {lastSave: $scope.lastSave}
    ).then(res => {
      if (!res) {
        $scope.exitingMultiplayer = false
        return;
      }
      else if (res === 2) {
        bngApi.engineLua("career_career.deactivateCareer()");
        bngApi.engineLua("endActiveGameMode()");
        $state.go("menu.mainmenu");
      }
      else {
        bngApi.engineLua("career_saveSystem.saveCurrent()", () => {
          $scope.exitCareerTo = "mainMenu"
        });
      }
    });
  }

  $scope.exitToFreeroam = function() {
    if ($scope.tutorialActive) {
      bngApi.engineLua("career_career.deactivateCareerAndReloadLevel()");
      $state.go("play");
      return;
    }
    ConfirmationDialog.open(
      null, "ui.career.exitPrompt",
      [
        { label: "ui.common.yes", key: 1, default: true },
        { label: "ui.common.no", key: 2, isCancel: false },
        { label: "ui.common.cancel", key: 0, isCancel: true }
      ], {lastSave: $scope.lastSave}
    ).then(res => {
      if (!res) {
        $scope.exitingMultiplayer = false
        return;
      }
      else if (res === 2) {
        bngApi.engineLua("career_career.deactivateCareerAndReloadLevel()");
        $state.go("play")
      }
      else {
        bngApi.engineLua("career_saveSystem.saveCurrent()", () => {
          $scope.exitCareerTo = "freeroam"
        });
      }
    });
  }

  $scope.exitToDesktop = function() {
    if ($scope.tutorialActive) {
      bngApi.engineLua("quit()");
      return;
    }
    ConfirmationDialog.open(
      null, "ui.career.exitPrompt",
      [
        { label: "ui.common.yes", key: 1, default: true },
        { label: "ui.common.no", key: 2, isCancel: false },
        { label: "ui.common.cancel", key: 0, isCancel: true }
      ], {lastSave: $scope.lastSave}
    ).then(res => {
      if (!res) {
        $scope.exitingMultiplayer = false
        return;
      }
      else if (res === 2) {
        bngApi.engineLua("quit()");
      }
      else {
        bngApi.engineLua("career_saveSystem.saveCurrent()", () => {
          $scope.exitCareerTo = "quit"
        });
      }
    });
  }

  $scope.$on('playerList', function(event, data) {
		let parsedList = JSON.parse(data);

    parsedList.sort(function(a, b) {
      var keyA = a.id,
          keyB = b.id;
      // Compare the 2 ID's
      if (keyA < keyB) return -1;
      if (keyA > keyB) return 1;
      return 0;
    });

    const a = JSON.stringify(angular.toJson(parsedList))
    const b = JSON.stringify(angular.toJson($scope.playersList))

    if (a != b) {
      $scope.playersList = parsedList;
    }
  })

  function updateSessionDetails() {
    bngApi.engineLua("MPCoreNetwork.getCurrentServer()", data => {
      console.log(data)
      $scope.serverName = data.name
    })
  }
  // Init
  updateSessionDetails()
}])