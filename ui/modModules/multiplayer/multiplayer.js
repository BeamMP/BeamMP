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
var userData = {
	username: 'Loading...',
	avatar: '',
	role: 'USER',
	color: '',
	id: -1
};
var beammpMetrics = {
	players: "...", 
	servers: "...",
	beammpGameVer: "...",
	beammpLauncherVer: "..."
}
var serverView = "";
let repopulateServerList = async function() {

};


import('/ui/lib/ext/purify.min.js')

angular.module('BeamNG.ui')
.run(function($rootScope, $templateCache) {
  $rootScope.$on('$stateChangeStart', function(event, toState, toParams, fromState, fromParams) {
    if (toState.name === 'loading' || fromState.name === 'loading') {
      $templateCache.remove('/ui/modules/loading/loading.html');
    }
  });
});

export default angular.module('multiplayer', ['ui.router'])
.config(['$stateProvider', function($stateProvider) {
  $stateProvider.state('menu.multiplayer', {
		url: '/multiplayer',
		templateUrl: '/ui/modModules/multiplayer/multiplayer.html',
		controller: 'MultiplayerController as multiplayer',
		backState: 'BACK_TO_MENU',
		abstract: true
	})
	.state('menu.multiplayer.tos', {
		url: '/mptos',
		templateUrl: '/ui/modModules/multiplayer/tos.partial.html',
		controller: 'MultiplayerTOSController as multiplayertos',
		backState: 'BACK_TO_MENU'
	})
	.state('menu.multiplayer.launcher', {
		url: '/mplauncher',
		templateUrl: '/ui/modModules/multiplayer/launcher.partial.html',
		controller: 'MultiplayerLauncherController as multiplayerlauncher',
		backState: 'BACK_TO_MENU'
	})
	.state('menu.multiplayer.login', {
		url: '/mplogin',
		templateUrl: '/ui/modModules/multiplayer/login.partial.html',
		controller: 'MultiplayerLoginController as multiplayerlogin',
		backState: 'BACK_TO_MENU'
	})
	.state('menu.multiplayer.servers', {
		url: '/mpservers',
		templateUrl: '/ui/modModules/multiplayer/servers.partial.html',
		controller: 'MultiplayerServersController as multiplayermenu',
		backState: 'BACK_TO_MENU'
	})
	.state('menu.multiplayer.official', {
		url: '/mpofficial',
		templateUrl: '/ui/modModules/multiplayer/official.partial.html',
		controller: 'MultiplayerOfficialController as multiplayermenu',
		backState: 'BACK_TO_MENU'
	})
	.state('menu.multiplayer.featured', {
		url: '/mpfeatured',
		templateUrl: '/ui/modModules/multiplayer/featured.partial.html',
		controller: 'MultiplayerFeaturedController as multiplayermenu',
		backState: 'BACK_TO_MENU'
	})
	.state('menu.multiplayer.partner', {
		url: '/mppartner',
		templateUrl: '/ui/modModules/multiplayer/partner.partial.html',
		controller: 'MultiplayerPartnerController as multiplayermenu',
		backState: 'BACK_TO_MENU'
	})
	.state('menu.multiplayer.recent', {
		url: '/mprecent',
		templateUrl: '/ui/modModules/multiplayer/recent.partial.html',
		controller: 'MultiplayerRecentController as multiplayermenu',
		backState: 'BACK_TO_MENU'
	})
	.state('menu.multiplayer.favorites', {
		url: '/mpfavorites',
		templateUrl: '/ui/modModules/multiplayer/favorites.partial.html',
		controller: 'MultiplayerFavoritesController as multiplayermenu',
		backState: 'BACK_TO_MENU'
	})
	.state('menu.multiplayer.direct', {
		url: '/mpdirect',
		templateUrl: '/ui/modModules/multiplayer/direct.partial.html',
		controller: 'MultiplayerDirectController as multiplayermenu',
		backState: 'BACK_TO_MENU'
	})
	.state('menu.options.multiplayer', {
		url: '/multiplayer',
		templateUrl: '/ui/modules/options/multiplayer.partial.html',
		backState: 'BACK_TO_MENU',
	})

}])

