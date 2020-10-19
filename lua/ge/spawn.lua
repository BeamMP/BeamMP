local M  = {}
local logTag = 'spawn.lua'

local function setVehicleObject(veh, jbeam, configString, pos, rot, color, color2, color3, cling, mp)
  if not veh then
    log('E', logTag, 'setVehicleObject Failed, no vehicle provided.')
    return
  end

  veh.JBeam = jbeam
  veh.partConfig = configString

  if color then
    veh.color = color:asLinear4F()
  end

  if mp then
    veh.isMP = true
  end

  if color2 then
    veh.colorPalette0 = color2:asLinear4F()
  end

  if color3 then
    veh.colorPalette1 = color3:asLinear4F()
  end

  -- TODO the rotation by 180 degrees needs to happen before the other rotation. The order might still be wrong in some places
  rot = quat(0,0,1,0) * rot -- rotate 180 degrees

  veh:spawnObjectWithPosRot(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)

  local missionGroup = scenetree.MissionGroup
  if not missionGroup then
    log('E', logTag, 'MissionGroup does not exist')
    return
  end
  missionGroup:addObject(veh.obj)

  -- do not save vehicles that are spawned via this function with the level
  veh.canSave = false

  -- add it to the group 'SpawnedVehicles'
  local vehGroup = scenetree.SpawnedVehicles
  if not vehGroup then
    vehGroup = createObject('SimGroup')
    if vehGroup then
      vehGroup:registerObject('SpawnedVehicles')
      vehGroup.canSave = false
      missionGroup:addObject(vehGroup.obj)
    end
  else
    vehGroup:addObject(veh.obj)
  end

  if cling then
    veh:autoplace(false)
  end
end

local function spawnVehicle(jbeam, configString, pos, rot, color, color2, color3, name, mp, cling, autoEnterVehicle)
  local veh = createObject("BeamNGVehicle")
  print("VEH SPAWN EVENT FROM SPAWN.LUA HAS VEH!")

  if cling == nil then
    cling = true
  end

  if not veh then
    log('E', logTag, 'Failed to create vehicle')
    return
  end

  autoEnterVehicle = tostring(autoEnterVehicle ~= false) -- nil defaults to 'true'
  veh:setDynDataFieldbyName("autoEnterVehicle", 0, autoEnterVehicle)

  local spawnDatablock = String("default_vehicle")
  local dataBlock = scenetree.findObject(spawnDatablock:c_str())

  if not datablock then
    veh.dataBlock = dataBlock
  else
    log('E', logTag, 'Failed to find dataBlock')
    return
  end

  name = name or "clone"
  local i = 0
  while scenetree.findObject(name) do
    name = "clone" .. tostring(i)
    i = i + 1
  end

  veh:registerObject(name)

  veh.licenseText = TorqueScript.setVar( "$beamngVehicleLicenseName","")

  setVehicleObject(veh, jbeam, configString, pos, rot, color, color2, color3, cling, mp)

  return veh
end

