(function () {
'use strict';

angular.module('beamng.stuff')

.controller('MultiplayerTOSController', ['$scope', 'bngApi', '$state', '$timeout', '$document', function($scope, bngApi, $state, $timeout, $document) {
	'use strict';
	// The lua setting need to be functional before we redirect, otherwise we'll land here again.
	// for that reason, we listen for the settings changed event that will ensure that the main menu will not get back here again

	if (localStorage.getItem("tosAccepted") == "true") {
		$state.go('menu.multiplayer');
	}

	$scope.validate = function () {
		localStorage.setItem("tosAccepted", "true");
		$state.go('menu.multiplayer');
	};

	$scope.openExternalLink = function(url) {
		bngApi.engineLua(`openWebBrowser("`+url+`")`);
	}
}]);

})();