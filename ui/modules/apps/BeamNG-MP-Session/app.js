var players = [];
var app = angular.module('beamng.apps');
app.directive('multiplayersession', ['UiUnits', function (UiUnits) {
	return {
		templateUrl: 'modules/apps/BeamNG-MP-Session/app.html',
		replace: true,
		restrict: 'EA',
		scope: true
	}
}]);
app.controller("MP", ['$scope', 'bngApi', function ($scope, bngApi) {

	var count = 0;
	var countUpdateInterval = null;
	var spamLocked = false;

	$scope.init = function() {
		countUpdateInterval = setInterval(updateCount, 20000);
	};

	$scope.select = function() {
		bngApi.engineLua('setCEFFocus(true)');
	}

	$scope.chatSend = function() {
		if (count > 12 || spamLocked) {
			spamLimit();
		}
		else {
			var cm = document.getElementById("CHATMESSAGE");
			if (cm.value) {
				if (cm.value.length > 150) {
					msgTooLong();
				}
				else {
					var msg = "ChatSend Pressed.";
					bngApi.engineLua('UI.console("'+ String(msg) + '")');
					bngApi.engineLua('UI.chatSend("'+ String(cm.value) + '")');
					cm.value = '';
					count++;
				}
			}
		}
	};

	function updateCount() {
		count = 0;
	}

	function msgTooLong() {
		addMessage("Your message should not be longer than 150 characters!");
	}

	function spamLimit() {
		if (!spamLocked) {
			spamLock();
		}
		addMessage("Spam warning: your chat has been locked for 20 seconds");
	}

	function spamLock() {
		spamLocked = true;
		clearInterval(countUpdateInterval);
		countUpdateInterval = null;
		count = 0;
		setTimeout(spamUnlock, 20000);
	}

	function spamUnlock() {
		countUpdateInterval = setInterval(updateCount, 20000)
		spamLocked = false;
	}
}]);

function addMessage(msg) {
	var node = document.createElement("li");
	node.style.marginBottom = "4px";
	var textnode = document.createTextNode(msg);
	var chat = document.getElementById("CHAT")
	node.appendChild(textnode);
	chat.appendChild(node);

	if (chat.children.length > 70) {
		chat.removeChild(chat.children[0]);
	}

	chat.scrollTop = chat.scrollHeight;
}

function greeting(server) {
	addMessage("You are now connected to " + server);
	addMessage("Welcome to chat! Chat box is at the bottom of your screen. Message length limit is 150 characters.");
}

function playerList(list) {
	clearPlayerList();
	var parsedList = JSON.parse(list);
	var playersList = document.getElementById("players");
	for (var i = 0; i < parsedList.length; i++) {
		var node = document.createElement("span");
		if (i==parsedList.length-1) {
			var text = document.createTextNode(parsedList[i].nickname);
		} else {
			var text = document.createTextNode(parsedList[i].nickname+", ");
		}
		node.appendChild(text);
		playersList.appendChild(node);
	}
}

function clearPlayerList() {
	var playersList = document.getElementById("players");
	while (playersList.children.length > 0) {
		playerList.removeChild(playerList.children[0]);
	}
}

function setOfflineInPlayerList() {
	var playersList = document.getElementById("players");
	var node = document.createElement("span");
	var text = document.createTextNode("OFFLINE");
	node.appendChild(text);
	playersList.appendChild(node);
}