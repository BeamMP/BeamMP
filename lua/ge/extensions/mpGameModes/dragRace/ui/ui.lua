require('ge/extensions/mpGameModes/dragRace/models/server_contract')

local function addMessage(message)
    guihooks.trigger('MPMessageUpdate', message)
end

local function showDragRaceStartPopup()
    addMessage(jsonEncode({
        visible = true,
        header = 'DragRace minigame',
        messages = {
            'You can race alone or invite a friend for a competition',
            'We also have a leaderboard for each vehicle class!'
        },
        buttons = {
            {
                icon = 'play_arrow',
                text = 'Multiplayer',
                action = 'mpGameModes_dragRace_dragRace.showMPDialog()'
            },
            {
                icon = 'play_arrow',
                text = 'Singleplayer',
                action = 'mpGameModes_dragRace_dragRace.showSPDialog()'
            },
        }
    }))
end

local function hideMessage()
    addMessage(jsonEncode({
        visible = false
    }))
end

local function showSPDragRaceDialog()
    hideMessage()

    local curVeh = extensions.core_vehicles.getCurrentVehicleDetails().model
    local vehName = curVeh.Brand..' '..curVeh.Name

    guihooks.trigger('MenuHide', false)
    guihooks.trigger('ChangeState',
            {
                state = "menu.spDragraceDialog",
                params = {
                    data = {
                        currentVehicle = vehName,
                    }
                }
            }
    )
end

local function showMPDragRaceDialog()
    hideMessage()

    local function getOtherVehiclesMap()
        local others = {}
        for localVehId, username in pairs( MPVehicleGE.getNicknameMap() ) do
            if not MPVehicleGE.isOwn(localVehId) then
                local _, playerId = MPVehicleGE.getPlayerByName(username)
                local model = core_vehicles.getVehicleDetails(localVehId).model
                table.insert(others, {
                    id = playerId,
                    username = username,
                    vehicle = {
                        id = MPVehicleGE.getServerVehicleID(localVehId),
                        name = model.Brand..' '.. model.Name,
                    }
                })
            end
        end

        local curVeh = extensions.core_vehicles.getCurrentVehicleDetails().model
        local vehName = curVeh.Brand..' '..curVeh.Name

        return {
            self = {
                id = MPConfig.getPlayerServerID(),
                username = MPConfig.getNickname(),
                vehicle = {
                    id = MPVehicleGE.getServerVehicleID(be:getPlayerVehicle(0):getID()),
                    name = vehName,
                },
            },
            playerList = others,
        }
    end

    guihooks.trigger('MenuHide', false)
    guihooks.trigger('ChangeState',
            {
                state = "menu.mpDragraceDialog",
                params = {
                    playerList = getOtherVehiclesMap()
                }
            }
    )
end

local function hideDragRaceDialog()
    hideMessage()
    guihooks.trigger('ChangeState', 'menu')
    guihooks.trigger('MenuHide', true)
    guihooks.trigger('ShowApps', true)
end

local function sync(state)
    local raceActive = state.raceType ~= RaceType.none

    local myId = MPConfig.getPlayerServerID()
    if myId == state.player1State.id then
        if state.player1State.status == PlayerStatus.prestaging and raceActive then
            guihooks.trigger('MPDragRaceShowMoveToStartHint', true)
        elseif state.player1State.status == PlayerStatus.ready and raceActive then
            guihooks.trigger(
                    'MPDragRaceShowCountdownDigit',
                    state.counters.countdownCounter
            )
        elseif state.player1State.status == PlayerStatus.disqualified then
            guihooks.trigger('MPDragRaceShowMoveToStartHint', false)
        end
    elseif myId == state.player2State.id then
        if state.player2State.status == PlayerStatus.prestaging and raceActive then
            guihooks.trigger('MPDragRaceShowMoveToStartHint', true)
        elseif state.player2State.status == PlayerStatus.ready and raceActive then
            guihooks.trigger(
                    'MPDragRaceShowCountdownDigit',
                    state.counters.countdownCounter
            )
        elseif state.player2State.status == PlayerStatus.disqualified then
            guihooks.trigger('MPDragRaceShowMoveToStartHint', false)
        end
    end
end

return {
    uiMessage = addMessage,
    showDragRaceStartPopup = showDragRaceStartPopup,
    hideMessage = hideMessage,
    showSPDragRaceDialog = showSPDragRaceDialog,
    showMPDragRaceDialog = showMPDragRaceDialog,
    hideDragRaceDialog = hideDragRaceDialog,
    sync = sync,
}
