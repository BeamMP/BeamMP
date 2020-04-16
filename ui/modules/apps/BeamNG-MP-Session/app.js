var app = angular.module('beamng.apps');
app.directive('multiplayersession', ['UiUnits', function (UiUnits) {
	return {
		templateUrl: 'modules/apps/BeamNG-MP-Session/app.html',
		replace: true,
		restrict: 'EA',
		scope: true
	}
}]);
app.controller("Session", ['$scope', 'bngApi', function ($scope, bngApi) {
	$scope.init = function() {
		bngApi.engineLua('UI.ready("MPSESSION")');
	};

	$scope.reset = function() {
		$scope.init();
	};

	$scope.select = function() {
		bngApi.engineLua('setCEFFocus(true)');
	};
}]);

function setPing(ping) {
	document.getElementById("Session-Ping").innerHTML = ping;
}

function setStatus(status) {
	document.getElementById("Session-Status").innerHTML = status;
}

function setPlayerCount(count) {
	document.getElementById("Session-PlayerCount").innerHTML = count;
}
