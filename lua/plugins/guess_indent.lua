local gh = require('custom.pack').gh

vim.pack.add { gh 'NMAC427/guess-indent.nvim' }
require('guess-indent').setup {}

if vim.g.have_nerd_font then vim.pack.add { gh 'nvim-tree/nvim-web-devicons' } end
