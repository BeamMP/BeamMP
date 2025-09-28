# Multiplayer Career Mode: Server Integration Guide

## 1. Overview

This document outlines the client-side implementation of the foundational features for a multiplayer career mode in BeamMP. It is intended for a C++ developer who will be implementing the corresponding server-side logic in the `BeamMP-Server` project.

The client-side implementation handles three core responsibilities:
1.  **Reporting Mission Completion:** Notifying the server when a player finishes a mission.
2.  **Requesting Player Balance:** Allowing a player to check their balance using chat commands.
3.  **Handling State Updates:** Receiving and processing career data (like balance updates) from the server.

The communication is handled via the existing `TriggerServerEvent` system. This guide details the specific events, their data payloads, and the expected server-side behavior.

## 2. Client-Side Modules

The implementation is spread across three key Lua files:

*   `lua/ge/extensions/MPCoreNetwork.lua`:
    *   Hooks into the game's `onClientEndMission` event to detect when a mission is finished.
    *   Sends the `Career:missionCompleted` event to the server.

*   `lua/ge/extensions/UI.lua`:
    *   Intercepts chat commands (`/money`, `/balance`) to send the `Career:RequestBalance` event.
    *   Listens for the `Career:BalanceInfo` event from the server.
    *   Handles all user-facing notifications and messages related to career events (balance updates, etc.).

*   `lua/ge/extensions/career_client.lua` (New Module):
    *   Acts as a centralized client-side cache for career data.
    *   Currently, it stores the player's balance locally so that other UI elements can access it without needing to query the server.

## 3. Server-Client Communication Protocol

The entire system relies on a simple event-based protocol.

### 3.1. Events Sent from Client to Server

#### a) `Career:missionCompleted`
*   **Trigger:** Fired automatically when a player completes any mission while in a multiplayer session.
*   **Data Payload:** A JSON string representing the game's native `mission` object. The structure of this object is determined by the BeamNG.drive game engine.
*   **Expected Server Behavior:**
    1.  Receive the event and the player's ID.
    2.  Parse the JSON `missionData` string into a usable data structure.
    3.  **Validate the mission:** This is a critical step. The server should have a list of valid "career mode" missions. It should check if the completed mission is on this list. This prevents players from farming rewards on short, non-career missions.
    4.  If the mission is valid, calculate the reward (e.g., a fixed amount, or based on mission score/time).
    5.  Add the reward to the player's balance.
    6.  Persist the player's updated data (e.g., save to a database or a player-specific JSON file).
    7.  (Recommended) Send a `Career:BalanceInfo` event back to the client to confirm the transaction and update their UI.

#### b) `Career:RequestBalance`
*   **Trigger:** Fired when a player types `/money` or `/balance` in the chat.
*   **Data Payload:** None. The server should identify the player via their connection ID.
*   **Expected Server Behavior:**
    1.  Receive the event and the player's ID.
    2.  Look up the player's current balance from the persisted data storage.
    3.  Send the balance back to the requesting client using the `Career:BalanceInfo` event.

### 3.2. Events Sent from Server to Client

#### a) `Career:BalanceInfo`
*   **Trigger:** Fired by the server in response to a balance request or after a player's balance has been updated (e.g., after a mission reward).
*   **Data Payload:** A string containing the player's new total balance (e.g., `"5000"`).
*   **Client-Side Behavior:**
    1.  The `onBalanceInfoReceived` handler in `UI.lua` is triggered.
    2.  The balance string is converted to a number.
    3.  The balance is stored in the `career_client.lua` cache via `career_client.setBalance()`.
    4.  A system message is displayed in the chat (e.g., "Your current balance is: $5000").
    5.  A prominent UI notification is displayed on the screen.

## 4. Getting Started for Server Developer

1.  **Locate the Event Handler:** The first step is to find the C++ code in `BeamMP-Server/src` that handles incoming network packets, specifically those prefixed with `E:` which corresponds to `TriggerServerEvent` from the client.
2.  **Register Event Handlers:** Implement a mechanism (likely a map or a switch-case) to route incoming event names (`Career:missionCompleted`, `Career:RequestBalance`) to specific C++ functions.
3.  **Implement Career Logic:** Create a `CareerManager` class or similar structure to contain the logic for validating missions, calculating rewards, and managing player data.
4.  **Implement Data Persistence:** Use a robust method for saving and loading player data. For initial development, a JSON library (like `nlohmann/json`, which might already be a dependency) to read/write from player-specific files would be sufficient.
5.  **Implement Response Events:** Use the server's equivalent of `TriggerClientEvent` to send the `Career:BalanceInfo` event back to the appropriate client.