// Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
// Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
// SPDX-License-Identifier: AGPL-3.0-or-later

var highlightedServer
var servers = []
var favorites = []
var recents = []
var mdDialog
var mdDialogVisible = false
//userData = {
//	username: 'Username here',
//	avatar: '\\ui\\ui-vue\\src\\assets\\fonts\\bngIcons\\svg\\personSolid.svg',
//	role: 'USER',
//	color: '',
//	id: -1
//}
var userData = {}
var searchFilters = {}
var beammpMetrics = {
	players: "...", 
	servers: "...",
	beammpGameVer: "...",
	beammpLauncherVer: "..."
}
var serverView = ""
let repopulateServerList = async function() {

}

var officialMaps = [
	"Automation Test Track",
	"Autotest", 				// aux
	"Cliff",
	"Derby",
	"Driver Training",
	"East Coast Usa",
	"Garage V2", 				// garage
	"Glow City", 				// lightrunner
	"Gridmap", 					// unavailable
	"Gridmap V2",
	"Hirochi Raceway",
	"Industrial",
	"Italy",
	"Johnson Valley",
	"Jungle Rock Island",
	"Showroom V2", 				// aux
	"Small Island",
	"Smallgrid", 				// aux
	"Template", 				// aux
	"Utah",
	"West Coast Usa"
]

var searchFiltersScrollAmount = 0

// Per-tag thumbnail filename for all known server tags
// undefined - don't show in tiles menu
// string - show in tiles menu with specified file name & extension from /ui/modModules/multiplayer/tiles/
const tagThemes = {
	'Mature/18+': undefined,

	'Freeroam': '',
	'Roleplay': '',
	'Economy': '',
	'Traffic': '',
	'Drift': '',
	'Derby': '',
	'Crawling': '',

	'Racing': undefined,
	'Racing:NASCAR': undefined,
	'Racing:Track': undefined,
	'Racing:Drag': undefined,
	'Racing:Rally': undefined,
	'Touge': '',

	'Offroad': '',
	'Crawling': '',
	'Dakar': undefined,
	'Challenge': '',

	'Derby': undefined,
	'Arena': undefined,

	'Snow/Ice': undefined,
	'Rain': undefined,
	'Night': undefined,
	'Weather': undefined,

	'Gamemode': undefined,
	'Gamemode:Racing': '',
	'Gamemode:Rally': '',
	'Gamemode:Drag': '',
	'Gamemode:Derby': '',
	'Gamemode:Infection': '',
	'Gamemode:Cops-Robbers': '',
	'Gamemode:Delivery': '',
	'Gamemode:Sumo': '',

	'Scenarios': '',
	'Events': '',
	'Leaderboard': undefined,

	'Modded': '',
	'Mod:BeamPaint': undefined,
	'Mod:BeamJoy': undefined,
	'Mod:CEI': undefined,

	'Lang:English': undefined,
	'Lang:Russian': undefined,
	'Lang:French': undefined,
	'Lang:Spanish': undefined,
	'Lang:Portuguese': undefined,
	'Lang:German': undefined,
	'Lang:Polish': undefined,
	'Lang:Arabic': undefined,

	'Vanilla': '',
	'Moderated': ''
}

import('/ui/lib/ext/purify.min.js')

angular.module('BeamNG.ui')
.run(function($rootScope, $templateCache) {
	$rootScope.$on('$stateChangeStart', function(event, toState, toParams, fromState, fromParams) {
		if (toState.name === 'loading' || fromState.name === 'loading') {
		$templateCache.remove('/ui/modules/loading/loading.html')
		}
	})
})

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
	.state('menu.multiplayer.tiles', {
		url: '/mpdirect',
		templateUrl: '/ui/modModules/multiplayer/tiles.partial.html',
		controller: 'MultiplayerTilesController as multiplayermenu',
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

// Check for server to join
$rootScope.$on('AutoJoinConfirmation', function(evt, data) {
	console.log('AutoJoinConfirmation',evt,data)
	var d = JSON.parse(decodeURI(data.message))
	confirmationMessage = `Do you want to connect to the server at ${d.ip}:${d.port}?`
	userConfirmed = window.confirm(confirmationMessage)
	if (userConfirmed) {
		bngApi.engineLua(`MPCoreNetwork.connectToServer("${d.ip}","${d.port}","${d.sname}")`)
	}
})

let avatarFallbackClass = ""
//if (userData.avatar && userData.avatar === '\\ui\\ui-vue\\src\\assets\\fonts\\bngIcons\\svg\\personSolid.svg' || userData.avatar.includes("Q291bGQgbm90IGVzdGFibGlzaCBjb25uZWN0aW9u")) {
//	userData.avatar = '\\ui\\ui-vue\\src\\assets\\fonts\\bngIcons\\svg\\personSolid.svg'
//	avatarFallbackClass = 'style="filter:invert(100%) sepia(0%) saturate(22%) hue-rotate(36deg) brightness(104%) contrast(108%)"'
//}

var beammpUserInfo = document.createElement("div")
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
	font-family var(--fnt-defs);
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
.beammp-info-bar .section {
	display: inline-flex;
	padding: 0 0.25em 0 0.25em;
	flex-direction: row;
	flex-wrap: nowrap;
	gap: 0.25em;
	align-items: center;
}
</style>
<div class="beammp-info-bar">
	<img src="/ui/modModules/multiplayer/beammp_new_cropped.png" style="padding-left: .5rem; margin: 0px 8px; height: 2em;">
	<span class="divider"></span>
	<div class="section">
		<div class="section">
			<img src="/ui/modModules/multiplayer/icons/account-multiple.svg" height="22px">
			<span>Players: <span id="beammpMetricsPlayers">${ beammpMetrics.players }</span></span>
			<img style="margin-left: 0.25em;" src="/ui/modModules/multiplayer/icons/dns.svg" height="22px">
			<span>Servers: <span id="beammpMetricsServers">${ beammpMetrics.servers }</span></span>
		</div>
	</div>
	<span class="divider" id="beammp-profile-divider"></span>
	<div class="section">
		<img src="${userData.avatar}" ${avatarFallbackClass} id="beammp-profile-avatar" style="margin: 0 5px; border-radius: 50%; background-color: var(--bng-cool-gray-400);" height="22px">
		<span id="beammp-profile-name">${userData.username}</span>
	</div>
</div>
`
var beammpModInfo = document.createElement("div")
beammpModInfo.innerHTML = `
	<style>
		#BeamMPVersionInject {
			display: flex;
			align-items: center;

			span {
				padding: 0 0.25em 0 0.25em;
			};
			.divider {
				background-color: #f60;
				width: .25rem;
				height: 1.8em;
				margin-left: .5rem;
				margin-right: .2rem;
				display: inline-block;
				transform: skew(-23deg);
			};
			.divider, #beammpModVersion {
				padding: 0;
			};
		}
	</style>

	<span class="divider"></span>
	<span>
		<span>BeamMP v.<span id="beammpModVersion">${beammpMetrics.beammpGameVer}</span>
	</span>
