--[[
	BeamMP Career Mode - Client-Side State Management

	This module handles the client-side state of the player's career,
	such as caching the player's balance. This allows other UI elements
	to access career data without constantly querying the server.
]]

local M = {}

-- Local cache for player's career data
local currentBalance = 0

--- Sets the player's current balance in the local cache.
-- This should be called when balance information is received from the server.
-- @param newBalance number The new balance to set.
function M.setBalance(newBalance)
	if type(newBalance) == "number" then
		currentBalance = newBalance
		log('I', 'CareerClient', 'Local balance cache updated: ' .. currentBalance)
		-- Optional: Trigger a guihook here if other UI elements need to be updated instantly
		guihooks.trigger('CareerBalanceUpdated', currentBalance)
	else
		log('W', 'CareerClient', 'Attempted to set invalid balance: ' .. tostring(newBalance))
	end
end

--- Gets the player's cached balance.
-- @return number The last known balance of the player.
function M.getBalance()
	return currentBalance
end

--- Initializes the career client module.
function M.onInit()
	-- Set an initial state or leave it at 0
	currentBalance = 0
	log('I', 'CareerClient', 'Initialized.')
end

return M