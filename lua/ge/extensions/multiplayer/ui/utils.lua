-- BeamMP, the BeamNG.drive multiplayer mod.
-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
--
-- BeamMP Ltd. can be contacted by electronic mail via contact@beammp.com.
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU Affero General Public License as published
-- by the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Affero General Public License for more details.
--
-- You should have received a copy of the GNU Affero General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

--- multiplayer_ui_utils API.
--- Author of this documentation is Titch
--- @module multiplayer_ui_utils
--- @usage copyTable(t) -- internal access
--- @usage multiplayer_ui_utils.imageButton(texID, size, color, activeColor, hoveredColor) -- external access

local M = {}

local imgui = ui_imgui

--- Creates an image button with the specified texture ID, size, and colors using IMGUI.
--- @param texID number The ID of the texture to use for the button.
--- @param size number The size of the button.
--- @param color table (optional) The color of the button. Defaults to the ImGui button color.
--- @param activeColor table (optional) The color of the button when active. Defaults to the ImGui active button color.
--- @param hoveredColor table (optional) The color of the button when hovered. Defaults to the ImGui hovered button color.
--- @return boolean Returns true if the button was clicked, false otherwise.
M.imageButton = function(texID, size, color, activeColor, hoveredColor)
    local colors = imgui.GetStyle().Colors
    color = color or colors[imgui.Col_Button]
    activeColor = activeColor or colors[imgui.Col_ButtonActive]
    hoveredColor = hoveredColor or colors[imgui.Col_ButtonHovered]

    -- Remove background
    imgui.PushStyleColor2(imgui.Col_Button, imgui.ImVec4(0, 0, 0, 0))
    local buttonSize = imgui.ImVec2(size, size)
    if imgui.ImageButton("##ImageButton" .. tostring(texID), texID, buttonSize, imgui.ImVec2Zero, imgui.ImVec2One, imgui.ImVec4(0, 0, 0, 0), imgui.ImVec4(1, 1, 1, 1)) then
        imgui.PopStyleColor()
        return true
    end

    imgui.PopStyleColor()
    return false
end

--- Creates a deep copy of the provided table.
--- @param t table The table to copy.
--- @return table copy new table that is a deep copy of the original table.
M.copyTable = function(t)
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            v = M.copyTable(v)
        end
        copy[k] = v
    end
    return copy
end


return M
