--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local M = {}
local Nickname = ''


-- ============= VARIABLES =============

-- ============= VARIABLES =============

local function println(stringToPrint)
	print("[BeamNG-MP] | "..stringToPrint)
end

--=============================================================================
--== UI related stuff
--=============================================================================

local function ready(ui) -- Only run on the calling from the UI
	println(ui.." UI Ready!")
	if Steam.isWorking and Steam.accountLoggedIn then
    UI.setNickname(Steam.playerName)
		println("Found Steam, Using Player Name / Gamer Name from there: "..Steam.playerName)
		be:executeJS('document.getElementById("NICKNAME").value = "'..Steam.playerName..'"') -- Set status
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

local function console(message)
	println("UI Message > "..message)
end

local function setNickname(value)
	Settings.Nickname = value
	--print('Chat Values (setChatMessage): '..value.data..' | '..chatMessage or "")
end

local function setStatus(tempStatus)
	be:executeJS('setStatus("'..tempStatus..'")')
end

local function sendGreetingToChat(ip, port)
	be:executeJS('greeting("'..tostring(ip)..':'..tostring(port)..'");')
end

local function updateChatLog(message)
	be:executeJS('addMessage("'..message..'");')
end

local function sendPlayerList(list)
	be:executeJS('playerList(\''..list..'\');')
end

local function disconnectMsgToChat()
	be:executeJS('addMessage("Disconnected from server"); setDisconnect(); clearPlayerList(); setOfflineInPlayerList();')
end

local function updatePlayerList(message)
	be:executeJS('UpdateSession("'..message..'")') -- Set Player List
end

local function setPing(ping)
	be:executeJS('setPing("'..ping..' ms")')
end

local function setUDPPing(ping)
	--be:executeJS('document.getElementById("UDPPING").innerHTML = "'..ping..'ms"')
end

local function chatSend(value)
	if not value then
		println('Chat Value not set! '..value)
		return
	else
		println('Chat: Message sent = '..value)
		Network.SendChatMessage(value)
	end
end

local function joinSession(ip, port)
	println("Attempting to join session on "..ip..':'..port)
	Settings.PlayerID = HelperFunctions.randomString(8)
	Network.JoinSession(ip, port)
end

M.onUpdate = onUpdate
M.ready = ready
M.error = error
M.console = console
M.message = message
M.chatSend = chatSend
M.joinSession = joinSession
--M.hostSession = hostSession
M.setNickname = setNickname
M.setStatus = setStatus
M.setPing = setPing
M.setUDPPing = setUDPPing
M.updateChatLog = updateChatLog
M.sendGreetingToChat = sendGreetingToChat
M.updatePlayerList = updatePlayerList
M.sendPlayerList = sendPlayerList
M.disconnectMsgToChat = disconnectMsgToChat

return M
