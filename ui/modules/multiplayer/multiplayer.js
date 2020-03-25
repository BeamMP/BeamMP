angular.module('beamng.stuff')

/**
 * @ngdoc controller
 * @name beamng.stuff:MultiplayerController
 * @requires logger
 * @requires $scope
 * @requires $state
 * @requires beamng.stuff:Contributors
 *
 * @description
 * Basic controller for the multiplayer scene
**/
.controller('MultiplayerController', ['logger', '$scope', '$state', '$timeout', 'bngApi',
function(logger, $scope, $state, $timeout, bngApi) {
	
	var vm = this;
	
	// --------- CUSTOM CODE --------- //
	bngApi.engineLua('Network.connectToLauncher()');
	
	vm.resetLauncherConnection = function() {
		bngApi.engineLua('Network.disconnectFromLauncher()');
		bngApi.engineLua('Network.connectToLauncher()');
	};
	
	vm.modelChanged = function($event) {
		var src = event.srcElement;
		console.log("ok");
		console.log(src.value);
	}
	
	$scope.$on('setMenuStatus', function (event, text) {
		document.getElementById("launcher-status").innerHTML = text;
	});	
	
	
	vm.stateName = $state.current.name;
	bngApi.engineLua('settings.requestState()');
	$scope.$on('$stateChangeSuccess', function (event, toState, toParams, fromState, fromParams) {
		vm.stateName = toState.name;
	});
	//bngApi.engineLua('core_gamestate.requestGameState();');   // if this isnt called the gamestate in menu doesnt update correctly.
	
	vm.exit = function ($event) {
		if ($event)
			logger.debug('[MultiplayerController] exiting by keypress event %o', $event);
		$state.go('menu.mainmenu');
	};

	var timeOut = $timeout(function() {
		if (vm.loadingPage === true) {
			vm.loadTimeout = true;
		}
	}, 10000);
  
	$scope.$on('$destroy', function () {
		$timeout.cancel(timeOut);
		logger.debug('[MultiplayerController] destroyed.');
	});
}])



