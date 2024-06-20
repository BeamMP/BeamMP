-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

v.mpVehicleType = "L" -- we assume vehicles are local (they're set to remove once we receive pos data from the server)

local keyStates = {} -- table of keys and their states, used as a reference
local keysToPoll = {} -- list of keys we want to poll for state changes
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

function addKeyEventListener(keyname, f, t)
	if type(keyname) == "table" then -- multiple keys were requested, this probably came from GE
		for _,v in pairs(keyname) do
			keysToPoll[v] = true
		end
	else
		f = f or function() end
		log('W','AddKeyEventListener', "Adding a key event listener for key '"..keyname.."'")
	
		table.insert(keypressTriggers, {key = keyname, func = f, type = t or 'both'})
		keysToPoll[keyname] = true
	end
end

local function onKeyStateChanged(key, state)
	keyStates[key] = state
	for i=1,#keypressTriggers do
		if keypressTriggers[i].key == key and (keypressTriggers[i].type == 'both' or keypressTriggers[i].type == (state and 'down' or 'up')) then
			keypressTriggers[i].func(state)
		end
	end
	obj:queueGameEngineLua("MPGameNetwork.onKeyStateChanged('"..key.."',"..tostring(state)..")")
end

function getKeyState(key)
	return keyStates[key] or false
end


local function setVehicleType(x)
  v.mpVehicleType = x
end

local function updateGFX(dtReal)
	if v.mpVehicleType == 'R' and hydros.enableFFB then -- disable ffb if it got enabled by a reset
		-- trigger a check that will set FFBID to -1
		hydros.enableFFB = false
		hydros.onFFBConfigChanged()
	end

	for k in pairs(keysToPoll) do
		if input.keys[k] ~= keyStates[k] then
			onKeyStateChanged(k, input.keys[k])
		end
	end
end

--M.onExtensionLoaded = function() addKeyEventListener('E') addKeyEventListener('G') end

local function onExtensionLoaded()
	obj:queueGameEngineLua("MPVehicleGE.onVehicleReady("..obj:getID()..")")
end

setmetatable(input.keys, {}) -- disable deprecated warning
detectGlobalWrites() -- reenable global write notifications

M.updateGFX = updateGFX
M.onExtensionLoaded    = onExtensionLoaded

M.setVehicleType       = setVehicleType

--M.getKeyState = getKeyState
--M.addKeyEventListener = addKeyEventListener

return M