`
beammpModInfo.id = 'BeamMPVersionInject'

$rootScope.$on('BeamMP_AuthReceived', function (event, data) {
	let nameElement = document.getElementById("beammp-profile-name")
	let avatarElement = document.getElementById("beammp-profile-avatar")
	let divider = document.getElementById("beammp-profile-divider")

	let isLoggedIn = false
	if (data.username) { // We'll only have a username if we've logged in
		isLoggedIn = true
	}

	//console.log(isLoggedIn, data)
	if (isLoggedIn) {
		userData = {
			username: data.username,
			avatar: data.avatar,
			role: data.role,
			color: data.color,
			id: data.id
		}

		nameElement.style.display = ''
		avatarElement.style.display = ''
		divider.style.display = ''
	} else {
		userData = {}

		nameElement.style.display = 'none'
		avatarElement.style.display = 'none'
		divider.style.display = 'none'

		return
	}

	if (!data.avatar || data.avatar.includes("Q291bGQgbm90IGVzdGFibGlzaCBjb25uZWN0aW9u")) {
		data.avatar = '\\ui\\ui-vue\\src\\assets\\fonts\\bngIcons\\svg\\personSolid.svg'
		avatarElement.style.filter = "invert(100%) sepia(0%) saturate(22%) hue-rotate(36deg) brightness(104%) contrast(108%)"
		avatarElement.src = '\\ui\\ui-vue\\src\\assets\\fonts\\bngIcons\\svg\\personSolid.svg'
	} else {
		avatarElement.style.filter = ""
	}

	if (!nameElement || !avatarElement) return

	
	nameElement.textContent = data.username
	avatarElement.src = data.avatar

	if (data.username == undefined) {
		divider.style.display = 'none'
		nameElement.style.display = 'none'
		avatarElement.style.display = 'none'
	} else if (window.location.href.includes("menu.mainmenu")) {
		divider.style.display = 'block'

		nameElement.style.display = 'block'
		avatarElement.style.display = 'block'

		if (nameElement && avatarElement) {
			userData = {
				username: data.username,
				avatar: data.avatar,
				role: data.role,
				color: data.color,
				id: data.id
			}
		}

		nameElement.textContent = data.username
		avatarElement.src = data.avatar
	}
})

$rootScope.$on('BeamMP_Info', function (event, data) {
	beammpMetrics = data	
	injectVersion()
	document.getElementById("beammpMetricsPlayers").textContent = beammpMetrics.players
	document.getElementById("beammpMetricsServers").textContent = beammpMetrics.servers

	document.getElementById("beammpModVersion").textContent = beammpMetrics.beammpGameVer
})

function injectVersion() {
	if (document.querySelector('#vue-app > div.vue-app-main.click-through > div.info-bar > div.info-bar-stats'))
		document.querySelector('#vue-app > div.vue-app-main.click-through > div.info-bar > div.info-bar-stats').appendChild(beammpModInfo)
}

$rootScope.$on('$stateChangeSuccess', async function (event, toState, toParams, fromState, fromParams) {
	//console.log(`Going from "${fromState.name}" -> "${toState.name}"`)

	if (toState.name == "menu.mainmenu") {
		bngApi.engineLua('MPCoreNetwork.getLoginState()')
		//console.log('Asking for BeamMP info from main menu or multiplayerPause')
		bngApi.engineLua('MPCoreNetwork.sendBeamMPInfo()')
		beammpUserInfo.style.display = "block"
		let userinfo =  document.getElementsByTagName("body")[0].appendChild(beammpUserInfo).children[1]
		//console.log(userinfo)
		userinfo.style = null


		let nameElement = document.getElementById("beammp-profile-name")
		let avatarElement = document.getElementById("beammp-profile-avatar")
		let divider = document.getElementById("beammp-profile-divider")

		if (nameElement) {
			nameElement.style.display = "block"
			//console.log('name shown', nameElement)
		}
		if (avatarElement) {
			avatarElement.style.display = "block"
		}
		if (divider) {
			divider.style.display = "block"
		}

		injectVersion()
	} else if (toState.name.includes("menu.multiplayer.")) {
		var searchFiltersPanel = document.getElementById('searchFiltersSidebar')
		if (toState.name === "menu.multiplayer.servers") {
			//console.log('Asking for BeamMP info because menu.multiplayer.servers was opened')
			bngApi.engineLua('MPCoreNetwork.sendBeamMPInfo()')
			if (searchFiltersPanel) searchFiltersPanel.style.display = ""
		} else {
			if (searchFiltersPanel) searchFiltersPanel.style.display = "none"
		}
		beammpUserInfo.style.display = "none"
		let userinfo = document.getElementsByTagName("body")[0].appendChild(beammpUserInfo).children[1]
		//userinfo.style.marginRight = "0"
		//userinfo.style.top = "0"
		//userinfo.style.lineHeight = "2.5em"
		//userinfo.style.height = "2.5em"
		userinfo.style.top = "5.625em"
		userinfo.style.marginRight = "0"
		userinfo.style.background = "none"
		userinfo.style.borderRadius = "var(--bng-corners-2)"


		let nameElement = document.getElementById("beammp-profile-name")
		let avatarElement = document.getElementById("beammp-profile-avatar")
		let divider = document.getElementById("beammp-profile-divider")

		if (nameElement) {
			nameElement.style.display = "none"
			//console.log('name hidden', nameElement)
		}
		if (avatarElement) {
			avatarElement.style.display = "none"
		}
		if (divider) {
			divider.style.display = "none"
		}

		
		//console.log('Adding Mod Version Info')
		injectVersion()
	} else {
		beammpUserInfo.style.display = "none"
	}
})
}])

/* //////////////////////////////////////////////////////////////////////////////////////////////
*	TOS CONTROLLER
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerTOSController', ['$scope', '$state', '$timeout', '$document', 
function($scope, $state, $timeout, $document) {
	'use strict'

	$scope.$on('$stateChangeSuccess', async function (event, toState, toParams, fromState, fromParams) {

		// Check if the user as acknowledged tos
		const tosAccepted = localStorage.getItem("tosAccepted")
		if (tosAccepted == "true") {
			$state.go('menu.multiplayer.servers')
			return
		}
	})

	// The lua setting need to be functional before we redirect, otherwise we'll land here again.
	// for that reason, we listen for the settings changed event that will ensure that the main menu will not get back here again
	$scope.validate = function () {
		localStorage.setItem("tosAccepted", "true")
		bngApi.engineLua(`MPConfig.acceptTos()`)
		$state.go('menu.multiplayer.servers')
	}

	$scope.openExternalLink = function(url) {
		bngApi.engineLua(`MPCoreNetwork.openURL("`+url+`")`)
	}

	bngApi.engineLua(`MPConfig.getConfig()`, (data) => {
		if (data != null) {
			if (!localStorage.getItem("tosAccepted")) {
				localStorage.setItem("tosAccepted", data.tos)
				$state.go('menu.multiplayer.servers')
			}
		}
	})
}])



/* //////////////////////////////////////////////////////////////////////////////////////////////
*	LAUNCHER CONNECTION CONTROLLER
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerLauncherController', ['$scope', '$state', '$timeout', '$document', 
function($scope, $state, $timeout, $document) {
	'use strict'
	// The lua setting need to be functional before we redirect, otherwise we'll land here again.
	// for that reason, we listen for the settings changed event that will ensure that the main menu will not get back here again
	$scope.connect = function () {
		bngApi.engineLua('MPCoreNetwork.connectToLauncher()')
	}
	
	$scope.$on('BeamMP_LauncherConnected', function (event, data) {
		$state.go('menu.multiplayer.login')
	})
	
	// The game's lua has an auto launcher reconnect in case
}])



/* //////////////////////////////////////////////////////////////////////////////////////////////
*	LOGIN CONTROLLER
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerLoginController', ['$scope', '$state', '$timeout', '$document', 
function($scope, $state, $timeout, $document) {
	'use strict'
	// The lua setting need to be functional before we redirect, otherwise we'll land here again.
	// for that reason, we listen for the settings changed event that will ensure that the main menu will not get back here again
	var vm = this
	$scope.login = function() {
		let credentials = {}
		credentials.username = document.getElementById('loginUsername').value.trim()
		credentials.password = document.getElementById('loginPassword').value.trim()
		if (credentials.username == "" || credentials.password == ""){
			document.getElementById('loginHeader').textContent = 'Missing credentials'
			return
		}	
		document.getElementById('loginPassword').value = ''
		document.getElementById('loginHeader').textContent = 'Attempting to log in...'
		bngApi.engineLua('MPCoreNetwork.login(' + bngApi.serializeToLua(credentials) + ')')
	}

	$scope.switchConnection = function() {
		var x = document.getElementById('LOGINERRORFIELD').textContent = ""
		var loginContainer = document.getElementById('LoginContainer')
		var guestContainer = document.getElementById('GuestContainer')
		if (loginContainer.style.display == "none") {
			loginContainer.style.display = 'block'
			guestContainer.style.display = 'none'
		} else {
			loginContainer.style.display = 'none'
			guestContainer.style.display = 'block'
		}
		
	}

	$scope.guestLogin = function() {
		bngApi.engineLua('MPCoreNetwork.login()')
	}
	
	$scope.$on('BeamMP_LoggedIn', function (event, data) {
		$state.go('menu.multiplayer.servers')
	})
	
	$scope.$on('BeamMP_LoginError', function (event, data) {
		var x = document.getElementById('LOGINERRORFIELD').textContent= data
	})
	
	//Workaround for sticky login UI
	$scope.$on('BeamMP_LoginState', function (event, data) {
		if (data == true) {
			$state.go('menu.multiplayer.servers')
		}
	})
	bngApi.engineLua('MPCoreNetwork.isLoggedIn()')
}])



/* //////////////////////////////////////////////////////////////////////////////////////////////
*	MAIN CONTROLLER
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerController', ['$scope', '$state', '$timeout', '$mdDialog', '$filter', 'ConfirmationDialog', 'toastr', '$translate', '$rootScope',
function($scope, $state, $timeout, $mdDialog, $filter, ConfirmationDialog, toastr, $translate, $rootScope) {
	var vm = this
	bngApi = bngApi
	mdDialog = $mdDialog

	$scope.dummy = undefined;

	$scope.beammpMetrics = beammpMetrics
	$scope.officialMaps = officialMaps

	$scope.switchToDirectConnect = function() {
		serverView = "direct"
		$state.go('menu.multiplayer.direct')

		var buttons = document.getElementsByClassName("servers-btn")
		for (var i = 0; i < buttons.length; i++) {
			buttons[i].classList.remove("bng-button-outline")
		}
		$timeout(function() {
			var button = document.getElementById("direct-connect-btn")
			button.classList.add("bng-button-outline")
		}, 200) // Unsure how to *properly* fix this. It works at >=5 fps
	}
	$scope.switchServerView = function(view) {
		var serversTableContainer = document.getElementById("serversTableContainer")
		if (serversTableContainer) {
			serversTableContainer.scrollTop = 0
		}
		serverView = view
		$state.go('menu.multiplayer.servers')
		repopulateServerList()

		var buttons = document.getElementsByClassName("servers-btn")
		for (var i = 0; i < buttons.length; i++) {
			buttons[i].classList.remove("bng-button-outline")
		}
		var button = document.getElementById(view+"-servers-btn")
		button.classList.add("bng-button-outline")

		var extra = document.getElementById("extra-button")
		if (extra)
		if (view == "recents") {
			$translate('ui.multiplayer.clearRecent').then(function (translation) {
				extra.style.display = ""
				extra.innerText = translation

				extra.onclick = function() {
					vm.clearRecents()
				}
			})
		} else if (view == "favorites") {
			$translate('ui.multiplayer.addCustomServer').then(function (translation) {
				extra.style.display = ""
				extra.innerText = translation

				extra.onclick = function() {
					vm.showCustomServer()
				}
			})
		} else {
			extra.style.display = "none"
		}
	}

	// Trigger Warning Prompt
	$scope.$on('BeamMP_DownloadSecurityPrompt', function (event, data) {
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
				bngApi.engineLua(`MPCoreNetwork.approveModDownload()`)
			}
			if (o) {
				o = false
				bngApi.engineLua(`MPCoreNetwork.rejectModDownload()`)
				vm.closeLoadingPopup()
			}			
		})
	})

	// Display the servers list page once the page is loaded
	$scope.$on('$stateChangeSuccess', async function (event, toState, toParams, fromState, fromParams) {
		bngApi.engineLua('MPCoreNetwork.getLoginState()')
		if (toState.url == "/multiplayer") {
			// local://local/ui/#/menu/multiplayer/mpservers
			document.getElementById('servers-btn').click()
		}

		// Check if the user as aknowledged tos
		const tosAccepted = localStorage.getItem("tosAccepted")
		//console.log(toState.url)
		if (tosAccepted != "true") {
			$state.go('menu.multiplayer.tos')
			return
		}

		// Check launcher is not connected
		const launcherConnected = await isLauncherConnected()
		if (!launcherConnected) {
			$state.go('menu.multiplayer.launcher')
			return
		}

		// Check if we are logged in
		const loggedIn = await isLoggedIn()
		if (!loggedIn) {
			$state.go('menu.multiplayer.login')
			return
		}
		
	})
	
	$scope.$on('BeamMP_LauncherConnectionLost', function (event, data) {
		$state.go('menu.multiplayer.launcher')
	})

	$scope.$on('BeamMP_ShowDialog', function (event, data) {
		switch (data.dialogtype) {
			case "alert":
				if (mdDialogVisible) { return }
				mdDialogVisible = true

				$mdDialog.show({
					template: `
						<md-dialog aria-label="Alert Dialog" style="
							display: flex;
							background-color: #252525;
							font-family: var(--fnt-defs);
							border-radius: var(--bng-corners-3);
							flex-direction: column;
							padding: 1em;
							text-shadow: none;
						">
							<div class="alertDialogTitle" style="
								font-family: Overpass var(--fnt-defs);
								font-size: 1.5em;
								text-align: center;
								font-weight: 600;
								color: white;
								margin-bottom: 16px;
							">
								${data.title}
							</div>
							<div style="
								font-size: 1em;
								color: oklch(92.5% 0 0);
								margin-bottom: 24px;
							">
								${data.text}
							</div>
							<div style="display: flex; justify-content: flex-end;gap:0.5em;">
								<button ng-click="continueOffline()" class="bng-button-link" style="text-transform: none">{{:: 'ui.multiplayer.mdDialog.continueOffline' | translate}}</button>
								<button ng-click="close()" class="bng-button-main" style="text-transform: none">${data.okText}</button>
							</div>
						</md-dialog>
					`,
					controller: function ($scope, $mdDialog) {
						$scope.close = function () {
							$mdDialog.hide()
							mdDialogVisible = false

							if (data.okJS !== undefined) {
								eval(data.okJS)
								return
							} else if (data.okLua !== undefined) {
								bngApi.engineLua(data.okLua)
								return
							}
						}
						$scope.continueOffline = function () {
							$mdDialog.hide()
							mdDialogVisible = false
						}
					}
				}).then(function () {
					mdDialogVisible = false
				})

				break
		}
	})

	$scope.$on('BeamMP_ServerJoined', function (event, data) {
		$state.go('play')
	})

	$scope.openProfile = function() {

	}

	$scope.copyName = function() {

	}

	$scope.logout = async function() {
		bngApi.engineLua(`MPCoreNetwork.logout()`)
		$state.go('menu.multiplayer.login')

		var accountSection = document.getElementById("serverlist-account-section")
		if (accountSection != null) {
			accountSection.style.display = "none"
		}

		var serverListCategories = document.getElementById("serverlist-categories")
		if (serverListCategories != null) {
			serverListCategories.style.display = "none"
		}

		var patreonButton = document.getElementById("patreonSidebarButton")
		if (patreonButton != null) {
			patreonButton.classList.remove("patreon-button-highlight")
			patreonButton.classList.remove("patreon-button-highlight-two")
		}
		var patreonButtonText = document.getElementById("patreonSidebarButtonSubtitle")
		if (patreonButtonText != null) patreonButtonText.innerHTML = ""

		var buttons = document.getElementsByClassName("servers-btn")
		for (var i = 0; i < buttons.length; i++) {
			buttons[i].classList.remove("bng-button-outline")
		}
	}

	vm.modelChanged = function($event) {
		var src = event.srcElement
		//console.log(src.value)
	}

	vm.refreshList = function() {
		//console.log("Attempting to refresh server list.")
		bngApi.engineLua('MPCoreNetwork.requestServerList()')
	}
	
	vm.clearRecents = function() {
		localStorage.removeItem("recents")
		repopulateServerList()
	}

	vm.directConnect = function() {
		let modlist = document.getElementById('mod-download-list')
		if (modlist) {
			modlist.style.display = 'none'
		}

		vm.loadingStatus = ""
		vm.downloadingMods = []
		$scope.$applyAsync()

		document.getElementById('LoadingStatus').innerText = ""

		//console.log('Clicked')
		var ip = document.getElementById('directip').value.trim()
		var port = document.getElementById('directport').value.trim()
		document.getElementById('LoadingServer').style.display = 'flex'
		bngApi.engineLua(`MPCoreNetwork.connectToServer("${ip || "127.0.0.1"}","${port || "30184"}")`)
	}

	vm.closePopup =  function() {
		document.getElementById('addCustomFav').style.display = 'none'
	}
	vm.closeLoadingPopup =  function() {
		document.getElementById('OriginalLoadingStatus').removeAttribute("hidden")
		document.getElementById('LoadingStatus').setAttribute("hidden", "hidden")
		document.getElementById('LoadingStatus').innerText = ""
		document.getElementById('LoadingServer').style.display = 'none'
		vm.downloadingMods.length = 0
		vm.downloadingMods = []
		vm.loadingStatus = ""
		lastModInfo = ''
		bngApi.engineLua('MPCoreNetwork.leaveServer()')
	}

	vm.showCustomServer = function() {
		document.getElementById('addCustomFav').style.display = 'flex'
	}

	vm.addCustomServer = async function() {
		var ip = document.getElementById('customFavIP')
		var port = document.getElementById('customFavPort')
		var name = document.getElementById('customFavName')
		var valid = (ip.value.length > 0) && (port.value.length > 0) && !isNaN(port.value)
		if (!valid) return
		var server = {
			cversion: await getLauncherVersion(), ip: ip.value, location: "--", map: "", maxplayers: undefined, players: undefined,
			owner: undefined, playersList: undefined, sdesc: "", sname: name.value, strippedName: name.value,
			custom: true, port: port.value,
			tags: ""
		}
		addFav(server)
		document.getElementById('addCustomFav').style.display = 'none'
		name.value = ''
		ip.value = ''
		port.value = ''
		repopulateServerList()
	}

	vm.directConnectFavorite = async function() {
		var ip = document.getElementById('directip').value.trim()
		var port = document.getElementById('directport').value.trim()

		var valid = (ip.length > 0) && (port.length > 0) && !isNaN(port)
		if (!valid) return
		var name = new Date().toLocaleString()
		var server = {
			cversion: await getLauncherVersion(), ip: ip, location: "--", map: "", maxplayers: "0", players: "0",
			owner: "", playersList: "", sdesc: "", sname: name, strippedName: name,
			custom: true, port: port
		}
		favorites = await getFavorites()
		addFav(server)
		toastr.info($filter('translate')('ui.multiplayer.favoritedToast.description'), $filter('translate')('ui.multiplayer.favoritedToast.title'))
	}

	vm.stateName = $state.current.name
	bngApi.engineLua('settings.requestState()')
	$scope.$on('$stateChangeSuccess', function (event, toState, toParams, fromState, fromParams) {
		vm.stateName = toState.name
	})

	vm.pasteClipboardToDirectIP = function() {
		bngApi.engineLua('getClipboard()', function (str) {
			$scope.$evalAsync(() =>  {
				if(!str.includes('.')) return

				var split = str.split(':')

				document.getElementById('directip').value = split[0]
				if (split.length==2) document.getElementById('directport').value = split[1]
			})
		})

	}

	vm.downloadingMods = []
	vm.loadingStatus = ""
	var lastModInfo = ''

	$scope.$on('LoadingInfo', function (event, data) {
		//console.log(vm, event, data)
		const loadingStatusElement = document.getElementById('LoadingStatus')
		//console.log(data.message)

		// Split the message into parts: mod number, mod name, progress, speed
		let modNumber = null
		let modName = null
		let progress = null
		let speed = null

		if (data.message.startsWith("Downloading Resource")) {
			let modlist = document.getElementById('mod-download-list')
			if (modlist) {
				modlist.style.display = 'block'
			}
			// Sample: 'Downloading Resource 1/10: Nissan 350z.zip (1.0%) at 12.8 Mbit/s'
			// Extract mod number, name, progress, and speed from the message
			const regex = /Downloading Resource (\d+\/\d+): (.+?) \((\d+\.\d+)%\)(?: at (.+))?/;
			const matches = data.message.match(regex)
			if (matches) {
				modNumber = matches[1]
				modName = matches[2]
				progress = matches[3]
				speed = matches[4] || '...'
			}
			//console.log(`Mod ${modNumber}: ${modName} - ${progress}% at ${speed}`)

			// Update current downloading mod info and if complete then push this mod into the downloaded mods info
			$scope.$apply(function() {
				// Update or add the current mod being downloaded
				const existingMod = vm.downloadingMods.find(mod => mod.name === modName)
				if (existingMod) {
					existingMod.progress = progress
					existingMod.speed = speed
				} else {
					// add this new mod to the beginning of the array
					vm.downloadingMods = [{ number: modNumber, name: modName, progress: progress, speed: speed }, ...vm.downloadingMods]
				}

				// If we switched to a new mod, mark the last one as done
				if (lastModInfo != '' && lastModInfo != modName) {
					const lastMod = vm.downloadingMods.find(mod => mod.name === lastModInfo)
					lastMod.progress = 100
					lastMod.speed = $filter('translate')('ui.multiplayer.download.done')
					lastModInfo = modName
				}
			})
		} else if (data.message.startsWith("Loading Resource")) {
			let modlist = document.getElementById('mod-download-list')
			if (modlist) {
				modlist.style.display = 'block'
			}
			// Sample: 'Loading Resource 1/70: Scintillacamaf.zip'
			const regex = /Loading Resource (\d+\/\d+): (.+)/
			const matches = data.message.match(regex)
			if (matches) {
				modNumber = matches[1]
				modName = matches[2]
			}
			//console.log(`Mod ${modNumber}: ${modName} - Loading`)

			// Update current downloading mod info and if complete then push this mod into the downloaded mods info
			$scope.$apply(function() {
				// Update or add the current mod being downloaded
				const existingMod = vm.downloadingMods.find(mod => mod.name === modName)
				if (existingMod) {
					existingMod.progress = '100'
					existingMod.speed = $filter('translate')('ui.multiplayer.loading')
				} else {
					vm.downloadingMods = [{ number: modNumber, name: modName, progress: '100', speed: $filter('translate')('ui.multiplayer.loading') }, ...vm.downloadingMods]
				}
			})
		} else {
			if (data.message == "done") {
				vm.loadingStatus = $filter('translate')('ui.multiplayer.loading')
				$timeout(function() {
					vm.loadingStatus = $filter('translate')('ui.multiplayer.download.done')
				}, 5000)
				lastModInfo = ''
			} else {
				vm.loadingStatus = data.message
			}

			document.getElementById('LoadingStatus').innerText = vm.loadingStatus

			vm.downloadingMods = []
		
			document.getElementById('OriginalLoadingStatus').setAttribute("hidden", "hidden")
			loadingStatusElement.removeAttribute("hidden")
		}

		$scope.$applyAsync()
	})


	vm.showMessage = function() {
		openExternalLink("https://beammp.gg/patreonbenefits")
	}
	
	let copyNameElement = document.getElementById("serverbrowser-account-copyname")
	let openProfileButton = document.getElementById('serverbrowser-account-openprofile')
	let copyIdElement = document.getElementById("serverbrowser-account-copyid")

	$scope.account = {
		username: userData.username,
		id: userData.id
	}

	$scope.openProfile = function() {
		openExternalLink("https://forum.beammp.com/u/" + userData.username + "/summary")
	}
	$scope.copyName = function() {
		if (userData.username) {
			bngApi.engineLua(`setClipboard("` + userData.username + `")`)
			toastr.info("Copied username to clipboard")
		} else {
			toastr.error("Failed to copy username")
		}
	}
	$scope.copyId = function() {
		if (userData.id) {
			bngApi.engineLua(`setClipboard("` + userData.id + `")`)
			toastr.info("Copied account ID to clipboard")
		} else {
			toastr.error("Failed to copy account ID")
		}
	}

	$scope.$on('BeamMP_AuthReceived', function (event, data) {
		let nameElement = document.getElementById("serverlist-profile-name")
		let roleTitleElement = document.getElementById("serverlist-profile-role-title")
		let avatarElement = document.getElementById("serverlist-profile-avatar")

		let isLoggedIn = false
		if (data.username) { // We'll only have a username if we've logged in
			isLoggedIn = true
		}


		var accountSection = document.getElementById("serverlist-account-section")
		var serverListCategories = document.getElementById("serverlist-categories")
		var accountDivider = document.getElementById("serverbrowser-account-divider")
		var accountAvatar = document.getElementById("serverlist-profile-avatar")
		if (isLoggedIn) {
			let patreonText = $filter('translate')('ui.multiplayer.patreon.message.user')
			let patreonButton = document.getElementById("patreonSidebarButton")
			var patreonButtonText = document.getElementById("patreonSidebarButtonSubtitle")

			if (accountSection) accountSection.style.display = ""
			if (serverListCategories) serverListCategories.style.display = ""
			if (accountDivider) accountDivider.style.display = ""
			if (accountAvatar) accountAvatar.style.display = ""


			if (data.role == "EA") {
				patreonText = $filter('translate')('ui.multiplayer.patreon.message.ea')

				patreonButton.classList.remove("patreon-button-highlight")
				patreonButton.classList.add("patreon-button-highlight-two")
				patreonButtonText.innerHTML = patreonText
			} else {

				if (patreonButton != null) {
					patreonButton.classList.remove("patreon-button-highlight-two")
					patreonButton.classList.add("patreon-button-highlight")
					patreonButtonText.innerText = patreonText
				}
			}

			if (nameElement) {
				nameElement.innerText = data.username
				if (data.color != null)
					roleTitleElement.style.backgroundColor = data.color
				else
					roleTitleElement.style.backgroundColor = "rgba(0, 0, 0, 0)"

				if (data.roleName) roleTitleElement.innerText = data.roleName.trim()
			}
			// Also check if avatar includes "Could not establish connection" in base64
			if (
				(data.avatar != undefined)
				&& !data.avatar.includes("Q291bGQgbm90IGVzdGFibGlzaCBjb25uZWN0aW9u")
				&& !data.avatar.includes("\\ui-vue\\src\\assets\\fonts\\bngIcons\\")
			) {
				//console.log('data.avatar properly exists. Using avatar data')
				//console.log(data.avatar)
				if (avatarElement) {
					avatarElement.src = data.avatar
					avatarElement.style.filter = ""
				}
			} else {
				//console.log('data.avatar does not exist or is using a fallback. Using fallback')
				//console.log(data.avatar)
				if (avatarElement) {
					avatarElement.src = '\\ui\\ui-vue\\src\\assets\\fonts\\bngIcons\\svg\\personSolid.svg'
					avatarElement.style.filter = "invert(100%) sepia(0%) saturate(22%) hue-rotate(36deg) brightness(104%) contrast(108%)"
				}
			}
		} else {
			if (nameElement != null) {
				nameElement.textContent = ""
				nameElement.style.backgroundColor = "rgba(0, 0, 0, 0)"
			}
			if (avatarElement != null) avatarElement.removeAttribute("src")
				
			if (accountSection) accountSection.style.display = "none"
			if (serverListCategories) serverListCategories.style.display = "none"
			if (accountDivider) accountDivider.style.display = "none"
			if (accountAvatar) accountAvatar.style.display = "none"
		}

		var buttons = document.getElementsByClassName("servers-btn")
		for (var i = 0; i < buttons.length; i++) {
			buttons[i].classList.remove("bng-button-outline")
		}

		$scope.account = userData
	})

	vm.exit = function ($event) {
		console.log(`vm.exit triggered in ${$scope.name}`)
		if ($event)
		console.log('[MultiplayerController] exiting by keypress event %o', $event)
		$state.go('menu.mainmenu')
	}

	var timeOut = $timeout(function() {
		if (vm.loadingPage === true) {
			vm.loadTimeout = true
		}
	}, 10000)

	$scope.$on('$destroy', function () {
		$timeout.cancel(timeOut)
		fancySync.disconnect()
		//console.log('[MultiplayerController] destroyed.')
	})

	$scope.formatBytes = formatBytes

	$scope.availableServerVersions = []
	$scope.availableMaps = []
	$scope.availableTags = []
	$scope.formattedTags = []
	$scope.availableServerLocations = []

	$scope.selectedServerLocations = []
	$scope.selectedMaps = []
	$scope.selectedTags = []
	$scope.selectedServerVersions = []

	vm.playerCountMin = 0
	vm.playerCountMax = 64

	vm.sliderMaxModSize = 80530 // in MB

	searchFiltersScrollAmount = 0
	
	const serverFiltersSidebar = document.getElementById('searchFilters')
	serverFiltersSidebar.addEventListener('scroll', () => {
		if (serverFiltersSidebar.scrollTop !== 0) {
			searchFiltersScrollAmount = serverFiltersSidebar.scrollTop
			//console.log(`Search filters list scrolled to: ${searchFiltersScrollAmount}px`)
		}
	}, { passive: true })

	function updateServerFilters(newSearchFilters) {
		//console.log('About to update server filters. scrollTop is:', searchFiltersScrollAmount)

		searchFilters = newSearchFilters
		localStorage.setItem("serverListOptions", JSON.stringify(newSearchFilters))
		setSearchFilters(Object.values(searchFilters))
		$scope.$emit('searchFiltersUpdated')
		repopulateServerList()
	}

	var playerCountMin = Number(vm.playerCountMin)
	var playerCountMax = Number(vm.playerCountMax)
	$scope.updatePlayerCountRange = async function() {
		playerCountMin = Number(vm.playerCountMin)
		playerCountMax = Number(vm.playerCountMax)
		$timeout(function() {
			if (
				playerCountMin !== searchFilters.playerCountMin ??
				playerCountMax !== searchFilters.playerCountMax
			) {
				var activeFilters = JSON.parse(localStorage.getItem("serverListOptions"))

				activeFilters.playerCountMin = playerCountMin
				activeFilters.playerCountMax = playerCountMax

				updateServerFilters(activeFilters)
			}
		}, 250)
	}

	var maxModSize = vm.sliderMaxModSize
	$scope.updateMaxModSize = function () {
		maxModSize = vm.sliderMaxModSize
		$timeout(function() {
			if (maxModSize !== searchFilters.sliderMaxModSize) {
				var activeFilters = JSON.parse(localStorage.getItem("serverListOptions"))

				activeFilters.sliderMaxModSize = maxModSize

				updateServerFilters(activeFilters)
			}
		}, 500)
	}

	$scope.$on('BeamMP_ServerListReceived', async function (event, data) {
		setSearchFilters(await getSearchFilterData(data))
	})
	$scope.$on('reloadSearchFilters', function (event, data) {
		//console.log('received reloadSearchFilters with data: ', data)
		setSearchFilters(data)
	})
	function setSearchFilters(serverSearchFilters) {
		$timeout(function() {
			$scope.availableServerLocations = serverSearchFilters[0]
			$scope.availableMaps = serverSearchFilters[1]
			$scope.availableTags = serverSearchFilters[2]
			$scope.formattedTags = serverSearchFilters[3]
			$scope.availableServerVersions = serverSearchFilters[4]

			$scope.selectedServerLocations = serverSearchFilters[5]
			$scope.selectedMaps = serverSearchFilters[6]
			$scope.selectedTags = serverSearchFilters[7]
			$scope.selectedServerVersions = serverSearchFilters[8]

			vm.playerCountMin = serverSearchFilters[9]
			vm.playerCountMax = serverSearchFilters[10]

			vm.sliderMaxModSize = serverSearchFilters[11]
		})
	}
	$scope.resetSearchFilters = function () {
		searchFilters.playerCountMin = 0
		searchFilters.playerCountMax = 64
		searchFilters.sliderMaxModSize = 80530
		searchFilters.selectedMaps = []
		searchFilters.selectedServerVersions = []
		searchFilters.selectedTags = []
		searchFilters.selectedServerLocations = []
		searchFilters.matchAll = true

		localStorage.setItem('serverListOptions', JSON.stringify(searchFilters))
		//console.log('Cleared filters, repopulating...')
		$scope.$emit('searchFiltersUpdated')
		repopulateServerList()
	}

	$scope.toggleTag = function(tag) {
		tag.raw = tag.raw.trim()
		var activeFilters = JSON.parse(localStorage.getItem("serverListOptions"))
		var isTagActive = -1
		//console.log(`Attempting to toggle tag ${tag.raw}`)
		for (var i = 0; i < activeFilters.selectedTags.length; i++) {
			//console.log(`Checking tag ${activeFilters.tags[i].raw}`)
			if (activeFilters.selectedTags[i].raw === tag.raw) {
				//console.log(`We have a match everybody!! isTagActive=true on ${tag.raw}`)
				isTagActive = i
				break
			}
		}
		if (isTagActive > -1) {
			//console.log(`Active tags includes ${tag.raw}, removing`)
			activeFilters.selectedTags.splice(isTagActive, 1)
		} else {
			//console.log(`Active tags does not include ${tag.raw}, adding`)
			tag.active = true
			activeFilters.selectedTags.push(tag)
		}

		updateServerFilters(activeFilters)
	}
	$scope.toggleSimple = function(category, value) {
		var activeFilters = JSON.parse(localStorage.getItem("serverListOptions"))

		switch (category) {
			case 'serverLocation':
				if (activeFilters.selectedServerLocations.includes(value)) {
					activeFilters.selectedServerLocations.splice(activeFilters.selectedServerLocations.findIndex(element => element === value), 1)
				} else {
					activeFilters.selectedServerLocations.push(value)
				}
				break
			case 'map':
				if (activeFilters.selectedMaps.includes(value)) {
					activeFilters.selectedMaps.splice(activeFilters.selectedMaps.findIndex(element => element === value), 1)
				} else {
					activeFilters.selectedMaps.push(value)
				}
				break
			case 'serverVersion':
				if (activeFilters.selectedServerVersions.includes(value)) {
					activeFilters.selectedServerVersions.splice(activeFilters.selectedServerVersions.findIndex(element => element === value), 1)
				} else {
					activeFilters.selectedServerVersions.push(value)
				}
				break
		}

		updateServerFilters(activeFilters)
	}
	$scope.setSavedScrollPos = async function() {
		$timeout(function() {
			const scrollAmt = searchFiltersScrollAmount
			//console.log('Setting saved scroll position in #searchFilters. Saved scroll position:', scrollAmt)
			document.getElementById('searchFilters').scrollTop = scrollAmt
			searchFiltersScrollAmount = scrollAmt
		})
	}

	$scope.getVueIconPath = getVueIconPath

	// This JS is independent from the .mp-fancy-blur elements. 
	// But, the CSS is still single-purpose. Haven't found a good solution for the CSS yet.
	var fancySync = new MutationObserver(function() {
		var mainMenuBg = document.querySelector('.background-image')
		if (mainMenuBg == null) return false
		
		var urls = mainMenuBg.getAttribute('style').match(/url\(.*?\)/ig)
		if (!urls, urls.length == 0) return false

		var incoming = urls[urls.length - 1]
		//console.log('Incoming bg url: '+incoming)
		var blurredBg = incoming.replace('.jpg', '_blur.jpg')

		document.querySelectorAll('.mp-fancy-blur').forEach(el => {
			el.style.setProperty('--mp-fancy-blur-src', blurredBg)
		})
		return true
	})

	var mainMenuBg = document.querySelector('.background-image')
	if (mainMenuBg) {
		fancySync.observe(mainMenuBg, { attributes: true, attributeFilter: ['style'] })
	}
}])

/* //////////////////////////////////////////////////////////////////////////////////////////////
*	TILES CONTROLLER
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerTilesController', ['$scope', '$state', '$timeout', '$document', 
function($scope, $state, $timeout, $document) {
	'use strict'

	var vm = this

	vm.availableServerVersions = []
	vm.availableMaps = []
	vm.availableTags = []
	vm.formattedTags = []
	vm.availableServerLocations = []

	$scope.$on('BeamMP_ServerListReceived', async function (event, data) {
		setSearchFilters(await getSearchFilterData(data))
	})
	$scope.$on('reloadSearchFilters', function (event, data) {
		//console.log('received reloadSearchFilters with data: ', data)
		setSearchFilters(data)
	})
	function setSearchFilters(serverSearchFilters) {
		vm.availableServerLocations = serverSearchFilters[0]
		vm.availableMaps = serverSearchFilters[1]
		vm.availableTags = serverSearchFilters[2]
		vm.formattedTags = serverSearchFilters[3]
		vm.availableServerVersions = serverSearchFilters[4]
	}
	bngApi.engineLua('MPCoreNetwork.requestServerList()')

	$scope.getTileBackground = function(filename) {
		if (filename && filename!=='') {
			return `'url("/ui/modModules/multiplayer/tiles/${filename}")'`
		} else {
			return `'url("/ui/images/appDefault.png")'`
		}
	}

	$scope.viewServersWithTag = function(tag) {
		console.log('Viewing servers with the following tag:', tag)
		
		searchFilters.selectedTags = [tag]

		let activeFilters = JSON.parse(localStorage.getItem("serverListOptions"))
		activeFilters.selectedTags = [tag]
		localStorage.setItem("serverListOptions", JSON.stringify(activeFilters))

		$scope.switchServerView('')
	}

	$scope.switchServerView = function(view) {
		var serversTableContainer = document.getElementById("serversTableContainer")
		if (serversTableContainer) {
			serversTableContainer.scrollTop = 0
		}
		serverView = view
		$state.go('menu.multiplayer.servers')
		repopulateServerList()

		var buttons = document.getElementsByClassName("servers-btn")
		for (var i = 0; i < buttons.length; i++) {
			buttons[i].classList.remove("bng-button-outline")
		}
		var button = document.getElementById(view+"-servers-btn")
		button.classList.add("bng-button-outline")

		var extra = document.getElementById("extra-button")
		if (extra)
		if (view == "recents") {
			$translate('ui.multiplayer.clearRecent').then(function (translation) {
				extra.style.display = ""
				extra.innerText = translation

				extra.onclick = function() {
					vm.clearRecents()
				}
			})
		} else if (view == "favorites") {
			$translate('ui.multiplayer.addCustomServer').then(function (translation) {
				extra.style.display = ""
				extra.innerText = translation

				extra.onclick = function() {
					vm.showCustomServer()
				}
			})
		} else {
			extra.style.display = "none"
		}
	}
	
}])


/* //////////////////////////////////////////////////////////////////////////////////////////////
*	SERVERS TAB
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerServersController', ['$scope', '$state', '$timeout', '$filter',
function($scope, $state, $timeout, $filter) {

	var vm = this
	$scope.$on('searchFiltersUpdated', function(event, data) {
		updateSearchFilters()
	})

	const defaultSearchFilters = {
			playerCountMin: 0,
			playerCountMax: 250,
			sliderMaxModSize: 80530, // in MB
			selectMap: [],
			serverVersions: [],
			tags: [],
			serverLocations: [],
			matchAll: true,
			searchText: "",

			formattedTags: [],

			selectedServerLocations: [],
			selectedMaps: [],
			selectedTags: [],
			selectedServerVersions: []
	}

	function migrateLegacyFilters() {
		var legacyFilters = JSON.parse(localStorage.getItem("serverListOptions"))
		if (legacyFilters) {
			legacyFilters.checkIsEmpty = undefined
			legacyFilters.checkIsNotEmpty = undefined
			legacyFilters.checkIsNotFull = undefined
			legacyFilters.checkModSlider = undefined
			legacyFilters.sliderMaxModSize = defaultSearchFilters.sliderMaxModSize //prefere to force it to this because the old value was likely not set by the user anyway
			legacyFilters.selectedMaps = [] //dont save the old selected map
			legacyFilters.selectMap = undefined
			
			if (!legacyFilters.selectedTags){
				legacyFilters.selectedTags = []
				legacyFilters.tags.forEach(element => {
					legacyFilters.selectedTags.push(formatRawTag(element))
				});
				legacyFilters.tags = defaultSearchFilters.tags
			}
			if (!legacyFilters.selectedServerVersions){
				legacyFilters.selectedServerVersions = []
				legacyFilters.serverVersions.forEach(element => {
					legacyFilters.selectedServerVersions.push(element)
				});
				legacyFilters.serverVersions = defaultSearchFilters.serverVersions
			}
			if (!legacyFilters.selectedServerLocations){
				legacyFilters.selectedServerLocations = []
				legacyFilters.serverLocations.forEach(element => {
					legacyFilters.selectedServerLocations.push(element)
				});
				legacyFilters.serverLocations = defaultSearchFilters.serverLocations
			}
			legacyFilters.playerCountMin = defaultSearchFilters.playerCountMin
			legacyFilters.playerCountMax = defaultSearchFilters.playerCountMax
			legacyFilters.matchAll = defaultSearchFilters.matchAll
			legacyFilters.searchText = defaultSearchFilters.searchText
			legacyFilters.formattedTags = defaultSearchFilters.formattedTags

			localStorage.setItem("serverListOptions", JSON.stringify(legacyFilters))
		}
	}

	function updateSearchFilters() {
		searchFilters = JSON.parse(localStorage.getItem("serverListOptions")) ?? defaultSearchFilters
		if (searchFilters.checkIsEmpty != undefined) migrateLegacyFilters()

		vm.playerCountMin = searchFilters.playerCountMin
		vm.playerCountMax = searchFilters.playerCountMax
		vm.sliderMaxModSize = searchFilters.sliderMaxModSize
		vm.selectMap = searchFilters.selectedMaps
		vm.serverVersions = searchFilters.selectedServerVersions
		vm.tags = searchFilters.selectedTags
		vm.serverLocations = searchFilters.selectedServerLocations
		vm.matchAll = searchFilters.matchAll
		vm.searchText = searchFilters.searchText
		vm.formattedTags = searchFilters.formattedTags
		vm.selectedTags = searchFilters.selectedTags
	}
	updateSearchFilters()
	
	vm.updateSearchText = function () {
		var activeFilters = JSON.parse(localStorage.getItem("serverListOptions"))

		activeFilters.searchText = vm.searchText

		searchFilters = activeFilters
		localStorage.setItem("serverListOptions", JSON.stringify(activeFilters))
		$scope.$emit('searchFiltersUpdated')
		repopulateServerList()
	}

	//bngApi.engineLua('MPCoreNetwork.requestServerList()')

	// Go back to the main menu on exit
	vm.exit = function ($event) {
		console.log(`vm.exit triggered in ${$scope.name}`)
		if ($event) console.log('[MultiplayerServersController] exiting by keypress event %o', $event)
		$state.go('menu.mainmenu')
	}

	const serversTableContainer = document.getElementById("serversTableContainer")
	$scope.itemHeight = 24
	$scope.buffer = 10
	$scope.viewportHeight = serversTableContainer.clientHeight
	$scope.selectedServerId = null
	$scope.expandedRowHeight = 0
	$scope.loadingShimmerCount = Math.ceil($scope.viewportHeight / $scope.itemHeight)

	$scope.onScroll = async function() {
		//console.log('onScroll fired')
		if ($scope.viewportHeight === 0) $scope.viewportHeight = serversTableContainer.clientHeight

		const scrollTop = serversTableContainer.scrollTop
		const total = $scope.serversArray.length
		const itemHeight = $scope.itemHeight
		const viewportHeight = $scope.viewportHeight
		const buffer = $scope.buffer
		
		//console.log(`viewportHeight:${viewportHeight} itemHeight:${itemHeight}`)
		const itemsPerView = Math.ceil(viewportHeight / itemHeight)
		const scrollRow = Math.floor(scrollTop / itemHeight)
		
		//console.log(`scrollRow:'${scrollRow}' itemsPerView:'${itemsPerView}'`)
		let startIndex = Math.max(0, scrollRow - Math.ceil(itemsPerView) + buffer)
		let endIndex = Math.min(total, scrollRow + Math.ceil(itemsPerView) + buffer)
		//console.log(`start:'${startIndex}' end:'${endIndex}'`)
		
		let beforeHeight = startIndex * itemHeight
		let afterHeight = (total - endIndex) * itemHeight

		if ($scope.selectedServerId && $scope.selectedIndex !== -1) {
			const selectedServerExists = $scope.serversArray.some(s => s.id === $scope.selectedServerId)
			if (selectedServerExists) {
				// when selectedIndex is not in the view anymore
				if ($scope.selectedIndex < startIndex || $scope.selectedIndex >= endIndex) {
					//if the selected server is above the current view
					if ($scope.selectedIndex < scrollRow) {		//this compense the height of the expanded row that is not rendered anymore
						beforeHeight += $scope.expandedRowHeight
					} else {	//if the selected server is below the current view
						afterHeight += $scope.expandedRowHeight
					}
				}
			}
		}

		$scope.visibleServers = $scope.serversArray.slice(startIndex, endIndex)
		$scope.beforeHeight = beforeHeight
		$scope.afterHeight = afterHeight
		if (!$scope.$$phase) {
			$scope.$digest()
		}
	}

	$scope.selectServer = function(server) {
		const serverId = server.id
		//console.log('Server '+serverId+' was selected')
		//console.log(server.server)
		highlightedServer = server.server
		if ($scope.selectedServerId === serverId) {
			$scope.selectedServerId = null
			server.server.formattedTags = undefined
			highlightedServer = null
			$scope.expandedRowHeight = 0
		} else {
			$scope.selectedServerId = serverId
			server.server.formattedTags = formatServerTags(server.server.tags)
			$scope.selectedIndex = $scope.serversArray.findIndex(s => s.id === $scope.selectedServerId)

			$timeout(function() {	//timeout because the serverInfoRow is not rendered yet
				const row = document.getElementById('ServerInfoRow')
				$scope.expandedRowHeight = row.offsetHeight
			})
		}
		$scope.onScroll()
	}

	serversTableContainer.addEventListener('scroll', () => {
		$scope.onScroll()
	}, { passive: true })


	$scope.addFav = function(server) {
		addFav(server)
		const index = $scope.serversArray.findIndex(s => 
			s.server.ip === server.ip && s.server.port === server.port
		)

		if (index !== -1) {
			$scope.serversArray[index].isFavorite = true
			
			$scope.$applyAsync()

		}
	}
	$scope.removeFav = function(server) {
		removeFav(server)
		const index = $scope.serversArray.findIndex(s => 
			s.server.ip === server.ip && s.server.port === server.port
		)

		if (index !== -1) {
			$scope.serversArray[index].isFavorite = false
			
			$scope.$applyAsync()

		}
	}

	$scope.sortTable = function(sortType, isNumber, dir) {
		const direction = dir || $scope.sortDirection || 1
		$scope.sortDirection = -direction // toggle direction

		$scope.serversArray.sort((a, b) => {
			const aVal = a.server[sortType]
			const bVal = b.server[sortType]
			if (isNumber) {
			return direction * (Number(aVal) - Number(bVal))
			} else {
			return direction * aVal.toString().localeCompare(bVal.toString(), undefined, { numeric: true })
			}
		})

		$scope.onScroll()
	}

	$scope.listPlayers = listPlayers
	$scope.formatCodes = formatCodes
	$scope.SmoothMapName = SmoothMapName
	$scope.modCount = modCount
	$scope.modList = modList
	$scope.formatBytes = formatBytes
	$scope.connect = connect
	$scope.customToNumber = customToNumber
	$scope.customIsFinite = customIsFinite
	$scope.customIsString = customIsString
	$scope.getTagCount = getTagCount
	$scope.formatServerTags = formatServerTags

	// Page loading timeout
	var timeOut = $timeout(function () {
		if (vm.loadingPage === true) {
			vm.loadTimeout = true
		}
	}, 10000)

	// Called when the page is left
	$scope.$on('$destroy', function () {
		serverView = ""
		$timeout.cancel(timeOut)
		//console.log('[MultiplayerServersController] destroyed.')
		var buttons = document.getElementsByClassName("servers-btn")
		for (var i = 0; i < buttons.length; i++) {
			buttons[i].classList.remove("bng-button-outline")
		}
	})
	
	$scope.$on('BeamMP_ServerListReceived', async function (event, data) {
		servers = await receiveServers(data)

		recents = await getRecents()
		favorites = await getFavorites()

		

		//console.log('Server list received, repopulating...')
		vm.repopulate()

		const serverSearchFilters = await getSearchFilterData(data)
		$scope.$emit('reloadSearchFilters', serverSearchFilters)
	})

	vm.repopulate = async function () {
		await populateTable(
			$filter,
			$scope,
			servers,
			serverView,
			searchFilters.searchText,
			searchFilters.playerCountMin,
			searchFilters.playerCountMax,
			searchFilters.sliderMaxModSize,
			searchFilters.selectedMaps,
			searchFilters.selectedServerVersions,
			searchFilters.selectedTags,
			searchFilters.selectedServerLocations,
			searchFilters.matchAll
		)

		vm.activeFiltersText = []
		vm.activeFiltersText.push([
			$filter('translate')('ui.multiplayer.filters.modSize') + " < ",
			formatBytes(searchFilters.sliderMaxModSize * 1e+6)
		])
		if (searchFilters.selectedMaps.length > 0) 		vm.activeFiltersText.push([
			$filter('translate')('ui.multiplayer.filters.map'),
			searchFilters.selectedMaps.join(", ")
		])
		if (searchFilters.selectedServerVersions.length > 0) 	vm.activeFiltersText.push([
			$filter('translate')('ui.multiplayer.filters.serverVersions'),
			searchFilters.selectedServerVersions.join(", ")
		])
		if (searchFilters.selectedTags.length > 0) 			vm.activeFiltersText.push([
			$filter('translate')('ui.multiplayer.filters.tags'),
			searchFilters.selectedTags
		])
		if (searchFilters.selectedServerLocations.length > 0) 	vm.activeFiltersText.push([
			$filter('translate')('ui.multiplayer.filters.serverLocations'),
			searchFilters.selectedServerLocations.join(", ")
		])

		var clearFiltersButton = document.getElementById("clearFiltersButton")
		//var FiltersPrefix = document.getElementById("FiltersPrefix")

		if (clearFiltersButton != null) {
			if (vm.activeFiltersText.length > 0) { 
				//activeFiltersText = activeFiltersText.slice(0, -2)
				clearFiltersButton.style.display = "block"
				//FiltersPrefix.style.display = "block"
			} else {
				clearFiltersButton.style.display = "none"
				//FiltersPrefix.style.display = "none"
			}
		}

		localStorage.setItem("serverListOptions", JSON.stringify(searchFilters))
	}

	$scope.isFilterOverlayVisible = false

	$scope.toggleFilterOverlay = function () {
		$scope.isFilterOverlayVisible = !$scope.isFilterOverlayVisible
	}
	$scope.addTagToSearchFilter = function (tag) {
		tag.raw = tag.raw.trim()
		console.log('Trying to add "'+tag.raw+'" to search filters')
		var isTagActive = -1
		console.log(searchFilters)
		for (var i = 0; i < searchFilters.selectedTags.length; i++) {
			//console.log(`Checking tag ${activeFilters.tags[i].raw}`)
			if (searchFilters.selectedTags[i].raw === tag.raw) {
				//console.log(`We have a match everybody!! isTagActive=true on ${tag.raw}`)
				isTagActive = i
				break
			}
		}
		if (isTagActive > -1) {
			console.log('Removing "'+tag.raw+'" from the search filters')
			searchFilters.selectedTags.splice(searchFilters.selectedTags.findIndex((included) => included === tag), 1)
			localStorage.setItem("serverListOptions", JSON.stringify(searchFilters))
			$scope.$emit('searchFiltersUpdated')
			repopulateServerList()
		} else {
			tag.active = true
			console.log('Added "'+JSON.stringify(tag)+'" to the search filters')
			searchFilters.selectedTags.push(tag)
			localStorage.setItem("serverListOptions", JSON.stringify(searchFilters))
			$scope.$emit('searchFiltersUpdated')
			repopulateServerList()
		}
	}

	repopulateServerList = function () {
		//console.log('repopulateServerList fired, repopulating...')
		vm.repopulate().then(() => { })
	}
}])

/* //////////////////////////////////////////////////////////////////////////////////////////////
*	DIRECT CONNECT TAB
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerDirectController', ['$scope', '$state', '$timeout',
function($scope, $state, $timeout) {
	var vm = this

	var timeOut = $timeout(function() {
		if (vm.loadingPage === true) {
			vm.loadTimeout = true
		}
	}, 10000)

	vm.exit = function ($event) {
		console.log(`vm.exit triggered in ${$scope.name}`)
		if ($event)
		console.log('[MultiplayerDirectController] exiting by keypress event %o', $event)
		$state.go('menu.mainmenu')
	}

	$scope.$on('$destroy', function () {
		$timeout.cancel(timeOut)
		//console.log('[MultiplayerDirectController] destroyed.')
	})
}])

.directive('compile', ['$compile', function ($compile) {
return function(scope, element, attrs) {
	scope.$watch(
	function(scope) {
		// watch the 'compile' expression for changes
		return scope.$eval(attrs.compile)
	},
	function(value) {
		// when the 'compile' expression changes
		// assign it into the current DOM
		element.html(value)
			// compile the new DOM and link it to the current scope.
			// NOTE: we only compile .childNodes so that
			// we don't get into infinite loop compiling ourselves
			$compile(element.contents())(scope)
			}
		)
	}
}])




/* //////////////////////////////////////////////////////////////////////////////////////////////
*	FUNCTIONS
*/ //////////////////////////////////////////////////////////////////////////////////////////////
// Set the first letter of each word upper case
function toTitleCase(str) {
	return str.replace(/\w\S*/g, function(txt){
		return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase()
	})
}

function SmoothMapName(map) {
	if (!map) return
	map = map.replace("/info.json","")
	map = map.split('/').pop().replace(/\s*/g,'')
	map = map.replace(/_/g," ")
	map = map.replace(/-/g," ")
	map = toTitleCase(map)
	return map
}

function formatBytes(bytes = 0, decimals = 2) {
	if (bytes == 0 || bytes == undefined) return '0 Bytes'
	const k = 1024
	const dm = decimals < 0 ? 0 : decimals
	const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB']
	const i = Math.floor(Math.log(bytes) / Math.log(k))
	return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i]
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
	'^o': 'italic',
	'^*': 'bngIcon'
}

import { icons as iconsOrig, iconsBySize, iconsByTag, getIconsWithTags } from "/ui/ui-vue/src/assets/fonts/bngIcons/bngIcons.js"
function formatCodes(string, isdesc = false) {
	let result = ''
	var currentText = ''
	let classes = new Set()

	string = DOMPurify.sanitize(string)

	const tokens = string.split(/(\^.)/g)

	const flush = () => {
		if (!currentText) return
		const classList = Array.from(classes)
		result += classList.length
			? `<span class="${classList.join(' ')}">${currentText}</span>`
			: currentText
		currentText = ''
	}

	for (let i = 0; i < tokens.length; i++) {
		const token = tokens[i]
		const nextToken = tokens[i+1]?.trim() || ''
		if (/^\^.$/.test(token)) {
			flush()
			if (token === '^r') { // reset
				classes.clear()
			} else if (isdesc && token === '^p') { // newline
				currentText += '<br>'
			} else if (isdesc && token === '^h') { // header
				classes.add('header')
			} else if (token === '^*') { // bngIcons
				const cls = globalThis.serverStyleMap?.[token]
				if(cls) classes.add(cls)

				if (iconsOrig[nextToken]) {
					currentText = iconsOrig[nextToken].glyph
				}
			} else {
				const cls = globalThis.serverStyleMap?.[token]
				if (cls?.startsWith('color-')) { // color
					[...classes].forEach(c => c.startsWith('color-') && classes.delete(c))
					classes.add(cls)
				} else if (cls) {
					classes.add(cls)
				}
			}
		} else if (tokens[i-1]!='^*') {
			currentText += token
		}
	}

	flush()
	return result
}


function modCount(s) {
	if(s.length==0) return 0
	return s.split(";").length-1
}

function modList(s) {
	var modarray = s.split(';')
	
	// Sort the mod array alphabetically
	modarray.sort()

	s = ""
	for (var i=0; i<modarray.length; i++){
		if (modarray[i] != '') {
			var modName = modarray[i].split('/').pop()
			modName = modName.replace(".zip","")
			s += modName
			//if (i<modarray.length-2)
			s += ", "
		}
	}
	//console.log(s)
	s = s.substring(0, s.length -2)
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
	else return data
}


function listPlayers(s) {
	if (s != undefined && s != "") {
		var re = new RegExp(";", 'g')
		s = s.replace(re, ', ');
		s = s.substring(0, s.length -2)
		return "Current players: " + s
	} else {
		return "No players..."
	}
}

function customToNumber(string) {
	return Number(string)
}
function customIsFinite(value) {
	return Number.isFinite(Number(value)) || false
}
function customIsString(content, index) {
	if (typeof content !== 'object') {
		return (typeof content) === 'string'
	} else {
		return (typeof content[index]) === 'string'
	}
}
function getTagCount(string) {
	return string.split(',').length
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
	"^p",
	"^*"
]

function stripCustomFormatting(name){
	for (var i = 0; i < serverStyleArray.length; i++){
		while (name.includes(serverStyleArray[i])){
			name = name.replace(serverStyleArray[i], "")
		}
	}
	return name
}


async function getFavorites() {
	return new Promise(function(resolve, reject) {
		bngApi.engineLua("MPConfig.getFavorites()", (data) => {
			if (!data) { resolve([]); return }
			if (typeof data === "object") if (Object.keys(data).length == 0) data = []
			favorites = data // Added this here so that we remove the await where this function was called.
			resolve(data || [])
		})
	})
}

function addFav(server, isUpdate) {
	const exists = favorites.some(fav => 
		fav.ip === server.ip && fav.port === server.port
	)
	if (!exists) {
		server["addTime"] = Date.now()
		favorites.push(server)
		saveFav()
		if (!isUpdate) bngApi.engineLua('MPCoreNetwork.requestServerList()')
	}
}

function removeFav(server) {
	for (let i = 0; i < favorites.length; i++) {
		let tmpServer = favorites[i]
		if (tmpServer.ip == server.ip && tmpServer.port == server.port) {
			favorites.splice(i, 1)
		}
	}
	saveFav()
	bngApi.engineLua('MPCoreNetwork.requestServerList()')
}

function saveFav() {
	var entry = Base64.encode(JSON.stringify(favorites))
	bngApi.engineLua('MPConfig.setFavorites(\'' + entry + '\')')
	
	// backup
	// bngApi.engineLua(`MPConfig.setFavorites(\'${JSON.stringify(favorites).replace(/'/g, "\\'")}\')`)
}


