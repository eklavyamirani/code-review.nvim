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

suite["comments.build_threads groups replies under root"] = function()
  local comments_ui = require("code-review.ui.comments")

  local comments = {
    { id = 100, body = "Root comment", path = "a.lua", line = 5, author = "alice", created_at = "", side = "RIGHT" },
    { id = 101, body = "Reply 1", path = "a.lua", line = 5, author = "bob", created_at = "", side = "RIGHT", in_reply_to = 100 },
    { id = 102, body = "Reply 2", path = "a.lua", line = 5, author = "charlie", created_at = "", side = "RIGHT", in_reply_to = 100 },
    { id = 200, body = "Another root", path = "a.lua", line = 10, author = "dave", created_at = "", side = "RIGHT" },
  }

  local threads = comments_ui.build_threads(comments)
  expect.equality(#threads, 2)
  expect.equality(threads[1].root.id, 100)
  expect.equality(#threads[1].replies, 2)
  expect.equality(threads[1].replies[1].author, "bob")
  expect.equality(threads[1].replies[2].author, "charlie")
  expect.equality(threads[2].root.id, 200)
  expect.equality(#threads[2].replies, 0)
end

suite["comments.display_virtual shows threaded comments"] = function()
  local ui_mod = require("code-review.ui")
  ui_mod.setup()
  local comments_ui = require("code-review.ui.comments")

  local buf = ui_mod.create_buf({})
  ui_mod.set_lines(buf, { "line1", "line2", "line3", "line4", "line5" })

  local comments = {
    { id = 100, body = "Root", path = "a.lua", line = 2, author = "alice", created_at = "", side = "RIGHT" },
    { id = 101, body = "Reply", path = "a.lua", line = 2, author = "bob", created_at = "", side = "RIGHT", in_reply_to = 100 },
  }

  comments_ui.display_virtual(buf, comments)

  -- Check extmarks — should have one extmark with 2 virtual lines (root + reply)
  local marks = vim.api.nvim_buf_get_extmarks(buf, ui_mod.ns, 0, -1, { details = true })
  assert(#marks > 0, "Expected at least one extmark for thread")
  local details = marks[1][4]
  assert(details.virt_lines and #details.virt_lines == 2, "Expected 2 virtual lines (root + reply)")

  vim.api.nvim_buf_delete(buf, { force = true })
end

return suite
