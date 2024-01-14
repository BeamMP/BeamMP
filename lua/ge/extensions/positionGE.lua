--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================

--- positionGE API.
--- Author of this documentation is Titch
--- @module positionGE
--- @usage applyPos(...) -- internal access
--- @usage positionGE.handle(...) -- external access


local M = {}

local actualSimSpeed = 1

--[[
	["X-Y"] = table
		[data] = table
			[pos] = array[3]
			[rot] = array[4]
			[vel] = array[3]
			[rvel] = array[4]
			[tim] = float
			[ping] = float
		[last_executed_tim] = float
		[executed_last] = hptimerstruct
		[median] = float
		[median_array] = array
			[1] = next index
			[2] = max array buffer size
			[3..[2] + 2] = float
		[median_timer] = hptimerstruct
		[executed] = bool
]]
local POSSMOOTHER = {}
local TIMER = (HighPerfTimer or hptimer) -- game own timer that is much more accurate then os.clock()



--- Called on specified interval by positionGE to simulate our own tick event to collect data.
local function tick()
	local ownMap = MPVehicleGE.getOwnMap() -- Get map of own vehicles
	for i,v in pairs(ownMap) do -- For each own vehicle
		local veh = be:getObjectByID(i) -- Get vehicle
		if veh then
			veh:queueLuaCommand("positionVE.getVehicleRotation()")
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
			local decoded = jsonDecode(data)
			local simspeedReal = simTimeAuthority.getReal()

			decoded.isTransitioning = (simTimeAuthority.get() ~= simspeedReal) or nil

			simspeedReal = simTimeAuthority.getPause() and 0 or simspeedReal -- set velocities to 0 if game is paused

			for k,v in pairs(decoded.vel) do decoded.vel[k] = v*simspeedReal end
			for k,v in pairs(decoded.rvel) do decoded.rvel[k] = v*simspeedReal end

			data = jsonEncode(decoded)
			MPGameNetwork.send('Zp:'..serverVehicleID..":"..data)
		end
	end
end


--- This function serves to send the position data received for another players vehicle from GE to VE, where it is handled.
-- @param decoded table The data to be applied to a vehicle, needs to contain "pos", "rot", "vel", "rvel", "ping" and "tim"
-- @param serverVehicleID string The VehicleID according to the server.
local function applyPos(decoded, serverVehicleID)
	local vehicle = MPVehicleGE.getVehicleByServerID(serverVehicleID)
	if not vehicle then log('E', 'applyPos', 'Could not find vehicle by ID '..serverVehicleID) return end

	local simspeedFraction = 1/simTimeAuthority.getReal()

	for k,v in pairs(decoded.vel) do decoded.vel[k] = v*simspeedFraction end
	for k,v in pairs(decoded.rvel) do decoded.rvel[k] = v*simspeedFraction end

	decoded.localSimspeed = simspeedFraction

	data = jsonEncode(decoded)


	local veh = be:getObjectByID(vehicle.gameVehicleID)
	if veh then -- vehicle already spawned, send data
		if veh.mpVehicleType == nil then
			veh:queueLuaCommand("MPVehicleVE.setVehicleType('R')")
			veh.mpVehicleType = 'R'
		end
		veh:queueLuaCommand("positionVE.setVehiclePosRot('"..data.."')")
	end
	local deltaDt = math.max((decoded.tim or 0) - (vehicle.lastDt or 0), 0.001)
	vehicle.lastDt = decoded.tim
	local ping = math.floor(decoded.ping*1000) -- (d.ping-deltaDt)

	vehicle.ping = ping
	vehicle.fps = 1/deltaDt
	vehicle.position = Point3F(decoded.pos[1],decoded.pos[2],decoded.pos[3])

	local owner = vehicle:getOwner()
	if owner then UI.setPlayerPing(owner.name, ping) end-- Send ping to UI
end

