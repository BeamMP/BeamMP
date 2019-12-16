// Modules to control application life and create native browser window
const {app, BrowserWindow} = require('electron')
const path = require('path')

// Keep a global reference of the window object, if you don't, the window will
// be closed automatically when the JavaScript object is garbage collected.
let mainWindow

var windowReady = false
function createWindow () {
  // Create the browser window.
  mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    webPreferences: {
      nodeIntegration: true,
      preload: path.join(__dirname, 'preload.js')
    }
  })

  // and load the index.html of the app.
  mainWindow.loadFile('index.html')

  windowReady = true

  // Open the DevTools.
  // mainWindow.webContents.openDevTools()

  // Emitted when the window is closed.
  mainWindow.on('closed', function () {
    // Dereference the window object, usually you would store windows
    // in an array if your app supports multi windows, this is the time
    // when you should delete the corresponding element.
    mainWindow = null
  })
}

// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.on('ready', createWindow)

// Quit when all windows are closed.
app.on('window-all-closed', function () {
  // On macOS it is common for applications and their menu bar
  // to stay active until the user quits explicitly with Cmd + Q
  if (process.platform !== 'darwin') app.quit()
})

app.on('activate', function () {
  // On macOS it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.
  if (mainWindow === null) createWindow()
})

// In this file you can include the rest of your app's specific main process
// code. You can also put them in separate files and require them here.

function SendToUI(type, data) {
  if (windowReady) {
    mainWindow.webContents.send(type, data)
  }
}

// Server Settings!
var map = "";

const net = require('net');
const uuidv4 = require('uuid/v4');
const args = require('minimist')(process.argv.slice(2));
console.log(args.port)
if (args.port) {
  var tcpport = args.port;
} else {
  var tcpport = 30813;
}
var udpport = tcpport + 1;
const host = '192.168.1.195';

const TCPserver = net.createServer();
TCPserver.listen(tcpport, () => {
  console.log('TCP Server listening on ' + TCPserver.address().address + ':' + tcpport);
  SendToUI('log', 'TCP Server listening on ' + TCPserver.address().address + ':' + tcpport)
});

let sockets = [];
let players = [];
let vehicles = [];

TCPserver.on('connection', function(sock) {
  console.log('[TCP] CONNECTED: ' + sock.remoteAddress + ':' + sock.remotePort);
  sockets.push(sock);

  var player = {};
  player.remoteAddress = sock.remoteAddress;
  player.remotePort = sock.remotePort;
  player.nickname = "";
  player.id = uuidv4();
  player.currentVehID = 0;

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
    console.log(code)
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
      case "U-VE":
      case "U-VN":
      case "U-VP":
      case "U-VL":
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
      case "U-NV":
        console.log(message)
        var vid = uuidv4();

        break;
      case "C-VS": // Client has changed vehicle. lets update our records.
        console.log(message)
        players.forEach(function(player, index, array) {
          if (player.currentVehID != message && player.remoteAddress == sock.remoteAddress && player.remotePort == sock.remotePort) {
            console.log("Player Found ("+player.id+"), updating current vehile("+message+")");
            player.currentVehID = message;
          }
        });
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

  sock.on('error', (err) => {
    // handle errors here
    if (err == "ECONNRESET") {
      console.error("Connection Reset!")
    } else {
      console.error("Sock Error");
      console.error(err);
      throw err;
    }
  });
});

TCPserver.on('error', (err) => {
  // handle errors here
  console.error("TCPserver Error");
  console.error(err);
  throw err;
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
