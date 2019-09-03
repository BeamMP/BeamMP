const console = require(`./console`); // Our Custom console
const fs = require('fs');
const WebSocket = require('ws');
const { spawn } = require('child_process')

module.exports = {
  javaversion: function (callback) {
    var spawn = require('child_process').spawn('java', ['-version']);
    spawn.on('error', function(err){
        return callback(err, null);
    })
    spawn.stderr.on('data', function(data) {
        data = data.toString().split('\n')[0];
        var javaVersion = new RegExp('java version').test(data) ? data.split(' ')[2].replace(/"/g, '') : false;
        if (javaVersion != false) {
            // TODO: We have Java installed
            return callback(null, javaVersion);
        } else {
            // TODO: No Java installed
          }
    });
  },

  hostGame: function (port) {
    console.log("Attempting to host multiplayer server...");
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
  },

  sendServerCommand: function(command) {
    try {
      if (child) {
        // https://stackoverflow.com/questions/13230370/nodejs-child-process-write-to-stdin-from-an-already-initialised-process
        child.stdin.setEncoding('utf-8');
        child.stdin.write(command+"\n");
        child.stdin.end(); /// this call seems necessary, at least with plain node.js executable
      }
    } catch (e) {
      console.log('Unable to send message to server. ('+e+')');
    }
  },

  readConfig: function (callback) { // This function reads our config file and if it is not found it will create it
    fs.access(`file://${__dirname}/config.json`, error => {
      if (!error) { // If config file is found then we load it and return it
        // The check succeeded, file exists
        var rawdata = fs.readFileSync(`file://${__dirname}/config.json`);
        var config = JSON.parse(rawdata);
        return callback(null, config);
      } else { // if not / else then we create the file and return our default data
        // The check failed
        var data = {
          "history": {
            "IP": "0.0.0.0",
            "Port": "30813",
          },
          "HostPort": "4450",
          "DarkMode": false
        }
        fs.writeFile ("./config.json", JSON.stringify(data, null, 2), function(err) {
          if (err) throw err;
          return callback(null, data);
        });
      }
    });
  }
}
