local M = {}


-- GET A TABLE LENGTH
local function tableLength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end


M.tableLength = tableLength


return M