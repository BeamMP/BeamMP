var app = angular.module('beamng.apps');
var mdDialog;
var mdDialogVisible = false;

app.directive('multiplayersession', [function () {
	return {
		templateUrl: '/ui/modules/apps/BeamMP-Session/app.html',
		replace: true,
		restrict: 'EA',
		scope: true,
		controllerAs: 'ctrl'
	}
}]);

app.controller("Session", ['$scope', '$mdDialog', function ($scope, $mdDialog) {
	$scope.init = function() {
		bngApi.engineLua('UI.ready("MP-SESSION")'); // needed to get the server name
		bngApi.engineLua('UI.sendQueue()'); // asks the lua to send queue data
	};

	mdDialog = $mdDialog;

	$scope.mpquit = function() {
		bngApi.engineLua('MPCoreNetwork.leaveServer(true)');
	};

	$scope.applyQueue = function() {
		bngApi.engineLua('MPVehicleGE.applyQueuedEvents()');
	};

	$scope.reset = function() {
		$scope.init();
	};

	$scope.select = function() {
		bngApi.engineLua('setCEFFocus(true)');
	};

	$scope.$on('showMdDialog', function (event, data) {
		switch(data.dialogtype) {
			case "alert":
				if (mdDialogVisible) { return; }
				console.log(data);
				console.log(mdDialogVisible);
				mdDialogVisible = true;
				mdDialog.show(
					mdDialog.alert().title(data.title).content(data.text).ok(data.okText)
				).then(function() {
					mdDialogVisible = false;
					if (data.okJS !== undefined) { eval(data.okJS); return; }
					else if (data.okLua !== undefined) { bngApi.engineLua(data.okLua); return; }
				}, function() { mdDialogVisible = false; })
				break;
		}
	});

	$scope.$on('setPing', function (event, ping) {
		var sessionPing = document.getElementById("Session-Ping")
		// To ensure that the element exists
		if (sessionPing) {
			sessionPing.innerHTML = ping;
		}
	});

	$scope.$on('setQueue', function (event, queue) {
		var queueBlock = document.getElementById("queue-block");
		// To ensure that the element exists
		if (queueBlock) {
			if (queue.show) queueBlock.style.display = "";
			else { queueBlock.style.display = "none"; return;}
		}		
		
		var queueCount = queue.editCount + queue.spawnCount;
		var queueElem = document.getElementById("Session-Queue")
		queueElem.innerHTML = `${queue.spawnCount}|${queue.editCount}`;
		queueElem.title = `Edits: ${queue.editCount}\nSpawns: ${queue.spawnCount}`; // titles dont work in game :C

	});

	$scope.$on('setStatus', function (event, status) {
		console.log('Setting status to: ' + sanitizeString(status))
		if (status == "") document.getElementById("server-name-block").style.display = "none";
		else document.getElementById("server-name-block").style.display = "";
		document.getElementById("Session-Status").innerHTML = sanitizeString(status); // DISPLAY SERVER NAME FORMATTING
	});

	$scope.$on('setPlayerCount', function (event, count) {
		document.getElementById("Session-PlayerCount").innerHTML = count;
	});
}]);

function sanitizeString(str) {  // VERY basic sanitization.
	str = str.replace(/<script.*?<\/script>/g, '');
	str = str.replace(/<button.*?<\/button>/g, '');
	str = str.replace(/<iframe.*?<\/iframe>/g, '');
	str = str.replace(/<a.*?<\/a>/g, '');
    return str
}
