print("BeamNG-MP Lua system loaded.")
local uiWebServer = require('utils/simpleHttpServer')
local websocket = require('libs/lua-websockets/websocket')
local copas = require('libs/copas/copas')

--local ev = require'ev'
--local ws_client = require('websocket.client').ev()

local listenHost = "0.0.0.0"
local httpListenPort = 3359

-- the websocket counterpart
local wsG = nil -- for use outside of standard system
local ws_client
local echo_handler = function(ws)
	wsG = ws
  while true do
    local message = ws:receive()
    if message then
      print('BeamNG-MP > Socket Message: '..message)
      ws:send(message)
    else
      ws:close()
      return
    end
  end
end

local function receive_data_job(job)
    while ws_client do
      local data_raw = ws_client:receive() --apparently always blocking so we need to use a coroutine
      if not data_raw then
        return
      end
      print('Cleint received ' .. tostring(data_raw))
    end
    print('receive coroutine done')
end

local M = {}

local function ready()
	print("BeamNG-MP UI Ready!")
end

local function joinSession(value)
	print('BeamNG-MP Attempting to join multiplayer session.')
	if false then --if not value then
		print("Join Session port or IP are blank.")
	else
		value = {}
		value.ip = "192.168.0.1" -- Preset to the host in my case
		value.port = 3360
		if value.ip ~= "" and value.port ~= 0 then
			extensions.core_jobsystem.create(function ()
				ws_client = websocket.client.copas({timeout=0})
				ws_client:connect('ws://'..value.ip..':'..value.port..'')
				extensions.core_jobsystem.create(receive_data_job)
				ws_client:send("I'm a client")
			end)
		end
	end
end

local webServerRunning = false

local function hostSession(value)
	print('BeamNG-MP Attempting to host multiplayer session.')
	local map = get
	if false then --if not value then
		print("Host Session port or IP are blank.")
	else
		value = 3359
		if value ~= 0 then
			listenHost = "0.0.0.0"
			httpListenPort = value
			uiWebServer.start(listenHost, httpListenPort, '/', nil, function(req, path)
				webServerRunning = true
				return {
					httpPort = 3359,--httpListenPort,
					wsPort = 3360,--httpListenPort + 1,
					host = listenHost,
				}
			end)
			print('BeamNG-MP Webserver hosted on '..listenHost..":"..httpListenPort)

			-- create a copas webserver and start listening
			wsServer = websocket.server.copas.listen{
				-- listen on port 8080
			  port = 3360,
			  -- the protocols field holds
			  --   key: protocol name
			  --   value: callback on new connection
			  protocols = {
			    -- this callback is called, whenever a new client connects.
			    -- ws is a new websocket instance
			    echo = echo_handler
			  },
			  default = echo_handler
			}
			print('BeamNG-MP Websockets hosted on '..listenHost..':3360')
		end
	end
end

local function onUpdate()
	copas.step(0)
	--[[if ws_client or webServerRunning then
		--copas.step(0)
	else
		return
	end

	if ws_client then
		local recv = ws_client:receive()
		if recv then
			print("client received ="..dumps(recv) )
		end
	end]]

	if webServerRunning then
		uiWebServer.update()
	end
end

M.onUpdate = onUpdate
M.ready = ready
M.joinSession = joinSession
M.hostSession = hostSession

return M
