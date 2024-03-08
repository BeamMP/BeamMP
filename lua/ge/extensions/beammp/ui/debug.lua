-- debug console for development purposes
local M = {}

M.dependencies = { "ui_imgui" }

local gui_module = require("ge/extensions/editor/api/gui")
local gui = { setupEditorGuiTheme = nop }
local im = ui_imgui
local ffi = require("ffi")

local ui_strings = {}

M.onExtensionLoaded = function()
    gui_module.initialize(gui)
    gui.registerWindow("beammp_debug", im.ImVec2(256, 256))
    gui.showWindow("beammp_debug")
end

local username = im.ArrayChar(128)
local password = im.ArrayChar(128)
local function DrawDebugWindow()


    if not gui.isWindowVisible("beammp_debug") then return end

    gui.setupWindow("beammp_debug")
    im.SetNextWindowBgAlpha(0.4)
    im.Begin("BeamMP dev / debug tools")

    im.Columns(4, "Bar")

    im.Text("Game")
    if im.Button("Lua reload") then
        Lua:requestReload()
    end
    if im.Button("Main Menu") then
        ReturnToMainMenu()
    end
    if im.Button("SmallGrid") then
        freeroam_freeroam.startFreeroam("levels/smallgrid/info.json")
    end
    if im.Button("GridMap V2") then
        freeroam_freeroam.startFreeroam("levels/gridmap_v2/info.json")
    end

    im.NextColumn()

    im.Text("BeamMP")
    im.Text("Current state: ".. tostring(beammp_network.GetState()))
    if im.Button("Req. server list") then
        beammp_network.requestServerList()
    end
    im.NextColumn()
    im.Text("Network")
    if im.Button("Connect") then
        beammp_network.connect()
    end
    if im.Button("Disconnect") then
        beammp_network.disconnect()
    end

    im.NextColumn()
    im.Text("Login")
    im.Separator()
    im.InputText("User", username)
    im.InputText("Pass", password)
    if im.Button("Login") then
        beammp_network.SendCredentials(ffi.string(ffi.cast("char*", username)), ffi.string(ffi.cast("char*", password)), true)
    end
    if im.Button("Logout") then
        beammp_network.Logout()
    end

    im.End()
end

M.onUpdate = DrawDebugWindow
M.onInit = function() setExtensionUnloadMode(M, "manual") end

return M
