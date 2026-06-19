local gh = require('custom.pack').gh

vim.pack.add {
  { src = gh 'L3MON4D3/LuaSnip', version = vim.version.range '2.*' },
  gh 'rafamadriz/friendly-snippets',
  { src = gh 'saghen/blink.cmp', version = vim.version.range '1.*' },
}

require('luasnip').setup {}
require('luasnip.loaders.from_vscode').lazy_load()

require('blink.cmp').setup {
  keymap = { preset = 'default' },
  appearance = { nerd_font_variant = 'mono' },
  completion = {
    documentation = {
      auto_show = true,
      auto_show_delay_ms = 500,
      treesitter_highlighting = true,
      window = { min_width = 10, max_width = 60, max_height = 20, border = 'rounded', winblend = 0, scrollbar = true },
    },
  },
  sources = {
    default = { 'lazydev', 'lsp', 'path', 'snippets', 'buffer' },
    providers = {
      lazydev = { name = 'LazyDev', module = 'lazydev.integrations.blink', score_offset = 100 },
    },
  },
  snippets = { preset = 'luasnip' },
  fuzzy = { implementation = 'lua' },
  signature = { enabled = true },
}
