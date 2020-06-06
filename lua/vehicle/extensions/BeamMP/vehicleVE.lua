--====================================================================================
-- All work by jojos38 & Titch2000.
-- You have no permission to edit, redistribute or upload. Contact us for more info!
--====================================================================================



local M = {}

local function applyPartConfig(data)
	local decodedData = jsonDecode(data) -- Decode received data
	partmgmt.setConfig(decodedData)
end

M.applyPartConfig = applyPartConfig

return M
