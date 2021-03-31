--====================================================================================
-- All work by Titch2000.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading mpConfig...")

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
  if not FS:directoryExists("settings/BeamMP") then
    return nil
  end

  local favs = nil
  local favsfile = '/settings/BeamMP/favorites.json'
  if FS:fileExists(favsfile) then
    favs = jsonReadFile(favsfile)
  else
	print("favs file doesnt exist")
  end
  return favs
end


local function setFavorites(favstr)
  if not FS:directoryExists("settings/BeamMP") then
    FS:directoryCreate("settings/BeamMP")
  end

  local favs = json.decode(favstr)
  local favsfile = '/settings/BeamMP/favorites.json'
  jsonWriteFile(favsfile, favs)
end


local function getConfig()
  if not FS:directoryExists("settings/BeamMP") then
    return nil
  end

  local file = '/settings/BeamMP/config.json'
  if FS:fileExists(file) then
    return jsonReadFile(file)
  else
	print("config file doesnt exist")
	return nil
  end
end

local function setConfig(settingName, settingVal)
	local config = getConfig()
	if not config then config = {} end

	config[settingName] = settingVal

	local favsfile = '/settings/BeamMP/config.json'
	jsonWriteFile(favsfile, config)
end


local function acceptTos()
	local config = getConfig()
	if not config then config = {} end

	config.tos = true

	local favsfile = '/settings/BeamMP/config.json'
	jsonWriteFile(favsfile, config)
end



-- Deprecated

--M.setNodesTickrate = setNodesTickrate
--M.getNodesTickrate = getNodesTickrate
--M.setInputsTickrate = setInputsTickrate
--M.getInputsTickrate = getInputsTickrate
--M.setPositionTickrate = setPositionTickrate
--M.getPositionTickrate = getPositionTickrate
--M.setElectricsTickrate = setElectricsTickrate
--M.getElectricsTickrate = getElectricsTickrate
--M.nodesDelay = nodesDelay
--M.inputsDelay = inputsDelay
--M.positionDelay = positionDelay
--M.electricsDelay = electricsDelay

-- Functions
M.getPlayerServerID = getPlayerServerID
M.setPlayerServerID = setPlayerServerID

M.getNickname = getNickname
M.setNickname = setNickname

M.getFavorites = getFavorites
M.setFavorites = setFavorites
M.getConfig = getConfig
M.setConfig = setConfig

M.acceptTos = acceptTos

print("mpConfig loaded")
return M
