-- Tests for file picker dispatcher and adapters
local T = require("mini.test")
local expect = T.expect
local helpers = require("tests.helpers")

local suite = T.new_set({
  hooks = {
    pre_case = function()
      helpers.reset()
      package.loaded["code-review.ui.file_picker"] = nil
      package.loaded["code-review.ui.file_picker.netrw"] = nil
      package.loaded["code-review.ui.file_picker.mini_files"] = nil
      package.loaded["code-review.config"] = nil
    end,
  },
})

-- === Dispatcher tests ===

suite["file_picker.detect returns mini_files when available"] = function()
  local picker = require("code-review.ui.file_picker")
  local result = picker.detect("auto")
  -- mini.files is installed in the test container
  expect.equality(result, "mini_files")
end

suite["file_picker.detect respects explicit preference"] = function()
  local picker = require("code-review.ui.file_picker")
  expect.equality(picker.detect("netrw"), "netrw")
  expect.equality(picker.detect("mini_files"), "mini_files")
end

suite["file_picker.load returns adapter module"] = function()
  local picker = require("code-review.ui.file_picker")
  local netrw = picker.load("netrw")
  expect.equality(type(netrw.open), "function")

  local mini = picker.load("mini_files")
  expect.equality(type(mini.open), "function")
end

suite["file_picker.load errors on unknown adapter"] = function()
  local picker = require("code-review.ui.file_picker")
  local ok, _ = pcall(picker.load, "nonexistent")
  expect.equality(ok, false)
end

-- === Temp directory tests ===

suite["file_picker.create_temp_dir creates symlinks"] = function()
  local picker = require("code-review.ui.file_picker")
  local cwd = vim.fn.getcwd()

  local files = {
    { path = "Dockerfile", status = "M" },
    { path = ".gitignore", status = "M" },
  }

  local temp_dir = picker.create_temp_dir(files, cwd)

  -- Verify temp dir was created
  expect.equality(vim.fn.isdirectory(temp_dir), 1)

  -- Verify symlinks exist
  for _, f in ipairs(files) do
    local target = temp_dir .. "/" .. f.path
    expect.equality(vim.fn.filereadable(target), 1)
  end

  -- Cleanup
  picker.cleanup(temp_dir)
  expect.equality(vim.fn.isdirectory(temp_dir), 0)
end

suite["file_picker.create_temp_dir handles nested paths"] = function()
  local picker = require("code-review.ui.file_picker")
  local cwd = vim.fn.getcwd()

  local files = {
    { path = "lua/code-review/init.lua", status = "M" },
  }

  local temp_dir = picker.create_temp_dir(files, cwd)
  local target = temp_dir .. "/lua/code-review/init.lua"
  expect.equality(vim.fn.filereadable(target), 1)

  picker.cleanup(temp_dir)
end

suite["file_picker.create_temp_dir handles deleted files"] = function()
  local picker = require("code-review.ui.file_picker")
  local cwd = vim.fn.getcwd()

  local files = {
    { path = "nonexistent-file.lua", status = "D" },
  }

  local temp_dir = picker.create_temp_dir(files, cwd)
  local target = temp_dir .. "/nonexistent-file.lua"
  -- Should create a placeholder file
  expect.equality(vim.fn.filereadable(target), 1)

  picker.cleanup(temp_dir)
end

-- === Config integration ===

suite["config includes file_picker default"] = function()
  local config = require("code-review.config")
  config.setup()
  expect.equality(config.values.file_picker, "auto")
end

suite["config allows file_picker override"] = function()
  local config = require("code-review.config")
  config.setup({ file_picker = "netrw" })
  expect.equality(config.values.file_picker, "netrw")
end

return suite
