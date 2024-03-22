// Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
// Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
// SPDX-License-Identifier: AGPL-3.0-or-later

var app = angular.module('beamng.apps');
let lastSentMessage = "";
let lastMsgId = 0;
let newChatMenu = false;

app.directive('multiplayerchat', [function () {
	return {
		templateUrl: '/ui/modules/apps/BeamMP-Chat/app.html',
		replace: true,
		restrict: 'EA',
		scope: true,
		controllerAs: 'ctrl'
	}
}]); 

app.controller("Chat", ['$scope', 'Settings', function ($scope, Settings) {

	$scope.init = function () {

		var chatMessages = retrieveChatMessages()
		newChatMenu = Settings.values.enableNewChatMenu;

		//console.log(`[CHAT] New chat menu: ${newChatMenu}`);

		// Set listeners
		var chatinput = document.getElementById("chat-input");

		// To ensure that the element exists
		if (chatinput) {
			chatinput.addEventListener("mouseover", function () { chatShown = true; showChat(); });
			chatinput.addEventListener("mouseout", function () { chatShown = false; });
			chatinput.addEventListener('keydown', onKeyDown); //used for 'up arrow' last msg functionality
			chatinput.addEventListener('keydown', onEnterKeyPress); // Handles Enter key press
		}

		var chatlist = document.getElementById("chat-list");

		// To ensure that the element exists
		if (chatlist) {
			chatlist.addEventListener("mouseover", function(){ chatShown = true; showChat(); });
			chatlist.addEventListener("mouseout", function(){ chatShown = false; });
		}

		// Set chat direction
		setChatDirection(localStorage.getItem('chatHorizontal'));
		setChatDirection(localStorage.getItem('chatVertical'));

		const chatbox = document.getElementById("chat-window");
		if (newChatMenu) {
			chatbox.style.display = "none";
		} else {
			chatbox.style.display = "flex";
		}

		if (chatMessages) {
			chatMessages.map((v, i) => {
				addMessage(v.message, v.time)
			})
		}
	};

	$scope.reset = function() {
		$scope.init();
	};

	$scope.select = function() {
		bngApi.engineLua('setCEFFocus(true)');
	};

	// Function to handle Enter key press
	function onEnterKeyPress(event) {
		const chatInput = document.getElementById("chat-input");
		if (event.key === "Enter" && chatInput === document.activeElement) {
			event.preventDefault();
			const text = chatInput.value;
			if (text.trim() !== "") {
				$scope.chatSend();
			}
			chatInput.value = '';
		}
	}

	// Set chat direction
	function setChatDirection(direction) {
	const chatbox = document.getElementById("chatbox");
	const chatwindow = document.getElementById("chat-window");
	const chatlist = document.getElementById("chat-list");

		switch (direction) {
			case "left":
				chatbox.style.flexDirection = "row";
				chatbox.style.marginLeft = "0";
				chatwindow.style.alignItems = "flex-start";
				localStorage.setItem('chatHorizontal', "left");
				break;

			case "right":
				chatbox.style.flexDirection = "row-reverse";
				chatbox.style.marginLeft = "auto";
				chatwindow.style.alignItems = "flex-start";
				localStorage.setItem('chatHorizontal', "right");
				break;

			case "middle":
				chatbox.style.flexDirection = "row";
				chatbox.style.marginLeft = "0";
				chatwindow.style.alignItems = "center";
				localStorage.setItem('chatHorizontal', "middle");
				break;

			case "top":
				chatwindow.style.flexDirection = "column-reverse";
				chatlist.style.flexDirection = "column-reverse";
				chatlist.style.marginTop = "0";
				chatlist.style.marginBottom = "auto";
				localStorage.setItem('chatVertical', "top");
				break;

			case "bottom":
				chatwindow.style.flexDirection = "column";
				chatlist.style.flexDirection = "column";
				chatlist.style.marginTop = "auto";
				chatlist.style.marginBottom = "0";
				localStorage.setItem('chatVertical', "bottom");
				break;

			default:
				// Handle default behavior or error case
				break;
		}
	}

	// Swap chat direction (left/middle/right)
	$scope.chatSwapHorizontal = function () {
		const chatHorizontal = localStorage.getItem('chatHorizontal') || "middle";

		switch (chatHorizontal) {
			case "left":
				setChatDirection("middle");
				break;

			case "middle":
				setChatDirection("right");
				break;

			default:
				setChatDirection("left");
				break;
		}
	};

	// Swap chat direction (top/bottom)
	$scope.chatSwapVertical = function () {
		const chatVertical = localStorage.getItem('chatVertical') || "";

		switch (chatVertical) {
			case "top":
				setChatDirection("bottom");
				break;

			default:
				setChatDirection("top");
				break;
		}
	};

	//Chat message function.
	$scope.$on('chatMessage', function (event, data) {
		if (data.id > lastMsgId) {
			lastMsgId = data.id;

			var now = new Date();
			var hour    = now.getHours();
			var minute  = now.getMinutes();
			var second  = now.getSeconds();
			if(hour < 10) hour = '0'+hour;
			if(minute < 10) minute = '0'+minute;
			if(second < 10) second = '0'+second;
		
			var time = hour + ":" + minute + ":" + second;
			
			storeChatMessage({message: data.message, time: time})
			addMessage(data.message);
		}
	});

	// Clear chat history
	$scope.$on('clearChatHistory', function (event, data) {
		localStorage.removeItem('chatMessages');
	})

	// Settings changed function
	$scope.$on('SettingsChanged', function (event, data) {
		Settings.values = data.values;
		const chatbox = document.getElementById("chat-window");
		if (newChatMenu) {
			chatbox.style.display = "none";
		} else {
			chatbox.style.display = "flex";
		}
	})

	// Chat Send Function
	$scope.chatSend = function () {
		let chatinput = document.getElementById("chat-input");
		const text = chatinput.value;
		if (text) {
			lastSentMessage = text;
			if (text.length > 500) addMessage("Your message is over the character limit! (500)");
			else {
				bngApi.engineLua('UI.chatSend(' + bngApi.serializeToLua(text) + ')');
				chatinput.value = '';
				chatinput.blur();
			}
		}
	};

}]);

