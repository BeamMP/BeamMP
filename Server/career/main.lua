--[[
	BeamMP Career Mode - Server-Side Plugin

	This script should be placed in the server's 'resources' directory.
	It handles all server-side logic for the career mode, including player data,
	mission rewards, and balance inquiries.
]]

-- =================================================================================================
-- Configuration
-- =================================================================================================
local saveDataFile = "career_data.json" -- File to save player data in the server's root directory.
local missionReward = 500 -- Fixed reward for completing any mission.
local startingBalance = 1000 -- The balance new players start with.

-- A list of valid career missions. The server will only grant rewards for missions in this list.
-- The mission name should match the 'name' field from the mission object sent by the client.
-- To grant rewards for ALL missions, simply set this to nil or an empty table.
-- Example: local validCareerMissions = { ["delivery_1"] = true, ["time_trial_west_coast"] = true }
local validCareerMissions = {}

-- =================================================================================================
-- Data Store
-- =================================================================================================
local playerData = {} -- In-memory table to store player data, e.g., { [playerID] = { balance = 1000 } }

-- =================================================================================================
-- Data Persistence Functions
-- =================================================================================================

-- Saves the playerData table to a JSON file
local function savePlayerData()
	if not json then
		print("[Career] JSON library not available. Cannot save data.")
		return
	end
	local jsonString = json.encode(playerData)
	local file = io.open(saveDataFile, "w")
	if file then
		file:write(jsonString)
		file:close()
		print("[Career] Player data saved.")
	else
		print("[Career] Error: Could not open file to save player data.")
	end
end

-- Loads player data from a JSON file into the playerData table
local function loadPlayerData()
	if not json then
		print("[Career] JSON library not available. Cannot load data.")
		return
	end
	local file = io.open(saveDataFile, "r")
	if file then
		local jsonString = file:read("*a")
		file:close()
		local success, data = pcall(json.decode, jsonString)
		if success and type(data) == "table" then
			playerData = data
			print("[Career] Player data loaded.")
		else
			print("[Career] Error: Could not decode player data or data is not a table.")
		end
	else
		print("[Career] No existing player data file found. A new one will be created.")
	end
end

-- =================================================================================================
-- Core Career Functions
-- =================================================================================================

-- Ensures a player has an entry in the data table and gives them a starting balance if they are new.
local function ensurePlayerData(playerID)
	local playerIDStr = tostring(playerID)
	if not playerData[playerIDStr] then
		playerData[playerIDStr] = { balance = startingBalance }
		print(("[Career] New player %s joined. Setting starting balance to %d."):format(playerID, startingBalance))
		savePlayerData()
	end
end

-- Adds money to a player's balance
local function addMoney(playerID, amount)
	local playerIDStr = tostring(playerID)
	ensurePlayerData(playerID)
	playerData[playerIDStr].balance = playerData[playerIDStr].balance + amount
	print(("[Career] Gave %d to player %s. New balance: %d"):format(amount, playerID, playerData[playerIDStr].balance))
	savePlayerData() -- Save after every change
end

-- Gets a player's balance
local function getBalance(playerID)
	local playerIDStr = tostring(playerID)
	ensurePlayerData(playerID)
	return playerData[playerIDStr].balance
end

-- =================================================================================================
-- Event Handlers
-- =================================================================================================

-- Handles the event when a client completes a mission
-- playerID is automatically provided by the server's event system
local function onMissionCompleted(playerID, missionDataJson)
	local success, missionData = pcall(json.decode, missionDataJson)
	if not success or type(missionData) ~= "table" then
		print(("[Career] Received invalid mission data from player %s."):format(playerID))
		return
	end

	-- Validate the mission if a whitelist is configured
	if validCareerMissions and next(validCareerMissions) ~= nil then
		if not missionData.name or not validCareerMissions[missionData.name] then
			print(("[Career] Player %s completed a non-career mission '%s'. No reward given."):format(playerID, missionData.name or "unknown"))
			return
		end
	end

	print(("[Career] Player %s completed a valid career mission. Granting reward."):format(playerID))
	addMoney(playerID, missionReward)

	-- Notify the player of their new balance
	local newBalance = getBalance(playerID)
	if MP and MP.TriggerClientEvent then
		MP.TriggerClientEvent(playerID, 'Career:BalanceInfo', tostring(newBalance))
	end
end

-- Handles a client's request for their balance
-- playerID is automatically provided by the server's event system
local function onRequestBalance(playerID, data)
	local balance = getBalance(playerID)
	print(("[Career] Player %s requested balance. Sending balance: %d"):format(playerID, balance))
	if MP and MP.TriggerClientEvent then
		MP.TriggerClientEvent(playerID, 'Career:BalanceInfo', tostring(balance))
	end
end

local function onPlayerConnected(playerID)
    ensurePlayerData(playerID)
end

-- =================================================================================================
-- Initialization
-- =================================================================================================

-- Register the events when the script loads
local function initialize()
	-- Load existing player data from file
	loadPlayerData()

	-- Register event handlers to listen for client events
	if MP and MP.RegisterEvent then
		MP.RegisterEvent("Career:missionCompleted", "onMissionCompleted")
		MP.RegisterEvent("Career:RequestBalance", "onRequestBalance")
        MP.RegisterEvent("PlayerConnect", "onPlayerConnected") -- To create data for new players
		print("[Career] Server-Side Career Plugin Loaded and Initialized.")
	else
		print("[Career] Error: MP or MP.RegisterEvent not found. Script will not function.")
	end
end

-- Run initialization
initialize()