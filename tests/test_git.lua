-- Tests for git module and diff parser
local T = require("mini.test")
local expect = T.expect
local helpers = require("tests.helpers")

local suite = T.new_set({
  hooks = {
    pre_case = helpers.reset,
  },
})

-- === git.lua tests ===

suite["git.root returns repo root"] = function()
  local git = require("code-review.git")
  local root = git.root()
  expect.no_equality(root, nil)
  -- Should end with our repo name or be a valid path
  assert(root:match("/"), "Expected an absolute path, got: " .. tostring(root))
end

suite["git.current_branch returns a branch name"] = function()
  local git = require("code-review.git")
  local branch = git.current_branch()
  expect.no_equality(branch, nil)
  assert(#branch > 0, "Branch name should not be empty")
end

suite["git.remote_url returns origin URL"] = function()
  local git = require("code-review.git")
  local url = git.remote_url("origin")
  expect.no_equality(url, nil)
  assert(url:match("code%-review"), "Expected URL to contain repo name, got: " .. tostring(url))
end

suite["git.parse_remote handles SSH URLs"] = function()
  local git = require("code-review.git")
  local owner, repo = git.parse_remote("git@github.com:eklavyamirani/code-review.nvim.git")
  expect.equality(owner, "eklavyamirani")
  expect.equality(repo, "code-review.nvim")
end

suite["git.parse_remote handles HTTPS URLs"] = function()
  local git = require("code-review.git")
  local owner, repo = git.parse_remote("https://github.com/eklavyamirani/code-review.nvim.git")
  expect.equality(owner, "eklavyamirani")
  expect.equality(repo, "code-review.nvim")
end

suite["git.remote_host extracts hostname from SSH"] = function()
  local git = require("code-review.git")
  local host = git.remote_host("git@github.com:user/repo.git")
  expect.equality(host, "github.com")
end

suite["git.remote_host extracts hostname from HTTPS"] = function()
  local git = require("code-review.git")
  local host = git.remote_host("https://dev.azure.com/org/project")
  expect.equality(host, "dev.azure.com")
end

suite["git.changed_files lists files between refs"] = function()
  local git = require("code-review.git")
  -- Use the actual test PR branches
  local files = git.changed_files("main", "test/sample-pr")
  assert(#files > 0, "Expected at least one changed file")
  -- Check structure
  local first = files[1]
  expect.no_equality(first.path, nil)
  expect.no_equality(first.status, nil)
end

suite["git.file_diff returns diff for a file"] = function()
  local git = require("code-review.git")
  local diff = git.file_diff("main", "test/sample-pr", "src/hello.lua")
  assert(#diff > 0, "Expected non-empty diff")
  assert(diff:match("@@ "), "Expected hunk header in diff")
end

suite["git.file_at_ref returns file content"] = function()
  local git = require("code-review.git")
  local content = git.file_at_ref("test/sample-pr", "src/hello.lua")
  expect.no_equality(content, nil)
  assert(content:match("greet"), "Expected file to contain 'greet' function")
end

-- === diff.lua parser tests ===

suite["diff.parse parses unified diff"] = function()
  local diff = require("code-review.diff")
  local raw = [[diff --git a/file.lua b/file.lua
--- a/file.lua
+++ b/file.lua
@@ -1,3 +1,4 @@
 local M = {}
+function M.new() end
 function M.old() end
 return M]]

  local files = diff.parse(raw)
  expect.equality(#files, 1)
  expect.equality(files[1].old_file, "file.lua")
  expect.equality(files[1].new_file, "file.lua")
  expect.equality(files[1].status, "modified")
  expect.equality(#files[1].hunks, 1)

  local hunk = files[1].hunks[1]
  expect.equality(hunk.old_start, 1)
  expect.equality(hunk.new_start, 1)
  expect.equality(#hunk.lines, 4)
end

suite["diff.parse assigns line numbers correctly"] = function()
  local diff = require("code-review.diff")
  local raw = [[diff --git a/f.lua b/f.lua
--- a/f.lua
+++ b/f.lua
@@ -1,3 +1,3 @@
 line1
-old_line
+new_line
 line3]]

  local files = diff.parse(raw)
  local lines = files[1].hunks[1].lines

  -- context line1: old=1, new=1
  expect.equality(lines[1].type, "context")
  expect.equality(lines[1].old_line, 1)
  expect.equality(lines[1].new_line, 1)

  -- removed old_line: old=2
  expect.equality(lines[2].type, "remove")
  expect.equality(lines[2].old_line, 2)
  expect.equality(lines[2].new_line, nil)

  -- added new_line: new=2
  expect.equality(lines[3].type, "add")
  expect.equality(lines[3].old_line, nil)
  expect.equality(lines[3].new_line, 2)

  -- context line3: old=3, new=3
  expect.equality(lines[4].type, "context")
  expect.equality(lines[4].old_line, 3)
  expect.equality(lines[4].new_line, 3)
end

suite["diff.parse detects new file"] = function()
  local diff = require("code-review.diff")
  local raw = [[diff --git a/new.lua b/new.lua
new file mode 100644
--- /dev/null
+++ b/new.lua
@@ -0,0 +1,2 @@
+local M = {}
+return M]]

  local files = diff.parse(raw)
  expect.equality(files[1].status, "added")
end

suite["diff.parse detects deleted file"] = function()
  local diff = require("code-review.diff")
  local raw = [[diff --git a/old.lua b/old.lua
deleted file mode 100644
--- a/old.lua
+++ /dev/null
@@ -1,2 +0,0 @@
-local M = {}
-return M]]

  local files = diff.parse(raw)
  expect.equality(files[1].status, "deleted")
end

suite["diff.parse handles multiple files"] = function()
  local diff = require("code-review.diff")
  local raw = [[diff --git a/a.lua b/a.lua
--- a/a.lua
+++ b/a.lua
@@ -1,1 +1,1 @@
-old
+new
diff --git a/b.lua b/b.lua
--- a/b.lua
+++ b/b.lua
@@ -1,1 +1,1 @@
-old2
+new2]]

  local files = diff.parse(raw)
  expect.equality(#files, 2)
  expect.equality(files[1].old_file, "a.lua")
  expect.equality(files[2].old_file, "b.lua")
end

suite["diff.parse with real git diff"] = function()
  local git = require("code-review.git")
  local diff_mod = require("code-review.diff")
  local raw = git.diff("main", "test/sample-pr")
  local files = diff_mod.parse(raw)
  assert(#files > 0, "Expected parsed files from real diff")
end

return suite
