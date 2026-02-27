-- Review session state management for code-review.nvim
local git = require("code-review.git")
local diff_parser = require("code-review.diff")
local detect = require("code-review.provider.detect")

local M = {}

---@class ReviewSession
---@field pr PR PR metadata
---@field provider table Provider module
---@field owner string Repository owner
---@field repo string Repository name
---@field files table[] Changed files list ({path, status})
---@field file_diffs table<string, FileDiff> Parsed diffs keyed by file path
---@field comments Comment[] All PR comments
---@field current_file_idx number Index into files list (1-based)
---@field active boolean Whether the session is active

--- The current active session (singleton)
---@type ReviewSession|nil
M.current = nil

--- Start a new review session
---@param opts? {remote?: string, cwd?: string}
---@return ReviewSession|nil session
---@return string|nil error
function M.start(opts)
  opts = opts or {}

  if M.current and M.current.active then
    return nil, "A review session is already active. Close it first with :CodeReviewClose"
  end

  -- Detect provider
  local provider, owner, repo = detect.detect(opts.remote, opts.cwd)
  if not provider then
    return nil, "Could not detect git provider from remote URL"
  end
  if not owner or not repo then
    return nil, "Could not parse owner/repo from remote URL"
  end

  -- Get current branch
  local branch = git.current_branch(opts.cwd)
  if not branch then
    return nil, "Could not determine current branch"
  end

  -- Fetch PR metadata
  local pr, err = provider.get_pr(owner, repo, branch)
  if not pr then
    return nil, err or "No PR found for branch: " .. branch
  end

  -- Get changed files
  local files = git.changed_files(pr.base_ref, pr.head_ref, opts.cwd)
  if #files == 0 then
    return nil, "No changed files found between " .. pr.base_ref .. " and " .. pr.head_ref
  end

  -- Parse diffs for all files
  local raw_diff = git.diff(pr.base_ref, pr.head_ref, opts.cwd)
  local parsed_files = diff_parser.parse(raw_diff)
  local file_diffs = {}
  for _, fd in ipairs(parsed_files) do
    file_diffs[fd.new_file] = fd
  end

  -- Fetch comments
  local comments = {}
  comments, err = provider.get_comments(owner, repo, pr.number)
  if err then
    -- Non-fatal: we can still review without comments
    vim.notify("code-review: failed to load comments: " .. err, vim.log.levels.WARN)
    comments = {}
  end

  local session = {
    pr = pr,
    provider = provider,
    owner = owner,
    repo = repo,
    files = files,
    file_diffs = file_diffs,
    comments = comments,
    current_file_idx = 1,
    active = true,
    reviewed = {}, -- file path -> boolean (review status tracking)
  }

  M.current = session
  return session, nil
end

