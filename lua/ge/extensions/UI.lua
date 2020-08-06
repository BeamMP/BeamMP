--====================================================================================
-- All work by Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local M = {}

local players = {}

print("UI Initialising...")

local function updateLoading(data)
  --print(data)
  local code = string.sub(data, 1, 1)
  local msg = string.sub(data, 2)

  if code == "l" then
    guihooks.trigger('LoadingInfo', {
      message = msg
    })
  end
end

local function typeof(var)
    local _type = type(var);
    if(_type ~= "table" and _type ~= "userdata") then
        return _type;
    end
    local _meta = getmetatable(var);
    if(_meta ~= nil and _meta._NAME ~= nil) then
        return _meta._NAME;
    else
        return _type;
    end
end

local function split(s, sep)
    local fields = {}

    local sep = sep or " "
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)

    return fields
end

local function updatePlayersList(playersString)
  --print(playersString)
  local players = split(playersString, ",")
  --print(dump(players))
  be:executeJS('playerList(\''..jsonEncode(players)..'\');')
end

local function setPing(ping)
	be:executeJS('setPing("'..ping..' ms")')
end

local function setNickName(name)
  print("My NickName: "..name)
	be:executeJS('setNickname("'..name..'")')
end

local function setStatus(status)
	be:executeJS('setStatus("'..status..' ms")')
end

local function setPlayerCount(playerCount)
	be:executeJS('setPlayerCount("'..playerCount..'")')
end

local function error(message)
	print("UI Error > "..message)
	ui_message(''..message, 10, 0, 0)
end

local function message(mess)
	print("[Message] > "..mess)
	ui_message(''..mess, 10, 0, 0)
end

local function showNotification(type, text)
  if text == nil then
    message(type)
  else
    if type == "error" then
      error(text)
    else
      message(text)
    end
  end
end

local function chatMessage(rawMessage)
  local message = string.sub(rawMessage, 2)
	be:executeJS('addMessage("'..message..'")')
end

local function chatSend(msg)
  local c = 'C:'..mpConfig.getNickname()..": "..msg
  print(c)
  GameNetwork.send(c)
end

local ready = true

local function ready(src, v)
  print("UI / Game Has now loaded ("..src..")")
  -- Now start the TCP connection to the launcher to allow the sending and receiving of the vehicle / session data
  if src == "MP-SESSION" or src == "FIRSTVEH" then
    if ready then
      ready = false
      GameNetwork.connectToLauncher()
    end
  end
  if src == "MP-SESSION" then
    commands.setFreeCamera() -- Fix camera
    local veh = be:getPlayerVehicle(0)
    veh:delete() -- 0.20 Fix?
    if commands.isFreeCamera(player) then commands.setGameCamera() end -- Fix camera
  end
end

local function readyReset()
  ready = true
end

M.updateLoading = updateLoading
M.updatePlayersList = updatePlayersList
M.ready = ready
M.readyReset = readyReset
M.setPing = setPing
M.setNickName = setNickName
M.setStatus = setStatus
M.chatMessage = chatMessage
M.chatSend = chatSend
M.setPlayerCount = setPlayerCount
M.showNotification = showNotification

print("UI Loaded.")
return M
