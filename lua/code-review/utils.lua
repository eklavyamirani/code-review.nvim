-- Shared utilities for code-review.nvim
local M = {}

--- Run a shell command and return stdout, stderr, exit code
---@param cmd string[]
---@param cwd? string Working directory
---@return string stdout
---@return string stderr
---@return number exit_code
function M.system(cmd, cwd)
  local result = vim.system(cmd, { text = true, cwd = cwd }):wait()
  return result.stdout or "", result.stderr or "", result.code
end

return M
