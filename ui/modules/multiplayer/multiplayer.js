var serversScope, selectRowScope, connectScope;
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
		bngApi.engineLua('CoreNetwork.connectToServer()');
	}

	connectScope = vm.connect;

	vm.refresh = function() {
		logger.debug("Attempting to refresh server list.")
		bngApi.engineLua('CoreNetwork.getServers()');
	}

	vm.directConnect = function() {
		console.log('Clicked')
		var ip = document.getElementById('directip').value;
		var port = document.getElementById('directport').value;
		document.getElementById('LoadingServer').style.display = 'block';
		bngApi.engineLua(`CoreNetwork.connectToServer("${ip}","${port}")`);
	};

	vm.stateName = $state.current.name;
	bngApi.engineLua('settings.requestState()');
	$scope.$on('$stateChangeSuccess', function (event, toState, toParams, fromState, fromParams) {
		vm.stateName = toState.name;
	});
	//bngApi.engineLua('core_gamestate.requestGameState();');   // if this isnt called the gamestate in menu doesnt update correctly.

	$scope.$on('LoadingInfo', function (event, data) {
		console.log(data.message)
		document.getElementById('LoadingStatus').innerText = data.message;
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
	bngApi.engineLua('CoreNetwork.getServers()');
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
		var table = document.getElementById("serversTable");
		deselect(table.selectedRow);
		row.classList.add("highlight");
		row.selected = true;
		table.selectedRow = row;
		//console.log(row)
		var id = row.getAttribute('data-id')
		//console.log(id)
		var servers = JSON.parse(localStorage.getItem('servers'))
		for (var i = 0; i < servers.length; i++) {
			if (servers[i].hasOwnProperty(id)) {
				//console.log(servers[i][id])
				var server = servers[i][id];
				bngApi.engineLua(`CoreNetwork.setServer("${id}", "${server.ip}", "${server.port}", "${server.modlist}")`);
			}
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

	function selectRow(event) {
		var table = document.getElementById("servers-table");
		var src = event.srcElement;
		var row = src.closest('tr');
		select(row, table);
	};

	function receiveServers(data) {
		console.log(data)
		localStorage.setItem('servers', JSON.stringify(data))
		var table = document.getElementById("serversTableBody");
		table.innerHTML = "";
		for (var i = 0; i < data.length; i++) {
			var v = data[i][Object.keys(data[i])[0]]
			var ver = v.version.substr(0, v.version.indexOf('.'));
			if (ver == "0") {
				//var row = table.rows[i];
				var servData = {};
				servData.ip = v.ip;
				servData.map = SmoothMapName(v.map);
				servData.players = v.players;
				servData.location = v.location;
				servData.name = formatServerName(v.sname);
				servData.maxPlayers = v.maxplayers;
				servData.ping = v.pps;
				servData.color = 'rgba(0,0,0,0)!important';
				if (v.official) servData.color = 'rgba(255,106,0,0.25)!important';
				var html = `
				<tr data-id="${Object.keys(data[i])[0]}" ng-onclick(selectRow(e)>
				<td style="background-color:${servData.color};">${servData.location}</td>
				<td style="background-color:${servData.color};">${servData.name}</td>
				<td style="background-color:${servData.color};">${servData.map}</td>
				<td style="background-color:${servData.color};">${servData.players}/${servData.maxPlayers}</td>
				<td style="background-color:${servData.color};">${servData.ping}</td>
				</tr>
				`;
				/*var row = table.insertRow(table.rows.length);
				row.setAttribute('data-id', Object.keys(data[i])[0]);
				row.insertCell(0).innerHTML = servData.location;
				row.insertCell(1).innerHTML = servData.name;
				row.insertCell(2).innerHTML = servData.map;
				row.insertCell(3).innerHTML = servData.players + "/" + servData.maxPlayers;
				row.insertCell(4).innerHTML = servData.ping;*/
				$('#serversTableBody').append(html);
				//row.servData = servData;
				//row.onclick = selectRow;
			}
		}
	};

	selectRowScope = selectRow
	serversScope = receiveServers;
}])
.controller('MultiplayerFavoritesController', ['logger', '$scope', '$state', '$timeout', 'bngApi', function(logger, $scope, $state, $timeout, bngApi) {
	var vm = this;
	//bngApi.engineLua('CoreNetwork.getServers()');
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
		var table = document.getElementById("serversTable");
		deselect(table.selectedRow);
		row.classList.add("highlight");
		row.selected = true;
		table.selectedRow = row;
		//console.log(row)
		var id = row.getAttribute('data-id')
		//console.log(id)
		var servers = JSON.parse(localStorage.getItem('servers'))
		for (var i = 0; i < servers.length; i++) {
			if (servers[i].hasOwnProperty(id)) {
				//console.log(servers[i][id])
				var server = servers[i][id];
				bngApi.engineLua(`CoreNetwork.setServer("${id}", "${server.ip}", "${server.port}", "${server.modlist}")`);
			}
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

	function selectRow(event) {
		var table = document.getElementById("servers-table");
		var src = event.srcElement;
		var row = src.closest('tr');
		select(row, table);
	};

	function receiveServers(data) {
		console.log(data)
		localStorage.setItem('servers', JSON.stringify(data))
		var table = document.getElementById("serversTableBody");
		table.innerHTML = "";
		for (var i = 0; i < data.length; i++) {
			var v = data[i][Object.keys(data[i])[0]]
			var ver = v.version.substr(0, v.version.indexOf('.'));
			if (ver == "0") {
				//var row = table.rows[i];
				var servData = {};
				servData.ip = v.ip;
				servData.map = SmoothMapName(v.map);
				servData.players = v.players;
				servData.location = v.location;
				servData.name = formatServerName(v.sname);
				servData.maxPlayers = v.maxplayers;
				servData.ping = v.pps;
				servData.color = 'rgba(0,0,0,0)!important';
				if (v.official) servData.color = 'rgba(255,106,0,0.25)!important';
				var html = `
				<tr data-id="${Object.keys(data[i])[0]}" ng-onclick(selectRow(e)>
				<td style="background-color:${servData.color};">${servData.location}${officialMark(v.official, false)}</td>
				<td style="background-color:${servData.color};">${servData.name}</td>
				<td style="background-color:${servData.color};">${servData.map}</td>
				<td style="background-color:${servData.color};">${servData.players}/${servData.maxPlayers}</td>
				<td style="background-color:${servData.color};">${servData.ping}</td>
				</tr>
				`;
				/*var row = table.insertRow(table.rows.length);
				row.setAttribute('data-id', Object.keys(data[i])[0]);
				row.insertCell(0).innerHTML = servData.location;
				row.insertCell(1).innerHTML = servData.name;
				row.insertCell(2).innerHTML = servData.map;
				row.insertCell(3).innerHTML = servData.players + "/" + servData.maxPlayers;
				row.insertCell(4).innerHTML = servData.ping;*/
				$('#serversTableBody').append(html);
				//row.servData = servData;
				//row.onclick = selectRow;
			}
		}
	};

	selectRowScope = selectRow
	serversScope = receiveServers;
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


function receiveServers(data) {
	serversScope(data);
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

var styleMap = {
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
};
function applyCode(string, codes) {
    var elem = document.createElement('span');
    string = string.replace(/\x00*/g, '');
    for(var i = 0, len = codes.length; i < len; i++) {
        elem.style.cssText += styleMap[codes[i]] + ';';
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
		$('#TEMPAREA').html(final);
    return $('#TEMPAREA').html();;
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
	if (data == undefined) {
		switch (type) {
			case "Number":
				return 0
			case "String":
				return "Not set"
		}
	}
}
function listPlayers(s) {
	if (s != undefined) {
		var re = new RegExp(";", 'g');
		s = s.replace(re, ', ');
		s = s.substring(0, s.length -2);
		return s
	} else {
		return "No players..."
	}
}

function format ( d ) {
    // `d` is the original data object for the row
		console.log(d)
    return `
		<tr id="ServerInfoRow">
			<td colspan="5">
				<h1 style="padding-left:10px;">`+officialMark(d.official, true)+formatServerName(d.sname)+`</h1>
	      <div class="row">
					<div class="col">
						<ul class="serverItemDetails">
							<li>Description: ${returnDefault(d.sdesc, "String")}</li>
							<li>Players: ${d.players}/${d.maxplayers}</li>
							<li>Owner: ${d.owner}</li>
								<li>Map: ${SmoothMapName(d.map)}</li>
						</ul>
					</div>
					<div class="col">
						<ul class="serverItemDetails">
							<li>PPS: ${d.pps}</li>
							<li>Mods: ${returnDefault(d.total, "Number")}</li>
							<li>Mod Names: ${modList(d.modlist)}</li>
							<li>Total Mods Size: ${formatBytes(d.modstotalsize) || "0"}</li>
						</ul>
					</div>
				</div>
				<div class="row" style="padding-left: 10px;">
					<md-button id="addFav-button" class="button md-button md-default-theme" ng-class="" ng-click="multiplayer.addFav()" style="margin-left: 10px;">Add Favorite</md-button>
					<md-button id="serverconnect-button" class="button md-button md-default-theme" ng-class="" ng-click="multiplayer.connect()" style="margin-left: 10px;">Connect</md-button>
				</div>
				<div class="row">
					<h4></h4>

					<p>${listPlayers(d.playerslist)}</p>
				</div>
	    </td>
		</tr>`;
}

window.onload = function() {
	if (window.jQuery) {
		// jQuery is loaded
		//alert("Yeah!");
		console.log("DT Setup?")
		var table = $('#serversTable').DataTable({
			responsive: true,
			"columns": [
				{
					"className":      'details-control',
					"orderable":      true,
					"data":           null,
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

		// Add event listener for opening and closing details
    $(document).on('click', '#serversTableBody > tr', function(e) {
			$("#ServerInfoRow").remove();
      var tr = e;//$(this).closest('tr');
      var row = table.row( tr );
      if ( row.child.isShown() ) {
        // This row is already open - close it
        row.child.hide();
        tr.removeClass('shown');
      } else {
        // Open this row
				var id = $(e.currentTarget).attr("data-id")
				console.log(id)
				var servers = JSON.parse(localStorage.getItem('servers'))
				for (var i = 0; i < servers.length; i++) {
					if (servers[i].hasOwnProperty(id)) {
						//console.log(servers[i][id])
						var server = servers[i][id];
						//$(e.currentTarget).append( format(server) ).show();
						$(format(server)).insertAfter($(e.currentTarget)).show();
	           $(e.currentTarget).addClass('shown');
					}
				}
      }
  	});

		$(document).on('click', '#addFav-button', function(e) {
			console.log(e)
		});

		// Add event listener for opening and closing details
    $(document).on('click', '#serverconnect-button', function(e) {
			connectScope();
		});
	} else {
		// jQuery is not loaded
		//alert("Doesn't Work");
	}
}

$(document).on('click', '#serversTableBody > tr', function(e) {
	selectRowScope(e.originalEvent)
});
