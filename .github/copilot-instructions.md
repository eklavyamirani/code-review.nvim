# Copilot Instructions — code-review.nvim

## Build & Test

Tests run inside Docker (Ubuntu 24.04, Neovim 0.10.3, GitHub CLI, plenary.nvim, mini.nvim pre-installed):

```bash
# Setup
cp .env.example .env   # add GH_TOKEN

# Run full test suite
docker compose run --rm dev bash scripts/test.sh

# Run a single test file
docker compose run --rm dev nvim --headless \
  -c "lua require('mini.test').setup()" \
  -c "lua require('mini.test').run_file('tests/test_git.lua')"

# Validate infrastructure (gh auth, git, nvim, deps)
docker compose run --rm dev bash scripts/validate.sh
```

Tests default to mocked API responses. Set `CODE_REVIEW_TEST_REAL_API=1` to hit the real GitHub API.

## Architecture

**Neovim plugin** for reviewing pull requests. Provider-agnostic design with GitHub as the first (and currently only) provider.

### Core flow

`plugin/code-review.lua` → registers `:CodeReview` / `:CodeReviewClose` commands
→ `lua/code-review/init.lua` — public API (`setup`, `start`, `close`, `statusline`, navigation functions)
→ `review.lua` — singleton session state (`ReviewSession` holds PR, files, comments, current file index)
→ `provider/detect.lua` — auto-detects provider from git remote hostname
→ `provider/github.lua` — calls GitHub API via `gh api` CLI subprocess

### Module responsibilities

| Module | Role |
|---|---|
| `config.lua` | Merges user options with defaults |
| `review.lua` | Session lifecycle, file navigation, comment filtering |
| `git.lua` | Git CLI wrapper (`vim.system()` calls for branch, remote, diff) |
| `diff.lua` | Parses unified diff output into `FileDiff` → `DiffHunk` → `DiffLine` structs |
| `provider/init.lua` | Provider registry with `validate`/`register`/`get` |
| `provider/detect.lua` | Maps remote hostnames to provider modules |
| `provider/github.lua` | GitHub implementation using `gh api` |
| `ui/init.lua` | Shared UI helpers (scratch buffers, highlights, namespace) |
| `ui/diff.lua` | Renders diffs in unified or split mode |
| `ui/comments.lua` | Floating window for comment input/display |
| `ui/file_list.lua` | Changed files sidebar |
| `health.lua` | `:checkhealth` integration |

### Provider interface

New providers implement three methods:

```lua
get_pr(owner, repo, branch) → (PR, error)
get_comments(owner, repo, pr_number) → (Comment[], error)
post_comment(owner, repo, pr_number, file, line, body, commit_id) → (Comment, error)
```

Then add a hostname pattern in `provider/detect.lua`. See `provider/github.lua` as the reference.

## Conventions

- **Error handling**: Functions return `(value, error)` tuples. Check `if not value` before proceeding.
- **User notifications**: Always use `vim.notify("code-review: ...", vim.log.levels.LEVEL)`.
- **System commands**: Use `utils.system(cmd, cwd)` which wraps `vim.system()` and returns `(stdout, stderr, code)`.
- **Buffer writes**: Use `ui.set_lines(buf, lines)` which toggles `modifiable` around the write.
- **Type annotations**: Use `---@class` and `---@field` LuaCATS annotations for data structures.
- **Test isolation**: Every test suite uses `hooks.pre_case = helpers.reset` to unload all plugin modules between test cases.
- **Test framework**: mini.test — assertions use `T.expect.equality(actual, expected)`.
