--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local M = {}
local Nickname = ''
local PlayerID = ''
local ClientID = Helpers.randomString(8)
local PORT = 4444
local IP = "127.0.0.1"
local Protocol = "TCP"

local function SettingsReset() -- Used for resetting the main settings like username, and such
  Nickname = ''
  PlayerID = ''
end

local function SessionReset() -- used for resetting current session specifics only
  PlayerID = ''
  Network.disconnectFromServer()
end

M.SettingsReset = SettingsReset
M.SessionReset = SessionReset
M.Nickname = Nickname
M.PlayerID = PlayerID
M.ClientID = ClientID
M.IP = IP
M.PORT = PORT
M.Protocol = Protocol

return M
