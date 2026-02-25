-- Smoke tests: verify plugin loads and configures correctly
local T = require("mini.test")
local expect = T.expect
local helpers = require("tests.helpers")

local suite = T.new_set({
  hooks = {
    pre_case = helpers.reset,
  },
})

suite["setup loads without error"] = function()
  local cr = require("code-review")
  cr.setup()
end

suite["setup merges user config"] = function()
  local cr = require("code-review")
  cr.setup({ diff_mode = "unified" })

  local config = require("code-review.config")
  expect.equality(config.values.diff_mode, "unified")
end

suite["default config has expected values"] = function()
  local cr = require("code-review")
  cr.setup()

  local config = require("code-review.config")
  expect.equality(config.values.diff_mode, "split")
  expect.equality(config.values.provider, nil)
  expect.equality(config.values.keymaps.next_file, "]f")
end

suite["utils.system runs commands"] = function()
  local utils = require("code-review.utils")
  local stdout, _, code = utils.system({ "echo", "hello" })
  expect.equality(code, 0)
  expect.equality(vim.trim(stdout), "hello")
end

return suite
