angular.module('beamng.stuff')

.directive('mpMissionUi', ['Settings', '$sce', 'Utils', '$filter', function (Settings, $sce, Utils, $filter) {
  return {
    template: `
      <div class="mp-mission-ui">
        <div class="start-hint" ng-if="moveToStartHintVisible">
            <div>MOVE SLOWLY</div>
            <div>TO START-LINE</div>
        </div>

        <div class="start-hint" ng-if="digit != null">
            <div ng-show="digit > 5">
                <div style="font-size: 100px;">STOP</div>
                <div style="font-size: 35px;">WAIT FOR COUNTDOWN</div>
            </div>
            <div ng-show="digit > 0 && digit < 6">
                <div style="font-size: 100px;">{{digit}}</div>
            </div>
            <div ng-show="digit == 0">
                <div style="font-size: 100px;">GO!</div>
            </div>
        </div>
      </div>
      `,
    replace: true,
    link: function (scope, element, attrs) {
      scope.moveToStartHintVisible = false;
      scope.digit = null;
      let timer = null;

      scope.$on('MPDragRaceShowMoveToStartHint', function (_, visible) {
        if (visible == null) {
            scope.moveToStartHintVisible = false;
        } else {
            scope.moveToStartHintVisible = visible;
        }
        scope.$evalAsync();
      });

      scope.$on('MPDragRaceShowCountdownDigit', function (_, digit) {
        scope.moveToStartHintVisible = false;
        scope.digit = digit;

        if (timer !== null) {
          clearTimeout(timer)
        }
        timer = setTimeout(function() {
          scope.digit = null;
          scope.$evalAsync();
        }, 1500);

        scope.$evalAsync();
      });
    }
  };
}]);
