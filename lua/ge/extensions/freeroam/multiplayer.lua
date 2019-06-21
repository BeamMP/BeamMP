print("BeamNG-MP Lua system loaded.")
local uiWebServer = require('utils/simpleHttpServer')
local websocket = require('libs/lua-websockets/websocket')
local copas = require('libs/copas/copas')
local helper = require('freeroam/helpers')
--local message = require(guihooks).message

--local ev = require'ev'
--local ws_client = require('websocket.client').ev()

local listenHost = "0.0.0.0"
local httpListenPort = 3359

-- the websocket counterpart
local wsG = nil -- for use outside of standard system
local ws_client
local echo_handler = function(ws) -- Our Server
	wsG = ws
  while true do
    local message = ws:receive()
    if message then
      print('BeamNG-MP > Socket Message: '..message)
      --ws:send(message)
			local msg = helper.split(message, '|')
			print(helper.dump(msg))
			if msg[1] == 'JOIN' then
				-- a client has asked to join the server, lets check they are using the correct map.
				print('BeamNG-MP > A new player is trying to join')
				ws:send('MAP|'..helper.GetMap())
			elseif msg[1] == 'CONNECTING' then
			-- a client is now joining having confirmed the map, we need to send them all current vehicle data
				print('BeamNG-MP > The new player has confirmed the map, Send them the session data')
				ws:send('Session data to go here')
			elseif msg[1] == 'CONNECTED' then
			-- start sending out our game data again. We will be the point of sync for all players
				print('BeamNG-MP > The new player has now synced with us. Now to unpause')
				ws:send('Start Broadcast of session data and unpause')
			elseif msg[1] == 'UPDATE' then
			-- a client sendus new data about they session state, so we need to update our vehicles to match theirs
				print('BeamNG-MP > A new player is trying to join')
				ws:send('Update our game with client data')
			elseif msg[1] == 'CHAT' then
				ws:send('CHAT|'..msg[2])
			end
    else
      ws:close()
      return
    end
  end
end

local function receive_data_job(job) -- Our Client
    while ws_client do
      local data_raw = ws_client:receive() --apparently always blocking so we need to use a coroutine
      if not data_raw then
        return
      end
      print('Client received ' .. tostring(data_raw))
			-- now lets break up the message we received so that we can make use of it since we dont know of a way to subscribe to different channels. Maybe in a new update? Socket.io?
			local msg = helper.split(data_raw, '|')
			if msg[1] == 'MAP' then
				print('BeamNG-MP > Socket Message: new data = '..msg[1]..' : '..msg[2])
				ui_message('Connection Successful. Setting up Session!', 10, 0, 0)
			elseif msg[1] == 'VEHICLE' then

			elseif msg[1] == 'CHAT' then
				ui_message(msg[2], 10, 0, 0)
			end
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
			ui_message('Attempting to join session: '..value.ip..':'..value.port..'', 10, 0, 0)
			extensions.core_jobsystem.create(function ()
				ws_client = websocket.client.copas({timeout=0})
				ws_client:connect('ws://'..value.ip..':'..value.port..'')
				extensions.core_jobsystem.create(receive_data_job)
				ws_client:send("JOIN|Hey")
			end)
		end
	end
end

local webServerRunning = false

local function hostSession(value)
	print('BeamNG-MP Attempting to host multiplayer session.')
	map.getMap()
	--local map = get
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
			ui_message('Session hosted on: '..listenHost..':3360', 10, 0, 0)
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

local function setChatMessage(value)
	print('Chat Values (chatSend): '..value..' | '..chatMessage)
	chatMessage = value
end

local function chatSend(value)
	print('Chat Values (setChatMessage): '..value..' | '..chatMessage)
	if not value then
		print('Chat Value not set! '..value..' | '..chatMessage)
		return
	else
		ws_client:send('CHAT|'..value)
	end
end

M.onUpdate = onUpdate
M.ready = ready
M.chatSend = chatSend
M.setChatMessage = SetChatMessage
M.joinSession = joinSession
M.hostSession = hostSession

return M
