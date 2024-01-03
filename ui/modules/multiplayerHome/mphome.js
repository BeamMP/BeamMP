angular.module('beamng.stuff')
/* //////////////////////////////////////////////////////////////////////////////////////////////
*	HOME CONTROLLER
*/ //////////////////////////////////////////////////////////////////////////////////////////////
.controller('MultiplayerHomeController', ['$scope', '$state', '$timeout', '$document', 
function($scope, $state, $timeout, $document) {
	'use strict';
  
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

/**
 * This function is designed for opening http based links in the web browser using the BeamMP Launcher.
 * Note: The URLs are scoped to BeamMP related domains only & Discord invite links (discord.gg)
 * @param {string} url 
 */

function openExternalLink(url){
	bngApi.engineLua(`MPCoreNetwork.mpOpenUrl("`+url+`")`);
}