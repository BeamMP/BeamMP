// Voice Chat controller for multiplayer options
angular.module('BeamNG.ui')
.run(['$rootScope', function($rootScope) {
    // Initialize voice chat data
    $rootScope.multiplayer = $rootScope.multiplayer || {};
    $rootScope.multiplayer.voiceInputDevices = [];
    $rootScope.multiplayer.voiceOutputDevices = [];
    $rootScope.multiplayer.micLevel = 0;

    // Handle device list received from launcher
    $rootScope.$on('VoiceChatDevicesReceived', function(event, devices) {
        console.log('Received voice devices:', devices);
        $rootScope.multiplayer.voiceInputDevices = devices.input || [];
        $rootScope.multiplayer.voiceOutputDevices = devices.output || [];
        $rootScope.$applyAsync();
    });

    // Handle microphone level updates
    $rootScope.$on('VoiceChatMicLevel', function(event, level) {
        $rootScope.multiplayer.micLevel = Math.max(0, Math.min(100, level || 0));
        // Don't trigger digest cycle for every mic level update (performance)
        if (!$rootScope.$$phase) {
            $rootScope.$applyAsync();
        }
    });

    // Request devices when entering multiplayer options
    $rootScope.$on('$stateChangeSuccess', function(event, toState) {
        if (toState.name === 'menu.options.multiplayer') {
            // Request device list from the game/launcher
            bngApi.engineLua('extensions.MPVoiceChat and extensions.MPVoiceChat.requestDevices()');
        }
    });
}]);
