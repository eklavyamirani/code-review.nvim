-- Provider auto-detection from git remote URL
local git = require("code-review.git")
local provider_registry = require("code-review.provider")

local M = {}

-- Map of hostname patterns to provider names
local host_patterns = {
  { pattern = "github%.com", provider = "github" },
  { pattern = "dev%.azure%.com", provider = "azure_devops" },
  { pattern = "ssh%.dev%.azure%.com", provider = "azure_devops" },
  { pattern = "gitea", provider = "gitea" },
  { pattern = "gitlab", provider = "gitlab" },
}

--- Detect the provider from the git remote URL
---@param remote? string Remote name (default: "origin")
---@param cwd? string Working directory
---@return table|nil provider The provider module
---@return string|nil owner Repository owner
---@return string|nil repo Repository name
function M.detect(remote, cwd)
  local url = git.remote_url(remote, cwd)
  if not url then
    return nil, nil, nil
  end

  local host = git.remote_host(url)
  if not host then
    return nil, nil, nil
  end

  local owner, repo = git.parse_remote(url)

  for _, entry in ipairs(host_patterns) do
    if host:match(entry.pattern) then
      -- Try to load the provider
      local prov = provider_registry.get(entry.provider)
      if not prov then
        -- Try to require it
        local ok, mod = pcall(require, "code-review.provider." .. entry.provider)
        if ok then
          provider_registry.register(mod)
          prov = mod
        end
      end
      return prov, owner, repo
    end
  end

  return nil, owner, repo
end

return M
