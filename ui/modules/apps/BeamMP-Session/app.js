var app = angular.module('beamng.apps');

app.directive('multiplayersession', ['UiUnits', function (UiUnits) {
	return {
		templateUrl: 'modules/apps/BeamMP-Session/app.html',
		replace: true,
		restrict: 'EA',
		scope: true
	}
}]);

app.controller("Session", ['$scope', 'bngApi', function ($scope, bngApi) {
	$scope.init = function() {
		bngApi.engineLua('UI.ready("MP-SESSION")');
	};

	$scope.mpquit = function() {
		bngApi.engineLua('MPCoreNetwork.resetSession(1)');
	};

	$scope.reset = function() {
		$scope.init();
	};

	$scope.select = function() {
		bngApi.engineLua('setCEFFocus(true)');
	};

	$scope.$on('setPing', function (event, ping) {
    document.getElementById("Session-Ping").innerHTML = ping;
	});

	$scope.$on('setStatus', function (event, status) {
		console.log('Setting Status to: ')
		console.log(sanitizeString(status))
		document.getElementById("Session-Status").innerHTML = sanitizeString(status); // DISPLAY SERVER NAME FORMATTING
	});

	$scope.$on('setPlayerCount', function (event, count) {
    document.getElementById("Session-PlayerCount").innerHTML = count;
	});
}]);

function sanitizeString(str) {  // VERY basic sanitization.
	str = str.replace(/<script.*?<\/script>/g, '');
	str = str.replace(/<button.*?<\/button>/g, '');
	str = str.replace(/<iframe.*?<\/iframe>/g, '');
	str = str.replace(/<a.*?<\/a>/g, '');
    return str
}
