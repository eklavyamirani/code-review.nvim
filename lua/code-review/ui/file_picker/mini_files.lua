-- mini.files adapter for code-review.nvim file picker
local M = {}

--- Open mini.files showing the changed files
---@param temp_dir string Path to temp directory with symlinks
---@param files table[] Changed files list
---@param on_select fun(path: string) Callback with the selected file path
function M.open(temp_dir, files, on_select)
  local ok, mini_files = pcall(require, "mini.files")
  if not ok then
    vim.notify("code-review: mini.files not available, falling back to netrw", vim.log.levels.WARN)
    require("code-review.ui.file_picker.netrw").open(temp_dir, files, on_select)
    return
  end

  mini_files.open(temp_dir)

  -- Hook into MiniFilesActionOpen to intercept file selection
  local group = vim.api.nvim_create_augroup("CodeReviewMiniFiles", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "MiniFilesActionOpen",
    callback = function(ev)
      -- ev.data.entry contains the opened entry
      if ev.data and ev.data.entry then
        local entry = ev.data.entry
        if entry.fs_type == "file" and entry.path:find(temp_dir, 1, true) then
          -- Close mini.files and route to diff
          mini_files.close()
          on_select(entry.path)
          return true -- prevent default open
        end
      end
    end,
  })
end

return M
