print("BeamNG-MP Lua system loaded.")
local uiWebServer = require('utils/simpleHttpServer')
local listenHost = "127.0.0.1"
local httpListenPort = 3359
uiWebServer.start(listenHost, httpListenPort, '/', nil, function(req, path)
	return {
		httpPort = httpListenPort,
		wsPort = httpListenPort + 1,
		host = listenHost,
	}
end)
print('BeamNG-MP created http server')

-- the websocket counterpart
local wsServer = require('libs/lua-websockets/websocket').server.copas.listen({
	interface = listenHost,
	port = httpListenPort + 1,
	protocols = {
		bngApi = bngApi_websocket_handler,
	},
	default = bngApi_websocket_handler,
})
print('BeamNG-MP created http server')

local M = {}

local function ready()
	print("BeamNG-MP UI Ready!")
end

local function joinSession(value)
	if not value then
		print("Join Session port or IP are blank.")
	else
		if value.ip ~= "" and value.port ~= 0 then

		end
	end
end

local function hostSession(value)
	if not value then
		print("Join Session port or IP are blank.")
	else
		if value.ip ~= "" and value.port ~= 0 then

		end
	end
end

M.ready = ready
M.joinSession = joinSession
M.hostSession = hostSession

return M
