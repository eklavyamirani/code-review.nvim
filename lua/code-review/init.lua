-- code-review.nvim: Review pull requests in Neovim
local M = {}

local config = require("code-review.config")

--- Setup the plugin with user options
---@param opts? table User configuration options
function M.setup(opts)
  config.setup(opts)
  require("code-review.ui").setup()
end

--- Start a review session for the current branch's PR
function M.start()
  M.setup()
  local review = require("code-review.review")
  local diff_ui = require("code-review.ui.diff")
  local file_list_ui = require("code-review.ui.file_list")

  local session, err = review.start()
  if not session then
    vim.notify("code-review: " .. (err or "Failed to start session"), vim.log.levels.ERROR)
    return
  end

  vim.notify(
    string.format("code-review: Reviewing PR #%d — %s (%d files)",
      session.pr.number, session.pr.title, #session.files),
    vim.log.levels.INFO
  )

  -- Open the first file's diff
  local file_diff = review.current_file_diff()
  if file_diff then
    local comments = review.comments_for_file(file_diff.new_file)
    diff_ui.open(file_diff, session.pr, comments, config.values.diff_mode)
  end

  -- Setup keybindings for the session
  M._setup_keymaps(session)
end

--- Close the current review session
function M.close()
  local review = require("code-review.review")
  local diff_ui = require("code-review.ui.diff")
  diff_ui.close()
  review.close()
  vim.notify("code-review: Session closed", vim.log.levels.INFO)
end

--- Navigate to the next file in the review
function M.next_file()
  local review = require("code-review.review")
  local diff_ui = require("code-review.ui.diff")
  local file = review.next_file()
  if file then
    local file_diff = review.current_file_diff()
    if file_diff and review.current then
      local comments = review.comments_for_file(file.path)
      diff_ui.open(file_diff, review.current.pr, comments)
    end
  end
end

--- Navigate to the previous file in the review
function M.prev_file()
  local review = require("code-review.review")
  local diff_ui = require("code-review.ui.diff")
  local file = review.prev_file()
  if file then
    local file_diff = review.current_file_diff()
    if file_diff and review.current then
      local comments = review.comments_for_file(file.path)
      diff_ui.open(file_diff, review.current.pr, comments)
    end
  end
end

--- Toggle diff mode
function M.toggle_diff()
  local review = require("code-review.review")
  local diff_ui = require("code-review.ui.diff")
  if not review.current then return end
  local file_diff = review.current_file_diff()
  if file_diff then
    local comments = review.comments_for_file(file_diff.new_file)
    diff_ui.toggle(file_diff, review.current.pr, comments)
  end
end

--- Add a comment at the current cursor position
function M.add_comment()
  local review = require("code-review.review")
  local comments_ui = require("code-review.ui.comments")
  if not review.current then
    vim.notify("code-review: No active review session", vim.log.levels.WARN)
    return
  end

  local file = review.current_file()
  if not file then return end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]

  comments_ui.open_input(file.path, line_num, function(body)
    comments_ui.submit(review.current, file.path, line_num, body)
  end)
end

--- Get statusline component
---@return string
function M.statusline()
  local review = require("code-review.review")
  if not review.current or not review.current.active then
    return ""
  end
  local s = review.current
  local file = review.current_file()
  local file_name = file and vim.fn.fnamemodify(file.path, ":t") or "?"
  return string.format("PR #%d | %s [%d/%d] | 💬 %d",
    s.pr.number, file_name, s.current_file_idx, #s.files, #s.comments)
end

--- Setup keymaps for the review session
---@param _session table
function M._setup_keymaps(_session)
  local km = config.values.keymaps
  local opts = { noremap = true, silent = true }

  vim.keymap.set("n", km.next_file, M.next_file, vim.tbl_extend("force", opts, { desc = "Next file" }))
  vim.keymap.set("n", km.prev_file, M.prev_file, vim.tbl_extend("force", opts, { desc = "Previous file" }))
  vim.keymap.set("n", km.toggle_diff, M.toggle_diff, vim.tbl_extend("force", opts, { desc = "Toggle diff mode" }))
  vim.keymap.set("n", km.add_comment, M.add_comment, vim.tbl_extend("force", opts, { desc = "Add comment" }))
end

return M
