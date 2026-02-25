-- Tests for UI modules (diff rendering, file list)
local T = require("mini.test")
local expect = T.expect
local helpers = require("tests.helpers")

local suite = T.new_set({
  hooks = {
    pre_case = function()
      helpers.reset()
      package.loaded["code-review.ui"] = nil
      package.loaded["code-review.ui.diff"] = nil
      package.loaded["code-review.ui.file_list"] = nil
    end,
  },
})

-- === UI base tests ===

suite["ui.create_buf creates a scratch buffer"] = function()
  local ui_mod = require("code-review.ui")
  ui_mod.setup()
  local buf = ui_mod.create_buf({ name = "[Test]" })
  expect.equality(vim.api.nvim_buf_is_valid(buf), true)
  expect.equality(vim.bo[buf].modifiable, false)
  vim.api.nvim_buf_delete(buf, { force = true })
end

suite["ui.set_lines sets buffer content"] = function()
  local ui_mod = require("code-review.ui")
  ui_mod.setup()
  local buf = ui_mod.create_buf({})
  ui_mod.set_lines(buf, { "line1", "line2", "line3" })
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  expect.equality(#lines, 3)
  expect.equality(lines[1], "line1")
  expect.equality(lines[3], "line3")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- === Unified diff rendering ===

suite["diff.render_unified creates buffer with diff content"] = function()
  local ui_mod = require("code-review.ui")
  ui_mod.setup()
  local diff_ui = require("code-review.ui.diff")

  local file_diff = {
    old_file = "test.lua",
    new_file = "test.lua",
    status = "modified",
    hunks = {
      {
        old_start = 1, old_count = 3,
        new_start = 1, new_count = 3,
        header = "@@ -1,3 +1,3 @@",
        lines = {
          { type = "context", text = "line1", old_line = 1, new_line = 1 },
          { type = "remove", text = "old", old_line = 2, new_line = nil },
          { type = "add", text = "new", old_line = nil, new_line = 2 },
          { type = "context", text = "line3", old_line = 3, new_line = 3 },
        },
      },
    },
  }

  local buf = diff_ui.render_unified(file_diff)
  expect.equality(vim.api.nvim_buf_is_valid(buf), true)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- Should have: --- header, +++ header, @@ header, 4 diff lines = 7 lines
  assert(#lines >= 7, "Expected at least 7 lines, got " .. #lines)
  assert(lines[1]:match("^---"), "First line should be --- header")
  assert(lines[2]:match("^%+%+%+"), "Second line should be +++ header")
  vim.api.nvim_buf_delete(buf, { force = true })
end

suite["diff.render_unified includes inline comments"] = function()
  local ui_mod = require("code-review.ui")
  ui_mod.setup()
  local diff_ui = require("code-review.ui.diff")

  local file_diff = {
    old_file = "test.lua",
    new_file = "test.lua",
    status = "modified",
    hunks = {
      {
        old_start = 1, old_count = 1, new_start = 1, new_count = 1,
        header = "@@ -1,1 +1,1 @@",
        lines = {
          { type = "add", text = "new_line", old_line = nil, new_line = 1 },
        },
      },
    },
  }

  local comments = {
    { id = 1, body = "Nice change!", path = "test.lua", line = 1, author = "reviewer", created_at = "", side = "RIGHT" },
  }

  local buf = diff_ui.render_unified(file_diff, comments)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local found_comment = false
  for _, line in ipairs(lines) do
    if line:match("reviewer") and line:match("Nice change") then
      found_comment = true
    end
  end
  assert(found_comment, "Expected inline comment in unified diff output")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- === File list rendering ===

suite["file_list.render creates file list buffer"] = function()
  local ui_mod = require("code-review.ui")
  ui_mod.setup()
  local file_list = require("code-review.ui.file_list")

  local files = {
    { path = "a.lua", status = "M", has_comments = true, is_current = true },
    { path = "b.lua", status = "A", has_comments = false, is_current = false },
    { path = "c.lua", status = "D", has_comments = false, is_current = false },
  }

  local selected = nil
  local buf = file_list.render(files, function(idx)
    selected = idx
  end)

  expect.equality(vim.api.nvim_buf_is_valid(buf), true)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- Header + separator + 3 files = 5 lines
  expect.equality(#lines, 5)
  assert(lines[1]:match("Changed Files"), "Expected header")
  assert(lines[3]:match("a%.lua"), "Expected first file")
  vim.api.nvim_buf_delete(buf, { force = true })
end

-- === Diff toggle ===

suite["diff.state tracks mode"] = function()
  local diff_ui = require("code-review.ui.diff")
  expect.equality(diff_ui.state.mode, "split")
  diff_ui.state.mode = "unified"
  expect.equality(diff_ui.state.mode, "unified")
end

return suite
