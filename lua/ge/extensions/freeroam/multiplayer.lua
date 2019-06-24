print("BeamNG-MP Lua system loaded.")
local uiWebServer = require('utils/simpleHttpServer')
local websocket = require('libs/lua-websockets/websocket')
local copas = require('libs/copas/copas')
local helper = require('freeroam/helpers')

local listenHost = "0.0.0.0"
local httpListenPort = 3359
local chatMessage = ""
local nick = ""

-- the websocket counterpart
local ws_client

local echo_handler = function(ws) -- Our Server
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
				ws:broadcast('CHAT|'..msg[2]..' is joining the session.')
				ws:send('MAP|freeroam')--..helper.GetMap())
			elseif msg[1] == 'CONNECTING' then
			-- a client is now joining having confirmed the map, we need to send them all current vehicle data
				print('BeamNG-MP > The new player has confirmed the map, Send them the session data')
				local vehs = helper.GetVehicles()
				print(helper.dump(vehs))
				print(vehs)
				local peeps = helper.GetPlayer()
				print(helper.dump(peeps))
				print(peeps)
				local map = helper.GetMap()
				print(helper.dump(map))
				print(map)
				local state = getState()
				print(helper.dump(state))
				print(state)
				local levelInfo = getObject("LevelInfo")
				print(helper.dump(levelInfo))
				print(levelInfo)
				ws:send('SETUP|'..vehs)
			elseif msg[1] == 'CONNECTED' then
			-- start sending out our game data again. We will be the point of sync for all players
				print('BeamNG-MP > The new player has now synced with us. Now to unpause')
				ws:send('Start Broadcast of session data and unpause')
			elseif msg[1] == 'UPDATE' then
			-- a client sendus new data about they session state, so we need to update our vehicles to match theirs
				print('BeamNG-MP > A new player is trying to join')
				ws:broadcast('Update our game with client data')
			elseif msg[1] == 'CHAT' then
				print('Attempting to broadcast chat message')
				ws:broadcast('CHAT|'..msg[2])
			elseif msg[1] == 'ERROR' then
				ws:send('ERROR|'..msg[2])
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
			-- now lets break up the message we received so that we can make use of it since we dont know of a way to subscribe to different channels.
			-- Maybe in a new update? Socket.io?
			local msg = helper.split(data_raw, '|')
			print(helper.dump(msg))

			print('BeamNG-MP > Socket Message: new data = '..msg[1]..' : '..msg[2])
			if msg[1] == 'MAP' then
				ui_message('Connection Successful. Setting up Session... (Map = '..msg[2]..')', 10, 0, 0)
				ws_client:send("CONNECTING|Map=good")
			elseif msg[1] == 'SETUP' then
				--print(msg[2])
			elseif msg[1] == 'UPDATE' then

			elseif msg[1] == 'CHAT' then
				print('New Chat Message: '..msg[2])
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
				local user = nick or "User"
				ws_client:send("JOIN|"..user)
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
			extensions.core_jobsystem.create(function ()
				ws_client = websocket.client.copas({timeout=0})
				ws_client:connect('ws://localhost:3360')
				extensions.core_jobsystem.create(receive_data_job)
				ws_client:send("JOIN|Hey")
			end)
			print('BeamNG-MP Websockets hosted on '..listenHost..':3360')
			ui_message('Session hosted on: '..listenHost..':3360', 10, 0, 0)
		end
	end
end

local function onUpdate()
	copas.step(0)
	if webServerRunning then
		uiWebServer.update()
	end
end

local function setNickname(value)
	nick = value.data
	--print('Chat Values (setChatMessage): '..value.data..' | '..chatMessage or "")
end

local function setChatMessage(value)
	chatMessage = value.data
	--print('Chat Values (setChatMessage): '..value.data..' | '..chatMessage or "")
end

local function chatSend(value)
	--print('Chat Values (chatSend): '..value.data..' | '..chatMessage or "")
	if not value then
		print('Chat Value not set! '..value.data..' | '..chatMessage or "")
		return
	else
		print('BeamNG-MP Chat: Message sent = '..value.data)
		ws_client:send('CHAT|'..nick..': '..value.data)
		chatMessage = ""
	end
end

M.onUpdate = onUpdate
M.ready = ready
M.chatSend = chatSend
M.setNickname = setNickname
M.setChatMessage = setChatMessage
M.joinSession = joinSession
M.hostSession = hostSession

return M
