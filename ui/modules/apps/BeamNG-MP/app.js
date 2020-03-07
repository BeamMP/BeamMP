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
				console.log("TEST" + nickname);
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

	$scope.chatClear = function() {
		chatClear();
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
					bngApi.engineLua('UI.console("ChatSend Pressed"); UI.chatSend("'+ String(cm.value) + '")');
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
	//getting current time and adding it to the message before displaying
	var now = new Date();
    var hour    = now.getHours();
    var minute  = now.getMinutes();
    var second  = now.getSeconds();
    if(hour.toString().length == 1) hour = '0'+hour;
    if(minute.toString().length == 1) minute = '0'+minute;
    if(second.toString().length == 1) second = '0'+second;
	var time = hour + ":" + minute + ":" + second;

	msg = time + " - " + msg;

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

function chatClear() {
	let chat = document.getElementById("CHAT");
	chat.innerHTML = '';
	//console.log(chat.children.length);
}

function greeting(server) {
	addMessage("You are now connected to " + server);
	addMessage("Welcome to chat! Our message length limit is 150 characters.");
}

function playerList(list) {
	clearPlayerList();
	let playersList = document.getElementById("playerstable");
	let parsedList = JSON.parse(list);

	for (let i = 0; i < parsedList.length; i++) {
		var row = playersList.insertRow(playersList.rows.length);
		var cell1 = row.insertCell(0);
		cell1.textContent = parsedList[i];
	}

	if(players != null){
		//get differences between playernames and send them as messages

		var left = players.filter((item)=>{
			return !parsedList.includes(item)
		});

		let joined = parsedList.filter((item)=>{
			return !players.includes(item)
		});

		for(var i = 0; i< left.length;i++)
			if(left[i].length>0) addMessage(left[i] + " left the server"); //the game would send an empty left message when joining a server

		for(var i = 0; i< joined.length;i++)
			addMessage(joined[i] + " joined the server");
	}
	players = parsedList; //store player list as an array for the next update
}


function clearPlayerList() {
	//players = [];
	let playersList = document.getElementById("playerstable");
	var rowCount = playersList.rows.length - 1;
	for(rowCount; rowCount >= 0; rowCount--) {
		playersList.deleteRow(rowCount);
	}
	var row = playersList.insertRow(0);
	var cell1 = row.insertCell(0);
	cell1.textContent = "PLAYERS";
}

function setOfflineInPlayerList() {
	let playersList = document.getElementById("players");
	if(playersList != null) playersList.textContent = "OFFLINE"; //added this cause it was throwing console errors
}
