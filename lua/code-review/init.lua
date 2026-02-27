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
  local file_picker = require("code-review.ui.file_picker")

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

  -- Setup keybindings for the session
  M._setup_keymaps(session)

  -- Open file picker — selecting a file opens its diff
  file_picker.open(session, function(file_path)
    local file = review.goto_file_by_path(file_path)
    if file then
      local file_diff = review.current_file_diff()
      if file_diff then
        local comments = review.comments_for_file(file.path)
        diff_ui.open(file_diff, session.pr, comments, config.values.diff_mode)
      end
    end
  end)
end

--- Close the current review session
function M.close()
  local review = require("code-review.review")
  local diff_ui = require("code-review.ui.diff")
  local file_picker = require("code-review.ui.file_picker")
  diff_ui.close()
  -- Clean up temp directory
  if review.current and review.current._temp_dir then
    file_picker.cleanup(review.current._temp_dir)
  end
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

--- Navigate to the next comment
function M.next_comment()
  local review = require("code-review.review")
  local diff_ui = require("code-review.ui.diff")
  if not review.current then return end

  local comment, file = review.next_comment()
  if comment and file then
    -- If we switched files, open the new file's diff
    local cur_file = review.current_file()
    if cur_file and cur_file.path == file.path then
      local file_diff = review.current_file_diff()
      if file_diff then
        -- Check if we need to reopen the diff (file changed)
        if diff_ui.state.file_path ~= file.path then
          local comments = review.comments_for_file(file.path)
          diff_ui.open(file_diff, review.current.pr, comments)
        end
        -- Move cursor to the comment line
        if #diff_ui.state.wins > 0 and vim.api.nvim_win_is_valid(diff_ui.state.wins[#diff_ui.state.wins]) then
          local win = diff_ui.state.wins[#diff_ui.state.wins]
          local max_line = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))
          local target = math.min(comment.line, max_line)
          pcall(vim.api.nvim_win_set_cursor, win, { target, 0 })
        end
      end
    end
  else
    vim.notify("code-review: No more comments", vim.log.levels.INFO)
  end
end

--- Navigate to the previous comment
function M.prev_comment()
  local review = require("code-review.review")
  local diff_ui = require("code-review.ui.diff")
  if not review.current then return end

  local comment, file = review.prev_comment()
  if comment and file then
    local cur_file = review.current_file()
    if cur_file and cur_file.path == file.path then
      local file_diff = review.current_file_diff()
      if file_diff then
        if diff_ui.state.file_path ~= file.path then
          local comments = review.comments_for_file(file.path)
          diff_ui.open(file_diff, review.current.pr, comments)
        end
        if #diff_ui.state.wins > 0 and vim.api.nvim_win_is_valid(diff_ui.state.wins[#diff_ui.state.wins]) then
          local win = diff_ui.state.wins[#diff_ui.state.wins]
          local max_line = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))
          local target = math.min(comment.line, max_line)
          pcall(vim.api.nvim_win_set_cursor, win, { target, 0 })
        end
      end
    end
  else
    vim.notify("code-review: No more comments", vim.log.levels.INFO)
  end
end

--- Navigate to the next hunk
function M.next_hunk()
  local diff_ui = require("code-review.ui.diff")
  diff_ui.next_hunk()
end

--- Navigate to the previous hunk
function M.prev_hunk()
  local diff_ui = require("code-review.ui.diff")
  diff_ui.prev_hunk()
end

--- Submit a PR review (approve, request changes, or comment)
function M.submit_review()
  local review = require("code-review.review")
  if not review.current then
    vim.notify("code-review: No active review session", vim.log.levels.WARN)
    return
  end

  local choices = { "APPROVE", "REQUEST_CHANGES", "COMMENT" }
  vim.ui.select(choices, { prompt = "Review type:" }, function(choice)
    if not choice then return end

    -- Open a floating window for the review body
    local comments_ui = require("code-review.ui.comments")
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "markdown"
    vim.bo[buf].bufhidden = "wipe"

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "<!-- " .. choice .. " review for PR #" .. review.current.pr.number .. " -->",
      "<!-- Write your review summary below, then press <leader>cs to submit -->",
      "",
    })

    local width = math.min(80, math.floor(vim.o.columns * 0.6))
    local height = math.min(10, math.floor(vim.o.lines * 0.3))
    local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      width = width,
      height = height,
      style = "minimal",
      border = "rounded",
      title = " 📝 " .. choice .. " Review ",
      title_pos = "center",
    })

    vim.api.nvim_win_set_cursor(win, { 3, 0 })
    vim.cmd("startinsert")

    vim.keymap.set("n", "<leader>cs", function()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local body_lines = {}
      for _, line in ipairs(lines) do
        if not line:match("^<!%-%-") then
          table.insert(body_lines, line)
        end
      end
      local body = vim.trim(table.concat(body_lines, "\n"))
      vim.api.nvim_win_close(win, true)

      local provider = review.current.provider
      if provider.submit_review then
        local result, err = provider.submit_review(
          review.current.owner, review.current.repo,
          review.current.pr.number, choice, body
        )
        if result then
          vim.notify("Review submitted: " .. choice, vim.log.levels.INFO)
        else
          vim.notify("Failed to submit review: " .. (err or "unknown"), vim.log.levels.ERROR)
        end
      else
        vim.notify("code-review: Provider does not support review submission", vim.log.levels.WARN)
      end
    end, { buffer = buf, desc = "Submit review" })

    vim.keymap.set("n", "q", function()
      vim.api.nvim_win_close(win, true)
    end, { buffer = buf, desc = "Cancel review" })
    vim.keymap.set("n", "<Esc>", function()
      vim.api.nvim_win_close(win, true)
    end, { buffer = buf, desc = "Cancel review" })
  end)