// --CHAT FADING --//
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

var chatShown = false;
var chatShowTime = 3500; // 5000ms
var chatFadeSteps = 1/30; // 60 steps
var chatFadeSpeed = 1000 / (1 / chatFadeSteps); // 1000ms

// Fade a node.
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

// Show the chat.
async function showChat() {
	if (newChatMenu) return;

	const chatList = document.getElementById("chat-list");
	const chatMessages = Array.from(chatList.getElementsByTagName("li"));

	while (chatShown) {
		chatMessages.forEach(message => message.classList.add("show-chat"));
		await sleep(100);
	}

	for (let steps = chatShowTime / 35; steps < chatShowTime; steps += chatShowTime / 35) {
		if (chatShown) return;
		await sleep(chatShowTime / 35);
	}

	let chatOpacity = 1.0;
	while (chatOpacity > 0.0) {
		if (chatShown) break;
		chatMessages.forEach(message => message.classList.remove("show-chat"));
		chatOpacity -= chatFadeSteps;
		await sleep(chatFadeSpeed);
	}
}

//Apply codes to string.
function applyCode(string, codes) {
	var elem = document.createElement("span");
	elem.style.fontSize = "initial";
	string = string.replace(/\x00*/g, "");
	for (var i = 0, len = codes.length; i < len; i++) {
		elem.style.cssText += serverStyleMap[codes[i]] + ";";
	}
	elem.innerHTML = string;
	return elem;
}

// Map of codes to CSS styles.
function formatRichString(string) {
	let tempAreaElement = document.createElement('div');
	tempAreaElement.setAttribute("id", "TEMPAREA");

	var codes = string.match(/\^.{1}/g) || [],
		indexes = [],
		apply = [],
		tmpStr,
		deltaIndex,
		noCode,
		final = document.createDocumentFragment(),
		i;

	for (i = 0, len = codes.length; i < len; i++) {
		indexes.push(string.indexOf(codes[i]));
		string = string.replace(codes[i], "\x00\x00");
	}

	if (indexes[0] !== 0) {
		final.appendChild(applyCode(string.substring(0, indexes[0]), []));
	}

	for (i = 0; i < len; i++) {
		indexDelta = indexes[i + 1] - indexes[i];
		if (indexDelta === 2) {
			while (indexDelta === 2) {
				apply.push(codes[i]);
				i++;
				indexDelta = indexes[i + 1] - indexes[i];
			}
			apply.push(codes[i]);
		} else {
			apply.push(codes[i]);
		}
		if (apply.lastIndexOf("^r") > -1) {
			apply = apply.slice(apply.lastIndexOf("^r") + 1);
		}
		tmpStr = string.substring(indexes[i], indexes[i + 1]);
		final.appendChild(applyCode(tmpStr, apply));
  }
  tempAreaElement.innerHTML = final;
  var innerHTML = [...final.childNodes].map((n) => n.outerHTML).join("\n");

  tempAreaElement = undefined;

  return innerHTML;
}

