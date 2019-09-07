angular.module('beamng.apps')

.directive('multiplayerdebug', ['bngApi', function (bngApi) {
	return {
		templateUrl: 'modules/apps/BeamNG-MP-DEBUG/app.html',
		replace: true,
		restrict: 'E',
		scope: false,
		controller: function ($scope, $element, $attrs) {
			$scope.mainStyle = {appWidth: "100%", appHeight: "100%", inLeft: "auto", inRight: "4px", appShow: "visible", groupsShow: "hidden"};
			$scope.checkStyle = {awareness: $scope.checkImg, method: ""};
			$scope.visible = {main: true};
		},
		controllerAs: 'ctrl'
	};
}]);
