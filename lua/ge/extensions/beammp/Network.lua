
-- VERY WIP of new protocol, does not actually load or work

local M = {}

local socket = require('socket')
local ffi = require("ffi")
local launcherSocket = nil


local state = {
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
    name = "No",
    protocol_version = "No",

}

local modIdentity = {
    purpose = "identification",
    who = "Official BeamMP Mod",
    mod_version = "123123123",
    game_version = "",
    network_version = "0.1",
}

local currentState = nil --[[    
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
    end
end

local function send(data)
    if data == nil then return end
    if launcherSocket ~= nil then
        -- add packet headers etc
        local index, errorMsg, byte = launcherSocket:send(ffi.new("uint32_t[1]", #data) .. data)
        if index == nil then
            log("E", "beammp_network.send", "Stopped at byte " .. tostring(byte) .. " out of" .. #data .. ". Error message: " .. errorMsg)
            return
        end
    end
end

-- receive identification packet from server
local function identifyMod()
    return jsonEncode(modIdentity)
end

local function receiveLauncherInfo(data)
    data = jsonDecode(data)
    log("I", "receiveLauncherInfo", data)
end

local function ReceiveAuth(data)
    local authData = jsonDecode(data)
    dump(data)
    -- switch state to Browsing
end




local function parseLauncherIdentity(data)
    data = jsonDecode(data)
    if data and data.network_version ~= "1.0" then
        return true
    end
end


-- parses header into individual chunks
local function ParseHeader(header)
    local target = string.sub(header, 1, 1)
    local flags = string.sub(header, 1, 1)
    local packetType = string.sub(header, 2, 2)
    local packetSubType = string.sub(header, 3, 3)
    local rawpid = string.sub(header, 4, 7)
    local rawvid = string.sub(header, 8, 9)
    local rawsize = string.sub(header, 10, 13)

    local pid = ffi.cast("uint32_t*", ffi.new("char[?]", 4, rawpid))[0]
    local vid = ffi.cast("uint16_t*", ffi.new("char[?]", 2, rawvid))[0]
    local dataSize = ffi.cast("uint32_t*", ffi.new("char[?]", 4, rawsize))[0]

    return target, packetType, packetSubType, pid, vid, dataSize
end



local function SendCoreMsg(data)
    if data == nil then return end
    send('C' .. data)
end

local function SendGameMsg(data)
    if data == nil then return end
    send('G' .. data)
end

local function SendCredentials(username, password)
    local msg = jsonEncode({
        purpose = "login_request";
        username = username;
        password = password
    })
    SendCoreMsg(msg)
end

--[[
    {
        purpose = "login_response";
        success = true || false;
        message = "Welcome Username, roles", "Welcome back x" on key login;
        username = "player69";
        role = "[Dev]", ["Mod"]
    }
]]
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
    jsonDecode()
	UI.promptAutoJoinConfirmation(params)
end

local HandleNetworkCore = {
    --ClientIdentification
    [packetType.LauncherInfo] = function(data) parseLauncherIdentity() end,
    [packetType.Error] = function(data) end, --ERROR
    --Login
    [packetType.AskForCredentials] = function(data) end, --AskForCredentials
    [packetType.LoginResult] = function(data) end, --LoginResult
    --QuickJoin
    [packetType.DoJoin] = function(data) end, --DoJoin
    --Browsing
    [packetType.ServerListRequest] = function(data) end, -- ServerListRequest  
    [packetType.ServerListResponse] = function(data) serverList = data; sendBeamMPInfo() end, -- ServerListResponse 
    [packetType.Connect] = function(data) end, -- Connect            
    [packetType.Logout] = function(data) end, -- Logout             
    --ServerAuthentication
    [packetType.AuthenticationError] = function() end, -- AuthenticationError 
    [packetType.AuthenticationOk] = function() end, -- AuthenticationOk    
    [packetType.PlayerRejected] = function() end, -- PlayerRejected
    
    --ServerIdentification
    [packetType.ConnectError] = function() end, -- ConnectError

    --ServerModDownload
    [packetType.ModSyncStatus] = function() end, -- ModSyncStatus
    [packetType.MapInfo] = function() end, -- MapInfo      
    [packetType.Disconnect] = function() end, -- Disconnect   
    
    --ServerSessionSetup
    [packetType.playerVehInfo] = function() end,
    [packetType.Ready] = function() end,
    --Playing


    ['session_setup'] = function(data)    end,
    ['mod_info'] = function(data) end,
	['auto_join'] = function(data) promptAutoJoin(data) end, -- Automatic Server Joining
	['set_mods'] = function(data) setMods(params) status = "LoadingResources" end, -- should be in session setup or whatever?
	['map'] = function(data) log('W', 'HandleNetwork', 'Received Map! '..data) loadLevel(data) end, -- should just be handled in session setup?
	['login_info'] = function(data) loginReceived(data) end, -- should update login information, is the user logged in, their username, roles?
	['update_ui'] = function(data) UI.updateLoading(data) end,
	['quick_join'] = function(data) promptAutoJoin(data) end,
}

local function CoreStuff(data)
    local jsonData = jsonDecode(data)
    if not jsonData then return end
    HandleNetworkCore[jsonData.purpose](jsonData)
end


local OldCore = {
	['B'] = function(params) serverList = params; sendBeamMPInfo() end, -- Server list received
	['J'] = function(params) promptAutoJoin(params) end, -- Automatic Server Joining
	['L'] = function(params) setMods(params) status = "LoadingResources" end, --received after sending 'C' packet
	['M'] = function(params) log('W', 'HandleNetwork', 'Received Map! '..params) loadLevel(params) end,
	['N'] = function(params) loginReceived(params) end,
	['U'] = function(params) handleU(params) end, -- Loading into server UI, handles loading mods, pre-join kick messages and ping
	['Z'] = function(params) launcherVersion = params; end,
}



local HandleNetworkGame = {
    [0x00] = function(...) UI.setPing(...) positionGE.setPing(...) end,
    [0x01] = function(...) MPVehicleGE.handle(...) end, -- all vehicle spawn, modification and delete events, couplers
	[0x02] = function(...) MPInputsGE.handle(...) end, -- inputs and gears
	[0x03] = function(...) MPElectricsGE.handle(...) end,
	[0x04] = function(...) nodesGE.handle(...) end, -- currently disabled
	[0x05] = function(...) MPPowertrainGE.handle(...) end, -- powertrain related things like diff locks and transfercases
	[0x06] = function(...) positionGE.handle(...) end, -- position and velocity
    [0x07] = function(...) UI.chatMessage(...) end,
    [0x08] = function(...) handleEvents(...) end, -- Event For another Resource
    [0x09] = function(...) end, -- player join, leave, pings
    [0x0a] = function(...) handleEvents(...) end,
    [0x0b] = function(...) quitMP(...) end, -- Player Kicked Event (new, contains reason)
	['P'] =  function(...) MPConfig.setPlayerServerID(...) end, -- should be done in session setup
	['J'] =  function(...) MPUpdatesGE.onPlayerConnect() UI.showNotification(...) end, -- A player joined
	['L'] =  function(...) UI.showNotification(...) end, -- Display custom notification
	['S'] =  function(...) sessionData(...) end, -- Update Session Data
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

local headerLen = 12

local function receive()
    if launcherSocket ~= nil then
        while (true) do
            -- header receive
            local rawHeader, err, partial = launcherSocket:receive(headerLen)
            if err ~= nil then
                log("E", "receive", "header receive failure, socket error: " .. err)
                log("E", "receive", "header receive failure, partial: " .. partial)
                disconnectSocket() -- retry?
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

            local target, packetType, packetSubType, pid, vid, dataSize = ParseHeader(rawHeader)
            local data, erorr, partial = launcherSocket:receive(dataSize)
            if erorr ~= nil then
                log("E", "receive", "data receive failure, socket error: " .. erorr)
                log("E", "receive", "data receive failure, partial: " .. partial)
            end

            if target == 'C' then
                HandleNetworkCore(jsonDecode(data))
                return
            end

            if target == 'G' then
                HandleNetworkGame[packetType](packetSubType, pid, vid, data)
                return
            end
        end
    end
end

local function progressState(newState)
    log("I", "progressState", "New state requested: " .. newState)
    local previousState = currentState
    return newState, previousState
end

local function GetState()
    return currentState
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
M.GetState = GetState
-- events
M.onUpdate = receive

return M
