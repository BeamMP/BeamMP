var connected = false;
var players = [];
let pingList = [];
var nickname = "";
var bngApiScope;
var app = angular.module('beamng.apps');
app.directive('multiplayerplayerlist', ['UiUnits', function (UiUnits) {
	return {
		templateUrl: 'modules/apps/BeamMP-PlayerList/app.html',
		replace: true,
		restrict: 'EA',
		scope: true
	}
}]);
app.controller("PlayerList", ['$scope', 'bngApi', function ($scope, bngApi) {
	$scope.warnVis = false;
	$scope.timer = null;
	bngApiScope =  bngApi;
	$scope.init = function() {
		bngApi.engineLua('UI.ready("MP-PlayerList")');
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
}]);

function playerList(list) {
	let playersList = document.getElementById("players-table");
	let parsedList = JSON.parse(list);
	if(players != null){
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

			if(parsedList[i].trim() != nickname.trim()) {
				// Insert a cell containing the player ping
				var pingCell = row.insertCell(1);
				pingCell.style.width = "50px";
				pingCell.style.height= "25px";
				pingCell.style.border = "none";
				
				// Insert the button inside the cell
				var btn = document.createElement("BUTTON");
				if (pingList[parsedList[i]]) btn.appendChild(document.createTextNode(pingList[parsedList[i]]));
				btn.setAttribute("onclick","teleportToPlayer('"+parsedList[i]+"')");
				btn.setAttribute("class", "tp-button buttons");
				pingCell.appendChild(btn);
			} else{
				nameCell.colSpan = 2;
			}
		}
		if(document.getElementById("plist-container").style.display == "block")
			document.getElementById("show-button").style.height = playersList.offsetHeight+"px"; 
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
	//bngApiScope.engineLua('MPVehicleGE.teleportVehToPlayer("'+targetPlayerName+'")')
}

function showPlayerInfo(targetPlayerName) {
	console.log("showPlayerInfoEvent: " + targetPlayerName);
	bngApiScope.engineLua('MPVehicleGE.teleportCameraToPlayer("'+targetPlayerName+'")')
}


function setNickname(n) {
	nickname = n
}

function setOfflineInPlayerList() {
	let playersList = document.getElementById("players");
	if(playersList != null) playersList.textContent = "OFFLINE"; //added this cause it was throwing console errors
}

function toggleList() {
	var listcont = document.getElementById("plist-container");
	var btn = document.getElementById("show-button");
	if(listcont.style.display != "block") { listcont.style.display = "block"; btn.innerHTML = "&gt;"; }
	else { listcont.style.display = "none"; btn.innerHTML = "&lt;"; btn.style.height = "80px"; }
}