--- Refresh the current session (re-fetch PR data, diff, comments)
--- Preserves cursor position and file review status
---@return boolean success
---@return string|nil error
function M.refresh()
  if not M.current or not M.current.active then
    return false, "No active session to refresh"
  end

  local s = M.current

  -- Re-fetch PR metadata
  local pr, err = s.provider.get_pr(s.owner, s.repo, s.pr.head_ref)
  if not pr then
    return false, err or "Failed to refresh PR"
  end

  -- Re-fetch diff
  local raw_diff = git.diff(pr.base_ref, pr.head_ref)
  local parsed_files = diff_parser.parse(raw_diff)
  local file_diffs = {}
  for _, fd in ipairs(parsed_files) do
    file_diffs[fd.new_file] = fd
  end

  -- Re-fetch files
  local files = git.changed_files(pr.base_ref, pr.head_ref)

  -- Re-fetch comments
  local comments = {}
  comments, err = s.provider.get_comments(s.owner, s.repo, pr.number)
  if err then
    vim.notify("code-review: failed to refresh comments: " .. err, vim.log.levels.WARN)
    comments = s.comments -- keep old comments
  end

  -- Preserve review status and cursor position
  local old_reviewed = s.reviewed
  local old_file_idx = s.current_file_idx
  local old_file = s.files[old_file_idx]

  -- Update session
  s.pr = pr
  s.files = files
  s.file_diffs = file_diffs
  s.comments = comments
  s.reviewed = old_reviewed

  -- Restore file position (try to find same file)
  if old_file then
    local found = false
    for i, f in ipairs(files) do
      if f.path == old_file.path then
        s.current_file_idx = i
        found = true
        break
      end
    end
    if not found then
      s.current_file_idx = math.min(old_file_idx, #files)
    end
  else
    s.current_file_idx = 1
  end

  return true, nil
end

--- Close the current review session
function M.close()
  if M.current then
    M.current.active = false
    M.current = nil
  end
end

--- Get the current file in the review
---@return table|nil file {path, status} or nil if no session
function M.current_file()
  if not M.current or not M.current.active then
    return nil
  end
  return M.current.files[M.current.current_file_idx]
end

--- Navigate to the next file
---@return table|nil file The new current file, or nil if at end
function M.next_file()
  if not M.current or not M.current.active then
    return nil
  end
  if M.current.current_file_idx < #M.current.files then
    M.current.current_file_idx = M.current.current_file_idx + 1
  end
  return M.current_file()
end

--- Navigate to the previous file
---@return table|nil file The new current file, or nil if at start
function M.prev_file()
  if not M.current or not M.current.active then
    return nil
  end
  if M.current.current_file_idx > 1 then
    M.current.current_file_idx = M.current.current_file_idx - 1
  end
  return M.current_file()
end

--- Jump to a file by index
---@param idx number 1-based index
---@return table|nil file
function M.goto_file(idx)
  if not M.current or not M.current.active then
    return nil
  end
  if idx >= 1 and idx <= #M.current.files then
    M.current.current_file_idx = idx
  end
  return M.current_file()
end

--- Jump to a file by path
---@param path string File path
---@return table|nil file
function M.goto_file_by_path(path)
  if not M.current or not M.current.active then
    return nil
  end
  for i, f in ipairs(M.current.files) do
    if f.path == path then
      M.current.current_file_idx = i
      return f
    end
  end
  return nil
end

--- Get the parsed diff for the current file
---@return FileDiff|nil
function M.current_file_diff()
  local file = M.current_file()
  if not file or not M.current then
    return nil
  end
  return M.current.file_diffs[file.path]
end

--- Get comments for a specific file
---@param path string File path
---@return Comment[]
function M.comments_for_file(path)
  if not M.current or not M.current.active then
    return {}
  end
  local result = {}
  for _, c in ipairs(M.current.comments) do
    if c.path == path then
      table.insert(result, c)
    end
  end
  return result
end

--- Navigate to the next comment (within file, then cross-file)
---@return Comment|nil comment The next comment, or nil
---@return table|nil file The file containing the comment
function M.next_comment()
  if not M.current or not M.current.active then
    return nil, nil
  end
  local comments = M.current.comments
  if #comments == 0 then
    return nil, nil
  end

  local cur_file = M.current_file()
  if not cur_file then return nil, nil end

  -- Get cursor line in current diff buffer
  local cursor_line = 1
  if vim.api.nvim_get_current_win() and vim.api.nvim_win_is_valid(vim.api.nvim_get_current_win()) then
    cursor_line = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())[1]
  end

  -- Sort comments for current file by line
  local file_comments = {}
  for _, c in ipairs(comments) do
    if c.path == cur_file.path and c.line then
      table.insert(file_comments, c)
    end
  end
  table.sort(file_comments, function(a, b) return a.line < b.line end)

  -- Find next comment in current file after cursor
  for _, c in ipairs(file_comments) do
    if c.line > cursor_line then
      return c, cur_file
    end
  end

  -- No more in current file — search subsequent files
  local n = #M.current.files
  for offset = 1, n - 1 do
    local idx = ((M.current.current_file_idx - 1 + offset) % n) + 1
    local f = M.current.files[idx]
    local fc = {}
    for _, c in ipairs(comments) do
      if c.path == f.path and c.line then
        table.insert(fc, c)
      end
    end
    if #fc > 0 then
      table.sort(fc, function(a, b) return a.line < b.line end)
      M.current.current_file_idx = idx
      return fc[1], f
    end
  end

  -- Wrap: return first comment in current file
  if #file_comments > 0 then
    return file_comments[1], cur_file
  end

  return nil, nil
