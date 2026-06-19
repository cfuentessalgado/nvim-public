local gh = require('custom.pack').gh

vim.pack.add { gh 'stevearc/conform.nvim' }

require('conform').setup {
  notify_on_error = false,
  format_on_save = function(bufnr)
    local enabled_filetypes = {}
    if enabled_filetypes[vim.bo[bufnr].filetype] then return { timeout_ms = 500 } end
    return nil
  end,
  default_format_opts = { lsp_format = 'fallback' },
  formatters_by_ft = {
    lua = { 'stylua' },
    php = { 'pint', 'php-cs-fixer', stop_after_first = true },
    blade = { 'blade-formatter' },
    javascript = { 'prettierd', 'prettier', stop_after_first = true },
    typescript = { 'prettierd', 'prettier', stop_after_first = true },
    go = { 'gofmt', 'goimports' },
    rust = { 'rustfmt' },
  },
  formatters = {
    pint = {
      command = function()
        local local_pint = vim.fn.findfile('vendor/bin/pint', '.;')
        if local_pint ~= '' then return vim.fn.fnamemodify(local_pint, ':p') end
        return 'pint'
      end,
    },
    ['php-cs-fixer'] = {
      command = function()
        local local_fixer = vim.fn.findfile('vendor/bin/php-cs-fixer', '.;')
        if local_fixer ~= '' then return vim.fn.fnamemodify(local_fixer, ':p') end
        return 'php-cs-fixer'
      end,
    },
  },
}

vim.keymap.set({ 'n', 'v' }, '<leader>bf', function() require('conform').format { async = true } end, { desc = '[B]uffer [F]ormat' })
vim.keymap.set({ 'n', 'v' }, '<leader>df', function() require('conform').format { async = true, lsp_format = 'fallback' } end, { desc = '[D]o [F]ormat' })
