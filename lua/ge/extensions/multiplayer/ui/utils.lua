local M = {}

local imgui = ui_imgui

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
