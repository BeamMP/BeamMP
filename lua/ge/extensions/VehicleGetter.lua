print("[BeamNG-MP] | VehicleGetter loaded.")
--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local json = require('libs/lunajson/lunajson')

local M = {}
local Timer = 0

local function println(stringToPrint)
	if stringToPrint ~= nil then
		print("[BeamNG-MP] [VehicleData] | "..stringToPrint or "")
	end
end

lastVehicleState = {
  steering = 0,
  throttle = 0,
  brake = 0,
  parkingbrake = 0,
  clutch = 0
}

local function getVehicleInputs()
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

  if firstRun == true then
    state.client = Settings.PlayerID
    player0.cid = Settings.PlayerID
    firstRun = false
  end

  for k, v in pairs(lastVehicleState) do
    local command = "obj:queueGameEngineLua('lastVehicleState." .. k .. " = ' .. input.state." .. k .. ".val)"
    local v = be:getPlayerVehicle(0)
    if v then
      be:getPlayerVehicle(0):queueLuaCommand(command)
    end
  end

  state.user = Settings.Nickname
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

local function getVehicleElectrics()
	local player0 = be:getPlayerVehicle(0) -- Our clients vehicle
  local state = {}
end

local function getVehicleNodes()
	local player0 = be:getPlayerVehicle(0) -- Our clients vehicle
  local state = {}
end

local function getVehiclePowertrain()
	local player0 = be:getPlayerVehicle(0) -- Our clients vehicle
  local state = {}
end

local function onUpdate(dt)
  Timer = Timer + dt
  local tcp = tonumber(Network.GetTCPStatus())
  local udp = tonumber(NetworkUDP.GetUDPStatus())
  --print("Network: "..tcp.." UDP Network: "..udp.."")
  if tcp > 0 and udp > 0 then
    if Timer > 0.5 then
      Timer = 0

      -- Update all our data on our vehicle
      --local state = getVehicleInputs()
      --local vehInputs = jsonEncode(state)
      -- Send All Updates depending on the chosen Protocol
			--println("Veh update sent")
      --if Settings.Protocol == "TCP" then
        --if tcp == 2 then
          --Network.TCPSend("U-VI"..Settings.ClientID..''..vehInputs)
					--Network.TCPSend("U-VE"..Settings.ClientID..''..vehReady)
        --end
      --elseif Settings.Protocol == "UDP" then
        --if udp == 2 then
          --NetworkUDP.UDPSend()
        --end
      --end
    end
  end
end

M.onUpdate = onUpdate

return M
