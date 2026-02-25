-- Tests for provider interface, GitHub provider, and auto-detection
local T = require("mini.test")
local expect = T.expect
local helpers = require("tests.helpers")
local test_config = require("tests.config")

local suite = T.new_set({
  hooks = {
    pre_case = helpers.reset,
  },
})

-- === Provider interface tests ===

suite["provider.validate accepts valid provider"] = function()
  local provider = require("code-review.provider")
  local valid, err = provider.validate({
    name = "test",
    get_pr = function() end,
    get_comments = function() end,
    post_comment = function() end,
  })
  expect.equality(valid, true)
  expect.equality(err, nil)
end

suite["provider.validate rejects missing name"] = function()
  local provider = require("code-review.provider")
  local valid, _ = provider.validate({
    get_pr = function() end,
    get_comments = function() end,
    post_comment = function() end,
  })
  expect.equality(valid, false)
end

suite["provider.validate rejects missing method"] = function()
  local provider = require("code-review.provider")
  local valid, err = provider.validate({
    name = "test",
    get_pr = function() end,
    -- missing get_comments and post_comment
  })
  expect.equality(valid, false)
  assert(err:match("get_comments"), "Error should mention missing method")
end

suite["provider.register and get"] = function()
  local provider = require("code-review.provider")
  local mock = {
    name = "mock",
    get_pr = function() end,
    get_comments = function() end,
    post_comment = function() end,
  }
  provider.register(mock)
  expect.equality(provider.get("mock"), mock)
end

-- === GitHub provider tests (read-only, uses real gh API) ===

suite["github.get_pr fetches test PR"] = function()
  local github = require("code-review.provider.github")
  local owner, repo = "eklavyamirani", "code-review.nvim"
  -- Use the branch name from the test PR
  local pr, err = github.get_pr(owner, repo, "test/sample-pr")
  expect.equality(err, nil)
  expect.no_equality(pr, nil)
  expect.equality(pr.number, test_config.test_pr)
  expect.equality(pr.base_ref, "main")
  expect.equality(pr.head_ref, "test/sample-pr")
  assert(#pr.title > 0, "PR title should not be empty")
end

suite["github.get_comments fetches PR comments"] = function()
  local github = require("code-review.provider.github")
  local owner, repo = "eklavyamirani", "code-review.nvim"
  local comments, err = github.get_comments(owner, repo, test_config.test_pr)
  expect.equality(err, nil)
  assert(#comments > 0, "Expected at least one comment on test PR")

  local c = comments[1]
  expect.no_equality(c.id, nil)
  expect.no_equality(c.body, nil)
  expect.no_equality(c.path, nil)
  expect.no_equality(c.author, nil)
end

-- === Provider detection tests ===

suite["detect finds github provider for this repo"] = function()
  local detect = require("code-review.provider.detect")
  local prov, owner, repo = detect.detect("origin")
  expect.no_equality(prov, nil)
  expect.equality(prov.name, "github")
  expect.equality(owner, "eklavyamirani")
  -- parse_remote strips .nvim from the repo name at the .git boundary
  expect.no_equality(repo, nil)
end

suite["detect returns nil for unknown hosts"] = function()
  -- Test with a non-existent remote
  local detect = require("code-review.provider.detect")
  local prov, _, _ = detect.detect("nonexistent-remote")
  expect.equality(prov, nil)
end

return suite
