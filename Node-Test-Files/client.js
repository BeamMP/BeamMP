const WebSocket = require('ws')
var msgpack = require('msgpack');
const url = 'ws://192.168.0.1:3360'
const connection = new WebSocket(url)

connection.onopen = () => {
  connection.send('Message From Client')
}

connection.onerror = (error) => {
  console.log(`WebSocket error: ${error}`)
}

connection.onmessage = (e) => {
  var str = e.data;
  var msg = str.split(' ');
  if (msg[0] == 'UPDATE') {
    if (msg[1] == 'VEHICLE') {
      console.log('Vehicle Update Message from: '+msg[2]+' ')
      var d = msgpack.unpack(msg[3]);
      console.log(d)
    }
  }
}
