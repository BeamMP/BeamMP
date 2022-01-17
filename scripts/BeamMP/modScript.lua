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

load("MPCoreNetwork")
registerCoreModule("MPCoreNetwork")

load("MPConfig")
registerCoreModule("MPConfig")

load("MPGameNetwork")
registerCoreModule("MPGameNetwork")

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

load("mpGameModes/dragRace/dragRace")
registerCoreModule("mpGameModes/dragRace/dragRace")

-- load this file last so it can reference the others
load("MPHelpers")
registerCoreModule("MPHelpers")
