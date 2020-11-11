var serversScope, selectRowScope, connectScope, displayServerScope, showDetailsScope, bngApiScope, setVersion;
var highlightedServer;
var launcherVersion = "";
angular.module('beamng.stuff')

/**
* @ngdoc controller
* @name beamng.stuff:MultiplayerController
* @requires logger
* @requires $scope
* @requires $state
*
* @description
* Basic controller for the multiplayer scene
**/
.controller('MultiplayerController', ['logger', '$scope', '$state', '$timeout', 'bngApi', function(logger, $scope, $state, $timeout, bngApi) {
	var vm = this;
	bngApiScope = bngApi;
	// --------- CUSTOM CODE --------- //

	$scope.$on('$stateChangeSuccess', function (event, toState, toParams, fromState, fromParams) {
		//console.log("INIT")
		//console.log(toState.url)
		if (toState.url == "/multiplayer") {
			// local://local/ui/#/menu/multiplayer/mpservers
			document.getElementById('servers-btn').click();
		}
	});

	vm.modelChanged = function($event) {
		var src = event.srcElement;
		console.log("ok");
		console.log(src.value);
	}

	vm.connect = function() {
		logger.debug("Attempting to call connect to server.")
		document.getElementById('LoadingServer').style.display = 'block'
		bngApi.engineLua('MPCoreNetwork.connectToServer()');
	}

	connectScope = vm.connect;

	vm.refreshList = function() {
		logger.debug("Attempting to refresh server list.")
		bngApi.engineLua('MPCoreNetwork.getServers()');
	}

	vm.directConnect = function() {
		console.log('Clicked')
		var ip = document.getElementById('directip').value;
		var port = document.getElementById('directport').value;
		document.getElementById('LoadingServer').style.display = 'block';
		bngApi.engineLua(`MPCoreNetwork.connectToServer("${ip}","${port}")`);
	};

	vm.closePopup =  function() {
		document.getElementById('addCustomFav').style.display = 'none';
		document.getElementById('LoadingServer').style.display = 'none';
	};

	vm.showCustomServer = function() {
		document.getElementById('addCustomFav').style.display = 'block';
	};

	vm.addCustomServer = function() {
		var valid = (document.getElementById('customFavIP').value.length > 0) && (document.getElementById('customFavPort').value.length > 0) && !isNaN(document.getElementById('customFavPort').value)

		if (!valid) return;

		addFav(document.getElementById('customFavName').value,
					document.getElementById('customFavIP').value,
					document.getElementById('customFavPort').value);



		document.getElementById('addCustomFav').style.display = 'none';
		document.getElementById('customFavName').value = '';
		document.getElementById('customFavIP').value = '';
		document.getElementById('customFavPort').value = '';
		refreshList();
	};

	vm.stateName = $state.current.name;
	bngApi.engineLua('settings.requestState()');
	$scope.$on('$stateChangeSuccess', function (event, toState, toParams, fromState, fromParams) {
		vm.stateName = toState.name;
	});
	//bngApi.engineLua('core_gamestate.requestGameState();');   // if this isnt called the gamestate in menu doesnt update correctly.

	vm.pasteClipboardToDirectIP = function() {
		bngApi.engineLua('getClipboard()', function (str) {
			$scope.$evalAsync(() =>  {
				if(!str.includes('.')) return;

				var split = str.split(':');

				document.getElementById('directip').value = split[0];
				if (split.length==2) document.getElementById('directport').value = split[1];
			});
		});

	};

	//vm.displayServers = displayServerScope();

	$scope.$on('LoadingInfo', function (event, data) {
		if (document.getElementById('LoadingStatus').innerText != data.message) console.log(data.message)
		if (data.message == "done") document.getElementById('LoadingStatus').innerText = "Done";
		else document.getElementById('LoadingStatus').innerText = data.message;
	});

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
.controller('MultiplayerServersController', ['logger', '$scope', '$state', '$timeout', 'bngApi', function(logger, $scope, $state, $timeout, bngApi) {
	var vm = this;

	vm.check_isEmpty = false;
	vm.check_isNotEmpty = false;
	vm.check_isNotFull = false;
	vm.check_modSlider = false;
	vm.slider_maxModSize = 500; //should be almost a terabyte

	bngApiScope = bngApi;
	bngApi.engineLua('MPCoreNetwork.getServers()');
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

	vm.connect = function() {
		logger.debug("Attempting to call connect to server.")
		document.getElementById('LoadingServer').style.display = 'block'
		bngApi.engineLua('MPCoreNetwork.connectToServer()');
	}

	function select(row, table) {
		var oldInfoRow = document.getElementById('ServerInfoRow')
		if (oldInfoRow != null) {
			oldInfoRow.remove();
		}
		var table = document.getElementById("serversTable");
		deselect(table.selectedRow);
		row.classList.add("highlight");
		row.selected = true;
		table.selectedRow = row;
		//console.log(row)
		var id = row.getAttribute("data-id")
		if (id !== null) {
			var servers = JSON.parse(localStorage.getItem('servers'))
			var server = servers[id];
			highlightedServer = servers[id];
			//$(showDetailsScope(server)).insertAfter($(e.currentTarget)).show();
			var serverInfoRow = showDetailsScope(server);
			var serverInfoRow = document.createElement("tr");
			serverInfoRow.innerHTML = showDetailsScope(server);
			serverInfoRow.setAttribute("id", "ServerInfoRow");
			row.parentNode.insertBefore(serverInfoRow, row.nextSibling);

			var connectToServerButton = document.getElementById('serverconnect-button');
      var createClickHandler = function() {
        return function() {
					vm.connect()
        };
      };
      connectToServerButton.onclick = createClickHandler();

			var addServer2FavButton = document.getElementById('addFav-button');
      var createClickHandler2 = function() {
        return function() {
					addFav()
        };
      };
      addServer2FavButton.onclick = createClickHandler2();

			bngApi.engineLua(`MPCoreNetwork.setCurrentServer("${id}", "${server.ip}", "${server.port}", "${server.modlist}", "${server.strippedName}")`);
		}
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
		$scope.$apply(function () {
			$scope.steamData = data;
		});
	});

	$scope.$on('addServer', function (event, data) {
		var table = document.getElementById("servers-table");
		var row = table.insertRow(table.rows.length);
		row.insertCell(0).innerHTML = data.location;
		row.insertCell(1).innerHTML = data.description;
		row.insertCell(2).innerHTML = data.map;
		row.insertCell(3).innerHTML = data.players + "/" + data.maxPlayers;
		row.insertCell(4).innerHTML = data.pps;
		row.servData = data;
		row.onclick = selectRow;
	});

	vm.selectRow = function(row) {
		console.log("[2] ROW CLICKED, DATA: ")
		var table = document.getElementById("servers-table");
		select(row, table);
	};

	function receiveServers(data) {
		console.log(data)
		var serverArray = new Array();

		for (var i = 0; i < data.length; i++) {
			var v = data[i][Object.keys(data[i])[0]]
			if(v.cversion == launcherVersion){
				v.strippedName = stripCustomFormatting(v.sname);
				serverArray.push(v);
			}
		}

		//serverArray.sort((a, b) => a.strippedName.localeCompare(b.strippedName)) //dont sort servers by name because people didnt like it :C
		serverArray.sort((a, b) => (b.official - a.official))

		localStorage.setItem('servers', JSON.stringify(serverArray))

		displayServers()
	};

	function displayServers() {
		var table = document.getElementById("serversTableBody");
		table.innerHTML = "";

		var servers = JSON.parse(localStorage.getItem('servers'))
		for (var i = 0; i < servers.length; i++) {
			var filtered = servers[i].strippedName.toLowerCase().includes(document.getElementById("search").value.toLowerCase());

			if(filtered && vm.check_isEmpty && servers[i].players>0) filtered = false;
			if(filtered && vm.check_isNotEmpty && servers[i].players==0) filtered = false;
			if(filtered && vm.check_isNotFull && servers[i].players==servers[i].maxplayers) filtered = false;

			if(vm.check_modSlider && vm.slider_maxModSize*1048576 < servers[i].modstotalsize) filtered = false;

			if(filtered){
				var bgcolor = 'rgba(0,0,0,0)!important';
				if (servers[i].official) bgcolor = 'rgba(255,106,0,0.25)!important';

				var html = `
				<tr data-id="${i}">
					<td style="background-color:${bgcolor};">${servers[i].location}</td>
					<td style="background-color:${bgcolor};">${formatServerName(servers[i].sname)}</td>
					<td style="background-color:${bgcolor};">${SmoothMapName(servers[i].map)}</td>
					<td style="background-color:${bgcolor};">${servers[i].players}/${servers[i].maxplayers}</td>
					<td style="background-color:${bgcolor};">${servers[i].pps}</td>
				</tr>
				`;

				//document.getElementById('TEMPNODE').innerHTML = html;

				//console.log("APPENDING NOW?")
				//$('#serversTableBody').append(html);
				document.getElementById('serversTableBody').innerHTML += html
			}
		}

		///////////////////////////////////////////////////////////////////////////
		// This adds the on click handler for the dynamically created element.
		var table = document.getElementById("serversTableBody");
    var rows = table.getElementsByTagName("tr");
    for (i = 0; i < rows.length; i++) {
      var currentRow = table.rows[i];
      var createClickHandler =
      function(row) {
        return function() {
					//console.log(row.getAttribute('data-id'))
					vm.selectRow(row, row.getAttribute('data-id'))
        };
      };
      currentRow.onclick = createClickHandler(currentRow);
    }
	};

	vm.displayServers = displayServers;

	function formatServerDetailsRow ( d ) {
    // `d` is the original data object for the row
		console.log(d)
    return `
			<td colspan="5">
				<h1 style="padding-left:10px;">`+officialMark(d.official, true)+formatServerName(d.sname)+`</h1>
					<div class="row">
					<div class="col">
						<table class="description-table">
							<tr><td>Owner:</td><td>${d.owner}</td></tr>
							<tr><td>Map:</td><td>${SmoothMapName(d.map)}</td></tr>
							<tr><td>Players:</td><td>${d.players}/${d.maxplayers}</td></tr>
							<tr><td valign="top">Description:</td><td>${formatDescriptionName(d.sdesc)}</td></tr>
						</table>
					</div>
					<div class="col">
						<ul class="serverItemDetails">
							<li>PPS: ${d.pps}</li>
							<li>Mods: ${modCount(d.modlist)}</li>
							<li>Mod Names: ${modList(d.modlist)}</li>
							<li>Total Mods Size: ${formatBytes(d.modstotalsize) || "0"}</li>
						</ul>
					</div>
				</div>
				<div class="row" style="padding-left: 10px;">
					<md-button id="serverconnect-button" class="button md-button md-default-theme" ng-class="" ng-click="multiplayer.connect()" style="margin-left: 10px;">Connect</md-button>
					<md-button id="addFav-button"        class="button md-button md-default-theme" ng-class="" ng-click="addFav()"            style="margin-left: 10px;">Add Favorite</md-button>
				</div>
				<div class="row">
					<h4></h4>

					<p>${listPlayers(d.playerslist)}</p>
				</div>
	    </td>`;
	};

	serversScope = receiveServers;
	//selectRowScope = selectRow;
	displayServerScope = displayServers;
	showDetailsScope = formatServerDetailsRow;
}])
.controller('MultiplayerFavoritesController', ['logger', '$scope', '$state', '$timeout', 'bngApi', function(logger, $scope, $state, $timeout, bngApi) {
	var vm = this;

	vm.check_isEmpty = false;
	vm.check_isNotEmpty = false;
	vm.check_isNotFull = false;
	vm.check_modSlider = false;
	vm.slider_maxModSize = 500; //should be almost a terabyte

	bngApiScope = bngApi;
	bngApi.engineLua('MPCoreNetwork.getServers()');
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

	vm.connect = function() {
		logger.debug("Attempting to call connect to server.")
		document.getElementById('LoadingServer').style.display = 'block'
		bngApi.engineLua('MPCoreNetwork.connectToServer()');
	}

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
		var oldInfoRow = document.getElementById('ServerInfoRow')
		if (oldInfoRow != null) {
			oldInfoRow.remove();
		}
		var table = document.getElementById("serversTable");
		deselect(table.selectedRow);
		row.classList.add("highlight");
		row.selected = true;
		table.selectedRow = row;
		console.log(row)
		var id = row.getAttribute("data-id")
		console.log(id);
		if (id !== null) {
			var server = null;
			if(id.split(',')[0]>-1) {
				id = id.split(',')[0];
				server = JSON.parse(localStorage.getItem('servers'))[id];
			} else {
				id = id.split(',')[1];
				console.log(id);
				server = JSON.parse(localStorage.getItem('favorites'))[id];
				//server.strippedName = server.strippedName.replace('UNKNOWN ', '');
			}

			highlightedServer = server;

			var serverInfoRow = showDetailsScope(server);
			var serverInfoRow = document.createElement("tr");
			serverInfoRow.innerHTML = showDetailsScope(server);
			serverInfoRow.setAttribute("id", "ServerInfoRow");
			row.parentNode.insertBefore(serverInfoRow, row.nextSibling);

			var connectToServerButton = document.getElementById('serverconnect-button');
      var createClickHandler = function() {
        return function() {
					vm.connect()
        };
      };
      connectToServerButton.onclick = createClickHandler();

			var remServer2FavButton = document.getElementById('removeFav-button');
      var createClickHandler2 = function() {
        return function() {
					removeFav()
        };
      };
      remServer2FavButton.onclick = createClickHandler2();

			bngApi.engineLua(`MPCoreNetwork.setCurrentServer("${id}", "${server.ip}", "${server.port}", "${server.modlist}", "${server.strippedName}")`);
		}
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
		$scope.$apply(function () {
			$scope.steamData = data;
		});
	});

	$scope.$on('addServer', function (event, data) {
		var table = document.getElementById("servers-table");
		var row = table.insertRow(table.rows.length);
		row.insertCell(0).innerHTML = data.location;
		row.insertCell(1).innerHTML = data.description;
		row.insertCell(2).innerHTML = data.map;
		row.insertCell(3).innerHTML = data.players + "/" + data.maxPlayers;
		row.insertCell(4).innerHTML = data.pps;
		row.servData = data;
		row.onclick = selectRow;
	});

	//function selectRow(event) {
	vm.selectRow = function(row) {
		console.log("[1] ROW CLICKED, DATA: ")
		var table = document.getElementById("servers-table");
		select(row, table);
	};

	function receiveServers(data) {
		var serverArray = new Array();

		for (var i = 0; i < data.length; i++) {
			var v = data[i][Object.keys(data[i])[0]]
			if(v.cversion == launcherVersion){
				v.strippedName = stripCustomFormatting(v.sname);
				serverArray.push(v);
			}
		}

		serverArray.sort((a, b) => a.strippedName.localeCompare(b.strippedName))
		serverArray.sort((a, b) => (b.official - a.official))

		localStorage.setItem('servers', JSON.stringify(serverArray))
		console.log(serverArray)
		displayServers();
	};

	function displayServers() {
		var table = document.getElementById("serversTableBody");
		table.innerHTML = "";

		var allServers = JSON.parse(localStorage.getItem('servers'))
		for(var i in allServers)
			allServers[i].id = i;

		var favjson = JSON.parse(localStorage.getItem('favorites'))
		if (favjson == null) return;

		var servers = new Array();


		for(var i in favjson){
			favjson[i].sname  = "❓ " + favjson[i].sname;
			var foundServers = allServers.filter(s=>s.ip == favjson[i].ip).filter(s=>s.port == favjson[i].port)
			if (foundServers.length>0) {
				foundServers[0].favid = i;
				servers.push(foundServers[0]);
			} else {
				favjson[i].id = -1;
				favjson[i].favid = i;
				servers.push(favjson[i]);
			}
		}

		console.log(servers);

		for (var i = 0; i < servers.length; i++) {
			var filtered = servers[i].strippedName.toLowerCase().includes(document.getElementById("search").value.toLowerCase());
			if(filtered && vm.check_isEmpty && servers[i].players>0) filtered = false;
			if(filtered && vm.check_isNotEmpty && servers[i].players==0) filtered = false;
			if(filtered && vm.check_isNotFull && servers[i].players==servers[i].maxplayers) filtered = false;

			if(vm.check_modSlider && vm.slider_maxModSize*1048576 < servers[i].modstotalsize) filtered = false;

			if(filtered){
				var bgcolor = 'rgba(0,0,0,0)!important';
				if (servers[i].official) bgcolor = 'rgba(255,106,0,0.25)!important';

				//console.log(servers[i].id);
				//console.log(servers[i].favid);

				var html = `
				<tr data-id="${servers[i].id},${servers[i].favid}" ng-onclick(selectRow(e)>
				<td style="background-color:${bgcolor};">${servers[i].location}</td>
				<td style="background-color:${bgcolor};">${formatServerName(servers[i].sname)}</td>
				<td style="background-color:${bgcolor};">${SmoothMapName(servers[i].map)}</td>
				<td style="background-color:${bgcolor};">${servers[i].players}/${servers[i].maxplayers}</td>
				<td style="background-color:${bgcolor};">${servers[i].pps}</td>
				</tr>
				`;
				//$('#serversTableBody').append(html);
				document.getElementById('serversTableBody').innerHTML += html
			}
		}

		///////////////////////////////////////////////////////////////////////////
		// This adds the on click handler for the dynamically created element.
		var table = document.getElementById("serversTableBody");
    var rows = table.getElementsByTagName("tr");
    for (i = 0; i < rows.length; i++) {
      var currentRow = table.rows[i];
      var createClickHandler =
      function(row) {
        return function() {
					//console.log(row.getAttribute('data-id'))
					vm.selectRow(row, row.getAttribute('data-id'))
        };
      };
      currentRow.onclick = createClickHandler(currentRow);
    }
	};

	vm.displayServers = displayServers;

	function setClientVersion(v) {
		launcherVersion = v;
	};
	function formatServerDetailsRow ( d ) {
    // `d` is the original data object for the row
		console.log(d)
    return `
			<td colspan="5">
				<h1 style="padding-left:10px;">`+officialMark(d.official, true)+formatServerName(d.sname)+`</h1>
					<div class="row">
					<div class="col">
						<table class="description-table">
							<tr><td>Owner:</td><td>${d.owner}</td></tr>
							<tr><td>Map:</td><td>${SmoothMapName(d.map)}</td></tr>
							<tr><td>Players:</td><td>${d.players}/${d.maxplayers}</td></tr>
							<tr><td valign="top">Description:</td><td>${formatDescriptionName(d.sdesc)}</td></tr>
						</table>
					</div>
					<div class="col">
						<ul class="serverItemDetails">
							<li>PPS: ${d.pps}</li>
							<li>Mods: ${modCount(d.modlist)}</li>
							<li>Mod Names: ${modList(d.modlist)}</li>
							<li>Total Mods Size: ${formatBytes(d.modstotalsize) || "0"}</li>
						</ul>
					</div>
				</div>
				<div class="row" style="padding-left: 10px;">
					<md-button id="serverconnect-button" class="button md-button md-default-theme" ng-class="" ng-click="multiplayer.connect()" style="margin-left: 10px;">Connect</md-button>
					<md-button id="removeFav-button"     class="button md-button md-default-theme" ng-class="" ng-click="removeFav()"           style="margin-left: 10px;">Remove Favorite</md-button>
				</div>
				<div class="row">
					<h4></h4>

					<p>${listPlayers(d.playerslist)}</p>
				</div>
	    </td>`;
	};

	//selectRowScope = selectRow;
	serversScope = receiveServers;
	setVersion = setClientVersion;
	displayServerScope = displayServers;
	showDetailsScope = formatServerDetailsRow;
}])


