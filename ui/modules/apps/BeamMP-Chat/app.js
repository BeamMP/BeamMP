// Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
// Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
// SPDX-License-Identifier: AGPL-3.0-or-later

;(function() {

var app = angular.module('beamng.apps');

let lastSentMessage = "";

let lastMsgId = 0;
let newChatMenu = false;
let chatFocused = false;
let chatScrollAnimation = null;
let chatScrollTarget = null;
let localChatUsername = "";
let mentionPlayerNames = [];
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


app.controller("BeamMPChatController", ['$scope', 'Settings', '$filter', function ($scope, Settings, $filter) {
	let activeChatList = null;
	let activeReplyMessageNode = null;
	$scope.chatInputText = "";
	$scope.players = [];
	$scope.replyLabel = $filter("translate")("ui.apps.beammp.chat.reply");
	$scope.replyTarget = null;
	$scope.chatInputMaxLength = 500;
	$scope.chatInputSegments = [{ text: "", isMention: false }];
	$scope.unreadMessages = 0;
	$scope.unreadMentions = 0;
	$scope.mentionQuery = null;
	$scope.selectedMentionIndex = 0;
	$scope.mentionSuggestions = [];
	$scope.mentionSuggestionListStyle = { height: "0rem" };

	const comparePlayerIds = function(first, second) {
		const firstId = Number(first.id);
		const secondId = Number(second.id);
		if (Number.isFinite(firstId) && Number.isFinite(secondId)) return firstId - secondId;
		if (Number.isFinite(firstId)) return -1;
		if (Number.isFinite(secondId)) return 1;
		return String(first.id).localeCompare(String(second.id));
	};

	const handleChatReplyClick = function(event) {
		const button = event.target.closest?.(".chat-message-reply");
		if (!button) return;
		const message = button.closest(".chat-message");
		if (!message?.dataset.replyAuthor) return;

		$scope.$applyAsync(function() {
			activeReplyMessageNode?.classList.remove("chat-message-reply-target");
			activeReplyMessageNode = message;
			activeReplyMessageNode.classList.add("chat-message-reply-target");
			$scope.replyTarget = createReplyTarget(
				message.dataset.replyAuthor,
				message.dataset.replyText || "",
				message.dataset.replyRoleColor || "",
				message.dataset.replyRoleTag || ""
			);
			$scope.chatInputMaxLength = 500 - $scope.replyTarget.prefix.length;
			const input = document.getElementById("chat-input");
			if (input) {
				input.focus();
				bngApi.engineLua("setCEFFocus(true)");
			}
			$scope.updateMentionSuggestions();
		});
	};

	$scope.cancelReply = function() {
		activeReplyMessageNode?.classList.remove("chat-message-reply-target");
		activeReplyMessageNode = null;
		$scope.replyTarget = null;
		$scope.chatInputMaxLength = 500;
	};

	const syncInputHighlightScroll = function() {
		const input = document.getElementById("chat-input");
		const highlight = document.querySelector("#chatbox .chat-input-highlight");
		if (input && highlight) highlight.scrollLeft = input.scrollLeft;
	};

	const syncInputHighlightSelection = function() {
		const input = document.getElementById("chat-input");
		const inputWrap = input?.parentElement;
		if (input && inputWrap) {
			inputWrap.classList.toggle("has-selection", input.selectionStart !== input.selectionEnd);
		}
	};

	const handleInputHighlightScroll = function() {
		syncInputHighlightScroll();
		syncInputHighlightSelection();
	};

	const scheduleInputHighlightScroll = function() {
		requestAnimationFrame(handleInputHighlightScroll);
	};

	$scope.updateMentionSuggestions = function() {
		const input = document.getElementById("chat-input");
		if (!input) return;
		$scope.chatInputSegments = buildMentionSegments(
			$scope.chatInputText || "",
			$scope.players.map(player => player.name)
		);
		scheduleInputHighlightScroll();
		const beforeCursor = input.value.slice(0, input.selectionStart ?? input.value.length);
		const match = beforeCursor.match(/(?:^|\s)@([^\s@]*)$/);
		const wasMentionActive = $scope.mentionQuery !== null;
		const nextMentionQuery = match ? match[1] : null;
		if (nextMentionQuery !== $scope.mentionQuery) {
			$scope.selectedMentionIndex = 0;
		}
		$scope.mentionQuery = nextMentionQuery;
		if ($scope.mentionQuery !== null && !wasMentionActive) {
			bngApi.engineLua("UI.updatePlayersList()");
		}
		const query = ($scope.mentionQuery || "").toLocaleLowerCase();
		const isIdQuery = /^\d+$/.test(query);
		$scope.mentionSuggestions = $scope.mentionQuery === null
			? []
			: $scope.players
				.filter(player => {
					const name = typeof player.name === "string" ? player.name.toLocaleLowerCase() : "";
					const id = String(player.id).toLocaleLowerCase();
					return isIdQuery ? id.startsWith(query) : name.includes(query);
				})
				.sort((first, second) => {
					if (!query || isIdQuery) return comparePlayerIds(first, second);
					const rank = player => {
						const name = player.name.toLocaleLowerCase();
						return name.startsWith(query) ? 0 : 1;
					};
					return rank(first) - rank(second) || comparePlayerIds(first, second);
				});
		$scope.selectedMentionIndex = $scope.mentionSuggestions.length
			? Math.min($scope.selectedMentionIndex, $scope.mentionSuggestions.length - 1)
			: 0;
		$scope.mentionSuggestionListStyle = {
			height: Math.min($scope.mentionSuggestions.length * 2.15, 6.45) + "rem",
		};
	};

	const scrollSelectedMentionIntoView = function() {
		const list = document.querySelector("#chatbox .mention-suggestion-list");
		const selected = list?.querySelector(".mention-suggestion.selected");
		if (!list || !selected) return;
		const listRect = list.getBoundingClientRect();
		const selectedRect = selected.getBoundingClientRect();
		if (selectedRect.bottom > listRect.bottom) {
			list.scrollTop += selectedRect.bottom - listRect.bottom;
		} else if (selectedRect.top < listRect.top) {
			list.scrollTop -= listRect.top - selectedRect.top;
		}
	};

	$scope.selectMention = function(player) {
		if ($scope.mentionQuery === null) return;
		const input = document.getElementById("chat-input");
		if (!input || !player || typeof player.name !== "string") return;
		const caret = input.selectionStart ?? input.value.length;
		const beforeCursor = input.value.slice(0, caret);
		const mentionStart = beforeCursor.lastIndexOf("@");
		if (mentionStart < 0) return;
		const insertion = "@" + player.name + " ";
		$scope.chatInputText = input.value.slice(0, mentionStart) + insertion + input.value.slice(caret);
		$scope.chatInputSegments = buildMentionSegments(
			$scope.chatInputText,
			$scope.players.map(currentPlayer => currentPlayer.name)
		);
		$scope.mentionQuery = null;
		$scope.mentionSuggestions = [];
		setTimeout(function() {
			input.focus();
			const nextCaret = mentionStart + insertion.length;
			input.setSelectionRange(nextCaret, nextCaret);
			scheduleInputHighlightScroll();
		}, 0);
	};

	$scope.handleChatInputKeydown = function(event) {
		if ($scope.mentionQuery !== null && $scope.mentionSuggestions.length) {
			if (event.key === "ArrowDown" || event.key === "ArrowUp") {
				event.preventDefault();
				const direction = event.key === "ArrowDown" ? 1 : -1;
				$scope.selectedMentionIndex = ($scope.selectedMentionIndex + direction + $scope.mentionSuggestions.length) % $scope.mentionSuggestions.length;
				requestAnimationFrame(scrollSelectedMentionIntoView);
				return;
			}
			if (event.key === "Escape") {
				event.preventDefault();
				$scope.mentionQuery = null;
				$scope.mentionSuggestions = [];
				return;
			}
			if (event.key === "Enter" || event.key === "Tab") {
				event.preventDefault();
				$scope.selectMention($scope.mentionSuggestions[$scope.selectedMentionIndex]);
				return;
			}
		}

		if (event.key === "Escape" && $scope.replyTarget) {
			event.preventDefault();
			$scope.cancelReply();
			return;
		}

		if (event.key === "ArrowUp") {
			document.getElementById("chat-input").value = lastSentMessage;
			$scope.chatInputText = lastSentMessage;
			$scope.chatInputSegments = buildMentionSegments(lastSentMessage, mentionPlayerNames);
			event.target.setSelectionRange(lastSentMessage.length, lastSentMessage.length);
			scheduleInputHighlightScroll();
		} else if (event.key === "Enter") {
			event.preventDefault();
			event.stopPropagation();
			$scope.chatSend();
		}
	};

	const handleChatAtSignKeydown = function(event) {
		const input = document.getElementById("chat-input");
		if (!input || document.activeElement !== input || newChatMenu) return;

		const isAtSign = event.key === "@" || (
			event.key === "à"
			&& (event.ctrlKey || event.altKey || event.getModifierState("AltGraph"))
		);
		const isAltGrZero = (event.ctrlKey || event.altKey || event.getModifierState("AltGraph"))
			&& !event.metaKey
			&& (event.code === "Digit0" || event.code === "Numpad0");
		const isCtrlZero = event.ctrlKey && !event.metaKey && (
			event.key === "0" || event.code === "Digit0" || event.code === "Numpad0"
		);
		if (!isAtSign && !isAltGrZero && !isCtrlZero) return;

		event.preventDefault();
		event.stopImmediatePropagation();
		const start = input.selectionStart ?? input.value.length;
		const end = input.selectionEnd ?? start;
		input.setRangeText("@", start, end, "end");
		input.dispatchEvent(new Event("input", { bubbles: true }));
	};

	const handleChatBlur = function() {
		chatFocused = false;
		scrollToLastMessage();
		$scope.$applyAsync(function() {
			clearUnreadMessages();
		});
	};

	const handleChatOutsidePointerDown = function(event) {
		const chatApp = document.getElementById("BeamMPChat");
		if (chatApp && !chatApp.contains(event.target)) handleChatBlur();
	};

	const clearUnreadMessages = function() {
		$scope.unreadMessages = 0;
		$scope.unreadMentions = 0;
	};

	const updateUnreadState = function() {
		if (isFollowingLatestMessage() && $scope.unreadMessages > 0) {
			$scope.$applyAsync(function() {
				clearUnreadMessages();
			});
		}
	};

	$scope.jumpToLatest = function() {
		scrollToLastMessage();
		clearUnreadMessages();
	};

	const applyChatStyle = function(useNewDesign) {
		const stylesheet = document.getElementById('chat-style');
		const sendButton = document.getElementById('send-button');
		if (!stylesheet) return;
		let newStylePath;
		if (useNewDesign) {
			newStylePath = '/ui/modules/apps/BeamMP-Chat/redesign.css';
			if (sendButton) sendButton.innerHTML = 'Send';
		} else {
			newStylePath = '/ui/modules/apps/BeamMP-Chat/app.css';
			if (sendButton) sendButton.innerHTML = 'Send';
		}		
		if (stylesheet.getAttribute('href') !== newStylePath) {
			stylesheet.setAttribute('href', newStylePath);
		}
		scrollToLastMessage();
		clearUnreadMessages();
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
			chatinput.removeEventListener("scroll", handleInputHighlightScroll);
			chatinput.removeEventListener("select", handleInputHighlightScroll);
			chatinput.removeEventListener("keyup", handleInputHighlightScroll);
			chatinput.removeEventListener("pointerup", handleInputHighlightScroll);
			chatinput.addEventListener("mouseover", function(){ chatShown = true; showChat(); });
			chatinput.addEventListener("mouseout", function(){ chatShown = false; });
			chatinput.addEventListener("focus", function() { chatFocused = true; });
			chatinput.addEventListener("blur", handleChatBlur);
			chatinput.addEventListener("scroll", handleInputHighlightScroll);
			chatinput.addEventListener("select", handleInputHighlightScroll);
			chatinput.addEventListener("keyup", handleInputHighlightScroll);
			chatinput.addEventListener("pointerup", handleInputHighlightScroll);
		}
		window.removeEventListener("keydown", handleChatAtSignKeydown, true);
		window.addEventListener("keydown", handleChatAtSignKeydown, true);

		var chatlist = document.getElementById("chat-list");
		// To ensure that the element exists
		if (chatlist) {
			if (activeChatList) activeChatList.removeEventListener("scroll", updateUnreadState);
			if (activeChatList) activeChatList.removeEventListener("click", handleChatReplyClick);
			activeChatList = chatlist;
			activeChatList.addEventListener("scroll", updateUnreadState);
			activeChatList.addEventListener("click", handleChatReplyClick);
			chatlist.addEventListener("mouseover", function(){ chatShown = true; showChat(); });
			chatlist.addEventListener("mouseout", function(){ chatShown = false; });
		}
		window.addEventListener("wheel", handleChatListWheel, { capture: true, passive: false });
		document.addEventListener("pointerdown", handleChatOutsidePointerDown, true);
		window.addEventListener("blur", handleChatBlur);
		bngApi.engineLua("UI.updatePlayersList()");
		bngApi.engineLua("MPConfig.getNickname()", function(name) {
			if (typeof name === "string" && name.trim()) {
				localChatUsername = name.trim();
				updateChatMentionHighlights();
				$scope.updateMentionSuggestions();
			}
		});
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
				addMessage(v.message, v.time, v, $scope.replyLabel)
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

	$scope.$on("$destroy", function() {
		window.removeEventListener("wheel", handleChatListWheel, true);
		document.removeEventListener("pointerdown", handleChatOutsidePointerDown, true);
		window.removeEventListener("blur", handleChatBlur);
		window.removeEventListener("keydown", handleChatAtSignKeydown, true);
		if (activeChatList) activeChatList.removeEventListener("scroll", updateUnreadState);
		if (activeChatList) activeChatList.removeEventListener("click", handleChatReplyClick);
		if (chatScrollAnimation !== null) {
			cancelAnimationFrame(chatScrollAnimation);
			chatScrollAnimation = null;
		}
		chatScrollTarget = null;
	});

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
			chatwindow.classList.add("chat-window-top");
			chatlist.style.flexDirection = "column-reverse";
			chatlist.style.justifyContent = "flex-start";
			chatlist.classList.add("chat-list-top");
			chatlist.style.marginTop = "0px";
			chatlist.style.marginBottom = "0px";
			localStorage.setItem('chatVertical', "top");
		}
		else if (direction == "bottom") {
			chatwindow.style.flexDirection = "column";
			chatwindow.classList.remove("chat-window-top");
			chatlist.style.flexDirection = "column";
			chatlist.style.justifyContent = "flex-start";
			chatlist.classList.remove("chat-list-top");
			chatlist.style.marginTop = "0px";
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
		clearUnreadMessages();
	}

	$scope.$on('onBeamMPChatMessage', function (event, data) {
		if (data.id > lastMsgId) {
			lastMsgId = data.id;
			const wasFollowingLatestMessage = isFollowingLatestMessage();
			const shouldFollowLatestMessage = !chatFocused || wasFollowingLatestMessage;

			var now = new Date();
			var hour    = now.getHours();
			var minute  = now.getMinutes();
			var second  = now.getSeconds();
			if(hour < 10) hour = '0'+hour;
			if(minute < 10) minute = '0'+minute;
			if(second < 10) second = '0'+second;
		
			var time = hour + ":" + minute + ":" + second;
			
			storeChatMessage({
				message: data.message,
				time: time,
				username: data.username,
				roleTag: data.roleTag,
				body: data.body,
				color: data.color,
			})
			addMessage(data.message, time, data, $scope.replyLabel);
			if (shouldFollowLatestMessage) {
				scrollToLastMessage();
				clearUnreadMessages();
			} else {
				$scope.unreadMessages += 1;
				if (isChatMessageMention(
					typeof data.body === "string" ? data.body : data.message,
					localChatUsername
				)) {
					$scope.unreadMentions += 1;
				}
			}
		}
	});

	$scope.$on('onBeamMPPlayerList', function(event, data) {
		try {
			const parsed = typeof data === "string" ? JSON.parse(data) : data;
			$scope.players = Array.isArray(parsed)
				? parsed.filter(player => player && player.id !== undefined && typeof player.name === "string")
				: [];
			mentionPlayerNames = $scope.players.map(player => player.name);
			$scope.chatInputSegments = buildMentionSegments(
				$scope.chatInputText || "",
				mentionPlayerNames
			);
			$scope.updateMentionSuggestions();
		} catch (error) {
			console.error("Failed to parse BeamMP player list for chat mentions", error);
			$scope.players = [];
			mentionPlayerNames = [];
			$scope.chatInputSegments = buildMentionSegments($scope.chatInputText || "", []);
			$scope.mentionSuggestions = [];
			$scope.updateMentionSuggestions();
		}
	});

	$scope.$on('onBeamMPSetNickname', function(event, data) {
		if (typeof data === "string" && data.trim()) {
			localChatUsername = data.trim();
			updateChatMentionHighlights();
			$scope.updateMentionSuggestions();
		}
	});

	$scope.$on('onBeamMPClearChatHistory', function (event, data) {
		localStorage.removeItem('chatMessages');
		clearUnreadMessages();
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
		const text = chatinput.value;
		if (text) {
			lastSentMessage = text;
			const message = ($scope.replyTarget?.prefix || "") + text;
			if (message.length > 500) addMessage("Your message is over the character limit! (500)");
			else {
				bngApi.engineLua('UI.chatSend(' + bngApi.serializeToLua(message) + ')');
				chatinput.value = '';
				$scope.chatInputText = '';
				$scope.cancelReply();
				$scope.chatInputSegments = buildMentionSegments("", mentionPlayerNames);
				chatinput.scrollLeft = 0;
				scheduleInputHighlightScroll();
				$scope.mentionQuery = null;
				$scope.mentionSuggestions = [];
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

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#39;")
}

function formatChatMessage(string) {

    let result = '';
    let currentText = '';
    let classes = new Set();

    string = escapeHtml(string);
    const tokens = string.split(/(\^.)/g);

    const flush = () => {
        if (!currentText) return;
        const classList = Array.from(classes);
        const formattedText = highlightEscapedMentions(currentText, localChatUsername);
        result += classList.length
            ? `<span class="${classList.join(' ')}">${formattedText}</span>`
            : formattedText;
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

function highlightEscapedMentions(escapedText, username) {
	if (!username) return escapedText;
	const escapedUsername = escapeHtml(username).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
	const pattern = new RegExp(`(^|[^\\w])(@${escapedUsername})(?=$|[^\\w])`, "gi");
	return escapedText.replace(pattern, '$1<span class="chat-mention">$2</span>');
}

function appendTextWithMention(parent, text, username) {
	if (!username) {
		parent.appendChild(document.createTextNode(text));
		return;
	}
	const escapedUsername = username.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
	const pattern = new RegExp(`(^|[^\\w])(@${escapedUsername})(?=$|[^\\w])`, "gi");
	let lastIndex = 0;
	for (const match of text.matchAll(pattern)) {
		const mentionStart = match.index + match[1].length;
		parent.appendChild(document.createTextNode(text.slice(lastIndex, mentionStart)));
		const mention = document.createElement("span");
		mention.className = "chat-mention";
		mention.textContent = match[2];
		parent.appendChild(mention);
		lastIndex = mentionStart + match[2].length;
	}
	parent.appendChild(document.createTextNode(text.slice(lastIndex)));
}

function buildMentionSegments(text, usernames) {
	const names = [...new Set(usernames.filter(name => typeof name === "string" && name.length))]
		.sort((first, second) => second.length - first.length);
	if (!names.length) return [{ text, isMention: false }];
	const alternatives = names.map(name => name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));
	const pattern = new RegExp(`(^|[^\\w])(@(?:${alternatives.join("|")}))(?=$|[^\\w])`, "gi");
	const segments = [];
	let lastIndex = 0;
	for (const match of text.matchAll(pattern)) {
		const mentionStart = match.index + match[1].length;
		if (mentionStart > lastIndex) {
			segments.push({ text: text.slice(lastIndex, mentionStart), isMention: false });
		}
		segments.push({ text: match[2], isMention: true });
		lastIndex = mentionStart + match[2].length;
	}
	if (lastIndex < text.length || !segments.length) {
		segments.push({ text: text.slice(lastIndex), isMention: false });
	}
	return segments;
}

function stripChatFormatCodes(value) {
	return String(value ?? "").replace(/\^p/g, " ").replace(/\^./g, "").replace(/\s+/g, " ").trim();
}

function truncateReplyQuote(value) {
	const characters = Array.from(stripChatFormatCodes(value));
	return characters.length > 50 ? characters.slice(0, 50).join("") + "…" : characters.join("");
}

function sanitizeReplyRoleTag(value) {
	return Array.from(stripChatFormatCodes(value))
		.slice(0, 32)
		.join("")
		.replace(/[{}|]/g, " ")
		.replace(/@/g, "＠");
}

function buildReplyPrefix(author, quote, roleColor = "", roleTag = "") {
	roleColor = sanitizeReplyRoleColor(roleColor);
	roleTag = sanitizeReplyRoleTag(roleTag);
	const safeAuthor = author.replace(/[|\]]/g, " ").replace(/@/g, "＠")
	const safeQuote = quote.replace(/\|/g, "¦").replace(/@/g, "＠")
	return `↪ [${safeAuthor}]${roleColor ? ` {${roleColor}}` : ""}${roleTag ? ` {tag:${roleTag}}` : ""} ${safeQuote} | `;
}

function sanitizeReplyRoleColor(value) {
	return typeof value === "string" && /^#[0-9a-f]{6}$/i.test(value) ? value.toLowerCase() : "";
}

function getReplyRoleColor(roleTag, color) {
	if (typeof roleTag !== "string" || !roleTag.trim()) return "";
	const channels = [0, 1, 2].map(index => Number(color?.[index]));
	if (!channels.every(Number.isFinite)) return "";
	return `#${channels
		.map(channel => Math.round(Math.max(0, Math.min(255, channel))).toString(16).padStart(2, "0"))
		.join("")}`;
}

function createReplyTarget(author, value, roleColor = "", roleTag = "") {
	let authorText = Array.from(stripChatFormatCodes(author)).slice(0, 48).join("");
	let quote = truncateReplyQuote(value);
	roleColor = sanitizeReplyRoleColor(roleColor);
	roleTag = sanitizeReplyRoleTag(roleTag);

	let prefix = buildReplyPrefix(authorText, quote, roleColor, roleTag);
	while (prefix.length > 300 && quote.length > 0) {
		quote = Array.from(quote).slice(0, -1).join("");
		prefix = buildReplyPrefix(authorText, quote, roleColor, roleTag);
	}
	while (prefix.length > 300 && authorText.length > 0) {
		authorText = Array.from(authorText).slice(0, -1).join("");
		prefix = buildReplyPrefix(authorText, quote, roleColor, roleTag);
	}
	return { author: authorText, quote, roleColor, roleTag, prefix };
}

function decodeReplyMessage(value) {
	const match = String(value ?? "").match(/^↪ \[([^\]]*)\](?: \{(#[0-9a-f]{6})\})?(?: \{tag:([^{}|]*)\})? ([\s\S]*?) \| /i);
	if (!match) return null;

	return {
		author: match[1],
		roleColor: sanitizeReplyRoleColor(match[2]),
		roleTag: sanitizeReplyRoleTag(match[3]),
		quote: match[4],
		body: String(value).slice(match[0].length),
	};
}

function containsLocalMention(text, username) {
	if (!username) return false;
	const escapedUsername = username.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
	const pattern = new RegExp(`(^|[^\\w])@${escapedUsername}(?=$|[^\\w])`, "i");
	return pattern.test(text);
}

function isReplyToLocalUser(author, username) {
	return Boolean(author && username && author.toLowerCase() === username.toLowerCase());
}

function isChatMessageMention(text, username, replyAuthor = null) {
	const reply = decodeReplyMessage(text);
	return isReplyToLocalUser(replyAuthor ?? reply?.author, username)
		|| containsLocalMention(reply?.body ?? text, username);
}

function updateChatMentionHighlights() {
	document.querySelectorAll("#chat-list .chat-message").forEach(message => {
		message.classList.toggle(
			"chat-message-mention",
			isChatMessageMention(
				message.dataset.chatMessageText || "",
				localChatUsername,
				message.dataset.chatMessageReplyAuthor
			)
		);
	});
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

function addMessage(msg, time = null, chatData = null, replyLabel) {
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
	const messageBody = typeof chatData?.body === "string" ? chatData.body : msgText;
	const reply = decodeReplyMessage(messageBody);
	chatMessageNode.dataset.chatMessageText = reply?.body ?? messageBody;
	chatMessageNode.dataset.chatMessageReplyAuthor = reply?.author ?? "";
	chatMessageNode.classList.toggle(
		"chat-message-mention",
		isReplyToLocalUser(reply?.author, localChatUsername)
			|| containsLocalMention(chatMessageNode.dataset.chatMessageText, localChatUsername)
	);
	fadeNode(chatMessageNode);

	// create node for the timestamp
	const messageTimestampNode = document.createElement("span");
	messageTimestampNode.className = "chat-message-timestamp";

	const timestampTextNode = document.createTextNode(time);
	messageTimestampNode.appendChild(timestampTextNode);

	// create text for the message itself, add it to chat message list
	const chatList = document.getElementById("chat-list");

	if (typeof chatData?.username === "string" && typeof chatData?.body === "string") {
		const color = chatData.color;
		const channels = [0, 1, 2].map(index => Number(color?.[index]));
		const roleColor = channels.every(Number.isFinite)
			? `rgb(${channels.map(channel => Math.max(0, Math.min(255, channel))).join(", ")})`
			: "";
		const identityNode = document.createElement("span");
		identityNode.className = "chat-message-identity";
		if (roleColor) identityNode.style.color = roleColor;

		if (chatData.roleTag) {
			const roleTagNode = document.createElement("span");
			roleTagNode.className = "chat-message-role";
			roleTagNode.appendChild(document.createTextNode(chatData.roleTag + " "));
			identityNode.appendChild(roleTagNode);
		}

		const usernameNode = document.createElement("span");
		usernameNode.className = "chat-message-username";
		usernameNode.appendChild(document.createTextNode(chatData.username));
		identityNode.appendChild(usernameNode);
		if (reply) {
			const replyPreviewNode = document.createElement("span");
			replyPreviewNode.className = "chat-message-reply-preview";
			const replyArrowNode = document.createElement("span");
			replyArrowNode.className = "chat-message-reply-arrow";
			replyArrowNode.textContent = "↪";
			const replyAuthorNode = document.createElement("span");
			replyAuthorNode.className = "chat-message-reply-author";
			replyAuthorNode.textContent = reply.author;
			if (reply.roleColor) replyAuthorNode.style.color = reply.roleColor;
			let replyRoleNode = null;
			if (reply.roleTag) {
				replyRoleNode = document.createElement("span");
				replyRoleNode.className = "chat-message-reply-role";
				replyRoleNode.textContent = reply.roleTag + " ";
				if (reply.roleColor) replyRoleNode.style.color = reply.roleColor;
			}
			const replyQuoteNode = document.createElement("span");
			replyQuoteNode.className = "chat-message-reply-quote";
			replyQuoteNode.innerHTML = formatChatMessage(truncateReplyQuote(reply.quote));
			replyPreviewNode.appendChild(replyArrowNode);
			if (replyRoleNode) replyPreviewNode.appendChild(replyRoleNode);
			replyPreviewNode.appendChild(replyAuthorNode);
			replyPreviewNode.appendChild(document.createTextNode(": "));
			replyPreviewNode.appendChild(replyQuoteNode);
			chatMessageNode.appendChild(replyPreviewNode);

			const replyContentNode = document.createElement("span");
			replyContentNode.className = "chat-message-reply-content";
			replyContentNode.appendChild(messageTimestampNode);
			replyContentNode.appendChild(identityNode);
			replyContentNode.appendChild(document.createTextNode(": "));
			const replyBodyNode = document.createElement("span");
			replyBodyNode.className = "chat-message-reply-body";
			appendTextWithMention(replyBodyNode, reply.body, localChatUsername);
			replyContentNode.appendChild(replyBodyNode);
			chatMessageNode.appendChild(replyContentNode);
		} else {
			chatMessageNode.appendChild(messageTimestampNode);
			chatMessageNode.appendChild(identityNode);
			chatMessageNode.appendChild(document.createTextNode(": "));
			appendTextWithMention(chatMessageNode, chatData.body, localChatUsername);
		}
	} else {
		chatMessageNode.appendChild(messageTimestampNode);
		appendTextWithMention(chatMessageNode, msgText, localChatUsername);
	}

	if (typeof chatData?.username === "string" && chatData.username !== "Server") {
		chatMessageNode.dataset.replyAuthor = chatData.username;
		chatMessageNode.dataset.replyText = reply?.body ?? messageBody;
		const replyRoleColor = getReplyRoleColor(chatData.roleTag, chatData.color);
		if (replyRoleColor) chatMessageNode.dataset.replyRoleColor = replyRoleColor;
		const replyRoleTag = sanitizeReplyRoleTag(chatData.roleTag);
		if (replyRoleTag) chatMessageNode.dataset.replyRoleTag = replyRoleTag;
		const replyButton = document.createElement("button");
		replyButton.className = "chat-message-reply";
		replyButton.type = "button";
		replyButton.dataset.tooltip = replyLabel;
		replyButton.setAttribute("aria-label", replyLabel);
		replyButton.textContent = "↩";
		chatMessageNode.appendChild(replyButton);
	}

	const shouldFollowLatestMessage = isFollowingLatestMessage();
	chatList.appendChild(chatMessageNode);

	// Delete oldest chat message if more than 70 messages exist
	if (chatList.children.length > 70) {
		chatList.removeChild(chatList.children[0]);
	}
	
	if (shouldFollowLatestMessage) scrollToLastMessage();

}

function isFollowingLatestMessage() {
	const chatlist = document.getElementById("chat-list");
	if (!chatlist) return true;
	if (getComputedStyle(chatlist).flexDirection === "column-reverse") {
		const scrollEnd = chatlist.clientHeight - chatlist.scrollHeight;
		return Math.abs(chatlist.scrollTop - scrollEnd) <= 32;
	}
	return chatlist.scrollHeight - chatlist.clientHeight - chatlist.scrollTop <= 32;
}

function scrollToLastMessage() {
	const chatwindow = document.getElementById("chat-window");
	const chatlist = document.getElementById("chat-list");
	if (chatScrollAnimation !== null) {
		cancelAnimationFrame(chatScrollAnimation);
		chatScrollAnimation = null;
	}
	chatScrollTarget = null;
	const isReversed = getComputedStyle(chatwindow).flexDirection === "column-reverse";
	if (isReversed) {
		chatlist.scrollTop = -chatlist.scrollHeight;
	} else {
		chatlist.scrollTop = chatlist.scrollHeight;
	}
}

function handleChatListWheel(event) {
	const chatApp = document.getElementById("BeamMPChat");
	const chatlist = document.getElementById("chat-list");
	if (!chatApp || !chatApp.contains(event.target) || !chatlist) return;

	const suggestionPanel = event.target.closest?.(".mention-suggestions");
	if (suggestionPanel) {
		const suggestionList = event.target.closest?.(".mention-suggestion-list");
		if (!suggestionList) {
			event.preventDefault();
			event.stopPropagation();
			return;
		}
		event.preventDefault();
		event.stopPropagation();
		const lineHeight = Number.parseFloat(getComputedStyle(suggestionList).lineHeight) || 16;
		const scrollDelta = event.deltaMode === 1
			? event.deltaY * lineHeight
			: event.deltaMode === 2
				? event.deltaY * suggestionList.clientHeight
				: event.deltaY;
		suggestionList.scrollTop += scrollDelta;
		return;
	}

	event.preventDefault();
	event.stopPropagation();

	const lineHeight = Number.parseFloat(getComputedStyle(chatlist).lineHeight) || 16;
	const scrollDelta = event.deltaMode === 1
		? event.deltaY * lineHeight
		: event.deltaMode === 2
			? event.deltaY * chatlist.clientHeight
			: event.deltaY;
	chatScrollTarget = (chatScrollTarget ?? chatlist.scrollTop) + scrollDelta;

	const isReversed = getComputedStyle(chatlist).flexDirection === "column-reverse";
	const maxScroll = Math.max(0, chatlist.scrollHeight - chatlist.clientHeight);
	chatScrollTarget = Math.max(isReversed ? -maxScroll : 0, Math.min(isReversed ? 0 : maxScroll, chatScrollTarget));

	if (chatScrollAnimation !== null) return;

	const animateScroll = function() {
		const remaining = chatScrollTarget - chatlist.scrollTop;
		if (Math.abs(remaining) < 0.5) {
			chatlist.scrollTop = chatScrollTarget;
			chatScrollAnimation = null;
			chatScrollTarget = null;
			return;
		}

		chatlist.scrollTop += remaining * 0.28;
		chatScrollAnimation = requestAnimationFrame(animateScroll);
	};

	chatScrollAnimation = requestAnimationFrame(animateScroll);
}

})();