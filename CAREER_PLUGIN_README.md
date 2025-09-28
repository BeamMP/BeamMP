# BeamMP Career Mode Plugin

This repository contains an optional, standalone Career Mode plugin for BeamMP servers. It provides a basic framework for players to earn money by completing missions and check their balance. The plugin is designed to be self-contained, requiring no modifications to the core BeamMP client or server files.

## Features

- **Persistent Player Balance:** Player money is saved on the server and persists across sessions.
- **Mission Rewards:** Server owners can configure the server to award money for completing missions.
- **Mission Whitelist:** To prevent farming, server owners can specify exactly which missions grant rewards.
- **Balance Command:** Players can check their balance at any time using the `/money` or `/balance` chat commands.
- **Easy Installation:** Simple drag-and-drop installation for both clients and servers.

## Installation

This plugin consists of two parts: a **Client Plugin** and a **Server Plugin**. Both must be installed for the system to work.

### 1. Server-Side Installation

The server plugin handles all the logic for tracking player data, validating missions, and awarding money.

1.  Navigate to your BeamMP server's main directory.
2.  Open the `Resources` folder.
3.  Copy the `Server/career` directory from this repository into your `Resources` folder.

The final structure should look like this:
```
YourBeamMPServer/
└── Resources/
    └── career/
        └── main.lua
```

The server will automatically detect and load the `main.lua` script upon startup.

### 2. Client-Side Installation

The client plugin allows players to communicate with the career system (e.g., use chat commands) and receive notifications.

**Players on your server must perform these steps:**

1.  Open your BeamMP Launcher.
2.  Click on "Manage user folder".
3.  This will open the `0.xx.x.x` version folder. Navigate into the `mods` folder.
4.  Copy the `Client/career` directory from this repository into your `mods` folder.

The final structure should look like this:
```
.../BeamMP/0.xx.x.x/mods/
└── career/
    └── main.lua
```

The BeamMP client will automatically load the plugin.

## Configuration (Server-Side)

All configuration is done by editing the `Server/career/main.lua` file.

### Setting Rewards and Starting Balance

You can change the default mission reward and the starting balance for new players:

```lua
-- The reward players get for a valid, completed mission.
local missionReward = 500

-- The amount of money new players start with.
local startingBalance = 1000
```

### Whitelisting Career Missions

By default, the server will grant a reward for **any** completed mission. To prevent players from farming easy missions, you can create a whitelist of missions that are eligible for rewards.

To do this, you need to find the unique name of a mission and add it to the `validCareerMissions` table.

**Example:** To only allow rewards for the "Delivery" and "A to B" missions, you would modify the table like this:

```lua
local validCareerMissions = {
    ["delivery_1"] = true, -- The name of the first delivery mission
    ["a_to_b_mission"] = true -- The name of the A to B mission
}
```

To find a mission's name, you can temporarily modify the `onMissionCompleted` function in `Server/career/main.lua` to print the mission name:

```lua
-- In onMissionCompleted function:
print("Mission completed with name: " .. tostring(missionData.name))
```

Complete the mission in-game and check the server console for its name. Then, add it to the whitelist and remove the print statement.

## How It Works

The system uses BeamMP's built-in event system to communicate between the client and server.
- **Client -> Server:**
  - `Career:missionCompleted`: Sent when a mission ends.
  - `Career:RequestBalance`: Sent when a player types `/money`.
- **Server -> Client:**
  - `Career:BalanceInfo`: Sent to update a player's balance on their screen.

All player data is stored in a `career_data.json` file in the root of your server directory.