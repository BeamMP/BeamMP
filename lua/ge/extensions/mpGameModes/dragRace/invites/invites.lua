local ui = require('ge/extensions/mpGameModes/dragRace/ui/ui')

local function sendInviteMessage(json)
    ui.hideDragRaceDialog()
    TriggerServerEvent('SendInvite', json:gsub(":","&"))
end

local function acceptInvite(data)
    ui.hideMessage()

    local parsed = jsonDecode(data)
    local json = {
        id1 = parsed.player1.id,
        id2 = parsed.player2.id,
    }
    TriggerServerEvent('RequestMPStart', jsonEncode(json):gsub(":","&"))
end

local function rejectInvite(_)
    ui.hideMessage()
end

return {
    send = sendInviteMessage,
    accept = acceptInvite,
    reject = rejectInvite,
}
