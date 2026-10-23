-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

v.mpVehicleType = "L" -- we assume vehicles are local (they're set to remove once we receive pos data from the server)
v.mpServerID = ""

local keyStates = {} -- table of keys and their states, sent by GE
local keypressTriggers = {}


-------------------------------------------------------------------------------
-- Keypress handling
-------------------------------------------------------------------------------

setmetatable(_G,{}) -- temporarily disable global write notifications

function onKeyPressed(keyname, f)
	addKeyEventListener(keyname, f, 'down')
end
function onKeyReleased(keyname, f)
	addKeyEventListener(keyname, f, 'up')
end

-- input.keys is gone in 0.39, the key is a keybind in GE now (MPKeybindsGE) and GE sends us its state
function addKeyEventListener(keyname, f, t)
	if type(keyname) ~= "string" then return end
	keyname = keyname:lower()
	f = f or function() end
	log('W','AddKeyEventListener', "Adding a key event listener for key '"..keyname.."'")
	table.insert(keypressTriggers, {key = keyname, func = f, type = t or 'both'})
	obj:queueGameEngineLua("if MPKeybindsGE then MPKeybindsGE.addVehicleKeyListener(" .. string.format("%q", keyname) .. ") end")
end

local function onKeyStateChanged(key, state)
	keyStates[key] = state
	for i=1,#keypressTriggers do
		if keypressTriggers[i].key == key and (keypressTriggers[i].type == 'both' or keypressTriggers[i].type == (state and 'down' or 'up')) then
			keypressTriggers[i].func(state)
		end
	end
end

function getKeyState(key)
	return keyStates[type(key) == "string" and key:lower() or key] or false
end


local function setVehicleType(x)
  v.mpVehicleType = x
end

local function setServerID(id)
  v.mpServerID = id
end

local function updateGFX(dtReal)
	if v.mpVehicleType == 'R' and hydros.enableFFB then -- disable ffb if it got enabled by a reset
		-- trigger a check that will set FFBID to -1
		hydros.enableFFB = false
		hydros.onFFBConfigChanged()
	end
end

local function onExtensionLoaded()
	obj:queueGameEngineLua("MPVehicleGE.onVehicleReady("..obj:getID()..")")
end

detectGlobalWrites() -- reenable global write notifications

M.updateGFX = updateGFX
M.onExtensionLoaded    = onExtensionLoaded

M.setVehicleType       = setVehicleType
M.setServerID          = setServerID
M.onKeyStateChanged    = onKeyStateChanged

--M.getKeyState = getKeyState
--M.addKeyEventListener = addKeyEventListener

return M
