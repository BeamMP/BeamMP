webserver = require('webserver') -- https://github.com/BeamNG/luawebserver/blob/master/webserver.lua
print('WebServer main.lua')
-- calledonce upon lua loading
function init()
    webserver.init('127.0.0.1', 8080)
end

-- should be called every frame
function update()
    webserver.update()
end
