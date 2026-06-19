local gh = require('custom.pack').gh

vim.pack.add { gh 'mbbill/undotree' }
vim.keymap.set('n', '<leader>u', '<cmd>UndotreeToggle<cr>', { desc = 'Toggle [U]ndo Tree' })
