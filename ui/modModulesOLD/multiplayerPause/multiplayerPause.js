
var playerListCache = [];

//	{
//		id: 'myModButton',			// id: Id for updating/popping the button
//		text: 'My Mod Button',		// text: Translated text to display in the pause menu
//		event: 'yourEvent',			// event: Emits the named event when clicked
//		classList: ''				// classList: Optional list of CSS classes to add to the button. Formatted like: "bng-button-main bng-button-attention"
//	}
var modButtons = {};

var currentServer = undefined;
var directConnect = undefined;
var serverIp = undefined;

var roleName = undefined;

var rootController = undefined;
angular.module('BeamNG.ui')
.run(function($rootScope, $templateCache) {
$rootScope.$on('$stateChangeSuccess', function(event, toState, toParams, fromState, fromParams) {
	if (!rootController) rootController = window.angular.element(document.querySelector('body')).controller();
	
	if (rootController.gameState === "multiplayer" && fromState.name === 'play' && toState.name === 'menu.mainmenu') {
		rootController.switchState('menu.multiplayerPause')
	};
});
});

export default angular.module('multiplayerPause', ['ui.router'])
.config(['$stateProvider', function($stateProvider) {
	$stateProvider.state('menu.multiplayerPause', {
		url: '/multiplayerPause',
		templateUrl: '/ui/modModules/multiplayerPause/multiplayerPause.html',
		controller: 'multiplayerPause',
		backState: 'BACK_TO_MENU',
		abstract: false,

		menuActionMapEnabled: true,
		clickThrough: true,

		uiLayout: 'careerPause',
		uiAppsShown: true,
	});
}])

