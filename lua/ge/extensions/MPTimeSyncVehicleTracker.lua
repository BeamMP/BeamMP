local M = {}

local abs = math.abs
local min = math.min
local max = math.max

-- the only reason this lua is necessary is because as far as i can tell there is not way to get the current sim time in GE, if there is one we can remove all this and just replace it with that function

local lastDTSim = 0
local lastVeSimTime = 0
local veSimTime = 0

local foundCarLastFrame
local framesSinceNewCar = 0
local noVECounter = 0

local simTimeVehID -- this is the vehicleID of the vehicle i use to send the accurate simulation Time to GE, dtSim in GE seems to drift at low frame rates

local function checkTrackingVehicle(dtSim, dtRaw) --TODO make sure this doesn't continuously retry if all vehicles fail, maybe it can be done from events only?
	if dtSim ~= 0 and lastDTSim ~= 0 and lastVeSimTime == veSimTime then
		local vehCount = be:getObjectCount()--noVECounter
		if foundCarLastFrame or framesSinceNewCar < 5 then
			foundCarLastFrame = false
			framesSinceNewCar = framesSinceNewCar + 1
		else
			if vehCount > 0 then
				local lastSimTimeVehID = simTimeVehID
	   			local newVeh = be:getObject(min(vehCount,noVECounter))
				if newVeh and newVeh:getActive() then
					simTimeVehID = newVeh:getID()
				--	dump("found new car" , simTimeVehID,be:getObjectCount())
					foundCarLastFrame = true
					if getVehicleByGameID(simTimeVehID) then
						newVeh:queueLuaCommand("if MPTimeSyncVE then MPTimeSyncVE.isSimTimeTracker = true end")
						if lastSimTimeVehID and lastSimTimeVehID ~= simTimeVehID then
							local oldVeh = be:getObjectByID(lastSimTimeVehID)
							if oldVeh then
								oldVeh:queueLuaCommand("if MPTimeSyncVE then MPTimeSyncVE.isSimTimeTracker = false end")
							end
						end
					end
				end
				framesSinceNewCar = 0
				noVECounter = noVECounter + 1
				if noVECounter > vehCount then
					noVECounter = 0
				end
			end
		end
		veSimTime = veSimTime + dtSim
	else
		noVECounter = 0
	end
    lastDTSim = dtSim
    lastVeSimTime = veSimTime
    return veSimTime - dtRaw
end

local function setSimTime(recSimTime,veCPUTime,objectID)
	if objectID and objectID == simTimeVehID and recSimTime then
		veSimTime = recSimTime
	end

	if objectID ~= simTimeVehID then
		if abs(recSimTime - veSimTime) > 1 then
			dump("wrong time wrong car",objectID,abs(recSimTime - veSimTime))
		end
	else
		if abs(recSimTime - veSimTime) > 1 then
			dump("wrong time correct car",objectID,abs(recSimTime - veSimTime))
		end
	end

	if not foundCarLastFrame and objectID and simTimeVehID ~= objectID then
		dump("received time from the wrong vehicle")
		dump("veSimTime   ",recSimTime)
		dump("objectID    ",objectID)
		local veh = be:getObjectByID(objectID)
		if veh then
			veh:queueLuaCommand("if positionVE then positionVE.isSimTimeTracker = false end")
		end
	elseif not recSimTime then
		dump("received time from the wrong vehicle and the time was nil")
		dump("objectID    ",objectID)
	end
end

local function onBeamMPVehicleReady(vehID,MPveh,vehOBJ)
	if getVehicleByGameID(vehID) then
		local veh = getObjectByID(vehID)
		if veh then
			if MPTimeSync.hasReceivedPing then
				veh:queueLuaCommand("if MPTimeSyncVE then MPTimeSyncVE.useTimeSync = true end")
			end
			if simTimeVehID == vehID then
				veh:queueLuaCommand("if MPTimeSyncVE then MPTimeSyncVE.isSimTimeTracker = true end")
			end
		end
	end
	--if next(MPVehicleGE.getOwnMap()) == nil then
	--	tempShiftTime = spectateTimeShift
	--else
	--	tempShiftTime = 0
	--end
	--if tempShiftTime ~= lastTempShiftTime then
	--	if tempShiftTime == 0 then
	--		guihooks.message("Spectator mode disable, prediction is now enabled", 3, "serverSimSyncOffsetChanged" , "notification")
	--	else
	--		guihooks.message("Spectator mode enabled, time shifted by "..(tempShiftTime*1000).." ms", 3, "serverSimSyncOffsetChanged" , "notification")
	--	end
	--end
	--lastTempShiftTime = tempShiftTime
end

local function onVehicleDestroyed(vehID)
	if vehID == simTimeVehID then
		simTimeVehID = nil
	end

--	local ownVehicles = MPVehicleGE.getOwnMap()

--	if next(ownVehicles) == nil then
--		--tempShiftTime = spectateTimeShift
--	else
--		local hasVeh = false
--		for vID ,_ in pairs(ownVehicles) do
--			if vID ~= vehID then
--				hasVeh = true
--				break
--			end
--		end
--		--tempShiftTime = hasVeh and 0 or spectateTimeShift
--	end
--	--dump("timeshift set to",tempShiftTime)
--	if tempShiftTime ~= lastTempShiftTime then
--		if tempShiftTime == 0 then
--			guihooks.message("Spectator mode disable, prediction is now enabled", 3, "serverSimSyncOffsetChanged" , "notification")
--		else
--			guihooks.message("Spectator mode enabled, time shifted by "..(tempShiftTime*1000).." ms", 3, "serverSimSyncOffsetChanged" , "notification")
--		end
--	end
--	lastTempShiftTime = tempShiftTime
end

M.checkTrackingVehicle = checkTrackingVehicle
M.onBeamMPVehicleReady = onBeamMPVehicleReady
M.onVehicleDestroyed   = onVehicleDestroyed
M.setSimTime           = setSimTime

return M