function getRecents() {
	return new Promise(function(resolve, reject) {
		var encoded = localStorage.getItem("recents")
		var tmpRecents = []
		if (encoded) {
			try {
				//decode
				tmpRecents = JSON.parse(Base64.decode(encoded))
			} catch (e) {
				try {
					//fallback if decode fail
					tmpRecents = JSON.parse(encoded)
				} catch (e2) {
					tmpRecents = []
				}
			}
		}
		recents = tmpRecents
		resolve(tmpRecents)
	})
}

function addRecent(server) { // has to have name, ip, port
	server["addTime"] = Date.now()
	recents = recents.filter(rec => 
		!(rec.ip === server.ip && rec.port === server.port)
	)	// Remove server and add it back
	recents.push(server)
	recents = recents.slice(-1 * 50) //keep the last 50 entries
	localStorage.setItem("recents", Base64.encode(JSON.stringify(recents)))
}

globalThis.openExternalLink = function(url){
	bngApi.engineLua(`MPCoreNetwork.openURL("`+url+`")`)
}

// /!\ IMPORTANT /!\ //// TYPE 0 = Normal / 1 = Favorites / 2 = Recents
async function populateTable($filter, $scope, servers, tab, searchText = '', playerCountMin, playerCountMax, sliderMaxModSize, selectMap = [], SelectedServerVersions = [], tags = [], SelectedServerLocations = [], matchAll) {
	$scope.serversTable = {}
	var type = 0
	if (tab == "favorites") type = 1
	else if (tab == "recents") type = 2
	let i = 0
	for (const server of servers) {
		i += 1
		if (!server) {
			console.log('server not found')
			continue
		}

		if (tab == "official" && !server.official) continue
		if (tab == "featured" && !server.featured) continue
		if (tab == "partner" && !server.partner) continue

		var shown = true
		var isFavorite = false
		var isRecent = false

		// Filter by search
		if (!server.strippedName.toLowerCase().includes(searchText.toLowerCase())) continue

		var activeFilters = 0
		var filterMatches = 0

		if(tags.length > 0) {
			//server.tags = "tag1,tag2"
			var serverTags = server.tags.toLowerCase().split(",").map(tag => tag.trim())

			activeFilters = activeFilters + 1
			var missingTags = 0
			for (let tag of tags) {
				if (!serverTags.includes(tag.raw.trim().toLowerCase())) missingTags+=1
			}
			if(missingTags===0) filterMatches+=1
			/*if (matchAll) {
				if(missingTags==0) {
					//console.log('Matching all tags. Pass.')
					filterMatches+=1
				} else {
					//console.log('Matching all tags. Fail.')
				}
			} else {
				if(missingTags < tags.length) {
					//console.log('Matching some tags. Pass.')
					filterMatches+=1
				} else {
					//console.log('Matching some tags. Fail.')
				}
			}*/
		}
		
		// Filter by empty or full
		activeFilters = activeFilters + 1
		if(server.players >= playerCountMin) {
			filterMatches+=1
		}
		activeFilters = activeFilters + 1
		if(server.players <= playerCountMax) {
			filterMatches+=1
		}

		// Filter by mod size
		if (server.modstotalsize) {
			activeFilters = activeFilters + 1
			if(sliderMaxModSize * 1048576 >= server.modstotalsize) filterMatches+=1
		}
	
		// Filter by map
		if (selectMap.length > 0) {
			activeFilters = activeFilters + 1
			if(selectMap.includes(SmoothMapName(server.map))) filterMatches+=1
		}

		if (SelectedServerVersions.length > 0) {
			activeFilters = activeFilters + 1
			if(SelectedServerVersions.includes("v" + server.version)) filterMatches+=1
		}

		if (SelectedServerLocations.length > 0) {
			activeFilters = activeFilters + 1
			if(SelectedServerLocations.includes(server.location)) filterMatches+=1
		}

		//console.log(`${filterMatches}/${activeFilters} matches`)
		if (matchAll) {
			if (filterMatches < activeFilters) continue
		} else {
			if (activeFilters > 0 && filterMatches < 1 ) continue
		}

		// Favorite
		for (let tmpServer of favorites) if (tmpServer.ip == server.ip && tmpServer.port == server.port) isFavorite = true
		if (type == 1 && !isFavorite) continue; // If it's favorite tab, we only show favorites

		// Recents
		for (let tmpServer of recents) if (tmpServer.ip == server.ip && tmpServer.port == server.port) {
			isRecent = true; 
			server.addTime = tmpServer.addTime
		}
		if (type == 2 && !isRecent) continue; // Everything happens underneath for recents

		// If the server passed the filter

		if (`${server.ip}:${server.port}` === $scope.selectedServerId) {
			console.log('Filling out formattedTags for the selected server')
			server.formattedTags = formatServerTags(server.tags)
		}

		$scope.serversTable[server.ip + ":" + server.port] = {server: server, isFavorite: isFavorite, isRecent: isRecent, name: server.sname, offline: false, custom: false}
		$scope.serversArray = Object.keys($scope.serversTable).map(function(key) {
			return $scope.serversTable[key]
		})

	}
	
	// Here we check if some favorited / recents servers are offline or not
	if (type == 1 || type == 2) {
		var toCheck = type == 1 ? favorites : recents
		for (let tmpServer1 of toCheck) {
			let stillOk = true
			for (let i = 0; i < servers.length; i++) {
				var tmpServer2 = servers[i]
				if (tmpServer1.ip == tmpServer2.ip && tmpServer1.port == tmpServer2.port) { stillOk = true; break }
				else stillOk = false
			}
			if (!stillOk) {

				// Filter by search
				if (!tmpServer1.strippedName.toLowerCase().includes(searchText.toLowerCase())) continue

				var activeFilters = 0
				var filterMatches = 0

				if(tmpServer1.tags && tags.length > 0) {
					//server.tags = "tag1,tag2"
					var serverTags = (tmpServer1.tags || "").toLowerCase().split(",").map(tag => tag.trim())
					
					activeFilters = activeFilters + 1
					var missingTags = 0
					for (let tag of tags) {
						if (!serverTags.includes(tag.raw.trim().toLowerCase())) missingTags+=1
					}
					if(missingTags < tags.length) filterMatches+=1
					/*if (matchAll) {
						if(missingTags==0) {
							//console.log('Matching all tags. Pass.')
							filterMatches+=1
						} else {
							//console.log('Matching all tags. Fail.')
						}
					} else {
						if(missingTags < tags.length) {
							//console.log('Matching some tags. Pass.')
							filterMatches+=1
						} else {
							//console.log('Matching some tags. Fail.')
						}
					}*/
				}
				
				// Filter by empty or full
				if (tmpServer1.players) {
					// min
					activeFilters = activeFilters + 1
					if(tmpServer1.players >= playerCountMin) { filterMatches+=1 }

					// max
					activeFilters = activeFilters + 1
					if(tmpServer1.players <= playerCountMax) { filterMatches+=1 }
				}
						

				// Filter by mod size
				if (tmpServer1.modstotalsize) {
					activeFilters = activeFilters + 1
					if(sliderMaxModSize * 1048576 >= tmpServer1.modstotalsize) filterMatches+=1
				}
			
				// Filter by map
				if (selectMap.length > 0) {
					activeFilters = activeFilters + 1
					if(selectMap.includes(SmoothMapName(tmpServer1.map))) filterMatches+=1
				}

				if (SelectedServerVersions.length > 0) {
					activeFilters = activeFilters + 1
					if(SelectedServerVersions.includes("v" + tmpServer1.version)) filterMatches+=1
				}

				if (SelectedServerLocations.length > 0) {
					activeFilters = activeFilters + 1
					if(SelectedServerLocations.includes(tmpServer1.location)) filterMatches+=1
				}

				console.log(`${filterMatches}/${activeFilters} matches`, tmpServer1)
				if (matchAll) {
					if (filterMatches < activeFilters) continue
				} else {
					if (activeFilters > 0 && filterMatches < 1 ) continue
				}

				var offline = false
				var custom = false
				var name = tmpServer1.sname
				if (!tmpServer1.custom) { name = '^c[^*globeSimpleNotSign^r^c Offline]^r ' + name; offline = true }
				else { name = '^e[^*bookmark^r^e Custom]^r ' + name; custom = true }
				$scope.serversTable[tmpServer1.ip + ":" + tmpServer1.port] = {server: tmpServer1, isFavorite: type == 1, isRecent: type == 2, name: name, offline: offline, custom: custom}
				$scope.serversArray = Object.keys($scope.serversTable).map(function(key) {
					return $scope.serversTable[key]
				})
			}
		}
	}
	if (Object.keys($scope.serversTable).length === 0) {
		$scope.serversArray = []
	}	
	$scope.serversArray.forEach(server => {
		server.id = server.server.ip + ':' + server.server.port
	})
	if (type == 2) {
		$scope.sortTable("addTime", true, -1)
	}

	//console.log('Completed repopulating')
	$scope.onScroll()

	$scope.$emit("reloadSearchFilters", await getSearchFilterData(servers))
}

