angular.module('beamng.apps')
.directive('multiplayer', ['UiUnits', function (UiUnits) {
	return {
		templateUrl: 'modules/apps/BeamNG-MP/app.html',
		replace: true,
		restrict: 'EA',
		scope: true,
		controller: ['$log', '$scope', 'bngApi', function ($log, $scope, bngApi) {
			$scope.mainStyle = {appWidth: "100%", appHeight: "100%", inLeft: "auto", inRight: "4px", appShow: "visible", groupsShow: "hidden"};
			$scope.visible = {main: true};

			$scope.enterMouse = function() {
				bngApi.engineLua('setCEFFocus(true)');
			};

			$scope.init = function() {
				console.log('UI Loaded');
				bngApi.engineLua('UI.ready()');
			}

			$scope.chatSend = function() {
				var msg = "ChatSend Pressed.";
				bngApi.engineLua('UI.console("'+ String(msg) + '")');
				var cm = document.getElementById("CHATMESSAGE").value;
				document.getElementById("CHATMESSAGE").value = '';
				bngApi.engineLua('UI.chatSend("'+ String(cm) + '")');
			}

			$scope.joinSession = function() {
				var ip = document.getElementById("IP").value;
				var port = document.getElementById("PORT").value;
				var nickname = document.getElementById("NICKNAME").value;
				var ready = true;

				if(port === "") {
				   console.log('Input is not alphanumeric setting default value 4444');
				   port = 4444
				}

				if (ip === "") {
					console.log('Input IP is empty setting default value localhost')
					ip = "localhost"
				}

				if (nickname.length < 3) {
					console.log('Nickname is too short. At least 3 characters are required.')
					bngApi.engineLua('UI.error("Your nickname is too short, min of 3 characters.")')
					document.getElementById("NICKNAME").style.border = "1px solid red";
					document.getElementById("statusText").innerHTML = "Status: nickname too short (3 chars min)"
					ready = false;
				}

				if (nickname.length > 30) {
					console.log('Nickname is too long. A maximum of 30 characters is allowed.')
					bngApi.engineLua('UI.error("Your nickname is too long, max 30 characters.")')
					document.getElementById("NICKNAME").style.border = "1px solid red";
					document.getElementById("statusText").innerHTML = "Status: nickname too long (30 chars max)"
					ready = false;
				}

				if (nickname.includes("\\")) {
					console.log('Your nickname contain illegal character.')
					bngApi.engineLua('UI.error("Your nickname contain illegal character.")')
					document.getElementById("NICKNAME").style.border = "1px solid red";
					document.getElementById("statusText").innerHTML = "Status: nickname can't contain backslash ( \\ )"
					ready = false;
				}

				if (nickname.includes("\"")) {
					console.log('Your nickname contain illegal character.')
					bngApi.engineLua('UI.error("Your nickname contain illegal character.")')
					document.getElementById("NICKNAME").style.border = "1px solid red";
					document.getElementById("statusText").innerHTML = "Status: nickname can't contain quotes ( \" )"
					ready = false;
				}

				if (nickname.includes("+")) {
					console.log('Your nickname contain illegal character.')
					bngApi.engineLua('UI.error("Your nickname contain illegal character.")')
					document.getElementById("NICKNAME").style.border = "1px solid red";
					document.getElementById("statusText").innerHTML = "Status: nickname can't contain plus ( + )"
					ready = false;
				}

				if (ready) {
					document.getElementById("NICKNAME").style.border = "";
					bngApi.engineLua('UI.setNickname("'+ String(nickname) + '")')
					bngApi.engineLua('UI.joinSession("'+ String(ip) + '",' + parseInt(port) + ')')
				}
			}

			$scope.hostSession = function() {
				var command = `UI.hostSession()`;
				bngApi.engineLua(command);
			}
		}]
	}
}]);
