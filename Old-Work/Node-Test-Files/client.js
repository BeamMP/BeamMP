const WebSocket = require('ws')
var msgpack = require('msgpack');
const readline = require('readline');
const url = 'ws://192.168.0.1:3360';
const connection = new WebSocket(url);

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

connection.onopen = () => {
  connection.send('JOIN|TEST CLIENT')
  GetInput();
};

connection.onerror = (error) => {
  console.log(`WebSocket error:`)
  console.log(error)
};

connection.onmessage = (e) => {
  var str = e.data;
  var msg = str.split('|');
  if (msg[0] == 'UPDATE') {
    if (msg[1] == 'VEHICLE') {
      console.log('Vehicle Update Message from: '+msg[2]+' ')
      console.log(msg[3])
      //var d = msgpack.unpack(msg[3]);
      //console.log(d)
    }
  }
  GetInput();
};

var preventMoreThanOne = true;
function GetInput() {
  if (preventMoreThanOne) {
    preventMoreThanOne = false;
    rl.question('> ', (answer) => {
      connection.send(answer)
      rl.close();
      preventMoreThanOne = true
    });
  }
};

//GetInput()
