vim.o.number = true
vim.o.relativenumber = true
vim.o.mouse = 'a'
vim.o.showmode = false
vim.schedule(function() vim.o.clipboard = 'unnamedplus' end)
vim.o.breakindent = true
vim.o.undofile = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.signcolumn = 'yes'
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.o.inccommand = 'split'
vim.o.cursorline = false
vim.o.scrolloff = 8
vim.o.sidescrolloff = 8
vim.o.wrap = false
vim.o.numberwidth = 2
vim.o.smartindent = true
vim.o.expandtab = true
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.shiftwidth = 4
vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false
vim.o.pumheight = 10
vim.o.showtabline = 0
vim.o.termguicolors = true
vim.o.background = 'dark'
vim.o.winbar = '%= %m%f'
vim.o.undodir = os.getenv 'HOME' .. '/.vim/undodir'
vim.o.confirm = true

vim.opt.isfname:append '@-@'
vim.filetype.add { extension = { templ = 'templ' } }

vim.diagnostic.config {
  update_in_insert = false,
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = { min = vim.diagnostic.severity.WARN } },
  virtual_text = false,
  virtual_lines = false,
  jump = {
    on_jump = function(_, bufnr)
      vim.diagnostic.open_float { bufnr = bufnr, scope = 'cursor', focus = false }
    end,
  },
}
