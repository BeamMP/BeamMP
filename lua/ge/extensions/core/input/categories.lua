-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

return {
  vehicle_specific = { order = 1, icon = "local_taxi",     title = "ui.options.controls.bindings.VehicleSpecific", desc="Controls for the current vehicle model"},
    vehicle          = { order = 2, icon = "directions_car", title = "ui.options.controls.bindings.Vehicle",         desc="Controls that control the currently focused vehicle"},
    general          = { order = 3, icon = "language",       title = "ui.options.controls.bindings.General",         desc="General controls for the game engine"},
    gameplay         = { order = 4, icon = "extension",      title = "ui.options.controls.bindings.Gameplay",        desc="Controls that change the gameplay experience"},
    camera           = { order = 5, icon = "videocam",       title = "ui.options.controls.bindings.Camera",          desc="Controls that change or move the camera around"},
    menu             = { order = 6, icon = "web",            title = "ui.options.controls.bindings.MenuNavigation",  desc="Menu/UI navigation controls"},
    slowmotion       = { order = 7, icon = "timer",          title = "ui.options.controls.bindings.SlowMotion",      desc="Controls that change the speed of time"},
    replay           = { order = 8, icon = "local_movies",   title = "ui.options.controls.bindings.Replay",          desc="Playback and recording controls"},
    editor           = { order = 9, icon = "editor",         title = "ui.options.controls.bindings.Editor",          desc="Controls used in the in-game editor"},
    flowgraph        = { order =10, icon = "editor",         title = "Flowgraph Editor",                             desc="Controls used in the Flowgraph Editor"},
    debug            = { order =11, icon = "bug_report",     title = "ui.options.controls.bindings.GeneralDebug",    desc="Controls that are used to find problems with the game engine"},
    vehicle_debug    = { order =12, icon = "settings",       title = "ui.options.controls.bindings.VehicleDebug",    desc="Controls that help vehicle creators"},
    
    controllerui    = { order =13, icon = "web",       title = "ui.options.controls.bindings.MenuNavigationNew",    desc="[WIP] Menu/UI navigation controls"},
  -- Added BeamMP Input Category
    beammp           = { order =13, icon = "settings",       title = "BeamMP",                                       desc="Controls that are used in BeamMP"},
}
