angular.module('beamng.stuff')

.directive('multiplayerMissions', ['$rootScope', function ($rootScope) {
  return {
    template: '<div class="mp-mission-popups" ng-show="missionPopupsVisible" ng-transclude></div>',
    replace: true,
    transclude: true,
    scope: false,
    link: function (scope, element, attrs) {
      scope.missionPopupsVisible = true;

      scope.$on('MPToggleMissionPopups', (_, state) => {
        if (typeof (state) === 'boolean')
          scope.missionPopupsVisible = state;
        else
          scope.missionPopupsVisible = !scope.missionPopupsVisible;

        scope.$evalAsync();
      });

      $rootScope.$on('$stateChangeStart', (_, state) => {
        scope.missionPopupsVisible = state.name === 'menu';
      });
    }
  };
}])

.directive('mpMissionInfo', ['Settings', '$sce', 'Utils', '$filter', function (Settings, $sce, Utils, $filter) {
  return {
    template: `
      <div class="mp-mission-info" ng-show="visible">
        <div class="header">

          <div style="position: relative">
            <div ng-if="h != null" class="header-title">{{h}}</div>
            <div ng-if="ms != null">
                <div ng-repeat="m in ms" class="header-subtitle">{{m}}</div>
            </div>
          </div>
        </div>

        <div ng-if="bs != null" class="buttons">
          <div ng-repeat="b in bs" class="button" ng-click="action(b.action)">
            <div>
              <span>
                <md-icon style="color: #ffffff; padding: 0 10px 5px 0">{{b.icon}}</md-icon>
              </span>
              {{b.text}}
            </div>
          </div>
        </div>
      </div>`,
    replace: true,
    link: function (scope, element, attrs) {
      scope.visible = false;
      scope.h = null;
      scope.ms = null;
      scope.bs = null;

      scope.$on('MPMessageUpdate', function (_, data) {
        var parsed = JSON.parse(data);

        scope.visible = parsed['visible'];
        scope.h = parsed['header'];
        scope.ms = parsed['messages'];
        scope.bs = parsed['buttons'];

        scope.$evalAsync();
      });

      scope.action = function(cmd) {
        if (cmd == "%CLOSE%") {
          scope.visible = false;
          scope.h = scope.ms = scope.bs = null;
          scope.$evalAsync();
        } else {
          bngApi.engineLua(cmd);
        }
      }
    }
  };
}]);
