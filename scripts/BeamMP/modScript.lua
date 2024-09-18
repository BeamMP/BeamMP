-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local ver = split(beamng_versionb, ".")
local majorVer = tonumber(ver[2])
local compatibleVersion = 33
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
setExtensionUnloadMode("multiplayer/multiplayer", "manual")

load("MPDebug")
setExtensionUnloadMode("MPDebug", "manual")

load("UI")
setExtensionUnloadMode("UI", "manual")

load("MPModManager")
setExtensionUnloadMode("MPModManager", "manual")

load("MPCoreNetwork")
setExtensionUnloadMode("MPCoreNetwork", "manual")

load("MPConfig")
setExtensionUnloadMode("MPConfig", "manual")

load("MPGameNetwork")
setExtensionUnloadMode("MPGameNetwork", "manual")

load("MPVehicleGE")
setExtensionUnloadMode("MPVehicleGE", "manual")

load("MPInputsGE")
setExtensionUnloadMode("MPInputsGE", "manual")

load("MPElectricsGE")
setExtensionUnloadMode("MPElectricsGE", "manual")

load("positionGE")
setExtensionUnloadMode("positionGE", "manual")

load("MPPowertrainGE")
setExtensionUnloadMode("MPPowertrainGE", "manual")

load("MPUpdatesGE")
setExtensionUnloadMode("MPUpdatesGE", "manual")

load("nodesGE")
setExtensionUnloadMode("nodesGE", "manual")

load("MPControllerGE")
setExtensionUnloadMode("MPControllerGE", "manual")

-- load this file last so it can reference the others
load("MPHelpers")
setExtensionUnloadMode("MPHelpers", "manual")

extensions.core_input_categories.beammp = { order = 999, icon = "settings", title = "BeamMP", desc = "BeamMP Controls" } --inject BeamMP input category at bottom of input categories list
