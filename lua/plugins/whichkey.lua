local gh = require('custom.pack').gh

vim.pack.add { gh 'folke/which-key.nvim' }

require('which-key').setup {
  delay = 0,
  icons = { mappings = vim.g.have_nerd_font },
  spec = {
    { '<leader>a', group = '[A]I / Sidekick' },
    { '<leader>c', group = '[C]ode' },
    { '<leader>d', group = '[D]ocument' },
    { '<leader>g', group = '[G]it' },
    { '<leader>r', group = '[R]ename' },
    { '<leader>s', group = '[S]earch', mode = { 'n', 'v' } },
    { '<leader>w', group = '[W]orkspace' },
    { '<leader>t', group = '[T]oggle' },
    { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
    { 'gr', group = 'LSP Actions', mode = { 'n' } },
  },
}
