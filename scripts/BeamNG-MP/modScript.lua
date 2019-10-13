load("Debug")
registerCoreModule("Debug")

load("HelperFunctions")
registerCoreModule("HelperFunctions") -- Helper Functions

load("UI")
registerCoreModule("UI") -- For all of our UI functions and handling

load("Settings")
registerCoreModule("Settings") -- Stores our session settings

load("Updates")
registerCoreModule("Updates") -- handles all vehicle updating things

load("Network")
registerCoreModule("Network") -- Handles all TCP related traffic

load("NetworkUDP")
registerCoreModule("NetworkUDP") -- All done over UDP

load("NetworkHandler")
registerCoreModule("NetworkHandler") -- Handle all network sending wrappers

load("vehicleGE")
registerCoreModule("vehicleGE") -- Contains vehicle related things

--[[load("sessionControl")
registerCoreModule("sessionControl")

load("playersList")
registerCoreModule("playersList")]]

load("updatesGE")
registerCoreModule("updatesGE")

load("inputsGE")
registerCoreModule("inputsGE")

load("electricsGE")
registerCoreModule("electricsGE")

load("positionGE")
registerCoreModule("positionGE")

load("powertrainGE")
registerCoreModule("powertrainGE")

load("nodesGE")
registerCoreModule("nodesGE")