--[[
pickSpawnPoint s responsible for finding a valid spawn point for a player and camera
@param spawnName string represent player or camera spawn point
]]
local function pickSpawnPoint(spawnName)
  local playerSP,spawnPointName
  local defaultSpawnPoint = setSpawnpoint.loadDefaultSpawnpoint()
  local spawnDefaultGroups = {"CameraSpawnPoints", "PlayerSpawnPoints", "PlayerDropPoints"}
  if defaultSpawnPoint then
    local spawnPoint = scenetree.findObject(defaultSpawnPoint)
    if spawnPoint then
      return spawnPoint
    else
      log('W', logTag, 'No SpawnPointName in mission file vehicle spawn in the default position')
    end
  end
  --Walk through the groups until we find a valid object
  for i,v in pairs(spawnDefaultGroups) do
    if scenetree.findObject(spawnDefaultGroups[i]) then
      local spawngroupPoint = scenetree.findObject(spawnDefaultGroups[i]):getRandom()
      if not spawngroupPoint then
        break
      end
      local sgPpointID = scenetree.findObjectById(spawngroupPoint:getID())
      if not sgPpointID then
        break
      end
      return sgPpointID
    end
  end

  --[[ ensuring backward compability with mods
  ]]
  local dps = scenetree.findObject("DefaultPlayerSpawnSphere")
  if dps then
    return scenetree.findObjectById(dps.obj:getID())
  end

  --[[Didn't find a spawn point by looking for the groups so let's return the
   "default" SpawnSphere First create it if it doesn't already exist
  ]]
  playerSP = createObject('SpawnSphere')
  if not playerSP then
    log('E', logTag, 'could not create playerSP')
    return
  end
  playerSP.dataBlock = scenetree.findObject('SpawnSphereMarker')
  if spawnName == "player" then
    playerSP.spawnClass = String("BeamNGVehicle")
    playerSP.spawnDatablock = String("default_vehicle")
    spawnPointName = "DefaultPlayerSpawnSphere"
    playerSP:registerObject(spawnPointName)
  elseif spawnName == 'camera' then
    playerSP.spawnClass = String("Camera")
    playerSP.spawnDatablock = String("Observer")
    spawnPointName = "DefaultCameraSpawnSphere"
    playerSP:registerObject(spawnPointName)
  end
  local missionCleanup = scenetree.MissionCleanup
  if not missionCleanup then
    log('E', logTag, 'MissionCleanup does not exist')
    return
  end
  --[[ Add it to the MissionCleanup group so that it doesn't get saved
    to the Mission (and gets cleaned up of course)
  ]]
  missionCleanup:addObject(playerSP.obj)
  return playerSP
end

local function spawnCamera()
  local game = scenetree.findObject("Game")
  if not game then
    log('E', logTag, 'gameConnection not found')
    return
  end
  local missionCleanup = scenetree.MissionCleanup
  if not missionCleanup then
    log('E', logTag, 'missionCleanup does not exist')
    return
  end
  for _,camName in ipairs({"gameCamera", "freeCamera"}) do
    -- Set the control object to the default camera
    if not game[camName] then
      local cam = createObject('Camera')
      if camName == "gameCamera" then
        cam:setLuaMode()
      end
      cam.dataBlock = scenetree.findObject("Observer")
      local res = cam:registerObject(camName)
      game[camName] = cam
    end
    --If we have a camera then set up some properties
    if game[camName] then
      local id = game[camName]
      local cam = scenetree.findObjectById(id)
      missionCleanup:addObject(cam.obj)
      game:setCameraHandler(cam.obj)
      local csp = pickSpawnPoint('camera')
      if csp  then
        cam:setTransform(csp:getTransform())
      else
        cam:setTransform(csp)
      end
    end
  end
end

--[[
spawnPlayer is responsible for spawning a player for a client
]]
local function spawnPlayer()
  local spawnClass, spawnDatablock, spawnProperties, spawnScript, player
  local spawnPoint = pickSpawnPoint('player')
  if M.preventPlayerSpawning then
    log('D',logTag,'not spawning player upon request')
    return
  end
  local game = scenetree.findObject("Game")
  if game.player and scenetree.findObjectById(game.player) then
    log('E', logTag, 'Attempting to create a player for a client that already has one!')
  end
  if spawnPoint then
    spawnClass      = String("BeamNGVehicle")
    spawnDatablock  = String("default_vehicle")
    if spawnPoint.spawnClass:c_str() ~=""  then
      spawnClass = spawnPoint.spawnClass
    end
    --[[
    This may seem redundant given the above but it allows
    the SpawnSphere to override the datablock without
    overriding the default player class
    ]]
    if spawnPoint.spawnDatablock and scenetree.findObject(spawnPoint.spawnDatablock:c_str()) then
      spawnDatablock = spawnPoint.spawnDatablock
    end

    local tempColor=ColorF(1, 1, 1, 1)     --player.color is point4f object
    local tempColorStr = TorqueScript.getVar("$beamngVehicleColor")
    tempColor:setFromString( (tempColorStr ~= '' and tempColorStr) or "1 1 1 1" )

    player = spawnVehicle(TorqueScript.getVar("$beamngVehicle"), TorqueScript.getVar("$beamngVehicleConfig"), vec3(spawnPoint:getPosition()), quat(spawnPoint:getRotation()) * quat(0,0,1,0), tempColor, tempColor, tempColor, "thePlayer")
  end

  -- Update the default camera to start with the player
  if game.freeCamera then
    local freeCamera = scenetree.findObjectById(game.freeCamera)
    if freeCamera then
      if spawnClass== "Player" then
        freeCamera:setTransform(player:getEyeTransform())
      else
        freeCamera:setTransform(player:getTransform())
      end
    else
      log('E', logTag, 'freeCamera not in scenetree')
    end
  end
  --[[Add the player object to MissionCleanup so that it
  won't get saved into the level files and will get
  cleaned up properly--]]
  local missionCleanup = scenetree.MissionCleanup
  if not missionCleanup then
    log('E', logTag, 'missionCleanup does not exist')
    return
  end
  missionCleanup:addObject(player.obj)
  local missionGroup = scenetree.MissionGroup
  if not missionGroup then
    log('E', logTag, 'MissionGroup does not exist')
    return
  end
  missionGroup:addObject(player.obj)
  player.canSave = false
  game.player = player
  commands.setGameCamera()
