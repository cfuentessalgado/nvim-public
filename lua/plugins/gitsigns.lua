local gh = require('custom.pack').gh

vim.pack.add { gh 'lewis6991/gitsigns.nvim' }

require('gitsigns').setup {
  signs = {
    add = { text = '┃' },
    change = { text = '┃' },
    delete = { text = '_' },
    topdelete = { text = '‾' },
    changedelete = { text = '~' },
    untracked = { text = '┆' },
  },
  signs_staged = {
    add = { text = '┃' },
    change = { text = '┃' },
    delete = { text = '_' },
    topdelete = { text = '‾' },
    changedelete = { text = '~' },
    untracked = { text = '┆' },
  },
  attach_to_untracked = true,
  current_line_blame_formatter = '<author>, <author_time:%R> - <summary>',
  on_attach = function(_, bufnr)
    local gs = package.loaded.gitsigns
    vim.keymap.set('n', '<leader>tb', gs.toggle_current_line_blame, { buffer = bufnr, desc = '[T]oggle [B]lame' })
  end,
}
