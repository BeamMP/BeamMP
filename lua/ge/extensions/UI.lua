--====================================================================================
-- All work by Titch2000, jojos38 & 20dka.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading UI...")



local players = {} -- { 'apple', 'banana', 'meow' }
local pings = {}   -- { 'apple' = 12, 'banana' = 54, 'meow' = 69 }
local UIqueue = {}


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

local function updatePlayersList(playersString)
	--print(playersString)
	local players = split(playersString, ",")
	--print(dump(players))
	be:executeJS('playerList(\''..jsonEncode(players)..'\');')

	be:executeJS('playerPings(\''..jsonEncode(pings)..'\');')
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
	if tonumber(ping) == -1 then -- not connected
		--print("ping is -1")
		--guihooks.trigger("app:showConnectionIssues", false)
	elseif tonumber(ping) == -2 then -- ping too high, display warning
		guihooks.trigger("app:showConnectionIssues", true)
	else
		guihooks.trigger("setPing", ""..ping.." ms")
		guihooks.trigger("app:showConnectionIssues", false)
		pings[MPConfig.getNickname()] = ping
	end
end



local function setNickname(name)
  --print("My Nickname: "..name)
	be:executeJS('setNickname("'..name..'")')
end



local function setStatus(status)
	--be:executeJS('setStatus("'..status..'")')
	guihooks.trigger("setStatus", status)
end



local function setPlayerCount(playerCount)
	--be:executeJS('setPlayerCount("'..playerCount..'")')
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
	local message = string.sub(rawMessage, 2)
	print("Message received: "..message) -- DO NOT REMOVE
	guihooks.trigger("chatMessage", message)
	TriggerClientEvent("ChatMessageReceived", message)
end



local function chatSend(msg)
	local c = 'C:'..MPConfig.getNickname()..": "..msg
	MPGameNetwork.send(c)
	TriggerClientEvent("ChatMessageSent", c)
end








local function ready(src)
	print("UI Has now loaded ("..src..") & MP = "..tostring(MPCoreNetwork.isMPSession()))

	if MPCoreNetwork.isMPSession() then

		if src == "MP-SESSION" then
			setPing("-2")
			local Server = MPCoreNetwork.getCurrentServer()
			print("---------------------------------------------------------------")
			--dump(Server)
			if Server then
				if Server.name then
					print('Server name: '..Server.name)
					setStatus("Server: "..Server.name)
				else
					print('Server.name = nil')
				end
			else
				print('Server = nil')
			end
			print("---------------------------------------------------------------")
		end
	end
end


local function setPlayerPing(playerName, ping)
	pings[playerName] = ping
end

M.updateLoading = updateLoading
M.updatePlayersList = updatePlayersList
M.ready = ready
M.setPing = setPing
M.setNickname = setNickname
M.setStatus = setStatus
M.chatMessage = chatMessage
M.chatSend = chatSend
M.setPlayerCount = setPlayerCount
M.showNotification = showNotification
M.setPlayerPing = setPlayerPing
M.updateQueue = updateQueue
M.sendQueue = sendQueue
M.showMdDialog = showMdDialog

print("UI loaded")
return M
