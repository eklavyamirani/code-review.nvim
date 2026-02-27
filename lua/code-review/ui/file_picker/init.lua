-- File picker dispatcher for code-review.nvim
-- Auto-detects and loads the best available file manager adapter
local M = {}

local adapters = {
  mini_files = "code-review.ui.file_picker.mini_files",
  netrw = "code-review.ui.file_picker.netrw",
}

--- Check if a Lua module is available
---@param mod string Module name
---@return boolean
local function has_module(mod)
  local ok = pcall(require, mod)
  return ok
end

--- Detect the best available file picker
---@param preference? string User preference: "auto", "netrw", "mini_files"
---@return string adapter_name
function M.detect(preference)
  if preference and preference ~= "auto" then
    return preference
  end
  -- Prefer mini.files if available, fall back to netrw
  if has_module("mini.files") then
    return "mini_files"
  end
  return "netrw"
end

--- Load an adapter by name
---@param name string
---@return table adapter
function M.load(name)
  local mod_path = adapters[name]
  if not mod_path then
    error("Unknown file picker adapter: " .. name)
  end
  return require(mod_path)
end

--- Create a temp directory with symlinks to changed files
---@param files table[] List of {path, status} from the review session
---@param repo_root string Absolute path to the repo root
---@return string temp_dir Path to the temp directory
function M.create_temp_dir(files, repo_root)
  local temp_dir = vim.fn.tempname() .. "-code-review"
  vim.fn.mkdir(temp_dir, "p")

  for _, f in ipairs(files) do
    local source = repo_root .. "/" .. f.path
    local target = temp_dir .. "/" .. f.path

    -- Create parent directories for nested files
    local parent = vim.fn.fnamemodify(target, ":h")
    if vim.fn.isdirectory(parent) == 0 then
      vim.fn.mkdir(parent, "p")
    end

    -- Create symlink (only for files that exist in the head version)
    if vim.fn.filereadable(source) == 1 then
      vim.uv.fs_symlink(source, target)
    else
      -- Deleted files: create a placeholder
      local fd = io.open(target, "w")
      if fd then
        fd:write("-- [deleted in this PR]\n")
        fd:close()
      end
    end
  end

  return temp_dir
end

--- Clean up a temp directory
---@param temp_dir string
function M.cleanup(temp_dir)
  if temp_dir and vim.fn.isdirectory(temp_dir) == 1 then
    vim.fn.delete(temp_dir, "rf")
  end
end

--- Open the file picker for a review session
---@param session table The active review session
---@param on_select fun(file_path: string) Callback when a file is selected
---@param preference? string File picker preference
function M.open(session, on_select, preference)
  local config = require("code-review.config")
  preference = preference or config.values.file_picker
  local adapter_name = M.detect(preference)
  local adapter = M.load(adapter_name)

  local git = require("code-review.git")
  local repo_root = git.root() or vim.fn.getcwd()
  local temp_dir = M.create_temp_dir(session.files, repo_root)

  -- Store temp_dir for cleanup
  session._temp_dir = temp_dir

  adapter.open(temp_dir, session.files, function(selected_path)
    -- Convert temp path back to repo-relative path
    local rel_path = selected_path:gsub("^" .. vim.pesc(temp_dir) .. "/", "")
    on_select(rel_path)
  end)
end

return M
