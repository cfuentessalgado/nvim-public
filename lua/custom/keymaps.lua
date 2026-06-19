vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
vim.keymap.set('n', '<leader>e', '<cmd>Neotree toggle<CR>', { desc = 'Toggle file tree' })
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<leader>h', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<leader>l', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<leader>j', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<leader>k', '<C-w><C-k>', { desc = 'Move focus to the upper window' })
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move selected lines up' })
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move selected lines down' })
vim.keymap.set('n', '<C-j>', '<cmd>cnext<CR>', { desc = 'Next quickfix item' })
vim.keymap.set('n', '<C-k>', '<cmd>cprev<CR>', { desc = 'Previous quickfix item' })

vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

if vim.env.NVIM_NEOGIT == '1' then
  vim.api.nvim_create_autocmd('VimEnter', { callback = function() require('neogit').open() end })
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'NeogitStatus',
    callback = function()
      vim.defer_fn(function() vim.keymap.set('n', 'q', '<cmd>qa<cr>', { buffer = true, desc = 'Quit Neovim' }) end, 100)
    end,
  })
end

-- vim.keymap.set('n', '<leader>lh', function()
--     vim.lsp.inlay_hint.enable()
-- end, { desc = 'Toggle LSP Inlay Hints' })
