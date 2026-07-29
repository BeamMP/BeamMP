-- Copyright (C) 2024 BeamMP Ltd., BeamMP team and contributors.
-- Licensed under AGPL-3.0 (or later), see <https://www.gnu.org/licenses/>.
-- SPDX-License-Identifier: AGPL-3.0-or-later

local M = {}

local loadedFunctions = false

-- Custom functions

-- hamster_wheel

local hamster_wheelController = controller.getController("hamster_wheel")

local function sendTargetRPMRatioHamster(controllerName, funcName, tempTable, ...)
    controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
    if hamster_wheelController and type(hamster_wheelController.engineInfo[6]) == "string" then
        tempTable.TargetRPMRatio = tonumber(hamster_wheelController.engineInfo[6]:match("-?[%d%.]+")) / 100
    end
    controllerSyncVE.sendControllerData(tempTable)
end

local function receiveTargetRPMRatioHamster(data)
    local input = data.variables[1]
    if data.TargetRPMRatio and controllerSyncVE.OGcontrollerFunctionsTable[data.controllerName]["setTargetRPMRatio"] then
        controllerSyncVE.OGcontrollerFunctionsTable[data.controllerName]["setTargetRPMRatio"](data.TargetRPMRatio)
    end

    controllerSyncVE.OGcontrollerFunctionsTable[data.controllerName][data.functionName](input)
end

-- spinner

local spinnerController = controller.getController("spinner")

local targetRPMRatio = 0
local targetRPMRatioIncrease = 0
local targetRPMRatioDecrease = 0
local updateTargetRPMRatio = nop

local function updateTargetRPMRatioFunc(dt)
    local currentTargetRPMRatio = tonumber(spinnerController.engineInfo[6]:match("-?[%d%.]+")) / 100
    local RPMRatioError = targetRPMRatio - currentTargetRPMRatio
    if targetRPMRatioIncrease ~= 0 or targetRPMRatioDecrease ~= 0 then
        controllerSyncVE.OGcontrollerFunctionsTable["spinner"]["setTargetRPMRatioIncrease"](targetRPMRatioIncrease)
        controllerSyncVE.OGcontrollerFunctionsTable["spinner"]["setTargetRPMRatioDecrease"](targetRPMRatioDecrease)
    elseif math.abs(RPMRatioError) > 0.001 then
        if RPMRatioError < 0 then
            controllerSyncVE.OGcontrollerFunctionsTable["spinner"]["setTargetRPMRatioIncrease"](0)
            controllerSyncVE.OGcontrollerFunctionsTable["spinner"]["setTargetRPMRatioDecrease"](math.abs(RPMRatioError)*10)
        else
            controllerSyncVE.OGcontrollerFunctionsTable["spinner"]["setTargetRPMRatioIncrease"](math.abs(RPMRatioError)*10)
            controllerSyncVE.OGcontrollerFunctionsTable["spinner"]["setTargetRPMRatioDecrease"](0)
        end
    else
        controllerSyncVE.OGcontrollerFunctionsTable["spinner"]["setTargetRPMRatioIncrease"](0)
        controllerSyncVE.OGcontrollerFunctionsTable["spinner"]["setTargetRPMRatioDecrease"](0)
        updateTargetRPMRatio = nop
    end
end

local function resetTargetRPMRatio()
    targetRPMRatio = 0
    targetRPMRatioIncrease = 0
    targetRPMRatioDecrease = 0
    controllerSyncVE.OGcontrollerFunctionsTable["spinner"]["setTargetRPMRatioIncrease"](0)
    controllerSyncVE.OGcontrollerFunctionsTable["spinner"]["setTargetRPMRatioDecrease"](0)
end

local function sendTargetRPMRatio(controllerName, funcName, tempTable, ...)
    controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
    if spinnerController then
        tempTable.TargetRPMRatio = tonumber(spinnerController.engineInfo[6]:match("-?[%d%.]+")) / 100
        controllerSyncVE.sendControllerData(tempTable)
    end
end

local function receiveTargetRPMRatio(data)
    local targetRPMRatioIncreaseInput = data.variables[1] or 0
    if data.functionName == "setTargetRPMRatioIncrease" then
        targetRPMRatioIncrease = targetRPMRatioIncreaseInput
    else
        targetRPMRatioDecrease = targetRPMRatioIncreaseInput
    end
    controllerSyncVE.OGcontrollerFunctionsTable[data.controllerName][data.functionName](targetRPMRatioIncreaseInput)

    if data.TargetRPMRatio and spinnerController and type(spinnerController.engineInfo[6]) == "string" then
        targetRPMRatio = data.TargetRPMRatio
        updateTargetRPMRatio = updateTargetRPMRatioFunc
    end
end

if spinnerController then
    updateTargetRPMRatio = updateTargetRPMRatioFunc
else
    resetTargetRPMRatio = nop
end

-- large Cannon

local cannonController = controller.getController("large_cannon")

local targetShootStrength = 1
local currentShootInput = 0
local updateStrength = nop

local function updateStrengthFunc(dt)
    local currentStrength = cannonController.engineInfo[1] / 1000 -- the cannon uses the engineInfo to display current power, this means we can read the current state from it
    local strengthError = targetShootStrength - currentStrength
    if currentShootInput ~= 0 then
        controllerSyncVE.OGcontrollerFunctionsTable["large_cannon"]["shootStrengthChange"](currentShootInput)
    elseif math.abs(strengthError) > 0.0001 then
        controllerSyncVE.OGcontrollerFunctionsTable["large_cannon"]["shootStrengthChange"](strengthError*100)
    else
        controllerSyncVE.OGcontrollerFunctionsTable["large_cannon"]["shootStrengthChange"](0)
        updateStrength = nop
    end