// Used to connect to the backend with ids
function connect(ip, port, name, skipModWarning = false) {
	console.log("Attempting to call connect to server...")
	// Add server to recents
	addRecent(highlightedServer)
	// Make sure the right content is displayed
	document.getElementById('OriginalLoadingStatus').removeAttribute("hidden")
	document.getElementById('LoadingStatus').setAttribute("hidden", "hidden")
	// Show the connecting screen
	document.getElementById('LoadingServer').style.display = 'flex'

	let modlist = document.getElementById('mod-download-list')
	if (modlist) {
		modlist.style.display = 'none'
	}

	const injector = angular.element(document.body).injector()
	const $controller = injector.get('$controller')
	const $rootScope = injector.get('$rootScope')
	const multiplayerCtrl = $controller('MultiplayerController', { $scope: $rootScope })

	multiplayerCtrl.loadingStatus = ""
	multiplayerCtrl.downloadingMods = []
	$rootScope.$applyAsync()

	// Connect with ids
	bngApi.engineLua('MPCoreNetwork.connectToServer("' + ip + '", ' + port + ',"' + name + '", ' + skipModWarning + ')')
}

async function receiveServers(data) {
	var serversArray = new Array()
	var launcherVersion = await getLauncherVersion()
	// Parse the data to a nice looking Array
	for (var i = 0; i < data.length; i++) {
		var v = data[i]
		const [vMajor, vMinor] = v.cversion.split('.').map(Number)
		const [launcherMajor, launcherMinor] = launcherVersion.split('.').map(Number)

		// Compare the versions
		if (vMajor === launcherMajor && launcherMinor >= vMinor) {
			v.strippedName = stripCustomFormatting(v.sname)
			serversArray.push(v)
		}
	}
	// Sort the servers to display official servers first
	serversArray.sort(function(a, b) {
		if (a.official && b.official) return a.strippedName.localeCompare(b.strippedName)
		else if (a.official) return -1
		else if (b.official) return 1
		return 0
	})
	return serversArray
}

