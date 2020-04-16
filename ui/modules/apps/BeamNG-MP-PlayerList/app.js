var connected = false;
var players = [];
var app = angular.module('beamng.apps');
app.directive('multiplayerplayerlist', ['UiUnits', function (UiUnits) {
	return {
		templateUrl: 'modules/apps/BeamNG-MP-PlayerList/app.html',
		replace: true,
		restrict: 'EA',
		scope: true
	}
}]);
app.controller("PlayerList", ['$scope', 'bngApi', function ($scope, bngApi) {
	$scope.warnVis = false;
	$scope.timer = null;
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
	let playersList = document.getElementById("playerstable");
	let parsedList = JSON.parse(list);

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

		if(joined.length>0 && left.length>0){ //update playerlist if someone joined or left
			clearPlayerList();
			for (let i = 0; i < parsedList.length; i++) {
				var row = playersList.insertRow(playersList.rows.length);
				var cell1 = row.insertCell(0);//insert in first column
				cell1.textContent = parsedList[i];

				//adding button
				var cell2 = row.insertCell(1);//insert in second column
				cell2.style.width = '30px';
				if(parsedList[i] != nickname){
					var btn = document.createElement("BUTTON");
					btn.appendChild(document.createTextNode("TP"));
					btn.setAttribute("onclick","teleportToPlayer('"+parsedList[i]+"')");
					cell2.appendChild(btn);
					cell1.setAttribute("onclick","teleportToPlayer('"+parsedList[i]+"')");
				}
			}
		}
	}
	players = parsedList; //store player list as an array for the next update
}

function clearPlayerList() {
	let playersList = document.getElementById("playerstable");
	var rowCount = playersList.rows.length - 1;
	for(rowCount; rowCount > 0; rowCount--) {
		playersList.deleteRow(1);
	}
	//var row = playersList.insertRow(0);
	//var cell1 = row.insertCell(0);
	//cell1.textContent = "PLAYERS";
}

function teleportToPlayer(targetPlayerName) {
	console.log("teleportEvent");
	addMessage("Teleporting to " + targetPlayerName);
	//actually teleport the car lol
}

function setOfflineInPlayerList() {
	let playersList = document.getElementById("players");
	if(playersList != null) playersList.textContent = "OFFLINE"; //added this cause it was throwing console errors
}

function toggleList() {
	var listcont = document.getElementById("list-container");
	var btn = document.getElementById("show-button");
	console.log("Playerlist window state: " + listcont.style.display);
	if(listcont.style.display != "block") { listcont.style.display = "block"; btn.innerHTML = 'Hide Players'; }
	else {listcont.style.display = "none"; btn.innerHTML = 'Show Players'; }

	console.log("Playerlist window state: " + listcont.style.display);
}
