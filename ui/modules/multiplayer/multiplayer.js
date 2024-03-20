// Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
// Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
// SPDX-License-Identifier: AGPL-3.0-or-later

var highlightedServer;
var servers = [];
var official = [];
var featured = [];
var partner = [];
var favorites = [];
var recents = [];
var mdDialog;
var mdDialogVisible = false;

angular.module('beamng.stuff')
/* //////////////////////////////////////////////////////////////////////////////////////////////
*	TOS CONTROLLER
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerTOSController', ['$scope', '$state', '$timeout', '$document', 
function($scope, $state, $timeout, $document) {
	'use strict';

	$scope.$on('$stateChangeSuccess', async function (event, toState, toParams, fromState, fromParams) {

		// Check if the user as acknowledged tos
		const tosAccepted = localStorage.getItem("tosAccepted");
		if (tosAccepted == "true") {
			$state.go('menu.multiplayer.servers');
			return;
		}
	});

	// The lua setting need to be functional before we redirect, otherwise we'll land here again.
	// for that reason, we listen for the settings changed event that will ensure that the main menu will not get back here again
	$scope.validate = function () {
		localStorage.setItem("tosAccepted", "true");
		bngApi.engineLua(`MPConfig.acceptTos()`);
		$state.go('menu.multiplayer.servers');
	};

	$scope.openExternalLink = function(url) {
		bngApi.engineLua(`openWebBrowser("`+url+`")`);
	}

	bngApi.engineLua(`MPConfig.getConfig()`, (data) => {
		if (data != null) {
			if (!localStorage.getItem("tosAccepted")) {
				localStorage.setItem("tosAccepted", data.tos);
				$state.go('menu.multiplayer.servers');
			}
		}
	});
}])



/* //////////////////////////////////////////////////////////////////////////////////////////////
*	LAUNCHER CONNECTION CONTROLLER
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerLauncherController', ['$scope', '$state', '$timeout', '$document', 
function($scope, $state, $timeout, $document) {
	'use strict';
	// The lua setting need to be functional before we redirect, otherwise we'll land here again.
	// for that reason, we listen for the settings changed event that will ensure that the main menu will not get back here again
	$scope.connect = function () {
		bngApi.engineLua('MPCoreNetwork.connectToLauncher()');
	};
	
	$scope.$on('onLauncherConnected', function (event, data) {
		$state.go('menu.multiplayer.login');
	});
	
	// The game's lua has an auto launcher reconnect in case
}])



/* //////////////////////////////////////////////////////////////////////////////////////////////
*	LOGIN CONTROLLER
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerLoginController', ['$scope', '$state', '$timeout', '$document', 
function($scope, $state, $timeout, $document) {
	'use strict';
	// The lua setting need to be functional before we redirect, otherwise we'll land here again.
	// for that reason, we listen for the settings changed event that will ensure that the main menu will not get back here again
	var vm = this;
	$scope.login = function() {
		let credentials = {}
		credentials.username = document.getElementById('loginUsername').value.trim();
		credentials.password = document.getElementById('loginPassword').value.trim();
		if (credentials.username == "" || credentials.password == ""){
			document.getElementById('loginHeader').textContent = 'Missing credentials';
			return;
		}	
		document.getElementById('loginPassword').value = '';
		document.getElementById('loginHeader').textContent = 'Attempting to log in...';
		bngApi.engineLua('MPCoreNetwork.login(' + bngApi.serializeToLua(credentials) + ')');
	}

	$scope.switchConnection = function() {
		var x = document.getElementById('LOGINERRORFIELD').textContent = "";
		var loginContainer = document.getElementById('LoginContainer');
		var guestContainer = document.getElementById('GuestContainer');
		if (loginContainer.style.display == "none") {
			loginContainer.style.display = 'block';
			guestContainer.style.display = 'none';
		} else {
			loginContainer.style.display = 'none';
			guestContainer.style.display = 'block';
		}
		
	}

	$scope.guestLogin = function() {
		bngApi.engineLua('MPCoreNetwork.login()');
	}
	
	$scope.$on('LoggedIn', function (event, data) {
		$state.go('menu.multiplayer.servers');
	});
	
	$scope.$on('LoginError', function (event, data) {
		var x = document.getElementById('LOGINERRORFIELD').textContent= data;
	});
	
	// Try to auto login
	// bngApi.engineLua('MPCoreNetwork.autoLogin()');
	// autologin is called from lua
}])



/* //////////////////////////////////////////////////////////////////////////////////////////////
*	MAIN CONTROLLER
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerController', ['$scope', '$state', '$timeout', '$mdDialog', 
function($scope, $state, $timeout, $mdDialog) {
	var vm = this;
	bngApi = bngApi;
	mdDialog = $mdDialog;
	// Display the servers list page once the page is loaded
	$scope.$on('$stateChangeSuccess', async function (event, toState, toParams, fromState, fromParams) {
		//console.log(toState.url);
		if (toState.url == "/multiplayer") {
			// local://local/ui/#/menu/multiplayer/mpservers
			document.getElementById('servers-btn').click();
			
		}

		// Check if the user as aknowledged tos
		const tosAccepted = localStorage.getItem("tosAccepted");
		//console.log(toState.url);
		if (tosAccepted != "true") {
			$state.go('menu.multiplayer.tos');
			return;
		}

		// Check launcher is not connected
		const launcherConnected = await isLauncherConnected();
		if (!launcherConnected) {
			$state.go('menu.multiplayer.launcher');
			return;
		}

		// Check if we are logged in
		const loggedIn = await isLoggedIn();
		if (!loggedIn) {
			$state.go('menu.multiplayer.login');
			return;
		}
	});
	
	$scope.$on('LauncherConnectionLost', function (event, data) {
		$state.go('menu.multiplayer.launcher');
	});

	$scope.$on('showMdDialog', function (event, data) {
		switch(data.dialogtype) {
			case "alert":
				if (mdDialogVisible) { return; }
				//console.log(data);
				//console.log(mdDialogVisible);
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

	$scope.$on('onServerJoined', function (event, data) {
		$state.go('play');
	});

	$scope.logout = function() {
		bngApi.engineLua(`MPCoreNetwork.logout()`);
		$state.go('menu.multiplayer.login');
	}

	vm.modelChanged = function($event) {
		var src = event.srcElement;
		//console.log(src.value);
	}

	vm.refreshList = function() {
		//console.log("Attempting to refresh server list.")
		bngApi.engineLua('MPCoreNetwork.requestServerList()');
	}
	
	vm.clearRecents = function() {
		localStorage.removeItem("recents");
		vm.refreshList();
	}

	vm.directConnect = function() {
		//console.log('Clicked')
		var ip = document.getElementById('directip').value.trim();
		var port = document.getElementById('directport').value.trim();
		document.getElementById('LoadingServer').style.display = 'block';
		bngApi.engineLua(`MPCoreNetwork.connectToServer("${ip}","${port}")`);
	};

	vm.closePopup =  function() {
		document.getElementById('addCustomFav').style.display = 'none';
	};
	vm.closeLoadingPopup =  function() {
		document.getElementById('OriginalLoadingStatus').removeAttribute("hidden");
		document.getElementById('LoadingStatus').setAttribute("hidden", "hidden");
		document.getElementById('LoadingServer').style.display = 'none';
		bngApi.engineLua('MPCoreNetwork.leaveServer()');
	};

	vm.showCustomServer = function() {
		document.getElementById('addCustomFav').style.display = 'block';
	};

	vm.addCustomServer = async function() {
		var ip = document.getElementById('customFavIP');
		var port = document.getElementById('customFavPort');
		var name = document.getElementById('customFavName');
		var valid = (ip.value.length > 0) && (port.value.length > 0) && !isNaN(port.value)
		if (!valid) return;
		var server = {
			cversion: await getLauncherVersion(), ip: ip.value, location: "--", map: "", maxplayers: "0", players: "0",
			owner: "", playersList: "", sdesc: "", sname: name.value, strippedName: name.value,
			custom: true, port: port.value
		};
		addFav(server);
		document.getElementById('addCustomFav').style.display = 'none';
		name.value = '';
		ip.value = '';
		port.value = '';
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
		if (data.message == "done") {
			document.getElementById('LoadingStatus').innerText = "Done";
		} else {
			document.getElementById('LoadingStatus').innerText = data.message;
		}
		
		document.getElementById('OriginalLoadingStatus').setAttribute("hidden", "hidden");
		document.getElementById('LoadingStatus').removeAttribute("hidden");
	});

	vm.exit = function ($event) {
		if ($event)
		console.log('[MultiplayerController] exiting by keypress event %o', $event);
		$state.go('menu.mainmenu');
	};

	var timeOut = $timeout(function() {
		if (vm.loadingPage === true) {
			vm.loadTimeout = true;
		}
	}, 10000);

	$scope.$on('$destroy', function () {
		$timeout.cancel(timeOut);
		//console.log('[MultiplayerController] destroyed.');
	});
}])



/* //////////////////////////////////////////////////////////////////////////////////////////////
*	OFFICIAL TAB
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerOfficialController', ['$scope', '$state', '$timeout', 
function($scope, $state, $timeout) {

	var vm = this;
	let serverListOptions = JSON.parse(localStorage.getItem("serverListOptions"))

	if (serverListOptions != null) {
		vm.checkIsEmpty = serverListOptions.checkIsEmpty
		vm.checkIsNotEmpty = serverListOptions.checkIsNotEmpty
		vm.checkIsNotFull = serverListOptions.checkIsNotFull
		vm.checkModSlider = serverListOptions.checkModSlider
		vm.sliderMaxModSize = serverListOptions.sliderMaxModSize
		vm.selectMap = serverListOptions.selectMap
		vm.searchText = ""
	} else {
		vm.checkIsEmpty = false
		vm.checkIsNotEmpty = false
		vm.checkIsNotFull = false
		vm.checkModSlider = false
		vm.sliderMaxModSize = 500 // in MB
		vm.selectMap = "Any"
		vm.searchText = ""
	}
	
	// Resize the server list
	setServersTableHeight();

	bngApi.engineLua('MPCoreNetwork.requestServerList()');

	// Go back to the main menu on exit
	vm.exit = function ($event) {
		if ($event) console.log('[MultiplayerOfficialController] exiting by keypress event %o', $event);
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
		//console.log('[MultiplayerOfficialController] destroyed.');
	});
	
	$scope.$on('onServerListReceived', async function (event, data) {
		servers = await receiveServers(data);
		official = await getOfficial();
		vm.repopulate();
	});
	
	vm.repopulate = async function() {
		if (serverListOptions != null) {
			if (serverListOptions.checkIsEmpty && vm.checkIsNotEmpty) vm.checkIsEmpty = false;
			if (serverListOptions.checkIsNotEmpty && vm.checkIsEmpty) vm.checkIsNotEmpty = false;
		}

		vm.availableMaps = await populateTable(
			document.getElementById("serversTableBody"),
			official,
			4, // Servers = 0, Favorites = 1, Recent = 2, Featured = 3, Official = 4
			vm.searchText,
			vm.checkIsEmpty,
			vm.checkIsNotEmpty,
			vm.checkIsNotFull,
			vm.checkModSlider,
			vm.sliderMaxModSize,
			vm.selectMap,
			bngApi
		);
		serverListOptions = {
			checkIsEmpty : vm.checkIsEmpty,
			checkIsNotEmpty : vm.checkIsNotEmpty,
			checkIsNotFull : vm.checkIsNotFull,
			checkModSlider : vm.checkModSlider,
			sliderMaxModSize : vm.sliderMaxModSize,
			selectMap : vm.selectMap,
		};
		localStorage.setItem("serverListOptions", JSON.stringify(serverListOptions));
	};

	vm.repopulate();
}])



/* //////////////////////////////////////////////////////////////////////////////////////////////
*	SERVERS TAB
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerServersController', ['$scope', '$state', '$timeout', 
function($scope, $state, $timeout) {

	var vm = this;
	let serverListOptions = JSON.parse(localStorage.getItem("serverListOptions"))

	if (serverListOptions)

	if (serverListOptions != null) {
		vm.checkIsEmpty = serverListOptions.checkIsEmpty
		vm.checkIsNotEmpty = serverListOptions.checkIsNotEmpty
		vm.checkIsNotFull = serverListOptions.checkIsNotFull
		vm.checkModSlider = serverListOptions.checkModSlider
		vm.sliderMaxModSize = serverListOptions.sliderMaxModSize
		vm.selectMap = serverListOptions.selectMap
		vm.searchText = ""
	} else {
		vm.checkIsEmpty = false
		vm.checkIsNotEmpty = false
		vm.checkIsNotFull = false
		vm.checkModSlider = false
		vm.sliderMaxModSize = 500 // in MB
		vm.selectMap = "Any"
		vm.searchText = ""
	}
	
	// Resize the server list
	setServersTableHeight();

	bngApi.engineLua('MPCoreNetwork.requestServerList()');

	// Go back to the main menu on exit
	vm.exit = function ($event) {
		if ($event) console.log('[MultiplayerServersController] exiting by keypress event %o', $event);
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
		//console.log('[MultiplayerServersController] destroyed.');
	});
	
	$scope.$on('onServerListReceived', async function (event, data) {
		servers = await receiveServers(data);
		vm.repopulate();
	});
	
	vm.repopulate = async function() {
		if (serverListOptions != null) {
			if (serverListOptions.checkIsEmpty && vm.checkIsNotEmpty) vm.checkIsEmpty = false;
			if (serverListOptions.checkIsNotEmpty && vm.checkIsEmpty) vm.checkIsNotEmpty = false;
		}

		vm.availableMaps = await populateTable(
			document.getElementById("serversTableBody"),
			servers,
			0, // Favorite, Recent or Servers tab
			vm.searchText,
			vm.checkIsEmpty,
			vm.checkIsNotEmpty,
			vm.checkIsNotFull,
			vm.checkModSlider,
			vm.sliderMaxModSize,
			vm.selectMap,
			bngApi
		);

		serverListOptions = {
			checkIsEmpty : vm.checkIsEmpty,
			checkIsNotEmpty : vm.checkIsNotEmpty,
			checkIsNotFull : vm.checkIsNotFull,
			checkModSlider : vm.checkModSlider,
			sliderMaxModSize : vm.sliderMaxModSize,
			selectMap : vm.selectMap,
		};
		localStorage.setItem("serverListOptions", JSON.stringify(serverListOptions));
	};
}])



/* //////////////////////////////////////////////////////////////////////////////////////////////
*	FEATURED TAB
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerFeaturedController', ['$scope', '$state', '$timeout', 
function($scope, $state, $timeout) {

	var vm = this;
	let serverListOptions = JSON.parse(localStorage.getItem("serverListOptions"))

	if (serverListOptions != null) {
		vm.checkIsEmpty = serverListOptions.checkIsEmpty
		vm.checkIsNotEmpty = serverListOptions.checkIsNotEmpty
		vm.checkIsNotFull = serverListOptions.checkIsNotFull
		vm.checkModSlider = serverListOptions.checkModSlider
		vm.sliderMaxModSize = serverListOptions.sliderMaxModSize
		vm.selectMap = serverListOptions.selectMap
		vm.searchText = ""
	} else {
		vm.checkIsEmpty = false
		vm.checkIsNotEmpty = false
		vm.checkIsNotFull = false
		vm.checkModSlider = false
		vm.sliderMaxModSize = 500 // in MB
		vm.selectMap = "Any"
		vm.searchText = ""
	}
	
	// Resize the server list
	setServersTableHeight();

	bngApi.engineLua('MPCoreNetwork.requestServerList()');

	// Go back to the main menu on exit
	vm.exit = function ($event) {
		if ($event) console.log('[MultiplayerFeaturedController] exiting by keypress event %o', $event);
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
		//console.log('[MultiplayerFeaturedController] destroyed.');
	});
	
	$scope.$on('onServerListReceived', async function (event, data) {
		servers = await receiveServers(data);
		featured = await getFeatured();
		//console.log(featured)
		vm.repopulate();
	});
	
	vm.repopulate = async function() {
		if (serverListOptions != null) {
			if (serverListOptions.checkIsEmpty && vm.checkIsNotEmpty) vm.checkIsEmpty = false;
			if (serverListOptions.checkIsNotEmpty && vm.checkIsEmpty) vm.checkIsNotEmpty = false;
		}

		vm.availableMaps = await populateTable(
			document.getElementById("serversTableBody"),
			featured,
			3, // Servers = 0, Favorites = 1, Recent = 2, Featured = 3
			vm.searchText,
			vm.checkIsEmpty,
			vm.checkIsNotEmpty,
			vm.checkIsNotFull,
			vm.checkModSlider,
			vm.sliderMaxModSize,
			vm.selectMap,
			bngApi
		);
		serverListOptions = {
			checkIsEmpty : vm.checkIsEmpty,
			checkIsNotEmpty : vm.checkIsNotEmpty,
			checkIsNotFull : vm.checkIsNotFull,
			checkModSlider : vm.checkModSlider,
			sliderMaxModSize : vm.sliderMaxModSize,
			selectMap : vm.selectMap,
		};
		localStorage.setItem("serverListOptions", JSON.stringify(serverListOptions));
	};
}])



/* //////////////////////////////////////////////////////////////////////////////////////////////
*	PARTNER TAB
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerPartnerController', ['$scope', '$state', '$timeout', 
function($scope, $state, $timeout) {

	var vm = this;
	let serverListOptions = JSON.parse(localStorage.getItem("serverListOptions"))

	if (serverListOptions != null) {
		vm.checkIsEmpty = serverListOptions.checkIsEmpty
		vm.checkIsNotEmpty = serverListOptions.checkIsNotEmpty
		vm.checkIsNotFull = serverListOptions.checkIsNotFull
		vm.checkModSlider = serverListOptions.checkModSlider
		vm.sliderMaxModSize = serverListOptions.sliderMaxModSize
		vm.selectMap = serverListOptions.selectMap
		vm.searchText = ""
	} else {
		vm.checkIsEmpty = false
		vm.checkIsNotEmpty = false
		vm.checkIsNotFull = false
		vm.checkModSlider = false
		vm.sliderMaxModSize = 500 // in MB
		vm.selectMap = "Any"
		vm.searchText = ""
	}
	
	// Resize the server list
	setServersTableHeight();

	bngApi.engineLua('MPCoreNetwork.requestServerList()');

	// Go back to the main menu on exit
	vm.exit = function ($event) {
		if ($event) console.log('[MultiplayerPartnerController] exiting by keypress event %o', $event);
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
		//console.log('[MultiplayerPartnerController] destroyed.');
	});
	
	$scope.$on('onServerListReceived', async function (event, data) {
		servers = await receiveServers(data);
		partner = await getPartner();
		//console.log(partner)
		vm.repopulate();
	});
	
	vm.repopulate = async function() {
		if (serverListOptions != null) {
			if (serverListOptions.checkIsEmpty && vm.checkIsNotEmpty) vm.checkIsEmpty = false;
			if (serverListOptions.checkIsNotEmpty && vm.checkIsEmpty) vm.checkIsNotEmpty = false;
		}

		vm.availableMaps = await populateTable(
			document.getElementById("serversTableBody"),
			partner,
			4, // Servers = 0, Favorites = 1, Recent = 2, Featured = 3, Partner = 4
			vm.searchText,
			vm.checkIsEmpty,
			vm.checkIsNotEmpty,
			vm.checkIsNotFull,
			vm.checkModSlider,
			vm.sliderMaxModSize,
			vm.selectMap,
			bngApi
		);
		serverListOptions = {
			checkIsEmpty : vm.checkIsEmpty,
			checkIsNotEmpty : vm.checkIsNotEmpty,
			checkIsNotFull : vm.checkIsNotFull,
			checkModSlider : vm.checkModSlider,
			sliderMaxModSize : vm.sliderMaxModSize,
			selectMap : vm.selectMap,
		};
		localStorage.setItem("serverListOptions", JSON.stringify(serverListOptions));
	};
}])



/* //////////////////////////////////////////////////////////////////////////////////////////////
*	RECENT TAB
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerRecentController', ['$scope', '$state', '$timeout', 
function($scope, $state, $timeout) {
	var vm = this;
	
	// Resize the server list
	setServersTableHeight();
	
	vm.searchText = "";

	bngApi.engineLua('MPCoreNetwork.sendBeamMPInfo()'); // request cached server lsit
	$scope.$on('onServerListReceived', async function (event, data) {
		servers = await receiveServers(data);
		recents = await getRecents();
		vm.repopulate();
	});

	vm.repopulate = async function() {
		vm.availableMaps = await populateTable(
			document.getElementById("serversTableBody"),
			servers,
			2, // Favorite, Recent or Servers tab
			vm.searchText,
			false,
			false,
			false,
			false,
			500,
			"Any",
			bngApi
		);
	};

	// When controller is unloaded
	vm.exit = function ($event) {
		if ($event)
		console.log('[MultiplayerRecentController] exiting by keypress event %o', $event);
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
		//console.log('[MultiplayerRecentController] destroyed.');
	});
}])



/* //////////////////////////////////////////////////////////////////////////////////////////////
*	FAVORITE TAB
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerFavoritesController', ['$scope', '$state', '$timeout', 
function($scope, $state, $timeout) {
	var vm = this;

	vm.checkIsEmpty = false;
	vm.checkIsNotEmpty = false;
	vm.checkIsNotFull = false;
	vm.checkModSlider = false;
	vm.sliderMaxModSize = 500; // in MB
	vm.selectMap = "Any";
	vm.searchText = "";
	bngApi.engineLua('MPCoreNetwork.sendBeamMPInfo()'); // request cached server list
	
	// Resize the server list
	setServersTableHeight();

	vm.exit = function ($event) {
		if ($event)
		console.log('[MultiplayerServersController] exiting by keypress event %o', $event);
		$state.go('menu.mainmenu');
	};

	$scope.$on('onServerListReceived', async function (event, data) {
		servers = await receiveServers(data);
		favorites = await getFavorites();
		vm.repopulate();
	});

	vm.repopulate = async function() {
		vm.availableMaps = await populateTable(
			document.getElementById("serversTableBody"),
			servers,
			1, // Favorite, Recent or Servers tab
			vm.searchText,
			vm.checkIsEmpty,
			vm.checkIsNotEmpty,
			vm.checkIsNotFull,
			vm.checkModSlider,
			vm.sliderMaxModSize,
			vm.selectMap,
			bngApi
		);
	};

	var timeOut = $timeout(function() {
		if (vm.loadingPage === true) {
			vm.loadTimeout = true;
		}
	}, 10000);

	$scope.$on('$destroy', function () {
		$timeout.cancel(timeOut);
		//console.log('[MultiplayerServersController] destroyed.');
	});

	function setColor(row) {
		// If odd gray / If even lightgray
		if (row.rowIndex % 2 == 0) row.style.backgroundColor = "white";
		else row.style.backgroundColor = "#f2f2f2";
	}
}])



/* //////////////////////////////////////////////////////////////////////////////////////////////
*	DIRECT CONNECT TAB
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerDirectController', ['$scope', '$state', '$timeout',
function($scope, $state, $timeout) {
	var vm = this;

	var timeOut = $timeout(function() {
		if (vm.loadingPage === true) {
			vm.loadTimeout = true;
		}
	}, 10000);

	vm.exit = function ($event) {
		if ($event)
		console.log('[MultiplayerDirectController] exiting by keypress event %o', $event);
		$state.go('menu.mainmenu');
	};

	$scope.$on('$destroy', function () {
		$timeout.cancel(timeOut);
		//console.log('[MultiplayerDirectController] destroyed.');
	});
}])

.directive('compile', ['$compile', function ($compile) {
  return function(scope, element, attrs) {
    scope.$watch(
      function(scope) {
        // watch the 'compile' expression for changes
        return scope.$eval(attrs.compile);
      },
      function(value) {
        // when the 'compile' expression changes
        // assign it into the current DOM
        element.html(value);
				// compile the new DOM and link it to the current
			  // scope.
			  // NOTE: we only compile .childNodes so that
			  // we don't get into infinite loop compiling ourselves
			  $compile(element.contents())(scope);
			}
		);
	};
}])



/* //////////////////////////////////////////////////////////////////////////////////////////////
*	FUNCTIONS
*/ //////////////////////////////////////////////////////////////////////////////////////////////
// Set the first letter of each word upper case
function toTitleCase(str) {
	return str.replace(/\w\S*/g, function(txt){
		return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
	});
}

