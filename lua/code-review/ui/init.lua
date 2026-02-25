-- UI coordinator for code-review.nvim
local M = {}

-- Namespace for extmarks and highlights
M.ns = vim.api.nvim_create_namespace("code-review")

-- Highlight groups
local function setup_highlights()
  local hl = vim.api.nvim_set_hl
  hl(0, "CodeReviewAdd", { default = true, bg = "#2a4a2a" })
  hl(0, "CodeReviewRemove", { default = true, bg = "#4a2a2a" })
  hl(0, "CodeReviewChange", { default = true, bg = "#4a4a2a" })
  hl(0, "CodeReviewHunkHeader", { default = true, fg = "#888888", italic = true })
  hl(0, "CodeReviewComment", { default = true, fg = "#ffaa00", italic = true })
  hl(0, "CodeReviewFileListCurrent", { default = true, bold = true })
  hl(0, "CodeReviewFileListComment", { default = true, fg = "#ffaa00" })
  hl(0, "CodeReviewSignAdd", { default = true, fg = "#00cc00" })
  hl(0, "CodeReviewSignRemove", { default = true, fg = "#cc0000" })
end

--- Initialize the UI module
function M.setup()
  setup_highlights()
end

--- Create a scratch buffer with given options
---@param opts? {name?: string, filetype?: string, modifiable?: boolean, listed?: boolean}
---@return number bufnr
function M.create_buf(opts)
  opts = opts or {}
  local buf = vim.api.nvim_create_buf(opts.listed or false, true)
  if opts.name then
    vim.api.nvim_buf_set_name(buf, opts.name)
  end
  if opts.filetype then
    vim.bo[buf].filetype = opts.filetype
  end
  vim.bo[buf].modifiable = opts.modifiable or false
  vim.bo[buf].bufhidden = "wipe"
  return buf
end

--- Set buffer lines (handles modifiable toggle)
---@param buf number
---@param lines string[]
function M.set_lines(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

return M
