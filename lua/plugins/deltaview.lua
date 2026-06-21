local gh = require('custom.pack').gh

vim.pack.add { gh 'kokusenz/deltaview.nvim' }

vim.keymap.set('n', '<leader>td', '<cmd>DeltaView<CR>', { desc = 'Enter [D]eltaView' })
vim.keymap.set('n', '<leader>sd', '<cmd>DeltaMenu<CR>', { desc = '[S]earch [D]iff' })