end

--- Reply to the comment at/near the current cursor position
function M.reply_comment()
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

  -- Find the nearest comment at or before the cursor line
  local file_comments = review.comments_for_file(file.path)
  local nearest = nil
  for _, c in ipairs(file_comments) do
    if c.line and c.line <= line_num and not c.in_reply_to then
      if not nearest or c.line > nearest.line then
        nearest = c
      end
    end
  end

  if not nearest then
    vim.notify("code-review: No comment found near cursor to reply to", vim.log.levels.WARN)
    return
  end

  comments_ui.open_input(file.path, nearest.line, function(body)
    local provider = review.current.provider
    if provider.reply_to_comment then
      local comment, err = provider.reply_to_comment(
        review.current.owner, review.current.repo,
        review.current.pr.number, nearest.id, body
      )
      if comment then
        table.insert(review.current.comments, comment)
        vim.notify("Reply posted successfully", vim.log.levels.INFO)
      else
        vim.notify("Failed to post reply: " .. (err or "unknown"), vim.log.levels.ERROR)
      end
    else
      vim.notify("code-review: Provider does not support reply", vim.log.levels.WARN)
    end
  end)
end

--- Refresh the current session
function M.refresh()
  local review = require("code-review.review")
  local diff_ui = require("code-review.ui.diff")
  if not review.current then
    vim.notify("code-review: No active review session", vim.log.levels.WARN)
    return
  end

  local ok, err = review.refresh()
  if ok then
    -- Re-render the current file diff
    local file_diff = review.current_file_diff()
    if file_diff then
      local file = review.current_file()
      local comments = file and review.comments_for_file(file.path) or {}
      diff_ui.open(file_diff, review.current.pr, comments)
    end
    vim.notify("code-review: Session refreshed", vim.log.levels.INFO)
  else
    vim.notify("code-review: " .. (err or "Failed to refresh"), vim.log.levels.ERROR)
  end
end

--- Toggle file review status
function M.toggle_reviewed()
  local review = require("code-review.review")
  if not review.current then return end
  local status = review.toggle_reviewed()
  if status ~= nil then
    local file = review.current_file()
    local label = status and "✓ reviewed" or "· pending"
    vim.notify("code-review: " .. (file and file.path or "file") .. " — " .. label, vim.log.levels.INFO)
  end
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
  local reviewed, total = review.review_progress()
  return string.format("PR #%d | %s [%d/%d] | 💬 %d | ✓ %d/%d",
    s.pr.number, file_name, s.current_file_idx, #s.files, #s.comments, reviewed, total)
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
  vim.keymap.set("n", km.next_comment, M.next_comment, vim.tbl_extend("force", opts, { desc = "Next comment" }))
  vim.keymap.set("n", km.prev_comment, M.prev_comment, vim.tbl_extend("force", opts, { desc = "Previous comment" }))
  vim.keymap.set("n", km.next_hunk, M.next_hunk, vim.tbl_extend("force", opts, { desc = "Next hunk" }))
  vim.keymap.set("n", km.prev_hunk, M.prev_hunk, vim.tbl_extend("force", opts, { desc = "Previous hunk" }))
  vim.keymap.set("n", km.reply_comment, M.reply_comment, vim.tbl_extend("force", opts, { desc = "Reply to comment" }))
  vim.keymap.set("n", km.toggle_reviewed, M.toggle_reviewed, vim.tbl_extend("force", opts, { desc = "Toggle file reviewed" }))
end

return M
