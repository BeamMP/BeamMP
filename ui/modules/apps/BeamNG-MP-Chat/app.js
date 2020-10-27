var app = angular.module('beamng.apps');
app.directive('multiplayerchat', ['UiUnits', function (UiUnits) {
	return {
		templateUrl: 'modules/apps/BeamNG-MP-Chat/app.html',
		replace: true,
		restrict: 'EA',
		scope: true
	}
}]);
app.controller("Chat", ['$scope', 'bngApi', function ($scope, bngApi) {
	$scope.warnVis = false;
	$scope.timer = null;
	let count = 0;
	let countUpdateInterval = null;
	let spamLocked = false;

	$scope.init = function() {
		//bngApi.engineLua('UI.ready("CHAT")');
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
	addMessage("You are now connected to " + stripCustomFormatting(sanitizeString(server)));
	addMessage("Welcome to our chat!");
}
