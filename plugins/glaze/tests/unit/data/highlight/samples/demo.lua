-- Lua sample
local M = {}

--[[ Block
comment ]]
function M.sum(...)
  local total = 0
  for _, v in ipairs({...}) do
    total = total + v
  end
  return total, "done", nil, true
end

print(M.sum(1, 2.5, 0x10), #"abc" .. [[long string]])
return M
