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
		[executed_last] = hptimerstruct
		[median] = float
		[median_array] = array
			[1] = next index
			[2] = max array buffer size
			[3..[2] + 2] = float
		[executed] = bool
]]
local POSSMOOTHER = {}
local TIMER = (HighPerfTimer or hptimer) -- game own

local DEBUG_TO_CSV = nil
local DEBUG_TABLE = {}
local function round(x)
  return x>=0 and math.floor(x+0.5) or math.ceil(x-0.5)
end
local function toCsv(serverVehicleID) -- temp code
	if DEBUG_TO_CSV == nil then
		DEBUG_TO_CSV = io.open("test.csv", "w")
		if DEBUG_TO_CSV == nil then return nil end
		
		local tmp = ""
		for i = 0, 20 do
			tmp = tmp .. i .. ","
		end
		tmp = string.sub(tmp, 1, string.len(tmp) - 1)
		DEBUG_TO_CSV:write(tmp .. "\n")
	end
	
	local split = split(serverVehicleID, "-")
	local playerid = tonumber(split[1])
	if playerid > 20 then return nil end
	if tonumber(split[2]) > 0 then return nil end -- only care for vid 0
	
	local current_time = os.clock()
	if DEBUG_TABLE[playerid] == nil then
		DEBUG_TABLE[playerid] = current_time
		return nil
	end
	
	local tmp = ""
	for i = 0, playerid - 1 do
		tmp = tmp .. ","
	end
	tmp = tmp .. tostring(round((current_time - DEBUG_TABLE[playerid]) * 1000)) .. ","
	for i = playerid - 1, 20 do
		tmp = tmp .. ","
	end
	tmp = string.sub(tmp, 1, string.len(tmp) - 1)
	DEBUG_TO_CSV:write(tmp .. "\n")
	
	DEBUG_TABLE[playerid] = current_time
end

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
-- @param data table The data to be applied as position and rotation
-- @param serverVehicleID string The VehicleID according to the server.
local function applyPos(decoded, serverVehicleID)
	local vehicle = MPVehicleGE.getVehicleByServerID(serverVehicleID)
	if not vehicle then log('E', 'applyPos', 'Could not find vehicle by ID '..serverVehicleID) return end
	
	toCsv(serverVehicleID)

	--local decoded = jsonDecode(data)

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


--- The raw message from the server. This is unpacked first and then sent to applyPos()
-- @param rawData string The raw message data.
local function handle(rawData)
	local code, serverVehicleID, data = string.match(rawData, "^(%a)%:(%d+%-%d+)%:({.*})")
	if code == 'p' then
		local decoded = jsonDecode(data)
		if settings.getValue("enablePosSmoother") then
			if POSSMOOTHER[serverVehicleID] == nil then
				local new = {}
				new.data = decoded
				new.executed_last = TIMER()
				new.executed = false
				new.median = 32
				new.median_array = {3,10,32,32,32,32,32,32,32,32,32,32}
				POSSMOOTHER[serverVehicleID] = new
				
			elseif POSSMOOTHER[serverVehicleID].data.tim > decoded.tim then
				-- nothing, outdated data
				
			elseif decoded.tim < 1 then -- vehicle may have been reloaded
				POSSMOOTHER[serverVehicleID].data = decoded
				POSSMOOTHER[serverVehicleID].executed = false
				
			else
				POSSMOOTHER[serverVehicleID].data = decoded
				POSSMOOTHER[serverVehicleID].executed = false
				
				local executed_last = POSSMOOTHER[serverVehicleID].executed_last:stop()
				if executed_last > 30 and executed_last < 80 then
					local median_array = POSSMOOTHER[serverVehicleID].median_array
					local next_index = median_array[1]
					median_array[next_index] = executed_last
					median_array[1] = next_index + 1
					if next_index == median_array[2] + 2 then
						median_array[1] = 3
					end
					
					local median = 0
					for i = 3, median_array[2] + 2 do
						median = median + median_array[i]
					end
					POSSMOOTHER[serverVehicleID].median = median / median_array[2]
					POSSMOOTHER[serverVehicleID].median_array = median_array
				end
			end
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

local function onPreRender(dt)
	-- ensuring that there is atleast a difference of 37ms between each pos packet execution
	for serverVehicleID, data in pairs(POSSMOOTHER) do
		local timedif = data.executed_last:stop()
		if not data.executed and timedif >= data.median then
			applyPos(data.data, serverVehicleID)
			POSSMOOTHER[serverVehicleID].executed_last = TIMER()
			POSSMOOTHER[serverVehicleID].executed = true
			
		elseif timedif > 60000 then -- vehicle potentially removed. rem entry
			POSSMOOTHER[serverVehicleID] = nil
		end
	end
end

local function onSettingsChanged()
	if not settings.getValue("enablePosSmoother") then -- nil/false
		POSSMOOTHER = {}
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
M.debug             = POSSMOOTHER
M.onInit = function() setExtensionUnloadMode(M, "manual") end

return M