function SmoothMapName(map) {
	if (!map) return;
	map = map.replace("/info.json","")
	map = map.split('/').pop().replace(/\s*/g,'')
	map = map.replace(/_/g," ")
	map = map.replace(/-/g," ")
	map = toTitleCase(map)
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
};

function applyDescCode(string, codes) {
    var elem = document.createElement('span');
		elem.style.fontSize = 'initial';
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

		// Find all color and formatting codes
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
		elem.style.fontSize = 'initial';
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
			return '<img src="local://local/ui/modules/multiplayer/beammp.png" alt="" style="height: 23px; padding-right: 10px;"> [Official Server]  '
		} else {
			return '<img src="local://local/ui/modules/multiplayer/beammp.png" alt="" style="height: 21px; padding-right: 10px; padding-left: 10px; position: absolute;">'
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

async function getOfficial() {
	return new Promise(function(resolve, reject) {
		var _official = []
		servers.forEach(server => {
			if (server.official === true || server.approved === true) {
				_official.push(server)
			}
		});
		
		official = _official
		
		resolve(_official || []);
	});
}

async function getFeatured() {
	return new Promise(function(resolve, reject) {
		var feat = []
		servers.forEach(server => {
			//console.log(server)
			if (server.featured === true) {
				feat.push(server)
			}
		});
		
		featured = feat
		
		resolve(feat || []);
	});
}

async function getPartner() {
	return new Promise(function(resolve, reject) {
		var part = []
		servers.forEach(server => {
			if (server.partner === true) {
				part.push(server)
			}
		});
		
		partner = part
		
		resolve(part || []);
	});
}

async function getFavorites() {
	return new Promise(function(resolve, reject) {
		bngApi.engineLua("MPConfig.getFavorites()", (data) => {
			if (!data) { resolve([]); return; }
			if (typeof data === "object") if (Object.keys(data).length == 0) data = [];
			favorites = data; // Added this here so that we remove the await where this function was called.
			resolve(data || []);
		});
	});
}

function addFav(server, isUpdate) {
	server.addTime = Date.now();
	favorites.push(server);
	saveFav();
	if (!isUpdate) bngApi.engineLua('MPCoreNetwork.requestServerList()');
}

function removeFav(server) {
	for (let i = 0; i < favorites.length; i++) {
		let tmpServer = favorites[i];
		if (tmpServer.ip == server.ip && tmpServer.port == server.port) {
			favorites.splice(i, 1);
		}
	}
	saveFav();
	bngApi.engineLua('MPCoreNetwork.sendBeamMPInfo()'); // request cached server list
}

function saveFav() {
	var entry = Base64.encode(JSON.stringify(favorites));
	bngApi.engineLua('MPConfig.setFavorites(\'' + entry + '\')');
	
	// backup
	// bngApi.engineLua(`MPConfig.setFavorites(\'${JSON.stringify(favorites).replace(/'/g, "\\'")}\')`);
}

function getRecents() {
	return new Promise(function(resolve, reject) {
		var tmpRecents = JSON.parse(localStorage.getItem("recents"));
		recents = tmpRecents || []; // Moved this to here so that we are no longer awaiting it
		resolve(tmpRecents || []);
	});
}

function addRecent(server, isUpdate) { // has to have name, ip, port
	server.addTime = Date.now();
	recents.push(server);
	recents = recents.slice(-1 * 30); //keep the last 30 entries
	if(!isUpdate) localStorage.setItem("recents", JSON.stringify(recents));
}

function openExternalLink(url){
	bngApi.engineLua(`mp_open_url("`+url+`")`);
}

function openForumLink(){
	openExternalLink("http://forum.beammp.com");
}

function getServerInfoHTML(d) {
		// `d` is the original data object for the row
		var favButton;
		//console.log(d);
		if (d.favorite) favButton = `<md-button id="removeFav-button" class="button servers-button md-button md-default-theme" ng-class="" ng-click="removeFav()" style="margin-left: 10px; background-color: #FF6961;">Remove Favorite</md-button>`;
		else favButton = `<md-button id="addFav-button" class="button servers-button md-button md-default-theme" ng-class="" ng-click="addFav(this)" style="margin-left: 10px; background-color: #FFB646">Add Favorite</md-button>`;
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
								<li>Mods: ${modCount(d.modlist|| "")}</li>
								<li>Mod Names: ${modList(d.modlist|| "")}</li>
								<li>Total Mods Size: ${formatBytes(d.modstotalsize) || "0"}</li>
							</ul>
						</div>
					</div>
					<div class="row" style="padding-left: 10px;">
						<md-button id="serverconnect-button" class="button servers-button md-button md-default-theme" ng-class="" ng-click="multiplayer.connect(` + d.ip + `, ` + d.port + `)" style="margin-left: 10px;">Connect</md-button>
						` + favButton + `
					</div>
					<div class="row">
						<h4></h4>
						<p>${listPlayers(d.playerslist|| "")}</p>
					</div>
			</td>`;
};


function createRow(table, server, bgcolor, bngApi, isFavorite, isRecent, sname) {
	let newRow = table.insertRow(table.length);
	newRow.style.fontSize = 0;
	newRow.server = server;
	newRow.server.favorite = isFavorite;
	newRow.server.recent = isRecent;
	/*newRow.innerHTML = `
		<td style="background-color:${bgcolor}; font-size: initial;"><i class="flag flag-${server.location}"></i> ${server.location}</td>
		<td style="background-color:${bgcolor};">${formatServerName(sname)}</td>
		<td style="background-color:${bgcolor}; font-size: initial;">${SmoothMapName(server.map)}</td>
		<td style="background-color:${bgcolor}; font-size: initial;">${server.players}/${server.maxplayers}</td>
	`;*/
	newRow.innerHTML = `
		<td style="background-color:${bgcolor}; font-size: initial; padding-left: 3px; text-align: right; padding-right: 10px;"><img src="local://local/ui/modules/multiplayer/flags/${server.location.toLowerCase()}.png" class="flag"></img> ${server.location}</td>
		<td style="background-color:${bgcolor};">${formatServerName(sname)}</td>
		<td style="background-color:${bgcolor}; font-size: initial;">${SmoothMapName(server.map)}</td>
		<td style="background-color:${bgcolor}; font-size: initial;">${server.players}/${server.maxplayers}</td>
	`;
	newRow.onclick = function() { select(this, bngApi); };
}

// /!\ IMPORTANT /!\ //// TYPE 0 = Normal / 1 = Favorites / 2 = Recents
async function populateTable(tableTbody, servers, type, searchText = '', checkIsEmpty, checkIsNotEmpty, checkIsNotFull, checkModSlider, sliderMaxModSize, selectMap = 'Any', bngApi) {
	var newTbody = document.createElement('tbody');
	newTbody.id = "serversTableBody";
	var mapNames = new Array(); //["Any"];
	for (const server of servers) {
		if (!server) {
			break;
		}
		var shown = true;
		var smoothMapName = SmoothMapName(server.map);
		var isFavorite = false;
		var isRecent = false;

		// Filter by search
		if (!server.strippedName.toLowerCase().includes(searchText.toLowerCase())) continue;
		
		// Filter by empty or full
		else if(checkIsEmpty && server.players > 0) continue;
		else if(checkIsNotEmpty && server.players == 0) continue;
		else if(checkIsNotFull && server.players >= server.maxplayers) continue;
		
		// Filter by mod size
		else if(checkModSlider && sliderMaxModSize * 1048576 < server.modstotalsize) continue;
	
		// Filter by map
		else if((selectMap != "Any" && selectMap != smoothMapName)) continue;

		// Add the maps to the combobox on the UI
		if(!mapNames.includes(smoothMapName)) mapNames.push(smoothMapName);

		// Favorite
		for (let tmpServer of favorites) if (tmpServer.ip == server.ip && tmpServer.port == server.port) isFavorite = tmpServer.addTime;
		if (type == 1 && !isFavorite) continue; // If it's favorite tab, we only show favorites

		// Recents
		for (let tmpServer of recents) if (tmpServer.ip == server.ip && tmpServer.port == server.port) isRecent = tmpServer.addTime;
		if (type == 2 && !isRecent) continue; // Everything happens underneath for recents

		// If the server passed the filter
		// Set the color relative to either favorite, featured, official or normal
		var bgcolor = isFavorite && type == 0 ? 'rgba(255, 215, 0, 0.35)!important' : server.featured ? 'rgba(0, 128, 0, 0.25)!important' : server.official ? 'rgba(255, 106, 0, 0.25)!important' : server.partner ? 'rgba(0, 123, 195, 0.3)!important' : 'rgba(0, 0, 0, 0)!important';


		createRow(newTbody, server, bgcolor, bngApi, isFavorite, isRecent, server.sname);
		if (isFavorite) addFav(server, true);
		if (isRecent) addRecent(server, true);
	}
	
	// Here we check if some favorited / recents servers are offline or not
	if (type == 1 || type == 2) {
		var toCheck = type == 1 ? favorites : recents
		for (let tmpServer1 of toCheck) {
			let stillOk = true;
			for (let i = 0; i < servers.length; i++) {
				var tmpServer2 = servers[i];
				if (tmpServer1.ip == tmpServer2.ip && tmpServer1.port == tmpServer2.port) { stillOk = true; break; }
				else stillOk = false;
			}
			if (!stillOk) {
				var bgcolor = "";
				var name = tmpServer1.sname;
				if (!tmpServer1.custom) { name += " [OFFLINE]"; bgcolor = "rgba(0, 0, 0, 0.35)!important"; }
				else { name += " [CUSTOM]"; bgcolor = "rgba(255, 215, 0, 0.35)!important" }
				createRow(newTbody, tmpServer1, bgcolor, bngApi, type == 1, type == 2, name);
			}
		}
	}
	tableTbody.parentNode.replaceChild(newTbody, tableTbody);
	mapNames.sort(); // Sort the maps by name
	mapNames.unshift("Any"); // Set Any to the beginning
	if (type == 2) sortTable("recent", true, -1);
	return mapNames; // Set the list of available maps
}

// Used to connect to the backend with ids
function connect(ip, port, name) {
	console.log("Attempting to call connect to server...")
	// Add server to recents
	addRecent(highlightedServer);
	// Make sure the right content is displayed
	document.getElementById('OriginalLoadingStatus').removeAttribute("hidden");
	document.getElementById('LoadingStatus').setAttribute("hidden", "hidden");
	// Show the connecting screen
	document.getElementById('LoadingServer').style.display = 'block'
	// Connect with ids
	bngApi.engineLua('MPCoreNetwork.connectToServer("' + ip + '", ' + port + ',"' + name + '")');
}

// Used to select a row (when it's clicked)
function select(row, bngApi) {
	var table = document.getElementById("serversTable");
	// Deselect the old row
	deselect(table.selectedRow);

	// Select the new one
	row.classList.add("highlight");
	row.selected = true;
	table.selectedRow = row;
	
	// Add the highlight menu
	var server = row.server;
	highlightedServer = server; // Set it as the selected server

	// Create and insert the server info tr
	var serverInfoRow = document.createElement("tr");
	serverInfoRow.innerHTML = getServerInfoHTML(server);
	serverInfoRow.setAttribute("id", "ServerInfoRow");
	serverInfoRow.server = row.server;
	row.parentNode.insertBefore(serverInfoRow, row.nextSibling);

	// Add the connect button
	var connectToServerButton = document.getElementById('serverconnect-button');
	connectToServerButton.onclick = function() { connect(row.server.ip, row.server.port, row.server.strippedName) };
	
	if (server.favorite) {
		var removeFavButton = document.getElementById('removeFav-button');
		removeFavButton.onclick = function() { removeFav(server); }
	}
	else {
		// Add the favorite button
		var addFavButton = document.getElementById('addFav-button');
		addFavButton.onclick = function() { addFav(server) };
	}
}

async function receiveServers(data) {
	var serversArray = new Array();
	var launcherVersion = await getLauncherVersion();
	// Parse the data to a nice looking Array
	for (var i = 0; i < data.length; i++) {
		var v = data[i]
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

async function getLauncherVersion() {
	return new Promise(function(resolve, reject) {
		bngApi.engineLua("MPCoreNetwork.getLauncherVersion()", (data) => {
			resolve(data);
		});
	});
}

async function isLoggedIn() {
	return new Promise(function(resolve, reject) {
		bngApi.engineLua("MPCoreNetwork.isLoggedIn()", (data) => {
			resolve(data);
		});
	});
}

async function isLauncherConnected() {
	return new Promise(function(resolve, reject) {
		bngApi.engineLua("MPCoreNetwork.isLauncherConnected()", (data) => {
			resolve(data);
		});
	});
}

var reverse = -1;
function sortTable(sortType, isNumber, dir) {
	if (dir) reverse = dir;
	var table = document.getElementById("serversTable");
    var tb = table.tBodies[0], tr = Array.prototype.slice.call(tb.rows, 0);
	var headers = document.querySelectorAll("#serversTable > thead > tr > th")
	tr = tr.sort(function (a, b) { // sort rows
		return reverse * (a.server[sortType].toString().localeCompare(b.server[sortType].toString(), undefined, {'numeric': isNumber}));
    });
    for(var i = 0; i < tr.length; ++i) tb.appendChild(tr[i]); // append each row in order
	reverse = -((+reverse) || -1);
}

function setServersTableHeight() {
	let topDistance = document.getElementById("serversTableContainer").getBoundingClientRect().top;
	let navBarHeight = document.querySelector(".menuNavbar").getBoundingClientRect().top;
	document.getElementById("serversTableContainer").style.maxHeight = (window.innerHeight - topDistance - (window.innerHeight - navBarHeight)) + 'px';
}


/**
*
*  Base64 encode / decode
*  http://www.webtoolkit.info/javascript_base64.html
*  https://stackoverflow.com/questions/23223718/failed-to-execute-btoa-on-window-the-string-to-be-encoded-contains-characte
**/
var Base64 = {

    // private property
    _keyStr: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="

    // public method for encoding
    , encode: function (input)
    {
        var output = "";
        var chr1, chr2, chr3, enc1, enc2, enc3, enc4;
        var i = 0;

        input = Base64._utf8_encode(input);

        while (i < input.length)
        {
            chr1 = input.charCodeAt(i++);
            chr2 = input.charCodeAt(i++);
            chr3 = input.charCodeAt(i++);

            enc1 = chr1 >> 2;
            enc2 = ((chr1 & 3) << 4) | (chr2 >> 4);
            enc3 = ((chr2 & 15) << 2) | (chr3 >> 6);
            enc4 = chr3 & 63;

            if (isNaN(chr2))
            {
                enc3 = enc4 = 64;
            }
            else if (isNaN(chr3))
            {
                enc4 = 64;
            }

            output = output +
                this._keyStr.charAt(enc1) + this._keyStr.charAt(enc2) +
                this._keyStr.charAt(enc3) + this._keyStr.charAt(enc4);
        } // Whend 

        return output;
    } // End Function encode 


    // public method for decoding
    ,decode: function (input)
    {
        var output = "";
        var chr1, chr2, chr3;
        var enc1, enc2, enc3, enc4;
        var i = 0;

        input = input.replace(/[^A-Za-z0-9\+\/\=]/g, "");
        while (i < input.length)
        {
            enc1 = this._keyStr.indexOf(input.charAt(i++));
            enc2 = this._keyStr.indexOf(input.charAt(i++));
            enc3 = this._keyStr.indexOf(input.charAt(i++));
            enc4 = this._keyStr.indexOf(input.charAt(i++));

            chr1 = (enc1 << 2) | (enc2 >> 4);
            chr2 = ((enc2 & 15) << 4) | (enc3 >> 2);
            chr3 = ((enc3 & 3) << 6) | enc4;

            output = output + String.fromCharCode(chr1);

            if (enc3 != 64)
            {
                output = output + String.fromCharCode(chr2);
            }

            if (enc4 != 64)
            {
                output = output + String.fromCharCode(chr3);
            }

        } // Whend 

        output = Base64._utf8_decode(output);

        return output;
    } // End Function decode 


    // private method for UTF-8 encoding
    ,_utf8_encode: function (string)
    {
        var utftext = "";
        string = string.replace(/\r\n/g, "\n");

        for (var n = 0; n < string.length; n++)
        {
            var c = string.charCodeAt(n);

            if (c < 128)
            {
                utftext += String.fromCharCode(c);
            }
            else if ((c > 127) && (c < 2048))
            {
                utftext += String.fromCharCode((c >> 6) | 192);
                utftext += String.fromCharCode((c & 63) | 128);
            }
            else
            {
                utftext += String.fromCharCode((c >> 12) | 224);
                utftext += String.fromCharCode(((c >> 6) & 63) | 128);
                utftext += String.fromCharCode((c & 63) | 128);
            }

        } // Next n 

        return utftext;
    } // End Function _utf8_encode 

    // private method for UTF-8 decoding
    ,_utf8_decode: function (utftext)
    {
        var string = "";
        var i = 0;
        var c, c1, c2, c3;
        c = c1 = c2 = 0;

        while (i < utftext.length)
        {
            c = utftext.charCodeAt(i);

            if (c < 128)
            {
                string += String.fromCharCode(c);
                i++;
            }
            else if ((c > 191) && (c < 224))
            {
                c2 = utftext.charCodeAt(i + 1);
                string += String.fromCharCode(((c & 31) << 6) | (c2 & 63));
                i += 2;
            }
            else
            {
                c2 = utftext.charCodeAt(i + 1);
                c3 = utftext.charCodeAt(i + 2);
                string += String.fromCharCode(((c & 15) << 12) | ((c2 & 63) << 6) | (c3 & 63));
                i += 3;
            }

        } // Whend 

        return string;
    } // End Function _utf8_decode 

}
