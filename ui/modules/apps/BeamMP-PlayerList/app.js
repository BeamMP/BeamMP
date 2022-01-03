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
	$scope.init = function() {
		bngApi.engineLua('UI.ready("MP-PlayerList")');
		// Set players list direction
		setPLDirection(localStorage.getItem('plHorizontal'));
		setPLDirection(localStorage.getItem('plVertical'));
		if (localStorage.getItem('plShown') == 1) showList();
	};

	$scope.reset = function() {
		connected = false;
		players = [];
		$scope.init();
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
}]);

function playerList(list) {
	let playersList = document.getElementById("players-table");
	let parsedList = JSON.parse(list);
	
	if(players != null && playersList != null){
		//get differences between playernames and send them as messages
		var left = players.filter((item) => { return !parsedList.includes(item) });
		var joined = parsedList.filter((item) => { return !players.includes(item) });

		// Clear the player list
		clearPlayerList();

		// And fill it with the updated players
		for (let i = 0; i < parsedList.length; i++) {
			// Insert a row at the end of the players list
			var row = playersList.insertRow(playersList.rows.length);

			// Insert a cell containing the player name
			var nameCell = row.insertCell(0);
			nameCell.textContent = parsedList[i];
			nameCell.setAttribute("onclick", "showPlayerInfo('"+parsedList[i]+"')");

			// Insert a cell containing the player ping
			var pingCell = row.insertCell(1);
			pingCell.setAttribute("class", "tp-button");

			// Insert the button inside the cell
			var btn = document.createElement("BUTTON");
			var pingText = pingList[parsedList[i]] || "?";
			btn.appendChild(document.createTextNode(pingText));
			btn.setAttribute("onclick","teleportToPlayer('"+parsedList[i]+"')");
			btn.setAttribute("class", "tp-button buttons");
			pingCell.appendChild(btn);
		}
		if(document.getElementById("plist-container").style.display == "block")
			document.getElementById("show-button").style.height = playersList.offsetHeight + "px"; 
	}
	players = parsedList; //store player list as an array for the next update
}

function playerPings(list) {
	pingList = JSON.parse(list);
	for(let i = 0; i < pingList.length; i++) {
		pingList[i] = pingList[i]-16;
		if (pingList[i] > 999) pingList[i] = 999;
	}
}


function clearPlayerList() {
	let playersList = document.getElementById("players-table");
	var rowCount = playersList.rows.length - 1;
	for(rowCount; rowCount > 0; rowCount--) playersList.deleteRow(1);
}

function teleportToPlayer(targetPlayerName) {
	console.log("teleportEvent: " + targetPlayerName);
	//bngApi.engineLua('MPVehicleGE.teleportVehToPlayer("'+targetPlayerName+'")')
}

function showPlayerInfo(targetPlayerName) {
	console.log("showPlayerInfoEvent: " + targetPlayerName);
	bngApi.engineLua('MPVehicleGE.teleportCameraToPlayer("'+targetPlayerName+'")')
}

function setNickname(n) {
	nickname = n
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
