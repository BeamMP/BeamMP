# BeamNG-MP
A LUA implementation at attempting to bring local network multiplayer to BeamNG.drive

# Contents
 - Installation
 - How does this work?
 - Network Codes
 - Progression tracking.
 - Troubleshooting - connecting to and playing on servers
 - Discord link


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

You will also require the "Bridge" downloadable from here: https://github.com/Starystars67/BeamNG-MP-Bridge/releases

A handy tutorial has been made here:

<a href="http://www.youtube.com/watch?feature=player_embedded&v=EvL77tTGgJU
" target="_blank"><img src="http://img.youtube.com/vi/EvL77tTGgJU/0.jpg"
alt="BeamNG-MP Install Tutorial" width="240" height="180" border="10" /></a>

# Servers
Servers and their repository / source code has now moved to here: https://github.com/Starystars67/BeamNG-MP-Server/
Please check out the wiki tab in the above link to setup your own server.

# How does this work?
So at present the idea sits as: Player sets them self as host, by setting a port and clicking host. This creates a running configuration of the world, current vehicles so on. This config is the first file that will be sent to any clients that try to join.

Joining clients will check that they can match that configuration file. if they can then they tell the server Okay, I'm going to join. This pauses the host and any joined clients. The new client will then setup their world to match the running config which will have been updated now to be the same as the state that the host has been paused at. The new client will also be in a paused state.

Now the new client will be setting up the world its current vehicles and so on.

once the new client is setup, all players will unpause and rely on web sockets to maintain an updated gameplay. mean while the host will periodically update the running configuration.

# New Network Codes
  Format: Capital Letter Followed by option (Lowercase) then data or whatever else

  Server / Setup

  Game / Session
  - O
    - d = Vehicle Destroyed, Format: Od:<ServerVehicleID>
    - s = Vehicle Spawned, Format: Os:0:<vehicleData>, 0 for the fact that it needs a serverVehicleID still.
    - m = Vehicle Moved / Switched, Format: Om:<ServerVehicleID>
    - r = Vehicle Resetted, Format: Or:<ServerVehicleID>

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
  - PLST = Sending Player List to client
  - SMSG = Screen Based Message

  Game / Session
  - U-VR (2121) = Vehicle Destroyed (deleted) Update (Your telling this)
  - U-VC (2020) = Vehicle Config Update / Confirm / Created
  - U-VL (2134) = Vehicle Position Update (Coords)
  - U-VP (2133) = Vehicle Powertrain Update
  - U-VN (2132) = Vehicle Notes Update
  - U-VE (2131) = Vehicle Electrics Update
  - U-VI (2130) = Vehicle Inputs Update
  - U-VV = Vehicle Velocity Update

# Ports
 - TCP = 30813
 - UDP = 30814
 - WS  = 30815


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

# Troubleshooting

### “I have the mod installed, but I can’t connect to any servers…”

At this stage you should have the bridge and BeamNG-MP UI up and running but cannot connect to a server. If you don’t have one of these, please follow the video posted above (in 'Installation') carefully.

There could be several reasons why this is happening, so we’ll cover some basic problems

-	First, make sure you have entered the correct IP into bridge, copy and paste the IP from the official BeamNG-MP discord – do NOT alter the port information

-	Make sure bridge is running and has been started. Then whilst in the same map as the server is running, press CTRL+L (to refresh the UI) and then click connect using the in-game BeamNG-MP UI.

-	Ensure that you have not put an IP or port in the BeamNG-MP in-game UI. You only need to enter your nickname here

-	Make sure there is no hidden space after the IP in the bridge, this will cause this error. Also check that the server isn’t down by checking the BeamNG-MP discord

-	Javascript errors that pop up in the bridge app can be fixed by restarting bridge. Currently a new version of the bridge is being developed and should combat these errors. These errors may be frequent upon server disconnect/game close, so if in doubt, restart bridge.


### "I am connected to the server, but I am experiencing problems..."


-	“I get stuck on connecting with no vehicle”
--	Use CTRL+E to select a vehicle, you should connect after you spawn a new vehicle
-	“I can’t see other people”
--	They need to refresh their vehicle when you connect using CTRL+R
-	“I can see other people, but they can’t see me”
--	Press CTRL+R
-	“I keep getting teleported to other people’s vehicles”
--	They are resetting their cars or spawning new ones.
-	“People keep refreshing their cars”
--	Ask them to use ‘insert’ (ins on keyboard) to reset their vehicle without annoying everyone else (please 😊 )
-	“I keep getting stuck inside of people”
--	This is normal, node syncing (collision) hasn’t been properly implemented yet, but it is high priority.
-	“People are lagging and sometimes hit my/other people's vehicles”
--	This is purely a connection issue and can only be resolved by reducing ping – choose a server closer to you, and check your ping in the UI app. You want <100 preferably (Please note that if other players have high ping, you will still suffer the same issue)
-	“People’s cars are falling through the floor/sky”
--	This bug is currently being worked out, but for the mean-time disconnect from the server, relaunch bridge, and refresh the UI (CTRL+L), then connect again and refresh the vehicles (CTRL+R); this should now fix the problem. Other members of the server may also need to do this to fix the issue.


# “I cannot find a fix for my issue" or "My issue still persists”


-	Please head on over to our official discord (BeamNG-MP) and start a new support ticket, in ‘Support area’ with a brief description of the error. A member of staff will help you with your problem. 😊

https://discord.gg/4VWgTJ2

#### Please keep in mind that this is a heavy work-in-progress, everything is subject to change and thus will be updated frequently -keep an eye on the official discord for any new releases, and check you have the latest version before you make a support ticket. Many thanks!
