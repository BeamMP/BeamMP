--====================================================================================
-- All work by Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local M = {}

local function updateLoading(data)
  print(data)
  local code = string.sub(data, 1, 1)
  local msg = string.sub(data, 2)

  if code == "l" then
    guihooks.trigger('LoadingInfo', {
      message = msg
    })
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

local function ready()
  print("UI / Game Has now loaded")
  -- Now start the TCP connection to the launcher to allow the sending and receiving of the vehicle / session data
  GameNetwork.connectToLauncher()
end

M.updateLoading = updateLoading
M.ready = ready
M.setPing = setPing
M.setStatus = setStatus
M.setPlayerCount = setPlayerCount

return M
