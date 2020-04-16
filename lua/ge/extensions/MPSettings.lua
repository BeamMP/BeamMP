local M = {}
print("MPSettings Loaded.")

-- MP VARIABLES
local ShowNameTags = true
local Nickname = ""
local PlayerServerID = -1

-- MP TICK SETTINGS
local nodesDelay = 0
local nodesTickrate = 6 -- in seconds

local positionDelay = 0
local positionTickrate = 0.016

local inputsDelay = 0
local inputsTickrate = 0.05

local electricsDelay = 0
local electricsTickrate = 6



-- Variables
M.ShowNameTags = ShowNameTags
M.Nickname = Nickname
M.PlayerServerID = PlayerServerID
M.State = State
M.nodesDelay = nodesDelay
M.nodesTickrate = nodesTickrate
M.positionDelay = positionDelay
M.positionTickrate = positionTickrate
M.inputsDelay = inputsDelay
M.inputsTickrate = inputsTickrate
M.electricsDelay = electricsDelay
M.electricsTickrate = electricsTickrate

local function SetShowNameTags(x)
  ShowNameTags = x
end

local function SetNickname(x)
  Nickname = x
end

local function SetNodesTickrate(x)
  nodesTickrate = x
end

local function SetPositionTickrate(x)
  positionTickrate = x
end

local function SetInputsTickrate(x)
  inputsTickrate = x
end

local function SetElectricsTickrate(x)
  electricsTickrate = x
end


-- Functions
M.SetShowNameTags = SetShowNameTags
M.SetNickname = SetNickname
M.SetNodesTickrate = SetNodesTickrate
M.SetPositionTickrate = SetPositionTickrate
M.SetInputsTickrate = SetInputsTickrate
M.SetElectricsTickrate = SetElectricsTickrate

return M
