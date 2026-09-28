-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- MPKeybindsGE API.
--- Keybinds for mods. Each one is a proper action in Options > Controls under BeamMP, so players can see what it does
--- and change the key, and the mod gets a function call when it's pressed / released.
--- The game only reads actions and default bindings from files, so they're written to the user folder while in use and
--- removed again when you leave the server.
--- The old key listener API (onKeyPressed, addKeyEventListener etc.) is on top of this now, input.keys is gone in 0.39.
--- @module MPKeybindsGE
--- @usage MPKeybindsGE.addAction("myModHorn", { title = "Air horn", default = "k", onDown = function() ... end })

local M = {}

local ACTIONS_FILE = "/lua/ge/extensions/core/input/actions/beammp_keybinds.json"
local BINDINGS_FILE = "/settings/inputmaps/keyboard_beammp_keybinds.json"
local ORDER_START = 100 -- after BeamMP's own actions in the BeamMP category

local actions = {}   -- [actionName] = { title, desc, default, listeners = { { onDown, onUp } }, order, state }
local nextOrder = ORDER_START
local dirty = false  -- files need writing, done once per frame so a mod adding 20 keys is one reload
local vehicleKeys = {} -- [key] = true, keys vehicle Lua listens to


-- ============= HELPERS =============

-- only letters, numbers and _ in action names, they end up in a Lua string in the action file
local function cleanName(name)
	return (tostring(name):gsub("[^%w_]", "_"))
end

-- the old API took input.keys names like "NUMPAD1" or "E", bindings use "numpad1" and "e"
local function cleanKey(key)
	if type(key) ~= "string" then return nil end
	key = key:gsub("^%s+", ""):gsub("%s+$", ""):lower()
	return key ~= "" and key or nil
end

local function keyActionName(key)
	return "beammpKey_" .. cleanName(key)
end

local function callListeners(action, down)
	for _, l in ipairs(action.listeners) do
		local f
		if down then f = l.onDown else f = l.onUp end
		if f then
			local ok, err = pcall(f, down)
			if not ok then log('E', 'MPKeybindsGE', 'Keybind "' .. action.title .. '" errored: ' .. tostring(err)) end
		end
	end
end


-- ============= FILES =============

local function writeFiles()
	dirty = false
	local actionsData, bindings = {}, {}
	for name, a in pairs(actions) do
		actionsData[name] = {
			cat = "beammp",
			order = a.order,
			ctx = "tlua",
			title = a.title,
			desc = a.desc,
			onDown = "if MPKeybindsGE then MPKeybindsGE.trigger('" .. name .. "', true) end",
			onUp = "if MPKeybindsGE then MPKeybindsGE.trigger('" .. name .. "', false) end",
		}
		if a.default then table.insert(bindings, { control = a.default, action = name }) end
	end

	if next(actionsData) then
		writeFile(ACTIONS_FILE, jsonEncode(actionsData))
		writeFile(BINDINGS_FILE, jsonEncode({ name = "Keyboard", vendor = "", vidpid = "", devicetype = "keyboard", bindings = bindings }))
	else
		FS:removeFile(ACTIONS_FILE)
		FS:removeFile(BINDINGS_FILE)
	end

	-- the file watcher doesn't always catch our own writes, so tell the input system straight away
	if core_input_actions then core_input_actions.onFileChanged(ACTIONS_FILE) end
	if core_input_bindings then core_input_bindings.onFileChanged(BINDINGS_FILE) end
end


-- ============= ACTIONS =============