.controller('MultiplayerServersController', ['logger', '$scope', '$state', '$timeout', 'bngApi',
function(logger, $scope, $state, $timeout, bngApi) {
	var vm = this;
	
	vm.exit = function ($event) {
		if ($event)
			logger.debug('[MultiplayerServersController] exiting by keypress event %o', $event);
		$state.go('menu.mainmenu');
	};
  
	var timeOut = $timeout(function() {
		if (vm.loadingPage === true) {
			vm.loadTimeout = true;
		}
	}, 10000);
  
	$scope.$on('$destroy', function () {
		$timeout.cancel(timeOut);
		logger.debug('[MultiplayerServersController] destroyed.');
	});
	
	function deselect(row) {
		if (!row) return;
		row.classList.remove("highlight");
		row.selected = false;
	}
	
	function select(row, table) {
		deselect(table.selectedRow);
		row.classList.add("highlight");
		row.selected = true;
		table.selectedRow = row;
	}
	
	function setColor(row) {
		if (row.rowIndex % 2 == 0) { // If odd gray / If even lightgray
			row.style.backgroundColor = "white";
		} else {
			row.style.backgroundColor = "#f2f2f2";
		}
	}
	
	vm.sortTable = function(n, data, number) {
		var table, rows, switching, i, x, y, shouldSwitch, dir, switchcount = 0;
		table = document.getElementById("servers-table");
		switching = true;
		// Set the sorting direction to ascending:
		dir = "asc";
		// Make a loop that will continue until no switching has been done:
		while (switching) {
			// Start by saying: no switching is done:
			switching = false;
			rows = table.rows;
			// Loop through all table rows (except the first, which contains table headers):
			for (i = 1; i < (rows.length - 1); i++) {
				// Start by saying there should be no switching:
				shouldSwitch = false;
				// Get the two elements you want to compare, one from current row and one from the next:
				x = rows[i].servData[data];
				y = rows[i + 1].servData[data];								
				if (x.toLowerCase) {
					x = x.toLowerCase()
					y = y.toLowerCase()
				}
				// Check if the two rows should switch place, based on the direction, asc or desc:
				if (dir == "asc") {
					if (x > y) {
						// If so, mark as a switch and break the loop:
						shouldSwitch = true;
						break;
					}
				} else if (dir == "desc") {
					if (x < y) {
					// If so, mark as a switch and break the loop:
					shouldSwitch = true;
					break;
				}
			}
		}
		if (shouldSwitch) {
			// If a switch has been marked, make the switch and mark that a switch has been done:
			rows[i].parentNode.insertBefore(rows[i + 1], rows[i]);
			switching = true;
			// Each time a switch is done, increase this count by 1:
			switchcount ++;
		} else {
			// If no switching has been done AND the direction is "asc", set the direction to "desc" and run the while loop again.
			if (switchcount == 0 && dir == "asc") {
				dir = "desc";
				switching = true;
			}
		}
	}
}
	
	$scope.$on('SteamInfo', function (event, data) {
		console.log("ok");
	});
	
	// TEMPORARY
	var table = document.getElementById("servers-table");
	for (var i = 0; i < 10; i++) {
		var row = table.rows[i];
		var servData = {};
		servData.ip = "192.168.1.1";
		servData.map = "test" + i;
		servData.players = i;
		servData.location = "AS" + i;
		servData.description = "A test server " + i;
		servData.maxPlayers = i;
		servData.ping = i*10;	
		var row = table.insertRow(table.rows.length);
		row.insertCell(0).innerHTML = servData.location;
		row.insertCell(1).innerHTML = servData.description;
		row.insertCell(2).innerHTML = servData.map;
		row.insertCell(3).innerHTML = servData.players + "/" + servData.maxPlayers;
		row.insertCell(4).innerHTML = servData.ping;
		row.servData = servData;
		row.onclick = selectRow;
	}
	
	$scope.$on('addServer', function (event, data) {
		var table = document.getElementById("servers-table");
		var row = table.insertRow(table.rows.length);
		row.insertCell(0).innerHTML = data.location;
		row.insertCell(1).innerHTML = data.description;
		row.insertCell(2).innerHTML = data.map;
		row.insertCell(3).innerHTML = data.players + "/" + data.maxPlayers;
		row.insertCell(4).innerHTML = data.ping;
		row.servData = data;
		row.onclick = selectRow;
	});

	function selectRow(event) {
		var table = document.getElementById("servers-table");
		var src = event.srcElement;
		var row = src.closest('tr');		
		select(row, table);
	};	
}])

.controller('MultiplayerSettingsController', ['logger', '$scope', '$state', '$timeout', 'bngApi',
function(logger, $scope, $state, $timeout, bngApi) {
	var vm = this;
	
	vm.exit = function ($event) {
		if ($event)
			logger.debug('[MultiplayerSettingsController] exiting by keypress event %o', $event);
		$state.go('menu.mainmenu');
	};
  
	var timeOut = $timeout(function() {
		if (vm.loadingPage === true) {
			vm.loadTimeout = true;
		}
	}, 10000);
  
	$scope.$on('$destroy', function () {
		$timeout.cancel(timeOut);
		logger.debug('[MultiplayerSettingsController] destroyed.');
	});
}])

.controller('MultiplayerDirectController', ['logger', '$scope', '$state', '$timeout', 'bngApi',
function(logger, $scope, $state, $timeout, bngApi) {
	var vm = this;
	
	vm.exit = function ($event) {
		if ($event)
			logger.debug('[MultiplayerDirectController] exiting by keypress event %o', $event);
		$state.go('menu.mainmenu');
	};
  
	var timeOut = $timeout(function() {
		if (vm.loadingPage === true) {
			vm.loadTimeout = true;
		}
	}, 10000);
  
	$scope.$on('$destroy', function () {
		$timeout.cancel(timeOut);
		logger.debug('[MultiplayerDirectController] destroyed.');
	});
}]);

