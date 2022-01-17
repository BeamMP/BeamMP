require('ge/extensions/mpGameModes/dragRace/models/server_contract')

local timeDigitsLeft
local timeDigitsRight
local speedDigitsLeft
local speedDigitsRight

local lights

local function initDisplay()
    if timeDigitsRight == nil or speedDigitsRight == nil then
        timeDigitsRight = {}
        speedDigitsRight = {}
        for i=1, 5 do
            table.insert(timeDigitsRight, scenetree.findObject("display_time_" .. i .. "_r"))
            table.insert(speedDigitsRight, scenetree.findObject("display_speed_" .. i .. "_r"))
        end
    end

    if timeDigitsLeft == nil or speedDigitsLeft == nil then
        timeDigitsLeft = {}
        speedDigitsLeft = {}
        for i=1, 5 do
            table.insert(timeDigitsLeft, scenetree.findObject("display_time_" .. i .. "_l"))
            table.insert(speedDigitsLeft, scenetree.findObject("display_speed_" .. i .. "_l"))
        end
    end
end

local function clearDisplays()
    initDisplay()

    local function clear(digits)
        for i=1, #digits do
            digits[i]:setHidden(true)
        end
    end

    clear(timeDigitsRight)
    clear(timeDigitsLeft)
    clear(speedDigitsRight)
    clear(speedDigitsLeft)
end

local function applyTime(timeDigits, timeDisplayValue)
    if #timeDisplayValue > 0 and #timeDisplayValue < 6 then
        for i,v in ipairs(timeDisplayValue) do
            timeDigits[i]:preApply()
            timeDigits[i]:setField('shapeName', 0, "art/shapes/quarter_mile_display/display_".. v ..".dae")
            timeDigits[i]:setHidden(false)
            timeDigits[i]:postApply()
        end
    end
end

local function applySpeed(speedDigits, speedDisplayValue)
    for i,v in ipairs(speedDisplayValue) do
        speedDigits[i]:preApply()
        speedDigits[i]:setField('shapeName', 0, "art/shapes/quarter_mile_display/display_".. v ..".dae")
        speedDigits[i]:setHidden(false)
        speedDigits[i]:postApply()
    end
end

local function updateDisplay(side, finishTime, finishSpeed)
    local timeDisplayValue = {}
    local speedDisplayValue = {}

    if finishTime < 10 then
        table.insert(timeDisplayValue, "empty")
    end

    if finishSpeed < 100 then
        table.insert(speedDisplayValue, "empty")
    end

    for num in string.gmatch(string.format("%.3f", finishTime), "%d") do
        table.insert(timeDisplayValue, num)
    end

    for num in string.gmatch(string.format("%.2f", finishSpeed), "%d") do
        table.insert(speedDisplayValue, num)
    end

    if side == 'r' then
        applyTime(timeDigitsRight, timeDisplayValue)
        applySpeed(speedDigitsRight, speedDisplayValue)
    elseif side == 'l' then
        applyTime(timeDigitsLeft, timeDisplayValue)
        applySpeed(speedDigitsLeft, speedDisplayValue)
    end
end

local function ensureLightsInit()
    if lights == nil then
        lights = {
            stageLights = {
                prestageLightL  = {obj = scenetree.findObject("Prestagelight_l"), anim = "prestage"},
                prestageLightR  = {obj = scenetree.findObject("Prestagelight_r"), anim = "prestage"},
                stageLightL     = {obj = scenetree.findObject("Stagelight_l"),    anim = "prestage"},
                stageLightR     = {obj = scenetree.findObject("Stagelight_r"),    anim = "prestage"}
            },
            countDownLights = {
                amberLight1R    = {obj = scenetree.findObject("Amberlight1_R"), anim = "tree"},
                amberLight2R    = {obj = scenetree.findObject("Amberlight2_R"), anim = "tree"},
                amberLight3R    = {obj = scenetree.findObject("Amberlight3_R"), anim = "tree"},
                amberLight1L    = {obj = scenetree.findObject("Amberlight1_L"), anim = "tree"},
                amberLight2L    = {obj = scenetree.findObject("Amberlight2_L"), anim = "tree"},
                amberLight3L    = {obj = scenetree.findObject("Amberlight3_L"), anim = "tree"},
                greenLightR     = {obj = scenetree.findObject("Greenlight_R"),  anim = "tree"},
                greenLightL     = {obj = scenetree.findObject("Greenlight_L"),  anim = "tree"},
                redLightR       = {obj = scenetree.findObject("Redlight_R"),  anim = "tree"},
                redLightL       = {obj = scenetree.findObject("Redlight_L"),  anim = "tree"}
            }
        }
    end
