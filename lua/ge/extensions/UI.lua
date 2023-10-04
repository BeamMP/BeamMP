--====================================================================================
-- All work by Titch2000, jojos38, 20dka & vulcan-dev.
-- You have no permission to edit, redistribute or upload. Contact BeamMP for more info!
--====================================================================================



local M = {}

local chatWindow = require("multiplayer.ui.chat")
local optionsWindow = require("multiplayer.ui.options")
local playerListWindow = require("multiplayer.ui.playerList")
require('/common/extensions/ui/flowgraph/editor_api')(M)
local imgui = ui_imgui
local imu = require('ui/imguiUtils')
local utils = require("multiplayer.ui.utils")
local configLoaded = false

M.uiIcons = {
    settings = 0,
    send = 0,
    reload = 0,
    close = 0,
    down = 0,
    up = 0,
    back = 0,
    user = 0,
}

local windowOpacity = 0.9

M.windowOpen = imgui.BoolPtr(true)
M.windowFlags = imgui.flags(imgui.WindowFlags_NoDocking, imgui.WindowFlags_NoTitleBar)
M.windowCollapsedFlags = imgui.flags(imgui.WindowFlags_NoDocking, imgui.WindowFlags_NoTitleBar, imgui.WindowFlags_NoScrollbar, imgui.WindowFlags_NoScrollWithMouse, imgui.WindowFlags_NoResize)
M.windowMinSize = imgui.ImVec2(25, 25)
M.windowPadding = imgui.ImVec2(5, 5)

M.canRender = true

local initialized = false
local fadeTimer = 0
local collapsed = false

M.settings = {}
M.defaultSettings = {
    colors = {
        windowBackground = imgui.ImVec4(0.13, 0.13, 0.13, 0.9),
        buttonBackground = imgui.ImVec4(0.13, 0.13, 0.13, 0.9),
        buttonHovered = imgui.ImVec4(0.95, 0.43, 0.49, 1),
        buttonActive = imgui.ImVec4(0.95, 0.43, 0.49, 1),
        textColor = imgui.ImVec4(1, 1, 1, 1),
        primaryColor = imgui.ImVec4(0.13, 0.13, 0.13, 1),
        secondaryColor = imgui.ImVec4(0.95, 0.43, 0.49, 1)
    },
    window = {
        inactiveFade = true,
        fadeTime = 2.5,
        fadeWhenCollapsed = false,
        showOnMessage = true
    }
}

local windows = {
    chat = chatWindow,
    options = optionsWindow,
    playerList = playerListWindow,
}

local windowTitle = "BeamMP Chat"
local currentWindow = windows.chat
local lastSize = imgui.ImVec2(0, 0)
local firstRender = true

local players = {} -- { 'apple', 'banana', 'meow' }
local pings = {}   -- { 'apple' = 12, 'banana' = 54, 'meow' = 69 }
local UIqueue = {} -- { editCount = x, show = bool, spawnCount = x }
local playersString = "" -- "player1,player2,player3"

local chatcounter = 0

local function updateLoading(data)
	local code = string.sub(data, 1, 1)
	local msg = string.sub(data, 2)
    --print(msg)
	if code == "l" then
		guihooks.trigger('LoadingInfo', {message = msg})
	end
end

local function promptAutoJoinConfirmation(data)
    --print(data)
    guihooks.trigger('AutoJoinConfirmation', {message = data})
    local jscode = "const [IP, PORT] = ['your_server_ip', 'your_server_port'], confirmationMessage = `Do you want to connect to the server at ${IP}:${PORT}?`, userConfirmed = window.confirm(confirmationMessage); userConfirmed ? alert('Connecting to the server...') : alert('Connection canceled.');"
    --bngApi
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
	local playerListData = {}
	for index, p in ipairs(players) do
		local player = MPVehicleGE.getPlayerByName(p)
		local username = p
		local color = {}
		local id = '?'
		if player then
			local prefix = ""
			for source, tag in pairs(player.nickPrefixes)
				do prefix = prefix..tag.." " end

			local suffix = ""
			for source, tag in pairs(player.nickSuffixes)
				do suffix = suffix..tag.." " end

			username = prefix..''..username..''..suffix..''..player.role.shorttag
			local c = player.role.forecolor
			color = {[0] = c.r, [1] = c.g, [2] = c.b, [3] = c.a}
			id = player.playerID
		end
		table.insert(playerListData, {name = p, formatted_name = username, color = color, id = id})
	end
	if not MPCoreNetwork.isMPSession() or tableIsEmpty(players) then return end
	guihooks.trigger("playerList", jsonEncode(playerListData))
	guihooks.trigger("playerPings", jsonEncode(pings))
	playerListWindow.updatePlayerList(pings) -- Send pings because this is a key-value table that contains name and the ping
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

