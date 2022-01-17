require('ge/extensions/mpGameModes/dragRace/models/server_contract')

local function raceTypeFromJson(json)
    if json == 'SP' then
        return RaceType.SP
    elseif json == 'MP' then
        return RaceType.MP
    elseif json == 'none' then
        return RaceType.none
    end
end

local function playerStatusFromJson(json)
    if json == 'prestaging' then
        return PlayerStatus.prestaging
    elseif json == 'ready' then
        return PlayerStatus.ready
    elseif json == 'racing' then
        return PlayerStatus.racing
    elseif json == 'disqualified' then
        return PlayerStatus.disqualified
    elseif json == 'none' then
        return PlayerStatus.none
    end
end

local function stateFromParsedJson(json)
    return {
        raceType = raceTypeFromJson(json.raceType),
        player1State = {
            id = json.player1State.id,
            status = playerStatusFromJson(json.player1State.status),
            result = json.player1State.result,
        },
        player2State = {
            id = json.player2State.id,
            status = playerStatusFromJson(json.player2State.status),
            result = json.player2State.result,
        },
        counters = json.counters,
    }
end

return {
    stateFromParsedJson = stateFromParsedJson,
}
