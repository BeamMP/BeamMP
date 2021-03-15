--====================================================================================
-- All work by Titch2000 and jojos38.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}
print("UI Initialising...")



local players = {} -- { 'apple', 'banana', 'meow' }
local pings = {}   -- { 'apple' = 12, 'banana' = 54, 'meow' = 69 }
local readyCalled = false



------------------- IMGUI

M.dependencies = {"ui_imgui"}

local gui_module = require("ge/extensions/editor/api/gui")
local gui = {setupEditorGuiTheme = nop}
local im = ui_imgui

local function setupPlayerList()
	gui_module.initialize(gui)
	gui.registerWindow("MPplayerList", im.ImVec2(256, 256))
end
local function showPlayerList()
	gui.showWindow("MPplayerList")
end
local function hidePlayerList()
	gui.hideWindow("MPplayerList")
end
local function drawPlayerList()
	if not gui.isWindowVisible("MPplayerList") then return end
	gui.setupWindow("MPplayerList")
    im.SetNextWindowBgAlpha(0.4)
	im.Begin("Playerlist")

	local thisUser = MPConfig.getNickname() or ""


	im.Columns(6, "Bar") -- gimme ein táblázat

	im.Text("Name") im.NextColumn()
	im.Text("Ping") im.NextColumn()
	im.Text("") im.NextColumn()
	im.Text("") im.NextColumn()
	im.Text("") im.NextColumn()
	im.Text("") im.NextColumn()

	local listIndex = 1
	for name, ping in pairs(pings) do
		if name ~= "" then
			listIndex = listIndex+1

			if name == thisUser then im.TextColored(im.ImVec4(0.0, 1.0, 1.0, 1.0), name) --teal if current user
			else im.Text(name) end
			im.NextColumn()

			im.Text(tostring(ping))
			im.NextColumn()

			if im.Button("Camera##"..tostring(listIndex)) then MPVehicleGE.teleportCameraToPlayer(name) end --focusCameraOnPlayer
			im.NextColumn()

			if im.Button("GPS##"..tostring(listIndex)) then MPVehicleGE.groundmarkerToPlayer(name) end
			im.NextColumn()

			if im.Button("Follow##"..tostring(listIndex)) then MPVehicleGE.groundmarkerFollowPlayer(name) end
			im.NextColumn()

			if im.Button("Teleport##"..tostring(listIndex)) then MPVehicleGE.teleportVehToPlayer(name) end
			im.NextColumn()
		end
	end

	im.Columns(1);
	im.End()
end

local function onUpdate()
	drawPlayerList()
end


M.onExtensionLoaded		= setupPlayerList
M.onUpdate				= onUpdate
M.showUI				= showPlayerList
M.hideUI				= hidePlayerList

------------------- IMGUI



local function updateLoading(data)
	local code = string.sub(data, 1, 1)
	local msg = string.sub(data, 2)
	if code == "l" then
		if msg == "Loading..." then MPCoreNetwork.addRecent() end
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
	local UIqueue = {spawnCount = tableSize(spawns), editCount = tableSize(edits), show = s}
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
	--be:executeJS('addMessage("'..message..'")')
	guihooks.trigger("chatMessage", message)
	TriggerClientEvent("ChatMessageReceived", message)
end



local function chatSend(msg)
	local c = 'C:'..MPConfig.getNickname()..": "..msg
	MPGameNetwork.send(c)
end








local function ready(src)
	print("UI / Game Has now loaded ("..src..") & MP = "..tostring(MPCoreNetwork.isMPSession()))
	-- Now start the TCP connection to the launcher to allow the sending and receiving of the vehicle / session data


	if MPCoreNetwork.isMPSession() then

		if src == "MP-SESSION" then
			setPing("-2")

			local Server = MPCoreNetwork.getCurrentServer()
			print("---------------------------------------------------------------")
			--dump(Server)
			if Server then
				local name = Server.name
				if name then
					print('Server name: '..name)
					setStatus("Server: "..name)
				else
					print('Server.name = nil')
				end
			else
				print('Server = nil')
			end
			print("---------------------------------------------------------------")
		end

		if src == "MP-GAMESTATE" then

			if not readyCalled then
				readyCalled = true
				print("[BeamMP] First Session Vehicle Removed")
				core_vehicles.removeCurrent(); -- 0.20 Fix
				commands.setFreeCamera()		 -- Fix camera

				MPGameNetwork.connectToLauncher()
			end
		end
	end
end



local function readyReset()
  readyCalled = false
end



local function setVehPing(vehicleID, ping)
	--print("Vehicle "..vehicleID.." has ping "..ping)
	local nickmap = MPVehicleGE.getNicknameMap()

	if not MPVehicleGE.isOwn(vehicleID) and nickmap[tonumber(vehicleID)] ~= nil then
		pings[nickmap[tonumber(vehicleID)]] = ping
		--print("belongs to: "..nickmap[tonumber(vehicleID)])
	end
end

local function GSUpdate(state)
	print('New GameState received')
	dump(state)
end

M.updateLoading = updateLoading
M.updatePlayersList = updatePlayersList
M.ready = ready
M.readyReset = readyReset
M.setPing = setPing
M.setNickname = setNickname
M.setStatus = setStatus
M.chatMessage = chatMessage
M.chatSend = chatSend
M.setPlayerCount = setPlayerCount
M.showNotification = showNotification
M.setVehPing = setVehPing
M.onGameStateUpdate = GSUpdate
M.updateQueue = updateQueue


return M
