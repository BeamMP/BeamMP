-- Note: Colors are not used anymore but I may add them back in the future

local M = {}

local utils = require("multiplayer.ui.utils")
local ffi = require('ffi')

M.chatMessages = {}

local imgui = ui_imgui
local heightOffset = 20
local forceBottom = false
local scrollToBottom = false
local chatMessage = imgui.ArrayChar(256)
local wasMessageSent = false

local function sendChatMessage(message)
    if message[0] == 0 then return end

    message = ffi.string(message)
    local messageTable = {
        message = message,
        sentTime = os.time(),
        id = #M.chatMessages + 1
    }

    local c = 'C:'..MPConfig.getNickname()..": "..message
	MPGameNetwork.send(c)
	TriggerClientEvent("ChatMessageSent", c)

    -- table.insert(M.chatMessages, messageTable) -- ! For debugging, remove this line and messageTable (addMessage handles this)
    wasMessageSent = true
    ffi.copy(chatMessage, "")
end

local function addMessage(message)
    local messageTable = {
        message = message,
        sentTime = os.time(),
        id = #M.chatMessages + 1
    }

    log("I", "chat", "Received message: " .. message)

    table.insert(M.chatMessages, messageTable)
end

local scrollbarVisible = false

local function render()
    local scrollbarSize = imgui.GetStyle().ScrollbarSize

    if imgui.BeginChild1("ChatArea", imgui.ImVec2(0, -imgui.GetTextLineHeightWithSpacing() - heightOffset), false) then
        scrollbarVisible = imgui.GetScrollMaxY() > 0
        local windowWidth = imgui.GetWindowWidth()
        local scrollbarPos = imgui.GetScrollY()

        if scrollbarPos >= imgui.GetScrollMaxY() then -- Todo: Fix scroll with multiple lines, u wanna do this Deer? :think:
            wasMessageSent = false
            forceBottom = true
        else
            forceBottom = false
        end

        for _, message in ipairs(M.chatMessages) do
            imgui.Columns(2, "ChatColumns", false)

            if not scrollbarVisible then
                imgui.SetColumnWidth(0, windowWidth - 42)
            else
                imgui.SetColumnWidth(0, windowWidth - 42 - scrollbarSize)
            end

            imgui.TextWrapped(message.message)
            imgui.NextColumn()
            imgui.Text(os.date("%H:%M", message.sentTime))

            imgui.Columns(1)
        end

        if scrollToBottom then
            imgui.SetScrollHereY(1)
            scrollToBottom = false
        end
        
        if forceBottom then
            imgui.SetScrollHereY(1)
        end

        imgui.EndChild()
    end

    imgui.PushStyleVar2(imgui.StyleVar_FramePadding, imgui.ImVec2(2, 2))
    imgui.PushStyleVar2(imgui.StyleVar_ItemSpacing, imgui.ImVec2(2, 0))
    imgui.PushStyleVar2(imgui.StyleVar_CellPadding, imgui.ImVec2(0, 0))
    imgui.SetCursorPosY(imgui.GetWindowHeight() - 35)

    imgui.PushStyleColor2(imgui.Col_FrameBg, imgui.ImVec4(UI.settings.colors.primaryColor.x, UI.settings.colors.primaryColor.y, UI.settings.colors.primaryColor.z, 1))

    if imgui.BeginChild1("ChatInput", imgui.ImVec2(0, 30), false) then
        imgui.SetNextItemWidth(imgui.GetWindowWidth() - 25)
        if imgui.InputText("##ChatInputMessage", chatMessage, 256, imgui.InputTextFlags_EnterReturnsTrue) then
            sendChatMessage(chatMessage)
            imgui.SetKeyboardFocusHere(1)
        end

        imgui.SameLine()
        if utils.imageButton(UI.uiIcons.send.texId, 20) then
            sendChatMessage(chatMessage)
            imgui.SetKeyboardFocusHere(1)
        end

        imgui.EndChild()
    end

    imgui.PopStyleColor(1)
    imgui.PopStyleVar(3)

    if wasMessageSent then
        heightOffset = 40

        if not forceBottom then
            local buttonPos = imgui.ImVec2(imgui.GetWindowWidth() - (scrollbarVisible and scrollbarSize or 0) - 24, imgui.GetWindowHeight() - 60)
            imgui.SetCursorPos(buttonPos)
            if utils.imageButton(UI.uiIcons.down.texId, 16) then
                scrollToBottom = true
                wasMessageSent = false
            end
        end
    else
        heightOffset = 20
    end
end

M.render = render
M.sendChatMessage = sendChatMessage
M.addMessage = addMessage

return M