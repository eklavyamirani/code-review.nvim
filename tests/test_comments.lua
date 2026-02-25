-- Tests for comments UI module
local T = require("mini.test")
local expect = T.expect
local helpers = require("tests.helpers")

local suite = T.new_set({
  hooks = {
    pre_case = function()
      helpers.reset()
      package.loaded["code-review.ui"] = nil
      package.loaded["code-review.ui.comments"] = nil
    end,
  },
})

suite["comments.display_virtual adds extmarks"] = function()
  local ui_mod = require("code-review.ui")
  ui_mod.setup()
  local comments_ui = require("code-review.ui.comments")

  -- Create a buffer with some content
  local buf = ui_mod.create_buf({})
  ui_mod.set_lines(buf, { "line1", "line2", "line3" })

  local comments = {
    { id = 1, body = "Test comment", path = "test.lua", line = 2, author = "user", created_at = "", side = "RIGHT" },
  }

  comments_ui.display_virtual(buf, comments)

  -- Check that extmarks were added
  local marks = vim.api.nvim_buf_get_extmarks(buf, ui_mod.ns, 0, -1, {})
  assert(#marks > 0, "Expected at least one extmark")

  vim.api.nvim_buf_delete(buf, { force = true })
end

suite["comments.display_virtual handles offset"] = function()
  local ui_mod = require("code-review.ui")
  ui_mod.setup()
  local comments_ui = require("code-review.ui.comments")

  local buf = ui_mod.create_buf({})
  ui_mod.set_lines(buf, { "header1", "header2", "code_line1", "code_line2" })

  local comments = {
    { id = 1, body = "Comment", path = "test.lua", line = 1, author = "u", created_at = "", side = "RIGHT" },
  }

  -- offset=2 means line 1 maps to buffer line 3 (index 2)
  comments_ui.display_virtual(buf, comments, 2)

  local marks = vim.api.nvim_buf_get_extmarks(buf, ui_mod.ns, 0, -1, {})
  assert(#marks > 0, "Expected extmark with offset")

  vim.api.nvim_buf_delete(buf, { force = true })
end

suite["comments.display_virtual ignores out of range lines"] = function()
  local ui_mod = require("code-review.ui")
  ui_mod.setup()
  local comments_ui = require("code-review.ui.comments")

  local buf = ui_mod.create_buf({})
  ui_mod.set_lines(buf, { "only_line" })

  local comments = {
    { id = 1, body = "Out of range", path = "test.lua", line = 999, author = "u", created_at = "", side = "RIGHT" },
  }

  -- Should not error
  comments_ui.display_virtual(buf, comments)

  vim.api.nvim_buf_delete(buf, { force = true })
end

return suite