.controller('multiplayerPause', ['$scope', '$state', '$timeout', 'UiAppsService', 'Settings', '$translate', 'ConfirmationDialog', 
function($scope, $state, $timeout, $UiAppsService, $Settings, $translate, ConfirmationDialog) {
	//console.log('Multiplayer pause menu opened');
	bngApi.engineLua('ui_topBar.updateActiveItem()')

	//$scope.$on("$destroy", function(event, data) {
	//	//console.log('Multiplayer pause menu closed');
	//});

	$scope.modButtons = modButtons;

	$scope.serverName = $translate.instant('ui.common.loading');
	$scope.serverDesc = $translate.instant('ui.common.loading');
	$scope.serverTags = {};
	$scope.playersList = playerListCache;
	$scope.pingList = {}
	$scope.dummy = undefined;
	$scope.maxPlayers = undefined;
	$scope.showPlayerIDs = $Settings.values.showPlayerIDs;
	$scope.authResult = {};
	$scope.roleName = roleName;

	$scope.$on('BeamMP_ServerListReceived', function(event, data) {
		onServerListReceived(data)
	});
	async function onServerListReceived(serverList) {
		function checkDirectConnect() {
			const serverDetailsButton = document.getElementById("mpPauseServerDetailsButton")
			if (!directConnect) {
				console.log('Joined current server via backend? Enabling server details')

				serverDetailsButton.removeAttribute('disabled')
				$scope.joinedViaBackend = true
			} else {
				console.log('Joined current server via direct connect? Simplifying server details')

				serverDetailsButton.setAttribute('disabled', '')
				$scope.joinedViaBackend = false
				$scope.serverName = ""
				$scope.playersText = $translate.instant('ui.multiplayer.players')
			}
		}
		if (currentServer) {
			console.log('Using cached current server data...')

			$scope.serverName = formatServerName(false, currentServer.sname)
			$scope.serverOwner = currentServer.owner
			$scope.serverDesc = formatServerName(true, currentServer.sdesc)
			$scope.serverTags = formatServerTags(currentServer.tags)
			$scope.maxPlayers = currentServer.maxplayers
			$scope.mods = {
				list: modList(currentServer.modlist || '').split(', '),
				total: Number(currentServer.modstotal),
				size: formatBytes(currentServer.modstotalsize)
			}
			if (currentServer.official) $scope.serverStatus = "official"
			if (currentServer.partner) $scope.serverStatus = "partner"
			if (currentServer.featured) $scope.serverStatus = "featured"

			checkDirectConnect()
		} else {

			if (serverIp) {
				console.log('Iterating through the server list to find the current server...')
				for (let i = 0; i < serverList.length; i++) {
					if (`${serverList[i].ip}:${serverList[i].port}` === serverIp) {
						console.log(`Found the current server in the server list after ${i} iterations`)
						//console.log(serverList[i])
						currentServer = serverList[i]

						$scope.serverName = formatServerName(false, currentServer.sname)
						$scope.serverOwner = currentServer.owner
						$scope.serverDesc = formatServerName(true, currentServer.sdesc)
						$scope.serverTags = formatServerTags(currentServer.tags)
						$scope.maxPlayers = currentServer.maxplayers
						$scope.mods = {
							list: modList(currentServer.modlist || '').split(', '),
							total: Number(currentServer.modstotal),
							size: formatBytes(Number(currentServer.modstotalsize))
						}
						if (currentServer.official) $scope.serverStatus = "official"
						if (currentServer.partner) $scope.serverStatus = "partner"
						if (currentServer.featured) $scope.serverStatus = "featured"

						checkDirectConnect()

						break
					}
				}
				if (!currentServer) {
					console.log("Didn't find the current server in the server list. Assuming custom server.")
					document.getElementById("mpPauseServerDetailsButton").setAttribute('disabled', '')
					$scope.serverName = ""
					$scope.joinedViaBackend = false
					$scope.playersText = $translate.instant('ui.multiplayer.players')
				}
			} else {
				console.log('Getting current server...')
				bngApi.engineLua(`MPCoreNetwork.getCurrentServer()`, function(coreCurrentServer) {
					if (coreCurrentServer) {
						if ((typeof serverIp==='string') && `${coreCurrentServer.ip}:${coreCurrentServer.port}`!==serverIp) {
							console.log('Clearing cached current server')
							currentServer = undefined;
						}
						directConnect = !coreCurrentServer.name
						serverIp = `${coreCurrentServer.ip}:${coreCurrentServer.port}`
						onServerListReceived(serverList)
					} else {
						console.log('Not connected to a server!')
					}
				})
			}
		}
	};

	bngApi.engineLua(`MPCoreNetwork.getAuthResult()`, function(authResult) {
		$scope.authResult = authResult;
		roleName = authResult.role;

		if (authResult.role) {
			bngApi.engineLua(`MPVehicleGE.getRoleInfoTable()`, function(data) {
				if (roleName !== "USER") {
					roleName = data[roleName].tag;
				} else {
					roleName = "User";
				};
				$scope.roleName = roleName;
			});
		};
	});

	$scope.$on('BeamMP_PauseMenuModButtons', function(event, data) {
		modButtons = {};
		for (const [id, modButton] of Object.entries(data)) {
			modButtons[id] = {
				id: id,
				text: modButton.text,
				event: modButton.event ?? '',
				class: modButton.class ?? 'mpPauseButton-outline'
			};

			//console.log(`Pushed mod button with id ${id}`);
		};
		$scope.modButtons = modButtons;
	});
	bngApi.engineLua('UI.sendPauseMenuModButtons()');
	
	$scope.modButtonClick = function(lua) {
		//console.log(`Running the following GE lua from a mod button: "${lua}"`);
		bngApi.engineLua(lua);
	};

	$scope.$on('BeamMP_PlayerPings', function(event, data) {
		const pingList = JSON.parse(data);
		for (const [username, ping] of Object.entries(pingList)) {
			if(username !== "") {
				for (const player of $scope.playersList.values()) {
					if (player.name === username) {
						player.ping = ping
					}
				}
			}
		};
		$scope.$applyAsync();
	});


	$scope.$on('BeamMP_PlayerList', function(event, data) {
		let parsedList = JSON.parse(data);

		parsedList.sort(function(a, b) {
		var keyA = a.id,
			keyB = b.id;
		// Compare the 2 ID's
		if (keyA < keyB) return -1;
		if (keyA > keyB) return 1;
		return 0;
		});

		const a = JSON.stringify(angular.toJson(parsedList))
		const b = JSON.stringify(angular.toJson($scope.playersList))

		if (a != b) {
			playerListCache = parsedList;
			$scope.playersList = playerListCache;
		};
	});

	var queuedPlayers = {};
	$scope.$on('BeamMP_SetQueue', function(event, data) {
		queuedPlayers = data.queuedPlayers || {};
		setQueue();
	});
	function setQueue() {
		queuedPlayers = Object.keys(queuedPlayers);
		for (const element of document.getElementsByClassName('mpPausePlayerListRowEventQueued')) {
			element.classList.remove('mpPausePlayerListRowEventQueued');
		};
		for (const index in playerListCache) {
			const player = playerListCache[index]
			let playerListRowElement = document.getElementById(`mpPause-playerList-${player.id}`);
			if (playerListRowElement) {
				if (queuedPlayers.includes(String(player.id))) {
					//console.log(`Adding event queued class for ${player.id}`);
					playerListRowElement.classList.add('mpPausePlayerListRowEventQueued');
				} else {
					//console.log(`Removing event queued class for ${player.id}`);
					playerListRowElement.classList.remove('mpPausePlayerListRowEventQueued');
				};
			};
		};
	}
	bngApi.engineLua('UI.updatePlayersList(); UI.sendQueue()');

	$scope.getVueIconPath = getVueIconPath;

	$scope.copyPlayerName = function(name) {
		$scope.dummy = undefined;
		bngApi.engineLua(`setClipboard(require("mime").unb64('` + btoa(name) + `'))`)
	};
	$scope.deleteAllVehicles = function(name) {
		bngApi.engineLua(`
			for id, veh in pairs(MPVehicleGE.getVehicles()) do
				if veh.ownerName == require("mime").unb64('` + btoa(name) + `') then
					local vehicle = getObjectByID(veh.gameVehicleID)
					if vehicle then vehicle:delete() end
				end
			end
		`)
	};
	$scope.queueEvents = function(id) {
		$scope.dummy = undefined;
		bngApi.engineLua(`MPVehicleGE.applyPlayerQueues(${id})`)
	};
	$scope.switchCameraTo = function(name) {
		$scope.dummy = undefined;
		bngApi.engineLua(`MPVehicleGE.focusCameraOnPlayer("${name}")`)
	};
	$scope.openProfile = function(name) {
		$scope.dummy = undefined;
		openExternalLink(`https://forum.beammp.com/u/${name}/summary`)
	};
	$scope.restoreVehicles = function(name) {
		$scope.dummy = undefined;
		bngApi.engineLua(`MPVehicleGE.restorePlayerVehicle("${name}")`)
	};

	$scope.resume = function() {
		$state.go('play')
	};
	$scope.openPopupOfId = function(id) {
		const elements = document.getElementsByClassName('mpPauseContainer');
		for (let i = 0; i < elements.length; i++) {
			const element = elements[i];

			if (element.id === id) {
				element.style.display = ""
			} else {
				element.style.display = "none"
			};
		};
	};
	$scope.mainMenu = function() {
		$state.go('menu.mainmenu');
	};
	$scope.leaveServer = function() {
		ConfirmationDialog.open(
			"ui.multiplayer.pauseMenu.areYouSure",
			"ui.multiplayer.pauseMenu.disconnectConfirmation",
			[
				{ label: "ui.multiplayer.pauseMenu.disconnect", key: true, default: false },
				{ label: "ui.common.cancel", key: false, default: true, isCancel: true },
			],
			{ class: "" }
		).then(res => {
			if (res) bngApi.engineLua(`MPCoreNetwork.leaveServer(true)`)
		});
	};
	$scope.quitGame = function() {
		ConfirmationDialog.open(
			"ui.multiplayer.pauseMenu.areYouSure",
			"ui.multiplayer.pauseMenu.quitToDesktopConfirmation",
			[
				{ label: "ui.multiplayer.pauseMenu.quitToDesktop", key: true, default: false },
				{ label: "ui.common.cancel", key: false, default: true, isCancel: true },
			],
			{ class: "" }
		).then(res => {
			if (res) bngApi.engineLua(`quit()`)
		});
	};
}]);

