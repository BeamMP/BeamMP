var connected = false;
var players = [];
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
	let count = 0;
	let countUpdateInterval = null;
	let spamLocked = false;

	$scope.init = function() {
		bngApi.engineLua('UI.ready("MP")');
		countUpdateInterval = setInterval(updateCount, 20000);
	};

	$scope.reset = function() {
		connected = false;
		players = [];
		$scope.init();
	};

	$scope.select = function() {
		bngApi.engineLua('setCEFFocus(true)');
	};

	$scope.connect = function() {
		if (!connected) {
			let inputs = document.getElementById("form").elements;
			let ip = inputs["IP"].value;
			let port = inputs["PORT"].value;
			let nickname = inputs["NICKNAME"].value;
			if(port === "") {
			port = "4444"
			}
			if (ip === "") {
				ip = "localhost"
			}
			if (nickname.length < 3 || nickname.includes("\\") || nickname.includes("\"") || nickname.includes("'") || nickname.includes("+")) {
				console.log('Nickname must be longer than 3 chars, cannot contain backslashes, quotes or a plus sign!');
				bngApi.engineLua('UI.error("Illegal nickname.")');
				addWarning();
			}
			else {
				bngApi.engineLua('UI.setNickname("'+ nickname.substring(0, 30) + '")');
				bngApi.engineLua('UI.joinSession("'+ ip + '","' + port + '")');
				connected = true;
			}
		}
	};

	$scope.disconnect = function() {
		bngApi.engineLua('Network.disconnectFromServer()');
		setPing("");
		connected = false;
	};

	$scope.select = function() {
		bngApi.engineLua('setCEFFocus(true)');
	};

	$scope.chatSend = function() {
		if (count > 12 || spamLocked) {
			spamLimit();
		}
		else {
			let cm = document.getElementById("CHATMESSAGE");
			if (cm.value) {
				if (cm.value.length > 150) {
					msgTooLong();
				}
				else {
					let msg = "ChatSend Pressed.";
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

	function addWarning() {
		if (!$scope.warnVis) {
			$scope.warnVis = true;
			$scope.timer = setTimeout(function() {
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

function addMessage(msg) {
	let node = document.createElement("li");
	node.style.marginBottom = "4px";
	let textnode = document.createTextNode(msg);
	let chat = document.getElementById("CHAT");
	node.appendChild(textnode);
	chat.appendChild(node);

	if (chat.children.length > 70) {
		chat.removeChild(chat.children[0]);
	}

	chat.scrollTop = chat.scrollHeight;
}

function greeting(server) {
	addMessage("You are now connected to " + server);
	addMessage("Welcome to chat! Our message length limit is 150 characters.");
}

function playerList(list) {
	clearPlayerList();
	let parsedList = JSON.parse(list);
	let playersList = document.getElementById("players");
	for (let i = 0; i < parsedList.length; i++) {
		let node = document.createElement("span");
		let text;
		if (i===parsedList.length-1) {
			text = document.createTextNode(parsedList[i].nickname);
		} else {
			text = document.createTextNode(parsedList[i].nickname+", ");
		}
		node.appendChild(text);
		playersList.appendChild(node);
	}
}

function clearPlayerList() {
	let playersList = document.getElementById("players");
	while (playersList.children.length > 0) {
		playersList.removeChild(playersList.children[0]);
	}
}

function setOfflineInPlayerList() {
	let playersList = document.getElementById("players");
	let node = document.createElement("span");
	let text = document.createTextNode("OFFLINE");
	node.appendChild(text);
	playersList.appendChild(node);
}
