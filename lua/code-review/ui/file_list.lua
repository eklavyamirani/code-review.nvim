-- Changed files list panel for code-review.nvim
local ui = require("code-review.ui")

local M = {}

-- Status icons
local status_icons = {
  A = "+",
  M = "~",
  D = "-",
  R = "→",
}

--- Render the file list into a buffer
---@param file_list table[] From review.file_list()
---@param on_select fun(idx: number) Callback when a file is selected
---@return number bufnr
function M.render(file_list, on_select)
  local lines = {}
  local highlights = {}

  table.insert(lines, "Changed Files (" .. #file_list .. ")")
  table.insert(lines, string.rep("─", 40))

  for i, f in ipairs(file_list) do
    local icon = status_icons[f.status] or "?"
    local comment_marker = f.has_comments and " 💬" or ""
    local current_marker = f.is_current and " ◀" or ""
    local line = string.format("  %s %s%s%s", icon, f.path, comment_marker, current_marker)
    table.insert(lines, line)

    if f.is_current then
      table.insert(highlights, { #lines, "CodeReviewFileListCurrent" })
    end
    if f.has_comments then
      table.insert(highlights, { #lines, "CodeReviewFileListComment" })
    end
  end

  local buf = ui.create_buf({ name = "[CodeReview] Files", filetype = "code-review-files" })
  ui.set_lines(buf, lines)

  -- Apply highlights
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf, ui.ns, hl[2], hl[1] - 1, 0, -1)
  end

  -- Set up keymap for selecting files
  vim.bo[buf].modifiable = false
  vim.keymap.set("n", "<CR>", function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line_idx = cursor[1] - 2 -- account for header lines
    if line_idx >= 1 and line_idx <= #file_list then
      on_select(line_idx)
    end
  end, { buffer = buf, desc = "Select file" })

  return buf
end

return M
