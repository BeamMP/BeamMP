'use strict'

angular.module('beamng.stuff')

.controller('MultiplayerPauseController', ['$rootScope', '$scope', 'toastr', '$state', 'Settings', '$http', '$filter', 'Utils', 'gamepadNav', 'ConfirmationDialog', 'translateService', 'MessageToasterService', function($rootScope, $scope, toastr, $state, Settings, $http, $filter, Utils, gamepadNav, ConfirmationDialog, translateService, messageToasterService) {

  $scope.exitingMultiplayer = false


  $scope.exitingMultiplayerSwitch = function() {
    $scope.exitingMultiplayer = !$scope.exitingMultiplayer
  }

  function infoToast(str) {
    toastr['info'](translateService.contextTranslate(str, true), "", messageToasterService.toastOptions)
  }

  $scope.exit = function() {
    ConfirmationDialog.open(
      "ui.multiplayer.exitToMainMenuTitle", "ui.multiplayer.exitToMainMenuPrompt",
      [
        { label: "ui.common.yes", key: 1, default: true },
        { label: "ui.common.no", key: 0, isCancel: true },
      ], {lastSave: $scope.lastSave}
    ).then(res => {
      if (!res) {
        $scope.exitingMultiplayer = false
        return;
      }
      else {
        bngApi.engineLua('MPCoreNetwork.leaveServer(true)');
      }
    });
  }

  /*$scope.exitToFreeroam = function() {
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
  }*/

  $scope.exitToDesktop = function() {
    if ($scope.tutorialActive) {
      bngApi.engineLua("quit()");
      return;
    }
    ConfirmationDialog.open(
      "ui.multiplayer.exitToDesktopTitle", "ui.multiplayer.exitToDesktopPrompt",
      [
        { label: "ui.common.yes", key: 1, default: true },
        { label: "ui.common.no", key: 2, isCancel: true },
      ]
    ).then(res => {
      if (!res) {
        $scope.exitingMultiplayer = false
        return;
      }
      else {
        bngApi.engineLua("quit()");
      }
    });
  }

  $scope.reportPlayer = function(player) {
    console.log(player)
    ConfirmationDialog.open(
      "ui.multiplayer.reportTitle", "ui.multiplayer.reportPrompt",
      [
        { label: "ui.common.cancel", key: false, isCancel: true },
        // { label: "Enter and don't show this again", key: true },
        { label: "ui.common.submit", key: true, default: true },
      ],
      { class: "experimental" },
      `You are currently reporting ${player.name}`
    ).then(res => {
      if (!res)
        return;
      $state.go("menu.career");
    });
  }

  $scope.hidePlayer = function(player) {
    bngApi.engineLua('MPVehicleGE.togglePlayerHidden("'+player.name+'")')
  }

  $scope.mutePlayer = function(player) {
    bngApi.engineLua('MPVehicleGE.togglePlayerMuted("'+player.name+'")')
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