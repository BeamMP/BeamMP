
-- VERY WIP of new protocol, does not actually load or work

local M = {}

local socket = require('socket')
local ffi = require("ffi")
local bit = require("bit")
local launcherSocket = nil



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
    --RequestServerInfo // TBD

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

    goto_identification = 0xaa00,
    goto_login = 0xaa01,
    goto_quickJoin = 0xaa02,
    goto_browsing = 0xaa03,
    goto_serverIdentification = 0xaa04,
    goto_serverAuthentication = 0xaa05,
    goto_serverModDownload = 0xaa06,
    goto_serverSessionSetup = 0xaa07,
    goto_serverPlaying = 0xaa08,
    goto_serverLeaving = 0xaa09, -- TBD
}

local state = {
    identification = 0xC0,
    login = 0xC1,
    quickJoin = 0xC2,
    browsing = 0xC3,
    serverIdentification = 0xC4,
    serverAuthentication = 0xC5,
    serverModDownload = 0xC6,
    modLoading = "TODO", -- TBD
    mapLoading = "TODO", -- TBD
    serverSessionSetup = 0xC7,
    serverPlaying = 0xC8,
    serverLeaving = 0xC9,
}

local function invertTable(a)
    local t = {}
    for k, v in pairs(a) do
      t[v] = k
    end
    return t
end

M.stateNames = invertTable(state)

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

local ver = split(beamng_versiond, ".")
local modIdentity = {
    implementation = "Official BeamMP Mod",
    mod_version = {10, 20, 30},
    --game_version = {ver[1], ver[2], ver[3]},
    game_version = {10,20,30},
    protocol_version = {1, 0, 0},
    game_path = FS:getGamePath(),
    user_path = FS:getUserPath(),
}



-- default state before connecting
local currentState = state.identification


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
    log("I", "stateChange", "New state requested. Changing from ".. tostring(M.stateNames[previousState]) .. " to ".. tostring(M.stateNames[newState]))
    currentState = newState
    return newState, previousState
end

local function GetState()
    return currentState
end

local function disconnectSocket()
    if launcherSocket ~= nil then
        log("I", "disconnectSocket", "Closing socket.")
        launcherSocket:close()
        launcherSocket = nil
        stateChange(state.identification)
    end
end

local function connectSocket()
    if launcherSocket ~= nil then
        log("W", "connectSocket", "Existing socket already exists.")
        disconnectSocket()
    end
    log("I", "connectSocket", "Connecting...")
    launcherSocket = socket.tcp()
    launcherSocket:setoption("keepalive", true)
    launcherSocket:settimeout(0)
    launcherSocket:connect(config.host, config.port)
end

