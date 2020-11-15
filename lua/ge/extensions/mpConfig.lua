-- FIXME
-- This should be removed?


local M = {}
print("mpConfig Initialising...")



-- MP VARIABLES
local Nickname = ""
local PlayerServerID = -1

local function setNickname(x)
  print("Nickname Set To: "..x)
  Nickname = x
end

local function getNickname()
  return Nickname
end

local function setPlayerServerID(x)
  PlayerServerID = x
end

local function getPlayerServerID()
	return PlayerServerID
end

local function setNodesTickrate(x)
  nodesTickrate = x
end

local function getNodesTickrate()
  return nodesTickrate
end

local function setPositionTickrate(x)
  positionTickrate = x
end

local function getPositionTickrate()
  return positionTickrate
end

local function setInputsTickrate(x)
  inputsTickrate = x
end

local function getInputsTickrate()
  return inputsTickrate
end



-- Variables
M.ShowNameTags = ShowNameTags
M.Nickname = Nickname
M.PlayerServerID = PlayerServerID
M.getPlayerServerID = getPlayerServerID
M.setPlayerServerID = setPlayerServerID
M.State = State
M.nodesDelay = nodesDelay
M.nodesTickrate = nodesTickrate
M.positionDelay = positionDelay
M.positionTickrate = positionTickrate
M.inputsDelay = inputsDelay
M.inputsTickrate = inputsTickrate



-- Functions
M.setNickname = setNickname
M.getNickname = getNickname
M.setNodesTickrate = setNodesTickrate
M.getNodesTickrate = getNodesTickrate
M.setPositionTickrate = setPositionTickrate
M.getPositionTickrate = getPositionTickrate
M.setInputsTickrate = setInputsTickrate
M.getInputsTickrate = getInputsTickrate



return M
