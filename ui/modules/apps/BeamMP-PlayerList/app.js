// Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
// Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
// SPDX-License-Identifier: AGPL-3.0-or-later

var connected = false;
var players = [];
let pingList = [];
var nickname = "";
var app = angular.module('beamng.apps');
app.directive('multiplayerplayerlist', [function () {
	return {
		templateUrl: '/ui/modules/apps/BeamMP-PlayerList/app.html',
		replace: true,
		restrict: 'EA',
		scope: true,
		controllerAs: 'ctrl'
	}
}]);
app.controller("PlayerList", ['$scope', function ($scope) {
	$scope.warnVis = false;
	$scope.timer = null;
	$scope.showPlayerIDs = true
	$scope.queueWithLMB = true;
	$scope.init = function() {
		// Set players list direction
		setPLDirection(localStorage.getItem('plHorizontal'));
		setPLDirection(localStorage.getItem('plVertical'));
		if (localStorage.getItem('plShown') == 1) showList();
	};

	$scope.settingsChanged = function() {
    bngApi.engineLua('settings.getValue("showPlayerIDs")', (data) => {
      $scope.showPlayerIDs = data
    })
	bngApi.engineLua('settings.getValue("queueWithLMB")', (data) => {
		$scope.queueWithLMB = data
	  })
  }
  $scope.settingsChanged()

	$scope.reset = function() {
		connected = false;
		players = [];
		$scope.init();
		$scope.settingsChanged()
	};

	$scope.select = function() {
		bngApi.engineLua('setCEFFocus(true)');
	};

	$scope.disconnect = function() {
		players = [];
		connected = false;
	};

	function setPLDirection(direction) {
		const mainContainer = document.getElementById("main-container");
		const plistContainer = document.getElementById("plist-container");
		const showButton = document.getElementById("show-button");
		if (direction == "left") {
			mainContainer.style.flexDirection = "row-reverse";
			localStorage.setItem('plHorizontal', "left");
		}
		else if (direction == "right") {
			mainContainer.style.flexDirection = "row";
			localStorage.setItem('plHorizontal', "right");
		}
		else if (direction == "top") {
			plistContainer.style.marginTop = "0";
			showButton.style.marginTop = "0";
			localStorage.setItem('plVertical', "top");
		}
		else if (direction == "bottom") {
			plistContainer.style.marginTop = "auto";
			showButton.style.marginTop = "auto";
			localStorage.setItem('plVertical', "bottom");
		}
	}

	$scope.plSwapHorizontal = function() {
		const plHorizontal = localStorage.getItem('plHorizontal');
		console.log(plHorizontal);
		if (plHorizontal != "left") setPLDirection("left");
		else setPLDirection("right");
	}

	$scope.plSwapVertical = function() {
		const plVertical = localStorage.getItem('plVertical');
		if (plVertical != "bottom") setPLDirection("bottom");
		else setPLDirection("top");
	}

	$scope.$on('playerPings', function(event, data) {
		pingList = JSON.parse(data);
		for(let i = 0; i < pingList.length; i++) {
			pingList[i] = pingList[i]-16;
			if (pingList[i] > 999) pingList[i] = 999;
		}
	})

	$scope.$on('playerList', function(event, data) {
		let playersList = document.getElementById("players-table");
		let parsedList = JSON.parse(data);
		
		if(players != null && playersList != null){
			//get differences between playernames and send them as messages
			var left = players.filter((item) => { return !parsedList.includes(item) });
			var joined = parsedList.filter((item) => { return !players.includes(item) });
	
			// Clear the player list
			clearPlayerList();
	
			parsedList.sort(function(a, b) {
				var keyA = a.id,
					  keyB = b.id;
				// Compare the 2 dates
				if (keyA < keyB) return -1;
				if (keyA > keyB) return 1;
				return 0;
			});

			// And fill it with the updated players
			for (let i = 0; i < parsedList.length; i++) {
				// Insert a row at the end of the players list
				var row = playersList.insertRow(playersList.rows.length);
	
				row.setAttribute("id", "playerlist-row-" + parsedList[i].id);

				// Insert a cell containing the player server id
				var idCell = row.insertCell(0);
				idCell.textContent = parsedList[i].id;
				idCell.setAttribute("onclick", "restorePlayerVehicle('"+parsedList[i].name+"')");
				if ($scope.showPlayerIDs) {
					idCell.setAttribute("class", "player-id");
				} else {
					idCell.setAttribute("class", "player-id ng-hide");
				}
				


				// Insert a cell containing the player name
				var nameCell = row.insertCell(1);
				nameCell.textContent = parsedList[i].formatted_name;
				//var c = parsedList[i].color
				//nameCell.style = `color:rgba(${c[0]},${c[1]},${c[2]},255)`;
				nameCell.setAttribute($scope.queueWithLMB ? "oncontextmenu" : "onclick", "showPlayerInfo('"+parsedList[i].name+"')");
				nameCell.setAttribute($scope.queueWithLMB ? "onclick" : "oncontextmenu","applyQueuesForPlayer('"+parsedList[i].id+"')");
				nameCell.setAttribute("class", "player-button");

				// Insert a cell containing the link to forum
				//var infoCell = row.insertCell(2);
				//infoCell.setAttribute("class", "view-button");

				// Insert the button inside the link to forum
				//var btn = document.createElement("BUTTON");
				//var pingText = "?";
				//btn.appendChild(document.createTextNode(pingText));
				//btn.setAttribute("onclick","viewPlayer('"+parsedList[i].name+"')");
				//btn.setAttribute("class", "view-button buttons");
				//infoCell.appendChild(btn);
	
				// Insert a cell containing the player ping
				var pingCell = row.insertCell(2);
				pingCell.setAttribute("class", "tp-button");
	
				// Insert the button inside the cell
				var btn = document.createElement("BUTTON");
				var pingText = pingList[parsedList[i].name] || "?";
				btn.appendChild(document.createTextNode(pingText+='ms'));
				btn.setAttribute("onclick","teleportToPlayer('"+parsedList[i]+"')");
				btn.setAttribute("class", "tp-button buttons");
				pingCell.appendChild(btn);

				if ($scope.queuedPlayers[parsedList[i].id] == true) {
					row.style.setProperty('background-color', 'var(--bng-orange-shade1)');
				}
			}
			if(document.getElementById("plist-container").style.display == "block")
				document.getElementById("show-button").style.height = playersList.offsetHeight + "px"; 
		}
		players = parsedList; //store player list as an array for the next update
	})

	$scope.$on('setNickname', function(event, data) {
		nickname = data
	})

	$scope.queuedPlayers = []

	$scope.$on('setQueue', function(event, data) {
		$scope.queuedPlayers = []

		if (!data.queuedPlayers) {
			var rows = document.querySelectorAll('[id^="playerlist-row-"]');
			for (let i = 0; i < rows.length; i++) {
				rows[i].style.setProperty('background-color', 'transparent');
			}
			return
		}

		for (var key in data.queuedPlayers) {
			$scope.queuedPlayers[key] = data.queuedPlayers[key]
			var playerrow = document.getElementById("playerlist-row-" + key)
			if (playerrow) {
				playerrow.style.setProperty('background-color', data.queuedPlayers[key] ? 'var(--bng-orange-shade1)' : 'transparent')
			}
		}
	})

	bngApi.engineLua('UI.updatePlayersList(); UI.sendQueue()'); // instantly populate the playerlist and their queues
}]);


