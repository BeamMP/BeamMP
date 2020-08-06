--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}

--local function applyPartConfig(data) -- Pre 0.20
	--local decodedData = jsonDecode(data) -- Decode received data
	--partmgmt.setConfig(decodedData)
--end

local function applyPartConfig(data) -- Post 0.20
    local decodedData = jsonDecode(data) -- Decode received data
    tableMerge(v.config, decodedData)
    obj:respawn(serialize(v.config))
end

M.applyPartConfig = applyPartConfig

return M