async function getLauncherVersion() {
	return new Promise(function(resolve, reject) {
		bngApi.engineLua("MPCoreNetwork.getLauncherVersion()", (data) => {
			resolve(data)
		})
	})
}

async function isLoggedIn() {
	return new Promise(function(resolve, reject) {
		bngApi.engineLua("MPCoreNetwork.isLoggedIn()", (data) => {
			resolve(data)
		})
	})
}

async function isLauncherConnected() {
	return new Promise(function(resolve, reject) {
		bngApi.engineLua("MPCoreNetwork.isLauncherConnected()", (data) => {
			resolve(data)
		})
	})
}

function getVueIconPath(iconName) {
	return "/ui/ui-vue/src/assets/fonts/bngIcons/svg/" + iconName + ".svg"
}

function formatServerTags(commaList) {
	if (typeof commaList !== "string") {return []}

	var tagList = []
	var tags = commaList.split(",")
	for (const tag of tags) {
		if (tag==="") continue

		const tagItem = formatRawTag(tag)

		tagList.push(tagItem)
	}
	return tagList
}

async function getSearchFilterData(serverList) {
	if (!serverList) {
		return searchFilters
	}
	servers = await receiveServers(serverList)

	var availableServerVersions = []
	var availableMaps = []
	var availableTags = []
	var formattedTags = []
	var availableServerLocations = []

	var selectedServerLocations = []
	var selectedMaps = []
	var selectedTags = []
	var selectedServerVersions = []

	var availableOfficialMaps = []

	for (const server of servers) {
		if (!availableServerVersions.includes("v" + server.version)) availableServerVersions.push("v" + server.version)

		if (!availableServerLocations.includes(server.location)) availableServerLocations.push(server.location)

		var smoothMapName = SmoothMapName(server.map)
		if (typeof smoothMapName === 'string' && smoothMapName !== '') {
			let isOfficialMap = officialMaps.includes(smoothMapName)

			if (isOfficialMap) {
				if (!availableOfficialMaps.includes(smoothMapName)) {
					//console.log(`Y ${smoothMapName}`)
					availableOfficialMaps.push(smoothMapName)
				}
			} else {
				if (!availableMaps.includes(smoothMapName)) {
					//console.log(`N ${smoothMapName}`)
					availableMaps.push(smoothMapName)
				}
			}
		}

		var serverTags = server.tags.split(",")
		for (const tag of serverTags) {
			if (!availableTags.includes(tag.trim()) && tag.trim().length > 0) availableTags.push(tag.trim())
		}
	}

	availableMaps.sort()

	availableOfficialMaps.sort().reverse()
	for (const mapName of availableOfficialMaps) {
		availableMaps.splice(0, 0, mapName)
	}

	availableServerVersions.sort()
	availableTags.sort()
	availableServerLocations.sort()

	const activeFilters = JSON.parse(localStorage.getItem("serverListOptions"))
	for (const tag of availableTags) {
		var tagItem = formatRawTag(tag, activeFilters)

		//console.log('Tag item: '+JSON.stringify(tagItem))
		//console.log('-')
		formattedTags.push(tagItem)
	}
	formattedTags.sort()

	return [
		availableServerLocations,
		availableMaps,
		availableTags,
		formattedTags,
		availableServerVersions,
		
		activeFilters.selectedServerLocations ?? [],
		activeFilters.selectedMaps ?? [],
		selectedTags,
		activeFilters.selectedServerVersions ?? [],

		activeFilters.playerCountMin ?? 0,
		activeFilters.playerCountMax ?? 64,
		activeFilters.sliderMaxModSize ?? 80530,
	]
}


