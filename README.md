# nvim-public

Personal Neovim config using native `vim.pack`.

## Requirements

Required:

- Neovim (0.12+) with native `vim.pack` support.
- `git`, for plugin installation.
- A C compiler / build tools, for Treesitter parsers and native plugin builds.
- `rg` / ripgrep, for Telescope grep features.

Strongly recommended:

- A Nerd Font, because `vim.g.have_nerd_font = true` and several plugins use icons.
- `make`, to build `telescope-fzf-native.nvim` and LuaSnip's optional jsregexp support.
- `fd`, for faster Telescope file finding when available.
- A system clipboard provider for `clipboard=unnamedplus`:
  - macOS: built in via `pbcopy`/`pbpaste`
  - Linux/X11: `xclip` or `xsel`
  - Linux/Wayland: `wl-clipboard`

Language/tooling requirements:

- Mason installs configured LSP servers and `stylua`.
- Other formatters must be available separately if you want those filetypes formatted:
  - PHP: `vendor/bin/pint`, `pint`, `vendor/bin/php-cs-fixer`, or `php-cs-fixer`
  - Blade: `blade-formatter`
  - JS/TS: `prettierd` or `prettier`
  - Go: `gofmt` and `goimports`
  - Rust: `rustfmt`
- Some Mason-managed servers require their ecosystem runtimes/package managers to install or run, such as Node/npm, Go, Rust/Cargo, PHP, etc.

Optional workflow tools:

- `tmux`, for Sidekick's configured mux backend.
- Sidekick target CLIs if you use those mappings: `claude`, `opencode`, and `pi`.

## Options

Leader and local leader are both `<Space>`.

Notable defaults:

- line numbers + relative numbers
- system clipboard via `unnamedplus`
- persistent undo in `$HOME/.vim/undodir`
- no swap, backup, or writebackup files
- search uses `ignorecase` + `smartcase`
- splits open right/below
- whitespace shown with custom `listchars`
- no line wrap
- 4-space tabs/indent by default
- true color + dark background
- `tokyonight-night` colorscheme
- diagnostics sorted by severity, rounded floats, virtual text off
- `*.templ` detected as `templ`

## Mappings

### Core

| Mode | Key | Action |
|---|---|---|
| Normal | `<Esc>` | Clear search highlights |
| Normal | `<leader>q` | Open diagnostic quickfix/location list |
| Normal | `<leader>e` | Toggle Neo-tree file tree |
| Terminal | `<Esc><Esc>` | Exit terminal mode |
| Normal | `<C-h>` / `<C-l>` | Move focus left/right |
| Normal | `<leader>h/j/k/l` | Move focus left/down/up/right |
| Visual | `K` / `J` | Move selected lines up/down |
| Normal | `<C-j>` / `<C-k>` | Next/previous quickfix item |
| Normal | `<leader>sef` | Edit temporary scratch file |

### Search

| Key | Action |
|---|---|
| `<leader>sh` | Help tags |
| `<leader>sk` | Keymaps |
| `<leader>sf` | Files |
| `<leader>f` | Git files |
| `<leader>sc` | Changed files / git status |
| `<leader>ss` | Telescope builtins |
| `<leader>sw` | Current word/selection |
| `<leader>sd` | Diagnostics |
| `<leader>sr` | Resume picker |
| `<leader>s.` | Recent files |
| `<leader>sx` | Commands |
| `<leader><leader>` | Buffers |
| `<leader>sg` | Multi-grep with optional glob, separated by two spaces |
| `<leader>g` | Prompted grep |
| `<leader>/` | Fuzzy search current buffer |
| `<leader>s/` | Live grep open files |
| `<leader>sn` | Search Neovim config |

### LSP

Buffer-local after LSP attach:

| Key | Action |
|---|---|
| `gd` / `gr` / `gI` / `gD` | Definition / references / implementation / declaration |
| `<leader>D` | Type definition |
| `<leader>wd` / `<leader>dd` | Workspace/document diagnostics |
| `<leader>ds` / `<leader>ws` | Document/workspace symbols |
| `<leader>rn` | Rename |
| `<leader>ca` | Code action |
| `K` | Hover |
| `<leader>th` | Toggle inlay hints |
| `<leader>td` | Toggle diagnostic virtual text |
| `<leader>cf` | Format |
| `grr` / `gri` / `grd` / `grt` | Telescope references/implementations/definitions/type definitions |
| `gO` / `gW` | Document/workspace symbols |

### Tools

| Key | Action |
|---|---|
| `<leader>bf` / `<leader>df` | Format with conform |
| `<leader>tb` | Toggle gitsigns current-line blame |
| `<leader>gs` | Open Neogit |
| `-` | Open parent directory with Oil |
| `<leader>-` | Close Oil buffer |
| `<leader>u` | Toggle UndoTree |

### Sidekick / AI

| Key | Action |
|---|---|
| Insert `<Tab>` | Jump/apply next edit suggestion, else tab |
| `<C-.>` | Toggle Sidekick CLI |
| `<leader>aa` | Toggle Sidekick CLI |
| `<leader>as` | Select CLI |
| `<leader>ad` | Detach CLI session |
| `<leader>at` | Send current context |
| `<leader>af` | Send current file |
| Visual `<leader>av` | Send selection |
| `<leader>asp` | Select prompt |
| `<leader>ac` / `<leader>ao` / `<leader>ap` | Toggle Claude / OpenCode / Pi |

## Plugins

- `blink.cmp` + `LuaSnip` + `friendly-snippets`
- `conform.nvim`
- `gitsigns.nvim`
- `guess-indent.nvim`
- `lazydev.nvim`
- `mason.nvim`, `mason-lspconfig.nvim`, `mason-tool-installer.nvim`
- `mini.nvim`
- `neo-tree.nvim`
- `neogit` + `diffview.nvim`
- `noice.nvim` + `nui.nvim`
- `nvim-autopairs`
- `nvim-lspconfig`
- `nvim-treesitter`
- `oil.nvim`
- `sidekick.nvim`
- `telescope.nvim`, `telescope-ui-select.nvim`, optional `telescope-fzf-native.nvim`
- `todo-comments.nvim`
- `tokyonight.nvim`
- `undotree`
- `which-key.nvim`

## LSP and formatting

LSP servers installed/enabled through Mason:

- `gopls`
- `rust_analyzer`
- `ts_ls`
- `intelephense`
- `bashls`
- `html`
- `emmet_language_server`
- `lua_ls`

Formatters configured through conform:

- Lua: `stylua`
- PHP: `pint`, then `php-cs-fixer`
- Blade: `blade-formatter`
- JS/TS: `prettierd`, then `prettier`
- Go: `gofmt`, `goimports`
- Rust: `rustfmt`

Format-on-save is currently disabled by an empty allowlist.
