# BeamNG-MP
A LUA implementation at attempting to bring local network multiplayer to BeamNG.drive

# Contents
 - Installation
 - How will this work?
 - Network Codes
 - Progression tracking.


# Installation
In order to run this your self you will need to download this repository and zip the lua, scripts and ui folders up into one zip file so you have something like:
<br><br>
```
BeamNG-MP.zip
  ├─ lua/
  ├─ scripts/
  └─ ui/
```
Then put this in your mods folder typically located at Documents/BeamNG.drive/mods.

You will also require the "Launcher" this little tool is what allows you to connect and play over the internet.
It does however require you have java 64bit SE installed.
--Then your good to go, start your game, agree with your other players on a map and then host / join.

# How will this work?
So at present the idea sits as: Player sets them self as host, by setting a port and clicking host. This creates a running configuration of the world, current vehicles so on. This config is the first file that will be sent to any clients that try to join.

Joining clients will check that they can match that configuration file. if they can then they tell the server Okay, I'm going to join. This pauses the host and any joined clients. The new client will then setup their world to match the running config which will have been updated now to be the same as the state that the host has been paused at. The new client will also be in a paused state.

Now the new client will be setting up the world its current vehicles and so on.

once the new client is setup, all players will unpause and rely on web sockets to maintain an updated gameplay. mean while the host will periodically update the running configuration.

# Network Codes
  XXXX - All codes are 4 characters and can be translated to a different control

  Server / Setup
  - HOLA = Welcome / Connection Successful
  - PING = Ping request
  - USER = Username Setting
  - MAPC = Map Checking
  - MAPS = Map Setting
  - CHAT = Chat Message
  - KICK = You have been Kicked

  Game / Session
  - U-VI = Vehicle Inputs Update

# Progression tracking
you can see and keep track of progression here:
https://trello.com/b/Kw75j3zZ/beamngdrive-multiplayer

# Helpful links
https://github.com/BeamNG/luawebserver/blob/master/webserver.lua


# Helper Snippets

```
ge_utils.lua
-- returns a list of all BeamNGVehicle objects currently spawned in the level
function getAllVehicles()
    local result = {}
    local nVehicles = be:getObjectCount()
    for objectId=0,nVehicles-1,1 do
        local vehicleObj = be:getObject(objectId)
        table.insert(result, vehicleObj)
    end
    return result
end

environment.lua
getState()
setState(state)

local levelInfo = getObject("LevelInfo")
```

lua/ge/extensions/core/online.lua has the info relating to steam details.
lua/ge/extensions/util/richPresence.lua for setting discord rich presence. WRONG IT IS ACTUALLY STEAM RICH PRESENCE!
print(extensions.util_richPresence.set('Playing BeamNG.drive Multiplayer'));

lua/ge/extensions/util/researchAdapter.lua This looks like either their attempt to make a multiplayer or is what it says on the tin and is for research.
Either way this will be extremely helpful for us!

Update: Actually is for this: https://github.com/BeamNG/BeamNGpy Still was helpful for communications insights.
