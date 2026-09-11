-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later
local M = {}

local abs = math.abs
local min = math.min
local max = math.max

local hydroBeams = {}
local hydroBeamsData = {}
local hydroBeamsElectricsNames = {}
local lastHydroBeamsElectricsValues = {}

local hydroBeamsChanged = {}
local lastHydroBeamsPositions = {}

local function getHydroBeams()
    for tagName, electricsName in pairs(hydroBeamsElectricsNames) do
        if electrics.values[electricsName] ~= lastHydroBeamsElectricsValues[electricsName] then
            hydroBeamsChanged[tagName] = true
        end
    end

    local foundChangedBeams = false
    local hydroBeamsToSend = {}
    for tagName, _ in pairs(hydroBeamsChanged) do
        local bcid = hydroBeams[tagName]
        local beamLength = obj:getBeamRestLength(bcid)
        if lastHydroBeamsPositions[tagName] ~= beamLength then
            lastHydroBeamsPositions[tagName] = beamLength
            hydroBeamsToSend[tagName] = beamLength
            foundChangedBeams = true
        else
            hydroBeamsChanged[tagName] = nil
        end
    end
    if foundChangedBeams then
	    obj:queueGameEngineLua("MPPowertrainGE.sendHydroBeamData(\'"..jsonEncode(hydroBeamsToSend).."\', "..obj:getID()..")")
    end

    for _, electricsName in pairs(hydroBeamsElectricsNames) do
        lastHydroBeamsElectricsValues[electricsName] = electrics.values[electricsName] -- some hydros use the same electric, so last values are updated in a separate loop so all hydro changes gets registered
    end
end

local hydroBeamsSmoothers = {}
local hydroBeamsLastState = {}
local hydroBeamsRecState = {}
local hydroBeamsRecChanged = {}

local function applyHydroBeams(data)
    local hydros = jsonDecode(data)
    for tagName, beamLength in pairs(hydros) do
        if hydroBeams[tagName] then
            hydroBeamsRecState[tagName] = beamLength
            hydroBeamsRecChanged[tagName] = 0
            hydroBeamsLastState[tagName] = obj:getBeamLength(hydroBeams[tagName])
        end
    end
end

local hasHydroPowertrain = false
local tickEnabled = false

local function updateGFX(dt)
    if hasHydroPowertrain and not tickEnabled then
        tickEnabled = true
        MPPowertrainVE.setHasHydraulicCylinders()
    end
	if v.mpVehicleType == 'R' then
        for tagName, time in pairs(hydroBeamsRecChanged) do
            local targetBeamRestLength = hydroBeamsRecState[tagName]
            local bcid = hydroBeams[tagName]
            local currentBeamLength = obj:getBeamLength(bcid)
            local diff = (targetBeamRestLength - currentBeamLength)
            if abs(diff) > 0.001 then
                local maxSpeed = hydroBeamsData[tagName].maxSpeed or 0.5
                local smoother = hydroBeamsSmoothers[tagName]
                local maxSpeedSmooth = smoother:get(1,dt)
                local speedLimit = min(0.003,maxSpeed*dt)*maxSpeedSmooth
                obj:setBeamLength(bcid, currentBeamLength + min(speedLimit,max(-speedLimit,diff*100*dt)))
            else
                hydroBeamsRecChanged[tagName] = nil
                hydroBeamsSmoothers[tagName]:reset()
            end
        end
    end
end

local function onReset()
    hydroBeamsRecChanged = {}
    hydroBeamsRecState = {}
    for id, smoother in pairs(hydroBeamsSmoothers) do
        smoother:reset()
    end
end

local function onExtensionLoaded()
    if not v.data.powertrainHydros then return end
    for _, hydro in pairs(v.data.powertrainHydros) do
        if hydro.beamTags then
            for _, tagName in pairs(hydro.beamTags) do -- for each beamTag
                for _, beam in pairs(v.data.beams) do -- look for beam with this tag
                    if beam.tag and beam.tag == tagName then
                        hydroBeams[tagName] = beam.cid
                        hydroBeamsElectricsNames[tagName] = hydro.directionElectricsName
                        lastHydroBeamsElectricsValues[hydro.directionElectricsName] = 0
                        hydroBeamsSmoothers[tagName] = newTemporalSmoothing(5,1)
                        hydroBeamsData[tagName] = hydro
                    end
                end
            end
        end
    end
    hasHydroPowertrain = true
end

M.getHydroBeams     = getHydroBeams
M.applyHydroBeams   = applyHydroBeams

M.updateGFX         = updateGFX
M.onReset           = onReset
M.onExtensionLoaded = onExtensionLoaded

return M
