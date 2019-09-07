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
end

local function error(message)
	println("UI Error > "..message)
	ui_message(''..message, 10, 0, 0)
end

local function message(message)
	println("[Message] > "..message)
	ui_message(''..message, 10, 0, 0)
end

local function console(message)
	println("UI Message > "..message)
end

local function setNickname(value)
	Settings.Nickname = value
	--print('Chat Values (setChatMessage): '..value.data..' | '..chatMessage or "")
end

local function setStatus(tempStatus)
	be:executeJS('document.getElementById("STATUS").innerHTML = "Status: '..tempStatus..'"') -- Set status
end

local function updateChatLog(message)
	be:executeJS('UpdateChat("'..message..'")') -- Set status
end

local function setPing(ping)
	be:executeJS('document.getElementById("PING").innerHTML = "Ping: '..ping..'ms"') -- Set status
	be:executeJS('document.getElementById("TCPPING").innerHTML = "'..ping..'ms"')
end

local function setUDPPing(ping)
	be:executeJS('document.getElementById("UDPPING").innerHTML = "'..ping..'ms"')
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

return M
