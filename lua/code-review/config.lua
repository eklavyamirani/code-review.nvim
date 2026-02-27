-- Configuration for code-review.nvim
local M = {}

---@class CodeReviewConfig
---@field provider? string Provider name override (auto-detected if nil)
---@field diff_mode? "unified"|"split" Default diff view mode
---@field keymaps? table Custom keymap overrides
local defaults = {
  provider = nil,
  diff_mode = "split",
  file_picker = "auto", -- "auto", "netrw", "mini_files"
  keymaps = {
    next_file = "]f",
    prev_file = "[f",
    next_comment = "]c",
    prev_comment = "[c",
    add_comment = "<leader>cc",
    toggle_diff = "<leader>ct",
    next_hunk = "]h",
    prev_hunk = "[h",
    reply_comment = "<leader>cr",
    toggle_reviewed = "<leader>cv",
  },
}

M.values = vim.deepcopy(defaults)

--- Merge user options with defaults
---@param opts? table
function M.setup(opts)
  M.values = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
end

return M
