const WebSocket = require('ws')
const url = 'ws://192.168.0.1:3360'
const connection = new WebSocket(url)

connection.onopen = () => {
  connection.send('Message From Client')
}

connection.onerror = (error) => {
  console.log(`WebSocket error: ${error}`)
}

connection.onmessage = (e) => {
  console.log(e.data)
}
