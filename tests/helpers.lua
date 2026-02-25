-- Test helpers for code-review.nvim
local M = {}

--- Reset plugin state between tests
function M.reset()
  package.loaded["code-review"] = nil
  package.loaded["code-review.config"] = nil
  package.loaded["code-review.git"] = nil
  package.loaded["code-review.utils"] = nil
end

return M
