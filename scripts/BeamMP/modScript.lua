--====================================================================================
-- All work by Titch2000 and jojos38.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

load("multiplayer/multiplayer")
registerCoreModule("multiplayer/multiplayer")

load("MPDebug")
registerCoreModule("MPDebug")

load("UI")
registerCoreModule("UI")

load("MPModManager")
registerCoreModule("MPModManager")

load("MPCoreSystem")
registerCoreModule("MPCoreSystem")

load("MPConfig")
registerCoreModule("MPConfig")

load("MPVehicleGE")
registerCoreModule("MPVehicleGE")

load("MPInputsGE")
registerCoreModule("MPInputsGE")

load("MPElectricsGE")
registerCoreModule("MPElectricsGE")

load("positionGE")
registerCoreModule("positionGE")

load("MPPowertrainGE")
registerCoreModule("MPPowertrainGE")

load("MPUpdatesGE")
registerCoreModule("MPUpdatesGE")

load("nodesGE")
registerCoreModule("nodesGE")

-- load this file last so it can reference the others
load("MPHelpers")
registerCoreModule("MPHelpers")
