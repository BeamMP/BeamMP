var bngApiScope;
var setVersion;
var highlightedServer;
var launcherVersion = "";
var servers = [];



angular.module('beamng.stuff')
/* //////////////////////////////////////////////////////////////////////////////////////////////
*	MAIN CONTROLLER
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerController', ['logger', '$scope', '$state', '$timeout', 'bngApi', function(logger, $scope, $state, $timeout, bngApi) {
	var vm = this;
	bngApiScope = bngApi;

	// Display the servers list page once the page is loaded
	$scope.$on('$stateChangeSuccess', function (event, toState, toParams, fromState, fromParams) {
		if (toState.url == "/multiplayer") {
			// local://local/ui/#/menu/multiplayer/mpservers
			document.getElementById('servers-btn').click();
		}
	});
	
	this.receiveServers = receiveServers;

	vm.switchToLogin = function() {
		document.getElementById('loginHeader').textContent = 'Login with your BeamMP account.';
		var x = document.getElementsByClassName('LOGINERRORFIELD')
		for(var i = 0; i < x.length; i++){
			x[i].textContent='';    // Change the content
		}
		document.getElementById('GuestContainer').style.display = 'none'
		document.getElementById('LoginContainer').style.display = 'block'
	}

	vm.login = function() {
		var u = document.getElementById('loginUsername').value.trim();
		var p = document.getElementById('loginPassword').value.trim();
		
		if (u == "" || p == ""){
			document.getElementById('loginHeader').textContent = 'Missing credentials';
			return;
		}
		
		document.getElementById('loginUsername').value = '';
		document.getElementById('loginPassword').value = '';
		var d = {
			username: u,
			password: p
		}

		document.getElementById('loginHeader').textContent = 'Attempting to log in...';

		bngApi.engineLua(`MPCoreNetwork.login('${JSON.stringify(d)}')`);
	}

	vm.logout = function() {
		document.getElementById('MultiplayerLoginBody').style.display = 'block';
		vm.switchToLogin();
		bngApi.engineLua(`MPCoreNetwork.logout()`);
	}

	vm.switchToGuest = function() {
		var x = document.getElementsByClassName('LOGINERRORFIELD')
		for(var i = 0; i < x.length; i++){
			x[i].textContent='';    // Change the content
		}
		document.getElementById('LoginContainer').style.display = 'none'
		document.getElementById('GuestContainer').style.display = 'block'
	}

	vm.guestLogin = function() {
		var u = document.getElementById('guestUsername').value;
		u = u.replace(/[^\x20-\x7A]|[\x21-\x2F]|[\x3A-\x40]|[\x5B-\x60]/g, "").substring(0, 20).trim();
		document.getElementById('guestUsername').value = '';
		var d = {
			guest: u
		}
		bngApi.engineLua(`MPCoreNetwork.login('${JSON.stringify(d)}')`);
	}

	$scope.$on('LoginContainerController', function (event, data) {
		var x = document.getElementsByClassName('LOGINERRORFIELD')
		for(var i = 0; i < x.length; i++){
			x[i].textContent='';    // Change the content
		}
		if (data.hide) { //login successful
			document.getElementById('MultiplayerLoginBody').style.display = 'none'
			
			if (data.message !== undefined) {
				console.log(data.message);
				localStorage.setItem('welcomeMessage',data.message.replace('Authentication Successful. ',''));
				document.getElementById('topRightStatus').textContent = data.message;
			} else {
				document.getElementById('topRightStatus').textContent = localStorage.getItem('welcomeMessage')||"";
			}
		} else {
			document.getElementById('MultiplayerLoginBody').style.display = 'block'
		}
	});

	$scope.$on('LoginError', function (event, data) {
		var x = document.getElementsByClassName('LOGINERRORFIELD')
		for(var i = 0; i < x.length; i++){
			x[i].textContent=data.message;    // Change the content
		}
	});

	$scope.$on('addRecent', function (event, data) {
		console.log("recent received from lua");
		addRecent(data);
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

	vm.refreshList = function() {
		logger.debug("Attempting to refresh server list.")
		bngApi.engineLua('MPCoreNetwork.getServers()');
	}
	
	vm.clearRecents = function() {
		localStorage.removeItem("recent");
		vm.refreshList();
	}

	vm.directConnect = function() {
		console.log('Clicked')
		var ip = document.getElementById('directip').value;
		var port = document.getElementById('directport').value;
		document.getElementById('LoadingServer').style.display = 'block';
		//addRecent({name:ip, ip:ip, port:port});
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
		vm.refreshList();
	};

	vm.stateName = $state.current.name;
	bngApi.engineLua('settings.requestState()');
	$scope.$on('$stateChangeSuccess', function (event, toState, toParams, fromState, fromParams) {
		vm.stateName = toState.name;
	});

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



/* //////////////////////////////////////////////////////////////////////////////////////////////
*	SERVERS TAB
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerServersController', ['logger', '$scope', '$state', '$timeout', 'bngApi', function(logger, $scope, $state, $timeout, bngApi) {

	var vm = this;
	vm.check_isEmpty = false;
	vm.check_isNotEmpty = false;
	vm.check_isNotFull = false;
	vm.check_modSlider = false;
	vm.slider_maxModSize = 500; //should be almost a terabyte
	vm.select_map = "Any"

	// Request for the servers
	bngApi.engineLua('MPCoreNetwork.getServers()');

	// Go back to the main menu on exit
	vm.exit = function ($event) {
		if ($event) logger.debug('[MultiplayerServersController] exiting by keypress event %o', $event);
		$state.go('menu.mainmenu');
	};

	// Page loading timeout
	var timeOut = $timeout(function() {
		if (vm.loadingPage === true) {
			vm.loadTimeout = true;
		}
	}, 10000);

	// Called when the page is left
	$scope.$on('$destroy', function () {
		$timeout.cancel(timeOut);
		logger.debug('[MultiplayerServersController] destroyed.');
	});
	
	this.createTableRow = createTableRow
	vm.displayServers = function() {
		// Clear the servers table
		var serversTable = document.getElementById("serversTableBody");
		serversTable.innerHTML = "";
			
		var mapNames = new Array(); //["Any"];
		var html = "";
		for (var i = 0; i < servers.length; i++) {
			var shown = true;
			
			// Filter by search
			if (!servers[i].strippedName.toLowerCase().includes(document.getElementById("search").value.toLowerCase())) shown = false;
			
			// Filter by empty or full
			else if(vm.check_isEmpty && servers[i].players > 0) shown = false;
			else if(vm.check_isNotEmpty && servers[i].players == 0) shown = false;
			else if(vm.check_isNotFull && servers[i].players == servers[i].maxplayers) shown = false;
			
			// Filter by mod size
			else if(vm.check_modSlider && vm.slider_maxModSize * 1048576 < servers[i].modstotalsize) shown = false;

			// Filter by map
			else if(!mapNames.includes(SmoothMapName(servers[i].map))) mapNames.push(SmoothMapName(servers[i].map));
			else if(vm.select_map != "Any" && (vm.select_map != SmoothMapName(servers[i].map))) shown = false;
			
			// If the server passed the filter 
			if(shown) createTableRow(serversTable, i, 0, false, bngApi);
		}
		mapNames.sort(); // Sort the maps by name
		mapNames.unshift("Any"); // Set Any to the beginning
		vm.availableMaps = mapNames; // Set the list of available maps
	};
	
	$scope.$on('onServersReceived', function (event, data) {
		servers = receiveServers(JSON.parse(data));
		vm.displayServers(servers);
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
}])



/* //////////////////////////////////////////////////////////////////////////////////////////////
*	RECENT TAB
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerRecentController', ['logger', '$scope', '$state', '$timeout', 'bngApi', function(logger, $scope, $state, $timeout, bngApi) {
	var vm = this;

	vm.check_isEmpty = false;
	vm.check_isNotEmpty = false;
	vm.check_isNotFull = false;
	vm.check_modSlider = false;
	vm.slider_maxModSize = 500; //should be almost a terabyte
	vm.select_map = "Any"

	bngApi.engineLua('MPCoreNetwork.getServers()');

	// Called when getServers() answered
	$scope.$on('onServersReceived', function (event, data) {
		console.log("Servers received");
		servers = receiveServers(JSON.parse(data));
		vm.displayServers(servers);
	});

	// When controller is unloaded
	vm.exit = function ($event) {
		if ($event)
		logger.debug('[MultiplayerRecentController] exiting by keypress event %o', $event);
		$state.go('menu.mainmenu');
	};

	// Page loading timeout prevention
	var timeOut = $timeout(function() {
		if (vm.loadingPage === true) {
			vm.loadTimeout = true;
		}
	}, 10000);

	// When page is unloaded
	$scope.$on('$destroy', function () {
		$timeout.cancel(timeOut);
		logger.debug('[MultiplayerRecentController] destroyed.');
	});

	vm.connect = function() {
		logger.debug("Attempting to call connect to server.")
		document.getElementById('LoadingServer').style.display = 'block'
		bngApi.engineLua('MPCoreNetwork.connectToServer()');
	}

	// Add a server inside the table
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

	vm.displayServers = function(servers) {
		var table = document.getElementById("serversTableBody");
		table.innerHTML = "";

		for(var i in servers) servers[i].id = i;
		var recentjson = JSON.parse(localStorage.getItem('recent'))
		var recentServers = new Array();

		for(var i in recentjson){
			recentjson[i].sname      = "❓ " + recentjson[i].name;
			recentjson[i].location   = "N/A";
			recentjson[i].map        = "Unknown";
			recentjson[i].players    = "?";
			recentjson[i].maxplayers = "?";
			recentjson[i].pps        = "?";

			var foundServers = servers.filter(s=>s.ip == recentjson[i].ip).filter(s=>s.port == recentjson[i].port)
			if (foundServers.length > 0) {
				foundServers[0].recid = i;
				recentServers.push(foundServers[0]);
			} else {
				recentjson[i].id = -1;
				recentjson[i].recid = i;
				recentServers.push(recentjson[i]);
			}
		}

		if (recentServers.length == 0) {
			var bgcolor = 'rgba(0,0,0,0)!important';
			var html = `
			<tr>
			<td style="background-color:${bgcolor};"></td>
			<td style="background-color:${bgcolor};"><center>No recent servers found. Join a server for something to show up here!</center></td>
			<td style="background-color:${bgcolor};"></td>
			<td style="background-color:${bgcolor};"></td>
			<td style="background-color:${bgcolor};"></td>
			</tr>
			`;
			document.getElementById('serversTableBody').innerHTML += html
		}

		for (var i = 0; i < recentServers.length; i++) createTableRow(table, i, 1, false, bngApi, recentServers);
	};
}])



/* //////////////////////////////////////////////////////////////////////////////////////////////
*	FAVORITE TAB
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerFavoritesController', ['logger', '$scope', '$state', '$timeout', 'bngApi', function(logger, $scope, $state, $timeout, bngApi) {
	var vm = this;

	vm.check_isEmpty = false;
	vm.check_isNotEmpty = false;
	vm.check_isNotFull = false;
	vm.check_modSlider = false;
	vm.slider_maxModSize = 500; //should be almost a terabyte

	bngApi.engineLua('MPCoreNetwork.getServers()');

	vm.exit = function ($event) {
		if ($event)
		logger.debug('[MultiplayerServersController] exiting by keypress event %o', $event);
		$state.go('menu.mainmenu');
	};
	
	// Called when getServers() answered
	$scope.$on('onServersReceived', function (event, data) {
		console.log("Servers received");
		servers = receiveServers(JSON.parse(data));
		vm.displayServers(servers);
	});

	vm.connect = function() {
		logger.debug("Attempting to call connect to server.")
		document.getElementById('LoadingServer').style.display = 'block'
		bngApi.engineLua('MPCoreNetwork.connectToServer()');
	}

	var timeOut = $timeout(function() {
		if (vm.loadingPage === true) {
			vm.loadTimeout = true;
		}
	}, 10000);

	$scope.$on('$destroy', function () {
		$timeout.cancel(timeOut);
		logger.debug('[MultiplayerServersController] destroyed.');
	});

	function setColor(row) {
		// If odd gray / If even lightgray
		if (row.rowIndex % 2 == 0) row.style.backgroundColor = "white";
		else row.style.backgroundColor = "#f2f2f2";
	}

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

	vm.displayServers = function() {
		var table = document.getElementById("serversTableBody");
		table.innerHTML = "";
		for(var i in servers) servers[i].id = i;

		getFavs()

		var favjson = JSON.parse(localStorage.getItem('favorites'))

		if (favjson == null) return;
		var favoriteServers = new Array();
		for(var i in favjson){
			favjson[i].sname  = "❓ " + favjson[i].sname;
			var foundServers = servers.filter(s=>s.ip == favjson[i].ip).filter(s=>s.port == favjson[i].port)
			if (foundServers.length>0) {
				foundServers[0].favid = i;
				favoriteServers.push(foundServers[0]);
			} else {
				favjson[i].id = -1;
				favjson[i].favid = i;
				favoriteServers.push(favjson[i]);
			}
		}

		for (var i = 0; i < favoriteServers.length - 1; i++) {
			var filtered = favoriteServers[i].strippedName.toLowerCase().includes(document.getElementById("search").value.toLowerCase());
			if(filtered && vm.check_isEmpty && favoriteServers[i].players>0) filtered = false;
			if(filtered && vm.check_isNotEmpty && favoriteServers[i].players==0) filtered = false;
			if(filtered && vm.check_isNotFull && favoriteServers[i].players==favoriteServers[i].maxplayers) filtered = false;
			if(vm.check_modSlider && vm.slider_maxModSize*1048576 < favoriteServers[i].modstotalsize) filtered = false;
			if(filtered) createTableRow(table, i, 1, true, bngApi, favoriteServers);
		}
	};

	function setClientVersion(v) {
		launcherVersion = v;
	};

	setVersion = setClientVersion;
}])



/* //////////////////////////////////////////////////////////////////////////////////////////////
*	DIRECT CONNECT TAB
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerDirectController', ['logger', '$scope', '$state', '$timeout', 'bngApi',
function(logger, $scope, $state, $timeout, bngApi) {
	var vm = this;

	var timeOut = $timeout(function() {
		if (vm.loadingPage === true) {
			vm.loadTimeout = true;
		}
	}, 10000);

	vm.exit = function ($event) {
		if ($event)
		logger.debug('[MultiplayerDirectController] exiting by keypress event %o', $event);
		$state.go('menu.mainmenu');
	};

	$scope.$on('$destroy', function () {
		$timeout.cancel(timeOut);
		logger.debug('[MultiplayerDirectController] destroyed.');
	});
}]);

function setClientVersion(v) {
	launcherVersion = v;
};

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
	var modarray = s.split(';');
	//console.log(modarray);
	s = "";

	for (var i=0; i<modarray.length-1; i++){
		var modName = modarray[i].split('/').pop();
		modName = modName.replace(".zip","");
		s += modName;
		//if (i<modarray.length-2)
			s += ", ";
	}
	//console.log(s);
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
		if(favArray[i].ip == highlightedServer.ip && favArray[i].port == highlightedServer.port) {
			favArray.splice(i, 1);
		}

	localStorage.setItem('favorites', JSON.stringify(favArray))
	saveFavs();
	bngApiScope.engineLua('MPCoreNetwork.getServers()');
}

function getFavs(){
	bngApiScope.engineLua(`MPConfig.getFavorites()`, (data) => {
		if (data == null) return;
		localStorage.setItem("favorites", JSON.stringify(data));
	});
}

function saveFavs(){
	bngApiScope.engineLua(`MPConfig.setFavorites(`+JSON.stringify(localStorage.getItem("favorites"))+`)`);
}

function addRecent(recentstr){ // has to have name, ip, port
	var json = JSON.parse(recentstr);
	console.log(json);
	var recents = JSON.parse(localStorage.getItem("recent"));
	if (recents == null) recents = new Array();

	json.sname = json.name;

	json.location = "N/A"    ,
	json.map = "Unknown"     ,
	json.modlist = ""        ,
	json.modstotal = "N/A"   ,
	json.modstotalsize = 0   ,
	json.official = 0        ,
	json.owner = ""          ,
	json.players = "N"       ,
	json.maxplayers = "A"    ,
	json.playerslist = ""    ,
	json.pps = "N/A"         ,
	json.private = false     ,
	json.time = 0            ,
	json.version = "-1"      ,
	json.id = -1

	var arr = Array(1).fill(json);

	console.log(recents);

	for(var i=0; i < Math.min(recents.length, 9); i++)
		if(arr.filter(s=>s.ip == recents[i].ip).filter(s=>s.port == recents[i].port).length==0)
			arr.push(recents[i]);

	//recents = recents.slice(0, 10); //keep the last 10 entries
	localStorage.setItem("recent", JSON.stringify(arr));
}

function openExternalLink(url){
	bngApiScope.engineLua(`openWebBrowser("`+url+`")`);
}

function openForumLink(){
	openExternalLink("http://forum.beammp.com");
}

function getServerInfoHTML(d, fav) {
		// `d` is the original data object for the row
		var favButton;
		if (fav) favButton = `<md-button id="removeFav-button"     class="button md-button md-default-theme" ng-class="" ng-click="removeFav()"           style="margin-left: 10px;">Remove Favorite</md-button>`;
		else favButton = `<md-button id="addFav-button"        class="button md-button md-default-theme" ng-class="" ng-click="addFav()"            style="margin-left: 10px;">Add Favorite</md-button>`;
		
		return `
				<td colspan="5">
					<h1 style="padding-left:10px;">`+officialMark(d.official, true)+formatServerName(d.sname)+`</h1>
						<div class="row">
						<div class="col">
							<table class="description-table">
								<tr><td>Owner:</td><td>${d.owner|| ""}</td></tr>
								<tr><td>Map:</td><td>${SmoothMapName(d.map || "")}</td></tr>
								<tr><td>Players:</td><td>${d.players|| ""}/${d.maxplayers|| ""}</td></tr>
								<tr><td valign="top">Description:</td><td>${formatDescriptionName(d.sdesc|| "")}</td></tr>
							</table>
						</div>
						<div class="col">
							<ul class="serverItemDetails">
								<li>PPS: ${d.pps|| ""}</li>
								<li>Mods: ${modCount(d.modlist|| "")}</li>
								<li>Mod Names: ${modList(d.modlist|| "")}</li>
								<li>Total Mods Size: ${formatBytes(d.modstotalsize) || "0"}</li>
							</ul>
						</div>
					</div>
					<div class="row" style="padding-left: 10px;">
						<md-button id="serverconnect-button" class="button md-button md-default-theme" ng-class="" ng-click="multiplayer.connect()" style="margin-left: 10px;">Connect</md-button>
						` + favButton + `
					</div>
					<div class="row">
						<h4></h4>
						<p>${listPlayers(d.playerslist|| "")}</p>
					</div>
			</td>`;
};

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

	getFavs();

	var favjson = JSON.parse(localStorage.getItem('favorites'));

	var favArray = new Array();

	if(favjson != null)
		for(var i in favjson)
			if(favArray.filter(s=>s.ip == favjson[i].ip).filter(s=>s.port == favjson[i].port).length==0)
				favArray.push(favjson[i]);

	if(favArray.filter(s=>s.ip == serverToAdd.ip).filter(s=>s.port == serverToAdd.port).length==0)
		favArray.push(serverToAdd);

	favArray.sort((a, b) => (a.official > b.official) ? -1 : 1)
	localStorage.setItem('favorites', JSON.stringify(favArray))
	saveFavs();
	bngApiScope.engineLua('MPCoreNetwork.getServers()');
}

function createTableRow(table, i, type, fav, bngApi, serversList) {
	var server = serversList ? serversList[i] : servers[i];
	var bgcolor = 'rgba(0,0,0,0)!important';
	if (server.official) bgcolor = 'rgba(255,106,0,0.25)!important';
	// Create the row and set it's attributes
	let newRow = table.insertRow(table.length);
	var bgcolor = server.official ? 'rgba(255,106,0,0.25)!important' : 'rgba(0,0,0,0)!important';
	var tempHTML = `
		<td style="background-color:${bgcolor};">${server.location}</td>
		<td style="background-color:${bgcolor};">${formatServerName(server.sname)}</td>
		<td style="background-color:${bgcolor};">${SmoothMapName(server.map)}</td>
		<td style="background-color:${bgcolor};">${server.players}/${server.maxplayers}</td>
		<td style="background-color:${bgcolor};">${server.pps}</td>
	`;
	newRow.innerHTML = tempHTML;
	if (type == 0) newRow.setAttribute('data-id', i);
	else newRow.setAttribute('data-id', server.id + "," + server.recid);
	newRow.onclick = function() { select(this, type, fav, bngApi) };
}

// Used to connect to the backend with ids
function connect(bngApi) {
	console.log("Attempting to call connect to server...")
	// Show the connecting screen
	document.getElementById('LoadingServer').style.display = 'block'
	// Connect with ids
	bngApi.engineLua('MPCoreNetwork.connectToServer()');
}

// Used to select a row (when it's clicked)
// Type 0 is normal servers
// Type 1 is saved servers (recent, favorite...)
function select(row, type, fav, bngApi) {
	var table = document.getElementById("serversTable");
	// Deselect the old row
	deselect(table.selectedRow);

	// Select the new one
	row.classList.add("highlight");
	row.selected = true;
	table.selectedRow = row;
	
	// Add the highlight menu
	var id = row.getAttribute("data-id")

	if (id) {
		
		var server;
		if (type == 0) var server = servers[id]; // Get the server of the selected row
		else {
			id = id.split(',');
			if(id[0] > -1) {
				id = id[0];
				server = servers[id];
			}
			else {
				id = id[1];
				server = JSON.parse(localStorage.getItem('recent'))[id];
			}
		}	
		
		highlightedServer = servers[id]; // Set it as the selected server

		// Create and insert the server info tr
		var serverInfoRow = document.createElement("tr");
		serverInfoRow.innerHTML = getServerInfoHTML(server, fav);
		serverInfoRow.setAttribute("id", "ServerInfoRow");	
		row.parentNode.insertBefore(serverInfoRow, row.nextSibling);
		
		// Add the connect button
		var connectToServerButton = document.getElementById('serverconnect-button');
		var createClickHandler = function() {
			return function() { connect(bngApi) };
		};
		connectToServerButton.onclick = createClickHandler();
		
		if (!fav) {
			// Add the favorite button
			var addServer2FavButton = document.getElementById('addFav-button');
			var createClickHandler2 = function() {
				return function() { addFav() };
			};
			addServer2FavButton.onclick = createClickHandler2();
		}
		else {
			var remServer2FavButton = document.getElementById('removeFav-button');
			var createClickHandler2 = function() {
				return function() {
					removeFav()
				};
			};
			remServer2FavButton.onclick = createClickHandler2();
		}

		// Set the currently selected server lua side
		bngApi.engineLua(`MPCoreNetwork.setCurrentServer("${id}", "${server.ip}", "${server.port}", "${server.modlist}", "${server.strippedName}")`);
	}
}

function receiveServers(data) {
	var serversArray = new Array();
	// Parse the data to a nice looking Array
	for (var i = 0; i < data.length; i++) {
		var v = data[i][Object.keys(data[i])[0]]
		if(v.cversion == launcherVersion){
			v.strippedName = stripCustomFormatting(v.sname);
			serversArray.push(v);
		}
	}
	// Sort the servers to display official servers first
	serversArray.sort(function(a, b) {
		if (a.official && b.official) return a.strippedName.localeCompare(b.strippedName)
		else if (a.official) return -1;
		else if (b.official) return 1;
		return 0;
	});	
	return serversArray;
};

// Used to deselect a row
function deselect(row) {
	// Deselected the row
	if (!row) return;
	row.classList.remove("highlight");
	row.selected = false;
	// Remove the information thing if it was shown
	var oldInfoRow = document.getElementById('ServerInfoRow')
	if (oldInfoRow) oldInfoRow.remove();
}
