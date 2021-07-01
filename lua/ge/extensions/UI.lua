--====================================================================================
-- All work by Titch2000, jojos38 & 20dka.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}
print("Loading UI...")



local players = {} -- { 'apple', 'banana', 'meow' }
local pings = {}   -- { 'apple' = 12, 'banana' = 54, 'meow' = 69 }


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


local function updateQueue(spawns, edits, s)
	local UIqueue = {spawnCount = tableSize(spawns), editCount = tableSize(edits)}
	if s == nil then
		s = UIqueue.spawnCount+UIqueue.editCount>0
	end
	UIqueue.show = s
	guihooks.trigger("setQueue", UIqueue)
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
		print("UI Error > "..text)
	else
		print("[Message] > "..text)
	end
	ui_message(''..text, 10, 0, 0)
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



local function setVehPing(vehicleID, ping)
	--print("Vehicle "..vehicleID.." has ping "..ping)
	local nickmap = MPVehicleGE.getNicknameMap()

	if not MPVehicleGE.isOwn(vehicleID) and nickmap[tonumber(vehicleID)] ~= nil then
		pings[nickmap[tonumber(vehicleID)]] = ping
		--print("belongs to: "..nickmap[tonumber(vehicleID)])
	end
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
M.setVehPing = setVehPing
M.updateQueue = updateQueue


print("UI loaded")
return M
