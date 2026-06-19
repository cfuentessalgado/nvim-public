local gh = require('custom.pack').gh

vim.pack.add { gh 'stevearc/oil.nvim' }

require('oil').setup {
  keymaps = {
    ['<leader>-'] = { 'actions.close', mode = 'n' },
  },
}
vim.keymap.set('n', '-', '<cmd>Oil<cr>', { desc = 'Open parent directory' })
