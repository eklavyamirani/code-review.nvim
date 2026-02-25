-- Utility functions
local M = {}

function M.trim(s)
  return s:match("^%s*(.-)%s*$")
end

function M.split(s, sep)
  local parts = {}
  for part in s:gmatch("[^" .. sep .. "]+") do
    table.insert(parts, part)
  end
  return parts
end

return M
