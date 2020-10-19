var beamng
  , HookManager = {trigger: () => {}}
;


// ui loaded via a server or ingame?
if (location.protocol !== 'local:') {

(function () {
'use strict';
  
  var beamngWsPort
    , beamngHost

  if(beamngWsPort === undefined) {
    // some defaults in case the configuration failed
    beamngWsPort = 16410;     
    beamngHost = '127.0.0.1';
  }

  var websocks = {};
  beamng = {
    externalUi: true,
    language: 'en-US',
    product: 'drive'
  };

  function reconnect() {
    //console.log(">> reconnect >>");
    websocks.engine = createWebSocket('engine', beamngHost, beamngWsPort)
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
      // console.log('onmessage: ', tag, evt);
      var d = JSON.parse(evt.data);
      if(d.id == -1) {
        switch (d.api) {
          case 'jsHook':
            if (HookManager) {
              HookManager.trigger.apply(undefined, d.data);
            }
            break;
          case 'streamData':
            if (oUpdate) {
              oUpdate(d.data);
            }
            break;
          case 'beamngVar': 
            for (var key in d.data) {
              beamng[key] = d.data[key];
            }
            break;
          default:
            // message from the game
            console.log(d.api, tag, d);
        }
        // console.log(d.api, tag, d);

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
      console.log('connectionStateChanged', tag, ws.state);
      
      // try to reconnect ourselfs
      if(!ws || ws.readyState == WebSocket.CLOSED) reconnect();
    }
    ws.onopen = function(evt) {
      //console.log(tag, 'onopen');
      ws.state = 'connected';
      console.log('connectionStateChanged', tag, ws.state);

      
      // request beamng variable
      apiCall('beamngVar');
    }
    ws.onerror = function(evt) {
      //console.log(tag, 'onerror');
      ws.state = 'error';
      console.log('connectionStateChanged', tag, ws.state);
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



  function apiCall(api, cmd, callback) {
    // console.log(arguments);
    // console.log('>> execLua send: ', api, cmd);
    var data = {api: api};
    data.cmd = cmd;
    if(callback === undefined) {
      data.id = -1;
    }
    websocks['engine'].call(data, (res) => {
      // console.log(res);
      if (res.ok && callback) {
        callback(res.result || res.stdOut);
      }
    }); 
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

  // mock beamng obj;
  beamng.sendEngineLua = apiCall.bind(undefined, 'engineLua');
  beamng.sendActiveObjectLua = apiCall.bind(undefined, 'activeObject');
  beamng.queueAllObjectLua = apiCall.bind(undefined, 'allObjects');
  beamng.sendGameEngine = apiCall.bind(undefined, 'engineScript');
})();
}