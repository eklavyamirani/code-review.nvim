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
  ai = {
    cmd = nil,         -- CLI command to pipe diff into (e.g., "gh copilot suggest", "claude -p")
    context = "file",  -- "file" (current file diff + file list) or "pr" (entire PR diff)
  },
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

--- Set a config value at runtime (dot-notation key path)
--- e.g., set("ai.cmd", "claude -p")
---@param key string Dot-separated key path
---@param value any
function M.set(key, value)
  local keys = vim.split(key, ".", { plain = true })
  local tbl = M.values
  for i = 1, #keys - 1 do
    if type(tbl[keys[i]]) ~= "table" then
      tbl[keys[i]] = {}
    end
    tbl = tbl[keys[i]]
  end
  tbl[keys[#keys]] = value
end

return M
