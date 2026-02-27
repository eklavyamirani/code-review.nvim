-- GitHub provider for code-review.nvim
-- Uses the gh CLI for API access (authentication handled by gh)
local utils = require("code-review.utils")

local M = {}
M.name = "github"

--- Run a gh api command and parse JSON response
---@param endpoint string API endpoint (e.g., "repos/owner/repo/pulls/1")
---@param method? string HTTP method (default: "GET")
---@param fields? table Key-value pairs for request body
---@return table|nil data Parsed JSON response
---@return string|nil error Error message
local function gh_api(endpoint, method, fields)
  local cmd = { "gh", "api", endpoint }
  if method then
    table.insert(cmd, "--method")
    table.insert(cmd, method)
  end
  if fields then
    for k, v in pairs(fields) do
      table.insert(cmd, "--field")
      table.insert(cmd, k .. "=" .. tostring(v))
    end
  end

  local stdout, stderr, code = utils.system(cmd)
  if code ~= 0 then
    return nil, "gh api failed: " .. stderr
  end

  local ok, data = pcall(vim.json.decode, stdout)
  if not ok then
    return nil, "Failed to parse JSON: " .. tostring(data)
  end
  return data, nil
end

--- Get PR for the current branch
---@param owner string Repository owner
---@param repo string Repository name
---@param branch string Branch name
---@return PR|nil pr
---@return string|nil error
function M.get_pr(owner, repo, branch)
  local data, err = gh_api("repos/" .. owner .. "/" .. repo .. "/pulls?head=" .. owner .. ":" .. branch .. "&state=open")
  if err then
    return nil, err
  end
  if not data or #data == 0 then
    return nil, "No open PR found for branch: " .. branch
  end

  local pr = data[1]
  return {
    id = pr.id,
    number = pr.number,
    title = pr.title,
    body = pr.body or "",
    base_ref = pr.base.ref,
    head_ref = pr.head.ref,
    author = pr.user.login,
    url = pr.html_url,
  }, nil
end

--- Get review comments on a PR (inline comments on code)
---@param owner string
---@param repo string
---@param pr_number number
---@return Comment[] comments
---@return string|nil error
function M.get_comments(owner, repo, pr_number)
  local data, err = gh_api("repos/" .. owner .. "/" .. repo .. "/pulls/" .. pr_number .. "/comments")
  if err then
    return {}, err
  end

  local comments = {}
  for _, c in ipairs(data or {}) do
    table.insert(comments, {
      id = c.id,
      body = c.body,
      path = c.path,
      line = c.line or c.original_line,
      side = c.side or "RIGHT",
      author = c.user.login,
      created_at = c.created_at,
      in_reply_to = c.in_reply_to_id,
    })
  end
  return comments, nil
end

--- Post a review comment on a PR
---@param owner string
---@param repo string
---@param pr_number number
---@param file string File path
---@param line number Line number
---@param body string Comment body
---@param commit_id string The SHA of the commit to comment on
---@return Comment|nil comment
---@return string|nil error
function M.post_comment(owner, repo, pr_number, file, line, body, commit_id)
  local data, err = gh_api(
    "repos/" .. owner .. "/" .. repo .. "/pulls/" .. pr_number .. "/comments",
    "POST",
    {
      body = body,
      path = file,
      line = line,
      side = "RIGHT",
      commit_id = commit_id,
    }
  )
  if err then
    return nil, err
  end

  return {
    id = data.id,
    body = data.body,
    path = data.path,
    line = data.line or data.original_line,
    side = data.side or "RIGHT",
    author = data.user.login,
    created_at = data.created_at,
    in_reply_to = data.in_reply_to_id,
  }, nil
end

--- Reply to a review comment on a PR
---@param owner string
---@param repo string
---@param pr_number number
---@param comment_id number The ID of the comment to reply to
---@param body string Reply body
---@return Comment|nil comment
---@return string|nil error
function M.reply_to_comment(owner, repo, pr_number, comment_id, body)
  local data, err = gh_api(
    "repos/" .. owner .. "/" .. repo .. "/pulls/" .. pr_number .. "/comments/" .. comment_id .. "/replies",
    "POST",
    { body = body }
  )
  if err then
    return nil, err
  end

  return {
    id = data.id,
    body = data.body,
    path = data.path,
    line = data.line or data.original_line,
    side = data.side or "RIGHT",
    author = data.user.login,
    created_at = data.created_at,
    in_reply_to = data.in_reply_to_id,
  }, nil
end

return M
