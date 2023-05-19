--====================================================================================
-- All work by Titch2000 and jojos38.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================
local ver = split(beamng_versionb, ".")
local majorVer = tonumber(ver[2])
local compatibleVersion = 28
if majorVer ~= compatibleVersion then
	log('W', 'versionCheck', 'BeamMP is incompatible with BeamNG.drive version '..beamng_versionb)
	log('M', 'versionCheck', 'Deactivating BeamMP mod.')
	core_modmanager.deactivateMod('multiplayerbeammp')
	core_modmanager.deactivateMod('beammp')
	if majorVer > compatibleVersion then
		guihooks.trigger("toastrMsg", {type="error", title="Error loading BeamMP", msg="BeamMP is currently not compatible with BeamNG.drive version "..beamng_versionb..". Check the BeamMP Discord for updates."})
		log('W', 'versionCheck', 'BeamMP is currently not compatible with BeamNG.drive version '..beamng_versionb..'. Check the BeamMP Discord for updates.')
	else
		guihooks.trigger("toastrMsg", {type="error", title="Error loading BeamMP", msg="BeamMP is not compatible with BeamNG.drive version "..beamng_versionb.. ". Please update your game."})
		log('W', 'versionCheck', 'BeamMP is not compatible with BeamNG.drive version '..beamng_versionb.. '. Please update your game.')
	end
	return
else
	log('M', 'versionCheck', 'BeamMP is compatible with the current version.')
end

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

-- load this file last so it can reference the others
load("MPHelpers")
registerCoreModule("MPHelpers")
