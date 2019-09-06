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

local function ready() -- Only run on the calling from the UI
	println("UI Ready!")
end

local function error(message)
	println("UI Error > "..message)
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

local function setPing(ping)
	be:executeJS('document.getElementById("PING").innerHTML = "Ping : '..ping..'ms"') -- Set status
end

local function chatSend(value)
	if not value then
		println('Chat Value not set! '..value)
		return
	else
		println('Chat: Message sent = '..value)
		--ws_client:send('CHAT|'..nick..': '..value.data)
	end
end

local function joinSession(ip, port)
	println("Attempting to join session on "..ip..':'..port)
	Settings.PlayerID = Helpers.randomString(8)
	Network.JoinSession(ip, port)
end

local function hostSession(param)

end

M.onUpdate = onUpdate
M.ready = ready
M.error = error
M.console = console
M.chatSend = chatSend
M.joinSession = joinSession
M.hostSession = hostSession
M.setNickname = setNickname
M.setStatus = setStatus
M.setPing = setPing

return M
