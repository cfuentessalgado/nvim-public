local gh = require('custom.pack').gh

vim.pack.add { gh 'folke/tokyonight.nvim' }
require('tokyonight').setup { styles = { comments = { italic = false } } }
vim.cmd.colorscheme 'tokyonight-night'
vim.opt.fillchars:append { eob = ' ' }

local function apply_highlights()
  -- vim.api.nvim_set_hl(0, 'Normal', { bg = 'none' })
  -- vim.api.nvim_set_hl(0, 'NormalFloat', { bg = 'none' })
  -- vim.api.nvim_set_hl(0, 'FloatBorder', { bg = 'none' })
  -- vim.api.nvim_set_hl(0, 'Pmenu', { bg = 'none' })
  vim.api.nvim_set_hl(0, 'WinBar', { bg = 'none', fg = '#4f5554' })
end

apply_highlights()
vim.api.nvim_create_autocmd('ColorScheme', { callback = apply_highlights })
