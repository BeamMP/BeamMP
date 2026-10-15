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


local remoteDisabled = false
local remoteEngines = {} -- combustion engines, a reset puts their failure limits back

-- the engine's random over-rev / over-torque failures, the owner's gear can arrive a moment late and lock up our copy
-- of their engine while theirs is fine
local function disableEngineFailures()
	for _, engine in ipairs(remoteEngines) do
		if engine.maxPhysicalAV ~= math.huge then
			engine.maxPhysicalAV = math.huge
			engine.maxTorqueRating = 0
		end
	end
end

-- things the game does for every vehicle that only make sense for your own, turned off on other players' vehicles
local function disableForRemote()
	if remoteDisabled then return end
	remoteDisabled = true

	-- the burnout and odometer stats only check that the AI is off, not that you're in the vehicle, so other players'
	-- burnouts and distance were added to your own stats. The odometer still counts, part wear uses it
	local stats = extensions.gameplayStatistic
	if stats then
		stats.metricAdd = nop
		stats.metricSet = nop
		stats.updateGFX = nil
		extensions.hookUpdate("updateGFX")
	end
	-- recovery points, you can't recover another player's vehicle and their resets come from the server
	recovery.updateGFX = nop

	-- UI messages, the stalled engine one has no check for who's in the vehicle and is sent every frame while it's stalled
	local trigger = guihooks.trigger
	guihooks.trigger = function(hookName, ...)
		if hookName == "Message" then return end
		return trigger(hookName, ...)
	end

	remoteEngines = powertrain.getDevicesByType("combustionEngine")
	disableEngineFailures()
end

local function setVehicleType(x)
  v.mpVehicleType = x
  if x == 'R' then disableForRemote() end
end

local function setServerID(id)
  v.mpServerID = id
end

local function updateGFX(dtReal)
	if remoteDisabled then disableEngineFailures() end
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
