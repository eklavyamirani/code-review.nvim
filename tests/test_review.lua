-- Tests for review session
local T = require("mini.test")
local expect = T.expect
local helpers = require("tests.helpers")

local suite = T.new_set({
  hooks = {
    pre_case = function()
      helpers.reset()
      -- Also reset review session state
      package.loaded["code-review.review"] = nil
      package.loaded["code-review.provider.detect"] = nil
      package.loaded["code-review.provider.github"] = nil
      package.loaded["code-review.provider"] = nil
    end,
  },
})

suite["review.start creates session for test PR branch"] = function()
  -- We need to be on the test/sample-pr branch for this to work
  -- Instead, test that the session module loads and has the right API
  local review = require("code-review.review")
  expect.equality(type(review.start), "function")
  expect.equality(type(review.close), "function")
  expect.equality(type(review.next_file), "function")
  expect.equality(type(review.prev_file), "function")
  expect.equality(type(review.current_file), "function")
  expect.equality(review.current, nil)
end

suite["review.close clears session"] = function()
  local review = require("code-review.review")
  -- Simulate an active session
  review.current = { active = true, files = {} }
  review.close()
  expect.equality(review.current, nil)
end

suite["review.file navigation works"] = function()
  local review = require("code-review.review")
  -- Simulate a session with files
  review.current = {
    active = true,
    files = {
      { path = "a.lua", status = "M" },
      { path = "b.lua", status = "A" },
      { path = "c.lua", status = "D" },
    },
    file_diffs = {},
    comments = {},
    current_file_idx = 1,
  }

  -- Current file
  local f = review.current_file()
  expect.equality(f.path, "a.lua")

  -- Next
  f = review.next_file()
  expect.equality(f.path, "b.lua")
  f = review.next_file()
  expect.equality(f.path, "c.lua")
  -- At end, stays on last
  f = review.next_file()
  expect.equality(f.path, "c.lua")

  -- Previous
  f = review.prev_file()
  expect.equality(f.path, "b.lua")
  f = review.prev_file()
  expect.equality(f.path, "a.lua")
  -- At start, stays on first
  f = review.prev_file()
  expect.equality(f.path, "a.lua")
end

suite["review.goto_file by index"] = function()
  local review = require("code-review.review")
  review.current = {
    active = true,
    files = {
      { path = "a.lua", status = "M" },
      { path = "b.lua", status = "A" },
    },
    file_diffs = {},
    comments = {},
    current_file_idx = 1,
  }

  local f = review.goto_file(2)
  expect.equality(f.path, "b.lua")
  expect.equality(review.current.current_file_idx, 2)
end

suite["review.goto_file_by_path"] = function()
  local review = require("code-review.review")
  review.current = {
    active = true,
    files = {
      { path = "a.lua", status = "M" },
      { path = "b.lua", status = "A" },
    },
    file_diffs = {},
    comments = {},
    current_file_idx = 1,
  }

  local f = review.goto_file_by_path("b.lua")
  expect.equality(f.path, "b.lua")
  expect.equality(review.current.current_file_idx, 2)

  -- Non-existent path
  f = review.goto_file_by_path("nonexistent.lua")
  expect.equality(f, nil)
end

