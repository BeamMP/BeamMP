-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}



-- ============= VARIABLES =============
local lastDevices = {}
local lastCombustionEngineData = {}
local cachedCombustionEngineData = {}
local ignitionLevel
local lastignitionLevel
local spawnVehicleIgnitionLevel
local devices = powertrain.getDevices()
-- ============= VARIABLES =============



local function applyLivePowertrain(data)
	local decodedData = jsonDecode(data) -- Decode data
	for k, v in pairs(decodedData) do -- For each device
		if v.mode and devices[k] and devices[k].setMode then
			devices[k].setMode(devices[k],v.mode)
		end
	end
end



local function getPowerTrainData()
	local devicesToSend = {}
	for k, v in pairs(devices) do -- For each device
		if v.mode and v.setMode then -- If it's something that interests us
			local currDevice = { type = v.type, mode = v.mode, gearIndex = v.gearIndex }
			local lastDevice = lastDevices[k] or { type = "", mode = "" }
			-- If it has changed
			-- We don't send the gearbox because it's already synced into MPElectricsVE
			if currDevice.mode ~= lastDevice.mode and v.name ~= "gearbox" then
				devicesToSend[k] = currDevice -- Send it
				-- print(k.. " has changed")
			end
			lastDevices[k] = currDevice
		end
	end
	if next(devicesToSend) then
		obj:queueGameEngineLua("MPPowertrainGE.sendLivePowertrain(\'"..jsonEncode(devicesToSend).."\', "..obj:getID()..")")
		-- print("Devices "..jsonEncode(devicesToSend).." sent")
	end
end


local function getCombustionEngineData(data)
	local combustionEngines = powertrain.getDevicesByType("combustionEngine")
	if next(combustionEngines) then
		local engines = {}
		for engineName,engine in pairs(combustionEngines) do
			local lastEngineData = lastCombustionEngineData[engineName] or {}
			local engineData = {}
			if lastEngineData.ignitionCoef ~= engine.ignitionCoef or lastEngineData.isStalled ~= engine.isStalled then
				engineData.ign = engine.ignitionCoef
				engineData.isStalled = engine.isStalled
			end
			if lastEngineData.starterEngagedCoef ~= engine.starterEngagedCoef then
				engineData.starter = engine.starterEngagedCoef
			end

			lastEngineData.ignitionCoef = engine.ignitionCoef
			lastEngineData.isStalled = engine.isStalled
			lastEngineData.starterEngagedCoef = engine.starterEngagedCoef

			lastCombustionEngineData[engineName] = lastEngineData
			if next(engineData) then
				engines[engine.name] = engineData
			end
		end
		if next(engines) then
			data.ICE = engines
		end
	end
	return data
end


local function getEngineData() --TODO maybe hook the functions instead of checking with ticking
	local data = {}
	if electrics.values.ignitionLevel ~= lastignitionLevel then
		data["ignLvl"] = electrics.values.ignitionLevel
	end
	lastignitionLevel = electrics.values.ignitionLevel

	data = getCombustionEngineData(data)

	if next(data) then
		obj:queueGameEngineLua("MPPowertrainGE.sendEngineData(\'"..jsonEncode(data).."\', "..obj:getID()..")")
	end
end

local function applyEngineData(data)
	data = jsonDecode(data)
	if data.ignLvl then
		ignitionLevel = data.ignLvl
	end
	if data.ICE then
		for engineName,engineData in pairs(data.ICE) do
			local receivedEngineData = cachedCombustionEngineData[engineName] or {}
			if engineData.ign ~= nil then
				receivedEngineData.ignitionCoef = engineData.ign
			end
			if engineData.starter ~= nil then
				receivedEngineData.starterEngagedCoef = engineData.starter
			end
			if engineData.isStalled ~= nil then
				receivedEngineData.isStalled = engineData.isStalled
			end
			cachedCombustionEngineData[engineName] = receivedEngineData
		end
	end
end

local periodicSynctime = 0

local function updateGFX(dt)
	if v.mpVehicleType == "R" then
		if ignitionLevel and electrics.values.ignitionLevel ~= ignitionLevel then
			electrics.setIgnitionLevel(ignitionLevel)
		end
		for engineName,engineData in pairs(cachedCombustionEngineData) do
			local engine = powertrain.getDevice(engineName)
			if engine then
				if engineData.ignitionCoef ~= engine.ignitionCoef then
					engine:setIgnition(engineData.ignitionCoef)
				end
				if engine.starterEngagedCoef == 0 then
					if engineData.starterEngagedCoef == 1 or not engineData.isStalled and engine.isStalled and engineData.ignitionCoef == 1 then
						engine:activateStarter()
					end
				end
				if engineData.isStalled and not engine.isStalled and engineData.starterEngagedCoef == 0 then
					engine:cutIgnition(1)
					if engine.starterEngagedCoef == 1 then
						engine:deactivateStarter()
					end
				end
			end
		end
	else
		periodicSynctime = periodicSynctime + dt
		if periodicSynctime >= 10 then
			periodicSynctime = 0
			lastignitionLevel = nil
			for _ , engineData in pairs(lastCombustionEngineData) do
				engineData.ignitionCoef = nil
				engineData.isStalled = nil
			end
		end
	end
end

local function cacheEngines()
	local combustionEngines = powertrain.getDevicesByType("combustionEngine")
	if next(combustionEngines) then
		for engineName,engine in pairs(combustionEngines) do
			engine.spawnVehicleIgnitionLevel = spawnVehicleIgnitionLevel or engine.spawnVehicleIgnitionLevel
			local receivedEngineData = cachedCombustionEngineData[engineName] or {}
			receivedEngineData.ignitionCoef = 1
			receivedEngineData.isStalled = false
			receivedEngineData.starterEngagedCoef = engine.starterEngagedCoef
			cachedCombustionEngineData[engine.name] = receivedEngineData
		end
	end
end

local function setIgnitionState(remoteignitionLevel)
	spawnVehicleIgnitionLevel = remoteignitionLevel
	cacheEngines()
end

local function onExtensionLoaded()
	cacheEngines()
end

local function check()
	getPowerTrainData()
	getEngineData()
end

M.check				  = check
M.applyLivePowertrain = applyLivePowertrain

M.getEngineData = getEngineData
M.applyEngineData = applyEngineData
M.setIgnitionState = setIgnitionState
M.updateGFX = updateGFX
M.onExtensionLoaded = onExtensionLoaded



return M