end


----------------
local function calculateRelativeVehiclePlacement(transform0, coupler0_offset, transform1, coupler1_offset)
  local coupler0_ws
  do
    local coupler0_os = MatrixF(true)
    coupler0_os:setColumn(3, coupler0_offset)
    coupler0_ws = transform0 * coupler0_os
  end

  local res
  do
    local coupler1_os = MatrixF(true)
    coupler1_os:setColumn(3, coupler1_offset)
    local coupler1_ws = transform1 * coupler1_os

    res = coupler0_ws * (coupler1_ws:inverse() * transform1)
  end
  return res
end

local function placeTrailer(vehId,couplerOffsetVeh, trailerId,couplerOffsetTrailer)

  local veh = be:getObjectByID(vehId)
  if not veh then return end

  local veh2 = be:getObjectByID(trailerId)
  if not veh2 then return end

  local transform0 = veh:getRefNodeMatrix()
  local coupler0_offset = couplerOffsetVeh--Point3F(0, 3, 0.2)
  local transform1 = veh2:getRefNodeMatrix()
  local coupler1_offset = couplerOffsetTrailer--Point3F(0.3, -3.3, 0)

  local mat = calculateRelativeVehiclePlacement(transform0, coupler0_offset, transform1, coupler1_offset)
  debugDrawer:drawSphere(mat:getColumn(3), 0.5, ColorF(0, 0, 1, 1))

  veh2:setTransform(mat)
  veh2:queueLuaCommand('obj:requestReset(RESET_PHYSICS)')
  veh2:resetBrokenFlexMesh()
  veh:queueLuaCommand('beamstate.activateAutoCoupling()')
end

local function spawnTrailerBehindVehicle(carID, trailerID)
  -- Spawn the trailer behind the vehicle
  local car = scenetree.findObjectById(carID)
  local carBB = car:getSpawnWorldOOBB()
  local halfCarLength = vec3(carBB:getHalfExtents()).y

  local trailer = scenetree.findObjectById(trailerID)
  local trailerBB = trailer:getSpawnWorldOOBB()
  local halfTrailerLength = vec3(trailerBB:getHalfExtents()).y

  -- Position on the bottom of the cars BB under the center
  local position = vec3(carBB:getCenter())
  position = position - vec3(car:getDirectionVectorUp()) * vec3(carBB:getHalfExtents()).z

  -- Difference of the bottom center of the trailer to trailer position
  local diffCenterPos = vec3(trailer:getPosition()) - (vec3(trailerBB:getCenter()) - vec3(trailer:getDirectionVectorUp()) * vec3(trailerBB:getHalfExtents()).z)

  -- Translate the trailer back so that the trailers BB touches the cars BB
  local direction = vec3(car:getDirectionVector())
  direction:normalize()
  position = position - (direction * (halfCarLength + halfTrailerLength))
  position = position + diffCenterPos
  trailer:setPosition(Point3F(position.x, position.y, position.z))
end

M.spawnVehicle                      = spawnVehicle
M.setVehicleObject                  = setVehicleObject
M.spawnCamera                       = spawnCamera
M.spawnPlayer                       = spawnPlayer
M.calculateRelativeVehiclePlacement = calculateRelativeVehiclePlacement
M.placeTrailer                      = placeTrailer
return M
