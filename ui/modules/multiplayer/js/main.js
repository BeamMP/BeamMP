angular.module("CreatorConsole", ['angular-flot', 'ui.router'])

.config(['$stateProvider', '$urlRouterProvider', function($stateProvider, $urlRouterProvider) {
  $stateProvider
  .state('dashboard', {
    url: '/dashboard',
    templateUrl: 'dashboard.html',
    controller: 'DashboardController',
  })
  .state('vehicle', {
    url: '/vehicle/:id',
    templateUrl: 'vehicle.html',
    controller: 'VehicleController',
  })

  $urlRouterProvider.otherwise('/dashboard');

}])

.service("bngApi", ['$rootScope', function($rootScope) {

  if(typeof beamngWsPort === 'undefined') {
    // some defaults in case the configuration failed
    beamngWsPort = 16720;     
    beamngHost = '127.0.0.1';
  }

  var websocks = {};
  $rootScope.instances = {};

  function reconnect() {
    //console.log(">> reconnect >>");
    websocks['engine'] = createWebSocket('engine', beamngHost, beamngWsPort)
  }

  /********************************************************/
  /** websocket START */
  function createWebSocket(tag, host, port, service) {
    var webSocket = window.WebSocket || window.MozWebSocket;
    var ws = new webSocket('ws://' + host + ':' + port.toString(), ['bngApi']);
    ws.callbacks = {};
    ws.msgID = 0;
    ws.connectionState = 'connecting';
    // main message receiver below
    ws.onmessage = function(evt) {
      //console.log('onmessage: ', tag, evt);
      var d = JSON.parse(evt.data);
      if(d.id == -1) {
        // message from the game
        $rootScope.$broadcast(d.api, tag, d);
        return;
      }
      if(ws.callbacks[d.id]) {
        ws.callbacks[d.id](d);
        delete ws.callbacks[d.id];
      } else {
        console.error("no API callback found: ", tag, d)
      }
    };
    // state callbacks below
    ws.onclose = function(evt) {
      //console.log(tag, 'onclose');
      ws.state = 'closed';
      $rootScope.$broadcast('connectionStateChanged', tag, ws.state);
      
      // try to reconnect ourselfs
      if(!ws || ws.readyState == WebSocket.CLOSED) reconnect();
    }
    ws.onopen = function(evt) {
      //console.log(tag, 'onopen');
      ws.state = 'connected';
      $rootScope.$broadcast('connectionStateChanged', tag, ws.state);
    }
    ws.onerror = function(evt) {
      //console.log(tag, 'onerror');
      ws.state = 'error';
      $rootScope.$broadcast('connectionStateChanged', tag, ws.state);
    }
    // custom functions below
    ws.call = function(cmd, callback) {
      //console.log("call: ", tag, cmd)
      if(ws.state !== 'connected') {
        console.error("unable to send lua, connection not established: ", tag, cmd);
        return;
      }
      if(cmd.id === undefined) {
        ws.msgID++;
        if(ws.msgID > Number.MAX_SAFE_INTEGER - 1) ws.msgID = 0; // the number is large so we try to work around overwriting long running callbacks
        cmd.id = ws.msgID
      }
      cmd = JSON.stringify(cmd);
      if(callback) {
        ws.callbacks[ws.msgID] = callback;
      }
      ws.send(cmd);
    }
    return ws;
  }
  /** websocket END */
  
  reconnect();

  /********************************************************/
  /** angular functions START */


  function engineLua(cmd, callback) {
    //console.log('>> execLua send: ', q);
    var data = {api: 'engineLua'};
    data.cmd = cmd;
    if(callback === undefined) {
      data.id = -1;
    }
    websocks['engine'].call(data, callback);
  }

  function objectCall(vid, data, callback) {
    if(!websocks[vid]) return;
    if(callback === undefined) {
      data.id = -1;
    }
    websocks[vid].call(data, callback);
  }

  function objectLua(vid, cmd, callback) {
    objectCall(vid, {api: 'vehicleLua', cmd: cmd}, callback);
  }

  // we listen on this here as we maintain the vehicle connections here as well
  $rootScope.$on('vehiclesChanged', function(evt, instance, d) {
    console.log(d.data);
    $rootScope.$apply(function(){
      //$rootScope.instances = d.data.vehicles;
      for (var a in d.data.vehicles) {
        if($rootScope.instances[a]) $rootScope.instances[a] = {};
        $rootScope.instances[a] = d.data.vehicles[a];
      }
      // TODO: deleted vehicles?

      $rootScope.vehicleCount = d.data.vehicleCount;
      for(var vid in d.data.vehicles) {
        if(!websocks[vid] || websocks[vid].readyState == WebSocket.CLOSED) {
          //console.log('opening new vehicle socket: ', vid, beamngHost, lastVehicleData[vid])
          websocks[vid] = createWebSocket(vid, beamngHost, $rootScope.instances[vid].port)
        }
      }
    });
  });

  $rootScope.connectionState = 'connecting';

  $rootScope.$on('connectionStateChanged', function(evt, instance, state) {
    console.log('connectionStateChanged: ', instance, state)
    if(!$rootScope.instances[instance]) $rootScope.instances[instance] = {};
    $rootScope.instances[instance].state = state;
    
    if(instance === 'engine') {
      $rootScope.engineConnectionState = state;
      if(state === 'connected') {
        engineLua('creatorMode.requestVehicles()');
      }
    }
  });


  // return service API
  return {
    // BeamNG API high level interface
    engineLua: engineLua,
    // TODO:
    engineScript: null,
    objectLua: objectLua,
    objectCall: objectCall,
    activeObjectLua: null,
    serializeToLua: null,
  }
}])

.controller("IndexController", ['$scope', '$interval', 'bngApi', function($scope, $interval, bngApi) {


}]);