end

local function resetLights()
    ensureLightsInit()
    for _,group in pairs(lights) do
        for _,light in pairs(group) do
            if light.obj then
                light.obj:setHidden(true)
            end
        end
    end
end

local function activatePrestageLights(side)
    if side == 'r' then
        lights.stageLights.prestageLightR.obj:setHidden(false)
    elseif side == 'l' then
        lights.stageLights.prestageLightL.obj:setHidden(false)
    end

end

local function activateStageLights(side)
    if side == 'r' then
        lights.stageLights.stageLightR.obj:setHidden(false)
    elseif side == 'l' then
        lights.stageLights.stageLightL.obj:setHidden(false)
    end
end

local function activateCountdownLights(side, countdown)
    if side == 'r' then
        if countdown < 4 then
            lights.countDownLights.amberLight1R.obj:setHidden(false)
        end
        if countdown < 3 then
            lights.countDownLights.amberLight2R.obj:setHidden(false)
        end
        if countdown < 2 then
            lights.countDownLights.amberLight3R.obj:setHidden(false)
        end
    elseif side == 'l' then
        if countdown < 4 then
            lights.countDownLights.amberLight1L.obj:setHidden(false)
        end
        if countdown < 3 then
            lights.countDownLights.amberLight2L.obj:setHidden(false)
        end
        if countdown < 2 then
            lights.countDownLights.amberLight3L.obj:setHidden(false)
        end
    end
end

local function activateStartLights(side)
    if side == 'r' then
        lights.countDownLights.greenLightR.obj:setHidden(false)
    elseif side == 'l' then
        lights.countDownLights.greenLightL.obj:setHidden(false)
    end
end

local function activateDsqLights(side)
    if side == 'r' then
        lights.countDownLights.redLightR.obj:setHidden(false)
    elseif side == 'l' then
        lights.countDownLights.redLightL.obj:setHidden(false)
    end
end

local function sync(state)
    resetLights()
    clearDisplays()

    local status1 = state.player1State.status
    local status2 = state.player2State.status

    if status1 == PlayerStatus.prestaging then
        activatePrestageLights('r')
    elseif status1 == PlayerStatus.ready then
        activateStageLights('r')
        activateCountdownLights('r', tonumber(state.counters.countdownCounter))
    elseif status1 == PlayerStatus.racing then
        activateStartLights('r')
    elseif status1 == PlayerStatus.disqualified then
        activateDsqLights('r')
    end

    if status2 == PlayerStatus.prestaging then
        activatePrestageLights('l')
    elseif status2 == PlayerStatus.ready then
        activateStageLights('l')
        activateCountdownLights('l', tonumber(state.counters.countdownCounter))
    elseif status2 == PlayerStatus.racing then
        activateStartLights('l')
    elseif status2 == PlayerStatus.disqualified then
        activateDsqLights('l')
    end

    if state.player1State.result.time then
        updateDisplay('r',
                tonumber(state.player1State.result.time),
                tonumber(state.player1State.result.maxSpeed)
        )
    end

    if state.player2State.result.time then
        updateDisplay('l',
                tonumber(state.player2State.result.time),
                tonumber(state.player2State.result.maxSpeed)
        )
    end
end

return {
    sync = sync,
}
