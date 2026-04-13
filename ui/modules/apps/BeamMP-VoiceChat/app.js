angular.module('beamng.apps')
.directive('multiplayervoicechat', [function () {
	return {
		templateUrl: '/ui/modules/apps/BeamMP-VoiceChat/app.html',
		replace: true,
		restrict: 'EA',
		scope: true
	};
}])
.controller('VoiceChat', ['$scope', function ($scope) {
	var selfEl = null;
	var othersEl = null;
	var activeSpeakers = {};
	var fadeTimers = {};

	$scope.init = function () {
		selfEl = document.getElementById('vc-self');
		othersEl = document.getElementById('vc-others');
	};

	$scope.$on('VoiceChatSelfStart', function () {
		if (selfEl) selfEl.style.display = '';
	});

	$scope.$on('VoiceChatSelfStop', function () {
		if (selfEl) selfEl.style.display = 'none';
	});

	$scope.$on('VoiceChatSpeaking', function (event, data) {
		if (!othersEl) return;
		var id = data.id;
		var name = data.name || ('Player ' + id);

		if (fadeTimers[id]) {
			clearTimeout(fadeTimers[id]);
		}

		if (!activeSpeakers[id]) {
			var el = document.createElement('div');
			el.className = 'vc-entry';
			el.id = 'vc-speaker-' + id;
			var icon = data.injected ? 'music_note' : 'mic';
			el.innerHTML = '<span class="vc-icon material-icons">' + icon + '</span><span class="vc-name">' + name + '</span>';
			othersEl.appendChild(el);
			activeSpeakers[id] = el;
		}

		fadeTimers[id] = setTimeout(function () {
			var el = activeSpeakers[id];
			if (el && el.parentNode) {
				el.parentNode.removeChild(el);
			}
			delete activeSpeakers[id];
			delete fadeTimers[id];
		}, 1500);
	});

	$scope.$on('VoiceChatSpeakingStop', function (event, data) {
		if (!data) return;
		var id = data.id;
		if (fadeTimers[id]) {
			clearTimeout(fadeTimers[id]);
			delete fadeTimers[id];
		}
		var el = activeSpeakers[id];
		if (el && el.parentNode) {
			el.parentNode.removeChild(el);
		}
		delete activeSpeakers[id];
	});

	$scope.$on('destroy', function () {
		for (var id in fadeTimers) {
			clearTimeout(fadeTimers[id]);
		}
		activeSpeakers = {};
		fadeTimers = {};
	});
}]);
