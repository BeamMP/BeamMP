-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

local function toggleBeamMinMax(controllerName, funcName, tempTable, ...)
	for _,group in pairs(...) do
		local pressure = controller.getController(controllerName).isBeamGroupAtPressureLevel(group, "minPressure")
		if pressure then
			controller.getController(controllerName).setBeamMax({group})
		else
			controller.getController(controllerName).setBeamMin({group})
		end
	end
end

local includedControllerTypes = {
	["pneumatics"] = {
		["setBeamMin"] = {},
		["setBeamMax"] = {},
		["setBeamPressure"] = {},
		["setBeamPressureLevel"] = {},
		["toggleBeamMinMax"] = {
			ownerFunction = toggleBeamMinMax
		},
		["setBeamMomentaryIncrease"] = {},
		["setBeamMomentaryDecrease"] = {},
		["setBeamDefault"] = {}
	},

	["pneumatics/autoLevelSuspension"] = {
		["toggleDump"] = {},
		["setDump"] = {},
		["toggleMaxHeight"] = {},
		["setMaxHeight"] = {},
		["setMomentaryIncrease"] = {},
		["setMomentaryDecrease"] = {}
	},

	--["pneumatics/actuators"] = { -- this works but is disabled because it causes unnecessary spam from the T-series air suspension which is the only official part that uses it AFAIK
	--	["setBeamGroupValveState"] = {},
	--	["toggleBeamGroupValveState"] = {},
	--	["setBeamGroupsValveState"] = {
	--		compare = true
	--		},
	--	["toggleBeamGroupsValveState"] = {
	--		compare = true
	--		}
	--},
}


local function loadFunctions()
	if controllerSyncVE ~= nil then
		controllerSyncVE.addControllerTypes(includedControllerTypes)
	else
		dump("controllerSyncVE not found")
	end
end

M.loadControllerSyncFunctions = loadFunctions

return M