//Store chat messages.
function storeChatMessage(message) {

  // Check if localStorage is available.
	if (typeof (Storage) !== "undefined") {

    // Get the existing chat messages from localStorage (if any).
    let chatMessages = JSON.parse(localStorage.getItem("chatMessages")) || [];

    // Add the new message to the chatMessages array.
    chatMessages.push(message);

		if (chatMessages.length > 100) {
			chatMessages.shift()
		}

    // Store the updated chatMessages array back in localStorage.
    localStorage.setItem("chatMessages", JSON.stringify(chatMessages));

    // You can optionally return the updated chatMessages array or perform other actions.
    return chatMessages;
  } else {
    console.error("localStorage is not available in this browser.");
    return null;
  }
}

//Retrieve chat messages.
function retrieveChatMessages() {

	// Check if localStorage is available.
	if (typeof localStorage !== 'undefined') {

		// Get the chat messages from localStorage.
		const storedMessages = localStorage.getItem('chatMessages');

		// Parse the stored data if it exists.
		if (storedMessages) {
			return JSON.parse(storedMessages);
		}
	}
}

//Max number of messages.
const MAX_MESSAGES = 100;

//Add a message to the chat window.
function addMessage(msg, time = null) {
	const currentTime = time || new Date();
	const formattedTime = new Intl.DateTimeFormat(undefined, {
		hour: "numeric",
		minute: "numeric",
		second: "numeric",
		hour12: false,
	}).format(currentTime);

	const chatList = document.getElementById("chat-list");
	const chatMessageNode = createMessageNode(msg, formattedTime);
	appendMessageToChat(chatList, chatMessageNode);

	// Ensure the chat window is scrolled to the bottom after adding a message
	scrollChat(chatList);
}

//Create a chat message node.
function createMessageNode(msg, formattedTime) {
	const chatMessageNode = document.createElement("li");
	chatMessageNode.className = "chat-message";
	fadeNode(chatMessageNode);

	const messageTimestampNode = document.createElement("span");
	messageTimestampNode.className = "chat-message-timestamp";
	const timestampTextNode = document.createTextNode(formattedTime);
	messageTimestampNode.appendChild(timestampTextNode);
	chatMessageNode.appendChild(messageTimestampNode);

	const msgText = "" + msg;
	if (msgText.startsWith("Server: ")) {
		const formattedInnerHtml = formatRichString(msgText);
		chatMessageNode.innerHTML += formattedInnerHtml;
	} else {
		const textNode = document.createTextNode(msgText);
		chatMessageNode.appendChild(textNode);
	}

	return chatMessageNode;
}

//Append a message to the chat window.
function appendMessageToChat(chatList, chatMessageNode) {
	chatList.appendChild(chatMessageNode);

	// Remove oldest message if the number of messages exceeds the maximum limit
	if (chatList.children.length > MAX_MESSAGES) {
		chatList.removeChild(chatList.children[0]);
	}
}

//Scroll chat window to bottom.
function scrollChat(chatList) {
	const chatWindow = document.getElementById("chat-window");
	if (chatWindow.style.flexDirection !== "column-reverse") {
		chatList.scrollTop = chatList.scrollHeight;
	} else {
		chatList.scrollTop = 0;
	}
}
    
// --KEYBOARD SHORTCUTS --//
function onKeyDown(e) {
	const chatInput = document.getElementById("chat-input");
	if (e.key === "ArrowUp") {
		chatInput.value = lastSentMessage;
		chatInput.setSelectionRange(lastSentMessage.length, lastSentMessage.length);
	}
}