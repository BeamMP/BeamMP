// This file is required by the index.html file and will
// be executed in the renderer process for that window.
// All of the Node.js APIs are available in this process.
const ipc = require('electron').ipcRenderer; // Allows comm between front and back
const functions = require(`./server-functions.js`); // Our Helper Functions
const console = require(`./console.js`); // Our Custom console
const WebSocket = require('ws');
var net = require('net');
const host = '127.0.0.1';

//ipc.on('info' , function(event , data){ console.log(data.msg) });

var config;
functions.readConfig(function(err, c){
  config = c;
  console.log("Config loaded.");
  functions.hostGame(config.HostPort);
});

window.addEventListener('DOMContentLoaded', () => {
  functions.javaversion(function(err, version){
    //$("#java-ver").text(version);
    console.log("Java " + version + " Found!");
  })

  $("#server-send").click(function() {
    var command = $("#server-input").val();
    $("#server-input").val('');
    functions.sendServerCommand(command);
    //}
  });

  $(document).on("keypress", function (e) {
    if (e.which == 13) { // Enter Key
      var command = $("#server-input").val();
      $("#server-input").val('');
      functions.sendServerCommand(command);
    }
  });
})