---------------------------------------------------------------
------------------------- Chat Stuff --------------------------
---------------------------------------------------------------
local function renderWindow()
    if not configLoaded then return end

    imgui.PushStyleVar2(imgui.StyleVar_WindowMinSize, (collapsed and imgui.ImVec2(lastSize.x, 20)) or M.windowMinSize)

    imgui.PushStyleVar2(imgui.StyleVar_WindowPadding, M.windowPadding)
    imgui.PushStyleVar1(imgui.StyleVar_WindowBorderSize, 0)

    imgui.PushStyleColor2(imgui.Col_WindowBg, imgui.ImVec4(M.settings.colors.windowBackground.x, M.settings.colors.windowBackground.y, M.settings.colors.windowBackground.z, windowOpacity))
    imgui.PushStyleColor2(imgui.Col_CheckMark, imgui.ImVec4(M.settings.colors.buttonActive.x, M.settings.colors.buttonActive.y, M.settings.colors.buttonActive.z, windowOpacity))

    imgui.PushStyleColor2(imgui.Col_Button, imgui.ImVec4(M.settings.colors.buttonBackground.x, M.settings.colors.buttonBackground.y, M.settings.colors.buttonBackground.z, windowOpacity))
    imgui.PushStyleColor2(imgui.Col_ButtonHovered, imgui.ImVec4(M.settings.colors.buttonHovered.x, M.settings.colors.buttonHovered.y, M.settings.colors.buttonHovered.z, windowOpacity))
    imgui.PushStyleColor2(imgui.Col_ButtonActive, imgui.ImVec4(M.settings.colors.buttonActive.x, M.settings.colors.buttonActive.y, M.settings.colors.buttonActive.z, windowOpacity))

    imgui.PushStyleColor2(imgui.Col_Text, imgui.ImVec4(M.settings.colors.textColor.x, M.settings.colors.textColor.y, M.settings.colors.textColor.z, windowOpacity))

    imgui.PushStyleColor2(imgui.Col_ResizeGrip, imgui.ImVec4(M.settings.colors.primaryColor.x, M.settings.colors.primaryColor.y, M.settings.colors.primaryColor.z, windowOpacity))
    imgui.PushStyleColor2(imgui.Col_ResizeGripHovered, imgui.ImVec4(M.settings.colors.secondaryColor.x, M.settings.colors.secondaryColor.y, M.settings.colors.secondaryColor.z, windowOpacity))
    imgui.PushStyleColor2(imgui.Col_ResizeGripActive, imgui.ImVec4(M.settings.colors.secondaryColor.x, M.settings.colors.secondaryColor.y, M.settings.colors.secondaryColor.z, windowOpacity))

    imgui.PushStyleColor2(imgui.Col_Separator, imgui.ImVec4(M.settings.colors.secondaryColor.x, M.settings.colors.secondaryColor.y, M.settings.colors.secondaryColor.z, windowOpacity))
    imgui.PushStyleColor2(imgui.Col_SeparatorHovered, imgui.ImVec4(M.settings.colors.secondaryColor.x, M.settings.colors.secondaryColor.y, M.settings.colors.secondaryColor.z, windowOpacity))
    imgui.PushStyleColor2(imgui.Col_SeparatorActive, imgui.ImVec4(M.settings.colors.secondaryColor.x, M.settings.colors.secondaryColor.y, M.settings.colors.secondaryColor.z, windowOpacity))

    imgui.PushStyleColor2(imgui.Col_ScrollbarBg, imgui.ImVec4(M.settings.colors.primaryColor.x, M.settings.colors.primaryColor.y, M.settings.colors.primaryColor.z, windowOpacity))
    imgui.PushStyleColor2(imgui.Col_ScrollbarGrab, imgui.ImVec4(M.settings.colors.secondaryColor.x, M.settings.colors.secondaryColor.y, M.settings.colors.secondaryColor.z, windowOpacity))
    imgui.PushStyleColor2(imgui.Col_ScrollbarGrabHovered, imgui.ImVec4(M.settings.colors.secondaryColor.x, M.settings.colors.secondaryColor.y, M.settings.colors.secondaryColor.z, windowOpacity))
    imgui.PushStyleColor2(imgui.Col_ScrollbarGrabActive, imgui.ImVec4(M.settings.colors.secondaryColor.x, M.settings.colors.secondaryColor.y, M.settings.colors.secondaryColor.z, windowOpacity))

    if collapsed then
        imgui.SetNextWindowSize(imgui.ImVec2(lastSize.x, 30))
    end

    if imgui.Begin("BeamMP Chat", M.windowOpen, (collapsed and M.windowCollapsedFlags or M.windowFlags)) then
        if not collapsed then
            lastSize = imgui.GetWindowSize()
        end

        -- check to fade out if inactive, check if hovered
        if M.settings.window.inactiveFade then
            if imgui.IsWindowFocused(imgui.HoveredFlags_ChildWindows) or imgui.IsWindowHovered(imgui.HoveredFlags_ChildWindows)
                -- or imgui.IsAnyItemHovered() or imgui.IsAnyItemActive() or imgui.IsAnyItemFocused() -- Not exactly sure why I added this but it might be important.
                or (collapsed and not M.settings.window.fadeWhenCollapsed) then
                windowOpacity = 0.9
                fadeTimer = 0
            else
                fadeTimer = fadeTimer + imgui.GetIO().DeltaTime
                if fadeTimer > M.settings.window.fadeTime then
                    windowOpacity = windowOpacity - 0.05
                    if windowOpacity < 0 then
                        windowOpacity = 0
                    end
                end
            end
        else
            windowOpacity = 0.9
        end

        -- local mainWindowTitle = "BeamMP Chat"
        if currentWindow == windows.chat then
            local msgCount = windows.chat.newMessageCount
            if msgCount > 0 then
                windowTitle = "BeamMP Chat (" .. tostring(msgCount) .. ')'
            else
                windowTitle = "BeamMP Chat"
            end
        end

        -- Titlebar
        imgui.PushStyleVar1(imgui.StyleVar_Alpha, windowOpacity)
        if imgui.BeginChild1("ChatTitlebar", imgui.ImVec2(0, 30), false) then
            imgui.SetCursorPosX(imgui.GetStyle().ItemSpacing.x)
            if currentWindow ~= windows.chat then
                local oldPosY = imgui.GetCursorPosY()
                imgui.SetCursorPosY(imgui.GetCursorPosY() + 4)
                if utils.imageButton(M.uiIcons.back.texId, 12) then
                    currentWindow = windows.chat
                end
                imgui.SameLine()
                imgui.SetCursorPosX(imgui.GetStyle().ItemSpacing.x + 20)
                imgui.SetCursorPosY(oldPosY)
            end

            imgui.Text(windowTitle)

            -- Collapsed
            imgui.SameLine()
            imgui.SetCursorPosX(imgui.GetWindowWidth() - 60)
            if not collapsed then
                if utils.imageButton(M.uiIcons.up.texId, 16) then
                    collapsed = true
                end
            else
                if utils.imageButton(M.uiIcons.down.texId, 16) then
                    collapsed = false
                end
            end

            -- Player List
            imgui.SameLine()
            imgui.SetCursorPosX(imgui.GetWindowWidth() - 40)
            if utils.imageButton(M.uiIcons.user.texId, 16) then
                currentWindow = windows.playerList
                windowTitle = "BeamMP Chat (Player List)"
            end

            -- Settings
            imgui.SameLine()
            imgui.SetCursorPosX(imgui.GetWindowWidth() - 20)
            if utils.imageButton(M.uiIcons.settings.texId, 16) then
                currentWindow = windows.options
                windowTitle = "BeamMP Chat (Options)"
            end
            imgui.EndChild()

            if not collapsed then
                currentWindow.render()
            end
        end
        imgui.PopStyleVar()
        imgui.End()
    end

    imgui.PopStyleColor(16)
    imgui.PopStyleVar(3)
