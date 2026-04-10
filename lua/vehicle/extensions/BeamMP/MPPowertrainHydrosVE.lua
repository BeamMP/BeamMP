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

local hydroBeamsRecState = {}
local hydroBeamsRecChanged = {}

local function applyHydroBeams(data)
    local hydros = jsonDecode(data)
    for tagName, beamLength in pairs(hydros) do
        if hydroBeams[tagName] then
            hydroBeamsRecState[tagName] = beamLength
            hydroBeamsRecChanged[tagName] = 0
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
            local currentBeamRestLength = obj:getBeamLength(bcid)
            local diff = (targetBeamRestLength - currentBeamRestLength)
            if abs(diff) > 0.001 or time < 2 then -- TODO find a better way to do calculate force and speed, this seems to work on the WL-40, but arm tilt is really slow, input sync masks this so it's only a problem when resyncing from a spawn, but it's possible it can also use to much force and break beams
                hydroBeamsRecChanged[tagName] = hydroBeamsRecChanged[tagName] + dt
                local device = hydroBeamsData[tagName]
                local force = max(-device.minimumDragCoef/15,min(device.minimumDragCoef/15,((device.minimumDragCoef/20)*dt*2000*diff)))
                obj:actuateBeam(bcid, force, device.maxSpeed*dt*2000, 0, 0, 0, device.minExtend, device.maxExtend, device.virtualMass, device.virtualMass)
            else
                hydroBeamsRecChanged[tagName] = nil
            end
        end
    end
end

local function onReset()
    hydroBeamsRecChanged = {}
    hydroBeamsRecState = {}
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