function formatRawTag(rawTag, activeSearchFilters) {
	var tagTexts = rawTag.trim().split(":")
	var tagItem = {
		icon: '',
		text: tagTexts[1] || rawTag,
		raw: rawTag,
		active: false
	}

	if (tagTexts[0] == "Racing") {
		tagItem.icon = '<img src='+getVueIconPath('helmets')+' class="button-icon button-icon-filter tag-icon" />'

	} else if (tagTexts[0] == "Gamemode") {
		tagItem.icon = '<img src='+getVueIconPath('gamepad')+' class="button-icon button-icon-filter tag-icon" />'

	} else if (tagTexts[0] == "Mod") {
		tagItem.icon = '<img src='+getVueIconPath('puzzleModule')+' class="button-icon button-icon-filter tag-icon" />'

	} else if (tagTexts[0] == "Lang") {
		tagItem.icon = '<img src='+getVueIconPath('language')+' class="button-icon button-icon-filter tag-icon" />'
	}
	tagItem.theme = tagThemes[tagItem.raw.trim()] ?? null

	if (activeSearchFilters) {
		for (var i = 0; i < activeSearchFilters.selectedTags.length; i++) {
			if (tagItem.raw.trim() === activeSearchFilters.selectedTags[i].raw) {
				tagItem.active = true
				break
			}
		}
	}

	return tagItem
}



// Base64 encoding and decoding functions
var Base64 = {
	encode: function(input) {
		return btoa(new TextEncoder().encode(input).reduce((data, byte) => data + String.fromCharCode(byte), ""))
	},
	decode: function(input) {
		return new TextDecoder().decode(Uint8Array.from(atob(input), c => c.charCodeAt(0)))
	}
}
