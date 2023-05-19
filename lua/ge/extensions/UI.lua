--====================================================================================
-- All work by Titch2000, jojos38 & 20dka.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}



local players = {} -- { 'apple', 'banana', 'meow' }
local pings = {}   -- { 'apple' = 12, 'banana' = 54, 'meow' = 69 }
local UIqueue = {} -- { editCount = x, show = bool, spawnCount = x }
local playersString = "" -- "player1,player2,player3"

local chatcounter = 0

local function updateLoading(data)
	local code = string.sub(data, 1, 1)
	local msg = string.sub(data, 2)
	if code == "l" then
		guihooks.trigger('LoadingInfo', {message = msg})
	end
end

local function split(s, sep)
    local fields = {}

    local sep = sep or " "
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)

    return fields
end

local function updatePlayersList(data)
	playersString = data or playersString
	local players = split(playersString, ",")
	if not MPCoreNetwork.isMPSession() or tableIsEmpty(players) then return end
	guihooks.trigger("playerList", jsonEncode(players))
	guihooks.trigger("playerPings", jsonEncode(pings))
end


local function sendQueue() -- sends queue to UI
	guihooks.trigger("setQueue", UIqueue)
end

local function updateQueue( spawnCount, editCount)
	UIqueue = {spawnCount = spawnCount, editCount = editCount}
	UIqueue.show = spawnCount+editCount > 0
	sendQueue()
end

local function setPing(ping)
	if tonumber(ping) < 0 then return end -- not connected
	guihooks.trigger("setPing", ""..ping.." ms")
	pings[MPConfig.getNickname()] = ping
end



local function setNickname(name)
	guihooks.trigger("setNickname", name)
end



local function setServerName(serverName)
	serverName = serverName or (MPCoreNetwork.getCurrentServer() and MPCoreNetwork.getCurrentServer().name)
	guihooks.trigger("setServerName", serverName)
end



local function setPlayerCount(playerCount)
	guihooks.trigger("setPlayerCount", playerCount)
end



local function showNotification(text, type)
	if type and type == "error" then
		log('I', 'showNotification', "[UI Error] > "..tostring(text))
	else
		log('I', 'showNotification', "[Message] > "..tostring(text))
		local leftName = string.match(text, "^(.+) left the server!$")
		if leftName then MPVehicleGE.onPlayerLeft(leftName) end
		--local joinedName = string.match(text, "^Welcome (.+)!$")
		--if joinedName then MPVehicleGE.onPlayerJoined(joinedName) end
	end
	ui_message(''..text, 10, nil, nil)
end

local function showMdDialog(options)
	guihooks.trigger("showMdDialog", options)
end

local function chatMessage(rawMessage)
	chatcounter = chatcounter+1
	local message = string.sub(rawMessage, 2)
	log('M', 'chatMessage', 'Chat message received: '..message) -- DO NOT REMOVE
	guihooks.trigger("chatMessage", {message = message, id = chatcounter})
	TriggerClientEvent("ChatMessageReceived", message)
end



local function chatSend(msg)
	local c = 'C:'..MPConfig.getNickname()..": "..msg
	MPGameNetwork.send(c)
	TriggerClientEvent("ChatMessageSent", c)
end



local function setPlayerPing(playerName, ping)
	pings[playerName] = ping
end

local function clearSessionInfo()
	log('W', 'clearSessionInfo', 'Clearing session info!')
	players = {}
	pings = {}
	UIqueue = {}
	playersString = "" 
end

M.onServerLeave = clearSessionInfo
M.updateLoading = updateLoading
M.updatePlayersList = updatePlayersList
M.setPing = setPing
M.setNickname = setNickname
M.setServerName = setServerName
M.chatMessage = chatMessage
M.chatSend = chatSend
M.setPlayerCount = setPlayerCount
M.showNotification = showNotification
M.setPlayerPing = setPlayerPing
M.updateQueue = updateQueue
M.sendQueue = sendQueue
M.showMdDialog = showMdDialog

return M
