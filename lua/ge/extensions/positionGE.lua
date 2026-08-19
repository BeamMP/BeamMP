-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- positionGE API.
--- Author of this documentation is Titch
--- @module positionGE
--- @usage applyPos(...) -- internal access
--- @usage positionGE.handle(...) -- external access


local M = {}

local ok, err = pcall(function()
    ffi.cdef[[
        typedef struct { float x, y, z; } Vec3;
        typedef struct { float x, y, z, w; } Quat;
        typedef struct { Vec3 pos; Quat rot; Vec3 vel; Vec3 rvel; double tim;} PosPacket;
    ]]
end)
if not ok then
    print("cdef error: " .. tostring(err))
end

local receivePacket = ffi.new("PosPacket")
local sendPacket = ffi.new("PosPacket")
local posPacketSize = ffi.sizeof(receivePacket);
local sendPacketSize = ffi.sizeof(sendPacket);

local actualSimSpeed = 1


--- Called on specified interval by positionGE to simulate our own tick event to collect data.
local function tick()
	for i,v in pairs(MPVehicleGE.getPlayerVehicleObjects(MPConfig.getPlayerServerID())) do
		if v then
			v:queueLuaCommand("if positionVE then positionVE.getVehicleRotation() end")
		end
	end
end


local sendPos  = vec3()
local sendVel  = vec3()
local sendRot  = quat()
local sendRvel = vec3()

local structSendPos  = sendPacket.pos
local structSendVel  = sendPacket.vel
local structSendRot  = sendPacket.rot
local structSendRvel = sendPacket.rvel
--- Wraps vehicle position, rotation etc. data from player own vehicles and sends it to the server.
-- INTERNAL USE
-- @param data table The position and rotation data from VE
-- @param gameVehicleID number The vehicle ID according to the local game
local function sendVehiclePosRot(data, gameVehicleID)
	if MPGameNetwork.launcherConnected() then
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			if MPTimeSyncGE.hasReceivedPing and #data == sendPacketSize then
				MPGameNetwork.send(MPNetworkHelpers.generatePacketBuffer('Zf',serverVehicleID,data))
			else
				local sendBuffer = MPNetworkHelpers.generatePacketBuffer('Zp',serverVehicleID,data)
				MPGameNetwork.send(sendBuffer)
			end
		end
	end
end

local recPos  = vec3()
local recVel  = vec3()
local recRot  = quat()
local recRvel = vec3()

local structPos = receivePacket.pos
local structVel = receivePacket.vel
local structRot = receivePacket.rot
local structRvel = receivePacket.rvel

