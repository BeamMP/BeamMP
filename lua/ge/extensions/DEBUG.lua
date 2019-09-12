print("[BeamNG-MP] | Debug loaded.")
--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local M = {}


-- ============= VARIABLES =============

-- ============= VARIABLES =============

local function println(stringToPrint)
	print("[BeamNG-MP] | "..stringToPrint)
end

--=============================================================================
--== DEBUG DISPLAY THINGS
--=============================================================================

local uiWebServer = require('utils/simpleHttpServer')
local websocket = require('libs/lua-websockets/websocket')
local copas = require('libs/copas/copas')
local json = require('libs/lunajson/lunajson')
local socket = require "socket"

local httpListenPort = 1337

-- the websocket counterpart
local ws_client
local wsServer
local Readyy = false
local webServerRunning = false

--=============================================================================
--== Vehicle Monitoring
--=============================================================================

lastVehicleState = {
  steering = 0,
  throttle = 0,
  brake = 0,
  parkingbrake = 0,
  clutch = 0
}

ui_message('DEBUGGING ENABLED!', 10, 0, 0)
extensions.core_jobsystem.create(function ()
	ws_client = websocket.client.copas({timeout=0})
	ws_client:connect('ws://localhost:'..httpListenPort..'')
	--extensions.core_jobsystem.create(receive_data_job)
	Readyy = true
  webServerRunning = true
	ws_client:send("JOIN|"..user.."|"..map)
end)

local function updateUI(opt, data)
	if opt == "updateTime" then
		be:executeJS('document.getElementById("PID").innerHTML = "'..data..'ms"')
	elseif opt == "runTime" then
		be:executeJS('document.getElementById("VID").innerHTML = "'..data..'ms"')
	end
end







local function getVehicleState()
  local player0 = be:getPlayerVehicle(0) -- Our clients vehicle
  local state = {}
  state.type = "VehicleState"

  --[[for i = 0, be:getObjectCount()-1 do
    local veh = be:getObject(i)
    --print(veh:getJBeamFilename()) --"pickup"
    --print(veh.partConfig) -- sometimes it''s a .pc file, if it's customised it's json data
    if veh.cid == nil then
      state.model = veh:getJBeamFilename()
      state.config = veh.partConfig
      veh.cid = cid -- this and the user one below will be helpful for us to keep track of the vehicles and whos is whos.
    end
    state.client = cid -- this and the user one below will be helpful for us to keep track of the vehicles and whos is whos.
  end]]

  state.model = player0:getJBeamFilename()
  state.config = player0.partConfig
  state.jbeam = player0.jbeam
  state.color = tostring(player0.color)
	--state.time = socket.gettime()*1000
  --1567510000000  -- socket.gettime()*1000
  --1567508880837  -- JS time
  --state.time = os.time()*1000
  --println(state.time)
  --1567509013000  -- os.time()*1000


  if firstRun == true then
    state.client = cid
    player0.cid = cid
    firstRun = false
  end

  state.user = user
  state.steering = lastVehicleState.steering
  state.throttle = lastVehicleState.throttle
  state.brake = lastVehicleState.brake
  state.clutch = lastVehicleState.clutch
  state.parkingbrake = lastVehicleState.parkingbrake

  local vdata = map.objects[be:getPlayerVehicle(0):getID()]
  state.pos = vdata.pos:toTable()
  state.vel = vdata.vel:toTable()
  state.dir = vdata.dirVec:toTable()
  local dir = vdata.dirVec:normalized()
  state.rot = math.deg(math.atan2(dir:dot(vec3(1, 0, 0)), dir:dot(vec3(0, -1, 0))))

  --state.view = Engine.getColorBufferBase64(320, 240)
  return state
end

local function requestVehicleInput(key)
  local command = "obj:queueGameEngineLua('lastVehicleState." .. key .. " = ' .. input.state." .. key .. ".val)"
  local v = be:getPlayerVehicle(0)
  if v then
    be:getPlayerVehicle(0):queueLuaCommand(command)
  end
end

local function requestVehicleInputs()
  for k, v in pairs(lastVehicleState) do
    requestVehicleInput(k)
  end
end

local function onUpdate()
	copas.step(0)
  requestVehicleInputs()
	if webServerRunning then
		uiWebServer.update()
	end
  if Readyy then
    local det = jsonEncode(getVehicleState())
	   ws_client:send(det)
  end
end

M.onUpdate  = onUpdate
M.updateUI = updateUI

return M
