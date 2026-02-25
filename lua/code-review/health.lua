local M = {}

function M.check()
  vim.health.start("code-review.nvim")

  -- Check Neovim version
  if vim.fn.has("nvim-0.10") == 1 then
    vim.health.ok("Neovim >= 0.10")
  else
    vim.health.error("Neovim >= 0.10 required")
  end

  -- Check git
  if vim.fn.executable("git") == 1 then
    vim.health.ok("git found")
  else
    vim.health.error("git not found in PATH")
  end

  -- Check gh CLI
  if vim.fn.executable("gh") == 1 then
    vim.health.ok("gh CLI found")
  else
    vim.health.warn("gh CLI not found (required for GitHub provider)")
  end

  -- Check plenary
  local ok = pcall(require, "plenary")
  if ok then
    vim.health.ok("plenary.nvim loaded")
  else
    vim.health.error("plenary.nvim not found")
  end
end

return M
