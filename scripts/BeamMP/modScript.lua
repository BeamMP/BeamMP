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

local ver = split(beamng_versionb, ".")
local majorVer = tonumber(ver[2])
local compatibleVersion = 31
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

-- load this file last so it can reference the others
load("MPHelpers")
setExtensionUnloadMode("MPHelpers", "manual")
