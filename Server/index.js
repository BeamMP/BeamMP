// Server Settings!
var map = "";

const net = require('net');
const uuidv4 = require('uuid/v4');
const tcpport = 4444;
const udpport = tcpport + 1;
const host = '192.168.1.195';

const TCPserver = net.createServer();
TCPserver.listen(tcpport, () => {
  console.log('TCP Server listening on ' + host + ':' + tcpport);
});

let sockets = [];
let players = [];

TCPserver.on('connection', function(sock) {
  console.log('[TCP] CONNECTED: ' + sock.remoteAddress + ':' + sock.remotePort);
  sockets.push(sock);

  var player = {};
  player.remoteAddress = sock.remoteAddress;
  player.remotePort = sock.remotePort;
  player.nickname = "";
  player.id = uuidv4();

  players.push(player);

  sock.write('HOLA'+player.id+'\n');
  if (map == "") {
    sock.write("MAPS\n");
  } else {
    sock.write("MAPC"+map+'\n')
  }

  sock.on('data', function(data) {
    // Write the data back to all the connected, the client will receive it as data from the server
    var str = data.toString();
    data = str.trim(); //replace(/\r?\n|\r/g, "");
    var code = data.substring(0, 4);
    var message = data.substr(4);
    //console.log(code)
    switch (code) {
      case "PING":
        console.log("Ping Received")
        sock.write('PONG\n');
        break;
      case "CHAT":
        sock.write(data+'\n');
        break;
      case "MAPS":
        map = message;
        console.log("Setting map to: "+map);
        sock.write("MAPC"+map+'\n');
      case "USER":
        players.forEach(function(player, index, array) {
          if (player.nickname == "" && player.remoteAddress == sock.remoteAddress && player.remotePort == sock.remotePort) {
            console.log("Player Found ("+player.id+"), setting nickname("+data.substr(4)+")");
            player.nickname = data.substr(4);
          }
        });
        break;
      case "U-VI":
        //console.log(data)
        //players.forEach(function(player, index, array) {
          //if (player.remoteAddress != sock.remoteAddress) {
            //console.log(player.remoteAddress+' != '+sock.remoteAddress+' Is not the same so we should send?')
            //console.log("Got Update to send!")
            sockets.forEach(function(socket, index, array) { // Send update to all clients
              //console.log(socket.remotePort+' != '+sock.remotePort+' Is not the same so we should send?')
              if ((sock.remoteAddress != socket.remoteAddress && sock.remotePort != socket.remotePort) || (sock.remoteAddress == socket.remoteAddress && sock.remotePort != socket.remotePort)) {
                socket.write(data+'\n');
              }
            });
          //}
        //});
        break;
      default:
        console.log('Unknown / unhandled data: ' + sock.remoteAddress + ': ' + data);
    }
    sockets.forEach(function(sock, index, array) {
      //sock.write(sock.remoteAddress + ':' + sock.remotePort + " said " + data + '\n');
    });
  });

  // Add a 'close' event handler to this instance of socket
  sock.on('close', function(data) {
    let index = sockets.findIndex(function(o) {
      return o.remoteAddress === sock.remoteAddress && o.remotePort === sock.remotePort;
    })
    if (index !== -1) sockets.splice(index, 1);
    console.log('CLOSED: ' + sock.remoteAddress + ' ' + sock.remotePort);
  });
});

var dgram = require('dgram');
var UDPserver = dgram.createSocket('udp4');

function UDPsend(message, info) {
  UDPserver.send(message,info.port,info.address,function(error){if(error){console.log("ERROR");console.log(error);client.close();};});
}

UDPserver.on('listening', function() {
  var address = UDPserver.address();
  console.log('UDP Server listening on ' + address.address + ':' + address.port);
});

var UDPMembers = [];

UDPserver.on('message',function(msg,info){
  //sending msg
  var str = msg.toString();
  data = str.trim(); //replace(/\r?\n|\r/g, "");
  var code = data.substring(0, 4);
  switch (code) {
    case "PING":
      UDPsend("PONG", info)
      break;
    default:
      console.log('[UDP] Data received from client : ' + msg.toString());
      console.log('Received %d bytes from %s:%d\n',msg.length, info.address, info.port);
  }
});

UDPserver.bind(udpport);
