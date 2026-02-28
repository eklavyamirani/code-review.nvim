-- Smoke tests: verify plugin loads and configures correctly
local T = require("mini.test")
local expect = T.expect
local helpers = require("tests.helpers")

local suite = T.new_set({
  hooks = {
    pre_case = function()
      helpers.reset()
      package.loaded["code-review.ui"] = nil
    end,
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

suite["config.set changes values at runtime"] = function()
  local cr = require("code-review")
  cr.setup()
  local config = require("code-review.config")

  config.set("ai.cmd", "claude -p")
  expect.equality(config.values.ai.cmd, "claude -p")

  config.set("diff_mode", "unified")
  expect.equality(config.values.diff_mode, "unified")
end

suite["default config has expected values"] = function()
  local cr = require("code-review")
  cr.setup()

  local config = require("code-review.config")
  expect.equality(config.values.diff_mode, "split")
  expect.equality(config.values.provider, nil)
  expect.equality(config.values.keymaps.next_file, "]f")
  expect.equality(config.values.ai.cmd, nil)
  expect.equality(config.values.ai.context, "file")
end

suite["utils.system runs commands"] = function()
  local utils = require("code-review.utils")
  local stdout, _, code = utils.system({ "echo", "hello" })
  expect.equality(code, 0)
  expect.equality(vim.trim(stdout), "hello")
end

suite["statusline returns empty when no session"] = function()
  package.loaded["code-review.review"] = nil
  local cr = require("code-review")
  expect.equality(cr.statusline(), "")
end

suite["public API has expected functions"] = function()
  local cr = require("code-review")
  expect.equality(type(cr.start), "function")
  expect.equality(type(cr.close), "function")
  expect.equality(type(cr.next_file), "function")
  expect.equality(type(cr.prev_file), "function")
  expect.equality(type(cr.toggle_diff), "function")
  expect.equality(type(cr.add_comment), "function")
  expect.equality(type(cr.statusline), "function")
  expect.equality(type(cr.next_comment), "function")
  expect.equality(type(cr.prev_comment), "function")
  expect.equality(type(cr.next_hunk), "function")
  expect.equality(type(cr.prev_hunk), "function")
  expect.equality(type(cr.reply_comment), "function")
  expect.equality(type(cr.submit_review), "function")
  expect.equality(type(cr.toggle_reviewed), "function")
  expect.equality(type(cr.refresh), "function")
  expect.equality(type(cr.ask_ai), "function")
  expect.equality(type(cr.set_config), "function")
  expect.equality(type(cr.checkout_file), "function")
  expect.equality(type(cr.show_pr_info), "function")
end

return suite
