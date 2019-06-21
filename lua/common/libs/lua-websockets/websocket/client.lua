return setmetatable({},{__index = function(self, name)
  if name ~= 'copas' and name ~= 'new' and name ~= 'ev' and name ~= 'sync' then return end -- we do random lookups here, so do not try to load random files there ...
  if name == 'new' then name = 'sync' end
  local backend = require("libs/lua-websockets/websocket/client_".. name)
  self[name] = backend
  if name == 'sync' then self.new = backend end
  return backend
end})
