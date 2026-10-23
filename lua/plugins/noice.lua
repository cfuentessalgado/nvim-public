local gh = require('custom.pack').gh

vim.pack.add { gh 'MunifTanjim/nui.nvim', gh 'folke/noice.nvim' }
require('noice').setup {
  init = function ()
    vim.opt.cmdheight = 1
  end
}
