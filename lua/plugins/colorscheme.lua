local gh = require('custom.pack').gh

vim.pack.add { gh 'folke/tokyonight.nvim' }
require('tokyonight').setup { styles = { comments = { italic = false } } }
vim.cmd.colorscheme 'tokyonight-night'
