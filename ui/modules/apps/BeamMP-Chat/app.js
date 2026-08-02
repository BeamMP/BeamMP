// Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
// Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
// SPDX-License-Identifier: AGPL-3.0-or-later

var app = angular.module('beamng.apps');

let lastSentMessage = "";

let lastMsgId = 0;
let newChatMenu = false;
import('/ui/lib/ext/purify.min.js')
app.directive('beammpChat', [function () {
	return {
		templateUrl: '/ui/modules/apps/BeamMP-Chat/app.html',
		replace: true,
		restrict: 'EA',
		scope: true,
		controllerAs: 'ctrl'
	}
}]); 


app.controller("BeamMPChatController", ['$scope', 'Settings', function ($scope, Settings) {
	const applyChatStyle = function(useNewDesign) {
		const stylesheet = document.getElementById('chat-style');
		const sendButton = document.getElementById('send-button');
		if (!stylesheet) return;
		let newStylePath;
		if (useNewDesign) {
			newStylePath = '/ui/modules/apps/BeamMP-Chat/redesign.css';
			if (sendButton) sendButton.innerHTML = '💬';
		} else {
			newStylePath = '/ui/modules/apps/BeamMP-Chat/app.css';
			if (sendButton) sendButton.innerHTML = 'Send';
		}		
		if (stylesheet.getAttribute('href') !== newStylePath) {
			stylesheet.setAttribute('href', newStylePath);
		}
		scrollToLastMessage();
	};

	$scope.init = function() {
		applyChatStyle(Settings.values.useUiAppRedesign);

		var chatMessages = retrieveChatMessages()
		newChatMenu = Settings.values.enableNewChatMenu;
		//console.log(`[CHAT] New chat menu: ${newChatMenu}`);
		// Set listeners
		var chatinput = document.getElementById("chat-input");
		// To ensure that the element exists
		if (chatinput) {
			chatinput.addEventListener("mouseover", function(){ chatShown = true; showChat(); });
			chatinput.addEventListener("mouseout", function(){ chatShown = false; });
			chatinput.addEventListener('keydown', onKeyDown); //used for 'up arrow' last msg functionality
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

		if (chatlist) {		// scroll to the bottom of the chat list on ui reload
			setTimeout(() => {
				scrollToLastMessage();
			}, 0)
		}
	};

	$scope.reset = function() {
		$scope.init();
	};

	$scope.select = function() {
		bngApi.engineLua('setCEFFocus(true)');
	};

	function setChatDirection(direction) {
		const chatbox = document.getElementById("chatbox");
		const chatwindow = document.getElementById("chat-window");
		const chatlist = document.getElementById("chat-list");
		if (direction == "left") {
			chatbox.style.flexDirection = "row";
			chatbox.style.marginLeft = "0px";
			chatwindow.style.alignItems = "flex-start";
			localStorage.setItem('chatHorizontal', "left");
		}
		else if (direction == "right") {
			chatbox.style.flexDirection = "row-reverse";
			chatbox.style.marginLeft = "auto";
			chatwindow.style.alignItems = "flex-start";
			localStorage.setItem('chatHorizontal', "right");
		}
		else if (direction == "middle") {
			chatbox.style.flexDirection = "row";
			chatbox.style.marginLeft = "0px";
			chatwindow.style.alignItems = "center";
			localStorage.setItem('chatHorizontal', "middle");
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
		const chatHorizontal = localStorage.getItem('chatHorizontal') || "middle";
		if (chatHorizontal == "left") setChatDirection("middle");
		else if (chatHorizontal == "middle") setChatDirection("right");
		else setChatDirection("left");
	}

	$scope.chatSwapVertical = function() {
		const chatVertical = localStorage.getItem('chatVertical');
		if (chatVertical != "top") setChatDirection("top");
		else setChatDirection("bottom");
	
		scrollToLastMessage();
	}

	$scope.$on('onBeamMPChatMessage', function (event, data) {
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

	$scope.$on('onBeamMPClearChatHistory', function (event, data) {
		localStorage.removeItem('chatMessages');
	})

	$scope.$on('SettingsChanged', function (event, data) {
		Settings.values = data.values;
		newChatMenu = Settings.values.enableNewChatMenu;

		applyChatStyle(Settings.values.useUiAppRedesign);

		const chatbox = document.getElementById("chat-window");
		if (newChatMenu) {
			chatbox.style.display = "none";
		} else {
			chatbox.style.display = "flex";
		}
	})

	$scope.chatSend = function() {
		let chatinput = document.getElementById("chat-input");
		const text = chatinput.value
		if (text) {
			lastSentMessage = text;
			if (text.length > 500) addMessage("Your message is over the character limit! (500)");
			else {
				bngApi.engineLua('UI.chatSend(' + bngApi.serializeToLua(text) + ')');
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
	if (newChatMenu) return;

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

// -------------------------------------------- MESSAGE FORMATTING -------------------------------------------- //


function formatChatMessage(string) {
    const blockedTags = new Set(['script', 'iframe', 'form', 'input', 'button', 'a']);
    
    const dangerousAttributePattern = /^(?:on.*|(?:form).*|action)$/i;

    function isSafeHtml(html) {
        const div = document.createElement('div');
        div.innerHTML = html;
        
        const elements = div.getElementsByTagName('*');
        for (let element of elements) {
            if (blockedTags.has(element.tagName.toLowerCase())) {
                return false;
            }
            
            for (let attr of element.attributes) {
                if (dangerousAttributePattern.test(attr.name) || 
                    /javascript:|data:/i.test(attr.value)) {
                    return false;
                }
            }
        }
        return true;
    }

    if (string.startsWith("Server: ")) {
        const messageContent = string.substring(8);
        if (messageContent.includes('<') && messageContent.includes('>')) {
            if (isSafeHtml(messageContent)) {
                return "Server: " + messageContent;
            }
        }
    }

    let result = '';
    let currentText = '';
    let classes = new Set();

    string = DOMPurify.sanitize(string);
    const tokens = string.split(/(\^.)/g);

    const flush = () => {
        if (!currentText) return;
        const classList = Array.from(classes);
        result += classList.length
            ? `<span class="${classList.join(' ')}">${currentText}</span>`
            : currentText;
        currentText = '';
    };

    for (let i = 0; i < tokens.length; i++) {
		const token = tokens[i];
		const nextToken = tokens[i+1]?.trim() || '';
		if (/^\^.$/.test(token)) {
			flush();
			if (token === '^r') {
				classes.clear();
			} else if (token === '^p') {
				currentText += '<br>';
			} else if (token === '^*') {
				const cls = globalThis.beammpTextStyleMap?.[token];
				if(cls) classes.add(cls);
				if (iconsOrig[nextToken]) {
					currentText = iconsOrig[nextToken].glyph
				};
			} else {
				const cls = globalThis.beammpTextStyleMap?.[token];
				if (cls?.startsWith('color-')) {
					[...classes].forEach(c => c.startsWith('color-') && classes.delete(c));
					classes.add(cls);
				} else if (cls) {
					classes.add(cls);
				}
			}
		} else if (tokens[i-1]!='^*') {
			currentText += token;
		}
	}

    flush();
    return result;
}

// -------------------------------------------- MESSAGE FORMATTING -------------------------------------------- //

function storeChatMessage(message) {
  // Check if localStorage is available
  if (typeof(Storage) !== "undefined") {
    // Get the existing chat messages from localStorage (if any)
    let chatMessages = JSON.parse(localStorage.getItem("chatMessages")) || [];

    // Add the new message to the chatMessages array
    chatMessages.push(message);

		if (chatMessages.length > 70) {
			chatMessages.shift()
		}

    // Store the updated chatMessages array back in localStorage
    localStorage.setItem("chatMessages", JSON.stringify(chatMessages));

    // You can optionally return the updated chatMessages array or perform other actions
    return chatMessages;
  } else {
    console.error("localStorage is not available in this browser.");
    return null;
  }
}

function retrieveChatMessages() {
	// Check if localStorage is available
	if (typeof localStorage !== 'undefined') {
		// Get the chat messages from localStorage
		const storedMessages = localStorage.getItem('chatMessages');

		// Parse the stored data if it exists
		if (storedMessages) {
			return JSON.parse(storedMessages);
		}
	}
}

function addMessage(msg, time = null) {
	//getting current time and adding it to the message before displaying
	if (time == null) {
		var now = new Date();
		var hour    = now.getHours();
		var minute  = now.getMinutes();
		var second  = now.getSeconds();
		if(hour < 10) hour = '0'+hour;
		if(minute < 10) minute = '0'+minute;
		if(second < 10) second = '0'+second;

		time = hour + ":" + minute + ":" + second;
	}

  const msgText = "" + msg
	msg = time + " " + msg;

	// Create the message node
	const chatMessageNode = document.createElement("li");
	chatMessageNode.className = "chat-message";
	fadeNode(chatMessageNode);

	// create node for the timestamp
	const messageTimestampNode = document.createElement("span");
	messageTimestampNode.className = "chat-message-timestamp";

	const timestampTextNode = document.createTextNode(time);
	messageTimestampNode.appendChild(timestampTextNode);

	chatMessageNode.appendChild(messageTimestampNode)

	// create text for the message itself, add it to chat message list
	const chatList = document.getElementById("chat-list");

	// check if this message is a server message before
	// doing rich formatting
	if (msgText.startsWith("Server: ")) {
		const formattedInnerHtml = formatChatMessage(msgText);
		chatMessageNode.innerHTML = chatMessageNode.innerHTML + formattedInnerHtml;
	} else {
		const textNode = document.createTextNode(msgText);
		chatMessageNode.appendChild(textNode);
	}

	chatList.appendChild(chatMessageNode);

	// Delete oldest chat message if more than 70 messages exist
	if (chatList.children.length > 70) {
		chatList.removeChild(chatList.children[0]);
	}
	
	scrollToLastMessage();

}

function scrollToLastMessage() {
	const chatwindow = document.getElementById("chat-window");
	const chatlist = document.getElementById("chat-list");
	const isReversed = getComputedStyle(chatwindow).flexDirection === "column-reverse";
	if (isReversed) {
		chatlist.scrollTop = -chatlist.scrollHeight;
	} else {
		chatlist.scrollTop = chatlist.scrollHeight;
	}
}

function onKeyDown(e) {
	if (e.key == "ArrowUp") {
		console.log(e);
		document.getElementById("chat-input").value = lastSentMessage;
		e.target.setSelectionRange(lastSentMessage.length, lastSentMessage.length);
	} else if (e.key === "Enter") {
		e.preventDefault();
		e.stopPropagation();
		document.getElementById("send-button").click();
	}
}
