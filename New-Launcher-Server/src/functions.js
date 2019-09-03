const console = require(`./console`); // Our Custom console
const fs = require('fs');
const WebSocket = require('ws');
const { spawn } = require('child_process')

module.exports = {
  getWindow: function (windowName) {
    for (var i = 0; i < windowArray.length; i++) {
      if (windowArray[i].name == windowName) {
        return windowArray[i].window;
      }
    }
    return null;
  },

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

  joinGame: function (ip, port) {
    console.log("Attempting to join multiplayer server @"+ip+":"+port);
    const serverWS = new WebSocket('ws://'+ip+':'+port+'/');
    serverWS.on('open', function open() {
      serverWS.send('');
    });
  },

  hostGame: function (port) {
    const remote = require('electron').remote;
    const BrowserWindow = remote.BrowserWindow;
    var win = new BrowserWindow({ width: 600, height: 400 });
    // and load the index.html of the app.
    //win.loadFile('index.html')
    win.loadURL(`file://${__dirname}/server.html`);

    // Open the DevTools.
    //win.webContents.openDevTools()

    // Emitted when the window is closed.
    win.on('closed', function () {
      // Dereference the window object, usually you would store windows
      // in an array if your app supports multi windows, this is the time
      // when you should delete the corresponding element.
      win = null
    })

    // Hide the toolbar at the top, E.g file, view, edit
    win.setMenuBarVisibility(false)
  },

  readConfig: function (callback) { // This function reads our config file and if it is not found it will create it
    fs.access(`./config.json`, error => {
    //fs.access(`file://${__dirname}/config.json`, error => {
      if (!error) { // If config file is found then we load it and return it
        // The check succeeded, file exists
        //var rawdata = fs.readFileSync(`file://${__dirname}/config.json`);
        var rawdata = fs.readFileSync(`./config.json`);
        var config = JSON.parse(rawdata);
        return callback(null, config);
      } else { // if not / else then we create the file and return our default data
        // The check failed
        console.log(error);
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
  },

  forwardToServer: function (mesage) {
    if (serverWS != NULL) {
      serverWS.send(message); // send to the game server TODO: format the message
    }
  }
}
