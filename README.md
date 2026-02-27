# code-review.nvim

Review pull requests directly inside Neovim. Provider-agnostic — works with GitHub, with more providers coming (Azure DevOps, Gitea, GitLab).

## Features

- **Diff views** — unified and side-by-side modes, togglable
- **File navigation** — traverse changed files with `]f` / `[f`
- **Inline comments** — read existing review comments, write new ones
- **Auto-detection** — provider and repo detected from your git remote
- **Statusline** — shows PR number, current file, and comment count

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
3. Navigate files with `]f` / `[f`, toggle diff mode with `<leader>ct`
4. Add comments with `<leader>cc`, submit with `<leader>cs`
5. Close the session with `:CodeReviewClose`

## Commands

| Command            | Description                          |
|--------------------|--------------------------------------|
| `:CodeReview`      | Start a review session for the current branch's PR |
| `:CodeReviewClose` | Close the current review session     |

## Keybindings

Active during a review session:

| Key            | Action                                |
|----------------|---------------------------------------|
| `]f`           | Next changed file                     |
| `[f`           | Previous changed file                 |
| `]c`           | Next comment                          |
| `[c`           | Previous comment                      |
| `<leader>cc`   | Add comment at cursor line            |
| `<leader>ct`   | Toggle diff mode (unified ↔ split)   |
| `<leader>cs`   | Submit comment (in comment window)    |
| `q` / `<Esc>`  | Cancel comment (in comment window)    |

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

  -- Custom keymap overrides
  keymaps = {
    next_file = "]f",
    prev_file = "[f",
    next_comment = "]c",
    prev_comment = "[c",
    add_comment = "<leader>cc",
    toggle_diff = "<leader>ct",
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

Output: `PR #1 | file.lua [2/5] | 💬 3`

## Adding a Provider

The plugin uses an abstract provider interface. To add a new provider:

1. Create `lua/code-review/provider/your_provider.lua`
2. Implement these methods:
   - `get_pr(owner, repo, branch)` → PR table or nil
   - `get_comments(owner, repo, pr_number)` → Comment list
   - `post_comment(owner, repo, pr_number, file, line, body, commit_id)` → Comment
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