end

local function loadConfig()
    local config = io.open("./settings/BeamMP/chat.json", "r")
    if not config then -- Write new config
        log("I", "chat", "No config found, creating default")

        local jsonData = jsonEncode(M.defaultSettings)
        config = io.open("./settings/BeamMP/chat.json", "w")
        config:write(jsonData)

        log("I", "chat", "Default config created")
    end

    -- Read config
    local jsonData = config:read("*all")
    config:close()

    local settings = jsonDecode(jsonData)
    if not settings then
        log("E", "beammp_chat", "Failed to decode config file")
        return
    end

    -- Find missing keys/settings
    local function findMissingKeys(src, tbl)
        local missing = {}
        for key, value in pairs(src) do
            if type(value) == "table" then
                local subKeys = findMissingKeys(value, tbl and tbl[key])
                for _, subKey in ipairs(subKeys) do
                    table.insert(missing, subKey)
                end
            elseif tbl == nil or tbl[key] == nil then
                table.insert(missing, key)
            end
        end

        return missing
    end

    configLoaded = true

    if #findMissingKeys(M.defaultSettings, settings) > 0 then
        log('I', "BeamMP", "Missing one or more settings, resetting config file...")
        M.settings = deepcopy(M.defaultSettings)
        optionsWindow.saveConfig(M.settings) -- we pass it in because "UI.lua" and "ui/options.lua" depend on eachother,
                                             -- so instead of doing "UI.options", we pass it in instead.
        return
    end

    M.settings = settings
