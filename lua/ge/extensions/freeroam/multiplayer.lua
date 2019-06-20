print("BeamNG-MP Lua system loaded.")
uiWebServer = require('utils/simpleHttpServer')
uiWebServer.start(listenHost, httpListenPort, '/', nil, function(req, path)
	return {
		httpPort = httpListenPort,
		wsPort = httpListenPort + 1,
		host = listenHost,
	}
end)
print('created http server')

-- the websocket counterpart
wsServer = require('libs/lua-websockets/websocket').server.copas.listen({
	interface = listenHost,
	port = httpListenPort + 1,
	protocols = {
		bngApi = bngApi_websocket_handler,
	},
	default = bngApi_websocket_handler,
})

local M = {}

local function ready()
	log("A", "titch", "BeamNG-MP UI Ready!")
end

local function joinSession(value)
	if not value then
		log("A", "titch", "Join Session port or IP are blank.")
	else
		if value.ip ~= "" and value.port ~= 0 then

		end
	end
end

local function hostSession(value)
	if not value then
		log("A", "titch", "Join Session port or IP are blank.")
	else
		if value.ip ~= "" and value.port ~= 0 then

		end
	end
end

M.ready = ready
M.joinSession = joinSession
M.hostSession = hostSession

return M
