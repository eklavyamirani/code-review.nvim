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

suite["diff.render_unified creates buffer with full file content"] = function()
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

  -- Mock git.file_at_ref so it returns the head file content
  local git = require("code-review.git")
  local orig = git.file_at_ref
  git.file_at_ref = function(_, _) return "line1\nnew\nline3" end

  local buf = diff_ui.render_unified(file_diff, "HEAD")
  expect.equality(vim.api.nvim_buf_is_valid(buf), true)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- Should show the full file (3 lines)
  expect.equality(#lines, 3)
  expect.equality(lines[1], "line1")
  expect.equality(lines[2], "new")
  expect.equality(lines[3], "line3")
  vim.api.nvim_buf_delete(buf, { force = true })

  git.file_at_ref = orig
end

suite["diff.render_unified highlights added lines"] = function()
  local ui_mod = require("code-review.ui")
  ui_mod.setup()
  local diff_ui = require("code-review.ui.diff")

  local file_diff = {
    old_file = "test.lua",
    new_file = "test.lua",
    status = "modified",
    hunks = {
      {
        old_start = 1, old_count = 1, new_start = 1, new_count = 2,
        header = "@@ -1,1 +1,2 @@",
        lines = {
          { type = "context", text = "existing", old_line = 1, new_line = 1 },
          { type = "add", text = "new_line", old_line = nil, new_line = 2 },
        },
      },
    },
  }

  local git = require("code-review.git")
  local orig = git.file_at_ref
  git.file_at_ref = function(_, _) return "existing\nnew_line" end

  local buf = diff_ui.render_unified(file_diff, "HEAD")
  -- The added line (line 2) should have a highlight extmark
  local marks = vim.api.nvim_buf_get_extmarks(buf, ui_mod.ns, 0, -1, { details = true })
  assert(#marks > 0, "Expected extmarks for removed/comment markers")
  vim.api.nvim_buf_delete(buf, { force = true })

  git.file_at_ref = orig
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

suite["diff.render_unified tracks hunk positions"] = function()
  local ui_mod = require("code-review.ui")
  ui_mod.setup()
  local diff_ui = require("code-review.ui.diff")

  local file_diff = {
    old_file = "test.lua",
    new_file = "test.lua",
    status = "modified",
    hunks = {
      {
        old_start = 1, old_count = 2, new_start = 1, new_count = 2,
        header = "@@ -1,2 +1,2 @@",
        lines = {
          { type = "remove", text = "old", old_line = 1, new_line = nil },
          { type = "add", text = "new", old_line = nil, new_line = 1 },
        },
      },
      {
        old_start = 10, old_count = 1, new_start = 10, new_count = 1,
        header = "@@ -10,1 +10,1 @@",
        lines = {
          { type = "remove", text = "old2", old_line = 10, new_line = nil },
          { type = "add", text = "new2", old_line = nil, new_line = 10 },
        },
      },
    },
  }

  local git = require("code-review.git")
  local orig = git.file_at_ref
  -- Provide 10 lines of content
  local content_lines = {}
  for i = 1, 10 do content_lines[i] = "line" .. i end
  git.file_at_ref = function(_, _) return table.concat(content_lines, "\n") end

  local buf, hunk_positions = diff_ui.render_unified(file_diff, "HEAD")
  expect.equality(#hunk_positions, 2)
  -- Hunk positions correspond to new_start values
  expect.equality(hunk_positions[1], 1)
  expect.equality(hunk_positions[2], 10)
  vim.api.nvim_buf_delete(buf, { force = true })

  git.file_at_ref = orig
end

suite["diff.toggle_collapse expands and collapses removed lines"] = function()
  local ui_mod = require("code-review.ui")
  ui_mod.setup()
  local diff_ui = require("code-review.ui.diff")

  local file_diff = {
    old_file = "test.lua",
    new_file = "test.lua",
    status = "modified",
    hunks = {
      {
        old_start = 1, old_count = 2, new_start = 1, new_count = 1,
        header = "@@ -1,2 +1,1 @@",
        lines = {
          { type = "remove", text = "deleted_line", old_line = 1, new_line = nil },
          { type = "context", text = "kept_line", old_line = 2, new_line = 1 },
        },
      },
    },
  }

  local git = require("code-review.git")
  local orig = git.file_at_ref
  git.file_at_ref = function(_, _) return "kept_line" end

  local buf = diff_ui.render_unified(file_diff, "HEAD")
  -- Should have collapsed items
  assert(diff_ui.state.collapsed_items and #diff_ui.state.collapsed_items > 0, "Expected collapsed items")
  local item = diff_ui.state.collapsed_items[1]
  expect.equality(item.expanded, false)
  expect.equality(item.type, "removed")

  -- Expand
  diff_ui.toggle_collapse(buf, item.line, "expand")
  expect.equality(item.expanded, true)

  -- Collapse
  diff_ui.toggle_collapse(buf, item.line, "collapse")
  expect.equality(item.expanded, false)

  vim.api.nvim_buf_delete(buf, { force = true })
  git.file_at_ref = orig
end

return suite
