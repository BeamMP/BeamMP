-- https://github.com/BeamNG/luawebserver/blob/master/webserver.lua
-- warning: this project was not completed, however the basefile serving over ltn12 should work

local M = {}

local bindhost = 'localhost'
local bindport = 23512

local tcp_socket = nil

local socket = require("socket.socket")
local url    = require("socket.url")
local ltn12  = require("socket.ltn12")

ltn12.BLOCKSIZE = 4096

local clients_read = {}
local clients_write = {}
local sinks = {}

local function init(_bindhost, _bindport)
    bindhost = _bindhost
    bindport = _bindport

    tcp_socket = socket.tcp()
    res, err = tcp_socket:bind(bindhost, bindport)
    if res == nil then
        print("unable to create webserver: " .. err)
    end
    tcp_socket:settimeout(0, 't')
    tcp_socket:listen()
    print("WebServer running on port "..bindport)
end

local function receiveRequest(c)
    -- receive first line only
    local line, err = c:receive()
    if err then
        -- 'timeout'
        print("client.receive error: " .. tostring(err))
        return
    end
    -- process URI's in that
    for uri in string.gmatch(line, "GET /([^ ]*) HTTP/[0-9].[0-9]") do
        local headers = {}
        while true do
            local line, err = c:receive()
            if err then
                -- 'timeout'
                print("client.receive error: " .. tostring(err))
                return nil
            end
            if line == '' then
                break
            end
            local args = split(line, ':', 1)
            if #args == 2 then
                local key = string.lower(trim(args[1]))
                local value = trim(args[2])
                headers[key] = value
            end
        end
        local uri_parsed = url.parse(uri)
        return {uri = uri_parsed, headers = headers}
    end
    return nil
end

local function update()
    -- accept new connections
    while true do
        local new_client = tcp_socket:accept()
        if new_client then
            --new_client:settimeout(0.1, 't')
            table.insert(clients_read,  new_client)
            table.insert(clients_write, new_client)
        else
            break
        end
    end

    local read, write, _ = socket.select(clients_read, clients_write, 0) -- _ = 'timeout' or nil, does not matter for our non-blocking usecase

    for _, c in ipairs(read) do
        if write[c] == nil then
            goto continue
        end

        c:settimeout(0.1, 't')

        local request = receiveRequest(c)
        if request == nil then
            goto continue
        end

        if request['uri'] == nil or request['uri']['path'] == nil then
            print('unable to open file for reading: '.. request['uri']['path'])
            goto continue
        end

        local fileHandle, err = io.open(request['uri']['path'], "rb")
        if fileHandle == nil or err then
            print('unable to open file for reading: '.. request['uri']['path'])
            goto continue
        end

        local fileSource = ltn12.source.file(fileHandle)
        local sink = socket.sink('close-when-done', c)

        table.insert(sinks, {c, fileSource, sink})

        ::continue::
    end

    -- now pump the data
    local newList = {}
    for i, sinkData in ipairs(sinks) do
        if write[sinkData[1]] then
            local res, err = ltn12.pump.step(sinkData[2], sinkData[3])
            print(tostring(res))
            print(tostring(err))
            if res then
                table.insert(newList, sinkData)
            end
        end
    end
    sinks = newList
end

-- public interface
M.init   = init
M.update = update

return M
