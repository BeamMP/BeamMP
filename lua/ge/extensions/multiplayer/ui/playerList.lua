-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- multiplayer_ui_playerList API.
--- Author of this documentation is Titch
--- @module multiplayer_ui_playerList
--- @usage updatePlayerList(jsonData) -- internal access
--- @usage multiplayer_ui_playerList.updatePlayerList(jsonData) -- external access

local M = {}

local imgui = ui_imgui
local players = {} -- contains name and ping for each entry

--- Updates the player list based on the provided JSON data.
--- @param jsonData table The JSON data containing player information.
local function updatePlayerList(jsonData)
    local playerList = {}
    for k, v in pairs(jsonData) do
        table.insert(playerList, {name = k, ping = tostring(v)})
    end
    table.sort(playerList, function(a, b)
        return a.name < b.name
    end)
    players = playerList
end

--- Renders the player list UI.
local function render()
    local hw = imgui.GetWindowWidth() / 2

    imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize("Name").x) / 4)
    imgui.Text("Name")
    imgui.SameLine()

    imgui.SetCursorPosX((hw + hw / 2) - imgui.CalcTextSize("Ping").x)
    imgui.Text("Ping")

    imgui.Separator()

    if imgui.BeginChild1("PlayerList", imgui.ImVec2(0, 0), false) then
        for _, player in pairs(players) do
            imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(player.name).x) / 4)
            imgui.Text(player.name)
            imgui.SameLine()
            imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize(ffi.string(player.ping)).x - hw / 2))
            imgui.Text(player.ping)
        end
    end
end


M.render = render
M.updatePlayerList = updatePlayerList

return M
