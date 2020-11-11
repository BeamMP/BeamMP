var connected = false;
var players = [];
let pingList = [];
var nickname = "";
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

	//console.log("Setting Elements for player list")

	if(players != null){
		//get differences between playernames and send them as messages

		var left = players.filter((item)=>{
			return !parsedList.includes(item)
		});

		let joined = parsedList.filter((item)=>{
			return !players.includes(item)
		});

		//for(var i = 0; i< left.length;i++)
			//if(left[i].length>0) addMessage(left[i] + " left the server"); //the game would send an empty left message when joining a server

		//for(var i = 0; i< joined.length;i++)
			//addMessage(joined[i] + " joined the server");

		//if(joined.length>0 || left.length>0){ //update playerlist if someone joined or left //keep updating because pings are a thing now
			clearPlayerList();
			for (let i = 0; i < parsedList.length; i++) {
				var row = playersList.insertRow(playersList.rows.length);
				var cell1 = row.insertCell(0);
				cell1.textContent = parsedList[i];
				cell1.className = "playerlistName";
				cell1.setAttribute("onclick","showPlayerInfo('"+parsedList[i]+"')");

				//adding button
				if(parsedList[i].trim() != nickname.trim()){
					var cell2 = row.insertCell(1);
					cell2.style.width = '30px';
					var btn = document.createElement("BUTTON");
					if (pingList[parsedList[i]] != null)
						btn.appendChild(document.createTextNode(pingList[parsedList[i]]));
					btn.setAttribute("onclick","teleportToPlayer('"+parsedList[i]+"')");
					btn.setAttribute("class","tp-button");
					cell2.appendChild(btn);
				}else{
					cell1.colSpan = 2;
				}
			}
			if(document.getElementById("plist-container").style.display == "block")
				document.getElementById("plist-show-button").style.height = playersList.offsetHeight+"px"; 

		//}
	}
	players = parsedList; //store player list as an array for the next update
}

function playerPings(list) {
	pingList = JSON.parse(list);
	for(let i = 0; i < pingList.length; i++) {
		pingList[i] = pingList[i]-16;
		if (pingList[i] > 999) pingList[i] = 999;
	}
	//console.log(pingList);
}


function clearPlayerList() {
	let playersList = document.getElementById("playerstable");
	var rowCount = playersList.rows.length - 1;
	for(rowCount; rowCount > 0; rowCount--) {
		playersList.deleteRow(1);
	}
}

function teleportToPlayer(targetPlayerName) {
	console.log("teleportEvent: " + targetPlayerName);
	//addMessage("Teleporting to " + targetPlayerName);
	//actually teleport the car lol
}

function showPlayerInfo(targetPlayerName) {
	console.log("showPlayerInfoEvent: " + targetPlayerName);
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
	var btn = document.getElementById("plist-show-button");
	console.log("Playerlist window state: " + listcont.style.display);
	if(listcont.style.display != "block") { listcont.style.display = "block"; btn.innerHTML = '>'; }
	else { listcont.style.display = "none"; btn.innerHTML = 'P l a y e r s'; btn.style.height = "160px"; }

	console.log("Playerlist window state: " + listcont.style.display);
}
