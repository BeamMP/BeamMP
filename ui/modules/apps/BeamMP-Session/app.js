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
		bngApi.engineLua('UI.ready("MP-SESSION")'); // needed to get the server name
	};

	$scope.mpquit = function() {
		bngApi.engineLua('MPCoreNetwork.resetSession(1)');
	};

	$scope.applyQueue = function() {
		bngApi.engineLua('MPVehicleGE.applyQueuedEvents()');
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

	$scope.$on('setQueue', function (event, queue) {
		if (queue.show) document.getElementById("queue-block").style.display = "";
		else { document.getElementById("queue-block").style.display = "none"; return;}
		
		var queueCount = queue.editCount + queue.spawnCount;
		var queueElem = document.getElementById("Session-Queue")
		queueElem.innerHTML = `${queue.spawnCount}|${queue.editCount}`;
		queueElem.title = `Edits: ${queue.editCount}\nSpawns: ${queue.spawnCount}`; // titles dont work in game :C

	});

	$scope.$on('setStatus', function (event, status) {
		console.log('Setting status to: ' + sanitizeString(status))
		if (status == "") document.getElementById("server-name-block").style.display = "none";
		else document.getElementById("server-name-block").style.display = "";
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
