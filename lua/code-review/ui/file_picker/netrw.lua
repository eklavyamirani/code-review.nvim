-- netrw adapter for code-review.nvim file picker
local M = {}

--- Open netrw showing the changed files
---@param temp_dir string Path to temp directory with symlinks
---@param files table[] Changed files list
---@param on_select fun(path: string) Callback with the selected file path
function M.open(temp_dir, files, on_select)
  -- Open netrw in a vertical split
  vim.cmd("vsplit " .. vim.fn.fnameescape(temp_dir))

  -- Set up autocmd to intercept file opens from this netrw session
  local group = vim.api.nvim_create_augroup("CodeReviewNetrw", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = temp_dir .. "/*",
    callback = function(ev)
      local bufname = vim.api.nvim_buf_get_name(ev.buf)
      -- Only intercept actual files, not netrw directory listings
      if vim.fn.isdirectory(bufname) == 0 and bufname:find(temp_dir, 1, true) then
        -- Prevent the file from actually loading
        vim.schedule(function()
          -- Close the buffer that netrw opened
          if vim.api.nvim_buf_is_valid(ev.buf) then
            vim.api.nvim_buf_delete(ev.buf, { force = true })
          end
          on_select(bufname)
        end)
      end
    end,
  })
end

return M