end

--- Navigate to the previous comment (within file, then cross-file)
---@return Comment|nil comment The previous comment, or nil
---@return table|nil file The file containing the comment
function M.prev_comment()
  if not M.current or not M.current.active then
    return nil, nil
  end
  local comments = M.current.comments
  if #comments == 0 then
    return nil, nil
  end

  local cur_file = M.current_file()
  if not cur_file then return nil, nil end

  local cursor_line = 1
  if vim.api.nvim_get_current_win() and vim.api.nvim_win_is_valid(vim.api.nvim_get_current_win()) then
    cursor_line = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())[1]
  end

  -- Sort comments for current file by line (descending)
  local file_comments = {}
  for _, c in ipairs(comments) do
    if c.path == cur_file.path and c.line then
      table.insert(file_comments, c)
    end
  end
  table.sort(file_comments, function(a, b) return a.line > b.line end)

  -- Find previous comment in current file before cursor
  for _, c in ipairs(file_comments) do
    if c.line < cursor_line then
      return c, cur_file
    end
  end

  -- No more in current file — search preceding files
  local n = #M.current.files
  for offset = 1, n - 1 do
    local idx = ((M.current.current_file_idx - 1 - offset) % n) + 1
    local f = M.current.files[idx]
    local fc = {}
    for _, c in ipairs(comments) do
      if c.path == f.path and c.line then
        table.insert(fc, c)
      end
    end
    if #fc > 0 then
      table.sort(fc, function(a, b) return a.line > b.line end)
      M.current.current_file_idx = idx
      return fc[1], f
    end
  end

  -- Wrap: return last comment in current file
  if #file_comments > 0 then
    return file_comments[1], cur_file  -- already sorted descending, so [1] is last
  end

  return nil, nil
end

--- Toggle review status for the current file
---@return boolean|nil status New status, or nil if no session
function M.toggle_reviewed()
  if not M.current or not M.current.active then
    return nil
  end
  local file = M.current_file()
  if not file then return nil end
  local current = M.current.reviewed[file.path] or false
  M.current.reviewed[file.path] = not current
  return not current
end

--- Get review status for a file
---@param path string
---@return boolean
function M.is_reviewed(path)
  if not M.current or not M.current.active then
    return false
  end
  return M.current.reviewed[path] or false
end

--- Get review progress
---@return number reviewed Count of reviewed files
---@return number total Total files
function M.review_progress()
  if not M.current or not M.current.active then
    return 0, 0
  end
  local reviewed = 0
  for _, f in ipairs(M.current.files) do
    if M.current.reviewed[f.path] then
      reviewed = reviewed + 1
    end
  end
  return reviewed, #M.current.files
end

--- Get file list summary for display
---@return table[] List of {path, status, has_comments, is_current}
function M.file_list()
  if not M.current or not M.current.active then
    return {}
  end
  local result = {}
  local comment_paths = {}
  for _, c in ipairs(M.current.comments) do
    comment_paths[c.path] = true
  end
  for i, f in ipairs(M.current.files) do
    table.insert(result, {
      path = f.path,
      status = f.status,
      has_comments = comment_paths[f.path] or false,
      is_current = i == M.current.current_file_idx,
      reviewed = M.current.reviewed[f.path] or false,
    })
  end
  return result
end

return M
