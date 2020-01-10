print("[BeamNG-MP] | Settings loaded.")
local Version = "0.0.2"
--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local M = {}
local Nickname = ''
local PlayerID = ''
local UpdateMethod = 2 -- 1 for smooth update when close (Will be out of sync at the moment) 2 Always sync using pos when more than MaxVariationDist out
local SmoothUpdateDist = 45 -- 45 is about 4 - 5 car lengths
local MaxVariationDist = 2 -- 2 for 2 grid squares our of sync
local ClientID = HelperFunctions.randomString(8)
local PORT = 4444
local IP = "127.0.0.1"
local Protocol = "UDP"
local Debug = false

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
M.SmoothUpdateDist = SmoothUpdateDist
M.UpdateMethod = UpdateMethod
M.MaxVariationDist = MaxVariationDist
M.Nickname = Nickname
M.PlayerID = PlayerID
M.ClientID = ClientID
M.IP = IP
M.PORT = PORT
M.Protocol = Protocol
M.Version = Version
M.Debug = Debug

return M
