local gh = require('custom.pack').gh

vim.pack.add { gh 'NeogitOrg/neogit', gh 'sindrets/diffview.nvim' }

require('neogit').setup {}
vim.keymap.set('n', '<leader>gs', '<cmd>Neogit<cr>', { desc = 'Open Neogit' })
