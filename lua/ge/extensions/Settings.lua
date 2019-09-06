--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local M = {}
local Nickname = ''
local PlayerID = ''

local function SettingsReset() -- Used for resetting the main settings like username, and such
  Nickname = ''
  PlayerID = ''
end

local function SessionReset() -- used for resetting current session specifics only
  PlayerID = ''
end

M.SettingsReset = SettingsReset
M.SessionReset = SessionReset
M.Nickname = Nickname
M.PlayerID = PlayerID

return M