end

local function chatMessage(rawMessage) -- chat message received (angular)
	chatcounter = chatcounter+1
	local message = string.sub(rawMessage, 2)
	local parts = split(message, ':')
	local username = parts[1]
	parts[1] = ''
	local msg = string.gsub(message, username..': ', '')
	local player = MPVehicleGE.getPlayerByName(username)
	if player then
		local prefix = ""
		for source, tag in pairs(player.nickPrefixes)
			do prefix = prefix..tag.." " end

		local suffix = ""
		for source, tag in pairs(player.nickSuffixes)
			do suffix = suffix..tag.." " end
		username = prefix..''..username..''..suffix..''..player.role.shorttag
		local c = player.role.forecolor
		local color = {[0] = c.r, [1] = c.g, [2] = c.b, [3] = c.a}
		log('M', 'chatMessage', 'Chat message received from: '..username..' >' ..msg) -- DO NOT REMOVE
		guihooks.trigger("chatMessage", {username = username, message = message, id = chatcounter, color = color})
		-- For IMGUI
		chatWindow.addMessage(username, msg, chatcounter, color)
	else
		log('M', 'chatMessage', 'Chat message received from: '..username.. ' >' ..msg) -- DO NOT REMOVE
		guihooks.trigger("chatMessage", {username = username, message = message, id = chatcounter})
		-- For IMGUI
		chatWindow.addMessage(username, msg, id)
	end
	TriggerClientEvent("ChatMessageReceived", message, username) -- Username added last to not break other mods.
end

local function chatSend(msg) -- sends chat message to server (angular)
	local c = 'C:'..MPConfig.getNickname()..": "..msg
	MPGameNetwork.send(c)
	TriggerClientEvent("ChatMessageSent", c)
end

local function bringToFront()
    windowOpacity = 0.9
    fadeTimer = 0
end

local function toggleChat()
    if not M.canRender then
        M.canRender = true
        windowOpacity = 0.9
    else
        M.canRender = false
    end
end

local function setPlayerPing(playerName, ping)
	pings[playerName] = ping
end

local function onClientEndMission()
    chatWindow.chatMessages = {}
    chatWindow.clearHistory()
end

local function onExtensionLoaded()
    log("D", "MPInterface", "Loaded")

    loadConfig()
    optionsWindow.onInit(M.settings)

    for k, _ in pairs(M.uiIcons) do
        local path = "./icons/" .. k .. ".png"
        if not FS:fileExists(path) then
            log("E", "MPInterface", "Missing icon: " .. k)
            goto continue
        end

        M.uiIcons[k] = imu.texObj(path)
        log("D", "MPInterface", "Loaded icon: " .. k)

        ::continue::
    end

	initialized = true
end

local function onUpdate()
    if not settings.getValue("enableNewChatMenu") or not initialized or not M.canRender or MPCoreNetwork and not MPCoreNetwork.isMPSession() then return end
    renderWindow()
end

M.updateLoading = updateLoading
M.promptAutoJoinConfirmation = promptAutoJoinConfirmation
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

M.bringToFront = bringToFront
M.toggleChat = toggleChat

M.onClientEndMission = onClientEndMission
M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate

return M
