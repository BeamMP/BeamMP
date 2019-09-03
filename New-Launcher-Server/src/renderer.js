// This file is required by the index.html file and will
// be executed in the renderer process for that window.
// All of the Node.js APIs are available in this process.
const ipc = require('electron').ipcRenderer; // Allows comm between front and back
const functions = require(`./functions.js`); // Our Helper Functions
const console = require(`./console.js`); // Our Custom console
const WebSocket = require('ws');
var net = require('net');
const host = '127.0.0.1';

//ipc.on('info' , function(event , data){ console.log(data.msg) });

var config;
functions.readConfig(function(err, c){
  config = c;
  console.log("Config loaded.");
  startLocalServer(config.HostPort);
});

function startLocalServer(port) {
  console.log("Starting Local TCP server on port "+port)
  const server = net.createServer();
  var client = new net.Socket();

  server.listen(port, () => {
    $("#localport").text(port);
    console.log('TCP Server is running on port ' + port +'.');
  });

  let sockets = [];

  server.on('connection', function(sock) { // Game Connection to us the Launcher
    console.log('CONNECTED: ' + sock.remoteAddress + ':' + sock.remotePort);

    // Get our Server IP and PORT
    var ip = $("#ip").val();
    var port = $("#port").val();

    // Attempt to connect to the MP server usign our port and ip
    console.log('Attempting to connect to Server');
    client.connect(port, ip, function() {
    	console.log('Connected');
    	client.write('Hello, server! Love, Client.');
    });

    client.on('data', function(data) { // Handle our launcher receiving data from the server
    	console.log('Received: ' + data);
      sock.write(data) // Forward that data to the game
    	//client.destroy(); // kill client after server's response
    });

    sockets.push(sock);
    //sock.write('10012\n')

    sock.on('data', function(data) {
      console.log('DATA ' + sock.remoteAddress + ': ' + data);
      //functions.forwardToServer(message);
      var code = data.slice(0,5)
      if (code == "20002") {
        // The disconnect code has been sent. Do not send to server and we now close up the connection
        client.destroy();
      }
      client.write(data); // Send our game data to our Server
    });

    client.on('close', function() {
    	console.log('Connection closed');
    });

    sock.on('close', function(data) {
      let index = sockets.findIndex(function(o) {
        return o.remoteAddress === sock.remoteAddress && o.remotePort === sock.remotePort;
      })
      if (index !== -1) sockets.splice(index, 1);
      console.log('CLOSED: ' + sock.remoteAddress + ' ' + sock.remotePort);
    });
  });
}

window.addEventListener('DOMContentLoaded', () => {
  functions.javaversion(function(err, version){
    $("#java-ver").text(version);
    console.log("Java " + version + " Found!");
  })

  $("#join-button").click(function() {
    var ip = $("#ip").val();
    var port = $("#port").val();
    if (ip != "" && port != "") {
      functions.joinGame(ip, port);
    } else {
      if (ip == "") {
        // TODO: tell user they need to fill the ip in

      } else if (port == "") {
        // TODO: tell user they need to enter the port

      }
    }
  });

  $("#host-button").click(function() {
    //var ip = $("#ip").val();
    //var port = $("#port").val();
    //if (ip != "" && port != "") {
    //console.log(config)
    functions.hostGame(config.HostPort);
    //}
  });
})
