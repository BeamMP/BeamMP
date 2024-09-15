-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- UI API.
--- Author of this documentation is Titch
--- @module UI
--- @usage applyElectrics(...) -- internal access
--- @usage UI.handle(...) -- external access


local M = {}

local chatWindow = require("multiplayer.ui.chat")
local optionsWindow = require("multiplayer.ui.options")
local playerListWindow = require("multiplayer.ui.playerList")
require('/common/extensions/ui/flowgraph/editor_api')(M)
local gui_module = require("ge/extensions/editor/api/gui")
local gui = {setupEditorGuiTheme = nop}
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
        showOnMessage = true,
        keepActive = true
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

--- Updates the loading information/message based on the provided data.
-- @param data string The raw data message containing the code and message.
local function updateLoading(data)
	local code = string.sub(data, 1, 1)
	local msg = string.sub(data, 2)
    --print(msg)
	if code == "l" then
		guihooks.trigger('LoadingInfo', {message = msg})
	end
end

--- Prompts the user for auto join confirmation and triggers the AutoJoinConfirmation event.
-- @param data string The message to display in the confirmation prompt.
local function promptAutoJoinConfirmation(data)
    --print(data)
    guihooks.trigger('AutoJoinConfirmation', {message = data})
    local jscode = "const [IP, PORT] = ['your_server_ip', 'your_server_port'], confirmationMessage = `Do you want to connect to the server at ${IP}:${PORT}?`, userConfirmed = window.confirm(confirmationMessage); userConfirmed ? alert('Connecting to the server...') : alert('Connection canceled.');"
    --bngApi
end

--- Splits a string into fields using the specified separator.
-- @param s string The string to split.
-- @param sep string (optional) The separator to use. Defaults to a space character.
-- @return table An array containing the split fields.
local function split(s, sep)
    local fields = {}

    local sep = sep or " "
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)

    return fields
end


--- Update the players string used to create the player list in the UI when in a session.
-- @param data string
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
			username = username .. player.role.shorttag
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

--- Used to tell the Ui of new status for the updates queue.
local function sendQueue() -- sends queue to UI
	guihooks.trigger("setQueue", UIqueue)
end

--- This function is used to update the edit/spawn queue values for the UI indicator.
-- @param spawnCount number
-- @param editCount number
-- @param queuedPlayers table
local function updateQueue( spawnCount, editCount, queuedPlayers)
	local queuedPlayersJS = {}
	if (not tableIsEmpty(queuedPlayers)) then
		for key, value in pairs(queuedPlayers) do
			queuedPlayersJS[tostring(key)] = value
		end
	else
		queuedPlayersJS = nil
	end

	UIqueue = {spawnCount = spawnCount, editCount = editCount, queuedPlayers = queuedPlayersJS}
	UIqueue.show = spawnCount+editCount > 0
	sendQueue()
end

--- Used to set our ping in the top status bar. It also is used in the math for position prediction
-- @param ping number
local function setPing(ping)
	if tonumber(ping) < 0 then return end -- not connected
	guihooks.trigger("setPing", ""..ping.." ms")
	pings[MPConfig.getNickname()] = ping
end


--- Set the users nickname so that we know what our username was in lua.
-- Useful in determining who we are 
-- @param name any
local function setNickname(name)
	guihooks.trigger("setNickname", name)
end


--- Set the server name in the status bar at the top while in session
-- This is set as part of the joining process automatically
-- @param serverName string
local function setServerName(serverName)
	serverName = serverName or (MPCoreNetwork.getCurrentServer() and MPCoreNetwork.getCurrentServer().name)
	guihooks.trigger("setServerName", serverName)
end


--- Update the player count in the top status bar when in a server. Should be preformatted
-- This is set as part of the joining process automatically and is updated during the session
-- @param playerCount string
local function setPlayerCount(playerCount)
	guihooks.trigger("setPlayerCount", playerCount)
end


--- Display a prompt in the top corner as a notification, Good for server related events like joins/leaves
-- @param text string
-- @param category string 
-- @param icon string material_ icons from ui\assets\Sprites\svg-symbols.svg example: smoking_rooms
local function showNotification(text, category, icon)
	log('I', 'showNotification', "[Message] > "..tostring(text))
	
	ui_message(''..text, 10, category or text, icon)
end
--- Show a UI dialog / alert box to inform the user of something.
-- @param options any
local function showMdDialog(options)
	guihooks.trigger("showMdDialog", options)
end

-- -------------------------------------------------------------
-- ----------------------- Chat Stuff --------------------------
-- -------------------------------------------------------------

--- Render the IMGUI chat window and playerlist windows + the settings for them.
local function renderWindow()
    if not configLoaded then return end

    gui.setupWindow("BeamMP Chat")

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


--- This function is used to load the settings and config of the UI (chat)
local function loadConfig()
    local config = io.open("./settings/BeamMP/chat.json", "r")
    if not config then -- Write new config
        log("I", "chat", "No config found, creating default")

        local jsonData = jsonEncode(M.defaultSettings)
        config = io.open("./settings/BeamMP/chat.json", "w")
        config:write(jsonData)

        log("I", "chat", "Default config created")
		config:close()
    end

    -- Read config
	config = io.open("./settings/BeamMP/chat.json", "r")
    local jsonData = config:read("*a")
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

--- Function is for when the game receives a new chat message from the server. 
-- This is for handling the raw chat message
-- @param rawMessage string The raw chat message with header codes
local function chatMessage(rawMessage) -- chat message received (angular)
	chatcounter = chatcounter+1
	local message = string.sub(rawMessage, 2)
	local parts = split(message, ':')
	local username = parts[1]
	parts[1] = ''
	local msg = string.gsub(message, username..': ', '')
	local player = MPVehicleGE.getPlayerByName(username)
	if player then
        username = username .. player.role.shorttag
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


--- Sends a chat message to the server for viewing by other players.
-- @param msg string The chat message typed by the user
local function chatSend(msg)
	local c = 'C:'..MPConfig.getNickname()..": "..msg
	MPGameNetwork.send(c)
	TriggerClientEvent("ChatMessageSent", c)
end

--- 
local function bringToFront()
    windowOpacity = 0.9
    fadeTimer = 0
end

--- Toggle the IMGUI chat to show or hide
local function toggleChat()
    if not M.canRender then
        M.canRender = true
        windowOpacity = 0.9
    else
        M.canRender = false
    end
end

--- This function is for mapping player pings to names for the playerlist
-- @param playerName string The player name
-- @param ping number The players ping
local function setPlayerPing(playerName, ping)
	pings[playerName] = ping
end

--- Executes when the user or mod ends a mission/session (map) .
-- @param mission table The mission object.
local function onClientEndMission(mission)
    pings = {}
    chatWindow.chatMessages = {}
    chatWindow.clearHistory()
end

--- Triggered by BeamNG when the lua mod is loaded by the modmanager system.
-- We use this to load our UI and config
local function onExtensionLoaded()
    log("D", "MPInterface", "Loaded")
	gui_module.initialize(gui)
	gui.registerWindow("BeamMP Chat", imgui.ImVec2(333, 266))
	gui.showWindow("BeamMP Chat")

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

--- onUpdate is a game eventloop function. It is called each frame by the game engine.
-- This is the main processing thread of BeamMP in the game
-- @param dt float
local function onUpdate(dt)
    if worldReadyState ~= 2 or not settings.getValue("enableNewChatMenu") or not initialized or not M.canRender or MPCoreNetwork and not MPCoreNetwork.isMPSession() then return end
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
M.onInit = function() setExtensionUnloadMode(M, "manual") end

return M
