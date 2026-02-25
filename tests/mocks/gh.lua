-- Mock gh CLI responses for write operations
local M = {}

M.post_comment_response = {
  id = 999,
  body = "mock comment",
  path = "src/hello.lua",
  line = 5,
  user = { login = "test-user" },
  created_at = "2025-01-01T00:00:00Z",
}

--- Mock gh api call for posting a review comment
---@param _pr table PR object
---@param _file string File path
---@param _line number Line number
---@param _body string Comment body
---@return table comment Mock comment response
function M.post_comment(_pr, _file, _line, _body)
  return vim.deepcopy(M.post_comment_response)
end

return M
