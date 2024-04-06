-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- multiplayer_ui_options API.
--- Author of this documentation is Titch
--- @module multiplayer_ui_options
--- @usage saveConfig(settings) -- internal access
--- @usage multiplayer_ui_options.saveConfig(settings) -- external access

local M = {}

local utils = require("multiplayer.ui.utils")

local imgui = ui_imgui
local longestSettingName = 0
local sortedSettings = {}

--- Converts a string to title case.
--- @param str string The input string.
--- @return string str The converted string in title case.
local function toTitleCase(str)
    return str:gsub("%u", function(c) return " " .. c end):gsub("^%l", string.upper)
end

-- ------------------------------
-- ---[ Utility Functions ]------
-- ------------------------------

--- Saves the configuration settings to file.
--- @param settings table The settings to be saved. If not provided, UI.settings will be used.
local function saveConfig(settings)
    local jsonData = jsonEncode(settings or UI.settings)
    local config = io.open("./settings/BeamMP/chat.json", "w")
    config:write(jsonData)
    config:close()
end


-- ------------------------------
-- ---[       Tabs        ]------
-- ------------------------------
--- Renders the theming section of the UI.
local function renderTheming()
    if imgui.BeginChild1("Colors", imgui.ImVec2(0, imgui.GetWindowHeight() - 100), false) then
        for _, setting in pairs(sortedSettings.colors) do
            if #setting.name > longestSettingName then
                longestSettingName = #setting.name
            end
            -- All are colors, create text and then 3 sliders
            local color = ffi.new("float[4]", setting.tab.x, setting.tab.y, setting.tab.z, 1)

            imgui.Text(toTitleCase(setting.name))
            imgui.SameLine()
            imgui.SetCursorPosX(longestSettingName * 8 + 10)
            if imgui.ColorEdit3("##" .. setting.name, color, imgui.ColorEditFlags_NoInputs) then
                UI.settings.colors[setting.name] = imgui.ImVec4(color[0], color[1], color[2], 1)
                setting.tab = imgui.ImVec4(color[0], color[1], color[2], 1)
            end
        end

        imgui.EndChild()
    end

    imgui.SetCursorPosY(imgui.GetWindowHeight() - 32)
    if imgui.Button("Reset to default") then
        UI.settings = utils.copyTable(UI.defaultSettings)
        sortedSettings = {}
        local newSortedSettings = {}
        for name, category in pairs(UI.defaultSettings) do
            newSortedSettings[name] = {}
            for settingName, setting in pairs(category) do
                table.insert(newSortedSettings[name], {name = settingName, tab = setting})
            end
            table.sort(newSortedSettings[name], function(a, b) return a.name < b.name end)
        end
        sortedSettings = newSortedSettings
    end

    imgui.SameLine()

    if imgui.Button("Save") then
        saveConfig()
    end
end

--- Renders the general section of the UI.
local function renderGeneral()
    if imgui.BeginChild1("General", imgui.ImVec2(0, imgui.GetWindowHeight() - 100), false) then
        local posx = longestSettingName * 8 + 10

        -- Inactive Fade
        imgui.Text("Inactive fade")
        imgui.SameLine()
        imgui.SetCursorPosX(posx)
        local pInactiveFade = imgui.BoolPtr(UI.settings.window.inactiveFade)
        if imgui.Checkbox("##Inactive fade", pInactiveFade) then
            UI.settings.window.inactiveFade = pInactiveFade[0]
        end

        -- Fade Time
        imgui.Text("Fade time")
        imgui.SameLine()
        imgui.SetCursorPosX(posx)
        local pFadeTime = imgui.FloatPtr(UI.settings.window.fadeTime)
        imgui.PushItemWidth(120)
        if imgui.InputFloat("##Fade time", pFadeTime, 0.1, 1, "%.1f") then
            if pFadeTime[0] < 0.1 then
                pFadeTime[0] = 0.1
            end

            UI.settings.window.fadeTime = pFadeTime[0]
        end
        imgui.PopItemWidth()

        -- Fade when collapsed
        imgui.Text("Fade when collapsed")
        imgui.SameLine()
        imgui.SetCursorPosX(posx)
        local pFadeWhenCollapsed = imgui.BoolPtr(UI.settings.window.fadeWhenCollapsed)
        if imgui.Checkbox("##Fade when collapsed", pFadeWhenCollapsed) then
            UI.settings.window.fadeWhenCollapsed = pFadeWhenCollapsed[0]
        end

        -- Show on message
        imgui.Text("Show on message")
        imgui.SameLine()
        imgui.SetCursorPosX(posx)
        local pShowOnMessage = imgui.BoolPtr(UI.settings.window.showOnMessage)
        if imgui.Checkbox("##Show on message", pShowOnMessage) then
            UI.settings.window.showOnMessage = pShowOnMessage[0]
        end

	--Keep active on Enter
        imgui.Text("Keep active on Enter")
        imgui.SameLine()
        imgui.SetCursorPosX(posx)
        local pKeepActive = imgui.BoolPtr(UI.settings.window.keepActive)
        if imgui.Checkbox("##Keep active on Enter", pKeepActive) then
            UI.settings.window.keepActive = pKeepActive[0]
        end
        
        -- Bottom Buttons
        imgui.EndChild()

        imgui.SetCursorPosY(imgui.GetWindowHeight() - 32)
        if imgui.Button("Reset to default") then
            UI.settings = utils.copyTable(UI.defaultSettings)
            sortedSettings = {}
            local newSortedSettings = {}
            for name, category in pairs(UI.defaultSettings) do
                newSortedSettings[name] = {}
                for settingName, setting in pairs(category) do
                    table.insert(newSortedSettings[name], {name = settingName, tab = setting})
                end
                table.sort(newSortedSettings[name], function(a, b) return a.name < b.name end)
            end
            sortedSettings = newSortedSettings
        end

        imgui.SameLine()

        if imgui.Button("Save") then
            saveConfig()
        end
    end
end


local tabs = {
    theming = {
        name = "Theming",
        render = renderTheming,
        id = 1,
    },
    general = {
        name = "General",
        render = renderGeneral,
        id = 2,
    }
}

local renderTab = renderTheming

--- Render the IMGUI elements
local function render()
    imgui.PushStyleVar1(imgui.StyleVar_FrameRounding, 0)
    imgui.Separator()

    for _, tab in pairs(tabs) do
        if imgui.Button(tab.name, imgui.ImVec2(imgui.GetWindowWidth() / 2, 23)) then
            renderTab = tab.render
        end
        imgui.SameLine()
    end

    imgui.SetCursorPosY(66)
    imgui.Separator()
    imgui.SetCursorPosY(70)

    renderTab()
end

--- Initial call when the mod/module is loaded 
local function onInit(settings)
    sortedSettings = {} -- for reloading

    -- Sort tabs by id
    local newSortedTabs = {}
    for _, tab in pairs(tabs) do
        table.insert(newSortedTabs, tab)
    end
    table.sort(newSortedTabs, function(a, b) return a.id < b.id end)
    tabs = newSortedTabs

    -- Sort settings alphabetically
    local newSortedSettings = {}
    for name, category in pairs(settings) do
        newSortedSettings[name] = {}
        for settingName, setting in pairs(category) do
            table.insert(newSortedSettings[name], {name = settingName, tab = setting})
        end
        table.sort(newSortedSettings[name], function(a, b) return a.name < b.name end)
    end
    sortedSettings = newSortedSettings
end

M.render = render
M.onInit = onInit
M.saveConfig = saveConfig

return M