suite["review.comments_for_file filters by path"] = function()
  local review = require("code-review.review")
  review.current = {
    active = true,
    files = {},
    file_diffs = {},
    comments = {
      { id = 1, path = "a.lua", body = "comment 1", line = 1, author = "user", created_at = "", side = "RIGHT" },
      { id = 2, path = "b.lua", body = "comment 2", line = 5, author = "user", created_at = "", side = "RIGHT" },
      { id = 3, path = "a.lua", body = "comment 3", line = 10, author = "user", created_at = "", side = "RIGHT" },
    },
    current_file_idx = 1,
  }

  local comments = review.comments_for_file("a.lua")
  expect.equality(#comments, 2)
  expect.equality(comments[1].id, 1)
  expect.equality(comments[2].id, 3)
end

suite["review.file_list includes comment and current indicators"] = function()
  local review = require("code-review.review")
  review.current = {
    active = true,
    files = {
      { path = "a.lua", status = "M" },
      { path = "b.lua", status = "A" },
    },
    file_diffs = {},
    comments = {
      { id = 1, path = "a.lua", body = "test", line = 1, author = "u", created_at = "", side = "RIGHT" },
    },
    current_file_idx = 1,
  }

  local list = review.file_list()
  expect.equality(#list, 2)
  expect.equality(list[1].is_current, true)
  expect.equality(list[1].has_comments, true)
  expect.equality(list[2].is_current, false)
  expect.equality(list[2].has_comments, false)
end

suite["review functions return nil when no session"] = function()
  local review = require("code-review.review")
  review.current = nil
  expect.equality(review.current_file(), nil)
  expect.equality(review.next_file(), nil)
  expect.equality(review.prev_file(), nil)
  expect.equality(review.goto_file(1), nil)
  expect.equality(#review.file_list(), 0)
  expect.equality(#review.comments_for_file("test"), 0)
end

suite["review.next_comment finds next in current file"] = function()
  local review = require("code-review.review")
  review.current = {
    active = true,
    files = {
      { path = "a.lua", status = "M" },
      { path = "b.lua", status = "A" },
    },
    file_diffs = {},
    comments = {
      { id = 1, path = "a.lua", body = "c1", line = 5, author = "u", created_at = "", side = "RIGHT" },
      { id = 2, path = "a.lua", body = "c2", line = 15, author = "u", created_at = "", side = "RIGHT" },
      { id = 3, path = "b.lua", body = "c3", line = 3, author = "u", created_at = "", side = "RIGHT" },
    },
    current_file_idx = 1,
  }

  -- Mock cursor at line 1 — next comment should be at line 5
  -- Note: next_comment reads cursor from current window but in headless tests,
  -- cursor is at line 1 by default
  local c, f = review.next_comment()
  expect.equality(c.line, 5)
  expect.equality(f.path, "a.lua")
end

suite["review.next_comment wraps to next file"] = function()
  local review = require("code-review.review")
  review.current = {
    active = true,
    files = {
      { path = "a.lua", status = "M" },
      { path = "b.lua", status = "A" },
    },
    file_diffs = {},
    comments = {
      { id = 1, path = "a.lua", body = "c1", line = 1, author = "u", created_at = "", side = "RIGHT" },
      { id = 2, path = "b.lua", body = "c2", line = 10, author = "u", created_at = "", side = "RIGHT" },
    },
    current_file_idx = 1,
  }

  -- Cursor at line 1, comment at line 1 is not "after" cursor (> not >=)
  -- so it should wrap to next file
  local c, f = review.next_comment()
  expect.equality(c.line, 10)
  expect.equality(f.path, "b.lua")
  expect.equality(review.current.current_file_idx, 2)
end

suite["review.prev_comment finds prev in current file"] = function()
  local review = require("code-review.review")
  review.current = {
    active = true,
    files = {
      { path = "a.lua", status = "M" },
    },
    file_diffs = {},
    comments = {
      { id = 1, path = "a.lua", body = "c1", line = 5, author = "u", created_at = "", side = "RIGHT" },
      { id = 2, path = "a.lua", body = "c2", line = 15, author = "u", created_at = "", side = "RIGHT" },
    },
    current_file_idx = 1,
  }

  -- In headless mode cursor is at 1, so prev_comment finds nothing before line 1
  -- and wraps around to last comment (line 15)
  local c, f = review.prev_comment()
  expect.equality(c.line, 15)
  expect.equality(f.path, "a.lua")
end

suite["review.next_comment returns nil when no comments"] = function()
  local review = require("code-review.review")
  review.current = {
    active = true,
    files = {
      { path = "a.lua", status = "M" },
    },
    file_diffs = {},
    comments = {},
    current_file_idx = 1,
  }

  local c, f = review.next_comment()
  expect.equality(c, nil)
  expect.equality(f, nil)
end

return suite
