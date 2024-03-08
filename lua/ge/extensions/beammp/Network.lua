
-- VERY WIP of new protocol, does not actually load or work

local M = {}

local socket = require('socket')
local ffi = require("ffi")
local launcherSocket = nil


local state = {
    stateless = 0,
    identification = 1,
    login = 2,
    quickJoin = 3,
    browsing = 4,
    serverIdentification = 6,
    serverAuthentication = 5,
    serverModDownload = 7,
    modLoading = "TODO",
    mapLoading = "TODO",
    serverSessionSetup = 8,
    serverPlaying = 9,
    serverLeaving = 10,
}

local packetType = {
    --ClientIdentification
    GameInfo            = 0x0001,
    LauncherInfo        = 0x0002,
    Error               = 0x0003,

    --Login
    AskForCredentials   = 0x0004,
    Credentials         = 0x0005,
    LoginResult         = 0x0006,

    --QuickJoin
    DoJoin              = 0x0007,
    JoinOk              = 0x0008,
    JoinDeny            = 0x0009,

    --Browsing
    ServerListRequest   = 0x000a,
    ServerListResponse  = 0x000b,
    Connect             = 0x000c,
    Logout              = 0x000d,
    --RequestServerInfo // TODO = ???

    --ServerAuthentication
    AuthenticationError = 0x000f,
    AuthenticationOk    = 0x0010,
    PlayerRejected      = 0x0011,

    --ServerIdentification
    ConnectError        = 0x000e,

    --ServerModDownload
    ModSyncStatus       = 0x0012,
    MapInfo             = 0x0013,
    Disconnect          = 0x0014,

    --ServerSessionSetup
    playerVehInfo       = 0x0015,
    Ready               = 0x0016,

    --Playing

    -- main codes
    game_ping = 0x00,
    game_vehicle = 0x01,
    game_input = 0x02,
    game_electrics = 0x03,
    game_nodes = 0x04,
    game_powertrain = 0x05,
    game_pos = 0x06,
    game_chat = 0x07,
    game_event = 0x08,
    game_player = 0x09,
    game_notification = 0x0a,
    game_kicked = 0x0b,

    --STATE CHANGES

    goto_identification = 0xaa00, -- ?? default state?
    goto_login = 0xaa01,
    goto_quickJoin = 0xaa02,
    goto_browsing = 0xaa03,
    goto_serverIdentification = 0xaa04,
    goto_serverAuthentication = 0xaa05,
    goto_serverModDownload = 0xaa06,
    goto_serverSessionSetup = 0xaa07,
    goto_serverPlaying = 0xaa08,
    goto_serverLeaving = 0xFFFF, --TODO
}

local config = {
    host = "127.0.0.1",
    port = "4444"
}

-- cached launcher information
local launcherInfo = {
    implementation = nil,
    version = nil,
    mod_cache_path = nil,
}

local modIdentity = {
    implementation = "Official BeamMP Mod",
    mod_version = {10, 20, 30},
    game_version = {10, 20, 30},
    protocol_version = {1, 0, 0},
}

local currentState = 0 --[[    
    indicates the current state of the mod, following are the valid states
    1. Identification - right after connecting to the Launcher, we switch to an indefitication state
    2. Login - if identification succeeds, we switch to login, after successful credential login, or cached key, we switch to browsing
    3. QuickJoin - prompted directly from the launcher, should open a dialog to join a server
    4. Browsing - Default state when logged in and not playing.
    5. ServerIdentification    -    IdentifyServer()
    6. ServerAuthentication    -    ConnectToServer()
    7. ServerModDownload       -    load mods?
    8. ServerSessionSetup      -    
    9. ServerPlaying           -    Game stuff idk
    10. ServerLeaving          -    LeaveServer()
]]


-- debug and helper functions
function string.fromhex(str)
    return (str:gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end))
end

function string.tohex(str)
    if type(str) == "number" then
        str = tostring(str)
    end
    return (str:gsub('.', function (c)
        return string.format('%02X', string.byte(c))
    end))
end

local function stateChange(newState)
    local previousState = currentState
    log("I", "stateChange", "New state requested. Changing from ".. tostring(previousState) .. " to ".. tostring(newState))
    currentState = newState
    return newState, previousState
end

local function GetState()
    return currentState
end

local launcherConnected = false

local function connectSocket()
    launcherSocket = socket.tcp()
    launcherSocket:setoption("keepalive", true)
    launcherSocket:settimeout(0)
    launcherSocket:connect(config.host, config.port)
end

local function disconnectSocket()
    if launcherSocket ~= nil then
        log("I", "disconnectSocket", "Closing socket.")
        launcherSocket:close()
        launcherSocket = nil
        currentState = state.stateless
    end
end