.run(['$rootScope', function ($rootScope) {
  $rootScope.$on('MainMenuButtons', function (event, addButton) {
    addButton({
      translateid: 'ui.playmodes.multiplayer',
      icon: '/ui/modModules/multiplayer/icons/account-multiple.svg',
      targetState: 'menu.multiplayer.tos'
    })
  })

  // Voice Chat UI data
  $rootScope.multiplayer = $rootScope.multiplayer || {};
  $rootScope.multiplayer.voiceInputDevices = [];
  $rootScope.multiplayer.voiceOutputDevices = [];
  $rootScope.multiplayer.micLevel = 0;

  $rootScope.$on('VoiceChatDevicesReceived', function(event, devices) {
    $rootScope.multiplayer.voiceInputDevices = devices.input || [];
    $rootScope.multiplayer.voiceOutputDevices = devices.output || [];
    $rootScope.$applyAsync();
  });

  $rootScope.$on('VoiceChatMicLevel', function(event, level) {
    $rootScope.multiplayer.micLevel = Math.max(0, Math.min(100, level || 0));
    if (!$rootScope.$$phase) {
      $rootScope.$applyAsync();
    }
  });

  $rootScope.$on('$stateChangeSuccess', function(event, toState) {
    if (toState.name === 'menu.options.multiplayer') {
      bngApi.engineLua('if extensions.MPVoiceChat then extensions.MPVoiceChat.requestDevices() end');
    }
  });

	// Check for server to join
	$rootScope.$on('AutoJoinConfirmation', function(evt, data) {
		console.log('AutoJoinConfirmation',evt,data)
		var d = JSON.parse(decodeURI(data.message))
		confirmationMessage = `Do you want to connect to the server at ${d.ip}:${d.port}?`
		userConfirmed = window.confirm(confirmationMessage); 
		if (userConfirmed) {
			bngApi.engineLua(`MPCoreNetwork.connectToServer("${d.ip}","${d.port}","${d.sname}")`);
		}
	})

	var beammpUserInfo = document.createElement("div");
	beammpUserInfo.innerHTML = `
	<style>
.beammp-info-bar {
  z-index: 96;
  position: absolute;
  top: 3em;
  right: 0;
  padding-left: 1.2rem;
  display: flex;
  flex-direction: row;
  align-items: center;
  margin-right: 3em;
  padding-right: 10px;
  background-image: linear-gradient(67deg,transparent 1.05rem,#f60 1.15rem 1.4rem,#00000099 1.5rem);
  border-top-right-radius: var(--bng-corners-1);
  border-bottom-right-radius: var(--bng-corners-1);
  color: #fff;
  pointer-events: all;
  height: 2.9em;
  line-height: 2.9em;
  overflow: hidden;
}

.beammp-info-bar > span.divider {
  display: inline-block;
  width: .25rem;
  height: 1.8em;
  margin-left: .5rem;
  margin-right: .2rem;
  padding: 0!important;
  background-color: #f60;
  transform: skew(23deg);
}
	</style>
	<div class="beammp-info-bar">
		<img src="/ui/modModules/multiplayer/beammp.png" style="padding-left: .5rem; margin: 0px 8px;" height="32px">
		<span class="divider"></span>
		<img src="/ui/modModules/multiplayer/icons/account-multiple.svg" style="padding: 5px" height="22px">
		<span style="padding-left: 5px; padding-right: 10px;">Players: <strong id="beammpMetricsPlayers">${ beammpMetrics.players }</strong> </span>
		<img src="/ui/modModules/multiplayer/icons/dns.svg" style="padding: 5px" height="22px">
		<span style="padding-left: 5px;">Servers: <strong id="beammpMetricsServers">${ beammpMetrics.servers }</strong> </span>
		<span class="divider" id="beammp-profile-divider"></span>
		<img src="${userData.avatar}" id="beammp-profile-avatar" style="padding: 5px; border-radius: 50%;" height="22px">
		<span><strong id="beammp-profile-name">${userData.username}</strong> </span>
	</div>
	`
	var beammpModInfo = document.createElement("div");
	beammpModInfo.innerHTML = `
		<span class="divider"></span>
		<span style="margin-right: 5px;">
			<span>BeamMP v<span id="beammpModVersion">${beammpMetrics.beammpGameVer}</span></span>
		</span>
	`
	beammpModInfo.id = 'BeamMPVersionInject'

	$rootScope.$on('authReceived', function (event, data) {	
		//console.log(event, data)
		let nameElement = document.getElementById("beammp-profile-name")
		let avatarElement = document.getElementById("beammp-profile-avatar")
		let divider = document.getElementById("beammp-profile-divider")

		if (nameElement && avatarElement) {
			userData = {
				username: data.username,
				avatar: data.avatar,
				role: data.role,
				color: data.color,
				id: data.id
			}
		} else {
			return;
		}

		
		nameElement.textContent = data.username;
		avatarElement.src = data.avatar;

		if (data.avatar == undefined) {
			divider.style.display = 'none'
			nameElement.style.display = 'none'
			avatarElement.style.display = 'none'
		} else if (window.location.href.includes("menu.mainmenu")) {
			divider.style.display = 'block'

			nameElement.style.display = 'block';
			avatarElement.style.display = 'block';

			if (nameElement && avatarElement) {
				userData = {
					username: data.username,
					avatar: data.avatar,
					role: data.role,
					color: data.color,
					id: data.id
				}
			}

			nameElement.textContent = data.username;
			avatarElement.src = data.avatar;
		}
	})

	$rootScope.$on('BeamMPInfo', function (event, data) {
		beammpMetrics = data	
		injectVersion()
		document.getElementById("beammpMetricsPlayers").textContent = beammpMetrics.players
		document.getElementById("beammpMetricsServers").textContent = beammpMetrics.servers

		document.getElementById("beammpModVersion").textContent = beammpMetrics.beammpGameVer
	})

	function injectVersion() {
		if (document.querySelector('#vue-app > div.vue-app-main.click-through > div.info-bar > div.info-bar-stats'))
			document.querySelector('#vue-app > div.vue-app-main.click-through > div.info-bar > div.info-bar-stats').appendChild(beammpModInfo);
	}

	$rootScope.$on('$stateChangeSuccess', async function (event, toState, toParams, fromState, fromParams) {
		//console.log(`Going from "${fromState.name}" -> "${toState.name}"`)
		if (toState.name == "menu.mainmenu") {
			bngApi.engineLua('MPCoreNetwork.getLoginState()');
			bngApi.engineLua('MPCoreNetwork.sendBeamMPInfo()');
			beammpUserInfo.style.display = "block";
			let userinfo =  document.getElementsByTagName("body")[0].appendChild(beammpUserInfo).children[1]
			//console.log(userinfo)
			userinfo.style = null


			let nameElement = document.getElementById("beammp-profile-name");
			let avatarElement = document.getElementById("beammp-profile-avatar");
			let divider = document.getElementById("beammp-profile-divider");

			if (nameElement) {
				nameElement.style.display = "block";
				console.log('name shown', nameElement)
			}
			if (avatarElement) {
				avatarElement.style.display = "block";
			}
			if (divider) {
				divider.style.display = "block";
			}

			injectVersion()
		} else if (toState.name.includes("menu.multiplayer")) {
			bngApi.engineLua('MPCoreNetwork.sendBeamMPInfo()');
			beammpUserInfo.style.display = "block";
			let userinfo =  document.getElementsByTagName("body")[0].appendChild(beammpUserInfo).children[1]
			userinfo.style.marginRight = "0"
			userinfo.style.top = "0"
			userinfo.style.lineHeight = "2.4em"
			userinfo.style.height = "2.4em"


			let nameElement = document.getElementById("beammp-profile-name");
			let avatarElement = document.getElementById("beammp-profile-avatar");
			let divider = document.getElementById("beammp-profile-divider");

			if (nameElement) {
				nameElement.style.display = "none";
				console.log('name hidden', nameElement)
			}
			if (avatarElement) {
				avatarElement.style.display = "none";
			}
			if (divider) {
				divider.style.display = "none";
			}

			
			//console.log('Adding Mod Version Info')
			injectVersion()
		} else {
			beammpUserInfo.style.display = "none";
		}
  })
}])

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
		bngApi.engineLua(`MPCoreNetwork.openURL("`+url+`")`);
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
	
	//Workaround for sticky login UI
	$scope.$on('actuallyLoggedIn', function (event, data) {
		if (data == true) {
			$state.go('menu.multiplayer.servers');
		}
	});
	bngApi.engineLua('MPCoreNetwork.isLoggedIn()');
}])



