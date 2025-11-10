--[[
	BeamMP Career Mode - Client-Side Plugin

	This is the client-side entry point for the optional career mode plugin.
	It handles all client-side logic, including chat commands, event handling,
	and local state management, without modifying core BeamMP files.
]]

-- =================================================================================================
-- Client-Side Career Module
-- =================================================================================================
local CareerClient = {}

-- Local cache for the player's balance
CareerClient.balance = 0

--- Sets the player's current balance in the local cache.
function CareerClient:setBalance(newBalance)
	if type(newBalance) == "number" then
		self.balance = newBalance
		print("[CareerClient] Local balance cache updated: " .. self.balance)
		guihooks.trigger('CareerBalanceUpdated', self.balance)
	else
		print("[CareerClient] Attempted to set invalid balance: " .. tostring(newBalance))
	end
end

--- Gets the player's cached balance.
function CareerClient:getBalance()
	return self.balance
end

-- =================================================================================================
-- Chat and Notification Handling
-- =================================================================================================

--- Displays a system message locally in the chat.
function CareerClient:showSystemMessage(text, sender, color)
    sender = sender or "[SYSTEM]"
    color = color or {[0] = 173, [1] = 216, [2] = 230, [3] = 255} -- Default to light blue

    -- This relies on the chat window being available through guihooks, which is standard.
    guihooks.trigger("chatMessage", {username = sender, message = text, id = math.random(1, 10000), color = color})
end

--- Displays a prominent on-screen notification.
function CareerClient:showNotification(text, category, icon)
	if ui_message then
		ui_message(text, 10, category or "Info", icon or "info")
	end
end

-- =================================================================================================
-- Event Handlers
-- =================================================================================================

--- Handles the 'Career:BalanceInfo' event from the server.
function CareerClient:onBalanceInfoReceived(balanceData)
	local newBalance = tonumber(balanceData)
	if newBalance then
		self:setBalance(newBalance)
		self:showSystemMessage("Your current balance is: $" .. string.format("%d", newBalance), "[CAREER]", {[0]=255, [1]=215, [2]=0, [3]=255})
		self:showNotification("Balance updated: $" .. string.format("%d", newBalance), "Career", "attach_money")
	else
		self:showSystemMessage("Received invalid balance information from the server.", "[CAREER]", {[0]=255, [1]=0, [2]=0, [3]=255})
	end
end

--- Intercepts chat messages to handle local commands.
-- This function will be hooked into the chatSend function.
function CareerClient:onChatSend(msg, cancel)
	if msg:sub(1, 1) == "/" then
		local parts = {}
		for part in msg:gmatch("([^%s]+)") do table.insert(parts, part) end
		local cmd = string.lower(parts[1])

		if cmd == "/money" or cmd == "/balance" then
			if TriggerServerEvent then
				TriggerServerEvent('Career:RequestBalance', '')
				self:showSystemMessage("Requesting your balance from the server...")
			end
			cancel.value = true -- Cancel the original chat message
		end
	end
end

--- Handles the end of a mission.
function CareerClient:onClientEndMission(mission)
	if MPCoreNetwork and MPCoreNetwork.isMPSession() and mission then
		if TriggerServerEvent then
			self:showSystemMessage("Mission finished! Sending results to the server...", "[CAREER]")
			local missionData = jsonEncode(mission)
			TriggerServerEvent('Career:missionCompleted', missionData)
		end
	end
end

-- =================================================================================================
-- Initialization
-- =================================================================================================

-- This initialization function hooks into the game's functions in a safe way.
local function initialize()
	print("[CareerClient] Initializing Career Mode Client Plugin...")

	-- 1. Hook into the chat function to intercept commands.
	if UI and UI.chatSend then
		local originalChatSend = UI.chatSend
		UI.chatSend = function(msg)
			local cancel = { value = false }
			CareerClient:onChatSend(msg, cancel)
			if not cancel.value then
				originalChatSend(msg)
			end
		end
	else
		print("[CareerClient] Warning: UI.chatSend not found. Chat commands will not work.")
	end

	-- 2. Register event handlers for server communication.
	if AddEventHandler then
		AddEventHandler('Career:BalanceInfo', function(data) CareerClient:onBalanceInfoReceived(data) end)
	else
		print("[CareerClient] Warning: AddEventHandler not found. Server communication will not work.")
	end

	-- 3. Hook into the global mission end event.
	-- This wraps the global function to ensure compatibility with other mods.
	local original_onClientEndMission = onClientEndMission
	onClientEndMission = function(mission)
		CareerClient:onClientEndMission(mission)
		if original_onClientEndMission then
			original_onClientEndMission(mission)
		end
	end

	print("[CareerClient] Career Mode Client Plugin Loaded and Initialized.")
end

initialize()