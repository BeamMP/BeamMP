--- sanity checks for state coming from the server (just in case)

local function checkPlayerState(playerState)
    return      playerState.id ~= nil
            and playerState.status ~= nil
            and playerState.result ~= nil
end

local function checkCounters(countersState)
    return      countersState.prestageCounter  ~= nil
            and countersState.countdownCounter ~= nil
            and countersState.raceCounter      ~= nil
end

local function checkStateDataIntegrity(state)
    return      state.raceType ~= nil
            and checkPlayerState(state.player1State)
            and checkPlayerState(state.player2State)
            and checkCounters(state.counters)
end

return {
    verifyState = checkStateDataIntegrity,
}