local function send(flags, purpose, pid, vid, data)
    if data == nil then data = "" end
    if launcherSocket ~= nil then
        print("sending: " .. data)
        if pid == nil then pid = 0xFFFFFFFF end
        if vid == nil then vid = 0xFFFF end

        -- flags don't do anything for now
        if flags == nil then
            flags = 0x00
        end

        flags = ffi.string(ffi.new("char[?]", 1, flags), 1)
        purpose = ffi.string(ffi.new("uint16_t[?]", 2, purpose), 2)
        pid = ffi.string(ffi.new("uint32_t[?]", 4, pid), 4)
        vid = ffi.string(ffi.new("uint16_t[?]", 2, vid), 2)

        local dataSize = ffi.string(ffi.new("uint32_t[?]", 4, #data), 4)
        local header = flags .. purpose .. pid .. vid .. dataSize
        local index, errorMsg, byte = launcherSocket:send(header .. data)
        if index == nil then
            log("E", "beammp_network.send", "Stopped at byte " .. tostring(byte) .. " out of" .. #data .. ". Error message: " .. errorMsg)
            return
        end
        return
    end
    return "Socket closed."
end

local function identifyMod()
    return jsonEncode(modIdentity)
end

local function receiveLauncherInfo(data)
    launcherInfo = jsonDecode(data)
    log("I", "receiveLauncherInfo", dumps(data))
    log("I", "receiveLauncherInfo", dumps(launcherInfo))
    send(nil, packetType.GameInfo, nil, nil, identifyMod())
end

local function receiveLoginResult(data)
    local authData = jsonDecode(data)
    dump(authData)
    -- switch state to Browsing
end


-- parses header into individual chunks
local function ParseHeader(header)
    local flags = string.sub(header, 1, 1)
    local purpose = string.sub(header, 2, 3)
    local rawpid = string.sub(header, 4, 7)
    local rawvid = string.sub(header, 8, 9)
    local rawsize = string.sub(header, 10, 13)


    log("I", "ParseHeader", "-----------NEW PACKET--------------")
    log("I", "ParseHeader", "purpose: " .. string.tohex(purpose))
    log("I", "ParseHeader", "rawpid: " .. string.tohex(rawpid))
    log("I", "ParseHeader", "rawvid: " .. string.tohex(rawvid))
    log("I", "ParseHeader", "rawsize: " .. string.tohex(rawsize))
    log("I", "ParseHeader", "-----------------------------------")

    local flags = ffi.cast("uint8_t*", ffi.new("char[?]", 1, flags))[0]
    local purpose = ffi.cast("uint16_t*", ffi.new("char[?]", 2, purpose))[0]
    local pid = ffi.cast("uint32_t*", ffi.new("char[?]", 4, rawpid))[0]
    local vid = ffi.cast("uint16_t*", ffi.new("char[?]", 2, rawvid))[0]
    local dataSize = ffi.cast("uint32_t*", ffi.new("char[?]", 4, rawsize))[0]

    log("I", "ParseHeader", "purpose: " .. purpose)
    log("I", "ParseHeader", "pid: " .. pid)
    log("I", "ParseHeader", "vid: " .. vid)
    log("I", "ParseHeader", "dataSize: " .. dataSize)

    return flags, purpose, pid, vid, dataSize
end

local function SendCredentials(username, password, remember)
    log("I", "SendCredentials", "Sending credentials to launcher...")
    local msg = jsonEncode({
        username = username;
        password = password;
        remember = remember;
    })
    send(nil, packetType.Credentials, nil, nil, msg)
end

local function Logout()
    send(nil, packetType.Logout)
end

local function ParseLogin(data)
    if data.success == true then
        guihooks.trigger("login success!")
        -- switch state to browsing
        return true
    elseif data.success == false then
        guihooks.trigger("login failure")
        -- switch state to login
    end
end

local function LogOut()
    local msg = jsonEncode({
        purpose = "logout"
    })
    SendCoreMsg(msg)
end


local function promptAutoJoin(params) -- TODO
    jsonDecode(params)
	UI.promptAutoJoinConfirmation(params)
end

local HandleNetwork = {
    --ClientIdentification
    [packetType.LauncherInfo]                       = function(...) receiveLauncherInfo(...) end,
    [packetType.Error]                              = function(...) log("E", "HandleNetwork", "Error: " .. tostring(...)) end, --ERROR
    --Login
    [packetType.AskForCredentials]                  = function(...) log("I", "HandleNetwork", "Prompting for credentials...") end, --TODO: Prompt user for credentials
    [packetType.LoginResult]                        = function(...) receiveLoginResult(...) end, --LoginResult
    --QuickJoin
    [packetType.DoJoin]                             = function(...) promptAutoJoin(...) end, --DoJoin
    --Browsing
    [packetType.ServerListResponse]                 = function(...) end,--serverList = data; sendBeamMPInfo() end, -- ServerListResponse
    [packetType.Connect]                            = function(...) end, -- Connect
    [packetType.Logout]                             = function(...) end, -- Logout
    --ServerAuthentication
    [packetType.AuthenticationError]                = function(...) end, -- AuthenticationError 
    [packetType.AuthenticationOk]                   = function(...) end, -- AuthenticationOk
    [packetType.PlayerRejected]                     = function(...) end, -- PlayerRejected
    
    --ServerIdentification
    [packetType.ConnectError]                       = function(...) end, -- ConnectError

    --ServerModDownload
    [packetType.ModSyncStatus]                      = function(...) end, -- ModSyncStatus
    [packetType.MapInfo]                            = function(...) end, -- MapInfo
    [packetType.Disconnect]                         = function(...) end, -- Disconnect

    --ServerSessionSetup
    [packetType.playerVehInfo]                      = function(...) end,
    [packetType.Ready]                              = function(...) end,
    --Playing



    -- Ingame packet handling
    --[packetType.game_ping]          = function(...) UI.setPing(...) positionGE.setPing(...) end,
    --[packetType.game_vehicle]       = function(...) MPVehicleGE.handle(...) end, -- all vehicle spawn, modification and delete events, couplers
    --[packetType.game_input]         = function(...) MPInputsGE.handle(...) end, -- inputs and gears
    --[packetType.game_electrics]     = function(...) MPElectricsGE.handle(...) end,
    --[packetType.game_nodes]         = function(...) nodesGE.handle(...) end, -- currently disabled
    --[packetType.game_powertrain]    = function(...) MPPowertrainGE.handle(...) end, -- powertrain related things like diff locks and transfercases
    --[packetType.game_pos]           = function(...) positionGE.handle(...) end, -- position and velocity
    --[packetType.game_chat]          = function(...) UI.chatMessage(...) end,
    --[packetType.game_event]         = function(...) handleEvents(...) end, -- Event For another Resource
    --[packetType.game_player]        = function(...) end, -- player join, leave, pings
    --[packetType.game_kicked]        = function(...) quitMP(...) end, -- Player Kicked Event (new, contains reason)
    --[packetType.game_notification]  = function(...) UI.showNotification(...) end, -- Display custom notification
    [packetType.goto_identification] =                  function() stateChange(state.identification) end,
    [packetType.goto_login] =                           function() stateChange(state.login) end,
    [packetType.goto_quickJoin] =                       function() stateChange(state.quickJoin) end,
    [packetType.goto_browsing] =                        function() stateChange(state.browsing) end,
    [packetType.goto_serverIdentification] =            function() stateChange(state.serverIdentification) end,
    [packetType.goto_serverAuthentication] =            function() stateChange(state.serverAuthentication) end,
    [packetType.goto_serverModDownload] =               function() stateChange(state.serverModDownload) end,
    [packetType.goto_serverSessionSetup] =              function() stateChange(state.serverSessionSetup) end,
    [packetType.goto_serverPlaying] =                   function() stateChange(state.serverPlaying) end,
    [packetType.goto_serverLeaving    ] =               function() stateChange(state.serverLeaving) end,

}


local function LeaveServer()

end

local function QuickJoin()

end

local function IdentifyServer(host, port)
    local msg = jsonEncode({
        purpose = "IdentifyServer";
        host = host;
        port = port;
    })
    SendCoreMsg(msg)
end

local function ReceiveServerIdentitiy()

end

local function ConnectToServer(host, port)
    local msg = jsonEncode({
        purpose = "ConnectToServer";
        host = host;
        port = port;
    })
    SendCoreMsg(msg)
end


local function GetState()
    return currentState
end

local function requestServerList()
    send(nil,packetType.ServerListRequest)
end

local headerLen = 13

local function receive()
    if launcherSocket ~= nil then
        while (true) do
            -- header receive
            local rawHeader, err, partial = launcherSocket:receive(headerLen)
            if err ~= nil and err~= "timeout" and err~= "closed" then
                log("E", "receive", "header receive failure, socket error: " .. err)
                log("E", "receive", "header receive failure, partial: " .. partial)
                --disconnectSocket() -- retry?
                return
            end

            if rawHeader == nil or rawHeader == "" then
                break
            end
            if #rawHeader ~= headerLen then
                log("E", "receive", "Invalid header length.")
                disconnectSocket()
                --TODO: some error message, a toast or whatever
                break
            end

            local flags, purpose, pid, vid, dataSize = ParseHeader(rawHeader)
            -- data receive
            local data, error, partial = launcherSocket:receive(dataSize)
            if err ~= nil and err~= "timeout" and err~= "closed" then
                log("E", "receive", "data receive failure, socket error: " .. error)
                log("E", "receive", "data receive failure, partial: " .. partial)
                return
            end
            HandleNetwork[purpose](data)
        end
    end
end

-- backwards compat stuff

MPCoreNetwork = {

}
MPGameNetwork = {

}


MPCoreNetwork.isMPSession = function()
    if currentState == state.serverPlaying then
        return true
    else
        return false
    end
end

MPCoreNetwork.isGoingMPSession = function()

end


-- public interface
M.send = send
M.connect = connectSocket
M.disconnect = disconnectSocket
M.SendCredentials = SendCredentials
M.Logout = Logout
M.GetState = GetState
M.requestServerList = requestServerList
-- events
M.onUpdate = receive

M.onInit = function() setExtensionUnloadMode(M, "manual") end
return M
