require('ge/extensions/mpGameModes/dragRace/models/server_contract')

local ui = require('ge/extensions/mpGameModes/dragRace/ui/ui')

local raceTimer = 0

local lastUpdatedState
local timeSinceLastServerUpdate = 0

local function raceStartTrigger(data)
    if data.triggerName ~= 'dragTrigger' then return end

    local vid = be:getPlayerVehicle(0):getID()
    if data.event == 'enter' and data.subjectID == vid and MPVehicleGE.isOwn(vid) then
        ui.showDragRaceStartPopup()
    elseif data.event == 'exit' then
        ui.hideMessage()
    end
end

local function handleMyRace(playerState, data)
    if playerState.status == PlayerStatus.prestaging then
        if data.triggerName == 'startTrigger_LR' then
            TriggerServerEvent('RequestPrestageReady', 'null')
            -- a bit awkward cuz we handle ui from physics, but
            -- that's the best simplest solution i see
            guihooks.trigger(
                    'MPDragRaceShowCountdownDigit',
                    lastUpdatedState.counters.countdownCounter
            )
        end
    elseif playerState.status == PlayerStatus.ready then
        if data.triggerName == 'laneTrigger_R' or data.triggerName == 'laneTrigger_L' then
            TriggerServerEvent('RequestDSQ', 'jumpstart')
        end
    elseif playerState.status == PlayerStatus.racing then
        if data.triggerName == 'endTrigger' then
            local curVeh = extensions.core_vehicles.getCurrentVehicleDetails().model
            local results = jsonEncode({
                time = raceTimer,
                maxSpeed = be:getPlayerVehicle(0):getVelocity():len() * 2.2369362920544,
                vehicleName = curVeh.Brand..' '..curVeh.Name,
            })
            TriggerServerEvent('RequestCrossedFinishLine', results:gsub(":","&"))
        end
    end
end

local function onBeamNGTrigger(data)
    if not lastUpdatedState then return end

    if lastUpdatedState.raceType == RaceType.none then
        raceStartTrigger(data)
        return
    end

    local myId = MPConfig.getPlayerServerID()
    if myId == lastUpdatedState.player1State.id then
        handleMyRace(lastUpdatedState.player1State, data)
    elseif myId == lastUpdatedState.player2State.id then
        handleMyRace(lastUpdatedState.player2State, data)
    end
end

local function onPreRender(dtReal, _, _)
    timeSinceLastServerUpdate = timeSinceLastServerUpdate + dtReal

    if timeSinceLastServerUpdate > 5 then
        TriggerServerEvent('RequestState', 'null')
        timeSinceLastServerUpdate = 0
    end

    if lastUpdatedState then
        local myId = MPConfig.getPlayerServerID()
        local p1s = lastUpdatedState.player1State
        local p2s = lastUpdatedState.player2State

        if (myId == p1s.id and p1s.status == PlayerStatus.racing) or
                (myId == p2s.id and p2s.status == PlayerStatus.racing) then
            raceTimer = raceTimer + dtReal
        else
            raceTimer = 0
        end
    end
end

local function updateActions()
    if lastUpdatedState.raceType == RaceType.none then
        extensions.core_input_actionFilter.clear(0)
    else
        local myId = MPConfig.getPlayerServerID()
        local p1s = lastUpdatedState.player1State
        local p2s = lastUpdatedState.player2State

        if myId == p1s.id or myId == p2s.id then
            local CONSTANTS = require('ge/extensions/mpGameModes/dragRace/util/constants')
            for _, action in ipairs( CONSTANTS.BLACKLIST_ACTIONS ) do
                extensions.core_input_actionFilter.addAction(0, action, true)
            end
        end
    end
end

local function sync(state)
    lastUpdatedState = state
    timeSinceLastServerUpdate = 0
    updateActions()
end

return {
    onPreRender = onPreRender,
    onBeamNGTrigger = onBeamNGTrigger,
    sync = sync,
}
