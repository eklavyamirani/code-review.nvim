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
  hunk_positions = {}, -- list of {line} positions in the current buffer(s) where hunks start
}

--- Render a unified diff view for a file
--- Shows the full HEAD file with highlighted changes.
--- Removed lines shown as collapsible virtual text.
--- Comments shown as collapsible virtual text markers.
---@param file_diff FileDiff Parsed file diff
---@param pr_head_ref string Head ref for getting file content
---@param comments? Comment[] Comments for this file
---@return number bufnr The buffer with the rendered view
function M.render_unified(file_diff, pr_head_ref, comments)
  local new_content = git.file_at_ref(pr_head_ref, file_diff.new_file) or ""
  local new_lines = vim.split(new_content, "\n", { plain = true })

  -- Detect filetype
  local ext = file_diff.new_file:match("%.(%w+)$")
  local ft = ext and vim.filetype.match({ filename = "file." .. ext }) or ""

  local buf = ui.create_buf({ name = "[CodeReview] " .. file_diff.new_file, filetype = ft })
  ui.set_lines(buf, new_lines)

  -- Build lookup maps
  local added_lines = {}     -- new_line -> true
  local removed_map = {}     -- new_line -> list of removed DiffLines (inserted BEFORE this line)
  local hunk_positions = {}

  for _, hunk in ipairs(file_diff.hunks) do
    table.insert(hunk_positions, hunk.new_start)

    -- Collect removed lines per hunk, keyed by the new_line they appear before
    local pending_removed = {}
    for _, dl in ipairs(hunk.lines) do
      if dl.type == "remove" then
        table.insert(pending_removed, dl)
      elseif dl.type == "add" then
        added_lines[dl.new_line] = true
        -- Attach pending removed lines to this added line
        if #pending_removed > 0 then
          if not removed_map[dl.new_line] then
            removed_map[dl.new_line] = {}
          end
          for _, r in ipairs(pending_removed) do
            table.insert(removed_map[dl.new_line], r)
          end
          pending_removed = {}
        end
      elseif dl.type == "context" then
        -- Remaining removed lines attach to this context line
        if #pending_removed > 0 then
          if not removed_map[dl.new_line] then
            removed_map[dl.new_line] = {}
          end
          for _, r in ipairs(pending_removed) do
            table.insert(removed_map[dl.new_line], r)
          end
          pending_removed = {}
        end
      end
    end
    -- Any trailing removed lines (deleted at end of hunk)
    if #pending_removed > 0 then
      -- Attach to line after hunk ends
      local after_line = hunk.new_start + hunk.new_count
      if not removed_map[after_line] then
        removed_map[after_line] = {}
      end
      for _, r in ipairs(pending_removed) do
        table.insert(removed_map[after_line], r)
      end
    end
  end

  -- Build comment map (line -> comments)
  local comment_map = {}
  if comments then
    local comments_ui = require("code-review.ui.comments")
    local threads = comments_ui.build_threads(comments)
    for _, thread in ipairs(threads) do
      local line = thread.root.line
      if line then
        if not comment_map[line] then
          comment_map[line] = {}
        end
        table.insert(comment_map[line], thread)
      end
    end
  end

  -- Track collapsible regions for expand/collapse
  -- collapsed_items: list of {line, type, data, extmark_id}
  M.state.collapsed_items = {}

  -- Apply highlights and virtual text
  for line_num, _ in pairs(added_lines) do
    if line_num <= #new_lines then
      vim.api.nvim_buf_add_highlight(buf, ui.ns, "CodeReviewAdd", line_num - 1, 0, -1)
    end
  end

  -- Add removed lines and comments as virtual text (collapsed by default)
  for line_num = 1, #new_lines + 1 do
    local removed = removed_map[line_num]
    if removed and #removed > 0 then
      local target_line = math.min(line_num, #new_lines) - 1
      if target_line < 0 then target_line = 0 end
      local marker = "[−" .. #removed .. " line" .. (#removed > 1 and "s" or "") .. " removed]"
      local extmark_id = vim.api.nvim_buf_set_extmark(buf, ui.ns, target_line, 0, {
        virt_lines = {
          { { "  " .. marker, "CodeReviewRemove" } },
        },
        virt_lines_above = (line_num <= #new_lines),
      })
      table.insert(M.state.collapsed_items, {
        line = target_line,
        type = "removed",
        data = removed,
        extmark_id = extmark_id,
        expanded = false,
        buf = buf,
      })
    end

    local threads = comment_map[line_num]
    if threads then
      local target_line = math.min(line_num, #new_lines) - 1
      if target_line < 0 then target_line = 0 end
      local total = 0
      for _, t in ipairs(threads) do
        total = total + 1 + #t.replies
      end
      local marker = "[💬 " .. total .. " comment" .. (total > 1 and "s" or "") .. "]"
      local extmark_id = vim.api.nvim_buf_set_extmark(buf, ui.ns, target_line, 0, {
        virt_lines = {
          { { "  " .. marker, "CodeReviewComment" } },
        },
      })
      table.insert(M.state.collapsed_items, {
        line = target_line,
        type = "comments",
        data = threads,
        extmark_id = extmark_id,
        expanded = false,
        buf = buf,
      })
    end
  end

  return buf, hunk_positions
end

--- Toggle expand/collapse for the item nearest the cursor
---@param buf number
---@param line number 0-based line
---@param action? "expand"|"collapse"|"toggle"
function M.toggle_collapse(buf, line, action)
  action = action or "toggle"
  if not M.state.collapsed_items then return end

  -- Find the nearest collapsed item to the cursor line
  local nearest = nil
  local min_dist = math.huge
  for _, item in ipairs(M.state.collapsed_items) do
    if item.buf == buf then
      local dist = math.abs(item.line - line)
      if dist < min_dist then
        min_dist = dist
        nearest = item
      end
    end
  end

  if not nearest or min_dist > 2 then return end

  local should_expand
  if action == "expand" then should_expand = true
  elseif action == "collapse" then should_expand = false
  else should_expand = not nearest.expanded
  end

  -- Delete old extmark
  vim.api.nvim_buf_del_extmark(buf, ui.ns, nearest.extmark_id)

  if should_expand then
    local virt_lines = {}
    if nearest.type == "removed" then
      for _, dl in ipairs(nearest.data) do
        table.insert(virt_lines, {
          { "  - " .. dl.text, "CodeReviewRemove" },
        })
      end
    elseif nearest.type == "comments" then
      for _, thread in ipairs(nearest.data) do
        table.insert(virt_lines, {
          { "  💬 " .. thread.root.author .. ": " .. thread.root.body:gsub("\n", " "), "CodeReviewComment" },
        })
        for _, reply in ipairs(thread.replies) do
          table.insert(virt_lines, {
            { "    ↳ " .. reply.author .. ": " .. reply.body:gsub("\n", " "), "CodeReviewComment" },
          })
        end
      end
    end
    nearest.extmark_id = vim.api.nvim_buf_set_extmark(buf, ui.ns, nearest.line, 0, {
      virt_lines = virt_lines,
      virt_lines_above = (nearest.type == "removed"),
    })
    nearest.expanded = true
  else
    -- Collapse back to marker
    local marker
    if nearest.type == "removed" then
      local n = #nearest.data
      marker = "[−" .. n .. " line" .. (n > 1 and "s" or "") .. " removed]"
    else
      local total = 0
      for _, t in ipairs(nearest.data) do
        total = total + 1 + #t.replies
      end
      marker = "[💬 " .. total .. " comment" .. (total > 1 and "s" or "") .. "]"
    end
    local hl = nearest.type == "removed" and "CodeReviewRemove" or "CodeReviewComment"
    nearest.extmark_id = vim.api.nvim_buf_set_extmark(buf, ui.ns, nearest.line, 0, {
      virt_lines = {
        { { "  " .. marker, hl } },
      },
      virt_lines_above = (nearest.type == "removed"),
    })
    nearest.expanded = false
  end
end

--- Toggle all collapsed items in the current buffer
---@param buf number
---@param action? "expand"|"collapse"
function M.toggle_all_collapsed(buf, action)
  if not M.state.collapsed_items then return end
  for _, item in ipairs(M.state.collapsed_items) do
    if item.buf == buf then
      if action == "expand" and not item.expanded then
        M.toggle_collapse(buf, item.line, "expand")
      elseif action == "collapse" and item.expanded then
        M.toggle_collapse(buf, item.line, "collapse")
      elseif not action then
        M.toggle_collapse(buf, item.line, "toggle")
      end
    end
  end
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

  -- Highlight changed lines and track hunk positions
  local removed_lines = {}
  local added_lines = {}
  local hunk_positions = {}
  for _, hunk in ipairs(file_diff.hunks) do
    -- Track the start position of each hunk in the right (new) buffer
    table.insert(hunk_positions, hunk.new_start)
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

  return left_buf, right_buf, hunk_positions
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
    local buf, hunk_positions = M.render_unified(file_diff, pr.head_ref, comments)
    vim.cmd("tabnew")
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    M.state.bufs = { buf }
    M.state.wins = { win }
    M.state.hunk_positions = hunk_positions

    -- Setup expand/collapse keymaps
    vim.keymap.set("n", "zo", function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      M.toggle_collapse(buf, cursor[1] - 1, "expand")
    end, { buffer = buf, desc = "Expand collapsed item" })
    vim.keymap.set("n", "zc", function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      M.toggle_collapse(buf, cursor[1] - 1, "collapse")
    end, { buffer = buf, desc = "Collapse expanded item" })
    vim.keymap.set("n", "<CR>", function()
      local cursor = vim.api.nvim_win_get_cursor(0)
      M.toggle_collapse(buf, cursor[1] - 1, "toggle")
    end, { buffer = buf, desc = "Toggle collapsed item" })
    vim.keymap.set("n", "zA", function()
      M.toggle_all_collapsed(buf)
    end, { buffer = buf, desc = "Toggle all collapsed items" })
  else
    local left_buf, right_buf, hunk_positions = M.render_split(file_diff, pr.base_ref, pr.head_ref, comments)
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
    M.state.hunk_positions = hunk_positions
  end
end

--- Navigate to the next hunk in the current diff buffer
---@return number|nil line The line number jumped to
function M.next_hunk()
  if #M.state.hunk_positions == 0 then return nil end
  local cursor_line = 1
  if #M.state.wins > 0 and vim.api.nvim_win_is_valid(M.state.wins[#M.state.wins]) then
    cursor_line = vim.api.nvim_win_get_cursor(M.state.wins[#M.state.wins])[1]
  end

  -- Find next hunk after cursor
  for _, pos in ipairs(M.state.hunk_positions) do
    if pos > cursor_line then
      for _, win in ipairs(M.state.wins) do
        if vim.api.nvim_win_is_valid(win) then
          pcall(vim.api.nvim_win_set_cursor, win, { pos, 0 })
        end
      end
      return pos
    end
  end

  -- Wrap to first hunk
  local pos = M.state.hunk_positions[1]
  for _, win in ipairs(M.state.wins) do
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_set_cursor, win, { pos, 0 })
    end
  end
  return pos
end

--- Navigate to the previous hunk in the current diff buffer
---@return number|nil line The line number jumped to
function M.prev_hunk()
  if #M.state.hunk_positions == 0 then return nil end
  local cursor_line = 1
  if #M.state.wins > 0 and vim.api.nvim_win_is_valid(M.state.wins[#M.state.wins]) then
    cursor_line = vim.api.nvim_win_get_cursor(M.state.wins[#M.state.wins])[1]
  end

  -- Find previous hunk before cursor
  for i = #M.state.hunk_positions, 1, -1 do
    local pos = M.state.hunk_positions[i]
    if pos < cursor_line then
      for _, win in ipairs(M.state.wins) do
        if vim.api.nvim_win_is_valid(win) then
          pcall(vim.api.nvim_win_set_cursor, win, { pos, 0 })
        end
      end
      return pos
    end
  end

  -- Wrap to last hunk
  local pos = M.state.hunk_positions[#M.state.hunk_positions]
  for _, win in ipairs(M.state.wins) do
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_set_cursor, win, { pos, 0 })
    end
  end
  return pos
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
