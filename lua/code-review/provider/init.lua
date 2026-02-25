-- Abstract provider interface for code-review.nvim
local M = {}

---@class PR
---@field id string|number
---@field number number
---@field title string
---@field body string
---@field base_ref string
---@field head_ref string
---@field author string
---@field url string

---@class Comment
---@field id string|number
---@field body string
---@field path string File path
---@field line number Line number in the diff
---@field side "LEFT"|"RIGHT" Which side of the diff
---@field author string
---@field created_at string
---@field in_reply_to string|number|nil Parent comment ID for threads

--- Required methods that every provider must implement
local required_methods = {
  "get_pr",
  "get_comments",
  "post_comment",
}

--- Validate that a provider implements all required methods
---@param provider table
---@return boolean valid
---@return string|nil error
function M.validate(provider)
  if not provider.name or type(provider.name) ~= "string" then
    return false, "Provider must have a 'name' string field"
  end
  for _, method in ipairs(required_methods) do
    if type(provider[method]) ~= "function" then
      return false, "Provider '" .. provider.name .. "' missing required method: " .. method
    end
  end
  return true, nil
end

--- Registry of known providers
---@type table<string, table>
M.registry = {}

--- Register a provider
---@param provider table
function M.register(provider)
  local valid, err = M.validate(provider)
  if not valid then
    error(err)
  end
  M.registry[provider.name] = provider
end

--- Get a provider by name
---@param name string
---@return table|nil provider
function M.get(name)
  return M.registry[name]
end

return M
