var connected = false;
var app = angular.module('beamng.apps');
app.directive('multiplayer', ['UiUnits', function (UiUnits) {
	return {
		templateUrl: 'modules/apps/BeamNG-MP/app.html',
		replace: true,
		restrict: 'EA',
		scope: true
	}
}]);
app.controller("Servers", ['$scope', 'bngApi', function ($scope, bngApi) {
	$scope.warnVis = false;
	$scope.timer = null;

	$scope.init = function() {
		bngApi.engineLua('UI.ready("MP")');
	}

	$scope.select = function() {
		bngApi.engineLua('setCEFFocus(true)');
	}

	$scope.connect = function() {
		if (!connected) {
			var inputs = document.getElementById("form").elements;
			var ip = inputs["IP"].value;
			var port = inputs["PORT"].value;
			var nickname = inputs["NICKNAME"].value;
			if(port === "") {
			port = "4444"
			}
			if (ip === "") {
				ip = "localhost"
			}
			if (nickname.length < 3 || nickname.includes("\\") || nickname.includes("\"") || nickname.includes("'") || nickname.includes("+")) {
				console.log('Nickname must be longer than 3 chars, cannot contain backslashes, quotes or a plus sign!')
				bngApi.engineLua('UI.error("Illegal nickname.")')
				addWarning();
			}
			else {
				bngApi.engineLua('UI.setNickname("'+ nickname.substring(0, 30) + '")');
				bngApi.engineLua('UI.joinSession("'+ ip + '","' + port + '")');
				connected = true;
			}
		}
	}

	$scope.disconnect = function() {
		bngApi.engineLua('Network.disconnectFromServer()');
		setPing("");
		connected = false;
	}

	function addWarning() {
		if (!$scope.warnVis) {
			$scope.warnVis = true;
			timer = setTimeout(function() {
				$scope.warnVis = false;
			}, 10000)
		}
	}
}]);

function setPing(ping) {
	document.getElementById("PING").innerHTML = ping;
}

function setStatus(status) {
	document.getElementById("STATUS").innerHTML = status;
}

function setDisconnect() {
	connected = false;
}