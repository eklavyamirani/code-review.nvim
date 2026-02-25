-- code-review.nvim: Review pull requests in Neovim
local M = {}

local config = require("code-review.config")

--- Setup the plugin with user options
---@param opts? table User configuration options
function M.setup(opts)
  config.setup(opts)
end

return M