function getVueIconPath(iconName) {
	return "/ui/ui-vue/src/assets/fonts/bngIcons/svg/" + iconName + ".svg"
};

function formatServerName(isdesc, string) {
    let result = '';
    let currentText = '';
    let classes = new Set();

	string = DOMPurify.sanitize(string);

    const tokens = string.split(/(\^.)/g);

    const flush = () => {
        if (!currentText) return;
        const classList = Array.from(classes);
        result += classList.length
            ? `<span class="${classList.join(' ')}">${currentText}</span>`
            : currentText;
        currentText = '';
    };

    for (let i = 0; i < tokens.length; i++) {
		const token = tokens[i];
		const nextToken = tokens[i+1]?.trim() || '';
		if (/^\^.$/.test(token)) {
			flush();
			if (token === '^r') { // reset
				classes.clear();
            } else if (isdesc && token === '^p') { // newline
                currentText += '<br>';
			} else if (isdesc && token === '^h') { // header
				classes.add('header');
			} else if (token === '^*') { // bngIcons
				const cls = globalThis.serverStyleMap?.[token];
				if(cls) classes.add(cls);
				if (iconsOrig[nextToken]) {
					currentText = iconsOrig[nextToken].glyph
				};
			} else {
				const cls = globalThis.serverStyleMap?.[token];
				if (cls?.startsWith('color-')) { // color
					[...classes].forEach(c => c.startsWith('color-') && classes.delete(c));
					classes.add(cls);
				} else if (cls) {
					classes.add(cls);
				}
			}
		} else if (tokens[i-1]!='^*') {
			currentText += token;
		}
	}

    flush();
    return result;
}