/* //////////////////////////////////////////////////////////////////////////////////////////////
*	MAIN CONTROLLER
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerController', ['$scope', '$state', '$timeout', '$mdDialog', '$filter', 'ConfirmationDialog', 'toastr', '$translate',
function($scope, $state, $timeout, $mdDialog, $filter, ConfirmationDialog, toastr, $translate) {
	var vm = this;
	bngApi = bngApi;
	mdDialog = $mdDialog;

	$scope.switchServerView = function(view) {
		var serversTableContainer = document.getElementById("serversTableContainer");
		if (serversTableContainer) {
			serversTableContainer.scrollTop = 0;
		}
		serverView = view;
		$state.go('menu.multiplayer.servers');
		repopulateServerList();

		var buttons = document.getElementsByClassName("servers-btn");
		for (var i = 0; i < buttons.length; i++) {
			buttons[i].classList.remove("md-primary");
			buttons[i].classList.remove("md-raised");
		}
		document.getElementById(view+"-servers-btn").classList.add("md-primary");
		document.getElementById(view+"-servers-btn").classList.add("md-raised");

		if (view == "recents") {
			$translate('ui.multiplayer.clearRecent').then(function (translation) {
				var extra = document.getElementById("extra-button");

				extra.style.display = "";
				extra.innerText = translation;

				extra.onclick = function() {
					vm.clearRecents();
				};
			});
		} else if (view == "favorites") {
			$translate('ui.multiplayer.addCustomServer').then(function (translation) {
				var extra = document.getElementById("extra-button");

				extra.style.display = "";
				extra.innerText = translation;

				extra.onclick = function() {
					vm.showCustomServer();
				};
			});
		} else {
			const extraBtn = document.getElementById("extra-button");
			if (extraBtn) extraBtn.style.display = "none";
		}
	}

	// Trigger Warning Prompt
	$scope.$on('DownloadSecurityPrompt', function (event, data) {
		var o = true
		ConfirmationDialog.open(
			"ui.multiplayer.security.title", "ui.multiplayer.security.prompt",
			[
				{ label: "ui.multiplayer.security.no_return", key: false, isCancel: true },
				// { label: "Enter and don't show this again", key: true },
				{ label: "ui.multiplayer.security.accept_proceed", key: true, default: true },
			],
			{ class: "experimental" }
		).then(res => {
			if (res) {
				o = false
				bngApi.engineLua(`MPCoreNetwork.approveModDownload()`);
			}
			if (o) {
				o = false
				bngApi.engineLua(`MPCoreNetwork.rejectModDownload()`);
				vm.closeLoadingPopup()
			}			
		});
	})

	// Display the servers list page once the page is loaded
	$scope.$on('$stateChangeSuccess', async function (event, toState, toParams, fromState, fromParams) {
		bngApi.engineLua('MPCoreNetwork.getLoginState()');
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
		switch (data.dialogtype) {
			case "alert":
				if (mdDialogVisible) { return; }
				mdDialogVisible = true;

				$mdDialog.show({
					template: `
    <md-dialog aria-label="Alert Dialog"
               style="display: flex; flex-direction: column; padding: 24px;">
      <div style="font-size: 24px; color: white; margin-bottom: 16px;">
        ${data.title}
      </div>
      <div style="font-size: 16px; color: white; margin-bottom: 24px;">
        ${data.text}
      </div>
      <div style="display: flex; justify-content: flex-end;">
        <md-button ng-click="continueOffline()" class="md-primary" style="color: white;">Continue offline</md-button>
        <md-button ng-click="close()" class="md-primary" style="color: white;">
          ${data.okText}
        </md-button>
      </div>
    </md-dialog>
  `,
					controller: function ($scope, $mdDialog) {
						$scope.close = function () {
							$mdDialog.hide();
							mdDialogVisible = false;

							if (data.okJS !== undefined) {
								eval(data.okJS);
								return;
							} else if (data.okLua !== undefined) {
								bngApi.engineLua(data.okLua);
								return;
							}
						};
						$scope.continueOffline = function () {
							$mdDialog.hide();
							mdDialogVisible = false;
						};
					}
				}).then(function () {
					mdDialogVisible = false;
				});

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
		let modlist = document.getElementById('mod-download-list');
		if (modlist) {
			modlist.style.display = 'none';
		}

		vm.loadingStatus = ""
		vm.downloadingMods = [];
		$scope.$applyAsync();

		document.getElementById('loadingstatus-divider').style.display = "none";
		document.getElementById('LoadingStatus').innerText = "";

		//console.log('Clicked')
		var ip = document.getElementById('directip').value.trim();
		var port = document.getElementById('directport').value.trim();
		document.getElementById('LoadingServer').style.display = 'flex';
		bngApi.engineLua(`MPCoreNetwork.connectToServer("${ip}","${port}")`);
	};

	vm.closePopup =  function() {
		document.getElementById('addCustomFav').style.display = 'none';
	};
	vm.closeLoadingPopup =  function() {
		document.getElementById('OriginalLoadingStatus').removeAttribute("hidden");
		document.getElementById('LoadingStatus').setAttribute("hidden", "hidden");
		document.getElementById('LoadingStatus').innerText = "";
		document.getElementById('loadingstatus-divider').style.display = 'none';
		document.getElementById('LoadingServer').style.display = 'none';
		vm.downloadingMods.length = 0;
		vm.downloadingMods = [];
		vm.loadingStatus = "";
		lastModInfo = '';
		bngApi.engineLua('MPCoreNetwork.leaveServer()');
	};

	vm.showCustomServer = function() {
		document.getElementById('addCustomFav').style.display = 'flex';
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

	vm.directConnectFavorite = async function() {
		var ip = document.getElementById('directip').value.trim();
		var port = document.getElementById('directport').value.trim();

		var valid = (ip.length > 0) && (port.length > 0) && !isNaN(port)
		if (!valid) return;
		var name = new Date().toLocaleString()
		var server = {
			cversion: await getLauncherVersion(), ip: ip, location: "--", map: "", maxplayers: "0", players: "0",
			owner: "", playersList: "", sdesc: "", sname: name, strippedName: name,
			custom: true, port: port
		}
		favorites = await getFavorites();
		addFav(server)
		toastr.info($filter('translate')('ui.multiplayer.favoritedToast.description'), $filter('translate')('ui.multiplayer.favoritedToast.title'));
	}

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

	vm.downloadingMods = [];
	vm.loadingStatus = "";
	var lastModInfo = '';

	$scope.$on('LoadingInfo', function (event, data) {
		//console.log(vm, event, data)
		const loadingStatusElement = document.getElementById('LoadingStatus')
		//console.log(data.message)

		// Split the message into parts: mod number, mod name, progress, speed
		let modNumber = null;
		let modName = null;
		let progress = null;
		let speed = null;

		if (data.message.startsWith("Downloading Resource")) {
			let modlist = document.getElementById('mod-download-list');
			if (modlist) {
				modlist.style.display = 'block';
			}
			// Sample: 'Downloading Resource 1/10: Nissan 350z.zip (1.0%) at 12.8 Mbit/s'
			// Extract mod number, name, progress, and speed from the message
			const regex = /Downloading Resource (\d+\/\d+): (.+?) \((\d+\.\d+)%\)(?: at (.+))?/;
			const matches = data.message.match(regex);
			if (matches) {
				modNumber = matches[1];
				modName = matches[2];
				progress = matches[3];
				speed = matches[4] || '...';
			}
			//console.log(`Mod ${modNumber}: ${modName} - ${progress}% at ${speed}`);

			// Update current downloading mod info and if complete then push this mod into the downloaded mods info
			$scope.$apply(function() {
				// Update or add the current mod being downloaded
				const existingMod = vm.downloadingMods.find(mod => mod.name === modName);
				if (existingMod) {
					existingMod.progress = progress;
					existingMod.speed = speed;
				} else {
					// add this new mod to the beginning of the array
					vm.downloadingMods = [{ number: modNumber, name: modName, progress: progress, speed: speed }, ...vm.downloadingMods];
				}

				// If we switched to a new mod, mark the last one as done
				if (lastModInfo != '' && lastModInfo != modName) {
					const lastMod = vm.downloadingMods.find(mod => mod.name === lastModInfo);
					lastMod.progress = 100;
					lastMod.speed = $filter('translate')('ui.multiplayer.download.done');
					lastModInfo = modName;
				}
			});
		} else if (data.message.startsWith("Loading Resource")) {
			let modlist = document.getElementById('mod-download-list');
			if (modlist) {
				modlist.style.display = 'block';
			}
			// Sample: 'Loading Resource 1/70: Scintillacamaf.zip'
			const regex = /Loading Resource (\d+\/\d+): (.+)/;
			const matches = data.message.match(regex);
			if (matches) {
				modNumber = matches[1];
				modName = matches[2];
			}
			//console.log(`Mod ${modNumber}: ${modName} - Loading`);

			// Update current downloading mod info and if complete then push this mod into the downloaded mods info
			$scope.$apply(function() {
				// Update or add the current mod being downloaded
				const existingMod = vm.downloadingMods.find(mod => mod.name === modName);
				if (existingMod) {
					existingMod.progress = '100';
					existingMod.speed = $filter('translate')('ui.multiplayer.loading');
				} else {
					vm.downloadingMods = [{ number: modNumber, name: modName, progress: '100', speed: $filter('translate')('ui.multiplayer.loading') }, ...vm.downloadingMods];
				}
			});
		} else {
			if (data.message == "done") {
				vm.loadingStatus = $filter('translate')('ui.multiplayer.download.done');
				lastModInfo = '';
			} else {
				vm.loadingStatus = data.message;
			}

			document.getElementById('LoadingStatus').innerText = vm.loadingStatus;

			vm.downloadingMods = []
		
			document.getElementById('OriginalLoadingStatus').setAttribute("hidden", "hidden");
			loadingStatusElement.removeAttribute("hidden");
		}
		let divider = document.getElementById('loadingstatus-divider')
		if (divider) {
			divider.style.display = (vm.downloadingMods.length > 0 || vm.loadingStatus != "") ? "block" : "none";
		}

		$scope.$applyAsync();
	});


	vm.showMessage = function() {
		openExternalLink("https://beammp.gg/patreonbenefits");
	}

	$scope.$on('authReceived', function (event, data) {
		let nameElement = document.getElementById("serverlist-profile-name")
		let idElement = document.getElementById("serverlist-profile-id")
		let avatarElement = document.getElementById("serverlist-profile-avatar")

		if (Object.keys(data).length > 1) {
			let patreonText = $filter('translate')('ui.multiplayer.patreon.message.user')

			let banner = document.getElementById("topRightStatus")

			if (banner != null) {

				if (data.role == "EA") {
					patreonText = $filter('translate')('ui.multiplayer.patreon.message.ea')
					banner.children[0].style.display = "none"
					banner.style.color = "#fe8cff";
				} else {
					banner.children[0].style.display = ""
					banner.style.color = "white";
				}

				banner.firstChild.nodeValue = patreonText
				banner.children[0].style.color = "var(--bng-orange)"
				banner.children[0].children[0].innerText = $filter('translate')('ui.multiplayer.patreon.button.user')

				if (data.color != null)
					nameElement.style.backgroundColor = data.color
				else
					nameElement.style.backgroundColor = "rgba(0, 0, 0, 0)"

				nameElement.textContent = data.username;
				avatarElement.src = data.avatar;

				if (data.id != null) {
					nameElement.style.cursor = "pointer";
					nameElement.onclick = function () {
						openExternalLink("https://forum.beammp.com/u/" + data.username + "/summary");
					}

					idElement.textContent = "ID: " + data.id
					idElement.onclick = function () {
						bngApi.engineLua(`setClipboard("` + data.id + `")`);
						toastr.info("Copied ID to clipboard")
					}
					if (data.role != "USER") {
						idElement.style.marginTop = "0"
					} else {
						idElement.style.marginTop = "6px"
					}
				} else {
					idElement.textContent = "";
					nameElement.onclick = null;
					nameElement.style.cursor = "default";
				}
			}
		} else {
			nameElement.textContent = "";
			nameElement.style.backgroundColor = "rgba(0, 0, 0, 0)";
			idElement.textContent = "";
			avatarElement.removeAttribute("src");
		}
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
*	SERVERS TAB
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerServersController', ['$scope', '$state', '$timeout', '$filter',
function($scope, $state, $timeout, $filter) {

	var vm = this;
	let serverListOptions = JSON.parse(localStorage.getItem("serverListOptions"))

	if (serverListOptions != null && serverListOptions.serverVersions != null && serverListOptions.tags != null && serverListOptions.serverLocations != null) {
		vm.checkIsEmpty = serverListOptions.checkIsEmpty
		vm.checkIsNotEmpty = serverListOptions.checkIsNotEmpty
		vm.checkIsNotFull = serverListOptions.checkIsNotFull
		vm.checkModSlider = serverListOptions.checkModSlider
		vm.sliderMaxModSize = serverListOptions.sliderMaxModSize
		vm.selectMap = serverListOptions.selectMap
		vm.serverVersions = serverListOptions.serverVersions
		vm.tags = serverListOptions.tags
		vm.serverLocations = serverListOptions.serverLocations
		vm.searchText = ""
	} else {
		vm.checkIsEmpty = false
		vm.checkIsNotEmpty = false
		vm.checkIsNotFull = false
		vm.checkModSlider = false
		vm.sliderMaxModSize = 500 // in MB
		vm.selectMap = "Any map"
		vm.serverVersions = []
		vm.tags = []
		vm.serverLocations = []
		vm.searchText = ""
	}


	bngApi.engineLua('MPCoreNetwork.requestServerList()');

	// Go back to the main menu on exit
	vm.exit = function ($event) {
		if ($event) console.log('[MultiplayerServersController] exiting by keypress event %o', $event);
		$state.go('menu.mainmenu');
	};

	const serversTableContainer = document.getElementById("serversTableContainer");
	$scope.itemHeight = 24;
	$scope.buffer = 10;
	$scope.viewportHeight = serversTableContainer.clientHeight;
	$scope.selectedServerId = null;
	$scope.expandedRowHeight = 0;
	$scope.loadingShimmerCount = Math.ceil($scope.viewportHeight / $scope.itemHeight)

	$scope.onScroll = function() {
		const scrollTop = serversTableContainer.scrollTop;
		const total = $scope.serversArray.length;
		const itemHeight = $scope.itemHeight;
		const viewportHeight = $scope.viewportHeight;
		const buffer = $scope.buffer;
		
		const itemsPerView = Math.ceil(viewportHeight / itemHeight);
		const scrollRow = Math.floor(scrollTop / itemHeight);
		
		let startIndex = Math.max(0, scrollRow - Math.ceil(itemsPerView) + buffer);
		let endIndex = Math.min(total, scrollRow + Math.ceil(itemsPerView) + buffer);
		
		let beforeHeight = startIndex * itemHeight;
		let afterHeight = (total - endIndex) * itemHeight;

		if ($scope.selectedServerId && $scope.selectedIndex !== -1) {
			const selectedServerExists = $scope.serversArray.some(s => s.id === $scope.selectedServerId);
			if (selectedServerExists) {
				// when selectedIndex is not in the view anymore
				if ($scope.selectedIndex < startIndex || $scope.selectedIndex >= endIndex) {
					//if the selected server is above the current view
					if ($scope.selectedIndex < scrollRow) {		//this compense the height of the expanded row that is not rendered anymore
						beforeHeight += $scope.expandedRowHeight;
					}else{	//if the selected server is below the current view
						afterHeight += $scope.expandedRowHeight;
					}
				}
			}
		}

		$scope.visibleServers = $scope.serversArray.slice(startIndex, endIndex);
		$scope.beforeHeight = beforeHeight;
		$scope.afterHeight = afterHeight;
		if (!$scope.$$phase) $scope.$digest();
	};

	$scope.selectServer = function(server) {
		const serverId = server.id;
		highlightedServer = server.server
		if ($scope.selectedServerId === serverId) {
			$scope.selectedServerId = null;
			highlightedServer = null
			$scope.expandedRowHeight = 0;
		} else {
			$scope.selectedServerId = serverId;
			$scope.selectedIndex = $scope.serversArray.findIndex(s => s.id === $scope.selectedServerId);

			$timeout(function() {	//timeout because the serverInfoRow is not rendered yet
				const row = document.getElementById('ServerInfoRow');
				$scope.expandedRowHeight = row.offsetHeight;
			})
		}
		$scope.onScroll();
	};

	serversTableContainer.addEventListener('scroll', () => {
		$scope.onScroll();
	}, { passive: true });


	$scope.addFav = function(server) {
		addFav(server);	
		const index = $scope.serversArray.findIndex(s => 
			s.server.ip === server.ip && s.server.port === server.port
		);

		if (index !== -1) {
			$scope.serversArray[index].isFavorite = true;
			
			$scope.$applyAsync(); 

		}
	};
	$scope.removeFav = function(server) {
		removeFav(server);
		const index = $scope.serversArray.findIndex(s => 
			s.server.ip === server.ip && s.server.port === server.port
		);

		if (index !== -1) {
			$scope.serversArray[index].isFavorite = false;
			
			$scope.$applyAsync(); 

		}
	};

	$scope.sortTable = function(sortType, isNumber, dir) {
		const direction = dir || $scope.sortDirection || 1;
		$scope.sortDirection = -direction; // toggle direction

		$scope.serversArray.sort((a, b) => {
			const aVal = a.server[sortType];
			const bVal = b.server[sortType];
			if (isNumber) {
			return direction * (Number(aVal) - Number(bVal));
			} else {
			return direction * aVal.toString().localeCompare(bVal.toString(), undefined, { numeric: true });
			}
		});

		$scope.onScroll();
	}

	$scope.listPlayers = listPlayers;
	$scope.formatCodes = formatCodes;
	$scope.SmoothMapName = SmoothMapName;
	$scope.modCount = modCount;
	$scope.modList = modList;
	$scope.formatBytes = formatBytes;
	$scope.connect = connect;
	// Page loading timeout
	var timeOut = $timeout(function () {
		if (vm.loadingPage === true) {
			vm.loadTimeout = true;
		}
	}, 10000);

	// Called when the page is left
	$scope.$on('$destroy', function () {
		serverView = "";
		$timeout.cancel(timeOut);
		//console.log('[MultiplayerServersController] destroyed.');
		var buttons = document.getElementsByClassName("servers-btn");
		for (var i = 0; i < buttons.length; i++) {
			buttons[i].classList.remove("md-primary");
			buttons[i].classList.remove("md-raised");
		}
	});
	
	$scope.$on('onServerListReceived', async function (event, data) {
		
		servers = await receiveServers(data);
		recents = await getRecents();
		favorites = await getFavorites();

		vm.availableServerVersions = [];
		vm.availableMaps = [];
		vm.availableTags = [];
		vm.availableServerLocations = [];

		for (const server of servers) {
			if (!vm.availableServerVersions.includes("v" + server.version)) vm.availableServerVersions.push("v" + server.version);

			if (!vm.availableServerLocations.includes(server.location)) vm.availableServerLocations.push(server.location);

			var smoothMapName = SmoothMapName(server.map);

			if(!vm.availableMaps.includes(smoothMapName)) vm.availableMaps.push(smoothMapName);

			var serverTags = server.tags.split(",");
			for (const tag of serverTags) {
				if (!vm.availableTags.includes(tag.trim())) vm.availableTags.push(tag.trim());	
			}
		}

		
		vm.availableMaps.sort();
		vm.availableMaps.unshift("Any map");

		vm.availableServerVersions.sort();

		vm.availableServerLocations.sort();
		
		vm.availableTags.sort();

		vm.repopulate();
	});

	vm.repopulate = async function () {
		if (serverListOptions != null) {
			if (serverListOptions.checkIsEmpty && vm.checkIsNotEmpty) vm.checkIsEmpty = false;
			if (serverListOptions.checkIsNotEmpty && vm.checkIsEmpty) vm.checkIsNotEmpty = false;
		}


		await populateTable(
			$filter,
			$scope,
			servers,
			serverView,
			vm.searchText,
			vm.checkIsEmpty,
			vm.checkIsNotEmpty,
			vm.checkIsNotFull,
			vm.checkModSlider,
			vm.sliderMaxModSize,
			vm.selectMap,
			vm.serverVersions,
			vm.tags,
			vm.serverLocations		
		);

		serverListOptions = {
			checkIsEmpty: vm.checkIsEmpty,
			checkIsNotEmpty: vm.checkIsNotEmpty,
			checkIsNotFull: vm.checkIsNotFull,
			checkModSlider: vm.checkModSlider,
			sliderMaxModSize: vm.sliderMaxModSize,
			selectMap: vm.selectMap,
			serverVersions: vm.serverVersions,
			serverLocations: vm.serverLocations,
			tags: vm.tags
		};

		var activeFiltersText = "";
		if (vm.checkIsEmpty) activeFiltersText += $filter('translate')('ui.multiplayer.filters.empty') + ", ";
		if (vm.checkIsNotEmpty) activeFiltersText += $filter('translate')('ui.multiplayer.filters.notEmpty') + ", ";
		if (vm.checkIsNotFull) activeFiltersText += $filter('translate')('ui.multiplayer.filters.notFull') + ", ";
		if (vm.checkModSlider) activeFiltersText += $filter('translate')('ui.multiplayer.filters.modSize') + " < " + vm.sliderMaxModSize + "MB, ";
		if (vm.selectMap != "Any map") activeFiltersText += $filter('translate')('ui.multiplayer.filters.map') + ": " + vm.selectMap + ", ";
		if (vm.serverVersions.length > 0) activeFiltersText += $filter('translate')('ui.multiplayer.filters.serverVersions') + vm.serverVersions.join(", ") + ", ";
		if (vm.tags.length > 0) activeFiltersText += $filter('translate')('ui.multiplayer.filters.tags') + vm.tags.join(", ") + ", ";
		if (vm.serverLocations.length > 0) activeFiltersText += $filter('translate')('ui.multiplayer.filters.serverLocations') + vm.serverLocations.join(", ") + ", ";

		var clearFiltersButton = document.getElementById("clearFiltersButton");
		//var FiltersPrefix = document.getElementById("FiltersPrefix");

		if (activeFiltersText.length > 0) { 
			activeFiltersText = activeFiltersText.slice(0, -2);
			clearFiltersButton.style.display = "block"; 
			//FiltersPrefix.style.display = "block";
		} else {
			clearFiltersButton.style.display = "none";
			//FiltersPrefix.style.display = "none";
		}

		document.getElementById("activeFilters").innerText = activeFiltersText

		localStorage.setItem("serverListOptions", JSON.stringify(serverListOptions));
	};


	$scope.isFilterOverlayVisible = false;

	$scope.toggleFilterOverlay = function () {
		$scope.isFilterOverlayVisible = !$scope.isFilterOverlayVisible;
	};

	$scope.clearFilters = function () {
		vm.checkIsEmpty = false;
		vm.checkIsNotEmpty = false;
		vm.checkIsNotFull = false;
		vm.checkModSlider = false;
		vm.sliderMaxModSize = 500;
		vm.selectMap = "Any map";
		vm.serverVersions = [];
		vm.tags = [];
		vm.serverLocations = [];
		vm.repopulate();
	}

	repopulateServerList = function () { vm.repopulate().then(() => { }); }
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

globalThis.serverStyleMap = {
    '^0': 'color-0',
    '^1': 'color-1',
    '^2': 'color-2',
    '^3': 'color-3',
    '^4': 'color-4',
    '^5': 'color-5',
    '^6': 'color-6',
    '^7': 'color-7',
    '^8': 'color-8',
    '^9': 'color-9',
    '^a': 'color-a',
    '^b': 'color-b',
    '^c': 'color-c',
    '^d': 'color-d',
    '^e': 'color-e',
    '^f': 'color-f',
    '^l': 'bold',
    '^m': 'line-through',
    '^n': 'underline',
    '^o': 'italic'
};

function formatCodes(string, isdesc = false) {
    let result = '';
    let currentText = '';
    let classes = new Set();

	string = DOMPurify.sanitize(string)

    const tokens = string.split(/(\^.)/g);

    const flush = () => {
        if (!currentText) return;
        const classList = Array.from(classes);
        result += classList.length
            ? `<span class="${classList.join(' ')}">${currentText}</span>`
            : currentText;
        currentText = '';
    };

    for (const token of tokens) {
        if (/^\^.$/.test(token)) {
            flush();
            if (token === '^r') {
                classes.clear();
            } else if (isdesc && token === '^p') {
                currentText += '<br>';
            } else {
                const cls = globalThis.serverStyleMap?.[token];
                if (cls?.startsWith('color-')) {
                    [...classes].forEach(c => c.startsWith('color-') && classes.delete(c));
                    classes.add(cls);
                } else if (cls) {
                    classes.add(cls);
                }
            }
        } else {
            currentText += token;
        }
    }

    flush();
    return result;
}


function modCount(s) {
	if(s.length==0) return 0;
	return s.split(";").length-1;
}

function modList(s) {
	var modarray = s.split(';');
	
	// Sort the mod array alphabetically
  	modarray.sort();

	s = "";
	for (var i=0; i<modarray.length; i++){
		if (modarray[i] != '') {
			var modName = modarray[i].split('/').pop();
			modName = modName.replace(".zip","");
			s += modName;
			//if (i<modarray.length-2)
			s += ", ";
		}
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
	const exists = favorites.some(fav => 
        fav.ip === server.ip && fav.port === server.port
    );
	if (!exists) {
		server["addTime"] = Date.now();
		favorites.push(server);
		saveFav();
		if (!isUpdate) bngApi.engineLua('MPCoreNetwork.requestServerList()');
	}
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
        var encoded = localStorage.getItem("recents");
        var tmpRecents = [];
        if (encoded) {
            try {
                //decode
                tmpRecents = JSON.parse(Base64.decode(encoded));
            } catch (e) {
                try {
                    //fallback if decode fail
                    tmpRecents = JSON.parse(encoded);
                } catch (e2) {
                    tmpRecents = [];
                }
            }
        }
        recents = tmpRecents;
        resolve(tmpRecents);
    });
}

function addRecent(server) { // has to have name, ip, port
	server["addTime"] = Date.now();
	recents = recents.filter(rec => 
        !(rec.ip === server.ip && rec.port === server.port)
    );	// Remove server and add it back
	recents.push(server);
	recents = recents.slice(-1 * 50); //keep the last 50 entries
	localStorage.setItem("recents", Base64.encode(JSON.stringify(recents)));
}

globalThis.openExternalLink = function(url){
	bngApi.engineLua(`MPCoreNetwork.openURL("`+url+`")`);
}

// /!\ IMPORTANT /!\ //// TYPE 0 = Normal / 1 = Favorites / 2 = Recents
async function populateTable($filter, $scope, servers, tab, searchText = '', checkIsEmpty, checkIsNotEmpty, checkIsNotFull, checkModSlider, sliderMaxModSize, selectMap = 'Any map', SelectedServerVersions = [], tags = [], SelectedServerLocations = []) {
	$scope.serversTable = {};
	$scope.serversArray = [];
	var type = 0;
	if (tab == "favorites") type = 1;
	else if (tab == "recents") type = 2;
	let i = 0;
	for (const server of servers) {
		i += 1;
		if (!server) {
			break;
		}

		if (tab == "official" && !server.official) continue;
		if (tab == "featured" && !server.featured) continue;
		if (tab == "partner" && !server.partner) continue;

		//server.tags = "tag1,tag2"
		var serverTags = server.tags.toLowerCase().split(",").map(tag => tag.trim());

		var missingTag = false;
		for (let tag of tags) {
			if (!serverTags.includes(tag.toLowerCase())) missingTag = true;
		}

		if (missingTag) continue;

		var shown = true;
		var smoothMapName = SmoothMapName(server.map);
		var isFavorite = false;
		var isRecent = false;

		// Filter by search
		if (!server.strippedName.toLowerCase().includes(searchText.toLowerCase())) continue;
		
		// Filter by empty or full
		else if(checkIsEmpty && server.players > 0) continue;
		else if(checkIsNotEmpty && server.players == 0) continue;
		else if(checkIsNotFull && server.players >= parseInt(server.maxplayers)) continue;
		
		// Filter by mod size
		else if(checkModSlider && sliderMaxModSize * 1048576 < server.modstotalsize) continue;
	
		// Filter by map
		else if((selectMap != "Any map" && selectMap != smoothMapName)) continue;

		else if (SelectedServerVersions.length > 0 && !SelectedServerVersions.includes("v" + server.version)) continue;

		else if (SelectedServerLocations.length > 0 && !SelectedServerLocations.includes(server.location)) continue;

		// Favorite
		for (let tmpServer of favorites) if (tmpServer.ip == server.ip && tmpServer.port == server.port) isFavorite = true;
		if (type == 1 && !isFavorite) continue; // If it's favorite tab, we only show favorites

		// Recents
		for (let tmpServer of recents) if (tmpServer.ip == server.ip && tmpServer.port == server.port) {
			isRecent = true; 
			server.addTime = tmpServer.addTime;
		}
		if (type == 2 && !isRecent) continue; // Everything happens underneath for recents

		// If the server passed the filter

		$scope.serversTable[server.ip + ":" + server.port] = {server: server, isFavorite: isFavorite, isRecent: isRecent, name: server.sname, offline: false, custom: false};
		$scope.serversArray = Object.keys($scope.serversTable).map(function(key) {
			return $scope.serversTable[key];
		});

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

				var serverTags = (tmpServer1.tags || "").toLowerCase().split(",").map(tag => tag.trim());
				var missingTag = false;
				for (let tag of tags) {
					if (!serverTags.includes(tag.toLowerCase())) missingTag = true;
				}
				if (missingTag) continue;

				var smoothMapName = SmoothMapName(tmpServer1.map);

				if (searchText && !tmpServer1.strippedName?.toLowerCase().includes(searchText.toLowerCase())) continue;
				if (checkIsEmpty && tmpServer1.players > 0) continue;
				if (checkIsNotEmpty && tmpServer1.players == 0) continue;
				if (checkIsNotFull && tmpServer1.players >= parseInt(tmpServer1.maxplayers)) continue;
				if (checkModSlider && sliderMaxModSize * 1048576 < tmpServer1.modstotalsize) continue;
				if (selectMap != "Any map" && selectMap != smoothMapName) continue;
				if (SelectedServerVersions.length > 0 && !SelectedServerVersions.includes("v" + tmpServer1.version)) continue;
				if (SelectedServerLocations.length > 0 && !SelectedServerLocations.includes(tmpServer1.location)) continue;


				var offline = false;
				var custom = false;
				var name = tmpServer1.sname;
				if (!tmpServer1.custom) { name += " [OFFLINE]"; offline = true; }
				else { name += " [CUSTOM]"; custom = true }
				$scope.serversTable[tmpServer1.ip + ":" + tmpServer1.port] = {server: tmpServer1, isFavorite: type == 1, isRecent: type == 2, name: name, offline: offline, custom: custom};
				$scope.serversArray = Object.keys($scope.serversTable).map(function(key) {
					return $scope.serversTable[key];
				});
			}
		}
	}
	if (Object.keys($scope.serversTable).length === 0) {
    	$scope.serversArray = [];
	}	
	$scope.serversArray.forEach(server => {
		server.id = server.server.ip + ':' + server.server.port;
	});
	if (type == 2) $scope.sortTable("addTime", true, -1) ; else $scope.onScroll();
}

// Used to connect to the backend with ids
function connect(ip, port, name, skipModWarning = false) {
	console.log("Attempting to call connect to server...")
	// Add server to recents
	addRecent(highlightedServer);
	// Make sure the right content is displayed
	document.getElementById('OriginalLoadingStatus').removeAttribute("hidden");
	document.getElementById('LoadingStatus').setAttribute("hidden", "hidden");
	// Show the connecting screen
	document.getElementById('LoadingServer').style.display = 'flex'

	let modlist = document.getElementById('mod-download-list');
	if (modlist) {
		modlist.style.display = 'none';
	}

	const injector = angular.element(document.body).injector();
	const $controller = injector.get('$controller');
	const $rootScope = injector.get('$rootScope');
	const multiplayerCtrl = $controller('MultiplayerController', { $scope: $rootScope });

	multiplayerCtrl.loadingStatus = ""
	multiplayerCtrl.downloadingMods = [];
	$rootScope.$applyAsync();

	document.getElementById('loadingstatus-divider').style.display = "none";

	// Connect with ids
	bngApi.engineLua('MPCoreNetwork.connectToServer("' + ip + '", ' + port + ',"' + name + '", ' + skipModWarning + ')');
}

async function receiveServers(data) {
	var serversArray = new Array();
	var launcherVersion = await getLauncherVersion();
	// Parse the data to a nice looking Array
	for (var i = 0; i < data.length; i++) {
		var v = data[i]
		const [vMajor, vMinor] = v.cversion.split('.').map(Number);
		const [launcherMajor, launcherMinor] = launcherVersion.split('.').map(Number);

		// Compare the versions
		if (vMajor === launcherMajor && launcherMinor >= vMinor) {
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



// Base64 encoding and decoding functions
var Base64 = {
    encode: function(input) {
        return btoa(new TextEncoder().encode(input).reduce((data, byte) => data + String.fromCharCode(byte), ""));
    },
    decode: function(input) {
        return new TextDecoder().decode(Uint8Array.from(atob(input), c => c.charCodeAt(0)));
    }
};