--- Tries to delay the positional update execution to match the average update interval from this vehicle
-- Reduces vehicle warping
-- @tparam serverVehicleID string X-Y
-- @tparam decoded table The data to be applied to a vehicle, needs to contain "pos", "rot", "vel", "rvel", "ping" and "tim"
local function smoothPosExec(serverVehicleID, decoded)
	if POSSMOOTHER[serverVehicleID] == nil then
		local new = {}
		new.data = decoded
		new.last_executed_tim = decoded.tim
		new.executed_last = TIMER()
		new.executed = false
		new.median = 32
		new.median_array = {3,10,32,32,32,32,32,32,32,32,32,32}
		--new.median_array = {3,20,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32,32}
		new.median_timer = TIMER()
		POSSMOOTHER[serverVehicleID] = new
				
	elseif decoded.tim < 3 or (POSSMOOTHER[serverVehicleID].last_executed_tim - decoded.tim) > 3 then -- if remote timer got reset or if new data is 3 seconds earlier then the known, expect that the remote vehicle got reset.
		POSSMOOTHER[serverVehicleID].data = decoded
		POSSMOOTHER[serverVehicleID].last_executed_tim = decoded.tim
		POSSMOOTHER[serverVehicleID].executed = false
				
	elseif POSSMOOTHER[serverVehicleID].last_executed_tim > decoded.tim then
		-- nothing, outdated data
		
	else
		-- ensure that there is a min age distance between the remote packages of 15ms.
		-- right order 0.022 -- 0.044 -- 0.066
		-- wrong order 0.022 -- 0.066 -- 0.044 (if 0.066 is received first, we overwrite it with 0.044 -> if 0.066 wasnt executed yet. otherwise this wouldnt be reached)
		-- Todo: try to calc a median packet between the two for all relevant data. eg. (decoded.pos + POSSMOOTHER[serverVehicleID].data.pos) / 2
		if (decoded.tim - POSSMOOTHER[serverVehicleID].last_executed_tim) < 0.015 then return nil end
		
		local median_time = POSSMOOTHER[serverVehicleID].median_timer:stopAndReset()
		POSSMOOTHER[serverVehicleID].data = decoded -- also outdates unexecuted packets
		POSSMOOTHER[serverVehicleID].executed = false
		if median_time > 14 then -- there can be lower intervals then 32ms, so we cover that
			if median_time < 80 then
				local median_array = POSSMOOTHER[serverVehicleID].median_array
				local next_index = median_array[1]
				median_array[next_index] = median_time
				median_array[1] = next_index + 1
				if next_index == median_array[2] + 2 then
					median_array[1] = 3
					local median = 0
					for i = 3, median_array[2] + 2 do
						median = median + median_array[i]
					end
					-- median + X to artificially count in small fluctuations
					POSSMOOTHER[serverVehicleID].median = (median / median_array[2]) + 3
				end
				POSSMOOTHER[serverVehicleID].median_array = median_array
			end
		end
	end
end

--- The raw message from the server. This is unpacked first and then sent to applyPos() or smoothPosExec()
-- @param rawData string The raw message data.
local function handle(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")
	if code == 'p' then
		local decoded = jsonDecode(data)
		if settings.getValue("enablePosSmoother") then
			smoothPosExec(serverVehicleID, decoded)
		else
			applyPos(decoded, serverVehicleID)
		end
	else
		log('W', 'handle', "Received unknown packet '"..tostring(code).."'! ".. rawData)
	end
end

--- This function is for setting a ping value for use in the math of predition of the positions 
-- @param ping number The Ping value
local function setPing(ping)
	local p = ping/1000
	for i = 0, be:getObjectCount() - 1 do
		local veh = be:getObject(i)
		if veh then
			veh:queueLuaCommand("positionVE.setPing("..p..")")
		end
	end
end

--- This function is to allow for the setting of the vehicle/objects position.
-- @param gameVehicleID number The local game vehicle / object ID
-- @param x number Coordinate x
-- @param y number Coordinate y
-- @param z number Coordinate z
local function setPosition(gameVehicleID, x, y, z) -- TODO: this is only here because there seems to be no way to set vehicle position in vehicle lua without resetting the vehicle
	local veh = be:getObjectByID(gameVehicleID)
	veh:setPositionNoPhysicsReset(Point3F(x, y, z))
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

--- This function is used to execute smoothed positional updates if enabled
local function onPreRender(dt)
	-- tick pos updates per vehicle based on their median pos update interval
	for serverVehicleID, data in pairs(POSSMOOTHER) do
		local timedif = data.executed_last:stop()
		if not data.executed and timedif >= data.median then
			POSSMOOTHER[serverVehicleID].executed_last:stopAndReset()
			POSSMOOTHER[serverVehicleID].executed = true
			POSSMOOTHER[serverVehicleID].last_executed_tim = data.data.tim
			applyPos(data.data, serverVehicleID)
			
		elseif timedif > 60000 then -- seconds. vehicle potentially removed. rem entry
			POSSMOOTHER[serverVehicleID] = nil
		end
	end
end

--- This function is used to reset the positional update smoother when it is disabled
local function onSettingsChanged()
	if not settings.getValue("enablePosSmoother") then -- nil/false
		for serverVehicleID, _ in pairs(POSSMOOTHER) do
			POSSMOOTHER[serverVehicleID] = nil
		end
	end
end

M.applyPos          = applyPos
M.tick              = tick
M.handle            = handle
M.sendVehiclePosRot = sendVehiclePosRot
M.setPosition       = setPosition
M.setPing           = setPing
M.setActualSimSpeed = setActualSimSpeed
M.getActualSimSpeed = getActualSimSpeed
M.onPreRender       = onPreRender
M.onSettingsChanged = onSettingsChanged
M.posSmoother       = POSSMOOTHER -- debug entry
M.onInit = function() setExtensionUnloadMode(M, "manual") end

return M
