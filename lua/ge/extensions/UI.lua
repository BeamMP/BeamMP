--====================================================================================
-- All work by Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local M = {}
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

local function setPing(ping)
	be:executeJS('setPing("'..ping..' ms")')
end

local function setStatus(status)
	be:executeJS('setStatus("'..status..' ms")')
end

local function setPlayerCount(playerCount)
	be:executeJS('setPlayerCount("'..playerCount..' ms")')
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

local function error(message)
	println("UI Error > "..message)
	ui_message(''..message, 10, 0, 0)
end

local function message(mess)
	println("[Message] > "..mess)
	ui_message(''..mess, 10, 0, 0)
end

local function chatMessage(message)
	be:executeJS('chatMessage("'..message..'")')
end

local function ready(src)
  print("UI / Game Has now loaded ("..src..")")
  -- Now start the TCP connection to the launcher to allow the sending and receiving of the vehicle / session data
  if src == "MP-SESSION" then
    GameNetwork.connectToLauncher()
  end
end

M.updateLoading = updateLoading
M.ready = ready
M.setPing = setPing
M.setStatus = setStatus
M.chatMessage = chatMessage
M.setPlayerCount = setPlayerCount
M.showNotification = showNotification

print("UI Loaded.")
return M
