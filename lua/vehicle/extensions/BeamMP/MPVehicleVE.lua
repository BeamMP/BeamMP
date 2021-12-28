--====================================================================================
-- All work by 20dka.
-- You have no permission to edit, redistrobute or upload. Contact BeamMP for more info!
--====================================================================================
-- Main VE lua file for BeamMP
--====================================================================================

local M = {}

v.mpVehicleType = "L" -- we assume vehicles are local (they're set to remove once we receive pos data from the server)
local callOnPhysUpdate = {}
local origPhysUpdateFunc = nop


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
			table.insert(keysToPoll, v)
		end
	else
		f = f or function() end
		log('W','AddKeyEventListener', "Adding a key event listener for key '"..keyname.."'")
	
		table.insert(keypressTriggers, {key = keyname, func = f, type = t or 'both'})
		table.insert(keysToPoll, v)
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

local function AddPhysUpdateHandler(n, f) -- n: name, string used as an ID, f: function
	--print("add phys for func "..n)
	callOnPhysUpdate[n] = f
end

local function DelPhysUpdateHandler(n)
	callOnPhysUpdate[n] = nil
end

-- physics update
local function update(dtSim)
	origPhysUpdateFunc(dtSim)
	for n,f in pairs(callOnPhysUpdate) do
		f(dtSim)
	end
end

local function updateGFX(dtReal)
	if motionSim.update ~= update then -- hook onto the unused phys update function
		log('M','updateGFX',"Adding phys update handler hook")
		origPhysUpdateFunc = motionSim.update
		motionSim.update = update
		
		motionSim.isPhysicsStepUsed = function() return true end
		updateCorePhysicsStepEnabled()
	end

	if v.mpVehicleType == 'R' and hydros.enableFFB then -- disable ffb if it got enabled by a reset
		-- trigger a check that will set FFBID to -1
		hydros.enableFFB = false
		hydros.onFFBConfigChanged()
	end

	for _,k in pairs(keysToPoll) do
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
M.onReset              = onReset

M.setVehicleType       = setVehicleType
M.AddPhysUpdateHandler = AddPhysUpdateHandler
M.DelPhysUpdateHandler = DelPhysUpdateHandler

--M.getKeyState = getKeyState
--M.addKeyEventListener = addKeyEventListener

return M