--- Adds a keybind, or another listener to one that exists. Shows in Options > Controls > BeamMP.
-- @tparam string name unique name, only letters, numbers and _ are kept
-- @tparam table def { title = string, desc = string, default = "k" (optional), onDown = function, onUp = function }
-- @treturn string the action name it was added as
-- @usage MPKeybindsGE.addAction("myModHorn", { title = "Air horn", default = "k", onDown = function() honk() end })
local function addAction(name, def)
	def = def or {}
	name = cleanName(name)
	local action = actions[name]
	if not action then
		action = { title = def.title or name, desc = def.desc or "", default = cleanKey(def.default), listeners = {}, order = nextOrder, state = false }
		nextOrder = nextOrder + 1
		actions[name] = action
		dirty = true
	end
	if def.onDown or def.onUp then
		table.insert(action.listeners, { onDown = def.onDown, onUp = def.onUp })
	end
	return name
end

--- Removes a keybind and its listeners.
-- @tparam string name
local function removeAction(name)
	name = cleanName(name)
	if not actions[name] then return end
	actions[name] = nil
	dirty = true
end

--- Called by the action when its key goes down / up. INTERNAL ONLY
-- @tparam string name
-- @tparam boolean down
local function trigger(name, down)
	local action = actions[name]
	if not action then return end
	action.state = down
	callListeners(action, down)
	if action.key and vehicleKeys[action.key] then
		be:queueAllObjectLua("if MPVehicleVE then MPVehicleVE.onKeyStateChanged('" .. action.key .. "', " .. tostring(down) .. ") end")
	end
end

--- Returns true while the keybind is held.
-- @tparam string name
-- @treturn boolean
local function isDown(name)
	local action = actions[cleanName(name)]
	return action and action.state or false
end


-- ============= KEY LISTENERS (old API) =============

local function keyAction(key)
	local name = keyActionName(key)
	local existing = actions[name]
	addAction(name, { title = "Server mod key (" .. key:upper() .. ")", desc = "A mod on this server listens for this key, you can change it here", default = key })
	actions[name].key = key
	return actions[name], existing == nil
end

--- Listens for a key, it shows up in Controls with that key as the default so players can change it.
-- @tparam string keyname like "NUMPAD1" or "e"
-- @tparam function f called with the key state (true = down)
-- @tparam string type 'down', 'up' or 'both' (default)
local function addKeyListener(keyname, f, type)
	local key = cleanKey(keyname)
	if not key then
		log('E', 'MPKeybindsGE', 'addKeyEventListener needs a key name, got ' .. tostring(keyname))
		return
	end
	local action = keyAction(key)
	type = type or 'both'
	f = f or function() end
	table.insert(action.listeners, {
		onDown = (type == 'both' or type == 'down') and f or nil,
		onUp = (type == 'both' or type == 'up') and f or nil,
	})
end

--- For key listeners in vehicle Lua, the key state gets sent to every vehicle.
-- @tparam string keyname
local function addVehicleKeyListener(keyname)
	local key = cleanKey(keyname)
	if not key then return end
	keyAction(key)
	vehicleKeys[key] = true
end

--- Returns the state of a key that's being listened for.
-- @tparam string keyname
-- @treturn boolean
local function getKeyState(keyname)
	local key = cleanKey(keyname)
	return key and isDown(keyActionName(key)) or false
end


-- ============= EVENTS =============

local function onUpdate()
	if dirty then writeFiles() end
end

-- mods register their keys again when you join, so a server's keys don't stay in Controls after you leave it
local function onDisconnect()
	if not next(actions) then return end
	actions, vehicleKeys = {}, {}
	nextOrder = ORDER_START
	dirty = true
end

-- files left over from a crash
local function onExtensionLoaded()
	if FS:fileExists(ACTIONS_FILE) or FS:fileExists(BINDINGS_FILE) then dirty = true end
end


M.addAction             = addAction
M.removeAction          = removeAction
M.isDown                = isDown
M.trigger               = trigger
M.addKeyListener        = addKeyListener
M.addVehicleKeyListener = addVehicleKeyListener
M.getKeyState           = getKeyState

M.onUpdate          = onUpdate
M.onDisconnect      = onDisconnect
M.onExtensionLoaded = onExtensionLoaded
M.onInit = function() setExtensionUnloadMode(M, "manual") end

return M
