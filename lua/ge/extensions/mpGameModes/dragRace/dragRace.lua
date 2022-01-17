local ui = require('ge/extensions/mpGameModes/dragRace/ui/ui')
local env = require('ge/extensions/mpGameModes/dragRace/world/env')
local callbacks = require('ge/extensions/mpGameModes/dragRace/world/callbacks')
local stateVerification = require('ge/extensions/mpGameModes/dragRace/util/data_integrity')
local parser = require('ge/extensions/mpGameModes/dragRace/models/parser')
local invites = require('ge/extensions/mpGameModes/dragRace/invites/invites')

local currentServerState = nil

local function startSP()
    ui.hideDragRaceDialog()
    TriggerServerEvent('RequestSPStart', 'null')
end

local function syncState(state)
    local inner = parser.stateFromParsedJson(jsonDecode(state))
    if not stateVerification.verifyState(inner) then return end

    currentServerState = inner
    callbacks.sync(currentServerState)
    env.sync(currentServerState)
    ui.sync(currentServerState)
end

return {
    onPreRender = callbacks.onPreRender,
    onBeamNGTrigger = callbacks.onBeamNGTrigger,
    showSPDialog = ui.showSPDragRaceDialog,
    showMPDialog = ui.showMPDragRaceDialog,
    startSP = startSP,
    sendInvite = invites.send,
    acceptInvite = invites.accept,
    rejectInvite = invites.reject,
    syncState = syncState,
    uiMessage = ui.uiMessage,
}