end

local function resetStrengthInput()
    currentShootInput = 0
    controllerSyncVE.OGcontrollerFunctionsTable["large_cannon"]["shootStrengthChange"](0)
end

if cannonController then
    updateStrength = updateStrengthFunc
else
    resetStrengthInput = nop
end

local function sendStrength(controllerName, funcName, tempTable, ...)
    controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)

    if cannonController then
        tempTable.strength = cannonController.engineInfo[1] / 1000
        controllerSyncVE.sendControllerData(tempTable)
    end
end

local function receiveStrength(data)
    if data.strength then
        targetShootStrength = data.strength
        currentShootInput = data.variables[1] or 0
        controllerSyncVE.OGcontrollerFunctionsTable[data.controllerName][data.functionName](currentShootInput)
        if currentShootInput == 0 then
            updateStrength = updateStrengthFunc
        end
    end
end

--kickplate

local function changePowerLevel(controllerName, funcName, tempTable, ...)
    local powerIncrease = ...
    if powerIncrease and electrics.values.kickplatePowerLevel then
        controller.getController("kickplate").setPowerLevel(electrics.values.kickplatePowerLevel + powerIncrease)
    end
end

-- spikestrips

local function prepareID(controllerName, funcName, tempTable, ...)
	tempTable["vehID"] = ...
	controllerSyncVE.sendControllerData(tempTable)
	return controllerSyncVE.OGcontrollerFunctionsTable[controllerName][funcName](...)
end

local function receiveID(data)
    if data.vehID then
        controllerSyncVE.OGcontrollerFunctionsTable[data.controllerName][data.functionName](data.vehID)
    end
end

-- compare set to true only sends data when there is a change
-- compare set to false sends the data every time the function is called
-- adding ownerFunction and/or receiveFunction can set custom functions to read or change data before sending or on receiveing
--["controllerFunctionName"] = {
--  ownerFunction = customFunctionOnSend,
--  receiveFunction = customFunctionOnReceive
--},
-- storeState stores the incoming data and then if the remote car was reset locally for whatever reason it reapplies the state

local includedControllerTypes = {
    ["rollover"] = {
        ["cycle"] = {},
        ["prepare"] = {}
    },

    ["hamster_wheel"] = {
        ["setTargetRPMRatioIncrease"] = {
            ownerFunction = sendTargetRPMRatioHamster,
            receiveFunction = receiveTargetRPMRatioHamster
        },
        ["setTargetRPMRatioDecrease"] = {
            ownerFunction = sendTargetRPMRatioHamster,
            receiveFunction = receiveTargetRPMRatioHamster
        },
        ["setTargetRPMRatio"] = {}
    },

    ["spinner"] = {
        ["setTargetRPMRatioIncrease"] = {
            ownerFunction = sendTargetRPMRatio,
            receiveFunction = receiveTargetRPMRatio
        },
        ["setTargetRPMRatioDecrease"] = {
            ownerFunction = sendTargetRPMRatio,
            receiveFunction = receiveTargetRPMRatio
        }
    },

    ["large_roller"] = {
        ["setTargetThrottle"] = {},
        ["setRollerHeight"] = {},
        ["updateGFX"] = {
            remoteOnly = true -- electrics makes the throttle sync, However the controller overRides the electrics each frame, this is to disable that
        }
    },

    ["large_cannon"] = {
        ["fireCannon"] = {},
        ["shootStrengthChange"] = {
            ownerFunction = sendStrength,
            receiveFunction = receiveStrength
        },
        ["targetInclinationChange"] = {}
    },

    ["kickplate"] = { -- TODO finish this, only power level syncs atm
        ["setPowerLevel"] = {},
        ["changePowerLevel"] = {
			ownerFunction = changePowerLevel
        },
        ["setRandomDirection"] = {},
        ["setPlateDirection"] = {}
    },

    ["spikestripRemoteScissor"] = {
        ["setOperationMode"] = {},
        ["toggleOperationMode"] = {},
        ["setTargetSelectionMode"] = {},
        ["setManualTargetId"] = {
			ownerFunction = prepareID,
			receiveFunction = receiveID,
        },
        ["setManualExtension"] = {},
        ["toggleManualExtension"] = {}
    },

    ["spikestripRemoteStick"] = {
        ["setOperationMode"] = {},
        ["toggleOperationMode"] = {},
        ["toggleArmed"] = {},
        ["setTargetSelectionMode"] = {},
        ["setManualTargetId"] = {
			ownerFunction = prepareID,
			receiveFunction = receiveID,
        },
        ["manualLaunch"] = {},
        ["manualRetract"] = {}
    },

    ["roofCrusherTester"] = {
        ["moveManually"] = {},
        ["toggleState"] = {}
    },

    ["testRoller"] = {
        ["changeRampAngle"] = {} -- TODO exclude ramp_angle electrics from electrics sync and sync it manually here, the hydros are so fast it causes shaking when using electrics sync
    },
}

local function updateGFX(dt)
    if not loadedFunctions then return end
    if v.mpVehicleType == 'R' then
        updateTargetRPMRatio(dt)
        updateStrength(dt)
    end
end

local function onReset()
    if not loadedFunctions then return end
    if v.mpVehicleType == 'R' then
        resetStrengthInput()
        resetTargetRPMRatio()
    end
end

local function loadFunctions()
    if controllerSyncVE ~= nil then
        controllerSyncVE.addControllerTypes(includedControllerTypes)
        loadedFunctions = true
    else
        dump("controllerSyncVE not found")
    end
end

M.onBeamMPLoadControllerSyncFunctions = loadFunctions
M.onReset = onReset
M.updateGFX = updateGFX

return M
