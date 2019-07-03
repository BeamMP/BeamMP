const WebSocket = require('ws')

const wss = new WebSocket.Server({ port: 3360 })

var map = ""

wss.on('connection', ws => {
  ws.on('message', message => {
    console.log(`Received message => ${message}`)
    var str = message;
    var msg = str.split('|');
    if (msg[0] == 'JOIN') {
      // STEP 1 a client has asked to join the server, lets check they are using the correct map.
      console.log('BeamNG-MP Server > A new player is trying to join')
      wss.clients.forEach(function each(client) {
        if (client !== ws && client.readyState === WebSocket.OPEN) {
          client.send('CHAT|'+msg[1]+' is joining the session.');
        }
      });
      //ws.broadcast('CHAT|'+msg[1]+' is joining the session.')
      if (map == "") {
        map = msg[2]
      }
      ws.send('MAP|'+map)
    } else if (msg[0] == 'CONNECTING') {
    // STEP 2 a client is now joining having confirmed the map, we need to send them all current vehicle data
      console.log('BeamNG-MP Server > The new player has confirmed the map, Send them the session data and pause all clients')
      wss.clients.forEach(function each(client) {
        if (client !== ws && client.readyState === WebSocket.OPEN) {
          client.send('UPDATE|PAUSE|true');
        }
      });
      //ws.broadcast('UPDATE|PAUSE|true')
      ws.send('SETUP|DATA')
    } else if (msg[0] == 'CONNECTED') {
    // STEP 3 start sending out our game data again. We will be the point of sync for all players
      console.log('BeamNG-MP Server > The new player has now synced with us. Now to unpause')
      wss.clients.forEach(function each(client) {
        if (client !== ws && client.readyState === WebSocket.OPEN) {
          client.send('CHAT|'+msg[1]+' Has joined the game!');
          client.send('UPDATE|PAUSE|false');
        }
      });
      //ws.broadcast('CHAT|'+msg[1]+' Has joined the game!')
      //ws.broadcast('UPDATE|PAUSE|false')
    } else if (msg[0] == 'UPDATE') {
    // STEP 4 a client sendus new data about they session state, so we need to update our vehicles to match theirs
      console.log('BeamNG-MP Server > Received update from: '+msg[2])
      wss.clients.forEach(function each(client) {
        if (client !== ws && client.readyState === WebSocket.OPEN) {
          client.send(message);
        }
      });
      //ws.broadcast(message)
    } else if (msg[0] == 'CHAT') {
      console.log('Attempting to broadcast chat message')
      wss.clients.forEach(function each(client) {
        if (client !== ws && client.readyState === WebSocket.OPEN) {
          client.send('CHAT|'+msg[1]);
        }
      });
      //ws.broadcast('CHAT|'+msg[1])
    } else if (msg[0] == 'ERROR') {
      ws.send('ERROR|'+msg[1])
    }
  })
  ws.send('Hello! Message From Server!!')
})
