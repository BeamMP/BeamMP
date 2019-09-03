--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local M = {}

-- ============= VARIABLES =============
local socket = require('socket')
local TCPSocket
local connectionStatus = 0 -- Status: 0 not connected | 1 connecting | 2 connected
local twoSecondsTimer = 2
local serverTimeoutTimer = 0
local playersMap = {}
local nickname = ""
local serverPlayerID = ""
local sysTime = 0
local pingStatus = "ready"
local pingTimer = 0
local timeoutMax = 15 --TODO: SET THE TIMER TO 30 SECONDS
local timeoutWarn = 7 --TODO: SET THE TIMER TO 5 SECONDS ONCE WE ARE MORE STREAMLINED
-- ============= VARIABLES =============

--================================ Function return + Handling ================================

M.onUpdate             = onUpdate

return M
