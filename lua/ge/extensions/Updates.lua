print("[BeamNG-MP] | Updates loaded.")
--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

local json = require('libs/lunajson/lunajson')

local M = {}

local function println(stringToPrint)
	if stringToPrint ~= nil then
		print("[BeamNG-MP] [Updates] | "..stringToPrint or "")
	end
end

local function updateVehicleInputs(client, inputs)
  for i = 0, be:getObjectCount()-1 do
    local veh = be:getObject(i)
    if veh:getJBeamFilename() == inputs.model and inputs.cid == veh.cid then
      found = true
      --print('Vehicle found for client: '..client)
      for k, v in pairs(inputs) do
        local typeof=type(v)
        if typeof=="table" then
					--println(k) -- should show pos, vel, dir
          --println(v[1])
          if k == "pos" then
            if Settings.UpdateMethod == 1 then
              local vdata = map.objects[be:getPlayerVehicle(0):getID()]
              local pos = vdata.pos:toTable()
              if HelperFunctions.GetDistanceBetweenCoords(pos[1], pos[2], pos[3], v[1], v[2], v[3], true) > Settings.SmoothUpdateDist then
                println("Dist is higher than "..Settings.SmoothUpdateDist..": "..HelperFunctions.GetDistanceBetweenCoords(pos[1], pos[2], pos[3], v[1], v[2], v[3], true))
                veh:setPosition(Point3F(v[1], v[2], v[3]))
              end
            elseif Settings.UpdateMethod == 2 then
              print(v[1])
              local vdata2 = map.objects[be:getObject(i):getID()]
              local pos = vdata2.pos:toTable()
              print(pos[1])
              if HelperFunctions.GetDistanceBetweenCoords(pos[1], pos[2], pos[3], v[1], v[2], v[3], true) > Settings.MaxVariationDist then
                println("Vehicle is further than should be and beyond tolerance: "..HelperFunctions.GetDistanceBetweenCoords(pos[1], pos[2], pos[3], v[1], v[2], v[3], true).." Should be no more than "..Settings.MaxVariationDist)
                veh:setPosition(Point3F(v[1], v[2], v[3]))
              end
            end
          elseif k == "dir" then

          elseif k == "vel" then
            veh:setVelocity(Point3F(v[1], v[2], v[3])) -- Experimental
          end
          --print('TABLE VALUE')
          --print(i)
          --print(v)
          --for key, value in pairs(v) do
            --print(key)
            --print(value)
            --issueVehicleInput(i, key, value)
          --end
        else
          --print('NON TABLE VALUE')
          --print(k)
          --print(v)
          --if k == "config" then
          if k == "throttle" or k == "clutch" or k == "brake" or k == "steering" or k == "parkingbrake" then -- TODO Add pos checking to syncronisation as well
						local command = "input.event('" .. key .. "', " .. val .. ", 1)"
					  --print(command)
					  if i ~= nil and command ~= nil then
					    local veh = be:getObject(i)
					    --be:getPlayerVehicle(i):queueLuaCommand(command)
					    veh:queueLuaCommand(command) -- Thank you to jojo38 for the solution here!
					  else
					    print('NIL VALUE DETECTED')
					  end
          end
        end
      end
    end
  end
  if not found then -- the vehicle was not found so we need to make it and then update
    --print(inputs.model..' not found for client: '..client..' Creating instead.')
    local spawnPos = vec3(inputs.pos) --vec3(player0:getPosition()) - vec3(player0:getDirectionVector()) * spawnGap * (active + i) * -1
		local spawnRot = vec3(inputs.dir) --vec3(player0:getDirectionVector())
    local up = vec3(0, 0, 1)
    local mainColor = nil
		mainColor = inputs.color
		mainColor = stringToTable(mainColor, ", ")
		mainColor = ColorF(mainColor[1], mainColor[2], mainColor[3], mainColor[4])
    local vid = be:getPlayerVehicleID(0)
    spawn.spawnVehicle(inputs.jbeam, inputs.config, vec3(spawnPos):toPoint3F(), quatFromDir(spawnRot, up), mainColor)
    local veh = be:getObjectByID(vid)
    if veh then
      be:enterVehicle(0, veh)
      return true
    end
  end
end

local function updateVehicleElectrics()

end

local function HandleUpdate(received)
  local packetLength = string.len(received)
  local code = string.sub(received, 1, 4)
  local ClientID = string.sub(received, 5, 12)
  local data = jsonDecode(string.sub(received, 13, packetLength))

    --println(code)
    --println(ClientID)
    --println(HelperFunctions.dump(data))

  if code == "U-VI" then
    println(ClientID..' == '..Settings.ClientID..' ?')
    if ClientID ~= Settings.ClientID then
      updateVehicleInputs(ClientID, data)
    end
  else
    println("Unknown Code '"..code.."' in Updates.lua")
  end
end

M.HandleUpdate = HandleUpdate

return M
