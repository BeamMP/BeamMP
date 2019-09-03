const { spawn } = require('child_process')
const child = spawn('java', ['-jar', 'server.jar', '-console'], {maxBuffer: 2000 * 1024});
var list = [];
child.stdout.setEncoding('utf8');

child.stdout.on('data', function (chunk) {
  list.push(chunk);
  console.log(chunk.toString());
});

child.stdout.on('end', function () {
  //callback(list.join());
  console.log(list.join());
  list = [];
});

child.on('close', (code) => {
  console.log(`child process exited with code ${code}`);
});
