angular.module('beamng.apps')
.directive('multiplayersession', ['UiUnits', function (UiUnits) {
	return {
		templateUrl: 'modules/apps/BeamNG-MP-Session/app.html',
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
				console.log('Session UI Loaded');
				bngApi.engineLua('UI.ready("Session")');
			}

			$scope.UpdateChat = function(msg) {
				console.log("Chat Message: "+msg)
				var node = document.createElement("LI");
				var textnode = document.createTextNode(msg);
				node.appendChild(textnode);
				document.getElementById("CHAT").appendChild(node);
				updateScroll();
			}

			$scope.UpdateSession = function(msg) {
				console.log("Chat Message: "+msg)
				var node = document.createElement("LI");
				var textnode = document.createTextNode(msg);
				node.appendChild(textnode);
				document.getElementById("CHAT").appendChild(node);
				updateScroll();
			}

			$scope.chatSend = function() {
				var msg = "ChatSend Pressed.";
				bngApi.engineLua('UI.console("'+ String(msg) + '")');
				var cm = document.getElementById("CHATMESSAGE").value;
				document.getElementById("CHATMESSAGE").value = '';
				bngApi.engineLua('UI.chatSend("'+ String(cm) + '")');
			}
		}]
	}
}]);
