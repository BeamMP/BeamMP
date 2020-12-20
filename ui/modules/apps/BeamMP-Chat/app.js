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
	$scope.init = function() {
		// Set listeners
		var chatinput = document.getElementById("chat-input");
		chatinput.addEventListener("mouseover", function(){ chatShown = true; showChat(); });
		chatinput.addEventListener("mouseout", function(){ chatShown = false; });
		var chatlist = document.getElementById("chat-list");
		chatlist.addEventListener("mouseover", function(){ chatShown = true; showChat(); });
		chatlist.addEventListener("mouseout", function(){ chatShown = false; });
		// Set chat direction
		setChatDirection(localStorage.getItem('chatHorizontal'));
		setChatDirection(localStorage.getItem('chatVertical'));
	};

	$scope.reset = function() {
		$scope.init();
	};

	$scope.select = function() {
		bngApi.engineLua('setCEFFocus(true)');
	};

	function setChatDirection(direction) {
		console.log("Moving chat to the " + direction);
		const chatbox = document.getElementById("chatbox");
		const chatwindow = document.getElementById("chat-window");
		const chatlist = document.getElementById("chat-list");
		if (direction == "left") {
			chatbox.style.flexDirection = "row";
			chatbox.style.marginLeft = "0px";
			localStorage.setItem('chatHorizontal', "left");
		}
		else if (direction == "right") {
			chatbox.style.flexDirection = "row-reverse";
			chatbox.style.marginLeft = "auto";
			localStorage.setItem('chatHorizontal', "right");
		}
		else if (direction == "top") {
			chatwindow.style.flexDirection = "column-reverse";
			chatlist.style.flexDirection = "column-reverse";
			chatlist.style.marginTop = "0px";
			chatlist.style.marginBottom = "auto";
			localStorage.setItem('chatVertical', "top");
		}
		else if (direction == "bottom") {
			chatwindow.style.flexDirection = "column";
			chatlist.style.flexDirection = "column";
			chatlist.style.marginTop = "auto";
			chatlist.style.marginBottom = "0px";
			localStorage.setItem('chatVertical', "bottom");
		}
	}

	$scope.chatSwapHorizontal = function() {
		const chatbox = document.getElementById("chatbox");
		const chatHorizontal = localStorage.getItem('chatHorizontal');
		console.log(chatHorizontal);
		if (chatHorizontal != "right") setChatDirection("right");
		else setChatDirection("left");
	}

	$scope.chatSwapVertical = function() {
		const chatwindow = document.getElementById("chat-window");
		const chatlist = document.getElementById("chat-list");
		const chatVertical = localStorage.getItem('chatVertical');
		if (chatVertical != "top") setChatDirection("top");
		else setChatDirection("bottom");
	}

	$scope.$on('chatMessage', function (event, message) {
		addMessage(message);
	});

	$scope.chatSend = function() {
		let chatinput = document.getElementById("chat-input");
		const text = chatinput.value
		if (text) {
			if (text > 150) addMessage("Your message should not be longer than 150 characters!");
			else {
				bngApi.engineLua("UI.chatSend(\""+ text.replace(/"/g, '\'') + "\")");
				chatinput.value = '';
			}
		}
	};
}]);



// -------------------------------------------- CHAT FADING -------------------------------------------- //
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

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
	var chatMessages = []
	while (chatShown) {
		// Get the chat and the messages
		// Copy the variables so it's a pointer
		var tempMessages = document.getElementById("chat-list").getElementsByTagName("li");
		for (i = 0; i < tempMessages.length; i++) {
			chatMessages[i] = tempMessages[i];
		}
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
    if(hour < 10) hour = '0'+hour;
    if(minute < 10) minute = '0'+minute;
    if(second < 10) second = '0'+second;
	var time = hour + ":" + minute + ":" + second;
	msg = time + " " + msg;

	// Create the message node and add it
	let node = document.createElement("li");
	node.style.padding = "3px 0px 3px 0px";
	node.style.backgroundColor = "rgba(0, 0, 0, 0.45)";
	fadeNode(node);
	let textNode = document.createTextNode(msg);
	let chatlist = document.getElementById("chat-list");
	node.appendChild(textNode);
	chatlist.appendChild(node);

	// Delete oldest chat message if too long
	if (chatlist.children.length > 70) chatlist.removeChild(chatlist.children[0]);

	// Scroll the chat depending of it's direction
	const chatwindow = document.getElementById("chat-window");
	if (chatwindow.style.flexDirection != "column-reverse") chatlist.scrollTop = chatlist.scrollHeight;
	else chatlist.scrollTop = 0;
}