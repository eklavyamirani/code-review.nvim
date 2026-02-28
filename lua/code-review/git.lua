-- Git CLI wrapper for code-review.nvim
local utils = require("code-review.utils")

local M = {}

--- Get the git repository root directory
---@param cwd? string Working directory
---@return string|nil root
function M.root(cwd)
  local stdout, _, code = utils.system({ "git", "rev-parse", "--show-toplevel" }, cwd)
  if code ~= 0 then
    return nil
  end
  return vim.trim(stdout)
end

--- Get the current branch name
---@param cwd? string
---@return string|nil branch
function M.current_branch(cwd)
  local stdout, _, code = utils.system({ "git", "rev-parse", "--abbrev-ref", "HEAD" }, cwd)
  if code ~= 0 then
    return nil
  end
  return vim.trim(stdout)
end

--- Get the remote URL for a given remote name
---@param remote? string Remote name (default: "origin")
---@param cwd? string
---@return string|nil url
function M.remote_url(remote, cwd)
  remote = remote or "origin"
  local stdout, _, code = utils.system({ "git", "remote", "get-url", remote }, cwd)
  if code ~= 0 then
    return nil
  end
  return vim.trim(stdout)
end

--- Parse a GitHub-style remote URL into owner/repo
---@param url string Remote URL (SSH or HTTPS)
---@return string|nil owner
---@return string|nil repo
function M.parse_remote(url)
  -- Strip trailing .git suffix
  url = url:gsub("%.git$", "")
  -- SSH: git@github.com:owner/repo
  local owner, repo = url:match("git@[^:]+:([^/]+)/(.+)$")
  if owner and repo then
    return owner, repo
  end
  -- HTTPS: https://github.com/owner/repo
  owner, repo = url:match("https?://[^/]+/([^/]+)/(.+)$")
  if owner and repo then
    return owner, repo
  end
  return nil, nil
end

--- Get the hostname from a remote URL
---@param url string
---@return string|nil hostname
function M.remote_host(url)
  -- SSH: git@github.com:...
  local host = url:match("git@([^:]+):")
  if host then
    return host
  end
  -- HTTPS: https://github.com/...
  host = url:match("https?://([^/]+)/")
  return host
end

--- List changed files between two refs
---@param base string Base ref
---@param head string Head ref
---@param cwd? string
---@return table[] files List of {path, status} tables
function M.changed_files(base, head, cwd)
  local stdout, _, code = utils.system({
    "git", "diff", "--name-status", base .. "..." .. head,
  }, cwd)
  if code ~= 0 then
    return {}
  end
  local files = {}
  for line in stdout:gmatch("[^\n]+") do
    local status, path = line:match("^(%S+)%s+(.+)$")
    if status and path then
      table.insert(files, { path = path, status = status })
    end
  end
  return files
end

--- Get the unified diff between two refs
---@param base string Base ref
---@param head string Head ref
---@param cwd? string
---@return string diff Raw unified diff output
function M.diff(base, head, cwd)
  local stdout, _, code = utils.system({
    "git", "diff", base .. "..." .. head,
  }, cwd)
  if code ~= 0 then
    return ""
  end
  return stdout
end

--- Get the diff for a specific file between two refs
---@param base string Base ref
---@param head string Head ref
---@param file string File path
---@param cwd? string
---@return string diff Raw unified diff output for the file
function M.file_diff(base, head, file, cwd)
  local stdout, _, code = utils.system({
    "git", "diff", base .. "..." .. head, "--", file,
  }, cwd)
  if code ~= 0 then
    return ""
  end
  return stdout
end

--- Get file contents at a specific ref
---@param ref string Git ref (branch, tag, commit SHA)
---@param file string File path
---@param cwd? string
---@return string|nil content
function M.file_at_ref(ref, file, cwd)
  local stdout, _, code = utils.system({
    "git", "show", ref .. ":" .. file,
  }, cwd)
  if code ~= 0 then
    return nil
  end
  return stdout
end

--- Get the merge base between two refs
---@param ref1 string
---@param ref2 string
---@param cwd? string
---@return string|nil merge_base
function M.merge_base(ref1, ref2, cwd)
  local stdout, _, code = utils.system({
    "git", "merge-base", ref1, ref2,
  }, cwd)
  if code ~= 0 then
    return nil
  end
  return vim.trim(stdout)
end

return M
