function ConnectingClient() -- triggered on each new joining client
  PauseGame()
  GetGameState()
  TimeoutWatcher()
  LogNewClient()
end

function CreateHostedSession() -- Establish our webserver for allowing connections and updating joined clients

end

function GetGameState() -- Gets the current running config / setup

end

function PauseGame() -- Guess what? It pauses the game... But wait there is more, it wont just pause us but all clients too!

end

function TimeoutWatcher() -- This will wait a x seconds before saying the joining client has timed out, this wait can be reset each time the new client makes a responce.

end

function AbortClientJoin() -- drop the connection

end

function LogNewClient() -- Stores info on the new client for later use

end

function PingClients() -- check our clients are still live

end