--- This function serves to send the position data received for another players vehicle from GE to VE, where it is handled.
-- @param encoded json The data to be applied to a vehicle, needs to contain "pos", "rot", "vel", "rvel", "ping" and "tim"
-- @param serverVehicleID string The VehicleID according to the server.
local function applyPos(data, serverVehicleID)
	local vehicle = MPVehicleGE.getVehicleByServerID(serverVehicleID)
	if not vehicle then log('E', 'applyPos', 'Could not find vehicle by ID '..serverVehicleID) return end
	local veh = getObjectByID(vehicle.gameVehicleID)
	local owner = vehicle:getOwner()
	if veh then -- vehicle already spawned, send data
		if veh.mpVehicleType == nil then
			veh:queueLuaCommand("MPVehicleVE.setVehicleType('R')")
			veh.mpVehicleType = 'R'
		end
		be:sendToMailbox("vehPosPckt" .. serverVehicleID ,data)
	elseif owner then
		if #data == posPacketSize then
			ffi.copy(receivePacket, data, posPacketSize)
			recPos:set(structPos.x,structPos.y,structPos.z)
			recVel:set(structVel.x,structVel.y,structVel.z)
			recRot:set(structRot.x,structRot.y,structRot.z,structRot.w)
			recRvel:set(structRvel.x,structRvel.y,structRvel.z)
		else
			log('E','applyPos', 'Received invalid position packet with size '..#data..' Expected '..posPacketSize)
			return
		end

		vehicle.position:set(recPos)
		vehicle.rotation:set(recRot)
	end
end

local function applyPosJson(data, serverVehicleID)
	local vehicle = MPVehicleGE.getVehicleByServerID(serverVehicleID)
	if not vehicle then log('E', 'applyPos', 'Could not find vehicle by ID '..serverVehicleID) return end
	local veh = getObjectByID(vehicle.gameVehicleID)
	if veh then -- vehicle already spawned, send data
		if veh.mpVehicleType == nil then
			veh:queueLuaCommand("MPVehicleVE.setVehicleType('R')")
			veh.mpVehicleType = 'R'
		end
		be:sendToMailbox("vehPosPcktJson" .. serverVehicleID ,data)
	end

	local owner = vehicle:getOwner()
	if owner and not owner.hasUpdatedPing or not veh then -- only update once per frame per player unless the vehicle is not spawned, spawned vehicles already gets their position and rotation in MPvehicleGE
		local decodedData = jsonDecode(data)
		local tim = decodedData.tim
		local ping = decodedData.ping

		recPos:set(decodedData.pos[1],decodedData.pos[2],decodedData.pos[3])
		recVel:set(decodedData.vel[1],decodedData.vel[2],decodedData.vel[3])
		recRot:set(decodedData.rot[1],decodedData.rot[2],decodedData.rot[3],decodedData.rot[4])
		recRvel:set(decodedData.rvel[1],decodedData.rvel[2],decodedData.rvel[3])

		vehicle.lastDt = tim
		local deltaDt = math.max((tim or 0) - (vehicle.lastDt or 0), 0.001)

		vehicle.position:set(recPos)
		vehicle.rotation:set(recRot)

		if owner and ping and not owner.updatedPing then-- TODO place holder until we have a dedicated player list ping packet
			ping = math.floor(ping*1000)

			UI.setPlayerPing(owner.name, ping) -- Send ping to UI
			owner.ping = ping
			owner.fps = 1/deltaDt
		end
		owner.hasUpdatedPing = true
	end
end

--- The raw message from the server. This is unpacked first and then sent to applyPos() or smoothPosExec()
-- @param rawData string The raw message data.
local function handle(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:(.*)")

	local veh = MPVehicleGE.getVehicles()[serverVehicleID]

	if not veh or veh.isLocal then
		return
	end

	if code == 'f' then
		applyPos(data, serverVehicleID)
	elseif code == 'p' then
		applyPosJson(data, serverVehicleID)
	else
		log('W', 'handle', "Received unknown packet '"..tostring(code).."'! ".. rawData)
	end
end

--- This function is for setting a ping value for use in the math of predition of the positions 
-- @param ping number The Ping value
local function setPing(ping)
	local p = ping/1000
	be:queueAllObjectLua("if positionVE then positionVE.setPing("..p..") end")
end

--- This function is to allow for the setting of the vehicle/objects position.
-- @param gameVehicleID number The local game vehicle / object ID
-- @param x number Coordinate x
-- @param y number Coordinate y
-- @param z number Coordinate z
local function setPosition(gameVehicleID, x, y, z) -- TODO: this is only here because there seems to be no way to set vehicle position in vehicle lua without resetting the vehicle
	local veh = getObjectByID(gameVehicleID)
	veh:setPositionNoPhysicsReset(Point3F(x, y, z))
end

local function setPositionRotationVelocity(gameVehicleID, positionData) -- this is done here because setting velocity and rotation in GE doesn't damage vehicles
	local pos = positionData.pos
	local newRot = positionData.rot
	local vel = positionData.vel
	local rvel = positionData.rvel
	local veh = getObjectByID(gameVehicleID)

	local localVel = veh:getVelocity()
	local vehVel = positionData.vehVel

	if localVel:length() > vehVel:length()*5 then -- detect if velocity was a teleport
		return
	end

	local refNodeID = veh:getRefNodeId()
	local vehRot = quatFromDir(-veh:getDirectionVector(), veh:getDirectionVectorUp())
	local rot = vehRot:inversed() * newRot

	veh:applyClusterVelocityScaleAdd(refNodeID, 1, -localVel.x, -localVel.y, -localVel.z) -- setting velocity to 0, seems more stable to do this before rotate then add velocity again after rotating
	veh:setClusterPosRelRot(refNodeID, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w) -- this also rotates current velocity

	veh:applyClusterVelocityScaleAdd(refNodeID, 1, vel.x, vel.y, vel.z) -- setting velocity with the GE command doesn't destroy vehicles so we set most of the velocity here

	local noCounterVelocity = positionData.noCounter or 0
	local onlyAngularVelocity = 1

	-- but since it doesn't do rotational velocity we still need to use VE
	-- apparently GE to VE queues are really fast, so we don't need any extra prediction with this queue
	veh:queueLuaCommand("velocityVE.setAngularVelocity("..vel.x..", "..vel.y..", "..vel.z..", "..rvel.x..", "..rvel.y..", "..rvel.z..","..onlyAngularVelocity..","..noCounterVelocity..")")
end

--- This function is used for setting the simulation speed 
--- @param speed number
local function setActualSimSpeed(speed)
	actualSimSpeed = speed*(1/simTimeAuthority.getReal())
end

--- This function is used for getting the simulation speed 
--- @return number actualSimSpeed
local function getActualSimSpeed()
	return actualSimSpeed
end

local function onUpdate(dtReal, dtSim, dtRaw)
	if MPGameNetwork and MPGameNetwork.launcherConnected() then
		setActualSimSpeed(dtSim/dtRaw)
		local players = getPlayers()
		for k,player in pairs(players) do
			player.hasUpdatedPing = false
		end
	end
end

M.applyPos                    = applyPos
M.tick                        = tick
M.handle                      = handle
M.sendVehiclePosRot           = sendVehiclePosRot
M.setPosition                 = setPosition
M.setPositionRotationVelocity = setPositionRotationVelocity
M.setPing                     = setPing
M.setActualSimSpeed           = setActualSimSpeed
M.getActualSimSpeed           = getActualSimSpeed
M.onUpdate                    = onUpdate
M.onInit = function() setExtensionUnloadMode(M, "manual") end

return M
