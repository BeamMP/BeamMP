print("BeamNG-MP Lua system loaded.")
local uiWebServer = require('utils/simpleHttpServer')
local wsServer = require('libs/lua-websockets/websocket')
local copas = require('libs/copas/copas')

--local ev = require'ev'
--local ws_client = require('websocket.client').ev()

local listenHost = "0.0.0.0"
local httpListenPort = 3359

-- the websocket counterpart
local wsServer = nil

local echo_handler = function(ws)
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
		value.ip = "0.0.0.0"
		value.port = 3360
		if value.ip ~= "" and value.port ~= 0 then
			local ws_client = require('libs/lua-websockets/websocket').new{
				ws_client:sock_receive(function()
			    print('connected')
			  end)

				ws_client:sock_connect('ws://'..value.ip..':'..value.port..'','echo')

				ws_client:sock_receive(function(ws, msg)
			    print('received',msg)
			  end)
			}
		end
	end
end

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
				return {
					httpPort = 3359,--httpListenPort,
					wsPort = 3360,--httpListenPort + 1,
					host = listenHost,
				}
			end)
			print('BeamNG-MP Webserver hosted on '..listenHost..":"..httpListenPort)

			-- create a copas webserver and start listening
			local server = require('libs/lua-websockets/websocket').server.copas.listen{
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
	if not uiWebServer then return end

	copas.step(0)
	uiWebServer.update()
end

M.onUpdate = onUpdate
M.ready = ready
M.joinSession = joinSession
M.hostSession = hostSession

return M