function formatServerTags(commaList) {
	var tagList = []
	var tags = commaList.split(",");
	//console.log('Server item tag input: "'+tags+'"')
	for (const tag of tags) {
		//console.log('    Tag list item input: '+JSON.stringify(tag))

		var tagTexts = tag.split(":");
		var tagItem = {
			icon: '',
			text: tagTexts[1] || tag,
			raw: tag
		};
		tagTexts[0] = tagTexts[0].split(" ").join("")
		//console.log('        Tag prefix input: "'+tagTexts[0]+'"')
		if (tagTexts.length > 1) {
			if (tagTexts[0] == "Racing") {
				tagItem.icon = '<img src='+getVueIconPath('helmets')+' class="tag-icon" />';
				//console.log('        Found "Racing"');

			} else if (tagTexts[0] == "Gamemode") {
				tagItem.icon = '<img src='+getVueIconPath('gamepad')+' class="tag-icon" />';
				//console.log('        Found "Gamemode"');

			} else if (tagTexts[0] == "Mod") {
				tagItem.icon = '<img src='+getVueIconPath('puzzleModule')+' class="tag-icon" />';
				//console.log('        Found "Mod"');

			} else if (tagTexts[0] == "Lang") {
				tagItem.icon = '<img src='+getVueIconPath('language')+' class="tag-icon" />';
				//console.log('        Found "Lang"');
			}
		} else {
			//console.log('        No icon found');
		}

		//console.log('    Tag list item output: '+JSON.stringify(tag))

		//console.log('Tag item: ', tagItem);
		//console.log('---');
		tagList.push(tagItem);
	};
	//console.log('Server item tag output: '+JSON.stringify(tagList))
	return tagList
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

function formatBytes(bytes = 0, decimals = 2) {
    if (bytes == 0 || bytes == undefined) return '0 Bytes';
    const k = 1024;
    const dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}
