-- Note: Colors are not used anymore but I may add them back in the future

local M = {
    chatMessages = {},
    newMessageCount = 0
}

local utils = require("multiplayer.ui.utils")
local ffi = require('ffi')

local imgui = ui_imgui
local heightOffset = 20
local forceBottom = false
local scrollToBottom = false
local chatMessageBuf = imgui.ArrayChar(256)
local wasMessageSent = false
local history = {}
local historyPos = -1

local inputCallbackC = ffi.cast("ImGuiInputTextCallback", function(data)
    if data.EventFlag == imgui.InputTextFlags_CallbackHistory then
        local prevHistoryPos = historyPos
        if data.EventKey == imgui.Key_UpArrow then
            historyPos = historyPos - 1
            if historyPos < 1 then
                if historyPos < 0 then
                    historyPos = #history
                else
                    historyPos = 1
                end
            end
        elseif data.EventKey == imgui.Key_DownArrow then
            if #history > 0 and historyPos == #history then
                ffi.fill(data.Buf, data.BufSize, 0)  -- Clear the buffer
                data.CursorPos = 0
                data.SelectionStart = 0
                data.SelectionEnd = 0
                data.BufTextLen = 0
                data.BufDirty = imgui.Bool(true)
                historyPos = -1
                return imgui.Int(0)  -- Return 0 to prevent further processing
            elseif historyPos == -1 then -- Empty, not on any history
                return imgui.Int(0)
            end

            historyPos = historyPos + 1
        end

        if #history > 0 and prevHistoryPos ~= historyPos then
            local t = history[historyPos]
            if type(t) ~= "string" then return imgui.Int(0) end
            local inplen = string.len(t)
            local inplenInt = imgui.Int(inplen)
            ffi.copy(data.Buf, t, math.min(data.BufSize - 1, inplen + 1))
            data.CursorPos = inplenInt
            data.SelectionStart = inplenInt
            data.SelectionEnd = inplenInt
            data.BufTextLen = inplenInt
            data.BufDirty = imgui.Bool(true);
        end
    elseif data.EventFlag == imgui.InputTextFlags_CallbackCharFilter and
        data.EventChar == 96 then -- 96 = '`'
        return imgui.Int(1)
    end
    return imgui.Int(0)
end)

local function clearHistory()
    log('I', "BeamMP UI", "Cleared chat history")
    history = {}
end

local function sendChatMessage(message)
    if message[0] == 0 then return end

    message = ffi.string(message)
    -- local messageTable = {
    --     message = message,
    --     sentTime = os.time(),
    --     id = #M.chatMessages + 1
    -- }

    local c = 'C:'..MPConfig.getNickname()..": "..message
	MPGameNetwork.send(c)
	TriggerClientEvent("ChatMessageSent", c)

    -- table.insert(M.chatMessages, messageTable) -- ! For debugging, remove this line and messageTable (addMessage handles this)
    wasMessageSent = true
    history[#history+1] = ffi.string(chatMessageBuf)
    historyPos = -1
    ffi.copy(chatMessageBuf, "")
end

local function addMessage(message)
    local messageTable = {
        message = message,
        sentTime = os.time(),
        id = #M.chatMessages + 1
    }

    table.insert(M.chatMessages, messageTable)
    if not forceBottom then
        M.newMessageCount = M.newMessageCount + 1
    end
end

local scrollbarVisible = false

local function render()
    local scrollbarSize = imgui.GetStyle().ScrollbarSize

    if imgui.BeginChild1("ChatArea", imgui.ImVec2(0, -imgui.GetTextLineHeightWithSpacing() - heightOffset), false) then
        scrollbarVisible = imgui.GetScrollMaxY() > 0
        local windowWidth = imgui.GetWindowWidth()
        local scrollbarPos = imgui.GetScrollY()

        if scrollbarPos >= imgui.GetScrollMaxY() then
            M.newMessageCount = 0
            wasMessageSent = false
            forceBottom = true
        else
            forceBottom = false
        end

        -- Render Message | Time
        for _, message in ipairs(M.chatMessages) do
            imgui.Columns(2, "ChatColumns", false)

            if not scrollbarVisible then
                imgui.SetColumnWidth(0, windowWidth - 42)
            else
                imgui.SetColumnWidth(0, windowWidth - 42 - scrollbarSize)
            end

            imgui.TextWrapped(message.message)

            if scrollToBottom or forceBottom then
                imgui.SetScrollHereY(1)
            end

            imgui.NextColumn()
            imgui.Text(os.date("%H:%M", message.sentTime))

            imgui.Columns(1)
        end

        imgui.EndChild()
    end

    if scrollToBottom then
        scrollToBottom = false
    end

    imgui.PushStyleVar2(imgui.StyleVar_FramePadding, imgui.ImVec2(2, 2))
    imgui.PushStyleVar2(imgui.StyleVar_ItemSpacing, imgui.ImVec2(2, 0))
    imgui.PushStyleVar2(imgui.StyleVar_CellPadding, imgui.ImVec2(0, 0))
    imgui.SetCursorPosY(imgui.GetWindowHeight() - 35)

    imgui.PushStyleColor2(imgui.Col_FrameBg, imgui.ImVec4(UI.settings.colors.primaryColor.x, UI.settings.colors.primaryColor.y, UI.settings.colors.primaryColor.z, 1))

    if imgui.BeginChild1("ChatInput", imgui.ImVec2(0, 30), false) then
        imgui.SetNextItemWidth(imgui.GetWindowWidth() - 25)
        if imgui.InputText("##ChatInputMessage", chatMessageBuf, 256, imgui.InputTextFlags_EnterReturnsTrue + imgui.InputTextFlags_CallbackHistory, inputCallbackC) then
            sendChatMessage(chatMessageBuf)
            imgui.SetKeyboardFocusHere(1)
        end

        imgui.SameLine()
        if utils.imageButton(UI.uiIcons.send.texId, 20) then
            sendChatMessage(chatMessageBuf)
            imgui.SetKeyboardFocusHere(1)
        end

        imgui.EndChild()
    end

    imgui.PopStyleColor(1)
    imgui.PopStyleVar(3)

    if wasMessageSent then
        heightOffset = 40

        if not forceBottom then
            imgui.SetCursorPosY(imgui.GetWindowHeight() - 60)

            -- imgui.Text(tostring(newMessageCount) .. " New Messages")
            -- imgui.SameLine()

            imgui.SetCursorPosX(imgui.GetWindowWidth() - (scrollbarVisible and scrollbarSize or 0) - 24)
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
M.clearHistory = clearHistory

return M