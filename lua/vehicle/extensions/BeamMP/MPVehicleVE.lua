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