--TODO: implement send retry
local function send(flags, purpose, pid, vid, data)
    if launcherSocket ~= nil then
        data = data and data or ""
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
        log("I", "send", "header: " .. string.tohex(header))
        log("I", "send", "data: " .. data)
        local index, errorMsg, byte = launcherSocket:send(header .. data)
        if index == nil then
            log("E", "beammp_network.send", "Stopped at byte " .. tostring(byte) .. " out of " .. #data .. ". Error message: " .. errorMsg)
            if errorMsg == "closed" then
                log("W", "send", "socket closed.")
                launcherSocket = nil
                currentState = state.identification
            end
        end
        return
    end
    log("W", "send", "Attempted to send data through a closed socket.")
end

local function identifyMod()
    return jsonEncode(modIdentity)
end

local function receiveLauncherInfo(data)
    local info = jsonDecode(data)
    if info == nil then
        log("E", "receiveLauncherInfo", "Received invalid launcher identification. Raw data: ".. data)
        disconnectSocket()
        return
    end
    launcherInfo = info
    log("I", "receiveLauncherInfo", dumps(launcherInfo))
    send(nil, packetType.GameInfo, nil, nil, identifyMod())
end

local function receiveLoginResult(data)
    local result = jsonDecode(data)
    if result == nil then
        log("E", "receiveLoginResult", "Login response is invalid. Raw data: " .. tostring(data))
        return
    end
    log("I", "receiveLoginResult", dumps(result))

    if result.success == true then
        return
    end
    if result.success == false then
        return
    end
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

local function promptAutoJoin(params) -- TODO
    jsonDecode(params)
	UI.promptAutoJoinConfirmation(params)
end

local function handleError(...)
    log("E", "handleError", ...)
end

local function promptCredentials(...)
    log("I", "HandleNetwork", "Prompting for credentials...")
end

local function setPing(...)
    UI.setPing(...)
    positionGE.setPing(...)
end

local function receiveServerListResponse(...)
    --serverList = data
    --sendBeamMPInfo()
end

local HandleNetwork = {
    [state.identification] = {
        [packetType.LauncherInfo] = receiveLauncherInfo,
        [packetType.Error] = handleError,
    },
    [state.login] = {
        [packetType.AskForCredentials] = promptCredentials,
        [packetType.LoginResult] = receiveLoginResult,
    },
    [state.quickJoin] = {
        [packetType.DoJoin] = promptAutoJoin,
    },
    [state.browsing] = {
        [packetType.ServerListResponse] = receiveServerListResponse,
        [packetType.Error] = handleError,
    },
    [state.serverIdentification] = {
        [packetType.ConnectError] = handleError, -- TODO: implement proper handler
    },
    [state.serverAuthentication] = {
        [packetType.AuthenticationError] = handleError, -- TODO: implement proper handler
        [packetType.AuthenticationOk]    = function(...) dump(...) end,
        [packetType.PlayerRejected]      = function(...) dump(...) end,
    },
    [state.serverModDownload] = {
        [packetType.ModSyncStatus] = function(...) dump(...) end, -- UI hook something or the other
        [packetType.MapInfo]       = function(...) dump(...) end, -- TODO: set the mapp
    },
    [state.serverSessionSetup] = {
        [packetType.playerVehInfo] = function(...) dump(...) end,
        [packetType.Ready]         = function(...) dump(...) end,
    },
    [state.serverPlaying] = {
        [packetType.game_ping]          = setPing,
        --[packetType.game_vehicle]       = MPVehicleGE.handle, -- all vehicle spawn, modification and delete events, couplers
        --[packetType.game_input]         = MPInputsGE.handle, -- inputs and gears
        --[packetType.game_electrics]     = MPElectricsGE.handle,
        --[packetType.game_nodes]         = nodesGE.handle, -- currently disabled
        --[packetType.game_powertrain]    = MPPowertrainGE.handle, -- powertrain related things like diff locks and transfercases
        --[packetType.game_pos]           = positionGE.handle, -- position and velocity
        --[packetType.game_chat]          = UI.chatMessage,
        --[packetType.game_event]         = handleEvents, -- Event For another Resource
        --[packetType.game_player]        = function(...) end, -- player join, leave, pings
        --[packetType.game_kicked]        = quitMP, -- Player Kicked Event (contains reason)
        --[packetType.game_notification]  = UI.showNotification, -- Display custom notification
        --[packetType.goto_serverLeaving] = stateChange(state.serverLeaving),
    },
    [state.serverLeaving] = {},
}

local function IdentifyServer(host, port) -- TBD
    local msg = jsonEncode({
        purpose = "IdentifyServer";
        host = host;
        port = port;
    })
    --SendCoreMsg(msg)
end

local function ReceiveServerIdentitiy()

end

local function ConnectToServer(host, port)
    local msg = jsonEncode({
        host = host;
        port = tonumber(port);
    })
    send(nil, packetType.Connect, nil, nil, msg)
end

local function LeaveServer()
    log("I", "LeaveServer", "Leaving server...")
end


local function GetState()
    return currentState
end

local function requestServerList()
    log("D", "requestServerList", "Requesting server list.")
    send(nil, packetType.ServerListRequest)
end

local function Handle(flags, purpose, pid, vid, dataSize, data)
    --0xaa01 -> 0xC1
    -- TODO: just make a map instead for readability reasons
    if bit.rshift(purpose, 8) == 0xaa then
        stateChange(bit.band(purpose, 0xFF) + 0xC0)
        return
    end
    local handleState = HandleNetwork[currentState]
    if handleState == nil then
        log("E", "receive", "Invalid state.")
        return
    end
    local handlePurpose = handleState[purpose]
    if handlePurpose == nil then
        log("E", "receive", "Invalid purpose for state: " .. tostring(M.stateNames[currentState]))
        log("I", "receive", "data:" .. tostring(data))
        return
    end
    handlePurpose(data)
    --Handle[currentState][purpose](data)
end

local headerLen = 13
local dataBuffer = ""
local frameCounter = 0
local flags, purpose, pid, vid, dataSize
local function receive()
    if launcherSocket ~= nil then
        frameCounter = frameCounter + 1
        while (true) do
            -- data receive
            if dataSize ~= nil and dataSize > #dataBuffer then
                local data, dataError, dataPartial = launcherSocket:receive(dataSize - #dataBuffer)
                if data ~= nil then
                    log("I", "receive", "Received: " .. tostring(#data) .. " bytes")
                end
                if dataError ~= nil then
                    log("E", "receive", "Data receive failure, socket error: " .. dataError)
                    log("E", "receive", "Data receive failure, partial: " .. dataPartial)
                    if dataError == "timeout" then
                        log("W", "receive", "Out of data to read. Delaying receive by 1 frame. Got " .. #dataPartial .. " out of " .. dataSize - #dataBuffer)
                        dataBuffer = dataBuffer .. dataPartial
                    end
                    if dataError == "closed" then
                        log("W", "receive", "Launcher socket closed.")
                        disconnectSocket()
                    end
                    return
                end
                dataBuffer = dataBuffer .. data
                --log("W", "dataSize: ".. dataSize)
                --log("W", "dataBuffer: ".. #dataBuffer)
            end

            if dataSize ~= nil and dataSize == #dataBuffer then
                Handle(flags, purpose, pid, vid, dataSize, dataBuffer)
                flags, purpose, pid, vid, dataSize = nil,nil,nil,nil,nil
                dataBuffer = ""
                log("I", "receive", "Receive completed on frame ".. frameCounter .. ".")
                log("I", "receive", "Data handled and cleared." )
            end
            

            -- header receive
            local rawHeader, headerError, headerPartial = launcherSocket:receive(headerLen)
            if headerError == "timeout" then return end
            if headerError == "closed" then disconnectSocket() return end
            if headerError ~= nil and headerError~= "closed" then
                log("E", "receive", "header receive failure, socket error: " .. headerError)
                log("E", "receive", "header receive failure, partial: " .. headerPartial)
                --disconnectSocket()
                return
            end

            if rawHeader == nil then
                log("W", "Header is nil")
                return
            end
            if #rawHeader < headerLen then
                log("E", "receive", "Invalid header length.")
                disconnectSocket()
                --TODO: some error message, a toast or whatever
                return
            end
            flags, purpose, pid, vid, dataSize = ParseHeader(rawHeader)
            frameCounter = 0
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
M.ConnectToServer = ConnectToServer
M.LeaveServer = LeaveServer
-- events
M.onUpdate = receive

M.onInit = function() setExtensionUnloadMode(M, "manual") end
return M
