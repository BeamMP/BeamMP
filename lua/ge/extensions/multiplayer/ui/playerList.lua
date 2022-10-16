local M = {}

local imgui = ui_imgui
local players = {} -- contains name and ping for each entry

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

local function render()
    local hw = imgui.GetWindowWidth() / 2

    imgui.SetCursorPosX((imgui.GetWindowWidth() - imgui.CalcTextSize("Name").x) / 4)
    imgui.Text("Name")
    imgui.SameLine()

    imgui.SetCursorPosX((hw + hw / 2) - imgui.CalcTextSize("Ping").x)
    imgui.Text("Ping")

    imgui.Separator()

    if imgui.BeginChild1("PlayerList", imgui.ImVec2(0, 0), true) then
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