var app = angular.module('beamng.apps');
app.directive('multiplayerchat', ['UiUnits', function (UiUnits) {
	return {
		templateUrl: 'modules/apps/BeamMP-Chat/app.html',
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
		document.getElementById("CHATMESSAGE").addEventListener("mouseover", function(){ chatShown = true; showChat(); });
		document.getElementById("CHATMESSAGE").addEventListener("mouseout", function(){ chatShown = false; console.log("leave"); });
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

	$scope.$on('useCustomChatWindow', function (setting) {
		if (setting == true) {
			var chatWindow = document.getElementById("MainChatBoxWindow");
			chatWindow.style.display = "none";
		}
	})

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
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}



// -------------------------------------------- CHAT FADING -------------------------------------------- //
var chatShown = false;
var chatShowTime = 3500; // 5000ms
var chatFadeSteps = 1/30; // 60 steps
var chatFadeSpeed = 1000 / (1/chatFadeSteps); // 1000ms
async function fadeNode(node) {
	// Set the node opacity to 1.0
	node.style.opacity = 1.0;
	// Once the node is shown, we wait before fading it
	// We take care of checking that the chat is not shown while we are waiting before fading
	for (var steps = chatShowTime/35; steps < chatShowTime; steps += chatShowTime/35) {
		if (chatShown) return;
		await sleep(chatShowTime/35);
	}
	// We fade the node
	var nodeOpacity = 1.0;
	while (nodeOpacity > 0.0) {
		// If the user move the mouse hover the chat before
		// this loop as ended then we break the loop
		if (chatShown) return;
		nodeOpacity = nodeOpacity - chatFadeSteps;
		node.style.opacity = nodeOpacity;
		await sleep(chatFadeSpeed);
	}
}

async function showChat() {
	// While the mouse is over the chat, we wait
	while (chatShown) {
		// Get the chat and the messages
		var chatMessages = document.getElementById("CHAT").getElementsByTagName("li");
		// Set all messages opacity to 1.0
		for (var i = 0; i < chatMessages.length; ++i) chatMessages[i].style.opacity = 1.0;
		await sleep(100);
	}
	// Once the mouse is not over the chat anymore, we wait before fading
	// We take care of checking that the chat is not shown while we are waiting before fading
	for (var steps = chatShowTime/35; steps < chatShowTime; steps += chatShowTime/35) {
		if (chatShown) return;
		await sleep(chatShowTime/35);
	}
	var chatOpacity = 1.0;
	while (chatOpacity > 0.0) {
		// If the user move the mouse hover the chat before
		// this loop as ended then we break the loop
		if (chatShown) break;
		chatOpacity = chatOpacity - chatFadeSteps;
		for (var i = 0; i < chatMessages.length; ++i) chatMessages[i].style.opacity = chatOpacity;
		await sleep(chatFadeSpeed);
	}
}
// -------------------------------------------- CHAT FADING -------------------------------------------- //



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
	//setTimeout(function(){ alert("Hello"); }, 3000);
	let node = document.createElement("li");
	node.style.paddingBottom = "4px";
	node.style.backgroundColor = "rgba(0, 0, 0, 0.45)";
	fadeNode(node);
	
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