.controller('MultiplayerDirectController', ['logger', '$scope', '$state', '$timeout', 'bngApi',
function(logger, $scope, $state, $timeout, bngApi) {
	var vm = this;
	bngApiScope = bngApi;

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


function receiveServers(data) {
	serversScope(data);
}

function setClientVersion(v) {
	launcherVersion = v;
};

function displayServers() {
	displayServerScope();
}

function toTitleCase(str) {
	return str.replace(/\w\S*/g, function(txt){
		return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
	});
}

function SmoothMapName(map) {
	if (map != "Any Map") {
		map = map.replace("/info.json","")
		map = map.split('/').pop().replace(/\s*/g,'')
		map = map.replace(/_/g," ")
		map = map.replace(/-/g," ")
		map = toTitleCase(map)
	}
	return map
}

function formatBytes(bytes = 0, decimals = 2) {
    if (bytes == 0 || bytes == undefined) return '0 Bytes';

    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];

    const i = Math.floor(Math.log(bytes) / Math.log(k));

    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}

var serverStyleMap = {
    '^0': 'color:#000000',
    '^1': 'color:#0000AA',
    '^2': 'color:#00AA00',
    '^3': 'color:#00AAAA',
    '^4': 'color:#AA0000',
    '^5': 'color:#AA00AA',
    '^6': 'color:#FFAA00',
    '^7': 'color:#AAAAAA',
    '^8': 'color:#555555',
    '^9': 'color:#5555FF',
    '^a': 'color:#55FF55',
    '^b': 'color:#55FFFF',
    '^c': 'color:#FF5555',
    '^d': 'color:#FF55FF',
    '^e': 'color:#FFFF55',
    '^f': 'color:#FFFFFF',
    '^l': 'font-weight:bold',
    '^m': 'text-decoration:line-through',
    '^n': 'text-decoration:underline',
    '^o': 'font-style:italic'
};
var descStyleMap = {
    '^0': 'color:#000000',
    '^1': 'color:#0000AA',
    '^2': 'color:#00AA00',
    '^3': 'color:#00AAAA',
    '^4': 'color:#AA0000',
    '^5': 'color:#AA00AA',
    '^6': 'color:#FFAA00',
    '^7': 'color:#AAAAAA',
    '^8': 'color:#555555',
    '^9': 'color:#5555FF',
    '^a': 'color:#55FF55',
    '^b': 'color:#55FFFF',
    '^c': 'color:#FF5555',
    '^d': 'color:#FF55FF',
    '^e': 'color:#FFFF55',
    '^f': 'color:#FFFFFF',
    '^l': 'font-weight:bold',
    '^m': 'text-decoration:line-through',
    '^n': 'text-decoration:underline',
    '^o': 'font-style:italic',
    '^p': 'display:block'
};
function applyDescCode(string, codes) {
    var elem = document.createElement('span');
    string = string.replace(/\x00*/g, '');
    for(var i = 0, len = codes.length; i < len; i++) {
        elem.style.cssText += descStyleMap[codes[i]] + ';';
    }
    elem.innerHTML = string;
    return elem;
}
function formatDescriptionName(string) {
    var codes = string.match(/\^.{1}/g) || [],
        indexes = [],
        apply = [],
        tmpStr,
        deltaIndex,
        noCode,
        final = document.createDocumentFragment(),
        i;
    for(i = 0, len = codes.length; i < len; i++) {
        indexes.push( string.indexOf(codes[i]) );
        string = string.replace(codes[i], '\x00\x00');
    }
    if(indexes[0] !== 0) {
        final.appendChild( applyDescCode( string.substring(0, indexes[0]), [] ) );
    }
    for(i = 0; i < len; i++) {
    	indexDelta = indexes[i + 1] - indexes[i];
        if(indexDelta === 2) {
            while(indexDelta === 2) {
                apply.push ( codes[i] );
                i++;
                indexDelta = indexes[i + 1] - indexes[i];
            }
            apply.push ( codes[i] );
        } else {
            apply.push( codes[i] );
        }
        if( apply.lastIndexOf('^r') > -1) {
            apply = apply.slice( apply.lastIndexOf('^r') + 1 );
        }
        tmpStr = string.substring( indexes[i], indexes[i + 1] );
        final.appendChild( applyDescCode(tmpStr, apply) );
    }
		//$('#TEMPAREA').html(final);
		document.getElementById('TEMPAREA').innerHTML = final;
		var innerHTML = [...final.childNodes].map( n=> n.outerHTML ).join('\n')
		//console.log(innerHTML)
    return innerHTML; //$('#TEMPAREA').html();
}
function applyCode(string, codes) {
    var elem = document.createElement('span');
    string = string.replace(/\x00*/g, '');
    for(var i = 0, len = codes.length; i < len; i++) {
        elem.style.cssText += serverStyleMap[codes[i]] + ';';
    }
    elem.innerHTML = string;
    return elem;
}
function formatServerName(string) {
    var codes = string.match(/\^.{1}/g) || [],
        indexes = [],
        apply = [],
        tmpStr,
        deltaIndex,
        noCode,
        final = document.createDocumentFragment(),
        i;
    for(i = 0, len = codes.length; i < len; i++) {
        indexes.push( string.indexOf(codes[i]) );
        string = string.replace(codes[i], '\x00\x00');
    }
    if(indexes[0] !== 0) {
        final.appendChild( applyCode( string.substring(0, indexes[0]), [] ) );
    }
    for(i = 0; i < len; i++) {
    	indexDelta = indexes[i + 1] - indexes[i];
        if(indexDelta === 2) {
            while(indexDelta === 2) {
                apply.push ( codes[i] );
                i++;
                indexDelta = indexes[i + 1] - indexes[i];
            }
            apply.push ( codes[i] );
        } else {
            apply.push( codes[i] );
        }
        if( apply.lastIndexOf('^r') > -1) {
            apply = apply.slice( apply.lastIndexOf('^r') + 1 );
        }
        tmpStr = string.substring( indexes[i], indexes[i + 1] );
        final.appendChild( applyCode(tmpStr, apply) );
    }
		//$('#TEMPAREA').html(final);
		document.getElementById('TEMPAREA').innerHTML = final;
		var innerHTML = [...final.childNodes].map( n=> n.outerHTML ).join('\n')
		//console.log(innerHTML)
    return innerHTML; //$('#TEMPAREA').html();
}
function officialMark(o, s) {
	if (o) {
		if (s) {
			return '<img src="./modules/multiplayer/beammp.png" alt="" style="height: 23px; padding-right: 10px;"> [Official Server]  '
		} else {
			return '<img src="./modules/multiplayer/beammp.png" alt="" style="height: 21px; padding-right: 10px; padding-left: 10px; position: absolute;">'
		}

	} else {
		return ""
	}
}
function modCount(s) {
	if(s.length==0) return 0;
	return s.split(";").length-1;
}
function modList(s) {
	var re = new RegExp("Resources/Client/", 'g');
	s = s.replace(re, '');
	var re = new RegExp(".zip", 'g');
	s = s.replace(re, '');
	var re = new RegExp(";", 'g');
	s = s.replace(re, ', ');
	s = s.substring(0, s.length -2);
	return s
}
function returnDefault(data, type) {
	if (data == undefined || data == null) {
		switch (type) {
			case "Number":
				return 0
			case "String":
				return "Not set"
		}
	}
	else return data;
}
function listPlayers(s) {
	if (s != undefined || s != "") {
		var re = new RegExp(";", 'g');
		s = s.replace(re, ', ');
		s = s.substring(0, s.length -2);
		return "Current players: " + s
	} else {
		return "No players..."
	}
}



/*window.onload = function() {
	if (window.jQuery) {
		// jQuery is loaded
		//alert("Yeah!");
		//console.log("DT Setup?")
		var table = $('#serversTable').DataTable({
			responsive: true,
			"columns": [
				{
					"className": 'details-control',
					"orderable": true,
					"data": null,
					"defaultContent": ''
				},
				{ "data": "location" },
				{ "data": "description" },
				{ "data": "map" },
				{ "data": "players" },
				{ "data": "pps" }
			],
			"order": [[1, 'asc']]
		});

		// Event listener for opening and closing details
		$(document).on('click', '#serversTableBody > tr', function(e) {
			$("#ServerInfoRow").remove();
			var row = table.row(e);
			if ( row.child.isShown() ) { // This row is already open - close it
				row.child.hide();
				e.removeClass('shown');
			} else { // Open this row
				var id = $(e.currentTarget).attr("data-id")
				if (id !== undefined) {
					var server;
					if(id.split(',')[0]>-1) {
						id = id.split(',')[0];
						server = JSON.parse(localStorage.getItem('servers'))[id];
					} else {
						id = id.split(',')[1];
						server = JSON.parse(localStorage.getItem('favorites'))[id];
					}

					$(showDetailsScope(server)).insertAfter($(e.currentTarget)).show();
					(e.currentTarget).classList.add('shown');
				}
			}
		});

		// Event listener for adding selected server to favs
		$(document).on('click', '#addFav-button', function(e) {
			addFav();
		});
		$(document).on('click', '#removeFav-button', function(e) {
			removeFav();
		});


		// Event listener for connecting to a selected server
		$(document).on('click', '#serverconnect-button', function(e) {
			connectScope();
		});
	} else {
		//alert("jQuery is not loaded");
	}
}*/

//$(document).on('click', '#serversTableBody > tr', function(e) {
	//selectRowScope(e.originalEvent)
//});


var serverStyleArray = [
    "^0",
    "^1",
    "^2",
    "^3",
    "^4",
    "^5",
    "^6",
    "^7",
    "^8",
    "^9",
    "^a",
    "^b",
    "^c",
    "^d",
    "^e",
    "^f",
    "^l",
    "^m",
    "^n",
    "^o",
    "^r",
    "^p"
];

function stripCustomFormatting(name){
	for (var i = 0; i < serverStyleArray.length; i++){
		while (name.includes(serverStyleArray[i])){
			name = name.replace(serverStyleArray[i], "");
		}
	}
	return name;
}

function removeFav() {
	var favjson = JSON.parse(localStorage.getItem('favorites'));
	var favArray = new Array();

	if(favjson != null)
		for(var i in favjson)
			if(favArray.filter(s=>s.ip == favjson[i].ip).filter(s=>s.port == favjson[i].port).length==0)
				favArray.push(favjson[i]);

	for(var i in favArray)
		if(favArray[i].ip == highlightedServer.ip
		&& favArray[i].port == highlightedServer.port
		&& favArray[i].sname == highlightedServer.sname)
			favArray.splice(i, 1);


	console.log(highlightedServer);

	localStorage.setItem('favorites', JSON.stringify(favArray))
	bngApiScope.engineLua('MPCoreNetwork.getServers()');
}

function addFav(fname, fip, fport) {
	var serverToAdd = new Object();
	if (fname !== undefined) {
		serverToAdd.ip = fip            ,
		serverToAdd.port = fport        ,
		serverToAdd.sdesc = fname       ,
		serverToAdd.sname = fname       ,
		serverToAdd.strippedName = fname,

		serverToAdd.cversion = "-1"     ,
		serverToAdd.location = "N/A"    ,
		serverToAdd.map = "Unknown"     ,
		serverToAdd.modlist = ""        ,
		serverToAdd.modstotal = "N/A"   ,
		serverToAdd.modstotalsize = 0   ,
		serverToAdd.official = 0        ,
		serverToAdd.owner = ""          ,
		serverToAdd.players = "N"       ,
		serverToAdd.maxplayers = "A"    ,
		serverToAdd.playerslist = ""    ,
		serverToAdd.pps = "N/A"         ,
		serverToAdd.private = false     ,
		serverToAdd.time = 0            ,
		serverToAdd.version = "-1"      ,
		serverToAdd.id = -1
																			}
														else
										{
		serverToAdd = highlightedServer;
		serverToAdd.players  = 0;
		serverToAdd.maxplayers  = 0;
		serverToAdd.time = 0;
		serverToAdd.pps = 0;
		serverToAdd.id = -1;
	}



	var favjson = JSON.parse(localStorage.getItem('favorites'));
	var favArray = new Array();

	console.log(favjson);

	if(favjson != null)
		for(var i in favjson)
			if(favArray.filter(s=>s.ip == favjson[i].ip).filter(s=>s.port == favjson[i].port).length==0)
				favArray.push(favjson[i]);

	if(favArray.filter(s=>s.ip == serverToAdd.ip).filter(s=>s.port == serverToAdd.port).length==0)
		favArray.push(serverToAdd);

	//favArray = [...new Set(favArray)];

	favArray.sort((a, b) => (a.official > b.official) ? -1 : 1)

	console.log(serverToAdd);
	console.log(favArray);

	localStorage.setItem('favorites', JSON.stringify(favArray))
	bngApiScope.engineLua('MPCoreNetwork.getServers()');
}

function findPlayer(pname, join=false){
	pname = pname.toLowerCase();
	var servers = JSON.parse(localStorage.getItem('servers'))
	for (var id = 0; id < servers.length; id++) {
		var server = servers[id];
		if (server.playerslist !== undefined){
			if (server.playerslist.toLowerCase().includes(pname)){
				var names = server.playerslist.split(';').filter(function (item) { return item.toLowerCase().includes(pname); });
				console.log("found player '" +names[0]+ "'\n on server ID:" +id+ "\n Title: " +stripCustomFormatting(server.sname));
				if(join){
					bngApiScope.engineLua(`MPCoreNetwork.setCurrentServer("${id}", "${server.ip}", "${server.port}", "${server.modlist}", "${server.sname}")`);
					if (document.getElementById('LoadingServer') !== null) document.getElementById('LoadingServer').style.display = 'block';
					bngApiScope.engineLua('MPCoreNetwork.connectToServer()');
				}
				return id;
			}
		}
	}
	console.log("player "+ pname+" not found.");
	return -1;
}
