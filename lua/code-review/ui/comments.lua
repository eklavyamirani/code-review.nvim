-- Comments UI for code-review.nvim
-- Handles displaying, writing, and submitting review comments
local ui = require("code-review.ui")

local M = {}

--- Open a floating window for writing a comment
---@param file_path string File being commented on
---@param line_num number Line number in the file
---@param on_submit fun(body: string) Callback with comment text
---@return number bufnr The comment input buffer
function M.open_input(file_path, line_num, on_submit)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].bufhidden = "wipe"

  -- Set initial content with placeholder
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "<!-- Comment on " .. file_path .. ":" .. line_num .. " -->",
    "<!-- Write your comment below, then press <leader>cs to submit -->",
    "",
  })
  -- Place cursor on the empty line
  local width = math.min(80, math.floor(vim.o.columns * 0.6))
  local height = math.min(10, math.floor(vim.o.lines * 0.3))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " 💬 Comment on " .. file_path .. ":" .. line_num .. " ",
    title_pos = "center",
  })

  -- Place cursor on the writable line
  vim.api.nvim_win_set_cursor(win, { 3, 0 })
  vim.cmd("startinsert")

  -- Submit keymap
  vim.keymap.set("n", "<leader>cs", function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    -- Filter out comment lines
    local body_lines = {}
    for _, line in ipairs(lines) do
      if not line:match("^<!%-%-") then
        table.insert(body_lines, line)
      end
    end
    local body = vim.trim(table.concat(body_lines, "\n"))
    if #body > 0 then
      vim.api.nvim_win_close(win, true)
      on_submit(body)
    else
      vim.notify("Comment body is empty", vim.log.levels.WARN)
    end
  end, { buffer = buf, desc = "Submit comment" })

  -- Cancel keymap
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, desc = "Cancel comment" })

  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf, desc = "Cancel comment" })

  return buf
end

--- Submit a comment via the provider
---@param review_session table The active review session
---@param file_path string
---@param line_num number
---@param body string
---@param callback? fun(comment: Comment|nil, err: string|nil)
function M.submit(review_session, file_path, line_num, body, callback)
  local provider = review_session.provider
  local owner = review_session.owner
  local repo = review_session.repo
  local pr = review_session.pr

  -- Get the head commit SHA for the comment
  local utils = require("code-review.utils")
  local stdout, _, code = utils.system({ "git", "rev-parse", pr.head_ref })
  if code ~= 0 then
    if callback then
      callback(nil, "Failed to get commit SHA for " .. pr.head_ref)
    end
    return
  end
  local commit_id = vim.trim(stdout)

  local comment, err = provider.post_comment(owner, repo, pr.number, file_path, line_num, body, commit_id)
  if comment then
    -- Add to session comments
    table.insert(review_session.comments, comment)
    vim.notify("Comment posted successfully", vim.log.levels.INFO)
  else
    vim.notify("Failed to post comment: " .. (err or "unknown error"), vim.log.levels.ERROR)
  end

  if callback then
    callback(comment, err)
  end
end

--- Build threaded comment structure from flat comments
---@param comments Comment[]
---@return table[] threads List of {root: Comment, replies: Comment[]}
function M.build_threads(comments)
  -- Index root comments (those without in_reply_to)
  local roots = {}
  local replies_map = {} -- comment_id -> replies list
  for _, c in ipairs(comments) do
    if not c.in_reply_to then
      table.insert(roots, c)
      if not replies_map[c.id] then
        replies_map[c.id] = {}
      end
    end
  end
  -- Collect replies
  for _, c in ipairs(comments) do
    if c.in_reply_to then
      if not replies_map[c.in_reply_to] then
        replies_map[c.in_reply_to] = {}
      end
      table.insert(replies_map[c.in_reply_to], c)
    end
  end
  -- Build thread list
  local threads = {}
  for _, root in ipairs(roots) do
    table.insert(threads, {
      root = root,
      replies = replies_map[root.id] or {},
    })
  end
  return threads
end

--- Display comments as virtual text on a buffer (with threading)
---@param buf number Buffer number
---@param comments Comment[] Comments to display
---@param offset? number Line offset (for unified diff headers)
function M.display_virtual(buf, comments, offset)
  offset = offset or 0
  local threads = M.build_threads(comments)

  for _, thread in ipairs(threads) do
    local root = thread.root
    if root.line then
      local line_idx = root.line - 1 + offset
      if line_idx >= 0 and line_idx < vim.api.nvim_buf_line_count(buf) then
        local virt_lines = {
          { { "  💬 " .. root.author .. ": " .. root.body:gsub("\n", " "), "CodeReviewComment" } },
        }
        for _, reply in ipairs(thread.replies) do
          table.insert(virt_lines, {
            { "    ↳ " .. reply.author .. ": " .. reply.body:gsub("\n", " "), "CodeReviewComment" },
          })
        end
        vim.api.nvim_buf_set_extmark(buf, ui.ns, line_idx, 0, {
          virt_lines = virt_lines,
        })
      end
    end
  end
end

return M
