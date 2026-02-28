# code-review.nvim

Review pull requests directly inside Neovim. Provider-agnostic — works with GitHub, with more providers coming (Azure DevOps, Gitea, GitLab).

## Features

- **Full-file unified view** — shows complete HEAD file with highlighted changes; removed lines and comments are collapsible virtual text (`zo`/`zc`/`zA`)
- **Side-by-side split view** — traditional diff with Neovim's built-in `diffthis` for scroll sync
- **File navigation** — traverse changed files with `]f` / `[f`
- **Hunk navigation** — jump between changed regions with `]h` / `[h`
- **Comment navigation** — jump between comments across files with `]c` / `[c`
- **Comment threading** — replies displayed inline with indentation; reply to any comment with `<leader>cr`
- **PR review submission** — approve, request changes, or comment via `:CodeReviewSubmit`
- **File review status** — track which files you've reviewed (`<leader>cv`), progress shown in statusline
- **Session refresh** — re-fetch PR data without restarting via `:CodeReviewRefresh`
- **AI-assisted review** — pipe diff context to any CLI tool via `:CodeReviewAsk` (configurable)
- **Checkout at ref** — open the full file at base or head ref via `:CodeReviewCheckout base|head`
- **PR info** — view PR description, metadata, and file summary via `:CodeReviewInfo`
- **Auto-detection** — provider and repo detected from your git remote
- **Statusline** — shows PR number, current file, comment count, and review progress

## Requirements

- Neovim >= 0.10
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [git](https://git-scm.com/)
- [GitHub CLI (`gh`)](https://cli.github.com/) — for the GitHub provider

## Installation

### lazy.nvim

```lua
{
  "eklavyamirani/code-review.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("code-review").setup()
  end,
}
```

### vim-plug

```vim
call plug#begin()
Plug 'nvim-lua/plenary.nvim'
Plug 'eklavyamirani/code-review.nvim'
call plug#end()

lua require("code-review").setup()
```

### Neovim 0.12+ native plugin manager (`vim.pack`)

```lua
vim.pack.add({
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/eklavyamirani/code-review.nvim",
})

require("code-review").setup()
```

## Usage

1. Check out the branch for the PR you want to review (or use a worktree)
2. Run `:CodeReview` — the plugin detects the branch, remote, and provider
3. Navigate files with `]f` / `[f`, hunks with `]h` / `[h`, comments with `]c` / `[c`
4. Toggle diff mode with `<leader>ct`; expand/collapse removed lines or comments with `zo` / `zc`
5. Add comments with `<leader>cc`, reply to existing with `<leader>cr`
6. Mark files reviewed with `<leader>cv`
7. Submit your review with `:CodeReviewSubmit`
8. Close the session with `:CodeReviewClose`

## Commands

| Command                        | Description                                          |
|--------------------------------|------------------------------------------------------|
| `:CodeReview`                  | Start a review session for the current branch's PR   |
| `:CodeReviewClose`             | Close the current review session                     |
| `:CodeReviewSubmit`            | Submit a review (approve / request changes / comment)|
| `:CodeReviewRefresh`           | Refresh PR data, diff, and comments in-place         |
| `:CodeReviewAsk`               | Ask AI to review the diff (configurable CLI)         |
| `:CodeReviewSet key value`     | Change config at runtime (e.g., `ai.cmd`)            |
| `:CodeReviewCheckout base/head`| Open current file at the specified ref               |
| `:CodeReviewInfo`              | Show PR description and metadata                     |

## Keybindings

Active during a review session:

| Key            | Action                                        |
|----------------|-----------------------------------------------|
| `]f`           | Next changed file                             |
| `[f`           | Previous changed file                         |
| `]h`           | Next hunk                                     |
| `[h`           | Previous hunk                                 |
| `]c`           | Next comment (cross-file)                     |
| `[c`           | Previous comment (cross-file)                 |
| `<leader>cc`   | Add comment at cursor line                    |
| `<leader>cr`   | Reply to nearest comment                      |
| `<leader>ct`   | Toggle diff mode (unified ↔ split)           |
| `<leader>cv`   | Toggle file reviewed status                   |
| `<leader>cs`   | Submit comment/review (in input window)       |
| `zo`           | Expand collapsed item (unified view)          |
| `zc`           | Collapse expanded item (unified view)         |
| `zA`           | Toggle all collapsed items (unified view)     |
| `q` / `<Esc>`  | Close floating window                         |

## Configuration

All options are optional — defaults shown below:

```lua
require("code-review").setup({
  -- Provider name override (auto-detected from git remote if nil)
  provider = nil,

  -- Default diff view mode: "split" or "unified"
  diff_mode = "split",

  -- File picker for browsing changed files: "auto", "netrw", "mini_files"
  -- "auto" prefers mini.files if installed, falls back to netrw
  file_picker = "auto",

  -- AI-assisted review configuration
  ai = {
    cmd = nil,         -- CLI command to pipe diff into (e.g., "claude -p", "gh copilot suggest")
    context = "file",  -- "file" (current file diff + file list) or "pr" (entire PR diff)
  },

  -- Custom keymap overrides
  keymaps = {
    next_file = "]f",
    prev_file = "[f",
    next_hunk = "]h",
    prev_hunk = "[h",
    next_comment = "]c",
    prev_comment = "[c",
    add_comment = "<leader>cc",
    reply_comment = "<leader>cr",
    toggle_diff = "<leader>ct",
    toggle_reviewed = "<leader>cv",
  },
})
```

## Statusline

Expose review state in your statusline:

```lua
-- lualine
require("lualine").setup({
  sections = {
    lualine_x = {
      { require("code-review").statusline },
    },
  },
})
```

Output: `PR #1 | file.lua [2/5] | 💬 3 | ✓ 2/5`

## Adding a Provider

The plugin uses an abstract provider interface. To add a new provider:

1. Create `lua/code-review/provider/your_provider.lua`
2. Implement these methods:
   - `get_pr(owner, repo, branch)` → PR table or nil
   - `get_comments(owner, repo, pr_number)` → Comment list
   - `post_comment(owner, repo, pr_number, file, line, body, commit_id)` → Comment
   - `submit_review(owner, repo, pr_number, event, body)` → Review (optional)
   - `reply_to_comment(owner, repo, pr_number, comment_id, body)` → Comment (optional)
3. Add a hostname pattern in `lua/code-review/provider/detect.lua`

See `lua/code-review/provider/github.lua` for a reference implementation.

## Development

```bash
# Setup
cp .env.example .env    # Add your GH_TOKEN
docker compose build

# Run tests
docker compose run --rm dev bash scripts/test.sh

# Validate infrastructure
docker compose run --rm dev bash scripts/validate.sh
```

## License

MIT
