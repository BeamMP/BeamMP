-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

--- positionGE API.
--- Author of this documentation is Titch
--- @module positionGE
--- @usage applyPos(...) -- internal access
--- @usage positionGE.handle(...) -- external access


local M = {}

local targetGameSpeed = 1
local actualSimSpeed = 1




--- Called on specified interval by positionGE to simulate our own tick event to collect data.
local function tick()
	for i,v in pairs(MPVehicleGE.getPlayerVehicleObjects(MPConfig.getPlayerServerID())) do
		if v then
			v:queueLuaCommand("positionVE.getVehicleRotation()")
		end
	end
end

--- Wraps vehicle position, rotation etc. data from player own vehicles and sends it to the server.
-- INTERNAL USE
-- @param data table The position and rotation data from VE
-- @param gameVehicleID number The vehicle ID according to the local game
local function sendVehiclePosRot(data, gameVehicleID)
	if MPGameNetwork.launcherConnected() then
		local serverVehicleID = MPVehicleGE.getServerVehicleID(gameVehicleID) -- Get serverVehicleID
		if serverVehicleID and MPVehicleGE.isOwn(gameVehicleID) then -- If serverVehicleID not null and player own vehicle
			MPGameNetwork.send(MPNetworkHelpers.generatePacketBuffer('Zp',serverVehicleID,data))
		end
	end
end


--- This function serves to send the position data received for another players vehicle from GE to VE, where it is handled.
-- @param encoded json The data to be applied to a vehicle, needs to contain "pos", "rot", "vel", "rvel", "ping" and "tim"
-- @param serverVehicleID string The VehicleID according to the server.
local function applyPos(data, serverVehicleID)
	local vehicle = MPVehicleGE.getVehicleByServerID(serverVehicleID)
	if not vehicle then log('E', 'applyPos', 'Could not find vehicle by ID '..serverVehicleID) return end

	local veh = getObjectByID(vehicle.gameVehicleID)
	if veh then -- vehicle already spawned, send data
		if veh.mpVehicleType == nil then
			veh:queueLuaCommand("MPVehicleVE.setVehicleType('R')")
			veh.mpVehicleType = 'R'
		end
		be:sendToMailbox("vehPosPckt" .. serverVehicleID ,data)
	end

	local owner = vehicle:getOwner()
	if owner and not owner.hasUpdatedPing or not veh then -- only update once per frame per player unless the vehicle is not spawned, spawned vehicles already gets their position and rotation in MPvehicleGE
		local decoded = jsonDecode(data)
		local deltaDt = math.max((decoded.tim or 0) - (vehicle.lastDt or 0), 0.001)
		vehicle.lastDt = decoded.tim

		vehicle.position:set(decoded.pos[1],decoded.pos[2],decoded.pos[3])
		vehicle.rotation:set(decoded.rot[1],decoded.rot[2],decoded.rot[3],decoded.rot[4])

		if owner and not owner.updatedPing then
			local ping = math.floor(decoded.ping*1000) -- (d.ping-deltaDt)
			UI.setPlayerPing(owner.name, ping)
			owner.ping = ping
			owner.fps = 1/deltaDt
		end-- Send ping to UI
		owner.hasUpdatedPing = true
	end
end


--- The raw message from the server. This is unpacked first and then sent to applyPos() or smoothPosExec()
-- @param rawData string The raw message data.
local function handle(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")

	local veh = MPVehicleGE.getVehicles()[serverVehicleID]

	if not veh or veh.isLocal then
		return
	end

	if code == 'p' then
		applyPos(data, serverVehicleID)
	else
		log('W', 'handle', "Received unknown packet '"..tostring(code).."'! ".. rawData)
	end
end

--- This function is for setting a ping value for use in the math of predition of the positions 
-- @param ping number The Ping value
local function setPing(ping)
	local p = ping/1000
	be:queueAllObjectLua("positionVE.setPing("..p..")")
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

	if math.abs(localVel.x) + math.abs(localVel.y) + math.abs(localVel.z) > (math.abs(vehVel.x) + math.abs(vehVel.y) + math.abs(vehVel.z))*5 then -- detect if velocity was a teleport
		return
	end

	local refNodeID = veh:getRefNodeId()
	local vehRot = quatFromDir(-veh:getDirectionVector(), veh:getDirectionVectorUp())
	local rot = vehRot:inversed() * newRot
	veh:setClusterPosRelRot(refNodeID, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)

	vel = vel - localVel:rotated(rot) -- setClusterPosRelRot also rotates the velocity so we have to do that as well
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
		local simSpeed = simTimeAuthority.getReal() * (simTimeAuthority.getPause() and 0 or 1)
		if targetGameSpeed ~= simSpeed then
			be:queueAllObjectLua("positionVE.setGameSpeed("..simSpeed..")")
		end
		targetGameSpeed = simSpeed
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
