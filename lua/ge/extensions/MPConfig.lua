-- FIXME
-- This should be removed?

local M = {}
print("mpConfig Initialising...")

-- MP VARIABLES
local Nickname = ""
local PlayerServerID = -1

-- MP TICK SETTINGS
local nodesDelay = 0
local nodesTickrate = 1.0 -- in seconds

local positionDelay = 0
local positionTickrate = 0.020 -- 0.016

local inputsDelay = 0
local inputsTickrate = 0.02 --0.05

local electricsDelay = 0
local electricsTickrate = 0.02

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

local function setElectricsTickrate(x)
  electricsTickrate = x
end

local function getElectricsTickrate()
  return electricsTickrate
end


local function getFavorites()
  if not FS:directoryExists("BeamMP") then
    return nil
  end

  local favs = nil
  local favsfile = '/BeamMP/favorites.json'
  if FS:fileExists(favsfile) then
    favs = jsonReadFile(favsfile)
  else
	print("favs file doesnt exist")
  end
  return favs
end


local function setFavorites(favstr)
  if not FS:directoryExists("BeamMP") then
    FS:directoryCreate("BeamMP")
  end

  local favs = json.decode(favstr)
  local favsfile = '/BeamMP/favorites.json'
  jsonWriteFile(favsfile, favs)
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
M.electricsDelay = electricsDelay
M.electricsTickrate = electricsTickrate

-- Functions
M.setNickname = setNickname
M.getNickname = getNickname
M.setNodesTickrate = setNodesTickrate
M.getNodesTickrate = getNodesTickrate
M.setPositionTickrate = setPositionTickrate
M.getPositionTickrate = getPositionTickrate
M.setInputsTickrate = setInputsTickrate
M.getInputsTickrate = getInputsTickrate
M.setElectricsTickrate = setElectricsTickrate
M.getElectricsTickrate = getElectricsTickrate

M.getFavorites = getFavorites
M.setFavorites = setFavorites

print("mpConfig Loaded.")
return M