function clearPlayerList() {
	let playersList = document.getElementById("players-table");
	var rowCount = playersList.rows.length - 1;
	for(rowCount; rowCount > 0; rowCount--) playersList.deleteRow(1);
}

function teleportToPlayer(targetPlayerName) {
	//console.log("teleportEvent: " + targetPlayerName);
	//bngApi.engineLua('MPVehicleGE.teleportVehToPlayer("'+targetPlayerName+'")')
}

function viewPlayer(targetPlayerName) {
	openExternalLink(`https://forum.beammp.com/u/${targetPlayerName}/summary`)
}

function restorePlayerVehicle(targetPlayerName){
    	bngApi.engineLua('MPVehicleGE.restorePlayerVehicle("'+targetPlayerName+'")')
}

function applyQueuesForPlayer(targetPlayerID) {
	bngApi.engineLua('MPVehicleGE.applyPlayerQueues('+targetPlayerID+')')
}

function showPlayerInfo(targetPlayerName) {
	//console.log("showPlayerInfoEvent: " + targetPlayerName);
	bngApi.engineLua('MPVehicleGE.focusCameraOnPlayer("'+targetPlayerName+'")')
}


function setOfflineInPlayerList() {
	let playersList = document.getElementById("players");
	if(playersList != null) playersList.textContent = "OFFLINE"; //added this cause it was throwing console errors
}

function showList() {
	var shownText = "&gt;";
	var hiddenText = "&lt;";
	if (localStorage.getItem('plHorizontal') == "right") { shownText = "&lt;"; hiddenText = "&gt;"; }
	var plContainer = document.getElementById("plist-container");
	var btn = document.getElementById("show-button");
	plContainer.style.display = "block";
	btn.innerHTML = shownText;
}

function hideList() {
	var hiddenText = "&lt;";
	if (localStorage.getItem('plHorizontal') == "right") { hiddenText = "&gt;"; }
	var plContainer = document.getElementById("plist-container");
	var btn = document.getElementById("show-button");
	plContainer.style.display = "block";
	btn.innerHTML = shownText;
}

function hideList() {
	var hiddenText = "&lt;";
	if (localStorage.getItem('plHorizontal') == "right") { hiddenText = "&gt;"; }
	var plContainer = document.getElementById("plist-container");
	var btn = document.getElementById("show-button");
	plContainer.style.display = "none";
	btn.innerHTML = hiddenText;
	btn.style.height = "75px";
}

function toggleList() {
	if(localStorage.getItem('plShown') != 1) {
		showList();
		localStorage.setItem('plShown', 1);
	}
	else {
		hideList();
		localStorage.setItem('plShown', 0);
	}
}
