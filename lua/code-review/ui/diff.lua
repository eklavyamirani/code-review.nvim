-- Diff rendering for code-review.nvim (unified and side-by-side views)
local ui = require("code-review.ui")
local git = require("code-review.git")

local M = {}

-- Track current diff buffers and windows
M.state = {
  mode = "split", -- "unified" or "split"
  bufs = {},      -- list of buffer numbers
  wins = {},      -- list of window IDs
  file_path = nil,
  cursor_line = 1,
}

--- Render a unified diff view for a file
---@param file_diff FileDiff Parsed file diff
---@param comments? Comment[] Comments for this file
---@return number bufnr The buffer with the rendered diff
function M.render_unified(file_diff, comments)
  local lines = {}
  local highlights = {} -- {line_idx, hl_group}

  -- Header
  table.insert(lines, "--- " .. file_diff.old_file)
  table.insert(lines, "+++ " .. file_diff.new_file)
  table.insert(highlights, { #lines - 1, "CodeReviewRemove" })
  table.insert(highlights, { #lines, "CodeReviewAdd" })

  -- Build comment lookup: line_number -> comments
  local comment_map = {}
  if comments then
    for _, c in ipairs(comments) do
      if not comment_map[c.line] then
        comment_map[c.line] = {}
      end
      table.insert(comment_map[c.line], c)
    end
  end

  for _, hunk in ipairs(file_diff.hunks) do
    table.insert(lines, hunk.header)
    table.insert(highlights, { #lines, "CodeReviewHunkHeader" })

    for _, dl in ipairs(hunk.lines) do
      local prefix = " "
      local hl_group = nil
      if dl.type == "add" then
        prefix = "+"
        hl_group = "CodeReviewAdd"
      elseif dl.type == "remove" then
        prefix = "-"
        hl_group = "CodeReviewRemove"
      end
      table.insert(lines, prefix .. dl.text)
      if hl_group then
        table.insert(highlights, { #lines, hl_group })
      end

      -- Inline comments
      local line_num = dl.new_line or dl.old_line
      if line_num and comment_map[line_num] then
        for _, c in ipairs(comment_map[line_num]) do
          table.insert(lines, "  💬 " .. c.author .. ": " .. c.body:gsub("\n", " "))
          table.insert(highlights, { #lines, "CodeReviewComment" })
        end
      end
    end
  end

  local buf = ui.create_buf({ name = "[CodeReview] " .. file_diff.new_file, filetype = "diff" })
  ui.set_lines(buf, lines)

  -- Apply highlights
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf, ui.ns, hl[2], hl[1] - 1, 0, -1)
  end

  return buf
end

--- Render side-by-side diff view for a file
---@param file_diff FileDiff Parsed file diff
---@param pr_base_ref string Base ref for getting old file content
---@param pr_head_ref string Head ref for getting new file content
---@param comments? Comment[]
---@return number left_buf, number right_buf
function M.render_split(file_diff, pr_base_ref, pr_head_ref, comments)
  -- Get full file contents
  local old_content = git.file_at_ref(pr_base_ref, file_diff.old_file) or ""
  local new_content = git.file_at_ref(pr_head_ref, file_diff.new_file) or ""

  local old_lines = vim.split(old_content, "\n", { plain = true })
  local new_lines = vim.split(new_content, "\n", { plain = true })

  -- Detect filetype from extension
  local ext = file_diff.new_file:match("%.(%w+)$")
  local ft = ext and vim.filetype.match({ filename = "file." .. ext }) or ""

  local left_buf = ui.create_buf({ name = "[CodeReview] " .. file_diff.old_file .. " (base)", filetype = ft })
  local right_buf = ui.create_buf({ name = "[CodeReview] " .. file_diff.new_file .. " (head)", filetype = ft })

  ui.set_lines(left_buf, old_lines)
  ui.set_lines(right_buf, new_lines)

  -- Highlight changed lines using hunk data
  local removed_lines = {}
  local added_lines = {}
  for _, hunk in ipairs(file_diff.hunks) do
    for _, dl in ipairs(hunk.lines) do
      if dl.type == "remove" and dl.old_line then
        removed_lines[dl.old_line] = true
      elseif dl.type == "add" and dl.new_line then
        added_lines[dl.new_line] = true
      end
    end
  end

  for line_num, _ in pairs(removed_lines) do
    if line_num <= #old_lines then
      vim.api.nvim_buf_add_highlight(left_buf, ui.ns, "CodeReviewRemove", line_num - 1, 0, -1)
    end
  end
  for line_num, _ in pairs(added_lines) do
    if line_num <= #new_lines then
      vim.api.nvim_buf_add_highlight(right_buf, ui.ns, "CodeReviewAdd", line_num - 1, 0, -1)
    end
  end

  -- Add inline comments as virtual text on the right buffer
  if comments then
    for _, c in ipairs(comments) do
      if c.line and c.line <= #new_lines then
        vim.api.nvim_buf_set_extmark(right_buf, ui.ns, c.line - 1, 0, {
          virt_lines = {
            { { "  💬 " .. c.author .. ": " .. c.body:gsub("\n", " "), "CodeReviewComment" } },
          },
        })
      end
    end
  end

  return left_buf, right_buf
end

--- Open the diff view in the current tab
---@param file_diff FileDiff
---@param pr table PR metadata (needs base_ref, head_ref)
---@param comments? Comment[]
---@param mode? "unified"|"split"
function M.open(file_diff, pr, comments, mode)
  mode = mode or M.state.mode
  M.close()

  M.state.mode = mode
  M.state.file_path = file_diff.new_file

  if mode == "unified" then
    local buf = M.render_unified(file_diff, comments)
    vim.cmd("tabnew")
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    M.state.bufs = { buf }
    M.state.wins = { win }
  else
    local left_buf, right_buf = M.render_split(file_diff, pr.base_ref, pr.head_ref, comments)
    vim.cmd("tabnew")
    local left_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(left_win, left_buf)
    vim.cmd("vsplit")
    local right_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(right_win, right_buf)

    -- Enable Neovim's built-in diff mode for cursor sync and folding
    vim.api.nvim_win_call(left_win, function()
      vim.cmd("diffthis")
    end)
    vim.api.nvim_win_call(right_win, function()
      vim.cmd("diffthis")
    end)

    M.state.bufs = { left_buf, right_buf }
    M.state.wins = { left_win, right_win }
  end
end

--- Close the current diff view
function M.close()
  for _, buf in ipairs(M.state.bufs) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  M.state.bufs = {}
  M.state.wins = {}
  M.state.file_path = nil
end

--- Toggle between unified and split modes
---@param file_diff FileDiff
---@param pr table
---@param comments? Comment[]
function M.toggle(file_diff, pr, comments)
  -- Save cursor position
  local cursor_line = 1
  if #M.state.wins > 0 and vim.api.nvim_win_is_valid(M.state.wins[1]) then
    cursor_line = vim.api.nvim_win_get_cursor(M.state.wins[1])[1]
  end

  local new_mode = M.state.mode == "unified" and "split" or "unified"
  M.open(file_diff, pr, comments, new_mode)

  -- Restore cursor roughly
  M.state.cursor_line = cursor_line
  if #M.state.wins > 0 and vim.api.nvim_win_is_valid(M.state.wins[1]) then
    local max_line = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(M.state.wins[1]))
    pcall(vim.api.nvim_win_set_cursor, M.state.wins[1], { math.min(cursor_line, max_line), 0 })
  end
end

return M
